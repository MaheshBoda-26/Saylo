import Foundation
import AppKit
import SayloCore
import os.log

/// Controls the dictation state machine and coordinates all components.
@MainActor
public final class DictationController: ObservableObject {
    private let logger = Logger(subsystem: "com.saylo", category: "DictationController")

    // Dependencies
    private let audioRecorder: AudioRecorder
    private let whistleEngine: WhistleEngine
    private let textInserter: TextInserter
    private let dictionaryStore: DictionaryStore
    private let historyStore: HistoryStore
    private let preferencesStore: PreferencesStore

    // State
    @Published public private(set) var state: DictationState = .idle
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var recordingDuration: TimeInterval = 0
    @Published public private(set) var lastError: String?

    // Timer for updating duration
    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    // Audio recording
    private var currentRecording: [Float] = []

    // State machine
    public enum DictationState: Equatable, Sendable {
        case idle
        case recording
        case transcribing
        case inserting
        case error(String)

        public var isActive: Bool {
            switch self {
            case .idle, .error: return false
            case .recording, .transcribing, .inserting: return true
            }
        }

        public var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .recording: return "Recording"
            case .transcribing: return "Transcribing"
            case .inserting: return "Inserting"
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    public init(
        audioRecorder: AudioRecorder,
        whistleEngine: WhistleEngine,
        textInserter: TextInserter,
        dictionaryStore: DictionaryStore,
        historyStore: HistoryStore,
        preferencesStore: PreferencesStore
    ) {
        self.audioRecorder = audioRecorder
        self.whistleEngine = whistleEngine
        self.textInserter = textInserter
        self.dictionaryStore = dictionaryStore
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
    }

    // MARK: - Public Actions

    public func startRecording() {
        guard state == .idle else { return }
        lastError = nil

        do {
            try audioRecorder.start()
            currentRecording.removeAll()
            recordingStartTime = Date()
            state = .recording
            startDurationTimer()
            logger.info("Started recording")
        } catch {
            handleError(error)
        }
    }

    public func stopRecording() {
        guard state == .recording else { return }
        stopDurationTimer()

        let recordedAudio = audioRecorder.stop()
        currentRecording = recordedAudio
        recordingDuration = Date().timeIntervalSince(recordingStartTime ?? Date())

        if recordedAudio.isEmpty || recordingDuration < 0.3 {
            // Too short, treat as cancel
            state = .idle
            logger.info("Recording too short, cancelled")
            return
        }

        state = .transcribing
        Task {
            await transcribeAndInsert()
        }
    }

    public func cancelRecording() {
        guard state == .recording else { return }
        _ = audioRecorder.stop()
        stopDurationTimer()
        state = .idle
        logger.info("Recording cancelled")
    }

    /// Clears an error state back to idle so dictation can be retried.
    public func dismissError() {
        guard case .error = state else { return }
        state = .idle
    }

    /// Re-inserts a previously dictated string at the current cursor position.
    public func reinsert(_ text: String) async {
        guard !text.isEmpty else { return }
        state = .inserting
        await textInserter.insert(text)
        state = .idle
    }

    public func toggleHandsFree() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing, .inserting:
            // Can't interrupt during processing
            break
        case .error:
            state = .idle
        }
    }

    // MARK: - Transcription Pipeline

    private func transcribeAndInsert() async {
        do {
            // Get keywords for biasing
            let keywords = dictionaryStore.getKeywordsForBiasing()

            // Determine language
            let language: String? = {
                let lang = preferencesStore.selectedLanguage
                return lang == .auto ? nil : lang.rawValue
            }()

            // Transcribe
            let transcript = try await whistleEngine.transcribe(
                currentRecording,
                language: language,
                keywords: keywords
            )

            // Apply post-processing corrections
            let processedText = dictionaryStore.applyCorrections(to: transcript.text)

            // Apply text post-processor (capitalization, punctuation)
            let postProcessor = TextPostProcessor(replacements: [:])
            let finalText = postProcessor.process(processedText.corrected)

            // Insert text
            state = .inserting
            await textInserter.insert(finalText)

            // Save to history
            let entry = DictationEntry(
                text: finalText,
                rawText: transcript.text,
                language: transcript.language,
                durationSec: recordingDuration,
                appBundleID: getFrontmostAppBundleID(),
                correctionsApplied: processedText.corrections
            )
            historyStore.addEntry(entry)

            state = .idle
            logger.info("Dictation completed: \(finalText)")

        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }

    private func handleError(_ error: Error) {
        let message = error.localizedDescription
        lastError = message
        state = .error(message)
        logger.error("Dictation error: \(message)")

        // Auto-dismiss error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.state == .error(message) {
                self?.state = .idle
            }
        }
    }

    // MARK: - Helpers

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(start)
                self.audioLevel = self.audioRecorder.level
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func getFrontmostAppBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}