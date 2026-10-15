//
//  ScreenManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/23/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Foundation
import Silica

/// Information about a layout for display in menus
struct LayoutMenuItemInfo {
    let key: String
    let name: String
    let isSelected: Bool
}

protocol ScreenManagerDelegate: AnyObject {
    associatedtype Window: WindowType
    func applyWindowLimit(forScreenManager screenManager: ScreenManager<Self>, minimizingIn range: (_ windowCount: Int) -> Range<Int>)
    /// `window-overflow: float`: floats the newest tiled windows on the screen over the limit.
    func floatOverflowWindows(forScreenManager screenManager: ScreenManager<Self>, limit: Int)
    func activeWindowSet(forScreenManager screenManager: ScreenManager<Self>, on screen: Window.Screen) -> WindowSet<Window>
    func onReflowInitiation()
    func onReflowCompletion()
    /// Windows that left view on this screen's Space (closed, quit, hidden, minimised, moved away, floated).
    func windowsLeftView(_ windowIDs: [Window.WindowID])
    /// Windows that appeared on this screen's Space; those that had left view before arrive again at `main-arrival-position`.
    /// Returns whether any moved, so the pass reads the window set again.
    func windowsCameBack(_ windowIDs: [Window.WindowID]) -> Bool
    /// Puts this screen's windows in this order (the layout moved a window into its pane). Returns whether any moved.
    func reorderWindows(_ windowIDs: [Window.WindowID]) -> Bool
}

/// What changed between two layout passes on the same Space and layout. Only visible windows are managed: a main window that
/// leaves view (closed, quit, hidden, minimised, moved to another Space, floated) shrinks main, as a window leaving a side
/// column shrinks only that column; main count is a maximum, not a target.
struct VisibleWindowChange<ID: Hashable> {
    /// Windows in the previous pass that aren't in this one.
    let left: [ID]
    /// Windows in this pass that weren't in the previous one.
    let appeared: [ID]
    /// How many fewer windows main should hold.
    let mainShrink: Int

    /// - Parameter previousMainCount: How many windows main held in the previous pass.
    init(previous: [ID], previousMainCount: Int, current: [ID]) {
        let previousSet = Set(previous)
        let currentSet = Set(current)
        var left = previous.filter { !currentSet.contains($0) }
        var appeared = current.filter { !previousSet.contains($0) }

        // A tab switch puts one window in another's place: neither left nor appeared.
        for index in previous.indices where index < current.count {
            if !currentSet.contains(previous[index]) && !previousSet.contains(current[index]) {
                left.removeAll { $0 == previous[index] }
                appeared.removeAll { $0 == current[index] }
            }
        }

        let main = Set(previous.prefix(previousMainCount))
        let leftMain = left.filter { main.contains($0) }.count
        // Bounded by how much the count dropped: a close and an open in one pass leave main as it is.
        self.left = left
        self.appeared = appeared
        self.mainShrink = min(leftMain, max(0, previous.count - current.count))
    }
}

final class ScreenManager<Delegate: ScreenManagerDelegate>: NSObject, Codable {
    typealias Window = Delegate.Window
    typealias Screen = Window.Screen

    enum CodingKeys: String, CodingKey {
        case layoutsBySpaceUUID
        /// Which layout each Space was on, by layout key, so a relaunch comes back on it.
        case currentLayoutKeyBySpaceUUID
    }

    weak var delegate: Delegate?

    private(set) var screen: Screen?
    private(set) var space: Space?

    /// The last window that has been focused on the screen. This value is updated by the notification observations in
    /// `ObserveApplicationNotifications`.
    private(set) var lastFocusedWindow: Window?
    /// The frames of the last layout pass, before window margins, for directional navigation.
    private(set) var lastAssignedFrames: [Window.WindowID: CGRect] = [:]

    /// The previous pass per Space UUID: its windows in order, how many of them were in main, and the layout.
    private struct PreviousPass {
        let windowIDs: [Window.WindowID]
        let mainCount: Int
        let layoutKey: String
    }
    private var previousPasses: [String: PreviousPass] = [:]
    private let userConfiguration: UserConfiguration

    /// The tiles windows on this screen refuse (stay bigger than), so each is reported once per tile size.
    private var refusedTiles = RefusedTileTracker<Window.WindowID>()

    private let reflowOperationDispatchQueue = DispatchQueue(
        label: "ScreenManager.reflowOperationQueue",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    private let reflowOperationQueue = OperationQueue()

    private var layouts: [Layout<Window>] = []
    private var currentLayoutIndexBySpaceUUID: [String: Int] = [:]
    private var layoutsBySpaceUUID: [String: [Layout<Window>]] = [:]
    private var currentLayoutIndex: Int = 0
    var previousLayoutKey: String?
    var currentLayout: Layout<Window>? {
        guard !layouts.isEmpty else {
            return nil
        }
        return layouts[currentLayoutIndex]
    }

    /// Returns layout info for all layouts in this screen manager, including selection state
    var layoutsInfo: [LayoutMenuItemInfo] {
        return layouts.enumerated().map { index, layout in
            LayoutMenuItemInfo(
                key: layout.layoutKey,
                name: layout.displayName,
                isSelected: index == currentLayoutIndex
            )
        }
    }

    private let layoutNameWindowController: LayoutNameWindowController

    init(screen: Screen, delegate: Delegate, userConfiguration: UserConfiguration) {
        self.screen = screen
        self.delegate = delegate
        self.userConfiguration = userConfiguration

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")

        super.init()

        layouts = LayoutType.layoutsWithConfiguration(userConfiguration)

        reflowOperationQueue.underlyingQueue = reflowOperationDispatchQueue
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let layoutsBySpaceUUID = try values.decode([String: [[String: Data]]].self, forKey: .layoutsBySpaceUUID)

        self.userConfiguration = UserConfiguration.shared
        self.layoutsBySpaceUUID = try layoutsBySpaceUUID.mapValues { keyedLayouts -> [Layout<Window>] in
            return try ScreenManager<Delegate>.decodedLayouts(from: keyedLayouts, userConfiguration: UserConfiguration.shared)
        }

        // Saved before this key existed: every Space starts on the first layout.
        let currentLayoutKeys = try values.decodeIfPresent([String: String].self, forKey: .currentLayoutKeyBySpaceUUID) ?? [:]
        self.currentLayoutIndexBySpaceUUID = ScreenManager.layoutIndices(byKey: currentLayoutKeys, layoutsBySpaceUUID: self.layoutsBySpaceUUID)

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")
    }

    /**
     Takes the list of layouts and inserts decoded layouts where appropriate.

     - Parameters:
        - encodedLayouts: A list of encoded layouts to be restored.
        - userConfiguration: User configuration defining the list of layouts.
     */
    static func decodedLayouts(from encodedLayouts: [[String: Data]], userConfiguration: UserConfiguration) throws -> [Layout<Window>] {
        let layouts: [Layout<Window>] = LayoutType.layoutsWithConfiguration(userConfiguration)
        var decodedLayouts: [Layout<Window>] = encodedLayouts.compactMap { layout in
            guard let keyData = layout["key"], let key = String(data: keyData, encoding: .utf8) else {
                return nil
            }

            guard let data = layout["data"] else {
                return nil
            }

            do {
                return try LayoutType<Window>.decoded(data: data, key: key)
            } catch {
                log.error("Failed to to decode layout: \(key)")
            }

            return nil
        }

        // Yes this is quadratic, but if your layout list is long enough for that to be significant what are you even doing?
        return layouts.map { layout -> Layout<Window> in
            guard let decodedLayoutIndex = decodedLayouts.firstIndex(where: { $0.layoutKey == layout.layoutKey }) else {
                return layout
            }

            return decodedLayouts.remove(at: decodedLayoutIndex)
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        let layoutsBySpaceUUID = try self.layoutsBySpaceUUID.mapValues { layouts in
            return try layouts.map { layout -> [String: Data] in
                let layoutKey = layout.layoutKey.data(using: .utf8)!
                let encodedLayout = try LayoutType.encoded(layout: layout)
                return ["key": layoutKey, "data": encodedLayout]
            }
        }
        try values.encode(layoutsBySpaceUUID, forKey: .layoutsBySpaceUUID)

        // The current Space's index is only copied into the dictionary when switching away from it.
        var currentLayoutIndices = currentLayoutIndexBySpaceUUID
        if let space {
            currentLayoutIndices[space.uuid] = currentLayoutIndex
        }
        let currentLayoutKeys = ScreenManager.layoutKeys(byIndex: currentLayoutIndices, layoutsBySpaceUUID: self.layoutsBySpaceUUID)
        try values.encode(currentLayoutKeys, forKey: .currentLayoutKeyBySpaceUUID)
    }

    /// The key of each Space's selected layout, for saving. Keys rather than indices, so reordering `layouts:` keeps the selection.
    static func layoutKeys(byIndex indices: [String: Int], layoutsBySpaceUUID: [String: [Layout<Window>]]) -> [String: String] {
        var keys: [String: String] = [:]
        for (spaceUUID, index) in indices {
            guard let layouts = layoutsBySpaceUUID[spaceUUID], layouts.indices.contains(index) else {
                continue
            }
            keys[spaceUUID] = layouts[index].layoutKey
        }
        return keys
    }

    /// Each Space's selected layout as an index again; a layout no longer in `layouts:` is dropped, so that Space starts on the first.
    static func layoutIndices(byKey keys: [String: String], layoutsBySpaceUUID: [String: [Layout<Window>]]) -> [String: Int] {
        var indices: [String: Int] = [:]
        for (spaceUUID, key) in keys {
            guard let index = layoutsBySpaceUUID[spaceUUID]?.firstIndex(where: { $0.layoutKey == key }) else {
                continue
            }
            indices[spaceUUID] = index
        }
        return indices
    }

    func updateScreen(to screen: Screen) {
        self.screen = screen
    }

    func updateSpace(to space: Space) {
        if let currentSpace = self.space {
            currentLayoutIndexBySpaceUUID[currentSpace.uuid] = currentLayoutIndex
        }

        self.space = space

        if let layouts = layoutsBySpaceUUID[space.uuid] {
            self.layouts = layouts
        } else {
            self.layouts = LayoutType.layoutsWithConfiguration(userConfiguration)
            layoutsBySpaceUUID[space.uuid] = layouts
        }

        // After the layouts: right after launch there are none yet, and the index would be rejected as out of range.
        setCurrentLayoutIndex(currentLayoutIndexBySpaceUUID[space.uuid] ?? 0, changingSpace: true)
    }

    func distributeEvent(_ change: Change<Window>) {
        switch change {
        case let .add(window: window):
            lastFocusedWindow = window
        case let .focusChanged(window):
            lastFocusedWindow = window
        case let .remove(window):
            if lastFocusedWindow == window {
                lastFocusedWindow = nil
            }
        case .windowSwap, .applicationActivate, .applicationDeactivate, .spaceChange, .layoutChange, .tabChange, .none, .unknown:
            break
        }

        log.debug("Screen: \(screen?.screenID() ?? "unknown") reflow -- Window Change: \(change)")

        guard let space, let layouts = layoutsBySpaceUUID[space.uuid] else {
            log.warning("Trying to distribute an event to a screen with no space")
            return
        }

        for layout in layouts {
            if let layout = layout as? StatefulLayout {
                layout.updateWithChange(change)
            }
        }
    }

    /// How long a reflow after a focus change waits for the rest of the burst: an app switch posts several events in a row.
    private static var focusReflowDelay: TimeInterval { 0.02 }
    private var pendingFocusReflow: DispatchWorkItem?

    /// Lays the screen out again. After a focus change the reflow waits briefly, so a burst of events reflows once.
    func setNeedsReflow(afterFocusChange: Bool = false) {
        reflowOperationQueue.cancelAllOperations()
        pendingFocusReflow?.cancel()
        pendingFocusReflow = nil

        log.debug("Screen: \(screen?.screenID() ?? "unknown") reflow")

        let reflow = DispatchWorkItem { [weak self] in
            self?.minimizeWindows()
            self?.reflow()
        }

        if afterFocusChange {
            pendingFocusReflow = reflow
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.focusReflowDelay, execute: reflow)
        } else {
            DispatchQueue.main.async(execute: reflow)
        }
    }

    private func minimizeWindows() {
        let mainPaneCount = (currentLayout as? PaneCountedLayout<Window>)?.paneCounts.main ?? (currentLayout as? PanedLayout)?.mainPaneCount ?? 0

        guard UserConfiguration.shared.tilingEnabled, let windowLimit = UserConfiguration.shared.windowMaxCount() else {
            return
        }

        if UserConfiguration.shared.windowOverflow() == .float {
            // In the Floating layout every window floats already.
            if !(currentLayout is FloatingLayout<Window>) {
                delegate?.floatOverflowWindows(forScreenManager: self, limit: windowLimit)
            }
            return
        }

        let shouldInsertAtFront = UserConfiguration.shared.mainArrivalPosition() == .first
        delegate?.applyWindowLimit(forScreenManager: self, minimizingIn: { windowCount in
            if windowLimit > windowCount {
                // Not enough windows to minimize.
                return 0 ..< 0
            }
            if !(currentLayout is PanedLayout) {
                // Minimize from the back, for layouts like floating/fullscreen.
                if shouldInsertAtFront {
                    return windowLimit ..< windowCount
                } else {
                    return 0 ..< windowCount - windowLimit
                }
            }
            if windowLimit <= mainPaneCount {
                // Don't minimize main panes. This allowing varying main pane count to pin windows.
                guard windowCount >= mainPaneCount else {return 0 ..< 0}
                return mainPaneCount ..< windowCount
            }
            // Minimize the oldest non-main panes.
            if shouldInsertAtFront {
                return windowLimit ..< windowCount
            } else {
                return mainPaneCount ..< windowCount + mainPaneCount - windowLimit
            }
        })
    }

    private func reflow() {
        guard let screen = screen else {
            return
        }

        guard userConfiguration.tilingEnabled, space?.type == CGSSpaceTypeUser else {
            return
        }

        // During rapid Space transitions, activation/focus notifications can arrive before
        // this screen manager updates its tracked Space. Skip reflow if state is stale.
        guard let currentSpace = CGSpacesInfo<Window>.currentSpaceForScreen(screen), currentSpace.id == space?.id else {
            return
        }

        guard var windows = delegate?.activeWindowSet(forScreenManager: self, on: screen), let spaceUUID = space?.uuid else {
            return
        }

        if let layout = currentLayout, let previous = previousPasses[spaceUUID], previous.layoutKey == layout.layoutKey {
            let change = VisibleWindowChange(previous: previous.windowIDs, previousMainCount: previous.mainCount, current: windows.windows.map(\.id))
            if !change.left.isEmpty {
                delegate?.windowsLeftView(change.left)
            }
            // Layouts with stored pane sizes shrink the pane a window left in `reconcile`; the others lower the maximum.
            if change.mainShrink > 0, !(layout is PaneCountedLayout<Window>), let panedLayout = layout as? PanedLayout {
                let mainCount = max(1, min(panedLayout.mainPaneCount, previous.mainCount) - change.mainShrink)
                log.debug("Main count \(panedLayout.mainPaneCount) → \(mainCount): \(change.mainShrink) main window(s) left view")
                while panedLayout.mainPaneCount > mainCount {
                    panedLayout.decreaseMainPaneCount()
                }
            }
            if !change.appeared.isEmpty, delegate?.windowsCameBack(change.appeared) == true,
               let rearranged = delegate?.activeWindowSet(forScreenManager: self, on: screen) {
                windows = rearranged
            }
        }

        if let layout = currentLayout, let order = layout.reconcile(windowIDs: windows.windows.map(\.id)),
           delegate?.reorderWindows(order) == true,
           let rearranged = delegate?.activeWindowSet(forScreenManager: self, on: screen) {
            windows = rearranged
        }

        guard let layout = currentLayout, let frameAssignments = layout.frameAssignments(windows, on: screen) else {
            lastAssignedFrames = [:]
            return
        }

        let windowIDs = windows.windows.map(\.id)
        let mainCount = (layout as? PaneCountedLayout<Window>)?.paneCounts.main
            ?? (layout as? PanedLayout).map { min($0.mainPaneCount, windowIDs.count) } ?? 0
        previousPasses[spaceUUID] = PreviousPass(windowIDs: windowIDs, mainCount: mainCount, layoutKey: layout.layoutKey)

        lastAssignedFrames = Dictionary(
            frameAssignments.map { ($0.frameAssignment.window.id, $0.frameAssignment.frame) },
            uniquingKeysWith: { _, last in last }
        )

        // Only built when a log destination wants it (`--log`): it asks every window for its title.
        log.debug(ScreenManager.reflowTrace(layout: layout, windowSet: windows, frameAssignments: frameAssignments))

        // TODO: fix mff
//        let mouseFollowsFocus = userConfiguration.mouseFollowsFocus()

        let completeOperation = BlockOperation()

        // The complete operation should execute the completion delegate call
        completeOperation.addExecutionBlock { [unowned completeOperation, weak self] in
            if completeOperation.isCancelled {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Some apps settle their size a moment after it's set.
                self?.checkTileFits(frameAssignments)
            }

            DispatchQueue.main.async {
                self?.delegate?.onReflowCompletion()
                // TODO: fix mff
//                if mouseFollowsFocus {
//                    if case .windowSwap(let window, _) = event {
//                        window.focus()
//                    }
//                }
            }
        }

        // The completion should be dependent on all assignments finishing
        frameAssignments.forEach { completeOperation.addDependency($0) }

        // Start the operation
        delegate?.onReflowInitiation()
        reflowOperationQueue.addOperations(frameAssignments, waitUntilFinished: false)
        reflowOperationQueue.addOperation(completeOperation)
    }

    /// One layout pass for the log: the layout and, per tiled window in list order, its app, title, whether it's on screen, and its tile.
    /// A window that's tiled but not on screen leaves an empty tile.
    private static func reflowTrace(layout: Layout<Window>, windowSet: WindowSet<Window>, frameAssignments: [FrameAssignmentOperation<Window>]) -> String {
        var header = "Reflow: \(layout.layoutName), \(windowSet.windows.count) windows"
        if let panedLayout = layout as? PanedLayout {
            header += String(format: ", main count %d, ratio %.2f", panedLayout.mainPaneCount, panedLayout.mainPaneRatio)
        }
        if let paneCountedLayout = layout as? PaneCountedLayout<Window> {
            header += ", panes \(paneCountedLayout.paneCounts)"
        }

        let lines = frameAssignments.enumerated().map { index, operation -> String in
            let assignment = operation.frameAssignment
            let tile = assignment.frame
            let tileText = String(format: "%.0f,%.0f %.0f×%.0f", tile.minX, tile.minY, tile.width, tile.height)
            guard let window = windowSet.window(for: assignment.window) else {
                return "  \(index). unknown window → \(tileText)"
            }
            let applicationName = NSRunningApplication(processIdentifier: window.pid())?.localizedName ?? "pid \(window.pid())"
            let onScreen = window.isOnScreen() ? "" : " [not on screen]"
            return "  \(index). \(applicationName) \"\(window.title() ?? "")\" #\(window.cgID())\(onScreen) → \(tileText)"
        }

        return ([header] + lines).joined(separator: "\n")
    }

    func updateCurrentLayout(_ updater: (Layout<Window>) -> Void) {
        guard let layout = currentLayout else {
            return
        }
        updater(layout)
        setNeedsReflow()
    }

    func cycleLayoutForward() {
        setCurrentLayoutIndex((currentLayoutIndex + 1) % layouts.count)
        setNeedsReflow()
    }

    func cycleLayoutBackward() {
        setCurrentLayoutIndex((currentLayoutIndex == 0 ? layouts.count : currentLayoutIndex) - 1)
        setNeedsReflow()
    }

    func selectLayout(_ layoutString: String) {
        guard let currentLayoutKey = currentLayout?.layoutKey else {
            return
        }

        let nextLayoutKey = currentLayoutKey == layoutString ? previousLayoutKey : layoutString

        guard let layoutIndex = layouts.firstIndex(where: { $0.layoutKey == nextLayoutKey }) else {
            return
        }

        setCurrentLayoutIndex(layoutIndex)
        setNeedsReflow()
        previousLayoutKey = currentLayoutKey
    }

    private func setCurrentLayoutIndex(_ index: Int, changingSpace: Bool = false) {
        guard (0..<layouts.count).contains(index) else {
            return
        }

        currentLayoutIndex = index

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .currentLayoutDidChange, object: nil)
        }

        guard !changingSpace || userConfiguration.enablesLayoutHUDOnSpaceChange() else {
            return
        }

        DispatchQueue.main.async {
            self.displayLayoutHUD()
        }
    }

    func shrinkMainPane() {
        guard let panedLayout = currentLayout as? PanedLayout else {
            return
        }
        panedLayout.shrinkMainPane()
    }

    func expandMainPane() {
        guard let panedLayout = currentLayout as? PanedLayout else {
            return
        }
        panedLayout.expandMainPane()
    }

    func nextWindowIDCounterClockwise() -> Window.WindowID? {
        guard let layout = currentLayout as? StatefulLayout else {
            return nil
        }

        return layout.nextWindowIDCounterClockwise()
    }

    func nextWindowIDClockwise() -> Window.WindowID? {
        guard let statefulLayout = currentLayout as? StatefulLayout else {
            return nil
        }

        return statefulLayout.nextWindowIDClockwise()
    }

    func displayLayoutHUD() {
        guard userConfiguration.enablesLayoutHUD(), space?.type == CGSSpaceTypeUser else {
            return
        }

        let currentLayoutName = currentLayout.flatMap({ $0.displayName }) ?? "None"
        let currentLayoutDescription = currentLayout?.layoutDescription ?? ""

        displayCustomHUD(title: currentLayoutName, description: currentLayoutDescription)
    }

    /// Shows the current layout's main pane count. Only paned layouts have one.
    func displayMainPaneCountHUD() {
        guard userConfiguration.enablesLayoutHUD(), let panedLayout = currentLayout as? PanedLayout else {
            return
        }

        let count = panedLayout.mainPaneCountDescription
        DispatchQueue.main.async {
            self.displayCustomHUD(title: "Main pane count · \(count)")
        }
    }

    @objc func hideLayoutHUD(_ sender: AnyObject) {
        layoutNameWindowController.close()
    }

    /// Reports tiled windows that stayed bigger than their tile after a layout pass: logged always, and shown in a HUD with `enables-refused-tile-hud`.
    private func checkTileFits(_ frameAssignments: [FrameAssignmentOperation<Window>]) {
        let fits = frameAssignments.compactMap { operation -> TileFit<Window.WindowID>? in
            let layoutWindow = operation.frameAssignment.window
            guard !operation.isCancelled,
                  let window = operation.windowSet.window(for: layoutWindow),
                  operation.windowSet.isWindowActive(layoutWindow),
                  !operation.windowSet.isWindowFloating(layoutWindow) else {
                return nil
            }

            let applicationName = NSRunningApplication(processIdentifier: window.pid())?.localizedName ?? "pid \(window.pid())"
            return TileFit(windowID: layoutWindow.id, applicationName: applicationName, tile: operation.frameAssignment.finalFrame.size, actual: window.frame().size)
        }

        let refusals = refusedTiles.update(fits)
        guard !refusals.isEmpty else {
            return
        }

        for refusal in refusals {
            log.info("Refused tile: \(refusal.applicationName) needs \(RefusedTileHUD.size(refusal.actual)), tile \(RefusedTileHUD.size(refusal.tile))")
        }

        guard userConfiguration.enablesRefusedTileHUD() else {
            return
        }

        let text = RefusedTileHUD.text(for: refusals)
        displayCustomHUD(title: text.title, description: text.description, duration: 2)
    }

    func displayCustomHUD(title: String, description: String = "", duration: TimeInterval = 0.6) {
        guard let screen = screen else {
            return
        }

        guard space?.type == CGSSpaceTypeUser else {
            return
        }

        defer {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideLayoutHUD(_:)), object: nil)
            perform(#selector(hideLayoutHUD(_:)), with: nil, afterDelay: duration)
        }

        guard let layoutNameWindow = layoutNameWindowController.window as? LayoutNameWindow else {
            return
        }

        // Use new displayNotification method with dynamic sizing
        layoutNameWindow.displayNotification(title: title, description: description)

        // Center the window after resizing
        let screenFrame = screen.frame()
        let screenCenter = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
        let windowOrigin = CGPoint(
            x: screenCenter.x - layoutNameWindow.frame.width / 2.0,
            y: screenCenter.y - layoutNameWindow.frame.height / 2.0
        )
        layoutNameWindow.setFrameOrigin(NSPointFromCGPoint(windowOrigin))

        layoutNameWindowController.showWindow(self)
    }
}

extension ScreenManager: Comparable {
    static func < (lhs: ScreenManager<Delegate>, rhs: ScreenManager<Delegate>) -> Bool {
        guard let lhsScreen = lhs.screen, let rhsScreen = rhs.screen else {
            return false
        }

        let originX1 = lhsScreen.frameWithoutDockOrMenu().origin.x
        let originX2 = rhsScreen.frameWithoutDockOrMenu().origin.x

        return originX1 < originX2
    }
}

extension Notification.Name {
    /// Posted on the main queue when a screen's current layout changes: cycled, selected, or restored on a space change.
    static let currentLayoutDidChange = Notification.Name("AmethystCurrentLayoutDidChange")
}
