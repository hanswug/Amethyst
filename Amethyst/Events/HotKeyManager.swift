//
//  HotKeyManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Carbon
import Foundation
import KeyboardShortcuts
import Silica

// Type for defining key code.
typealias AMKeyCode = Int

// Type for defining modifier flags.
typealias AMModifierFlags = NSEvent.ModifierFlags

// Specific key code defined to be invalid.
// Can be used to identify if a returned key code is valid or not.
private let AMKeyCodeInvalid: AMKeyCode = 0xFF

typealias HotKeyHandler = () -> Void

/// `amethyst://command/<command-key>` runs any command, bound to a key or not, from outside the app (scripts, launchers).
enum CommandURL {
    static let scheme = "amethyst"

    /// The command key of a command URL, or `nil` for any other URL.
    static func commandKey(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == "command" else {
            return nil
        }

        // `path` is percent-decoded, so names with spaces (e.g. padding modes) can be passed encoded.
        let components = url.path.split(separator: "/")
        guard components.count == 1 else {
            return nil
        }

        return String(components[0])
    }
}

class HotKeyManager<Application: ApplicationType>: NSObject {
    private let userConfiguration: UserConfiguration

    /// Every command set up in `setUpWithWindowManager`, bound to a key or not, by command key.
    private(set) var commandHandlers: [String: HotKeyHandler] = [:]

    private(set) lazy var stringToKeyCodes: [String: [AMKeyCode]] = {
        return self.constructKeyCodeMap()
    }()

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        super.init()
        _ = constructKeyCodeMap()
    }

    private static func keyCodeForNumber(_ number: NSNumber) -> AMKeyCode {
        let string = "\(number)"

        guard !string.isEmpty else {
            return AMKeyCodeInvalid
        }

        switch string.last! {
        case "1":
            return kVK_ANSI_1
        case "2":
            return kVK_ANSI_2
        case "3":
            return kVK_ANSI_3
        case "4":
            return kVK_ANSI_4
        case "5":
            return kVK_ANSI_5
        case "6":
            return kVK_ANSI_6
        case "7":
            return kVK_ANSI_7
        case "8":
            return kVK_ANSI_8
        case "9":
            return kVK_ANSI_9
        case "0":
            return kVK_ANSI_0
        default:
            return AMKeyCodeInvalid
        }
    }

    func setUpWithWindowManager(_ windowManager: WindowManager<Application>, configuration: UserConfiguration, appDelegate: AppDelegate) {
        constructCommandWithCommandKey(CommandKey.cycleLayoutForward.rawValue) {
            let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
            screenManager?.cycleLayoutForward()
        }

        constructCommandWithCommandKey(CommandKey.cycleLayoutBackward.rawValue) {
            let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
            screenManager?.cycleLayoutBackward()
        }

        constructCommandWithCommandKey(CommandKey.shrinkMain.rawValue) {
            let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
            screenManager?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.shrinkMainPane()
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.expandMain.rawValue) {
            let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
            screenManager?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.expandMainPane()
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.increaseMain.rawValue) {
            let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
            screenManager?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.increaseMainPaneCount()
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.decreaseMain.rawValue) {
            let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
            screenManager?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.decreaseMainPaneCount()
                }
            }
        }

        // Commands 1–4 only do something in custom layouts, so they're offered only when there are any.
        if !LayoutType<Application.Window>.customLayoutKeys().isEmpty {
            constructCommandWithCommandKey(CommandKey.command1.rawValue) {
                let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
                screenManager?.updateCurrentLayout { layout in
                    if let customLayout = layout as? CustomLayout {
                        customLayout.command1()
                    }
                }
            }

            constructCommandWithCommandKey(CommandKey.command2.rawValue) {
                let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
                screenManager?.updateCurrentLayout { layout in
                    if let customLayout = layout as? CustomLayout {
                        customLayout.command2()
                    }
                }
            }

            constructCommandWithCommandKey(CommandKey.command3.rawValue) {
                let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
                screenManager?.updateCurrentLayout { layout in
                    if let customLayout = layout as? CustomLayout {
                        customLayout.command3()
                    }
                }
            }

            constructCommandWithCommandKey(CommandKey.command4.rawValue) {
                let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
                screenManager?.updateCurrentLayout { layout in
                    if let customLayout = layout as? CustomLayout {
                        customLayout.command4()
                    }
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.focusCCW.rawValue) {
            windowManager.focusTransitionCoordinator.moveFocusCounterClockwise()
        }

        constructCommandWithCommandKey(CommandKey.focusCW.rawValue) {
            windowManager.focusTransitionCoordinator.moveFocusClockwise()
        }

        constructCommandWithCommandKey(CommandKey.focusMain.rawValue) {
            windowManager.focusTransitionCoordinator.moveFocusToMain()
        }

        constructCommandWithCommandKey(CommandKey.swapCCW.rawValue) {
            windowManager.windowTransitionCoordinator.swapFocusedWindowCounterClockwise()
        }

        constructCommandWithCommandKey(CommandKey.swapCW.rawValue) {
            windowManager.windowTransitionCoordinator.swapFocusedWindowClockwise()
        }

        constructCommandWithCommandKey(CommandKey.swapMain.rawValue) {
            windowManager.windowTransitionCoordinator.swapFocusedWindowToMain()
        }

        constructCommandWithCommandKey(CommandKey.displayCurrentLayout.rawValue) {
            DispatchQueue.main.async {
                windowManager.displayCurrentLayout()
            }
        }

        constructCommandWithCommandKey(CommandKey.toggleFloat.rawValue) {
            windowManager.toggleFloatForFocusedWindow()
        }

        constructCommandWithCommandKey(CommandKey.toggleTiling.rawValue) {
            self.userConfiguration.tilingEnabled = !self.userConfiguration.tilingEnabled
            windowManager.markAllScreensForReflow()
        }

        constructCommandWithCommandKey(CommandKey.enableTiling.rawValue) {
            guard !self.userConfiguration.tilingEnabled else { return }
            self.userConfiguration.tilingEnabled = true
            windowManager.markAllScreensForReflow()
        }

        constructCommandWithCommandKey(CommandKey.disableTiling.rawValue) {
            guard self.userConfiguration.tilingEnabled else { return }
            self.userConfiguration.tilingEnabled = false
            windowManager.markAllScreensForReflow()
        }

        constructCommandWithCommandKey(CommandKey.reevaluateWindows.rawValue) {
            windowManager.reevaluateWindows()
        }

        constructCommandWithCommandKey(CommandKey.toggleFocusFollowsMouse.rawValue) {
            self.userConfiguration.toggleFocusFollowsMouse()
        }

        constructCommandWithCommandKey(CommandKey.relaunchAmethyst.rawValue) { [weak appDelegate] in
            appDelegate?.relaunch(self)
        }

        constructCommandWithCommandKey(CommandKey.increaseWindowMaxCount.rawValue) {
            self.userConfiguration.increaseWindowMaxCount()
            windowManager.markAllScreensForReflow()
            DispatchQueue.main.async {
                windowManager.displayWindowCountHUD()
            }
        }

        constructCommandWithCommandKey(CommandKey.decreaseWindowMaxCount.rawValue) {
            self.userConfiguration.decreaseWindowMaxCount()
            windowManager.markAllScreensForReflow()
            DispatchQueue.main.async {
                windowManager.displayWindowCountHUD()
            }
        }

        LayoutType<Application.Window>.availableLayoutStrings().forEach { (layoutKey, _) in
            self.constructCommandWithCommandKey(UserConfiguration.constructLayoutKeyString(layoutKey)) {
                let screenManager: ScreenManager<WindowManager<Application>>? = windowManager.focusedScreenManager()
                screenManager?.selectLayout(layoutKey)
            }
        }

        constructCommandWithCommandKey(CommandKey.cyclePaddingModeForward.rawValue) {
            windowManager.cyclePaddingMode(forward: true)
        }

        constructCommandWithCommandKey(CommandKey.cyclePaddingModeBackward.rawValue) {
            windowManager.cyclePaddingMode(forward: false)
        }

        userConfiguration.paddingModes().forEach { paddingMode in
            self.constructCommandWithCommandKey(UserConfiguration.constructPaddingModeKeyString(paddingMode.name)) {
                windowManager.selectPaddingMode(named: paddingMode.name)
            }
        }

        constructCommandWithCommandKey(CommandKey.showCommandPalette.rawValue) { [weak appDelegate] in
            DispatchQueue.main.async {
                appDelegate?.toggleCommandPalette()
            }
        }
    }

    private func constructKeyCodeMap() -> [String: [AMKeyCode]] {
        var stringToKeyCodes: [String: [AMKeyCode]] = [:]

        // Generate unicode character keymapping from keyboard layout data.  We go
        // through all keycodes and create a map of string representations to a list
        // of key codes. It has to map to a list because a string representation
        // canmap to multiple codes (e.g., 1 and numpad 1 both have string
        // representation "1").
        var currentKeyboard = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        var rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)

        if rawLayoutData == nil {
            currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeUnretainedValue()
            rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        }

        // Get the layout
        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        let layout: UnsafePointer<UCKeyboardLayout> = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var keysDown: UInt32 = 0
        var chars: [UniChar] = [0, 0, 0, 0]
        var realLength: Int = 0

        for keyCode in (0..<AMKeyCodeInvalid) {
            switch keyCode {
            case
            kVK_ANSI_Keypad0,
            kVK_ANSI_Keypad1,
            kVK_ANSI_Keypad2,
            kVK_ANSI_Keypad3,
            kVK_ANSI_Keypad4,
            kVK_ANSI_Keypad5,
            kVK_ANSI_Keypad6,
            kVK_ANSI_Keypad7,
            kVK_ANSI_Keypad8,
            kVK_ANSI_Keypad9:
                continue
            default:
                break
            }

            UCKeyTranslate(layout,
                           UInt16(keyCode),
                           UInt16(kUCKeyActionDisplay),
                           0,
                           UInt32(LMGetKbdType()),
                           UInt32(kUCKeyTranslateNoDeadKeysBit),
                           &keysDown,
                           chars.count,
                           &realLength,
                           &chars)

            let string = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, realLength) as String

            if let keyCodes = stringToKeyCodes[string] {
                var mutableKeyCodes = keyCodes
                mutableKeyCodes.append(keyCode)
                stringToKeyCodes[string] = mutableKeyCodes
            } else {
                stringToKeyCodes[string] = [keyCode]
            }
        }

        // Add codes for non-printable characters. They are not printable so they
        // are not generated from the keyboard layout data.
        stringToKeyCodes["space"] = [kVK_Space]
        stringToKeyCodes["enter"] = [kVK_Return]
        stringToKeyCodes["up"] = [kVK_UpArrow]
        stringToKeyCodes["right"] = [kVK_RightArrow]
        stringToKeyCodes["down"] = [kVK_DownArrow]
        stringToKeyCodes["left"] = [kVK_LeftArrow]
        stringToKeyCodes["delete"] = [kVK_Delete]

        return stringToKeyCodes
    }

    private func constructCommandWithCommandKey(_ commandKey: String, handler: @escaping HotKeyHandler) {
        commandHandlers[commandKey] = userConfiguration.commandHandler(running: handler)
        userConfiguration.constructCommand(for: self, commandKey: commandKey, handler: handler)
    }

    /// Runs a command the same way its hotkey would. Returns `false` if there is no command with that key.
    @discardableResult func runCommand(_ commandKey: String) -> Bool {
        guard let handler = commandHandlers[commandKey] else {
            return false
        }

        handler()
        return true
    }

    /// What the command palette lists: every named command that is set up, except the palette itself and layouts the configuration doesn't use, with its current shortcut.
    @MainActor func commandPaletteEntries() -> [CommandPaletteEntry] {
        let hiddenLayoutCommands = CommandPalette.unconfiguredLayoutCommands(
            availableLayoutKeys: LayoutType<Application.Window>.availableLayoutStrings().map { $0.key },
            configuredLayoutKeys: userConfiguration.layoutKeys()
        )
        let listed = Set(commandHandlers.keys).subtracting(hiddenLayoutCommands)
        return CommandPalette.entries(from: HotKeyManager.hotKeyNameToDefaultsKey(), registered: listed) { commandKey in
            KeyboardShortcuts.getShortcut(for: KeyboardShortcuts.Name(commandKey))?.description
        }
    }

    private func carbonModifiersFromModifiers(_ modifiers: UInt) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        if (modifiers & UInt(NSEvent.ModifierFlags.shift.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(shiftKey)
        }

        if (modifiers & UInt(NSEvent.ModifierFlags.command.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(cmdKey)
        }

        if (modifiers & UInt(NSEvent.ModifierFlags.option.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(optionKey)
        }

        if (modifiers & UInt(NSEvent.ModifierFlags.control.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(controlKey)
        }

        return carbonModifiers
    }

    /// Display names by command key, for every command that is set up. Commands 1–4 are listed only when there are custom layouts.
    static func hotKeyNameToDefaultsKey(customLayoutKeys: [String] = LayoutType<Application.Window>.customLayoutKeys()) -> [[String]] {
        var hotKeyNameToDefaultsKey: [[String]] = []

        hotKeyNameToDefaultsKey.append(["Cycle layout forward", CommandKey.cycleLayoutForward.rawValue])
        hotKeyNameToDefaultsKey.append(["Cycle layout backwards", CommandKey.cycleLayoutBackward.rawValue])
        hotKeyNameToDefaultsKey.append(["Shrink main pane", CommandKey.shrinkMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Expand main pane", CommandKey.expandMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Increase main pane count", CommandKey.increaseMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Decrease main pane count", CommandKey.decreaseMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Increase window max count", CommandKey.increaseWindowMaxCount.rawValue])
        hotKeyNameToDefaultsKey.append(["Decrease window max count", CommandKey.decreaseWindowMaxCount.rawValue])
        if !customLayoutKeys.isEmpty {
            hotKeyNameToDefaultsKey.append(["Custom layout command 1", CommandKey.command1.rawValue])
            hotKeyNameToDefaultsKey.append(["Custom layout command 2", CommandKey.command2.rawValue])
            hotKeyNameToDefaultsKey.append(["Custom layout command 3", CommandKey.command3.rawValue])
            hotKeyNameToDefaultsKey.append(["Custom layout command 4", CommandKey.command4.rawValue])
        }
        hotKeyNameToDefaultsKey.append(["Move focus counter clockwise", CommandKey.focusCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Move focus clockwise", CommandKey.focusCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Move focus to main window", CommandKey.focusMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window counter clockwise", CommandKey.swapCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window clockwise", CommandKey.swapCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window with main window", CommandKey.swapMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Force windows to be reevaluated", CommandKey.reevaluateWindows.rawValue])

        hotKeyNameToDefaultsKey.append(["Toggle float for focused window", CommandKey.toggleFloat.rawValue])
        hotKeyNameToDefaultsKey.append(["Display current layout", CommandKey.displayCurrentLayout.rawValue])
        hotKeyNameToDefaultsKey.append(["Toggle focus follows mouse", CommandKey.toggleFocusFollowsMouse.rawValue])
        hotKeyNameToDefaultsKey.append(["Toggle global tiling", CommandKey.toggleTiling.rawValue])
        hotKeyNameToDefaultsKey.append(["Enable global tiling", CommandKey.enableTiling.rawValue])
        hotKeyNameToDefaultsKey.append(["Disable global tiling", CommandKey.disableTiling.rawValue])

        for (layoutKey, layoutName) in LayoutType<Application.Window>.availableLayoutStrings() {
            let commandName = "Select \(layoutName) layout"
            let commandKey = "select-\(layoutKey)-layout"
            hotKeyNameToDefaultsKey.append([commandName, commandKey])
        }

        hotKeyNameToDefaultsKey.append(["Cycle padding mode forward", CommandKey.cyclePaddingModeForward.rawValue])
        hotKeyNameToDefaultsKey.append(["Cycle padding mode backwards", CommandKey.cyclePaddingModeBackward.rawValue])

        for paddingMode in UserConfiguration.shared.paddingModes() {
            let commandName = "Select \(paddingMode.name) padding mode"
            let commandKey = UserConfiguration.constructPaddingModeKeyString(paddingMode.name)
            hotKeyNameToDefaultsKey.append([commandName, commandKey])
        }

        hotKeyNameToDefaultsKey.append(["Relaunch Amethyst", CommandKey.relaunchAmethyst.rawValue])
        hotKeyNameToDefaultsKey.append(["Show command palette", CommandKey.showCommandPalette.rawValue])

        return hotKeyNameToDefaultsKey
    }
}
