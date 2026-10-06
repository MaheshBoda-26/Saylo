import AppKit
import Foundation
import SwiftUI
import os.log
import ServiceManagement

@MainActor
public final class PreferencesStore: ObservableObject {
    private let logger = Logger(subsystem: "com.saylo", category: "PreferencesStore")

    // MARK: - Published Properties (backed by @AppStorage)

    @AppStorage("hotkey") public var hotkey: HotkeyConfig = .fn {
        didSet { notifyChange() }
    }

    @AppStorage("language") public var language: String = SupportedLanguage.auto.rawValue {
        didSet { notifyChange() }
    }

    @AppStorage("playSounds") public var playSounds: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("handsFreeEnabled") public var handsFreeEnabled: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false {
        didSet {
            notifyChange()
            updateLoginItem()
        }
    }

    @AppStorage("pillPosition") public var pillPosition: PillPosition = .bottomCenter {
        didSet { notifyChange() }
    }

    @AppStorage("showMenuBarIcon") public var showMenuBarIcon: Bool = true {
        didSet { notifyChange() }
    }

    @AppStorage("maxHistoryItems") public var maxHistoryItems: Int = 1000 {
        didSet { notifyChange() }
    }

    @AppStorage("showFloatingPillAlways") public var showFloatingPillAlways: Bool = false {
        didSet { notifyChange() }
    }

    @AppStorage("showInDock") public var showInDock: Bool = true {
        didSet {
            notifyChange()
            updateDockVisibility()
        }
    }

    @AppStorage("muteAudioWhileDictating") public var muteAudioWhileDictating: Bool = false {
        didSet { notifyChange() }
    }

    // MARK: - Computed

    public var selectedLanguage: SupportedLanguage {
        get { SupportedLanguage(rawValue: language) ?? .auto }
        set { language = newValue.rawValue }
    }

    // MARK: - Initialization

    public init() {
        // Ensure login item state matches preference on launch
        if launchAtLogin {
            updateLoginItem()
        }
        updateDockVisibility()
    }

    private func updateDockVisibility() {
        // Regular = visible in Dock; Accessory = menu-bar only.
        // NOTE: NSApplication.shared (not NSApp) — NSApp is still nil
        // while StateObjects are created in SayloApp.init().
        NSApplication.shared.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    // MARK: - Login Item Management

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
                logger.info("Registered login item")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered login item")
            }
        } catch {
            logger.error("Failed to update login item: \(error.localizedDescription)")
        }
    }

    // MARK: - Change Notification

    private func notifyChange() {
        // Post notification for other components to react
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }

    // MARK: - Reset

    public func resetToDefaults() {
        hotkey = .fn
        language = SupportedLanguage.auto.rawValue
        playSounds = true
        handsFreeEnabled = true
        launchAtLogin = false
        pillPosition = .bottomCenter
        showMenuBarIcon = true
        maxHistoryItems = 1000
        showFloatingPillAlways = false
        showInDock = true
        muteAudioWhileDictating = false
    }
}

extension Notification.Name {
    static let preferencesChanged = Notification.Name("com.saylo.preferencesChanged")
}