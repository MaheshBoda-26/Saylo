import Foundation
import Carbon
import os.log

/// Monitors global hotkey events using CGEventTap.
///
/// Both supported hotkeys — Fn and Right Option — are modifier keys, and macOS
/// reports modifier transitions as `.flagsChanged`, never as `.keyDown`/`.keyUp`.
/// The tap therefore listens for flags changes only; handling Right Option in the
/// key-down path (as the first version did) meant it could never fire.
public final class HotkeyMonitor: ObservableObject {
    private let logger = Logger(subsystem: "com.saylo", category: "HotkeyMonitor")

    public enum Event {
        case keyDown
        case keyUp
        case doubleTap
    }

    public var onEvent: ((Event) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeyConfig: HotkeyConfig = .fn
    private var handsFreeEnabled: Bool = true

    // Double-tap detection
    private var lastKeyDownTime: CFAbsoluteTime = 0
    private let doubleTapThreshold: CFAbsoluteTime = 0.3

    /// Tracks the pressed state of the *active* hotkey, whichever it is.
    private var keyWasPressed = false

    private let lock = NSLock()

    public init() {}

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return eventTap != nil
    }

    /// Starts the event tap. Returns true if the tap is running afterwards.
    /// Fails (returns false) when Accessibility permission is missing.
    @discardableResult
    public func start(config: HotkeyConfig, handsFree: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard eventTap == nil else { return true }

        self.hotkeyConfig = config
        self.handsFreeEnabled = handsFree
        self.keyWasPressed = false
        self.lastKeyDownTime = 0

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: { (_, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("Failed to create event tap — check Accessibility permissions")
            return false
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        logger.info("Hotkey monitor started for \(config.displayName)")
        return true
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
            keyWasPressed = false
            logger.info("Hotkey monitor stopped")
        }
    }

    /// Applies a new hotkey configuration. Restarts the tap only when one is running.
    public func updateConfig(_ config: HotkeyConfig, handsFree: Bool) {
        lock.lock()
        let wasRunning = eventTap != nil
        let unchanged = hotkeyConfig == config && handsFreeEnabled == handsFree
        lock.unlock()

        guard wasRunning, !unchanged else { return }
        stop()
        start(config: config, handsFree: handsFree)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disables a tap whose callback is too slow. Re-arm it so
            // the hotkey keeps working for the rest of the session.
            lock.lock()
            let tap = eventTap
            lock.unlock()
            if let tap {
                logger.info("Event tap was disabled by the system — re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        default:
            break
        }

        // Hand the event back unretained: the system owns it for the duration of
        // the callback. `passRetained` would add an unbalanced +1 per event.
        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        lock.lock()
        let config = hotkeyConfig
        lock.unlock()

        let flags = event.flags
        let pressed: Bool

        switch config {
        case .fn:
            pressed = flags.contains(.maskSecondaryFn)
        case .rightOption:
            // Right Option is keycode 0x3D; left Option must not trigger.
            guard event.getIntegerValueField(.keyboardEventKeycode) == 0x3D else { return }
            pressed = flags.contains(.maskAlternate)
        }

        lock.lock()
        let wasPressed = keyWasPressed
        keyWasPressed = pressed
        lock.unlock()

        guard pressed != wasPressed else { return }

        if pressed {
            handleKeyDown()
        } else {
            handleKeyUp()
        }
    }

    private func handleKeyDown() {
        lock.lock()
        let handsFree = handsFreeEnabled
        let lastTime = lastKeyDownTime
        let threshold = doubleTapThreshold
        lock.unlock()

        let now = CFAbsoluteTimeGetCurrent()

        if handsFree && lastTime > 0 && now - lastTime < threshold {
            // Double-tap detected
            lock.lock()
            lastKeyDownTime = 0 // Prevent triple-tap
            lock.unlock()
            onEvent?(.doubleTap)
        } else {
            lock.lock()
            lastKeyDownTime = now
            lock.unlock()
            onEvent?(.keyDown)
        }
    }

    private func handleKeyUp() {
        onEvent?(.keyUp)
    }

    deinit {
        stop()
    }
}
