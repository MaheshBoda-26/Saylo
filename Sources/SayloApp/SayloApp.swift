import SwiftUI
import SayloCore
import DesignSystem

@main
struct SayloApp: App {
    // Core services
    // NOTE: audioRecorder / whistleEngine / textInserter are owned by
    // DictationController — do not also hold StateObject copies here.
    // JSONStore and HotkeyMonitor are deliberately absent too: they are
    // retained by the stores and the coordinator below, and a second
    // StateObject copy would only create a second, unused instance.
    @StateObject private var dictionaryStore: DictionaryStore
    @StateObject private var historyStore: HistoryStore
    @StateObject private var preferencesStore: PreferencesStore
    @StateObject private var permissionsManager: PermissionsManager
    @StateObject private var dictationController: DictationController

    /// Closes the hotkey → dictation → floating-pill loop.
    /// Retained by this struct (SwiftUI creates the App once) and owns the
    /// HotkeyMonitor.
    private let hotkeyCoordinator: DictationHotkeyCoordinator

    init() {
        // Inter / Instrument Serif / Geist Mono must be registered before any
        // view resolves DesignSystem.Typography.*, otherwise every custom font
        // silently falls back to the system face.
        DesignSystem.registerBundledFonts()

        // Initialize stores (single shared instances)
        let jStore = JSONStore()
        let dictStore = DictionaryStore(jsonStore: jStore)
        let histStore = HistoryStore(jsonStore: jStore)
        let pStore = PreferencesStore()
        let perms = PermissionsManager()
        let monitor = HotkeyMonitor()

        // A missing or unreadable model used to terminate the app with no
        // window and no explanation. Keep the UI alive and report it instead.
        let engine: WhistleEngine?
        let startupError: String?
        if let modelURL = Self.locateModel() {
            do {
                engine = try WhistleEngine(modelURL: modelURL)
                startupError = nil
            } catch {
                engine = nil
                startupError = "The speech model could not be loaded: \(error.localizedDescription)"
            }
        } else {
            engine = nil
            startupError = "The speech model (whistle.cact) is missing from the app bundle."
        }

        // Initialize dictation controller
        let dController = DictationController(
            audioRecorder: AudioRecorder(),
            whistleEngine: engine,
            textInserter: TextInserter(),
            dictionaryStore: dictStore,
            historyStore: histStore,
            preferencesStore: pStore,
            startupError: startupError
        )

        self._dictionaryStore = StateObject(wrappedValue: dictStore)
        self._historyStore = StateObject(wrappedValue: histStore)
        self._preferencesStore = StateObject(wrappedValue: pStore)
        self._permissionsManager = StateObject(wrappedValue: perms)
        self._dictationController = StateObject(wrappedValue: dController)

        self.hotkeyCoordinator = DictationHotkeyCoordinator(
            dictationController: dController,
            preferencesStore: pStore,
            permissionsManager: perms,
            hotkeyMonitor: monitor
        )

        // Warm up the engine
        if let engine {
            Task {
                try? await engine.warmUp()
            }
        }
    }

    /// Bundle first: a Finder-launched `.app` has `/` as its working directory,
    /// so the relative path only helps `swift run` from the package root.
    private static func locateModel() -> URL? {
        if let bundled = Bundle.main.url(forResource: "whistle", withExtension: "cact") {
            return bundled
        }
        let local = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("vendor/whistle.cact")
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    var body: some Scene {
        // Main window
        WindowGroup {
            MainWindow()
                .environmentObject(dictationController)
                .environmentObject(historyStore)
                .environmentObject(dictionaryStore)
                .environmentObject(preferencesStore)
                .environmentObject(permissionsManager)
                .task {
                    hotkeyCoordinator.activate()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 840)
        .commands {
            AppCommands(
                dictationController: dictationController,
                preferencesStore: preferencesStore
            )
        }

        // Dictionary window
        WindowGroup("Dictionary", id: "dictionary") {
            DictionaryWindow()
                .environmentObject(dictionaryStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 500)

        // Menu bar extra — `isInserted` removes the item from the menu bar
        // entirely when the user turns it off, rather than leaving a blank slot.
        MenuBarExtra(isInserted: Binding(
            get: { preferencesStore.showMenuBarIcon },
            set: { preferencesStore.showMenuBarIcon = $0 }
        )) {
            MenuBarView()
                .environmentObject(dictationController)
                .environmentObject(preferencesStore)
                .environmentObject(historyStore)
                .environmentObject(dictionaryStore)
                .environmentObject(permissionsManager)
        } label: {
            Image(systemName: "waveform")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(
                    dictationController.state == .recording ? DesignSystem.Color.danger :
                    dictationController.state.isActive ? DesignSystem.Color.accent :
                    DesignSystem.Color.ink
                )
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Commands

struct AppCommands: Commands {
    // NOTE: Commands do NOT inherit .environmentObject() modifiers applied to a
    // Scene's content, so these are injected explicitly by SayloApp.body.
    let dictationController: DictationController
    let preferencesStore: PreferencesStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .newItem) {
            Button("New Dictation") {
                dictationController.startRecording()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(dictationController.state.isActive)
        }

        CommandGroup(after: .sidebar) {
            Button("Open Dictionary") {
                NotificationCenter.default.post(name: .openDictionary, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command])

            Divider()

            Button("Clear History") {
                NotificationCenter.default.post(name: .clearHistory, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }

        CommandMenu("Dictation") {
            Button("Start/Stop") {
                switch dictationController.state {
                case .idle, .error:
                    dictationController.startRecording()
                case .recording:
                    dictationController.stopRecording()
                default:
                    break
                }
            }
            .keyboardShortcut(" ", modifiers: [.command])

            Button("Cancel") {
                dictationController.cancelRecording()
            }
            .keyboardShortcut(.escape)
            .disabled(dictationController.state != .recording)
        }
    }
}
