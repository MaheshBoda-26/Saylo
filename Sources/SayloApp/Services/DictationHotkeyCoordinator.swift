import AppKit
import Combine
import Foundation
import os.log

/// Owns the global-hotkey → dictation → floating-pill loop.
///
/// - starts (and restarts) the event tap with the current preferences
/// - gates recording on microphone permission (prompting on first press)
/// - shows/updates/hides the floating pill from dictation state
/// - keeps the tap alive across app-activate and preference changes
///
/// ## Hold-to-talk vs hands-free
///
/// A double-tap is two press/release pairs. If the first release stopped the
/// recording immediately, the second press would always arrive during
/// transcription and hands-free could never engage. The stop is therefore
/// deferred by the double-tap window when hands-free is enabled; a second press
/// inside that window cancels it and latches the session instead.
@MainActor
final class DictationHotkeyCoordinator {
    private let logger = Logger(subsystem: "com.saylo", category: "DictationHotkeyCoordinator")

    /// Must be at least `HotkeyMonitor`'s double-tap threshold.
    private static let stopDeferral: TimeInterval = 0.32

    private let dictationController: DictationController
    private let preferencesStore: PreferencesStore
    private let permissionsManager: PermissionsManager
    private let hotkeyMonitor: HotkeyMonitor

    private var pill: FloatingPillPanel?
    private var cancellables = Set<AnyCancellable>()
    private var meterTimer: Timer?
    private var hideWorkItem: DispatchWorkItem?
    private var activated = false

    // Hands-free state machine
    private var pendingStop: DispatchWorkItem?
    private var handsFreeLatched = false
    private var suppressNextKeyUp = false
    private var isStarting = false
    /// A latched stop blocks new starts for one double-tap window, so the
    /// release of the stop tap cannot be mistaken for the start of a new one.
    private var startBlockedUntil = Date.distantPast

    init(
        dictationController: DictationController,
        preferencesStore: PreferencesStore,
        permissionsManager: PermissionsManager,
        hotkeyMonitor: HotkeyMonitor
    ) {
        self.dictationController = dictationController
        self.preferencesStore = preferencesStore
        self.permissionsManager = permissionsManager
        self.hotkeyMonitor = hotkeyMonitor

        hotkeyMonitor.onEvent = { [weak self] event in
            Task { @MainActor in
                await self?.handleHotkey(event)
            }
        }

        // Pill follows dictation state.
        dictationController.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.reflect(state: state)
                }
            }
            .store(in: &cancellables)

        // Hotkey/pill prefs can change at runtime.
        NotificationCenter.default.publisher(for: .preferencesChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyPreferences()
            }
            .store(in: &cancellables)

        // Accessibility may be granted while we run — retry the tap then.
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.permissionsManager.checkPermissions()
                self?.ensureTap()
            }
            .store(in: &cancellables)
    }

    /// Idempotent. Call from the app's content onAppear.
    func activate() {
        permissionsManager.checkPermissions()
        ensureTap()
        if !activated {
            activated = true
            // If the user wants the pill always visible, show standby now.
            reflect(state: dictationController.state)
        }
        if !permissionsManager.hasAccessibilityPermission {
            logger.info("Accessibility not granted — global hotkey tap cannot start until it is")
        }
    }

    // MARK: - Event tap

    private func ensureTap() {
        if hotkeyMonitor.isRunning {
            hotkeyMonitor.updateConfig(preferencesStore.hotkey,
                                       handsFree: preferencesStore.handsFreeEnabled)
            return
        }
        let ok = hotkeyMonitor.start(
            config: preferencesStore.hotkey,
            handsFree: preferencesStore.handsFreeEnabled
        )
        if !ok {
            logger.error("Event tap failed — global hotkey inactive until Accessibility is granted")
        }
    }

    private func applyPreferences() {
        ensureTap()
        // Turning hands-free off mid-session must end the latched recording,
        // otherwise it would keep capturing until the buffer cap.
        if !preferencesStore.handsFreeEnabled, handsFreeLatched {
            endHandsFree()
        }
        Task { @MainActor in
            self.reflect(state: self.dictationController.state)
        }
    }

    // MARK: - Hotkey events

    private func handleHotkey(_ event: HotkeyMonitor.Event) async {
        switch event {
        case .keyDown:
            cancelPendingStop()
            // A press while latched is the first half of the "stop" tap.
            guard !handsFreeLatched else { return }
            await pressDown()

        case .keyUp:
            if suppressNextKeyUp {
                // Release that completes the double-tap that started the session.
                suppressNextKeyUp = false
                return
            }
            if handsFreeLatched {
                endHandsFree()
                return
            }
            scheduleStop()

        case .doubleTap:
            cancelPendingStop()
            if handsFreeLatched {
                endHandsFree()
            } else {
                await beginHandsFree()
            }
        }
    }

    /// Stops a latched session and blocks an immediate restart.
    ///
    /// Stopping is a single tap: down (ignored while latched) then up. Without
    /// the block, a user who taps twice to stop would fire a second `.keyDown`
    /// inside the double-tap window and start a brand-new recording.
    private func endHandsFree() {
        handsFreeLatched = false
        suppressNextKeyUp = false
        cancelPendingStop()
        startBlockedUntil = Date().addingTimeInterval(Self.stopDeferral)
        dictationController.stopRecording()
    }

    /// Starts (or hands-free latches) recording, requesting mic access first.
    private func pressDown() async {
        guard dictationController.state == .idle else { return }
        guard !isStarting else { return }
        guard Date() >= startBlockedUntil else { return }
        isStarting = true
        defer { isStarting = false }

        // Mic gate: prompt on first use so the app appears in
        // System Settings → Privacy → Microphone.
        if !permissionsManager.hasMicrophonePermission {
            _ = await permissionsManager.requestMicrophonePermission()
            guard permissionsManager.hasMicrophonePermission else {
                logger.info("Mic permission denied — not recording")
                return
            }
        }
        dictationController.startRecording()
    }

    private func beginHandsFree() async {
        switch dictationController.state {
        case .idle:
            await pressDown()
            guard dictationController.state == .recording else { return }
        case .recording:
            break
        default:
            return
        }
        handsFreeLatched = true
        suppressNextKeyUp = true
    }

    private func scheduleStop() {
        cancelPendingStop()

        guard preferencesStore.handsFreeEnabled else {
            dictationController.stopRecording()
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingStop = nil
            self.dictationController.stopRecording()
        }
        pendingStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stopDeferral, execute: work)
    }

    private func cancelPendingStop() {
        pendingStop?.cancel()
        pendingStop = nil
    }

    // MARK: - Pill

    private func ensurePill() -> FloatingPillPanel {
        if let pill { return pill }
        let panel = FloatingPillPanel()
        self.pill = panel
        return panel
    }

    private func reflect(state: DictationController.DictationState) {
        hideWorkItem?.cancel()
        hideWorkItem = nil

        let panel = ensurePill()
        panel.updateState(
            state,
            level: dictationController.audioLevel,
            duration: dictationController.recordingDuration,
            hotkey: preferencesStore.hotkey.shortLabel
        )

        switch state {
        case .recording:
            panel.show(at: preferencesStore.pillPosition)
            startMeter()
        case .transcribing, .inserting, .error:
            panel.show(at: preferencesStore.pillPosition)
            stopMeter()
        case .idle:
            stopMeter()
            if preferencesStore.showFloatingPillAlways {
                // Standby pill stays up between dictations.
                panel.show(at: preferencesStore.pillPosition)
            } else if case .inserting = lastNonIdle {
                // Let the "Pasted" confirmation linger briefly.
                scheduleHide(after: 1.4)
            } else {
                scheduleHide(after: 0.3)
            }
        }

        if state.isActive || state.isError {
            lastNonIdle = state
        }
    }

    private var lastNonIdle: DictationController.DictationState = .idle

    private func scheduleHide(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            self?.pill?.hide()
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func startMeter() {
        guard meterTimer == nil else { return }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let pill = self.pill else { return }
                pill.updateState(
                    self.dictationController.state,
                    level: self.dictationController.audioLevel,
                    duration: self.dictationController.recordingDuration,
                    hotkey: self.preferencesStore.hotkey.shortLabel
                )
            }
        }
    }

    private func stopMeter() {
        meterTimer?.invalidate()
        meterTimer = nil
    }
}

// MARK: - DictationState helpers

private extension DictationController.DictationState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
