---
phase: whole-codebase
reviewed: 2026-11-09T22:30:00Z
depth: deep
files_reviewed: 30
files_reviewed_list:
  - Package.swift
  - Sources/CNeedle/include/needle.h
  - Sources/CNeedle/shim.c
  - Sources/SayloCLI/main.swift
  - Sources/SayloApp/Design/DesignSystem.swift
  - Sources/SayloApp/Design/WaveformLoader.swift
  - Sources/SayloApp/Models/Models.swift
  - Sources/SayloApp/SayloApp.swift
  - Sources/SayloApp/Services/DictationController.swift
  - Sources/SayloApp/Services/DictationHotkeyCoordinator.swift
  - Sources/SayloApp/Services/HotkeyMonitor.swift
  - Sources/SayloApp/Services/PermissionsManager.swift
  - Sources/SayloApp/Services/TextInserter.swift
  - Sources/SayloApp/Stores/DictionaryStore.swift
  - Sources/SayloApp/Stores/HistoryStore.swift
  - Sources/SayloApp/Stores/JSONStore.swift
  - Sources/SayloApp/Stores/PreferencesStore.swift
  - Sources/SayloApp/UI/DictionaryWindow.swift
  - Sources/SayloApp/UI/FloatingPill.swift
  - Sources/SayloApp/UI/MainWindow.swift
  - Sources/SayloApp/UI/MenuBarView.swift
  - Sources/SayloApp/UI/SettingsWindow.swift
  - Sources/SayloCore/AudioChunker.swift
  - Sources/SayloCore/AudioRecorder.swift
  - Sources/SayloCore/SpeechActivity.swift
  - Sources/SayloCore/TextPostProcessor.swift
  - Sources/SayloCore/WhistleEngine.swift
  - Tests/SayloCoreTests/SayloCoreTests.swift
  - scripts/bundle.sh
  - scripts/setup.sh
findings:
  critical: 5
  warning: 21
  info: 14
  total: 40
status: issues_found
---

# Saylo — Code Review Report

**Reviewed:** 2026-11-09
**Depth:** deep (cross-file call-chain analysis)
**Files Reviewed:** 30 (24 Swift sources, 1 C header, 1 C shim, 2 shell scripts, Package.swift, 1 test file)
**Status:** issues_found

## Summary

Saylo is a ~5.9k-line SwiftUI macOS dictation app: a C speech engine (`needle`) wrapped by an actor, an `AVAudioEngine` capture path with energy-based silence gating, a CGEventTap global hotkey, pasteboard-based text insertion, and JSON-file persistence for history and a correction dictionary.

The core DSP and silence-gating code (`SpeechActivity`, `AudioChunker`, `WhisperEngine` JSON parsing) is well-tested and defensively written. The failure surface is concentrated in the **app-layer glue**: the dictionary correction loop, SwiftUI environment wiring, the audio tap lifecycle, and the hotkey state machine. Five defects are release-blocking: one hangs the app deterministically, two crash, one can crash on retry after a failed start, and one destroys history with a single click.

A large amount of the UI is presentational scaffolding from the Paper artboards: several stats are fabricated constants, several controls are wired to nothing, and a meaningful set of preferences are declared, rendered, persisted — and never read.

**Verification note:** `swift build` could not be run in this environment (`swift-tools-version:6.0` vs installed Swift 5.10.1, and `xcrun` has no macOS platform path). All findings are from static analysis of the sources, cross-checked against call sites. No source files were modified.

---

## Critical Issues

### CR-01: Dictionary corrections can hang the app forever (infinite loop)

**File:** `Sources/SayloApp/Stores/DictionaryStore.swift:182-186`, `:220-250`

**Issue:** For `.word`-type entries, `rebuildIndexes()` builds a pattern from the phrase and sets the **replacement to the same phrase**:

```swift
case .word:
    let pattern = buildFlexiblePattern(from: entry.phrase)
    corrections.append((pattern: pattern, replacement: entry.phrase))
```

`applyCorrectionPattern` then loops on `firstMatch` and re-replaces:

```swift
while let match = regex.firstMatch(in: correctedText, ...) {
    ...
    correctedText.replaceSubrange(matchRange, with: finalReplacement)
    didChange = true
}
```

When the matched text already equals the replacement, the substitution is a no-op, the regex still matches at the same offset, and the loop never advances. Because `applyCorrections` runs on the `@MainActor` inside `DictationController.transcribeAndInsert` (`DictationController.swift:174`), the UI freezes permanently and the user must force-quit.

**Reproduction:** Add any word to the dictionary (e.g. "Kubernetes"), then dictate a sentence containing it. The default `.word` entry type is what the "+ Add new word" sheet creates, so this is the ordinary path, not an edge case.

**Fix:** Replace the manual loop with a single non-overlapping pass and guard against self-replacement:

```swift
private func applyCorrectionPattern(pattern: String, replacement: String,
                                    to text: String) -> (didChange: Bool, originalMatch: String, correctedText: String) {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return (false, "", text)
    }
    let full = NSRange(text.startIndex..<text.endIndex, in: text)
    var didChange = false
    var lastMatch = ""

    let result = regex.stringByReplacingMatches(in: text, options: [], range: full) { match, matched in
        guard matched != replacement else { return matched }   // no-op match: leave alone
        didChange = true
        lastMatch = matched
        return matched.first?.isUppercase == true
            ? replacement.prefix(1).uppercased() + replacement.dropFirst()
            : replacement
    }
    return (didChange, lastMatch, result)
}
```

Also skip building a correction pair when `pattern` and `replacement` are equivalent, and add a unit test that applies a `.word` entry twice to the same text (this would have caught the hang).

---

### CR-02: Settings sheets are missing `PermissionsManager` → crash on the Permissions/Microphone tabs

**File:** `Sources/SayloApp/UI/MainWindow.swift:77-83`, `Sources/SayloApp/UI/MenuBarView.swift:124-129`, `Sources/SayloApp/UI/SettingsWindow.swift:12`

**Issue:** `SettingsWindow` declares `@EnvironmentObject private var permissionsManager: PermissionsManager`, and both `MicrophonePane` and `PermissionsPane` resolve it from the environment. Neither sheet injects it:

```swift
// MainWindow.swift:77
SettingsWindow()
    .environmentObject(preferencesStore)
    .environmentObject(historyStore)
    .environmentObject(dictionaryStore)
    .environmentObject(dictationController)   // no permissionsManager

// MenuBarView.swift:124
SettingsWindow()
    .environmentObject(preferencesStore)
    .environmentObject(historyStore)
    .environmentObject(dictionaryStore)       // no permissionsManager
```

Selecting **Microphone** or **Permissions** in Settings opens from the main window (sidebar gear, ⌘,) or from the menu-bar popover traps with `No ObservableObject of type PermissionsManager found`. The only place that *does* inject it is the `WindowGroup("Settings", id: "settings")` at `SayloApp.swift:100-106`, and nothing in the app ever opens that window (no `openWindow(id: "settings")` call exists), so it is unreachable.

**Fix:** Inject the manager in both sheets, and delete the unreachable `WindowGroup` (or make the sheets call `openWindow(id: "settings")` and keep a single presentation path):

```swift
// both sheet call sites
.environmentObject(permissionsManager)
```

Note `MainWindow` does not currently hold `permissionsManager` at all — add `@EnvironmentObject private var permissionsManager: PermissionsManager` to `MainWindow` and inject it at the root.

---

### CR-03: `fatalError` kills the app at launch when the model cannot load; `fatalError` on empty dictionary input

**File:** `Sources/SayloApp/SayloApp.swift:28-30`, `:71-73`; `Sources/SayloApp/Stores/DictionaryStore.swift:26`, `:30`

**Issue:** The app's entry point resolves the model as

```swift
let modelURL = Bundle.main.url(forResource: "whistle", withExtension: "cact") ??
              URL(fileURLWithPath: "vendor/whistle.cact")
...
} catch {
    fatalError("Failed to initialize Saylo: \(error)")
}
```

The relative fallback resolves against the process working directory, which is `/` for a Finder-launched `.app`. If the bundle resource is missing or renamed (a very plausible packaging regression — `bundle.sh` copies `whistle.cact` by hand), the user gets an immediate, silent termination with no window, no dialog, and no log visible outside Console. There is no degraded mode and no way to report the problem from the UI.

Separately, `DictionaryStore.addEntry` and `updateEntry` use `fatalError` for what is ordinary user input validation:

```swift
guard !trimmedPhrase.isEmpty else { fatalError("Phrase cannot be empty") }
guard !trimmedReplacement.isEmpty else { fatalError("Replacement cannot be empty") }
```

The add/edit sheet guards these today, but `addEntry` is a `public` API on a store, and `importFrom`/future callers are not protected. A crash is not an input-validation strategy.

**Fix:** Surface a recoverable error instead of terminating:

```swift
// SayloApp
private let engineError: String?
// in catch: self.engineError = error.localizedDescription, and render an
// "Engine unavailable — reinstall Saylo" view instead of fatalError.
```

```swift
// DictionaryStore
public func addEntry(...) throws -> DictionaryEntry {
    guard !trimmedPhrase.isEmpty else { throw DictionaryError.emptyPhrase }
    ...
}
```

---

### CR-04: `AudioRecorder.start()` leaks its tap on failure and then crashes on retry

**File:** `Sources/SayloCore/AudioRecorder.swift:39-68`

**Issue:** `start()` installs a tap and only then starts the engine, with no cleanup if the engine fails:

```swift
input.installTap(onBus: 0, bufferSize: 1024, format: format) { ... }
engine.prepare()
try engine.start()          // throws → tap stays installed, engine stopped
```

`AVAudioNode.installTap` raises an Objective-C exception ("required condition is false: nullptr == Tap()") if a tap already exists on that bus. So the sequence *start → engine.start() fails → user presses the hotkey again → start → installTap* is a hard crash, not a handled error. The tap is never removed because `stop()` is only reachable while `state == .recording`, and the state was never advanced.

The same method also computes `let ratio = target.sampleRate / format.sampleRate` with no guard. When the input node has no usable device, `outputFormat(forBus: 0)` can report a 0 Hz sample rate; `ratio` becomes `inf` and `AVAudioFrameCount(Double(pcm.frameLength) * ratio)` traps on the `UInt32` conversion.

**Fix:**

```swift
public func start() throws {
    // never stack taps
    engine.inputNode.removeTap(onBus: 0)
    ...
    guard format.sampleRate > 0, format.channelCount > 0 else {
        throw NSError(domain: "Saylo", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "No microphone input available"])
    }
    input.installTap(...)
    engine.prepare()
    do { try engine.start() }
    catch {
        input.removeTap(onBus: 0)
        engine.stop()
        throw error
    }
}
```

Also guard `AudioRecorder.stop()` with a `tapInstalled` flag so it cannot call `removeTap` when no tap exists.

---

### CR-05: The "More actions" (⋯) button deletes a history entry with no confirmation

**File:** `Sources/SayloApp/UI/MainWindow.swift:469-477`

**Issue:** In every hovered timeline row, the third control is an ellipsis labelled "More actions", but its action is an immediate, irreversible delete:

```swift
Button {
    historyStore.deleteEntry(entry)          // no confirmation, no undo
} label: {
    Image(systemName: "ellipsis")
        .foregroundStyle(DesignSystem.Color.muted)
}
.buttonStyle(.plain)
.accessibilityLabel("More actions")
```

The visual and accessibility contract says "more actions"; the behaviour is "destroy". The entry is removed from memory and `store.json` is rewritten on the next save, so there is no undo path. This is a one-click data-loss trap on the primary screen.

**Fix:** Either open a menu (Copy / Copy Raw / Re-insert / Delete) or route through a confirmation:

```swift
Button { showingDeleteConfirm = true } label: { Image(systemName: "ellipsis") }
    .accessibilityLabel("More actions")
    .confirmationDialog("Delete this dictation?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
        Button("Delete", role: .destructive) { historyStore.deleteEntry(entry) }
    }
```

---

## Warnings

### WR-01: Changing the push-to-talk key has no effect until restart

**File:** `Sources/SayloApp/Services/DictationHotkeyCoordinator.swift:59-67`, `:95-104`

**Issue:** `.preferencesChanged` calls `ensureTap()`, which returns early whenever a tap already exists:

```swift
private func ensureTap() {
    guard !hotkeyMonitor.isRunning else { return }
    let ok = hotkeyMonitor.start(config: preferencesStore.hotkey, ...)
```

`HotkeyMonitor.updateConfig(_:handsFree:)` — the method that would apply the new config — has **zero call sites**. The settings picker therefore writes the preference, posts the notification, and nothing consumes it.

**Fix:** On `.preferencesChanged`, call `hotkeyMonitor.updateConfig(preferencesStore.hotkey, handsFree: preferencesStore.handsFreeEnabled)` when the tap is already running.

---

### WR-02: The Right Option hotkey can never fire

**File:** `Sources/SayloApp/Services/HotkeyMonitor.swift:126-142`

**Issue:** Right Option is a modifier key. macOS delivers modifier transitions as `.flagsChanged`, never as `.keyDown`/`.keyUp`. The code only handles `rightOption` inside the `.keyDown`/`.keyUp` branches, while the `.flagsChanged` branch is hard-gated to `config == .fn`:

```swift
case .flagsChanged:
    ...
    if config == .fn { ... }          // rightOption ignored here
case .keyDown:
    if config == .rightOption && ...  // never reached for a modifier
```

Selecting "Right Option (⌥)" in Settings silently disables dictation entirely.

**Fix:** Handle both configs in `.flagsChanged`, using the event's keycode:

```swift
case .flagsChanged:
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let pressed: Bool
    switch config {
    case .fn:         pressed = flags.contains(.maskSecondaryFn)
    case .rightOption: guard keycode == 0x3D else { return Unmanaged.passUnretained(event) }
                       pressed = flags.contains(.maskAlternate)
    }
    ...
```

---

### WR-03: Hands-free (double-tap) mode cannot work as designed

**File:** `Sources/SayloApp/Services/DictationHotkeyCoordinator.swift:108-117`, `Sources/SayloApp/Services/HotkeyMonitor.swift:151-177`

**Issue:** A double-tap is two press/release pairs. The state machine is:

1. press #1 → `.keyDown` → `startRecording()` → state `.recording`
2. release #1 → `.keyUp` → `stopRecording()` → state `.transcribing`
3. press #2 → `.doubleTap` → `toggleHandsFree()` → case `.transcribing, .inserting: break`

So the first tap starts *and stops* the recording, and the second tap is swallowed because transcription is already running. The "Hands-Free Mode" toggle in Settings, the "Double-tap Fn" copy in the menu bar, and the `handsFree` plumbing all describe a feature that never engages.

**Fix:** Defer the key-up action long enough to see whether a second press arrives, or track a `handsFreeLatched` flag so `.keyUp` only stops when the session was not started by a double-tap:

```swift
case .keyUp:
    if dictationController.handsFreeActive { return }
    dictationController.stopRecording()
```

---

### WR-04: The event tap over-retains every system event

**File:** `Sources/SayloApp/Services/HotkeyMonitor.swift:148`

**Issue:** The callback returns `Unmanaged.passRetained(event)`. The event is owned by the system for the duration of the callback; the conventional contract is to hand the same reference back unretained. `passRetained` adds an unbalanced +1 for **every keystroke and modifier change in the session**, so memory grows for as long as the app runs with Accessibility granted.

**Fix:**

```swift
return Unmanaged.passUnretained(event)
```

Confirm with an Instruments Allocations trace over a few minutes of typing.

---

### WR-05: Dictionary entries are fed to the post-processor as raw regex source

**File:** `Sources/SayloApp/Services/DictationController.swift:178-183`

**Issue:** `correctionPairs` already contains regex patterns (e.g. `\bClaude\ Code\b`), but they are passed as the *literal* "from" strings of `TextPostProcessor`:

```swift
let postProcessor = TextPostProcessor(
    replacements: dictionaryStore.correctionPairs.reduce(into: [:]) { $0[$1.pattern] = $1.replacement },
    ...
)
```

`TextPostProcessor.process` then escapes them again (`NSRegularExpression.escapedPattern(for: from)`) and wraps them in `\b`, producing `\b\\bClaude\\ Code\\b\b`, which can never match — so the second correction pass is dead. Worse, `applyPhoneticCorrections` builds a Double Metaphone index from those same backslash-laden strings, so the phonetic map is keyed by garbage; any ordinary word whose metaphone happens to collide gets rewritten with a dictionary replacement.

**Fix:** Pass plain phrases, not patterns:

```swift
replacements: Dictionary(uniqueKeysWithValues:
    dictionaryStore.entries.filter { $0.isEnabled && $0.type == .correction }
        .compactMap { e in e.replacement.map { (e.phrase, $0) } })
```

and let `applyCorrections` be the single owner of regex construction.

---

### WR-06: Fabricated metrics and hardcoded personal data in shipped UI

**File:** `Sources/SayloApp/UI/MainWindow.swift:366`, `:648`, `:656`, `:675`, `:687`, `:749`, `:759`, `:761`; `SettingsWindow.swift:62-66`, `:286`; `MenuBarView.swift:57`; `DictionaryWindow.swift:186`, `:267-288`

**Issue:** Several values are presented as measurements but are constants:

| Shown | Reality |
|---|---|
| "Welcome back, Mahesh" | hardcoded name |
| "Top 4%" | hardcoded string |
| "↗ 1.4K% this month" | hardcoded string |
| `SayloProgressBar(value: 0.78)` / `0.82` | hardcoded |
| `wpm` → `95` when there is no data | hardcoded fallback |
| `dictionaryFixes` → `0` | always zero |
| `scriptsEquivalent` → `max(1, totalWords / 4500)` | minimum of 1 script even with 0 words |
| "MacBook Air Mic" | not the actual input device |
| "biasing weight 1.x" | derived from `sum(unicodeScalars) % 6` |
| "Saylo v1.0.0 (Apple M2)", "Cactus Whistle 16.9 MB" | hardcoded strings |

**Fix:** Compute from stores or remove. Anything that cannot be measured should not be rendered as a measurement — a fabricated "Top 4%" in a productivity app is a credibility problem, not a cosmetic one.

---

### WR-07: The menu bar icon cannot actually be hidden

**File:** `Sources/SayloApp/SayloApp.swift:126`

**Issue:** `showMenuBarIcon` only swaps the symbol name for an empty string:

```swift
Image(systemName: preferencesStore.showMenuBarIcon ? "waveform" : "")
```

`MenuBarExtra` is always present, so the item still occupies menu-bar space (as a blank/placeholder), and an empty SF Symbol name logs a symbol-resolution error on every render. The preference is also not exposed in Settings, so it can only change by editing defaults.

**Fix:** Conditionally include the scene — `if preferencesStore.showMenuBarIcon { MenuBarExtra { ... } }` is not allowed in a `SceneBuilder`, so either use `NSStatusItem` directly or remove the toggle.

---

### WR-08: Menu commands post notifications nobody observes

**File:** `Sources/SayloApp/SayloApp.swift:158-177`; declarations at `SettingsWindow.swift:363-368`

**Issue:** "Open Dictionary" (⌘D) and "Clear History" (⇧⌘⌫) post `.openDictionary` / `.clearHistory`. Grep across `Sources/` shows **no observers** for either. `exportDictionary` and `importDictionary` are declared and never posted or observed at all. Both menu items are inert, and "Clear History" silently fails to do the destructive thing it advertises.

**Fix:** Observe the notifications in `MainWindow` (`onReceive`) and call `historyStore.clearHistory()` / open the dictionary window via `openWindow`; or delete the commands.

---

### WR-09: Three preferences are persisted, rendered, and never read

**File:** `Sources/SayloApp/Stores/PreferencesStore.swift:21`, `:44`, `:59`; `Sources/SayloApp/Stores/JSONStore.swift:54`

**Issue:** `playSounds`, `muteAudioWhileDictating`, and `maxHistoryItems` have Settings toggles (or a stored value) but no consumers:

- `playSounds` — no sound is ever played.
- `muteAudioWhileDictating` — no audio ducking/muting code exists.
- `maxHistoryItems` — `JSONStore.addHistoryEntry` hardcodes `if historyEntries.count > 1000`.

**Fix:** Implement or remove. For `maxHistoryItems`, thread it through: `HistoryStore.addEntry` → `JSONStore.addHistoryEntry(_:limit:)`.

---

### WR-10: A corrupt `store.json` is silently discarded and then overwritten

**File:** `Sources/SayloApp/Stores/JSONStore.swift:23-34`, `:36-47`

**Issue:** `load()` catches a decode failure, logs it, and leaves both arrays empty. The very next mutation calls `save()`, which atomically replaces the (recoverable) corrupt file with an empty store. All history and dictionary entries are permanently lost, and the only trace is a log line.

**Fix:** On decode failure, move the unreadable file aside before continuing:

```swift
catch {
    logger.error("Failed to load store: \(error.localizedDescription)")
    let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
    try? FileManager.default.moveItem(at: fileURL, to: backup)
}
```

---

### WR-11: Clipboard restore races the paste and loses promised types

**File:** `Sources/SayloApp/Services/TextInserter.swift:19-43`

**Issue:** Three problems in one flow:

1. The saved snapshot copies `item.data(forType:)` eagerly. Pasteboard types backed by a *promised* data provider return `nil` here, so those representations are dropped and cannot be restored.
2. The clipboard is restored after a fixed 100 ms regardless of whether the target app finished pasting. A slow app (Electron, remote desktop) can paste the restored content instead of the dictation.
3. If `sendCommandV()` fails (Accessibility revoked mid-session), the method still restores the clipboard and returns normally — the user sees "Pasted" in the pill while nothing was inserted.

**Fix:** Capture `NSPasteboardItem` references (or `readObjects`) instead of raw data, verify insertion by checking the focused element's value or waiting on a paste-completion signal, and surface a failure back to `DictationController` so the state becomes `.error` rather than `.idle`.

---

### WR-12: "Re-insert" pastes into Saylo itself

**File:** `Sources/SayloApp/Services/DictationController.swift:132-137`; call sites `MainWindow.swift:452`, `:500`

**Issue:** `reinsert(_:)` is triggered by a button/context menu inside Saylo's window. `TextInserter.insert` sends ⌘V to whatever is frontmost — which is Saylo, because the user just clicked it. The text is pasted into the app's own UI (or nowhere, if no text field is focused) instead of the app the user was dictating into.

**Fix:** Record the previously frontmost application when the row is clicked, re-activate it before pasting, or restrict re-insert to "copy to clipboard" and let the user paste.

---

### WR-13: The heatmap month labels never render

**File:** `Sources/SayloApp/UI/MainWindow.swift:887-903`

**Issue:**

```swift
return grid.enumerated().map { index, column in
    defer { lastLabelledColumn = index }
    guard index - lastLabelledColumn >= minimumColumnGap else { return nil }
    ...
}
```

`defer` runs on **every** exit, including the early `return nil`, so `lastLabelledColumn` is set to the current index each iteration. On the next pass `index - lastLabelledColumn == 1`, which always fails the `>= 3` gap check. After the first column, no label can ever be produced.

**Fix:** Only update the marker when a label is actually emitted:

```swift
guard index - lastLabelledColumn >= minimumColumnGap else { return nil }
guard let first = column.compactMap({ $0 }).first?.date else { return nil }
guard let previous = cal.date(byAdding: .day, value: -7, to: first),
      cal.component(.month, from: previous) != cal.component(.month, from: first) else { return nil }
lastLabelledColumn = index
return f.string(from: first)
```

---

### WR-14: The pill's waveform timer is never invalidated; hide/show can race

**File:** `Sources/SayloApp/UI/FloatingPill.swift:193-205`, `:75-80`

**Issue:** `recordingView.onAppear` calls `startWaveformAnimation()`, which creates a **repeating `Timer` that is never invalidated**. Every time the recording view appears a new timer is added, and each one ticks for the lifetime of the process, mutating `@State` on a view that may not be on screen.

Separately, `hide()` schedules an uncancellable `orderOut` 0.3 s later. If a new recording starts inside that window, `show()` runs, and the pending `orderOut` then hides the pill mid-recording. (`reflect()` cancels its own `DispatchWorkItem`, but not the one inside `hide()`.)

**Fix:** Drive the animation with `TimelineView(.animation)` (as `WaveformLoader` already does) instead of a timer, and make `hide()` cancellable — store the pending work item on the panel and cancel it in `show()`.

---

### WR-15: The pill ignores the screen origin and hardcodes the hotkey label

**File:** `Sources/SayloApp/UI/FloatingPill.swift:52-68`, `:243-245`

**Issue:** Positions are computed from `screen.visibleFrame.width/height` but applied as absolute origins without adding `visibleFrame.minX/minY`. On a secondary display (or any arrangement where the main screen is not at the origin) the pill appears on the wrong monitor, often off-screen.

`hotkeyDisplay` returns the literal `"fn"`, so the pill says "Saylo Ready · fn" even when Right Option is configured.

**Fix:**

```swift
let f = screen.visibleFrame
newOrigin = CGPoint(x: f.minX + (f.width - frame.width) / 2, y: f.minY + 60)
```

and pass the configured hotkey into `PillContent` instead of the constant.

---

### WR-16: Recorder buffer is unbounded; file loader fails silently

**File:** `Sources/SayloCore/AudioRecorder.swift:61-64`, `:93-109`

**Issue:** `self.buffer.append(contentsOf: samples)` grows without limit for the whole recording — a forgotten hands-free session accumulates 16 kHz floats indefinitely (≈230 MB/hour) with no cap, warning, or auto-stop. `WhistleEngine.maxSamples` exists (30 s) but is never used.

`load(url:)` returns `[]` — indistinguishable from silence — when the converter cannot be created or the output buffer allocation fails, and then force-unwraps `out.floatChannelData![0]`. Callers (`saylo-cli`, tests) treat `[]` as "no speech".

**Fix:** Cap capture (`if buffer.count > maxSamples { … auto-stop … }`), throw a typed error from `load`, and guard `floatChannelData` before subscripting.

---

### WR-17: Engine output is read without a bounds guarantee

**File:** `Sources/SayloCore/WhistleEngine.swift:59-71`

**Issue:** A 64 KB `[CChar]` buffer is passed to `needle_transcribe`, and the result is read with

```swift
let json = out.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
```

There is no check that the engine NUL-terminated within capacity (or that `rc < capacity`). If a long transcript or an engine change fills the buffer, `String(cString:)` reads past the allocation — undefined behaviour in a memory-safe language. The `baseAddress!` is also unguarded.

**Fix:** Verify the return code against capacity and find the terminator explicitly:

```swift
let end = out.firstIndex(of: 0) ?? out.count
let json = String(decoding: out[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
```

---

### WR-18: Tests pass vacuously when `vendor/` is absent, and the bug classes above are untested

**File:** `Tests/SayloCoreTests/SayloCoreTests.swift:133-145`, `:150-156`

**Issue:** Both integration tests `return` early (i.e. pass) when `vendor/whistle.cact` or `vendor/test.wav` is missing — and `vendor/` is `.gitignore`d, so on CI/fresh clones these are green no-ops. There is no coverage at all for `DictionaryStore.applyCorrections` (CR-01), `TextPostProcessor` fed regex patterns (WR-05), `AudioChunker` with non-default parameters, or the hotkey state machine.

**Fix:** Use `#require` / `XCTSkip` so a missing fixture is reported as skipped rather than passed, and add a `DictionaryStoreTests` target with a self-replacement regression test.

---

### WR-19: All dictation text is stored unencrypted, forever

**File:** `Sources/SayloApp/Stores/JSONStore.swift:15-20`, `:99-107`

**Issue:** Every transcription — plus its raw pre-correction text, the frontmost app's bundle ID, and timestamps — is written in plaintext to `~/Library/Application Support/Saylo/store.json`. There is no encryption, no retention policy (WR-09), no "don't save history" option, and no delete-on-quit. For a product whose selling point is "100% local", local plaintext is still readable by any process running as the user, by backups, and by anything that syncs Application Support.

**Fix:** At minimum document the storage location and add a "Clear history on quit" / "Don't store history" preference; ideally protect the file with `FileProtection`-equivalent permissions (0600) and consider encrypting with a Keychain-held key.

---

### WR-20: The recorded destination app can be wrong

**File:** `Sources/SayloApp/Services/DictationController.swift:177`, `:204`

**Issue:** `getFrontmostAppBundleID()` is called twice — once before post-processing (for code-context formatting) and again after `textInserter.insert(...)` to build the history entry. After a paste, focus may have moved (or Saylo may be frontmost), so the stored `appBundleID` can describe the wrong app, corrupting the "Where you dictate" insights.

**Fix:** Capture once at the start of `transcribeAndInsert` and reuse the value.

---

### WR-21: Editing an entry's type double-writes and cannot clear a replacement

**File:** `Sources/SayloApp/UI/DictionaryWindow.swift:172-181`; `Sources/SayloApp/Stores/DictionaryStore.swift:45-63`

**Issue:** When the type changes, the sheet handler calls `updateEntry` and *then* deletes and re-adds:

```swift
dictionaryStore.updateEntry(entry, phrase: phrase, replacement: replacement)
if entry.type != type {
    dictionaryStore.deleteEntry(entry)
    dictionaryStore.addEntry(phrase: phrase, replacement: replacement, type: type)
}
```

That is two `store.json` writes plus a transient duplicate, and the new entry gets a fresh `id`/`createdAt` (breaking any identity-based UI state). Additionally `updateEntry(replacement:)` is `String?` where `nil` means "leave unchanged", so converting a `.correction` to a `.word` can never clear the stored replacement through the normal path.

**Fix:** Add a single `replaceEntry(_:with:)` store method that performs one write and preserves the id, and give `updateEntry` an explicit tri-state for replacement (`enum FieldUpdate<T> { case unchanged, clear, set(T) }` or a separate `clearReplacement()`).

---

## Info

### IN-01: Dead code inventory

| Symbol | Location | Note |
|---|---|---|
| `Preferences` struct | `Models.swift:129-167` | Never constructed; `PreferencesStore` uses `@AppStorage` |
| `HotkeyMonitor.updateConfig` | `HotkeyMonitor.swift:93-100` | Zero call sites (see WR-01) |
| `PermissionsManager.allPermissionsGranted` | `PermissionsManager.swift:58-60` | Never read |
| `DictionaryStore.export()`, `importFrom`, `ExportFormat`, `ExportEntry` | `DictionaryStore.swift:255-318` | Entire export/import feature unreachable |
| `SayloSerifHeroCard` | `DesignSystem.swift:613-657` | Unused view |
| `EntryStats.duration` | `MainWindow.swift:1036-1040` | Unused |
| `DictionaryEntry.displayText`, `keywordForBiasing` | `Models.swift:100-111` | Unused |
| `WhistleEngine.maxSamples` | `WhistleEngine.swift:26` | Declared, never enforced (see WR-16) |
| `HistoryStore.selectedEntry` | `HistoryStore.swift:13` | Never set or read |
| `FocusedValue selectedEntry` | `SayloApp.swift:145`, `:203-212` | `setFocusedValue` never called anywhere |
| `WidgetRail.onViewReport` | `MainWindow.swift:414`, `:538` | Passed `{}`, never invoked |
| `WaveformLoaderDemo` + `#Preview` | `WaveformLoader.swift:72-92` | Demo view compiled into the shipping target |
| `SettingsWindow.dismiss` | `SettingsWindow.swift:8` | Never used |
| `AudioChunker.sampleRate` defaults | `AudioChunker.swift:4-5` | Fine, but untested with non-defaults |

### IN-02: Buttons wired to nothing

- `AppCommands` "Show History" — empty action body (`SayloApp.swift:158-163`).
- `InsightsContentView` clock button — `Button {}` (`MainWindow.swift:610`).
- Dictionary toolbar magnifier and up/down arrows are `Image`s, not buttons (`DictionaryWindow.swift:91-96`) — they look interactive and are not.
- `MenuBarView` `.keyboardShortcut(",")` inside a popover has no effect (`MenuBarView.swift:96`).

### IN-03: Redundant initialization

- `AddEditEntrySheet.init` assigns `_type` twice (`DictionaryWindow.swift:310`, `:314`).
- `SayloApp.init` instantiates a throwaway `JSONStore()` (and `PermissionsManager`, `HotkeyMonitor`) via property defaults, then replaces all of them with freshly constructed instances — two file loads and two permission probes at launch (`SayloApp.swift:10-16`, `:34-57`).
- `PermissionsManager.requestMicrophonePermission` wraps `await MainActor.run` inside an already-`@MainActor` type (`PermissionsManager.swift:30-32`).

### IN-04: Misplaced imports and odd declarations

- `import AVFoundation` at the bottom of `PermissionsManager.swift:64`.
- `FloatingPillPanel` declares `private var hostingView: NSHostingView<PillContent>` where `PillContent` is `private` — legal but makes the public panel unusable from outside its file (`FloatingPill.swift:8-9`).

### IN-05: `PillContent.update` is a mutating method on a view

**File:** `Sources/SayloApp/UI/FloatingPill.swift:254-258`

`mutating func update(...)` is called on `hostingView?.rootView.update(...)`. It relies on `@State` setters from outside the view body and on write-back of a value-type root view. It happens to work, but it is fragile; a small `@Observable` model (or passing the state through the initializer and letting SwiftUI diff) is the supported pattern.

### IN-06: `Package.swift` and build ergonomics

- `.unsafeFlags(["-Lvendor/macos-arm64"])` is a **relative** linker path, so `swift build` only works from the repo root and the package can never be consumed as a dependency (`Package.swift:16-20`).
- `vendor/` is gitignored, so a fresh clone cannot build until `scripts/setup.sh` runs; the CI workflow does this, but the README does not (`README.md` is 8 bytes).
- `.unsafeFlags` on library targets also disables the `swift build` cache in some toolchain versions.

### IN-07: Bogus `Info.plist` keys

`NSAccessibilityUsageDescription` and `NSAppSleepDisabled` (`Sources/SayloApp/Resources/Info.plist`) are not recognised keys. Accessibility has no usage-description requirement, and app-nap suppression is not controlled this way; both are silently ignored.

### IN-08: Signing and CI hardening

- `scripts/bundle.sh` signs ad-hoc with `codesign --deep` (deprecated for distribution) and no hardened-runtime flag or entitlements; there is no `.entitlements` file in the repo.
- The script copies Swift runtime dylibs out of the Xcode toolchain; the macOS runtime lives in `/usr/lib/swift` on the target OS, so this mostly duplicates binaries and inflates the bundle.
- `.github/workflows/*.yml` pins `actions/checkout@v4`, `swift-actions/setup-swift@v2`, `actions/upload-artifact@v4`, `softprops/action-gh-release@v2` by mutable tag rather than commit SHA.

### IN-09: Silent failure in the design system

- `colorFromHex` returns a fully transparent colour for malformed input instead of asserting (`DesignSystem.swift:246-248`).
- `CTFontManagerRegisterFontsForURL`'s return value is discarded, so a font that fails to register produces only the silent system-font fallback the comment warns about (`DesignSystem.swift:46-50`).
- `bundledFontURLs()` recursively enumerates the entire app bundle (including nested frameworks) at launch to find `Fonts` directories — unnecessary I/O on the main thread (`DesignSystem.swift:52-93`).

### IN-10: `AudioChunker` can loop forever with custom parameters

**File:** `Sources/SayloCore/AudioChunker.swift:4-27`

With `searchSeconds >= maxSeconds`, `lo` can fall before `start`, `bestCut` can be less than `start`, and `start = bestCut` walks backwards — an infinite loop. Defaults (5 s / 30 s) are safe; the public signature allows the bad case.

### IN-11: `EntryStats.appName` is wrong and expensive

**File:** `Sources/SayloApp/UI/MainWindow.swift:1042-1048`

`($0 as NSString).lastPathComponent` on a bundle identifier returns the whole identifier (`lastPathComponent` splits on `/`, not `.`). It also calls `NSRunningApplication.runningApplications(withBundleIdentifier:)` for every entry on every render of the insights view.

### IN-12: Misleading CLI message

**File:** `Sources/SayloCLI/main.swift:18-31`

`report` runs `engine.transcribe` *before* checking `gated`, then prints "(silence — below the speech threshold, model not run)". The model call did happen (it short-circuits on empty input). Move the `gated` check above the transcription call or reword the message.

### IN-13: `wasSilent` is read outside its lock

**File:** `Sources/SayloCore/AudioRecorder.swift:15`, `:74-89`; read at `DictationController.swift:103`

`wasSilent` is written inside `lock.withLock` but read without it. Benign in practice (the tap is removed before the read), but it is a data race under the Swift memory model and will be flagged by strict concurrency checking.

### IN-14: No lint/format configuration

There is no `.swiftlint.yml`, `.swift-format`, or editor config. Given the file sizes (`MainWindow.swift` 1084 lines, `DesignSystem.swift` 777, `SettingsWindow.swift` 413) a formatter plus a "no file over ~500 lines" rule would have surfaced several of the structural issues above.

---

## Cross-cutting assessment

**Security.** No injection sinks, no network I/O, no `eval`, no hardcoded credentials, no dynamic code loading. The risk surface is inherent to the product rather than a defect: an active `CGEventTap` plus synthetic ⌘V requires Accessibility, which is effectively full input control. Two privacy issues are worth product decisions rather than code fixes: plaintext transcript storage (WR-19) and clipboard full-content copy/restore (WR-11). The absence of an entitlements file and hardened runtime (IN-08) matters the day this ships outside a developer machine.

**Error handling.** The dominant pattern is "log and continue" — `JSONStore.load`, `AudioRecorder.load`, `TextInserter.insert`, `PreferencesStore.updateLoginItem`, `CTFontManagerRegisterFontsForURL`. In a dictation app the user's only feedback channel is the floating pill, and none of these failures reach it. WR-11 is the sharpest example: the pill says "Pasted" when nothing was pasted.

**State machine.** The hotkey/dictation interaction (WR-01, WR-02, WR-03) is the weakest area. Hold-to-talk works; every other advertised mode (right option, hands-free, changing the key at runtime) does not. This deserves a small explicit state machine with tests rather than ad-hoc `guard` chains across two objects.

## Suggested fix order

1. **CR-01** — app hang. One-line guard + loop rewrite; add a regression test.
2. **CR-02** — missing environment object; add `.environmentObject(permissionsManager)` at both sheet sites.
3. **CR-05** — destructive ellipsis button; replace with a menu or confirmation.
4. **CR-03 / CR-04** — replace `fatalError` with recoverable errors; harden the audio tap lifecycle.
5. **WR-01/02/03** — rebuild the hotkey state machine; this is the difference between a demo and a usable app.
6. **WR-05 / WR-10 / WR-09** — correctness and data-integrity in the store layer.
7. **WR-06 / WR-07 / WR-08 / IN-02** — remove or wire the inert UI; fabricated metrics should not ship.

---

_Reviewed: 2026-11-09_
_Reviewer: gsd-code-reviewer (deep pass, whole repository)_
_Depth: deep_
