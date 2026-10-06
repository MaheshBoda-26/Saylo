import Foundation
import Carbon
import AppKit
import os.log

/// Inserts text at the current cursor position using pasteboard + synthetic ⌘V.
/// Restores the original clipboard contents afterward.
@MainActor
public final class TextInserter {
    private let logger = Logger(subsystem: "com.saylo", category: "TextInserter")

    public init() {}

    /// Inserts the given text at the current cursor position.
    public func insert(_ text: String) async {
        guard !text.isEmpty else { return }

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

        // Small delay to ensure pasteboard is ready
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Send ⌘V
        sendCommandV()

        // Wait a bit then restore clipboard
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        restoreClipboard(savedItems)
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)

        // ⌘V down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Small delay
        usleep(10_000) // 10ms

        // ⌘V up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    private func restoreClipboard(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}