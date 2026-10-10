//
//  AppDelegate.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CoreServices
import Foundation
import LoginServiceKit
import RxCocoa
import RxSwift
import Silica
import SwiftyBeaver

class AppDelegate: NSObject, NSApplicationDelegate {
    static let windowManagerEncodingKey = "EncodedWindowManager"

    // The preferences window still exists in the nib but is never shown: the configuration file is the only source of settings.
    @IBOutlet var preferencesWindowController: PreferencesWindowController?

    fileprivate var windowManager: WindowManager<SIApplication>?
    private var hotKeyManager: HotKeyManager<SIApplication>?

    fileprivate var statusItem: NSStatusItem?
    @IBOutlet var statusItemMenu: NSMenu?
    @IBOutlet var versionMenuItem: NSMenuItem?
    @IBOutlet var startAtLoginMenuItem: NSMenuItem?
    @IBOutlet var toggleGlobalTilingMenuItem: NSMenuItem?
    @IBOutlet var layoutsMenuItem: NSMenuItem?
    private var paddingMenuItem: NSMenuItem?

    /// Command URLs that arrived before the commands were set up, e.g. the one that launched the app.
    private var pendingCommandURLs: [URL] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Registered this early so a URL that launches the app isn't dropped.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            log.addDestination(ConsoleDestination())
        #endif

        if CommandLine.arguments.contains("--log") {
            let destination = ConsoleDestination()
            destination.useNSLog = true
            log.addDestination(destination)
        }

        log.info("Logging is enabled")
        log.debug("Debug logging is enabled")

        // Hosting unit tests: don't manage windows, which needs Accessibility and makes macOS ask for it on every build.
        guard !ProcessInfo.processInfo.isHostingTests else {
            return
        }

        UserConfiguration.shared.delegate = self
        UserConfiguration.shared.load()

        if let encodedWindowManager = UserDefaults.standard.data(forKey: AppDelegate.windowManagerEncodingKey), UserConfiguration.shared.restoreLayoutsOnLaunch() {
            let decoder = JSONDecoder()
            windowManager = try? decoder.decode(WindowManager<SIApplication>.self, from: encodedWindowManager)
        }

        let resolvedWindowManager = windowManager ?? WindowManager(userConfiguration: UserConfiguration.shared)
        windowManager = resolvedWindowManager
        hotKeyManager = HotKeyManager(userConfiguration: UserConfiguration.shared)

        hotKeyManager?.setUpWithWindowManager(resolvedWindowManager, configuration: UserConfiguration.shared, appDelegate: self)

        pendingCommandURLs.forEach(runCommand(from:))
        pendingCommandURLs = []

        NotificationCenter.default.addObserver(forName: .currentLayoutDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.updateStatusItemTitle()
        }
        updateStatusItemTitle()
    }

    /// Shows the current layout's name next to the menu bar icon.
    private func updateStatusItemTitle() {
        let screenManager = windowManager?.focusedScreenManager() ?? windowManager?.screenManager(at: 0)
        let layoutName = screenManager?.currentLayout?.layoutName
        statusItem?.button?.imagePosition = .imageLeft
        statusItem?.button?.title = layoutName.map { " \($0)" } ?? ""
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, let url = URL(string: urlString) else {
            log.warning("Ignoring a URL event without a valid URL")
            return
        }

        guard hotKeyManager != nil else {
            pendingCommandURLs.append(url)
            return
        }

        runCommand(from: url)
    }

    /// Runs the command a command URL names. Only registered commands run; anything else is logged and ignored.
    private func runCommand(from url: URL) {
        guard let commandKey = CommandURL.commandKey(from: url) else {
            log.warning("Ignoring unsupported URL: \(url)")
            return
        }

        guard hotKeyManager?.runCommand(commandKey) == true else {
            log.warning("Ignoring URL for unknown command: \(commandKey)")
            return
        }

        log.debug("Ran command from URL: \(commandKey)")
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let version = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"
        let shortVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let statusItemImage = NSImage(named: "icon-statusitem")
        statusItemImage?.isTemplate = true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.image = statusItemImage
        statusItem?.menu = statusItemMenu
        statusItem?.highlightMode = true

        let hideMenuBarIcon: Bool = UserConfiguration.shared.hideMenuBarIcon()
        statusItem?.isVisible = !hideMenuBarIcon

        versionMenuItem?.title = "Version \(shortVersion) (\(version))"
        toggleGlobalTilingMenuItem?.title = "Disable"

        startAtLoginMenuItem?.state = (LoginServiceKit.isExistLoginItems(at: Bundle.main.bundlePath) ? .on : .off)

        // Set up status item menu delegate to refresh layouts when main menu is opened
        statusItemMenu?.delegate = self

        // Padding modes come from the configuration, so their submenu is built here rather than in the nib.
        if let statusItemMenu = statusItemMenu, let layoutsMenuItem = layoutsMenuItem {
            let paddingMenuItem = NSMenuItem(title: "Padding", action: nil, keyEquivalent: "")
            paddingMenuItem.submenu = NSMenu(title: "Padding")
            statusItemMenu.insertItem(paddingMenuItem, at: statusItemMenu.index(of: layoutsMenuItem) + 1)
            self.paddingMenuItem = paddingMenuItem
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard let windowManager = windowManager else {
            return
        }

        do {
            let encoder = JSONEncoder()
            let encodedWindowManager = try encoder.encode(windowManager)
            UserDefaults.standard.set(encodedWindowManager, forKey: AppDelegate.windowManagerEncodingKey)
        } catch {
            log.error("Failed to encode window manager: \(error)")
        }
    }

    @IBAction func toggleStartAtLogin(_ sender: AnyObject) {
        if startAtLoginMenuItem?.state == .off {
            LoginServiceKit.addLoginItems(at: Bundle.main.bundlePath)
        } else {
            LoginServiceKit.removeLoginItems(at: Bundle.main.bundlePath)
        }
        startAtLoginMenuItem?.state = (LoginServiceKit.isExistLoginItems(at: Bundle.main.bundlePath) ? .on : .off)
    }

    @IBAction func toggleGlobalTiling(_ sender: AnyObject) {
        UserConfiguration.shared.tilingEnabled = !UserConfiguration.shared.tilingEnabled
        windowManager?.markAllScreensForReflow()
    }

    @IBAction func resetLayouts(_ sender: AnyObject) {
        UserDefaults.standard.removeObject(forKey: AppDelegate.windowManagerEncodingKey)
        windowManager?.reset()
    }

    @IBAction func relaunch(_ sender: AnyObject) {
        AppManager.relaunch()
    }

    /// Opens the configuration file in its default editor, creating a starter file if there is none.
    @IBAction func editConfig(_ sender: AnyObject) {
        do {
            let path = try UserConfiguration.shared.editableConfigurationFilePath()
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } catch {
            log.error("Could not open the configuration file: \(error)")
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could not open the configuration file"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func populateLayoutsMenu() {
        guard let layoutsMenuItem = layoutsMenuItem,
              let submenu = layoutsMenuItem.submenu else {
            return
        }

        // Clear existing items
        submenu.removeAllItems()

        // Get screen manager: try focused screen first, then screen under mouse cursor
        let screenManager: ScreenManager<WindowManager<SIApplication>>? = {
            if let focused = windowManager?.focusedScreenManager() {
                return focused
            }
            // Fallback to screen containing mouse cursor (useful when clicking menu bar)
            let mouseLocation = NSEvent.mouseLocation
            if let nsScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                let amScreen = AMScreen(screen: nsScreen)
                return windowManager?.screenManager(for: amScreen)
            }
            return nil
        }()

        guard let screenManager = screenManager else {
            let errorItem = NSMenuItem(title: "Unable to determine current screen", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            submenu.addItem(errorItem)
            return
        }

        // Get layouts from the screen manager (not from global config)
        let layouts = screenManager.layoutsInfo

        // Check if no layouts are available and return early
        if layouts.isEmpty {
            let noLayoutsItem = NSMenuItem(title: "No layouts enabled", action: nil, keyEquivalent: "")
            noLayoutsItem.isEnabled = false
            submenu.addItem(noLayoutsItem)
            return
        }

        // Add menu items for each layout in the screen manager
        for layoutInfo in layouts {
            let menuItem = NSMenuItem(title: layoutInfo.name, action: #selector(selectLayout(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = layoutInfo.key
            menuItem.state = layoutInfo.isSelected ? .on : .off

            submenu.addItem(menuItem)
        }
    }

    private func populatePaddingMenu() {
        guard let paddingMenuItem = paddingMenuItem, let submenu = paddingMenuItem.submenu else {
            return
        }

        submenu.removeAllItems()

        let paddingModes = UserConfiguration.shared.paddingModes()
        paddingMenuItem.isHidden = paddingModes.isEmpty

        let activeName = UserConfiguration.shared.activePaddingMode()?.name
        for paddingMode in paddingModes {
            let menuItem = NSMenuItem(title: paddingMode.name, action: #selector(selectPaddingMode(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = paddingMode.name
            menuItem.state = paddingMode.name == activeName ? .on : .off
            submenu.addItem(menuItem)
        }
    }

    @IBAction func selectPaddingMode(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else {
            return
        }

        windowManager?.selectPaddingMode(named: name)
    }

    @IBAction func selectLayout(_ sender: NSMenuItem) {
        guard let layoutKey = sender.representedObject as? String,
              let windowManager = windowManager,
              let screenManager = windowManager.focusedScreenManager() else {
            return
        }

        screenManager.selectLayout(layoutKey)
        // Menu will be refreshed automatically when next opened via NSMenuDelegate
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        windowManager?.preferencesDidClose()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Refresh layouts menu when main status item menu is about to open
        if menu == statusItemMenu {
            populateLayoutsMenu()
            populatePaddingMenu()
        }
    }
}

extension AppDelegate: UserConfigurationDelegate {
    func configurationGlobalTilingDidChange(_ userConfiguration: UserConfiguration) {
        var statusItemImage: NSImage?
        if UserConfiguration.shared.tilingEnabled == true {
            statusItemImage = NSImage(named: "icon-statusitem")
            toggleGlobalTilingMenuItem?.title = "Disable Tiling"
        } else {
            statusItemImage = NSImage(named: "icon-statusitem-disabled")
            toggleGlobalTilingMenuItem?.title = "Enable Tiling"
        }
        statusItemImage?.isTemplate = true
        statusItem?.image = statusItemImage
    }

    func configurationAccessibilityPermissionsDidChange(_ userConfiguration: UserConfiguration) {
        windowManager?.reevaluateWindows()
    }
}
