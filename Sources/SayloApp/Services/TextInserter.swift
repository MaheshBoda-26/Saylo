import AppKit
import ApplicationServices
import Carbon
import Foundation
import os.log

/// Inserts text at the current cursor position using pasteboard + synthetic ⌘V.
/// Restores the original clipboard contents afterward.
@MainActor
public final class TextInserter {
    private let logger = Logger(subsystem: "com.saylo", category: "TextInserter")

    public init() {}

    /// Inserts the given text at the current cursor position.
    /// - Returns: `false` when the paste could not be performed (no Accessibility
    ///   permission, or the synthetic key events could not be created). Callers
    ///   must surface that instead of reporting success.
    @discardableResult
    public func insert(_ text: String) async -> Bool {
        guard !text.isEmpty else { return false }

        guard AXIsProcessTrusted() else {
            logger.error("Cannot insert text — Accessibility permission is not granted")
            return false
        }

        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        } ?? []

        // Set new text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChangeCount = pasteboard.changeCount

        // Small delay to ensure pasteboard is ready
        try? await Task.sleep(nanoseconds: 50_000_000)

        guard sendCommandV() else {
            restoreClipboard(savedItems, expectedChangeCount: ourChangeCount)
            return false
        }

        // Give slow hosts (Electron, remote desktop) time to consume the paste
        // before putting the old clipboard back.
        try? await Task.sleep(nanoseconds: 150_000_000)
        restoreClipboard(savedItems, expectedChangeCount: ourChangeCount)
        return true
    }

    private func sendCommandV() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        // ⌘V down
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)

        // Small delay
        usleep(10_000) // 10ms

        // ⌘V up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }
        keyUp.flags = .maskCommand
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    /// Puts the previous clipboard back, but only if nothing else has claimed the
    /// clipboard in the meantime — restoring blindly would discard whatever the
    /// user copied while the paste was in flight.
    private func restoreClipboard(_ items: [NSPasteboardItem], expectedChangeCount: Int) {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == expectedChangeCount else { return }

        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
