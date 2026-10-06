# Saylo — Push-to-Talk Dictation for macOS (Wispr Flow clone)

## What we're cloning
Wispr Flow: hold a hotkey (Fn) anywhere → speak → release → cleaned-up text is typed into
whatever app has focus. Menu-bar app, floating "listening" pill, personal dictionary, history.
Saylo does the same, but **100% on-device** using Cactus **Whistle** (released 2026-10-02).

## Machine
Apple **M2, 8 GB RAM**, macOS 27.0.1, Swift 6.4 (Command Line Tools only — **no full Xcode**).
→ Whistle is perfect here: 16.9 MB, CPU-only, ~11 ms time-to-first-token for 10 s audio.
→ Avoid Electron/Python runtimes for the shipped app (RAM + latency + permissions pain).

## Whistle facts (from cactuscompute.com/blog/whistle)
- Input: 16 kHz mono, **max 30 s per pass**. Langs: en, de, fr, es, it, nl, pl (auto-detect or forced).
- Features: word timestamps, **keyword biasing** (custom vocab), silence → empty transcript.
- Distribution: `needle download macos-arm64` → `needle` binary, `libneedle.a`, `needle.h`;
  `needle download whistle` → `whistle.cact`. C API: `needle_load`, `needle_transcribe`, `needle_embed`.
- Python: `pip install cactus-needle` → `needle.transcribe("clip.wav")` (good for quick validation).

## Recommended architecture: native Swift, in-process C engine

```
 Hotkey (CGEventTap: hold Fn / Right-⌥) ──► DictationController (state machine)
                                              │ idle → recording → transcribing → inserting
 AVAudioEngine mic tap → resample 16k mono ──►│ Float32 ring buffer
                                              ▼
                     WhistleEngine (Swift wrapper over libneedle.a / needle.h, model loaded once)
                                              ▼
                     TextPostProcessor (spacing, capitalization, dictionary replacements)
                                              ▼
                     TextInserter (pasteboard save → Cmd+V via CGEvent → restore clipboard)
 UI: SwiftUI MenuBarExtra + floating NSPanel "pill" with live waveform + Settings window
```
- **SwiftPM** project (builds with CLT, no Xcode needed); `CNeedle` system-library target wraps `needle.h`.
- `scripts/bundle.sh` assembles `Saylo.app` (Info.plist, mic usage string, icon, ad-hoc codesign).
- >30 s dictation: split on silence near 25–30 s windows and concatenate.
- Permissions: Microphone, Accessibility (event tap + synthetic paste).

## Plan
### Phase 0 — Validate the model (≈15 min)
- [ ] `pip install cactus-needle` in `.venv`; transcribe a test WAV; record latency on M2
- [ ] `needle download macos-arm64` + `needle download whistle`; inspect `needle.h` signatures

### Phase 1 — Skeleton (CLI, proves the pipeline)
- [ ] SwiftPM package `Saylo` with targets `CNeedle`, `SayloCore`, `saylo-cli`
- [ ] `WhistleEngine`: load `.cact` once, `transcribe([Float]) -> (text, lang, ms)`
- [ ] `AudioRecorder`: AVAudioEngine → 16 kHz mono Float32
- [ ] CLI: press Enter to start/stop → prints transcript + timing
- [ ] Verify: end-to-end latency < 300 ms for a 5 s utterance

### Phase 2 — Real push-to-talk app
- [ ] Menu-bar app (`MenuBarExtra`, LSUIElement), global hold-to-talk hotkey via CGEventTap
- [ ] TextInserter (paste into focused app, clipboard restore)
- [ ] Permission onboarding (Mic + Accessibility) with deep links to System Settings
- [ ] Floating pill overlay with live level meter; start/stop sounds
- [ ] `.app` bundling script + ad-hoc signing; launch at login

### Phase 3 — Polish & "Flow"-like features
- [ ] Custom dictionary → Whistle `keywords` biasing + replacements
- [ ] History window (searchable, copy again); language selector
- [ ] Hands-free mode (double-tap hotkey to lock), >30 s chunking
- [ ] Optional cleanup pass (filler-word removal; later Needle/LLM rewrite)

### Phase 4 — Branding
- [ ] Saylo identity: logo/app icon, palette, wordmark, pill animation, onboarding screens

## Review
_(filled in after implementation)_
