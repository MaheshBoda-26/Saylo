import AppKit
import Combine
import Foundation
import os.log

/// Owns the global-hotkey → dictation → floating-pill loop.
///
/// Previously nothing called `HotkeyMonitor.start` and nothing owned a
/// `FloatingPillPanel`, so pressing the hotkey did nothing and no pill
/// ever appeared. This coordinator closes that loop:
///
/// - starts (and restarts) the event tap with the current preferences
/// - gates recording on microphone permission (prompting on first press)
/// - shows/updates/hides the floating pill from dictation state
/// - keeps the tap alive across app-activate and preference changes
@MainActor
final class DictationHotkeyCoordinator {
    private let logger = Logger(subsystem: "com.saylo", category: "DictationHotkeyCoordinator")

    private let dictationController: DictationController
    private let preferencesStore: PreferencesStore
    private let permissionsManager: PermissionsManager
    private let hotkeyMonitor: HotkeyMonitor

    private var pill: FloatingPillPanel?
    private var cancellables = Set<AnyCancellable>()
    private var meterTimer: Timer?
    private var hideWorkItem: DispatchWorkItem?
    private var activated = false

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
                self?.ensureTap()
                Task { @MainActor in
                    self?.reflect(state: self?.dictationController.state ?? .idle)
                }
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
        guard !hotkeyMonitor.isRunning else { return }
        let ok = hotkeyMonitor.start(
            config: preferencesStore.hotkey,
            handsFree: preferencesStore.handsFreeEnabled
        )
        if !ok {
            logger.error("Event tap failed — global hotkey inactive until Accessibility is granted")
        }
    }

    // MARK: - Hotkey events

    private func handleHotkey(_ event: HotkeyMonitor.Event) async {
        switch event {
        case .keyDown:
            await pressDown()
        case .keyUp:
            dictationController.stopRecording()
        case .doubleTap:
            await pressDown(toggle: true)
        }
    }

    /// Starts (or hands-free toggles) recording, requesting mic access first.
    private func pressDown(toggle: Bool = false) async {
        // Mic gate: prompt on first use so the app appears in
        // System Settings → Privacy → Microphone.
        if !permissionsManager.hasMicrophonePermission {
            _ = await permissionsManager.requestMicrophonePermission()
            guard permissionsManager.hasMicrophonePermission else {
                logger.info("Mic permission denied — not recording")
                return
            }
        }
        if toggle {
            dictationController.toggleHandsFree()
        } else {
            dictationController.startRecording()
        }
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
            duration: dictationController.recordingDuration
        )

        switch state {
        case .recording, .transcribing, .inserting, .error:
            panel.show(at: preferencesStore.pillPosition)
            startMeter()
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
                    duration: self.dictationController.recordingDuration
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
