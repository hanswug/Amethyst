//
//  WindowManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/14/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Carbon
import Foundation
import RxSwift
import Silica
import SwiftyJSON

enum TrackingError: Error {
    case unreliableFloating
    case unknownScreen
    case unknownSpace
    case alreadyTracked
}

/**
 The tolerant interval between the click and the application of a mouse move from focus.
 
 - Note:
 
 At the time of the check we confirm that the mouse is not _currently_ clicked. However, it is possible that the click happened faster than the focus notification could be processed so that when we process the focus the mouse is no longer clicked. In this case we could incorrectly move the mouse to the center of the focused window.
 
 This value is an approximation of the time between a fast click and the focus event being processed. For values larger than this we would expect the mouse to still be clicked.
 */
private let mouseMoveClickSpeedTolerance: TimeInterval = 0.3

final class WindowManager<Application: ApplicationType>: NSObject, Codable {
    typealias Window = Application.Window
    typealias Screen = Window.Screen

    struct PendingEvent {
        let screen: Screen
        let event: Change<Window>
    }

    private struct UndeterminedApplication {
        let application: NSRunningApplication
        let activationPolicyObservation: NSKeyValueObservation?
        let isFinishedLaunchingObservation: NSKeyValueObservation?

        func invalidate() {
            activationPolicyObservation?.invalidate()
            isFinishedLaunchingObservation?.invalidate()
        }
    }

    enum CodingKeys: String, CodingKey {
        case screens
        /// The window order, so a relaunch keeps who's in the main pane.
        case windowOrder
        /// Each Space's last main window, so `swap-main` from main can swap back after a relaunch.
        case lastMainWindows
    }

    /// How long after launch saved windows may still arrive in their saved place (applications answer slowly, with retries).
    private static var windowOrderRestoreTimeout: TimeInterval { 10 }

    let windowTransitionCoordinator: WindowTransitionCoordinator<WindowManager<Application>>
    let focusTransitionCoordinator: FocusTransitionCoordinator<WindowManager<Application>>

    private var applications: [pid_t: AnyApplication<Application>] = [:]
    private var applicationObservations: [pid_t: UndeterminedApplication] = [:]
    private var screens: Screens
    private let windows = Windows()
    private let focusBorder = FocusBorder()
    private var lastReflowTime = Date()
    private var lastFocusDate: Date?
    /// Windows claimed as secondary-window anchors before being tracked, with when; see `claimSecondaryWindowAnchors(among:)`.
    private var untrackedSecondaryWindowAnchors: [Window.WindowID: (window: Window, claimed: Date)] = [:]
    private var pendingTabDetection: [Window.WindowID: Window] = [:]
    private var earlyFocusedWindows: Set<Window.WindowID> = []
    private var eventQueue: [PendingEvent] = []

    private lazy var mouseStateKeeper = MouseStateKeeper(delegate: self)
    private lazy var applicationEventHandler = ApplicationEventHandler(delegate: self)
    private let userConfiguration: UserConfiguration
    private let disposeBag = DisposeBag()

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        self.screens = Screens()
        self.windowTransitionCoordinator = WindowTransitionCoordinator<WindowManager<Application>>()
        self.focusTransitionCoordinator = FocusTransitionCoordinator<WindowManager<Application>>(userConfiguration: userConfiguration)
        super.init()
        initialize()
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.screens = try values.decode(Screens.self, forKey: .screens)
        self.userConfiguration = UserConfiguration.shared
        self.windowTransitionCoordinator = WindowTransitionCoordinator<WindowManager<Application>>()
        self.focusTransitionCoordinator = FocusTransitionCoordinator<WindowManager<Application>>(userConfiguration: userConfiguration)
        super.init()

        // Saved before these were saved: windows are added as they arrive, with no last main window.
        windows.restoreOrder(try values.decodeIfPresent([SavedWindowID].self, forKey: .windowOrder) ?? [])
        let savedLastMainWindows = try values.decodeIfPresent([String: SavedWindowID].self, forKey: .lastMainWindows) ?? [:]
        windows.restoreLastMainWindows(Dictionary(
            savedLastMainWindows.compactMap { key, window in CGSSpaceID(key).map { ($0, window) } },
            uniquingKeysWith: { first, _ in first }
        ))
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.windowOrderRestoreTimeout) { [weak self] in
            self?.windows.stopRestoringOrder()
        }

        initialize()
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(screens, forKey: .screens)
        try values.encode(windows.savedOrder, forKey: .windowOrder)
        // JSON object keys are strings.
        let lastMainWindows = Dictionary(uniqueKeysWithValues: windows.savedLastMainWindows.map { (String($0.key), $0.value) })
        try values.encode(lastMainWindows, forKey: .lastMainWindows)
    }

    private func initialize() {
        windowTransitionCoordinator.target = self
        focusTransitionCoordinator.target = self

        addWorkspaceNotificationObserver(NSWorkspace.didHideApplicationNotification, selector: #selector(applicationDidHide(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.didUnhideApplicationNotification, selector: #selector(applicationDidUnhide(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.activeSpaceDidChangeNotification, selector: #selector(activeSpaceDidChange(_:)))
        // Some apps don't post their own accessibility activation notification. Without a reflow,
        // layouts that track focus (BSP) miss a click into another app.
        addWorkspaceNotificationObserver(NSWorkspace.didActivateApplicationNotification, selector: #selector(applicationActivated(_:)))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        installApplicationMonitor()

        reevaluateWindows()
        screens.updateScreens(windowManager: self)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    func reset() {
        screens = Screens()
        reevaluateWindows()
        screens.updateScreens(windowManager: self)
    }

    private func addWorkspaceNotificationObserver(_ name: NSNotification.Name, selector: Selector) {
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(self, selector: selector, name: name, object: nil)
    }

    @objc func applicationActivated(_ sender: AnyObject) {
        updateFocusBorder()
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return
        }
        markScreenForReflow(screen, afterFocusChange: true)
//        doMouseFollowsFocus(focusedWindow: focusedWindow)
    }

    @objc func applicationDidLaunch(_ notification: Notification) {
        guard let launchedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        add(runningApplication: launchedApplication)
    }

    @objc func applicationDidTerminate(_ notification: Notification) {
        guard let terminatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithPID(terminatedApplication.processIdentifier) else {
            return
        }

        remove(application: application)
    }

    @objc func applicationDidHide(_ notification: Notification) {
        guard let hiddenApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithPID(hiddenApplication.processIdentifier) else {
            return
        }

        deactivate(application: application)
    }

    @objc func applicationDidUnhide(_ notification: Notification) {
        guard let unhiddenApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithPID(unhiddenApplication.processIdentifier) else {
            return
        }

        application.dropWindowsCache()
        for window in application.windows() {
            add(window: window)
        }
        activate(application: application)
    }

    @objc func activeSpaceDidChange(_ notification: Notification) {
        // Update spaces across screens so that events get distributed to the correct layouts
        screens.updateSpaces()

        for pendingEvent in eventQueue {
            distributeEventToScreen(pendingEvent.screen, change: pendingEvent.event)
        }
        eventQueue.removeAll()

        pendingTabDetection.removeAll()
        earlyFocusedWindows.removeAll()

        // Focus settles a moment after the Space changes.
        updateFocusBorder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateFocusBorder()
        }

        for runningApplication in NSWorkspace.shared.runningApplications {
            let pid = runningApplication.processIdentifier
            guard let application = applicationWithPID(pid) else {
                continue
            }

            application.dropWindowsCache()

            for window in application.windows() {
                add(window: window)
            }
        }

        windows.regenerateActiveIDCache()
        markAllScreensForReflow()
    }

    @objc func screenParametersDidChange(_ notification: Notification) {
        screens.updateScreens(windowManager: self)
    }
}

extension WindowManager: ApplicationEventHandlerDelegate {
    private func installApplicationMonitor() {
        let target = GetApplicationEventTarget()
        let launchedEventSpec = EventTypeSpec(eventClass: OSType(kEventClassApplication), eventKind: OSType(kEventAppLaunched))
        let terminatedEventSpec = EventTypeSpec(eventClass: OSType(kEventClassApplication), eventKind: OSType(kEventAppTerminated))
        var eventSpecs = [launchedEventSpec, terminatedEventSpec]
        let eventHandler = UnsafeMutableRawPointer(Unmanaged.passUnretained(applicationEventHandler).toOpaque())
        let error = InstallEventHandler(target, applicationEventHandlerUPP, 2, &eventSpecs, eventHandler, nil)

        if error != noErr {
            log.error("error installing app launch monitor: \(error)")
        }
    }

    func add(applicationWithPID pid: pid_t) {
        guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
            log.warning("process launched with no application: \(pid)")
            return
        }

        add(runningApplication: runningApplication)
    }

    func remove(applicationWithPID pid: pid_t) {
        guard let application = applicationWithPID(pid) else {
            log.warning("process terminated with no application: \(pid)")
            return
        }

        remove(application: application)
    }
}

extension WindowManager {
    func focusedScreenManager() -> ScreenManager<WindowManager<Application>>? {
        return screens.focusedScreenManager()
    }

    fileprivate func applicationWithPID(_ pid: pid_t) -> AnyApplication<Application>? {
        return applications[pid]
    }

    fileprivate func add(application: AnyApplication<Application>) {
        guard applications[application.pid()] == nil else {
            let applicationWindows = application.windows()
            claimSecondaryWindowAnchors(among: applicationWindows, of: application)
            for window in applicationWindows {
                add(window: window)
            }
            return
        }

        ApplicationObservation(application: application, delegate: self)
            .addObservers()
            .subscribe(
                onCompleted: { [weak self] in
                    self?.applications[application.pid()] = application

                    let applicationWindows = application.windows()
                    self?.claimSecondaryWindowAnchors(among: applicationWindows, of: application)
                    for window in applicationWindows {
                        self?.add(window: window)
                    }
                }
            )
            .disposed(by: disposeBag)
    }

    fileprivate func remove(application: AnyApplication<Application>) {
        // Use the windows we track, not the app's: its window list is a stale cache, and a quit app can't be asked.
        for window in windows.windows(forApplicationWithPID: application.pid()) {
            remove(window: window)
        }
        applications.removeValue(forKey: application.pid())
    }

    fileprivate func activate(application: AnyApplication<Application>) {
        windows.activateApplication(withPID: application.pid())
        windows.regenerateActiveIDCache()
        markAllScreensForReflow()
    }

    fileprivate func deactivate(application: AnyApplication<Application>) {
        windows.deactivateApplication(withPID: application.pid())
        markAllScreensForReflow()
    }

    fileprivate func remove(window: Window) {
        log.debug("Removing window: \(window)")
        pendingTabDetection.removeValue(forKey: window.id())
        earlyFocusedWindows.remove(window.id())
        distributeEventToAllScreens(.remove(window: window))
        markAllScreensForReflow()
        windows.regenerateActiveIDCache()
        releaseSecondaryWindowAnchor(window)
        windows.remove(window: window)
    }

    func toggleFloatForFocusedWindow() {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return
        }

        guard windows.windows(onScreen: screen).contains(focusedWindow) else {
            let windowChange: Change<Window> = .add(window: focusedWindow)
            add(window: focusedWindow)
            guard windows.window(withID: focusedWindow.id()) != nil else {
                return
            }
            setFloating(false, forWindow: focusedWindow, reason: .toggled)
            claimSecondaryWindowAnchorIfFree(focusedWindow)
            distributeEventToScreen(screen, change: windowChange)
            markScreenForReflow(screen)
            return
        }

        let windowChange: Change = windows.isWindowFloating(focusedWindow) ? .add(window: focusedWindow) : .remove(window: focusedWindow)
        setFloating(!windows.isWindowFloating(focusedWindow), forWindow: focusedWindow, reason: .toggled)
        // Floating the anchor keeps it the anchor; tiling a secondary only makes it the anchor if there is none.
        claimSecondaryWindowAnchorIfFree(focusedWindow)
        distributeEventToScreen(screen, change: windowChange)
        markScreenForReflow(screen)
    }

    /// Shows in a HUD whether the focused window tiles, floats or isn't managed, and why, and logs it.
    func explainFocusedWindow() {
        let focusedWindow = Window.currentlyFocused()
        let text = focusedWindow.map { WindowExplanation.text(for: explanationInput(for: $0)) } ?? (title: "No focused window", description: "")

        if let focusedWindow {
            let applicationName = NSRunningApplication(processIdentifier: focusedWindow.pid())?.localizedName ?? "pid \(focusedWindow.pid())"
            log.info("Explain window: \(applicationName) \"\(focusedWindow.title() ?? "")\" · \(text.title) · \(text.description)")
        }

        DispatchQueue.main.async {
            let screenManager = self.focusedScreenManager() ?? self.screens.screenManagers.first
            screenManager?.displayCustomHUD(title: text.title, description: text.description, duration: 3)
        }
    }

    private func explanationInput(for window: Window) -> WindowExplanation.Input {
        guard window.shouldBeManaged() else {
            return WindowExplanation.Input(state: .notStandard)
        }

        guard windows.isWindowTracked(window) else {
            return WindowExplanation.Input(state: .notTracked)
        }

        var input = WindowExplanation.Input(
            state: windows.isWindowFloating(window) ? .floating : .tiled,
            reason: windows.placementReason(for: window)
        )
        input.floatingIsAllowList = !userConfiguration.floatingBundleIdentifiersIsBlacklist()
        input.tilingEnabled = userConfiguration.tilingEnabled
        input.isSecondaryWindowAnchor = windows.secondaryWindowAnchors.slot(anchoredBy: window.id()) != nil
        input.windowMaxCount = userConfiguration.windowMaxCount()

        if let screen = window.screen() {
            input.tiledCount = windows.activeWindows(onScreen: screen).count
            let screenManager = screens.screenManagers.first { $0.screen?.screenID() == screen.screenID() }
            input.isFloatingLayout = screenManager?.currentLayout?.layoutKey == FloatingLayout<Window>.layoutKey
        }

        return input
    }

    func distributeEventToScreen(_ screen: Screen, change: Change<Window>) {
        screens.distributeEventToScreen(screen, change: change)
    }

    func distributeEventToAllScreens(_ change: Change<Window>) {
        screens.distributeEventToAllScreens(change: change)
    }

    func markScreenForReflow(_ screen: Screen, afterFocusChange: Bool = false) {
        screens.markScreenForReflow(screen, afterFocusChange: afterFocusChange)
    }

    func markAllScreensForReflow() {
        screens.markAllScreensForReflow()
    }

    func displayCurrentLayout() {
        for screenManager in screens.screenManagers {
            screenManager.displayLayoutHUD()
        }
    }

    func displayWindowCountHUD() {
        let countText = userConfiguration.windowMaxCount().map(String.init) ?? "unlimited"
        displayWindowLimitHUD(title: "Window max count · \(countText)")
    }

    /// Shows a setting toggled from the palette (focus border, main arrival position) on every screen, with `enables-layout-hud`.
    func displaySettingHUD(title: String) {
        guard userConfiguration.enablesLayoutHUD() else {
            return
        }

        for screenManager in screens.screenManagers {
            screenManager.displayCustomHUD(title: title)
        }
    }

    /// Shows a window limit setting (the count, the overflow policy or size) on every screen, with `enables-window-count-hud`.
    func displayWindowLimitHUD(title: String, description: String = "") {
        guard userConfiguration.enablesWindowCountHUD() else {
            return
        }

        for screenManager in screens.screenManagers {
            screenManager.displayCustomHUD(title: title, description: description)
        }
    }

    func selectPaddingMode(named name: String) {
        guard let paddingMode = userConfiguration.selectPaddingMode(named: name) else {
            log.warning("Unknown padding mode: \(name)")
            return
        }

        paddingModeDidChange(to: paddingMode)
    }

    func cyclePaddingMode(forward: Bool) {
        guard let paddingMode = userConfiguration.cyclePaddingMode(forward: forward) else {
            return
        }

        paddingModeDidChange(to: paddingMode)
    }

    private func paddingModeDidChange(to paddingMode: PaddingMode) {
        // Screen paddings are read on every reflow, so reflowing applies the new mode immediately.
        markAllScreensForReflow()

        DispatchQueue.main.async {
            guard self.userConfiguration.enablesLayoutHUD() else {
                return
            }

            for screenManager in self.screens.screenManagers {
                screenManager.displayCustomHUD(title: "Padding · \(paddingMode.name)")
            }
        }
    }

    func add(runningApplication: NSRunningApplication) {
        switch runningApplication.isManageable {
        case .manageable:
            let application = AnyApplication(Application(runningApplication: runningApplication))
            add(application: application)
        case .undetermined:
            monitorUndeterminedApplication(runningApplication)
        case .unmanageable:
            break
        }
    }

    func monitorUndeterminedApplication(_ runningApplication: NSRunningApplication) {
        let pid = runningApplication.processIdentifier

        if let previousApplication = applicationObservations[pid] {
            previousApplication.invalidate()
            applicationObservations.removeValue(forKey: pid)
        }

        let activationPolicyObservation = runningApplication.observe(\.activationPolicy) { [weak self] runningApplication, change in
            guard case .setting = change.kind else {
                return
            }

            if runningApplication.activationPolicy == .regular {
                self?.applicationObservations[runningApplication.processIdentifier]?.invalidate()
                self?.applicationObservations.removeValue(forKey: runningApplication.processIdentifier)
                self?.add(runningApplication: runningApplication)
            }
        }

        let isFinishedLaunchingObservation = runningApplication.observe(\.isFinishedLaunching) { [weak self] runningApplication, change in
            guard case .setting = change.kind else {
                return
            }

            if runningApplication.isFinishedLaunching {
                self?.applicationObservations[runningApplication.processIdentifier]?.invalidate()
                self?.applicationObservations.removeValue(forKey: runningApplication.processIdentifier)
                self?.add(runningApplication: runningApplication)
            }
        }

        applicationObservations[pid] = UndeterminedApplication(
            application: runningApplication,
            activationPolicyObservation: activationPolicyObservation,
            isFinishedLaunchingObservation: isFinishedLaunchingObservation
        )
    }

    func reevaluateWindows() {
        for runningApplication in NSWorkspace.shared.runningApplications {
            add(runningApplication: runningApplication)
        }
        markAllScreensForReflow()
    }

    private func add(window: Window, afterWindow otherWindow: Window? = nil) {
        log.debug("Adding window: \(window)")
        guard window.shouldBeManaged() else {
            log.debug("Window should not be managed: \(window)")
            return
        }

        guard let application = applicationWithPID(window.pid()) else {
            log.error("Tried to add a window without an application: \(window)")
            return
        }

        defer {
            windows.regenerateActiveIDCache()
        }

        guard !windows.isWindowTracked(window) else {
            log.debug("Window was already tracked: \(window)")
            return
        }

        ApplicationObservation(application: application, delegate: self)
            .addObserversForWindow(window)
            .map { try self.determineFloatForWindow(window, application: application, force: false) }
            .retry { error in
                error.enumerated().flatMap { count, error -> Observable<Int> in
                    guard error is TrackingError, count < 6 else {
                        return .error(error)
                    }

                    log.debug("error in determining float for window: \(window) - \(error)")
                    return .timer(.milliseconds((count * count * 100)), scheduler: MainScheduler.instance)
                }
            }
            .catch { error in
                guard error is TrackingError else {
                    throw error
                }
                log.debug("forcing float for window: \(window)")
                try self.determineFloatForWindow(window, application: application, force: true)
                return .just(())
            }
            .map { try self.track(window: window, application: application, afterWindow: otherWindow) }
            .retry { error in
                error.enumerated().flatMap { count, error -> Observable<Int> in
                    guard error is TrackingError, count < 6 else {
                        return .error(error)
                    }

                    log.debug("encountered an error trying to track window: \(error)")
                    return .timer(.milliseconds((count * count * 100)), scheduler: MainScheduler.instance)
                }
            }
            .subscribe()
            .disposed(by: disposeBag)
    }

    private func determineFloatForWindow(_ window: Window, application: AnyApplication<Application>, force: Bool) throws {
        if let reason = try secondaryWindowFloatReason(window, force: force) {
            setFloating(true, forWindow: window, reason: reason)
            return
        }

        switch application.floatDecisionForWindow(window) {
        case .unreliable where !force:
            throw TrackingError.unreliableFloating
        case let .reliable(decision), let .unreliable(decision):
            setFloating(decision.float == .floating, forWindow: window, reason: decision.reason)
        }
    }

    /// Sets whether a window floats and records why, for `explain-window` and the log.
    private func setFloating(_ floating: Bool, forWindow window: Window, reason: PlacementReason) {
        windows.setFloating(floating, forWindow: window, reason: reason)

        let applicationName = NSRunningApplication(processIdentifier: window.pid())?.localizedName ?? "pid \(window.pid())"
        let reasonText = WindowExplanation.reasonText(reason, floating: floating, allowList: !userConfiguration.floatingBundleIdentifiersIsBlacklist())
        log.info("\(floating ? "Floating" : "Tiled"): \(applicationName) \"\(window.title() ?? "")\" · \(reasonText)")
    }

    /// The `floating-secondary-windows` slot of a window, or `nil` if its application isn't listed or its space is unknown.
    private func secondaryWindowSlot(for window: Window) -> SecondaryWindowAnchors<Window.WindowID>.Slot? {
        guard let runningApplication = NSRunningApplication(processIdentifier: window.pid()),
              userConfiguration.floatsSecondaryWindows(of: runningApplication),
              let space = CGWindowsInfo.windowSpace(window) else {
            return nil
        }

        return SecondaryWindowAnchors.Slot(pid: window.pid(), space: space)
    }

    /**
     Why a window floats because of `floating-secondary-windows`, or `nil` if it doesn't: it does when its application is listed and already has a live anchor on the window's space. This only ever forces floating; otherwise the regular floating rules decide.
     */
    private func secondaryWindowFloatReason(_ window: Window, force: Bool) throws -> PlacementReason? {
        guard let runningApplication = NSRunningApplication(processIdentifier: window.pid()),
              userConfiguration.floatsSecondaryWindows(of: runningApplication) else {
            return nil
        }

        guard let slot = secondaryWindowSlot(for: window) else {
            // Without a space there is no anchor to compare with. Retry, and when that keeps failing float the window:
            // a wrongly floated window costs one toggle, a wrongly tiled one reshuffles the layout.
            guard force else {
                throw TrackingError.unreliableFloating
            }
            return .secondaryWindowSpaceUnknown
        }

        guard let anchorID = windows.secondaryWindowAnchors.anchor(for: slot), anchorID != window.id() else {
            return nil
        }

        if let anchor = windows.window(withID: anchorID) {
            // Closed windows can stay tracked (not every app reports them destroyed), so ask whether it still exists.
            guard windowExists(anchor) else {
                releaseSecondaryWindowAnchor(anchor)
                return windows.secondaryWindowAnchors.anchor(for: slot) != nil ? .secondaryWindow : nil
            }
            return .secondaryWindow
        }

        // An anchor claimed up front by `claimSecondaryWindowAnchors(among:)` that isn't tracked yet. Tracking takes at most a
        // few seconds of retries; one that never gets tracked (e.g. an invisible window) must not keep the slot.
        if let untracked = untrackedSecondaryWindowAnchors[anchorID],
           windowExists(untracked.window), Date().timeIntervalSince(untracked.claimed) < 6 {
            return .secondaryWindow
        }

        windows.secondaryWindowAnchors.release(anchorID)
        untrackedSecondaryWindowAnchors.removeValue(forKey: anchorID)
        return nil
    }

    /**
     When an application's existing windows are picked up together (Amethyst starting, an application launching with restored windows) they are judged in arbitrary order, and the first tiled one would claim the anchor. Instead, claim free slots up front for the largest window per space, so e.g. a Settings window open next to the main window floats rather than tiles.
     */
    private func claimSecondaryWindowAnchors(among applicationWindows: [Window], of application: AnyApplication<Application>) {
        var largestWindows: [SecondaryWindowAnchors<Window.WindowID>.Slot: (window: Window, area: CGFloat)] = [:]

        // Only windows seen for the first time: an already tracked (e.g. floating) window never becomes the anchor this way.
        // The application's window list is cached and can still contain closed windows, so check each one still exists.
        for window in applicationWindows where !windows.isWindowTracked(window) && windowExists(window) && window.shouldBeManaged() {
            // A window the regular rules float (e.g. an Open panel) can't be the tiled anchor.
            if case .reliable(.floating) = application.defaultFloatForWindow(window) {
                continue
            }

            guard let slot = secondaryWindowSlot(for: window) else {
                continue
            }

            let frame = window.frame()
            let area = frame.width * frame.height
            if area > largestWindows[slot]?.area ?? -1 {
                largestWindows[slot] = (window, area)
            }
        }

        for (slot, candidate) in largestWindows where windows.secondaryWindowAnchors.claim(slot, for: candidate.window.id()) {
            untrackedSecondaryWindowAnchors[candidate.window.id()] = (candidate.window, Date())
            log.debug("Secondary windows: \(candidate.window) is the anchor for pid \(slot.pid) on space \(slot.space) (largest window)")
        }
    }

    /**
     Frees the slot when an anchor goes away (closed, minimised, its app quit). A window of the same application on that space that the user tiled takes over; otherwise the slot stays free until the next new window tiles. Floating secondaries never take over by themselves.
     */
    private func releaseSecondaryWindowAnchor(_ window: Window) {
        untrackedSecondaryWindowAnchors.removeValue(forKey: window.id())

        guard let slot = windows.secondaryWindowAnchors.release(window.id()) else {
            return
        }

        let successor = windows.windows(forApplicationWithPID: slot.pid).first { candidate in
            candidate.id() != window.id()
                && !windows.isWindowFloating(candidate)
                && CGWindowsInfo.windowSpace(candidate) == slot.space
                && windowExists(candidate)
        }

        if let successor = successor, windows.secondaryWindowAnchors.claim(slot, for: successor.id()) {
            log.debug("Secondary windows: \(successor) took over as anchor from \(window)")
        } else {
            log.debug("Secondary windows: anchor \(window) went away; the next new window becomes the anchor")
        }
    }

    /// Whether the window still exists, asked of the window server directly (the applications' window lists are cached).
    private func windowExists(_ window: Window) -> Bool {
        let cgID = window.cgID()
        guard cgID != kCGNullWindowID else {
            return false
        }

        return CGWindowsInfo<Window>(options: .optionIncludingWindow, windowID: cgID)?.descriptions.isEmpty == false
    }

    /// A tiled window of a listed application becomes its space's anchor if the slot is free.
    private func claimSecondaryWindowAnchorIfFree(_ window: Window) {
        untrackedSecondaryWindowAnchors.removeValue(forKey: window.id())

        guard !windows.isWindowFloating(window), let slot = secondaryWindowSlot(for: window) else {
            return
        }

        if windows.secondaryWindowAnchors.claim(slot, for: window.id()) {
            log.debug("Secondary windows: \(window) is the anchor for pid \(slot.pid) on space \(slot.space)")
        }
    }

    private func track(window: Window, application: AnyApplication<Application>, afterWindow otherWindow: Window? = nil) throws {
        guard !windows.isWindowTracked(window) else {
            log.warning("Trying to track a window that is already tracked: \(window)")
            throw TrackingError.alreadyTracked
        }

        guard let screen = window.screen() else {
            throw TrackingError.unknownScreen
        }

        guard CGWindowsInfo.windowSpace(window) != nil else {
            throw TrackingError.unknownSpace
        }

        if let otherWindow = otherWindow {
            _ = windows.replace(window: window, withWindow: otherWindow)
            distributeEventToScreen(screen, change: .tabChange(window: window, previousWindow: otherWindow))
        } else {
            windows.add(window: window, atFront: userConfiguration.mainArrivalPosition() == .first)

            // Only send .add to layouts if the window is on the currently active space.
            // Windows tracked during a space change for a different space should not
            // generate .add events — doing so gives layouts stale data for windows
            // that aren't visible on the current space.
            let windowSpace = CGWindowsInfo.windowSpace(window)
            let currentSpaceID = CGSpacesInfo<Window>.currentSpaceForScreen(screen)?.id
            let isOnCurrentSpace: Bool
            if let currentSpaceID, let windowSpace {
                isOnCurrentSpace = currentSpaceID == windowSpace
            } else {
                isOnCurrentSpace = true
            }

            if isOnCurrentSpace {
                let windowChange: Change = windows.isWindowFloating(window) ? .unknown : .add(window: window)
                distributeEventToScreen(screen, change: windowChange)
            }
        }

        claimSecondaryWindowAnchorIfFree(window)
        markScreenForReflow(screen)
    }

    /**
     This function is a best effort to detect changes between native macOS tabs.
     
     - Description:
        Each "tab" is an independent window, but the underlying system relates them in some way that we do not have access to. The heuristic is to find a window from the same application that has recently left the screen, and swap them.
     
        This performs pretty well in steady state, but can be a bit wonky when finding the existing tabs depending on how quick the transitions are.

     - Parameters:
        - window: the window that might be a tab change.
     */
    func swapInTab(window: Window) {
        guard let screen = window.screen() else {
            return
        }

        // We do this to avoid triggering tab swapping when just switching focus between apps.
        // If the window's app is not running by this point then it's not a tab switch.
        guard let runningApp = NSRunningApplication(processIdentifier: window.pid()), runningApp.isActive else {
            return
        }

        // We take the windows that are being tracked so we can properly detect when a tab switch is a new tab.
        // It is important here to compute isActive and isOnScreen as soon as possible for improved accuracy.
        let applicationWindows = windows.windows(forApplicationWithPID: window.pid())
            .map { ($0, windows.isWindowActive($0), $0.isOnScreen()) }

        var string = "\n\tNew Window: \(window)"
        applicationWindows.forEach { string += "\n\tExisting window: \($0)" }
        log.debug(string)

        for (existingWindow, isActive, isOnScreen) in applicationWindows {
            guard existingWindow != window else {
                log.debug("Windows are the same:\n\tNew: \(window)\n\t\(existingWindow)")
                continue
            }

            // The window needs to have been active _at some point_, but must not be currently on screen.
            let didLeaveScreen = (isActive || windows.isWindowActive(existingWindow)) && !existingWindow.isOnScreen()
            let isInvalid = existingWindow.cgID() == kCGNullWindowID

            log.debug("""
            Considering window: \(existingWindow)
            isActive: \(isActive), isOnScreen: \(isOnScreen), isInvalid: \(isInvalid), managed: \(existingWindow.shouldBeManaged())
            Recomputed isActive: \(windows.isWindowActive(existingWindow)), isOnScreen: \(existingWindow.isOnScreen())
            """)

            // The window needs to have either left the screen and therefore is being replaced
            // or be invalid and therefore being removed and can be replaced.
            guard didLeaveScreen || isInvalid else {
                log.debug("Window candidate discarded: \(existingWindow)")
                continue
            }

            // We have to make sure that we haven't had a focus change too recently as that could mean
            // the window is already active, but just became focused by swapping window focus.
            // The time is in seconds, and too long a time ends up with quick switches triggering tabs to incorrectly
            // swap.
            let changeInterval = lastFocusDate.flatMap { abs($0.timeIntervalSinceNow) }
            if let changeInterval = changeInterval, abs(changeInterval) < 0.1 && !isInvalid {
                log.debug("""
                Window candidate discarded: \(existingWindow)
                lastFocusChange: \(lastFocusDate?.description ?? "nil") now: \(changeInterval) isInvalid: \(isInvalid)
                """)
                continue
            }

            log.debug("Selected existing window: \(existingWindow)")

            guard windows.isWindowTracked(window) else {
                // If the window isn't tracked we add it in relation to the existing one.
                pendingTabDetection.removeValue(forKey: window.id())
                earlyFocusedWindows.remove(window.id())
                add(window: window, afterWindow: existingWindow)
                return
            }

            // If we get here, we are working with a window that has been previously added.
            // Instead of going through the whole add process, we can just swap the windows in order.
            pendingTabDetection.removeValue(forKey: window.id())
            earlyFocusedWindows.remove(window.id())
            windows.replace(window: existingWindow, withWindow: window)
            windows.regenerateActiveIDCache()

            // Note that the existing window moving out of screen will be tracked as a remove,
            // but the "adding" happens above, so we need to distribute the relevant change.
            distributeEventToScreen(screen, change: .tabChange(window: window, previousWindow: existingWindow))
            markScreenForReflow(screen)

            return
        }

        windows.regenerateActiveIDCache()
        if earlyFocusedWindows.remove(window.id()) != nil {
            // Focus notification already fired before we got here — the visual
            // transition is settled so call completeTabDetection directly.
            completeTabDetection(for: window, on: screen)
        } else {
            pendingTabDetection[window.id()] = window
        }
    }

    private func completeTabDetection(for window: Window, on screen: Screen) {
        windows.regenerateActiveIDCache()

        let applicationWindows = windows.windows(forApplicationWithPID: window.pid())

        for existingWindow in applicationWindows {
            guard existingWindow != window else { continue }

            let didLeaveScreen = windows.isWindowActive(existingWindow) && !existingWindow.isOnScreen()
            let isInvalid = existingWindow.cgID() == kCGNullWindowID

            guard didLeaveScreen || isInvalid else { continue }

            log.debug("completeTabDetection: selected candidate \(existingWindow) for \(window)")

            guard windows.isWindowTracked(window) else {
                pendingTabDetection.removeValue(forKey: window.id())
                earlyFocusedWindows.remove(window.id())
                add(window: window, afterWindow: existingWindow)
                return
            }

            pendingTabDetection.removeValue(forKey: window.id())
            earlyFocusedWindows.remove(window.id())
            windows.replace(window: existingWindow, withWindow: window)
            windows.regenerateActiveIDCache()
            distributeEventToScreen(screen, change: .tabChange(window: window, previousWindow: existingWindow))
            markScreenForReflow(screen)
            return
        }

        log.debug("completeTabDetection: no candidate found")
        add(window: window)
    }

    func onReflowInitiation() {
        mouseStateKeeper.handleReflowEvent()
    }

    func onReflowCompletion() {
//        if let focusedWindow = Window.currentlyFocused() {
//            doMouseFollowsFocus(focusedWindow: focusedWindow)
//        }

        // This handler will be executed by the Operation, in a queue.  Although async
        // (and although the docs say that it executes in a separate thread), I consider
        // this to be thread safe, at least safe enough, because we always want the
        // latest time that a reflow took place.
        mouseStateKeeper.handleReflowEvent()
        lastReflowTime = Date()
        updateFocusBorder()
    }

    func doMouseFollowsFocus(focusedWindow: Window) {
        guard UserConfiguration.shared.mouseFollowsFocus() else {
            return
        }

        guard NSEvent.pressedMouseButtons == 0 else {
            // If a mouse button is pressed, then the user is probably dragging something between windows. Do not move the mouse.
            return
        }

        // See the description of mouseMoveClickSpeedTolerance for details.
        if let interval = mouseStateKeeper.lastClick?.timeIntervalSinceNow, abs(interval) < mouseMoveClickSpeedTolerance {
            return
        }

        if focusTransitionCoordinator.recentlyTriggeredFocusFollowsMouse() {
            // If we have recently triggered focus-follows-mouse, then disable mouse-follows-focus. Otherwise, the moment
            // focus-follows-mouse is triggered, the mouse will jump to the center of the focused window.
            return
        }

        let windowFrame = focusedWindow.frame()
        let mouseCursorPoint = NSPoint(x: windowFrame.midX, y: windowFrame.midY)
        if let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left) {
            mouseMoveEvent.flags = CGEventFlags(rawValue: 0)
            mouseMoveEvent.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }
}

extension WindowManager: MouseStateKeeperDelegate {
    func recommendMainPaneRatio(_ ratio: CGFloat) {
        guard let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager() else { return }

        screenManager.updateCurrentLayout { layout in
            if let panedLayout = layout as? PanedLayout {
                panedLayout.recommendMainPaneRatio(ratio)
            }
        }
    }

    func swapDraggedWindowWithDropzone(_ draggedWindow: Window) {
        guard let screen = draggedWindow.screen() else { return }

        let windows: [Window] = self.windows.windows(onScreen: screen)

        // need to flip mouse coordinate system to fit Amethyst https://stackoverflow.com/a/45289010/2063546
        let flippedPointerLocation = NSPointToCGPoint(NSEvent.mouseLocation)
        let unflippedY = Screen.globalHeight() - flippedPointerLocation.y + screen.frameIncludingDockAndMenu().origin.y
        let pointerLocation = NSPointToCGPoint(NSPoint(x: flippedPointerLocation.x, y: unflippedY))

        if let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager(), let layout = screenManager.currentLayout {
            let windowSet = self.windows.windowSet(forWindowsOnScreen: screen)
            if let layoutWindow = layout.windowAtPoint(pointerLocation, of: windowSet, on: screen), let framedWindow = self.windows.window(withID: layoutWindow.id) {
                executeTransition(.switchWindows(draggedWindow, framedWindow))
                return
            }
        }

        // Ignore if there is no window at that point
        guard let secondWindow = WindowsInformation.alternateWindowForScreenAtPoint(pointerLocation, withWindows: windows, butNot: draggedWindow) else {
            return
        }
        executeTransition(.switchWindows(draggedWindow, secondWindow))
    }
}

// MARK: ApplicationObservationDelegate
extension WindowManager: ApplicationObservationDelegate {
    func application(_ application: AnyApplication<Application>, didAddWindow window: Window) {
        add(window: window)
    }

    func application(_ application: AnyApplication<Application>, didRemoveWindow window: Window) {
        remove(window: window)
        updateFocusBorder()
    }

    func application(_ application: AnyApplication<Application>, didFocusWindow window: Window) {
        defer { updateFocusBorder() }

        guard let screen = window.screen() else {
            return
        }

        lastFocusDate = Date()

        if pendingTabDetection.removeValue(forKey: window.id()) != nil {
            completeTabDetection(for: window, on: screen)
        } else if windows.isWindowTracked(window) {
            windows.recordFocus(of: window)
            distributeEventToScreen(screen, change: .focusChanged(window: window))
            markScreenForReflow(screen, afterFocusChange: true)
        } else {
            // Focus notification arrived before the creation notification.
            // Record this so swapInTab can call completeTabDetection immediately
            // rather than deferring to a focus event that has already passed.
            log.debug("Focused untracked window before creation notification - recording early focus: \(window)")
            earlyFocusedWindows.insert(window.id())
        }

//        doMouseFollowsFocus(focusedWindow: window)
    }

    func application(_ application: AnyApplication<Application>, didFindPotentiallyNewWindow window: Window) {
        guard !windows.isWindowTracked(window) else {
            return
        }

        swapInTab(window: window)
    }

    func application(_ application: AnyApplication<Application>, didMoveWindow window: Window) {
        moveFocusBorder(with: window)

        guard userConfiguration.mouseSwapsWindows() else {
            return
        }

        guard let screen = window.screen(), activeWindows(on: screen).contains(window) else {
            return
        }

        switch mouseStateKeeper.state {
        case .dragging:
            // be aware of last reflow time, again to prevent race condition
            let reflowEndInterval = Date().timeIntervalSince(lastReflowTime)
            guard reflowEndInterval > mouseStateKeeper.dragRaceThresholdSeconds else { break }

            // record window and wait for mouse up
            mouseStateKeeper.state = .moving(window: window)
        case let .doneDragging(lmbUpMoment):
            mouseStateKeeper.state = .pointing // flip state first to prevent race condition

            // if mouse button recently came up, assume window move is related
            let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
            guard dragEndInterval < mouseStateKeeper.dragRaceThresholdSeconds else { break }

            mouseStateKeeper.swapDraggedWindowWithDropzone(window)
        default:
            break
        }
    }

    func application(_ application: AnyApplication<Application>, didResizeWindow window: Window) {
        moveFocusBorder(with: window)

        guard userConfiguration.mouseResizesWindows() else {
            return
        }

        guard let screen = window.screen(), activeWindows(on: screen).contains(window) else {
            return
        }

        guard
            let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager(),
            let layout = screenManager.currentLayout,
            layout is PanedLayout
        else {
            return
        }

        guard let oldFrame = layout.assignedFrame(window, of: windows.windowSet(forActiveWindowsOnScreen: screen), on: screen) else {
            return
        }

        let ratio = oldFrame.impliedMainPaneRatio(windowFrame: window.frame())

        switch mouseStateKeeper.state {
        case .dragging, .resizing:
            // record window and wait for mouse up
            mouseStateKeeper.state = .resizing(screen: screen, ratio: ratio)
        case let .doneDragging(lmbUpMoment):
            // if mouse button recently came up, assume window resize is related
            let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
            if dragEndInterval < mouseStateKeeper.dragRaceThresholdSeconds {
                mouseStateKeeper.state = .pointing // flip state first to prevent race condition

                if let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager() {
                    screenManager.updateCurrentLayout { layout in
                        if let panedLayout = layout as? PanedLayout {
                            panedLayout.recommendMainPaneRatio(ratio)
                        }
                    }
                }
            }
        default:
            break
        }
    }

    func applicationDidActivate(_ application: AnyApplication<Application>) {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(applicationActivated(_:)),
            object: nil
        )
        perform(#selector(applicationActivated(_:)), with: nil, afterDelay: 0.2)
    }
}

// MARK: Transition Coordination
extension WindowManager {
    func screen(at index: Int) -> Screen? {
        return screenManager(at: index)?.screen
    }

    func screenManager(at screenIndex: Int) -> ScreenManager<WindowManager<Application>>? {
        guard screenIndex > -1 && screenIndex < screens.screenManagers.count else {
            return nil
        }

        return screens.screenManagers[screenIndex]
    }

    func screenManager(for screen: Screen) -> ScreenManager<WindowManager<Application>>? {
        return screens.screenManagers.first { $0.screen?.screenID() == screen.screenID() }
    }

    func screenManagerIndex(for screen: Screen) -> Int? {
        return screens.screenManagers.firstIndex { $0.screen?.screenID() == screen.screenID() }
    }
}

// MARK: Window Transition
extension WindowManager: WindowTransitionTarget {
    func executeTransition(_ transition: WindowTransition<Window>) {
        switch transition {
        case let .switchWindows(window, otherWindow):
            guard windows.swap(window: window, withWindow: otherWindow) else {
                return
            }

            distributeEventToAllScreens(.windowSwap(window: window, otherWindow: otherWindow))
            markAllScreensForReflow()
        case let .moveWindowToScreen(window, screen):
            let currentScreen = window.screen()
            window.moveScaled(to: screen)
            if currentScreen != nil {
                distributeEventToScreen(screen, change: .remove(window: window))
                markScreenForReflow(screen)
            }
            distributeEventToScreen(screen, change: .add(window: window))
            window.focus()
        case let .moveWindowToSpaceAtIndex(window, spaceIndex, sourceSpaceIndex):
            guard
                let screen = window.screen(),
                let spaces = CGSpacesInfo<Window>.spacesForAllScreens(includeOnlyUserSpaces: true),
                spaceIndex < spaces.count
            else {
                return
            }

            let targetSpace = spaces[spaceIndex]
            guard let targetScreen = CGSpacesInfo<Window>.screenForSpace(space: targetSpace) else {
                return
            }
            distributeEventToScreen(screen, change: .remove(window: window))
            eventQueue.append(PendingEvent(screen: targetScreen, event: .add(window: window)))
            window.move(toSpaceAtIndex: UInt(spaceIndex + 1))
            if targetScreen.screenID() != screen.screenID() {
                // necessary to set frame here as window is expected to be at origin relative to targe screen when moved, can be improved.
                window.moveScaled(to: targetScreen)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if !UserConfiguration.shared.followWindowsThrownBetweenSpaces() {
                    SISystemWideElement.switch(toSpace: UInt(sourceSpaceIndex + 1))
                }
            }
        case .resetFocus:
            if let screen = screens.screenManagers.first?.screen {
                executeTransition(.focusScreen(screen))
            }
        }
    }

    func isWindowFloating(_ window: Window) -> Bool {
        return windows.isWindowFloating(window)
    }

    func currentLayout() -> Layout<Application.Window>? {
        return focusedScreenManager()?.currentLayout
    }

    func activeWindows(on screen: Screen) -> [Window] {
        return windows.activeWindows(onScreen: screen).filter { window in
            return window.shouldBeManaged() && !self.windows.isWindowFloating(window)
        }
    }

    func nextScreenIndexClockwise(from screen: Screen) -> Int {
        guard let screenManagerIndex = self.screenManagerIndex(for: screen) else {
            return -1
        }

        return (screenManagerIndex + 1) % (screens.screenManagers.count)
    }

    func nextScreenIndexCounterClockwise(from screen: Screen) -> Int {
        guard let screenManagerIndex = self.screenManagerIndex(for: screen) else {
            return -1
        }

        return (screenManagerIndex == 0 ? screens.screenManagers.count - 1 : screenManagerIndex - 1)
    }

    func lastMainWindowForCurrentSpace() -> Window? {
        guard let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
              let lastMainWindow = windows.lastMainWindows[currentFocusedSpace.id]
        else {
            return nil
        }
        return lastMainWindow
    }
}

// MARK: Directional Navigation
extension WindowManager {
    /// The tiled window in `direction` from `window` on its screen, or `nil` at the edge. A floating window starts from its live frame.
    func directionalNeighbor(of window: Window, toward direction: Direction) -> Window? {
        guard let screen = window.screen(), let screenManager = screenManager(for: screen) else {
            return nil
        }

        let assignedFrames = screenManager.lastAssignedFrames
        let candidates = activeWindows(on: screen).filter { $0.id() != window.id() }
        let frames = Dictionary(
            candidates.compactMap { candidate in assignedFrames[candidate.id()].map { (candidate.id(), $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        let start = isWindowFloating(window) ? window.frame() : (assignedFrames[window.id()] ?? window.frame())
        let mru = CGWindowsInfo.windowSpace(window).flatMap { windows.recentlyFocused[$0] } ?? []

        guard let neighborID = DirectionalNavigation.neighbor(
            of: start,
            direction: direction,
            frames: frames,
            frontToBack: frontToBack(candidates),
            mru: mru
        ) else {
            return nil
        }

        return candidates.first { $0.id() == neighborID }
    }

    /// The window's frame in the last layout pass, before margins.
    func assignedFrame(of window: Window) -> CGRect? {
        guard let screen = window.screen() else {
            return nil
        }

        return screenManager(for: screen)?.lastAssignedFrames[window.id()]
    }

    func isFullscreenLayout(on screen: Screen) -> Bool {
        return screenManager(for: screen)?.currentLayout is FullscreenLayout<Window>
    }

    /// The windows' IDs in on-screen order, frontmost first.
    private func frontToBack(_ windows: [Window]) -> [Window.WindowID] {
        guard let info = CGWindowsInfo<Window>(options: .optionOnScreenOnly, windowID: CGWindowID(0)) else {
            return []
        }

        let idsByCGID = Dictionary(windows.map { ($0.cgID(), $0.id()) }, uniquingKeysWith: { first, _ in first })
        return info.descriptions.compactMap { description in
            (description[kCGWindowNumber as String] as? NSNumber).flatMap { idsByCGID[CGWindowID($0.uint32Value)] }
        }
    }
}

// MARK: Focus Border
extension WindowManager {
    /// Puts the focus border around the focused window, or hides it: when it's off, for windows Ametrine doesn't manage,
    /// in native full screen, and for tiled windows in the Fullscreen layout.
    func updateFocusBorder() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.updateFocusBorder() }
            return
        }

        guard userConfiguration.focusBorder(),
              let window = Window.currentlyFocused(),
              windows.isWindowTracked(window),
              !windows.isWindowHidden(window),
              let screen = window.screen(),
              CGSpacesInfo<Window>.currentSpaceForScreen(screen)?.type == CGSSpaceTypeUser,
              windows.isWindowFloating(window) || !isFullscreenLayout(on: screen)
        else {
            focusBorder.hide()
            return
        }

        focusBorder.show(
            around: window.frame(),
            above: window.cgID(),
            onSpace: CGWindowsInfo<Window>.windowSpace(window),
            appearance: userConfiguration.focusBorderAppearance()
        )
    }

    /// Keeps the border on its window while the window moves or resizes.
    private func moveFocusBorder(with window: Window) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.moveFocusBorder(with: window) }
            return
        }

        guard window.cgID() == focusBorder.currentWindowID else {
            return
        }

        focusBorder.move(to: window.frame())
    }
}

// MARK: Focus Transition
extension WindowManager: FocusTransitionTarget {
    func windows(onScreen screen: Screen) -> [Window] {
        return windows.activeWindows(onScreen: screen)
    }

    func executeTransition(_ transition: FocusTransition<Window>) {
        switch transition {
        case let .focusWindow(window):
            window.focus()
        case let .focusScreen(screen):
            screen.focusScreen()
        }
    }

    func lastFocusedWindow(on screen: Screen) -> Window? {
        return screens.screenManagers.first { $0.screen?.screenID() == screen.screenID() }?.lastFocusedWindow
    }

    func nextWindowIDClockwise(on screen: Screen) -> Window.WindowID? {
        return screenManager(for: screen)?.nextWindowIDClockwise()
    }

    func nextWindowIDCounterClockwise(on screen: Screen) -> Window.WindowID? {
        return screenManager(for: screen)?.nextWindowIDCounterClockwise()
    }
}

extension WindowManager: ScreenManagerDelegate {
    func applyWindowLimit(forScreenManager screenManager: ScreenManager<WindowManager<Application>>, minimizingIn range: (Int) -> Range<Int>) {
        guard let screen = screenManager.screen else {
            return
        }

        let windows = screenManager.currentLayout is FloatingLayout
            ? self.windows(onScreen: screen).filter { $0.shouldBeManaged() }
            : activeWindows(on: screen)
        windows[range(windows.count)].forEach {
            $0.minimize()
        }
    }

    func floatOverflowWindows(forScreenManager screenManager: ScreenManager<WindowManager<Application>>, limit: Int) {
        guard let screen = screenManager.screen else {
            return
        }

        let overflow = windows.newestWindows(activeWindows(on: screen), over: limit)
        guard !overflow.isEmpty else {
            return
        }

        let area = screen.adjustedFrame()
        let size = OverflowWindows.size(
            in: area,
            mode: userConfiguration.windowOverflowSize(),
            fixedSize: userConfiguration.windowOverflowFixedSize(),
            share: userConfiguration.windowOverflowReasonableShare()
        )

        // Windows floated over the limit earlier keep their cascade slots.
        var occupiedCenters = windows.windows(onScreen: screen)
            .filter { windows.isWindowFloating($0) && windows.placementReason(for: $0) == .windowLimit }
            .map { CGPoint(x: $0.frame().midX, y: $0.frame().midY) }

        for window in overflow {
            setFloating(true, forWindow: window, reason: .windowLimit)
            distributeEventToScreen(screen, change: .remove(window: window))

            let cascade = OverflowWindows.cascadeIndex(occupiedCenters: occupiedCenters, in: area)
            let placed = placeOverflowWindow(window, size: size, area: area, cascade: cascade)
            occupiedCenters.append(CGPoint(x: placed.midX, y: placed.midY))

            // Some apps restore their own frame a moment after opening a window; place it once more if one did.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self,
                      self.windows.isWindowFloating(window),
                      self.windows.placementReason(for: window) == .windowLimit else {
                    return
                }

                let frame = window.frame()
                guard abs(frame.midX - placed.midX) > OverflowWindows.slotTolerance
                    || abs(frame.midY - placed.midY) > OverflowWindows.slotTolerance
                    || abs(frame.width - placed.width) > OverflowWindows.slotTolerance
                    || abs(frame.height - placed.height) > OverflowWindows.slotTolerance else {
                    return
                }

                log.debug("Placing overflow window again; its app moved it: \(window)")
                self.placeOverflowWindow(window, size: size, area: area, cascade: cascade)
            }
        }
    }

    /**
     Centres an overflow window in its cascade slot at the given size, in one step so the size is set where it fits (macOS shrinks a window resized
     near the screen edge), then re-centres on the size the app accepted (apps with a minimum size stay bigger). Returns the frame it ended up with.
     */
    @discardableResult private func placeOverflowWindow(_ window: Window, size: CGSize, area: CGRect, cascade: Int) -> CGRect {
        let threshold = CGSize(width: 1, height: 1)
        let target = OverflowWindows.frame(size: size, centeredIn: area, cascade: cascade)
        window.setFrame(target, withThreshold: threshold)

        let actualSize = window.frame().size
        guard abs(actualSize.width - size.width) > 1 || abs(actualSize.height - size.height) > 1 else {
            return target
        }

        let corrected = OverflowWindows.frame(size: actualSize, centeredIn: area, cascade: cascade)
        window.setFrame(corrected, withThreshold: threshold)
        return corrected
    }

    func activeWindowSet(forScreenManager screenManager: ScreenManager<WindowManager<Application>>, on screen: Screen) -> WindowSet<Window> {
        return windows.windowSet(forActiveWindowsOnScreen: screen)
    }
}
