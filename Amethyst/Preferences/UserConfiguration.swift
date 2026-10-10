//
//  UserConfiguration.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import SwiftyJSON
import Yams

enum DefaultFloat: Equatable {
    case floating
    case notFloating

    fileprivate static func from(_ bool: Bool) -> DefaultFloat {
        return bool ? .floating : .notFloating
    }
}

protocol ConfigurationStorage {
    func object(forKey key: ConfigurationKey) -> Any?
    func array(forKey key: ConfigurationKey) -> [Any]?
    func bool(forKey key: ConfigurationKey) -> Bool
    func float(forKey key: ConfigurationKey) -> Float
    func stringArray(forKey key: ConfigurationKey) -> [String]?

    func set(_ value: Any?, forKey key: ConfigurationKey)
    func set(_ value: Bool, forKey key: ConfigurationKey)
}

extension UserDefaults: ConfigurationStorage {
    func object(forKey key: ConfigurationKey) -> Any? {
        return object(forKey: key.rawValue)
    }

    func array(forKey key: ConfigurationKey) -> [Any]? {
        return array(forKey: key.rawValue)
    }

    func bool(forKey key: ConfigurationKey) -> Bool {
        return bool(forKey: key.rawValue)
    }

    func float(forKey key: ConfigurationKey) -> Float {
        return float(forKey: key.rawValue)
    }

    func stringArray(forKey key: ConfigurationKey) -> [String]? {
        return stringArray(forKey: key.rawValue)
    }

    func set(_ value: Any?, forKey key: ConfigurationKey) {
        set(value, forKey: key.rawValue)
    }

    func set(_ value: Bool, forKey key: ConfigurationKey) {
        set(value, forKey: key.rawValue)
    }
}

enum ConfigurationKey: String {
    case layouts = "layouts"
    case commandMod = "mod"
    case commandKey = "key"
    case mod1 = "mod1"
    case mod2 = "mod2"
    case mod3 = "mod3"
    case mod4 = "mod4"
    case windowMargins = "window-margins"
    case smartWindowMargins = "smart-window-margins"
    case windowMarginSize = "window-margin-size"
    case windowMinimumHeight = "window-minimum-height"
    case windowMinimumWidth = "window-minimum-width"
    case windowMaxCount = "window-max-count"
    case floatingBundleIdentifiers = "floating"
    case floatingBundleIdentifiersIsBlacklist = "floating-is-blacklist"
    case floatingSecondaryWindows = "floating-secondary-windows"
    case ignoreMenuBar = "ignore-menu-bar"
    case floatSmallWindows = "float-small-windows"
    case smallWindowSize = "small-window-size"
    case mouseFollowsFocus = "mouse-follows-focus"
    case focusFollowsMouse = "focus-follows-mouse"
    case mouseSwapsWindows = "mouse-swaps-windows"
    case mouseResizesWindows = "mouse-resizes-windows"
    case layoutHUD = "enables-layout-hud"
    case layoutHUDOnSpaceChange = "enables-layout-hud-on-space-change"
    case windowCountHUD = "enables-window-count-hud"
    case useCanaryBuild = "use-canary-build"
    case newWindowsToMain = "new-windows-to-main"
    case followSpaceThrownWindows = "follow-space-thrown-windows"
    case windowResizeStep = "window-resize-step"
    case screenPaddingLeft = "screen-padding-left"
    case screenPaddingRight = "screen-padding-right"
    case screenPaddingTop = "screen-padding-top"
    case screenPaddingBottom = "screen-padding-bottom"
    case paddingModes = "padding-modes"
    case paddingMode = "padding-mode"
    case debugLayoutInfo = "debug-layout-info"
    case restoreLayoutsOnLaunch = "restore-layouts-on-launch"
    case disablePaddingOnBuiltinDisplay = "disable-padding-on-builtin-display"
    case hideMenuBarIcon = "hide-menu-bar-icon"
}

extension ConfigurationKey: CaseIterable {}

enum CommandKey: String {
    case cycleLayoutForward = "cycle-layout"
    case cycleLayoutBackward = "cycle-layout-backward"
    case shrinkMain = "shrink-main"
    case expandMain = "expand-main"
    case increaseMain = "increase-main"
    case decreaseMain = "decrease-main"
    case command1 = "command1"
    case command2 = "command2"
    case command3 = "command3"
    case command4 = "command4"
    case focusCCW = "focus-ccw"
    case focusCW = "focus-cw"
    case focusMain = "focus-main"
    case focusScreenCCW = "focus-screen-ccw"
    case focusScreenCW = "focus-screen-cw"
    case swapScreenCCW = "swap-screen-ccw"
    case swapScreenCW = "swap-screen-cw"
    case swapCCW = "swap-ccw"
    case swapCW = "swap-cw"
    case swapMain = "swap-main"
    case throwSpacePrefix = "throw-space"
    case focusScreenPrefix = "focus-screen"
    case throwScreenPrefix = "throw-screen"
    case throwSpaceLeft = "throw-space-left"
    case throwSpaceRight = "throw-space-right"
    case toggleFloat = "toggle-float"
    case displayCurrentLayout = "display-current-layout"
    case toggleTiling = "toggle-tiling"
    case enableTiling = "enable-tiling"
    case disableTiling = "disable-tiling"
    case reevaluateWindows = "reevaluate-windows"
    case toggleFocusFollowsMouse = "toggle-focus-follows-mouse"
    case relaunchAmethyst = "relaunch-amethyst"
    case increaseWindowMaxCount = "increase-window-max-count"
    case decreaseWindowMaxCount = "decrease-window-max-count"
    case cyclePaddingModeForward = "cycle-padding-mode"
    case cyclePaddingModeBackward = "cycle-padding-mode-backward"
}

protocol UserConfigurationDelegate: AnyObject {
    func configurationGlobalTilingDidChange(_ userConfiguration: UserConfiguration)
    func configurationAccessibilityPermissionsDidChange(_ userConfiguration: UserConfiguration)
}

class FloatingBundle: NSObject {
    @objc dynamic let id: String
    @objc dynamic let windowTitles: [String]

    init(id: String, windowTitles: [String]) {
        self.id = id
        self.windowTitles = windowTitles
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FloatingBundle else {
            return false
        }

        return other.id == id && other.windowTitles == windowTitles
    }

    func encoded() -> Any {
        return [
            "id": id,
            "window-titles": windowTitles
        ]
    }

    static func from(_ object: Any) -> FloatingBundle? {
        if let id = object as? String {
            return FloatingBundle(id: id, windowTitles: [])
        } else if let dict = object as? [String: Any] {
            var json = JSON(dict)

            if let id = json["id"].string, let windowTitles = json["window-titles"].arrayObject as? [String] {
                return FloatingBundle(id: id, windowTitles: windowTitles)
            }

            guard let key = dict.keys.first, dict.count == 1 else {
                return nil
            }

            json = json[key]

            if let windowTitles = json["window-titles"].arrayObject as? [String] {
                return FloatingBundle(id: key, windowTitles: windowTitles)
            }

            return nil
        } else {
            return nil
        }
    }
}

/// A named set of screen paddings that can be switched at runtime, e.g. to emulate a smaller display on a large one.
struct PaddingMode: Equatable {
    let name: String
    let top: CGFloat
    let bottom: CGFloat
    let left: CGFloat
    let right: CGFloat

    static func from(_ object: Any) -> PaddingMode? {
        guard let dict = object as? [String: Any] else {
            return nil
        }

        let json = JSON(dict)

        // A bare number in YAML (e.g. `name: 27`) is parsed as a number, so accept that as the name too.
        guard let name = json["name"].string ?? json["name"].number?.stringValue, !name.isEmpty else {
            return nil
        }

        return PaddingMode(
            name: name,
            top: CGFloat(json["top"].doubleValue),
            bottom: CGFloat(json["bottom"].doubleValue),
            left: CGFloat(json["left"].doubleValue),
            right: CGFloat(json["right"].doubleValue)
        )
    }
}

class UserConfiguration: NSObject {
    static let shared = UserConfiguration()
    /// Defaults key for the selected padding mode. Deliberately not a `ConfigurationKey`, so loading the configuration never overwrites it.
    static let activePaddingModeKey = "active-padding-mode"

    private let storage: ConfigurationStorage
    private let stateDefaults: UserDefaults

    weak var delegate: UserConfigurationDelegate?

    var tilingEnabled = true {
        didSet {
            delegate?.configurationGlobalTilingDidChange(self)
        }
    }
    var hasAccessibilityPermissions = true {
        didSet {
            delegate?.configurationAccessibilityPermissionsDidChange(self)
        }
    }

    var configurationYAML: [String: Any]?
    var configurationJSON: JSON?
    /// The configuration file that was loaded, if any.
    private(set) var configurationFilePath: String?
    var defaultConfiguration: JSON?

    var modifier1: AMModifierFlags?
    var modifier2: AMModifierFlags?
    var modifier3: AMModifierFlags?
    var modifier4: AMModifierFlags?

    init(storage: ConfigurationStorage, stateDefaults: UserDefaults = .standard) {
        self.storage = storage
        self.stateDefaults = stateDefaults
    }

    override convenience init() {
        self.init(storage: UserDefaults.standard)
    }

    private func configurationValueForKey<T>(_ key: ConfigurationKey, fallbackToDefault: Bool = true) -> T? {
        return configurationValue(forKeyValue: key.rawValue, fallbackToDefault: fallbackToDefault)
    }

    private func configurationValue<T>(forKeyValue keyValue: String, fallbackToDefault: Bool = true) -> T? {
        if let yamlValue = configurationYAML?[keyValue] {
            if yamlValue is NSNull {
                return nil
            } else {
                return yamlValue as? T
            }
        }

        if let jsonValue = configurationJSON?[keyValue], jsonValue.exists(), jsonValue.error == nil {
            return jsonValue.rawValue as? T
        }

        if fallbackToDefault {
            return defaultConfiguration?[keyValue].rawValue as? T
        }

        return nil
    }

    func modifierFlagsForStrings(_ modifierStrings: [String]) -> AMModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for modifierString in modifierStrings {
            switch modifierString {
            case "option":
                flags.insert(.option)
            case "shift":
                flags.insert(.shift)
            case "control":
                flags.insert(.control)
            case "command":
                flags.insert(.command)
            default:
                log.warning("Unrecognized modifier string: \(modifierString)")
            }
        }
        return flags
    }

    func load() {
        let hasAccessibilityPermissions = confirmAccessibilityPermissions()
        if self.hasAccessibilityPermissions != hasAccessibilityPermissions {
            self.hasAccessibilityPermissions = hasAccessibilityPermissions
        }
        loadConfigurationFile()
        loadConfiguration()
    }

    func loadConfiguration() {
        for key in ConfigurationKey.allCases {
            let value: Any? = configurationValueForKey(key, fallbackToDefault: false)
            let defaultValue = defaultConfiguration?[key.rawValue]
            let existingValue = storage.object(forKey: key)

            // With a configuration file, the file rules: a key it leaves out gets the built-in default (or none),
            // never a value left over from an earlier configuration or the old preferences window.
            if hasCustomConfiguration() {
                let hasDefaultConfigurationValue = (defaultValue != nil && defaultValue?.error == nil)
                storage.set(value ?? (hasDefaultConfigurationValue ? defaultValue?.rawValue : nil), forKey: key)
                continue
            }

            let hasLocalConfigurationValue = value != nil
            let hasDefaultConfigurationValue = (defaultValue != nil && defaultValue?.error == nil)
            let hasExistingValue = (existingValue != nil)

            guard hasLocalConfigurationValue || (hasDefaultConfigurationValue && !hasExistingValue) else {
                continue
            }

            storage.set(hasLocalConfigurationValue ? value : defaultValue?.rawValue, forKey: key)
        }

        for invalidMode in (storage.array(forKey: .paddingModes) ?? []) where PaddingMode.from(invalidMode) == nil {
            log.warning("Ignoring padding mode without a name: \(invalidMode)")
        }
    }

    private func yamlForConfig(at path: String) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path, isDirectory: nil) else {
            return nil
        }

        let configPath = URL(fileURLWithPath: path)

        guard let string = try? String(contentsOf: configPath) else {
            return nil
        }

        do {
            let yaml = try Yams.load(yaml: string)
            return yaml as? [String: Any]
        } catch {
            log.debug(error)
            return nil
        }
    }

    private func jsonForConfig(at path: String) -> JSON? {
        guard FileManager.default.fileExists(atPath: path, isDirectory: nil) else {
            return nil
        }

        let configPath = URL(fileURLWithPath: path)

        guard let data = try? Data(contentsOf: configPath) else {
            return nil
        }

        return try? JSON(data: data)
    }

    /// The name of the configuration files. A renamed build sets AMConfigName in its Info.plist to read its own files.
    static var configurationName: String {
        return (Bundle.main.infoDictionary?["AMConfigName"] as? String) ?? "amethyst"
    }

    /// `$XDG_CONFIG_HOME/<name>` (a file, or a directory holding `amethyst.yml`).
    static var xdgConfigurationDirectory: String {
        let xdgConfigPath = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? NSHomeDirectory().appending("/.config")
        return xdgConfigPath.appending("/\(configurationName)")
    }

    /// The configuration file to edit: the loaded one, or a new `$XDG_CONFIG_HOME/<name>/amethyst.yml` created on demand.
    func editableConfigurationFilePath() throws -> String {
        if let configurationFilePath = configurationFilePath, FileManager.default.fileExists(atPath: configurationFilePath) {
            return configurationFilePath
        }

        let directory = UserConfiguration.xdgConfigurationDirectory
        let path = directory.appending("/amethyst.yml")
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let starter = "# \(UserConfiguration.configurationName) configuration. This file is the only source of settings and key bindings.\n"
            try starter.write(toFile: path, atomically: true, encoding: .utf8)
        }
        return path
    }

    /// The app only runs on a configuration file: one that's missing or can't be read stops it. Finding the error is the editor's job.
    private func exitWithConfigurationFileError() -> Never {
        let path = configurationFilePath ?? "configuration file"
        exitWithAlert("Error in configuration file", path: path, advice: "Fix the file and start it again.")
    }

    private func exitWithMissingConfigurationFile() -> Never {
        let path = UserConfiguration.xdgConfigurationDirectory.appending("/amethyst.yml").replacingOccurrences(of: NSHomeDirectory(), with: "~")
        exitWithAlert("No configuration file found", path: path, advice: "Create it and start again.")
    }

    private func exitWithAlert(_ message: String, path: String, advice: String) -> Never {
        log.error("\(message): \(path)")

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        let appName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? "Amethyst"
        alert.informativeText = "\(path)\n\n\(appName) will quit. \(advice)"
        alert.runModal()
        exit(1)
    }

    private func loadConfigurationFile() {
        let configName = UserConfiguration.configurationName
        let amethystXDGConfigPath = UserConfiguration.xdgConfigurationDirectory
        let amethystYAMLConfigPath = NSHomeDirectory().appending("/.\(configName).yml")
        let amethystJSONConfigPath = NSHomeDirectory().appending("/.\(configName)")
        let defaultAmethystConfigPath = Bundle.main.path(forResource: "default", ofType: "amethyst")

        var isDirectory: ObjCBool = false
        /**
         Prioritiy order for config files:
         1. yml in home dir
         2. yml in xdg path
         3. json in home dir
         4. default json
         */
        if FileManager.default.fileExists(atPath: amethystYAMLConfigPath, isDirectory: &isDirectory) {
            configurationFilePath = amethystYAMLConfigPath
            configurationYAML = yamlForConfig(at: amethystYAMLConfigPath)

            if configurationYAML == nil {
                exitWithConfigurationFileError()
            }
        } else if FileManager.default.fileExists(atPath: amethystXDGConfigPath, isDirectory: &isDirectory) {
            configurationFilePath = isDirectory.boolValue ? amethystXDGConfigPath.appending("/amethyst.yml") : amethystXDGConfigPath
            configurationYAML = yamlForConfig(at: configurationFilePath!)

            if configurationYAML == nil {
                exitWithConfigurationFileError()
            }
        } else if FileManager.default.fileExists(atPath: amethystJSONConfigPath, isDirectory: &isDirectory) {
            configurationFilePath = amethystJSONConfigPath
            configurationJSON = jsonForConfig(at: amethystJSONConfigPath)

            if configurationJSON == nil {
                exitWithConfigurationFileError()
            }
        } else {
            exitWithMissingConfigurationFile()
        }

        defaultConfiguration = jsonForConfig(at: defaultAmethystConfigPath ?? "")
        if defaultConfiguration == nil {
            log.error("error loading default configuration")

            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error loading default configuration"
            alert.runModal()
        }

        let mod1Strings: [String] = configurationValueForKey(.mod1) ?? []
        let mod2Strings: [String] = configurationValueForKey(.mod2) ?? []
        let mod3Strings: [String]? = configurationValueForKey(.mod3)
        let mod4Strings: [String]? = configurationValueForKey(.mod4)

        modifier1 = modifierFlagsForStrings(mod1Strings)
        modifier2 = modifierFlagsForStrings(mod2Strings)

        if modifier1 == nil || modifier1!.isEmpty {
            log.error("error loading a mod1")

            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error loading mod1"
            alert.runModal()
        }

        if modifier2 == nil || modifier2!.isEmpty {
            log.error("error loading a mod2")

            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error loading mod2"
            alert.runModal()
        }

        if let mod3Strings = mod3Strings {
            modifier3 = modifierFlagsForStrings(mod3Strings)
        }

        if let mod4Strings = mod4Strings {
            modifier4 = modifierFlagsForStrings(mod4Strings)
        }
    }

    static func constructLayoutKeyString(_ layoutKey: String) -> String {
        return "select-\(layoutKey)-layout"
    }

    static func constructPaddingModeKeyString(_ paddingModeName: String) -> String {
        return "select-\(paddingModeName)-padding-mode"
    }

    /**
     Registers a command's hotkey. Only the configuration file binds keys: a command it leaves out, sets to `false` or binds to `<NONE>` has no hotkey, and there are no built-in default keys. Shortcuts stored by earlier versions (e.g. recorded in the old preferences window) are always replaced.
     */
    func constructCommand(for hotKeyRegistrar: HotKeyRegistrar, commandKey: String, handler: @escaping HotKeyHandler) {
        let command: [String: Any]? = configurationValue(forKeyValue: commandKey, fallbackToDefault: false)
        // `key: 1` is a number in YAML, so accept any scalar as the key.
        let keyString = command?[ConfigurationKey.commandKey.rawValue].map { "\($0)" }
        let modifierString = command?[ConfigurationKey.commandMod.rawValue] as? String

        var modifiers: AMModifierFlags?
        switch modifierString {
        case "mod1"?:
            modifiers = modifier1
        case "mod2"?:
            modifiers = modifier2
        case "mod3"?:
            modifiers = modifier3
        case "mod4"?:
            modifiers = modifier4
        case nil, "<NONE>"?:
            modifiers = nil
        case let unknown?:
            log.warning("Unknown modifier \(unknown) for \(commandKey); leaving it unbound")
            modifiers = nil
        }

        hotKeyRegistrar.registerHotKey(
            with: modifiers == nil ? nil : keyString,
            modifiers: modifiers,
            handler: commandHandler(running: handler),
            defaultsKey: commandKey,
            override: true
        )
    }

    /// Wraps a command's handler the way every command runs, from a hotkey or otherwise: confirm Accessibility permissions, then run off the main thread.
    func commandHandler(running handler: @escaping HotKeyHandler) -> HotKeyHandler {
        return { [weak self] in
            guard let `self` = self else {
                return
            }

            let hasAccessibilityPermissions = self.confirmAccessibilityPermissions()

            if self.hasAccessibilityPermissions != hasAccessibilityPermissions {
                self.hasAccessibilityPermissions = hasAccessibilityPermissions
            }

            guard hasAccessibilityPermissions else {
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                handler()
            }
        }
    }

    func hasCustomConfiguration() -> Bool {
        return configurationYAML != nil || configurationJSON != nil
    }

    func layoutKeys() -> [String] {
        let layoutKeys = storage.array(forKey: .layouts) as? [String]
        return layoutKeys ?? []
    }

    func setLayoutKeys(_ layoutKeys: [String]) {
        storage.set(layoutKeys as Any?, forKey: .layouts)
    }

    func runningApplication(_ runningApplication: BundleIdentifiable, byDefaultFloatsForTitle title: String?) -> Reliable<DefaultFloat> {
        let useIdentifiersAsBlacklist = floatingBundleIdentifiersIsBlacklist()

        // If the application is in the floating list we need to continue to check title
        // Otherwise
        //   - Blacklist means not floating
        //   - Whitelist menas floating
        guard let floatingBundle = runningApplicationFloatingBundle(runningApplication) else {
            return .reliable(DefaultFloat.from(!useIdentifiersAsBlacklist))
        }

        // If the window list is empty then all windows are included in the list
        //   - Blacklist means floating
        //   - Whitelist means not floating
        if floatingBundle.windowTitles.isEmpty {
            return .reliable(DefaultFloat.from(useIdentifiersAsBlacklist))
        }

        // If the title is `nil` then we cannot make a determination so we fall back to the default. However, we have to treat this value as unreliable as the window could have just been created and be in the process of loading.
        guard let title = title else {
            return .unreliable(DefaultFloat.from(!useIdentifiersAsBlacklist))
        }

        // If the title matches it is included
        //   - Blacklist means floating
        //   - Whitelist means not floating
        if floatingBundle.windowTitles.contains(where: { windowTitle in
            if title.range(of: windowTitle, options: .regularExpression) != nil {
                return true
            } else {
                return false
            }
        }) {
            return .reliable(DefaultFloat.from(useIdentifiersAsBlacklist))
        }

        // Otherwise the window is not included
        //   - Blacklist means not floating
        //   - Whitelist means floating
        let defaultFloat = DefaultFloat.from(!useIdentifiersAsBlacklist)

        // If the title is empty the window could have just been created and in the process of loading. Our float determination could still be correct, but to account for the potential change we mark it as unreliable.
        if title.isEmpty {
            return .unreliable(defaultFloat)
        }

        return .reliable(defaultFloat)
    }

    func runningApplicationFloatingBundle(_ runningApplication: BundleIdentifiable) -> FloatingBundle? {
        return floatingBundles().first { floatingBundle in
            UserConfiguration.bundleIdentifier(runningApplication.bundleIdentifier, matches: floatingBundle.id)
        }
    }

    /// Whether the application is listed in `floating-secondary-windows`, i.e. only its first window on a space tiles and its other windows float.
    func floatsSecondaryWindows(of runningApplication: BundleIdentifiable) -> Bool {
        let patterns = storage.stringArray(forKey: .floatingSecondaryWindows) ?? []
        return patterns.contains { UserConfiguration.bundleIdentifier(runningApplication.bundleIdentifier, matches: $0) }
    }

    /// Matches a bundle identifier against an application id from the configuration: exactly, or as a glob when the id contains `*`.
    private static func bundleIdentifier(_ bundleIdentifier: String?, matches pattern: String) -> Bool {
        guard pattern.contains("*") else {
            return pattern == bundleIdentifier
        }

        let bundleIdentifier = bundleIdentifier ?? ""
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")

        guard let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$", options: []) else {
            return false
        }

        let fullRange = NSRange(location: 0, length: bundleIdentifier.count)
        return regex.firstMatch(in: bundleIdentifier, options: [], range: fullRange) != nil
    }

    func ignoreMenuBar() -> Bool {
        return storage.bool(forKey: .ignoreMenuBar)
    }

    func floatSmallWindows() -> Bool {
        return storage.bool(forKey: .floatSmallWindows)
    }

    func smallWindowSize() -> CGFloat {
        let size = CGFloat(storage.float(forKey: .smallWindowSize))
        return size > 0 ? size : 500
    }

    func mouseFollowsFocus() -> Bool {
        return storage.bool(forKey: .mouseFollowsFocus)
    }

    func focusFollowsMouse() -> Bool {
        return storage.bool(forKey: .focusFollowsMouse)
    }

    func toggleFocusFollowsMouse() {
        storage.set(!focusFollowsMouse(), forKey: .focusFollowsMouse)
    }

    func mouseSwapsWindows() -> Bool {
        return storage.bool(forKey: .mouseSwapsWindows)
    }

    func mouseResizesWindows() -> Bool {
        return storage.bool(forKey: .mouseResizesWindows)
    }

    func enablesLayoutHUD() -> Bool {
        return storage.bool(forKey: .layoutHUD)
    }

    func enablesLayoutHUDOnSpaceChange() -> Bool {
        return storage.bool(forKey: .layoutHUDOnSpaceChange)
    }

    func enablesWindowCountHUD() -> Bool {
        return storage.bool(forKey: .windowCountHUD)
    }

    func useCanaryBuild() -> Bool {
        return storage.bool(forKey: .useCanaryBuild)
    }

    func windowMarginSize() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowMarginSize))
    }

    func windowMargins() -> Bool {
        if !storage.bool(forKey: .windowMargins) {
            return false
        }
        // if smartWindowMargins is not enabled, enable window margins
        if !smartWindowMargins() {
            return true
        }
        // if smartWindowMargins is enabled, enabled window margins if there are more than one visible windows on screen
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let infoList = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return true
        }
        let visibleWindows = infoList.filter { ($0["kCGWindowLayer"] as? Int) == 0 }
        return visibleWindows.count > 1
    }

    func smartWindowMargins() -> Bool {
        return storage.bool(forKey: .smartWindowMargins)
    }

    func windowMinimumHeight() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowMinimumHeight))
    }

    func windowMinimumWidth() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowMinimumWidth))
    }

    func windowMaxCount() -> Int? {
        let int = Int(storage.float(forKey: .windowMaxCount))
        return int == 0 ? nil : int
    }

    private func setConfigurationValueWithKVO(_ value: Any?, forKey key: ConfigurationKey) {
        if let userDefaults = storage as? UserDefaults {
            userDefaults.willChangeValue(forKey: key.rawValue)
            userDefaults.set(value, forKey: key)
            userDefaults.didChangeValue(forKey: key.rawValue)
        } else {
            storage.set(value, forKey: key)
        }
    }

    func increaseWindowMaxCount() {
        let currentCount = windowMaxCount() ?? 0
        let newCount = currentCount + 1

        setConfigurationValueWithKVO(Float(newCount), forKey: .windowMaxCount)
    }

    func decreaseWindowMaxCount() {
        let currentCount = windowMaxCount() ?? 1
        let newCount = max(0, currentCount - 1)

        setConfigurationValueWithKVO(Float(newCount), forKey: .windowMaxCount)
    }

    func windowResizeStep() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowResizeStep) / 100.0)
    }

    func screenPaddingTop() -> CGFloat {
        return activePaddingMode()?.top ?? CGFloat(storage.float(forKey: .screenPaddingTop))
    }

    func screenPaddingBottom() -> CGFloat {
        return activePaddingMode()?.bottom ?? CGFloat(storage.float(forKey: .screenPaddingBottom))
    }

    func screenPaddingLeft() -> CGFloat {
        return activePaddingMode()?.left ?? CGFloat(storage.float(forKey: .screenPaddingLeft))
    }

    func screenPaddingRight() -> CGFloat {
        return activePaddingMode()?.right ?? CGFloat(storage.float(forKey: .screenPaddingRight))
    }

    /// The configured padding modes in order. Entries without a name and repeated names are skipped.
    func paddingModes() -> [PaddingMode] {
        var names = Set<String>()
        return (storage.array(forKey: .paddingModes) ?? [])
            .compactMap { PaddingMode.from($0) }
            .filter { names.insert($0.name).inserted }
    }

    /// The selected padding mode, falling back to `padding-mode` until one has been selected. `nil` if the name matches no configured mode, in which case the plain screen paddings apply.
    func activePaddingMode() -> PaddingMode? {
        let initialMode = storage.object(forKey: .paddingMode)
        let initialName = (initialMode as? String) ?? (initialMode as? NSNumber)?.stringValue

        guard let name = stateDefaults.string(forKey: UserConfiguration.activePaddingModeKey) ?? initialName else {
            return nil
        }

        return paddingModes().first { $0.name == name }
    }

    /// Selects the padding mode with the given name. Returns the mode, or `nil` and changes nothing if no mode has that name.
    @discardableResult func selectPaddingMode(named name: String) -> PaddingMode? {
        guard let paddingMode = paddingModes().first(where: { $0.name == name }) else {
            return nil
        }

        stateDefaults.set(paddingMode.name, forKey: UserConfiguration.activePaddingModeKey)
        return paddingMode
    }

    /// Selects the next (or previous) padding mode in configuration order, wrapping around. Starts at the first (or last) mode when none is active. Returns `nil` if no modes are configured.
    @discardableResult func cyclePaddingMode(forward: Bool) -> PaddingMode? {
        let paddingModes = self.paddingModes()

        guard !paddingModes.isEmpty else {
            return nil
        }

        let nextIndex: Int
        if let activeName = activePaddingMode()?.name, let index = paddingModes.firstIndex(where: { $0.name == activeName }) {
            nextIndex = (index + (forward ? 1 : paddingModes.count - 1)) % paddingModes.count
        } else {
            nextIndex = forward ? 0 : paddingModes.count - 1
        }

        let paddingMode = paddingModes[nextIndex]
        stateDefaults.set(paddingMode.name, forKey: UserConfiguration.activePaddingModeKey)
        return paddingMode
    }

    func floatingBundleIdentifiersIsBlacklist() -> Bool {
        guard storage.object(forKey: .floatingBundleIdentifiersIsBlacklist) != nil else {
            return true
        }
        return storage.bool(forKey: .floatingBundleIdentifiersIsBlacklist)
    }

    func floatingBundles() -> [FloatingBundle] {
        guard let floatingBundles = storage.array(forKey: .floatingBundleIdentifiers) else {
            return []
        }

        return floatingBundles.compactMap { FloatingBundle.from($0) }
    }

    func setFloatingBundles(_ floatingBundles: [FloatingBundle]) {
        storage.set(floatingBundles.map { $0.encoded() }, forKey: .floatingBundleIdentifiers)
    }

    func sendNewWindowsToMainPane() -> Bool {
        return storage.bool(forKey: .newWindowsToMain)
    }

    func disablePaddingOnBuiltinDisplay() -> Bool {
        return storage.bool(forKey: .disablePaddingOnBuiltinDisplay)
    }

    func followWindowsThrownBetweenSpaces() -> Bool {
        return storage.bool(forKey: .followSpaceThrownWindows)
    }

    func restoreLayoutsOnLaunch() -> Bool {
        return storage.bool(forKey: .restoreLayoutsOnLaunch)
    }

    func hideMenuBarIcon() -> Bool {
        return storage.bool(forKey: .hideMenuBarIcon)
    }
}

extension ProcessInfo {
    /// Whether the app was launched as the host of a unit test bundle rather than to manage windows.
    var isHostingTests: Bool {
        return ["XCTestConfigurationFilePath", "XCTestSessionIdentifier", "XCTestBundlePath"].contains { environment[$0] != nil }
    }
}

extension UserConfiguration {
    @discardableResult func confirmAccessibilityPermissions() -> Bool {
        // When the app is only hosting unit tests it doesn't need Accessibility, so check without prompting.
        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: !ProcessInfo.processInfo.isHostingTests
        ]

        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
