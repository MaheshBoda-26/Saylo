import SwiftUI
import SayloCore
import DesignSystem

@main
struct SayloApp: App {
    // Core services
    // NOTE: audioRecorder / whistleEngine / textInserter are owned by
    // DictationController — do not also hold StateObject copies here.
    @StateObject private var jsonStore = JSONStore()
    @StateObject private var dictionaryStore: DictionaryStore
    @StateObject private var historyStore: HistoryStore
    @StateObject private var preferencesStore = PreferencesStore()
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var dictationController: DictationController
    @StateObject private var hotkeyMonitor = HotkeyMonitor()

    /// Closes the hotkey → dictation → floating-pill loop.
    private let hotkeyCoordinator: DictationHotkeyCoordinator

    init() {
        // Initialize WhistleEngine with bundled model
        let modelURL = Bundle.main.url(forResource: "whistle", withExtension: "cact") ??
                      URL(fileURLWithPath: "vendor/whistle.cact")
        do {
            let engine = try WhistleEngine(modelURL: modelURL)

            // Initialize stores (single shared instances)
            let jStore = JSONStore()
            let dictStore = DictionaryStore(jsonStore: jStore)
            let histStore = HistoryStore(jsonStore: jStore)
            let pStore = PreferencesStore()
            let perms = PermissionsManager()
            let monitor = HotkeyMonitor()

            // Initialize dictation controller
            let dController = DictationController(
                audioRecorder: AudioRecorder(),
                whistleEngine: engine,
                textInserter: TextInserter(),
                dictionaryStore: dictStore,
                historyStore: histStore,
                preferencesStore: pStore
            )

            self._jsonStore = StateObject(wrappedValue: jStore)
            self._dictionaryStore = StateObject(wrappedValue: dictStore)
            self._historyStore = StateObject(wrappedValue: histStore)
            self._preferencesStore = StateObject(wrappedValue: pStore)
            self._permissionsManager = StateObject(wrappedValue: perms)
            self._hotkeyMonitor = StateObject(wrappedValue: monitor)
            self._dictationController = StateObject(wrappedValue: dController)

            self.hotkeyCoordinator = DictationHotkeyCoordinator(
                dictationController: dController,
                preferencesStore: pStore,
                permissionsManager: perms,
                hotkeyMonitor: monitor
            )

            // Warm up the engine
            Task {
                try? await engine.warmUp()
            }

        } catch {
            fatalError("Failed to initialize Saylo: \(error)")
        }
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
                    await hotkeyCoordinator.activate()
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

        // Settings window (Cmd+,)
        WindowGroup("Settings", id: "settings") {
            SettingsWindow()
                .environmentObject(preferencesStore)
                .environmentObject(historyStore)
                .environmentObject(dictionaryStore)
                .environmentObject(permissionsManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 550)

        // Dictionary window
        WindowGroup("Dictionary", id: "dictionary") {
            DictionaryWindow()
                .environmentObject(dictionaryStore)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 500)

        // Menu bar extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(dictationController)
                .environmentObject(preferencesStore)
                .environmentObject(historyStore)
                .environmentObject(dictionaryStore)
        } label: {
            Image(systemName: preferencesStore.showMenuBarIcon ? "waveform" : "")
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
    @FocusedValue(\.selectedEntry) private var selectedEntry: DictationEntry?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .newItem) {
            Button("New Dictation") {
                dictationController.startRecording()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(dictationController.state.isActive)
        }

        CommandGroup(before: .sidebar) {
            Button("Show History") {
                // Focus main window
            }
            .keyboardShortcut("1", modifiers: [.command])
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

// MARK: - Focused Values

private struct SelectedEntryKey: FocusedValueKey {
    typealias Value = DictationEntry
}

extension FocusedValues {
    var selectedEntry: DictationEntry? {
        get { self[SelectedEntryKey.self] }
        set { self[SelectedEntryKey.self] = newValue }
    }
}

