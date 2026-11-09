# Saylo

Push-to-talk dictation for macOS. Hold a key anywhere, speak, release — the
cleaned-up text lands at your cursor. Speech recognition runs entirely on your
Mac with Cactus **Whistle**, so audio never leaves the machine.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.0 toolchain (the package declares `swift-tools-version:6.0`)
- Xcode 16 **or** the standalone Swift 6 toolchain — `#Preview` macros are not
  used anywhere, so Command Line Tools alone are enough to build

## Setup

The speech model and the static engine library live in `vendor/`, which is not
checked in. Fetch them once:

```sh
./scripts/setup.sh
```

This creates a Python venv, downloads `whistle.cact` and `libneedle.a` for
`macos-arm64`, installs the C header into `Sources/CNeedle/include/`, and
generates `vendor/test.wav` for the integration test.

## Build and run

```sh
swift build                 # both executables
swift run Saylo             # the app (grant mic + Accessibility when asked)
swift run saylo-cli --file vendor/test.wav
```

Build a double-clickable app bundle:

```sh
./scripts/bundle.sh
open .build/Saylo.app
```

## Permissions

Saylo asks for two:

- **Microphone** — to capture dictation.
- **Accessibility** — to detect the global hotkey and to send ⌘V. Without it the
  hotkey does nothing and text insertion fails with a visible error.

`scripts/bundle.sh` signs ad-hoc with a pinned designated requirement
(`identifier "com.saylo.app"`) so rebuilding does not invalidate the
Accessibility grant.

## Usage

- **Hold Fn** (or Right Option) and speak; release to transcribe and paste.
- **Double-tap** the hotkey to latch hands-free; tap once to stop.
- Change the key, language, pill position, and history retention in Settings.
- The dictionary biases recognition and corrects spellings afterwards.

## Where data lives

Dictation history and dictionary entries are stored in
`~/Library/Application Support/Saylo/store.json` with `0600` permissions. Turn
off **Save dictation history** in Settings to stop writing entries, and
**Clear History** (⇧⌘⌫) to delete them.

## Tests

```sh
swift test
```

The integration tests need `vendor/whistle.cact` and `vendor/test.wav`; they are
reported as skipped, not passed, when those files are missing.

## Layout

```
Sources/CNeedle    C shim + header for the Whistle engine
Sources/SayloCore  audio capture, chunking, correction engine, text cleanup
Sources/SayloApp   SwiftUI app: windows, stores, services
Sources/SayloCLI   record → transcribe → clean pipeline, for development
```
