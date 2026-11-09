import AppKit
import Foundation
import SayloCore
import os.log

/// Controls the dictation state machine and coordinates all components.
@MainActor
public final class DictationController: ObservableObject {
    private let logger = Logger(subsystem: "com.saylo", category: "DictationController")

    // Dependencies
    private let audioRecorder: AudioRecorder
    /// `nil` when the speech model could not be loaded at launch. The app still
    /// runs — the UI reports the problem instead of terminating.
    private let whistleEngine: WhistleEngine?
    private let textInserter: TextInserter
    private let dictionaryStore: DictionaryStore
    private let historyStore: HistoryStore
    private let preferencesStore: PreferencesStore

    // State
    @Published public private(set) var state: DictationState = .idle
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var recordingDuration: TimeInterval = 0
    @Published public private(set) var lastError: String?
    /// Non-nil when the app started without a usable speech engine.
    @Published public private(set) var startupError: String?

    // Timer for updating duration
    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    // Audio recording
    private var currentRecording: [Float] = []

    /// The app that was frontmost when dictation started. Used to return focus
    /// to it when re-inserting a past dictation from Saylo's own window.
    private var lastTargetApp: NSRunningApplication?

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
        whistleEngine: WhistleEngine?,
        textInserter: TextInserter,
        dictionaryStore: DictionaryStore,
        historyStore: HistoryStore,
        preferencesStore: PreferencesStore,
        startupError: String? = nil
    ) {
        self.audioRecorder = audioRecorder
        self.whistleEngine = whistleEngine
        self.textInserter = textInserter
        self.dictionaryStore = dictionaryStore
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
        self.startupError = startupError
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
            rememberTargetApp()
            playCue("Tink")
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
            // Too short, or the recorder found no speech above the noise floor.
            state = .idle
            if audioRecorder.wasSilent {
                logger.info("No speech detected, cancelled")
            } else {
                logger.info("Recording too short, cancelled")
            }
            return
        }

        playCue("Pop")
        state = .transcribing
        Task {
            await transcribeAndInsert()
        }
    }

    public func cancelRecording() {
        guard state == .recording else { return }
        _ = audioRecorder.stop()
        currentRecording.removeAll()
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

        // The user clicked a row inside Saylo, so Saylo is frontmost. Hand focus
        // back to the app they were dictating into before sending ⌘V.
        if let target = lastTargetApp,
           target.bundleIdentifier != Bundle.main.bundleIdentifier,
           !target.isTerminated {
            target.activate()
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        let inserted = await textInserter.insert(text)
        if inserted {
            state = .idle
        } else {
            handleError(DictationError.insertionFailed)
        }
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
            guard let whistleEngine else {
                throw WhistleError.modelNotFound("the speech model is unavailable")
            }

            // Get keywords for biasing
            let keywords = dictionaryStore.getKeywordsForBiasing()

            // Determine language
            let language: String? = {
                let lang = preferencesStore.selectedLanguage
                return lang == .auto ? nil : lang.rawValue
            }()

            // Capture the destination once: after the paste the frontmost app may
            // have changed, and the history entry should describe where the text
            // actually went.
            let appBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

            // Transcribe
            let transcript = try await whistleEngine.transcribe(
                currentRecording,
                language: language,
                keywords: keywords
            )

            // Apply post-processing corrections
            let processedText = dictionaryStore.applyCorrections(to: transcript.text)

            // Apply text post-processor (capitalization, punctuation, phonetic corrections, context-aware formatting)
            let postProcessor = TextPostProcessor(
                replacements: dictionaryStore.phraseReplacements,
                removingFillers: true,
                appBundleID: appBundleID
            )
            let finalText = postProcessor.process(processedText.corrected)

            // Speech models still emit a hallucinated phrase for some non-speech
            // audio that clears the energy gate. Nothing to insert means nothing
            // to record — an empty row would only ever be noise in the timeline.
            guard !finalText.isEmpty else {
                state = .idle
                logger.info("No speech recognised, nothing inserted")
                return
            }

            // Insert text
            state = .inserting
            let inserted = await textInserter.insert(finalText)
            guard inserted else {
                throw DictationError.insertionFailed
            }

            // Save to history
            if preferencesStore.storeHistory {
                let entry = DictationEntry(
                    text: finalText,
                    rawText: transcript.text,
                    language: transcript.language,
                    durationSec: recordingDuration,
                    appBundleID: appBundleID,
                    correctionsApplied: processedText.corrections
                )
                historyStore.addEntry(entry, limit: preferencesStore.effectiveHistoryLimit)
            }

            state = .idle
            logger.info("Dictation completed: \(finalText)")

        } catch {
            handleError(error)
        }

        // The samples are no longer needed once the clip has been transcribed.
        currentRecording.removeAll(keepingCapacity: false)
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

    private enum DictationError: LocalizedError {
        case insertionFailed

        var errorDescription: String? {
            switch self {
            case .insertionFailed:
                return "Could not insert text. Check Accessibility permission."
            }
        }
    }

    private func rememberTargetApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        lastTargetApp = app
    }

    private func playCue(_ name: String) {
        guard preferencesStore.playSounds else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func startDurationTimer() {
        guard let start = recordingStartTime else { return }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
                self.audioLevel = self.audioRecorder.level

                // A hands-free session left running would otherwise record until
                // the buffer cap, so stop cleanly when the cap is reached.
                if self.audioRecorder.reachedLimit, self.state == .recording {
                    self.logger.info("Capture limit reached, stopping")
                    self.stopRecording()
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
