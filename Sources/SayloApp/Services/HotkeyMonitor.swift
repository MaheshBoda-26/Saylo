import Foundation
import Carbon
import os.log

/// Monitors global hotkey events using CGEventTap.
/// Supports Fn key (hold) and Right Option (hold) with double-tap for hands-free mode.
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

    // Fn key tracking (it's a modifier flag change, not a regular key)
    private var fnWasPressed = false

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

        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (_, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
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
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            eventTap = nil
            runLoopSource = nil
            logger.info("Hotkey monitor stopped")
        }
    }

    public func updateConfig(_ config: HotkeyConfig, handsFree: Bool) {
        lock.lock()
        let wasRunning = eventTap != nil
        lock.unlock()

        if wasRunning { stop() }
        start(config: config, handsFree: handsFree)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags

        switch type {
        case .flagsChanged:
            // Fn key is detected as a flags change
            let fnPressed = flags.contains(.maskSecondaryFn)

            lock.lock()
            let config = hotkeyConfig
            let wasPressed = fnWasPressed
            fnWasPressed = fnPressed
            lock.unlock()

            if fnPressed != wasPressed {
                if config == .fn {
                    if fnPressed {
                        handleKeyDown()
                    } else {
                        handleKeyUp()
                    }
                }
            }

        case .keyDown:
            lock.lock()
            let config = hotkeyConfig
            lock.unlock()

            if config == .rightOption && flags.contains(.maskAlternate) && event.getIntegerValueField(.keyboardEventKeycode) == 0x3D {
                handleKeyDown()
            }

        case .keyUp:
            lock.lock()
            let config = hotkeyConfig
            lock.unlock()

            if config == .rightOption && !flags.contains(.maskAlternate) && event.getIntegerValueField(.keyboardEventKeycode) == 0x3D {
                handleKeyUp()
            }

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }

    private func handleKeyDown() {
        lock.lock()
        let handsFree = handsFreeEnabled
        let lastTime = lastKeyDownTime
        let threshold = doubleTapThreshold
        lock.unlock()

        let now = CFAbsoluteTimeGetCurrent()
        let timeSinceLast = now - lastTime

        if handsFree && timeSinceLast < threshold {
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

// MARK: - HotkeyConfig Extension for Display

extension HotkeyConfig {
    var keyEquivalent: String {
        switch self {
        case .fn: return "⌘" // Placeholder - Fn doesn't have a standard symbol
        case .rightOption: return "⌥"
        }
    }
}