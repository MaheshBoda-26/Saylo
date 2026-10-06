import Foundation
import AppKit
import os.log

/// Manages microphone and accessibility permissions.
@MainActor
public final class PermissionsManager: ObservableObject {
    private let logger = Logger(subsystem: "com.saylo", category: "PermissionsManager")

    @Published public var hasMicrophonePermission: Bool = false
    @Published public var hasAccessibilityPermission: Bool = false

    public init() {
        checkPermissions()
    }

    public func checkPermissions() {
        // Check microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        hasMicrophonePermission = (micStatus == .authorized)

        // Check accessibility
        hasAccessibilityPermission = AXIsProcessTrusted()

        logger.info("Permissions - Mic: \(self.hasMicrophonePermission), Accessibility: \(self.hasAccessibilityPermission)")
    }

    public func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            self.hasMicrophonePermission = granted
        }
        return granted
    }

    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Note: AXIsProcessTrustedWithOptions returns immediately, the prompt is async
        // We'll re-check after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkPermissions()
        }
    }

    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public var allPermissionsGranted: Bool {
        hasMicrophonePermission && hasAccessibilityPermission
    }
}

// Need to import AVFoundation for AVCaptureDevice
import AVFoundation