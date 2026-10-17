//
//  Layout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/3/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

/**
 A base class for specific layout algorithms defining size and position of windows.
 
 - Requires:
 Specific layouts must subclass and override the following properties and methods:
 - `layoutName`
 - `layoutKey`
 
 Subclasses can optionally override `layoutDescription` to provide debugging information for the layout state.
 
 - Note:
 Usage of a layout object requires specifying a `WindowType` parameter.
 */
class Layout<Window: WindowType>: Codable {
    typealias Screen = Window.Screen

    private enum CodingKeys: String, CodingKey {
        case key
    }

    /// The layout's own name, for logs. What the user sees is `displayName`.
    class var layoutName: String { fatalError("Must be implemented by subclass") }

    /// The configuration key of the layout.
    class var layoutKey: String { fatalError("Must be implemented by subclass") }

    /// The layout's own name, for logs. What the user sees is `displayName`.
    var layoutName: String { return type(of: self).layoutName }

    /// The name shown in the menu bar, HUD, Layouts menu and palette: the `layout-names` entry, or the layout key.
    var displayName: String {
        return UserConfiguration.shared.layoutDisplayName(forKey: layoutKey)
    }

    /// The configuration key of the layout.
    var layoutKey: String { return type(of: self).layoutKey }

    /// The debug description of the layout.
    var layoutDescription: String { return "" }

    /// Takes over its twin's state (`LayoutType.twin`): main count, ratio, pane sizes. A twin is the same layout mirrored, so
    /// pane i is pane i and nothing needs translating. Layouts without such state ignore it.
    func adoptState(from twin: Layout<Window>) {}

    required init() {}

    required init(from decoder: Decoder) throws {}

    /// Base encoder for layouts; basically a noop.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layoutKey, forKey: .key)
    }

    /**
     Takes a list of windows and a screen and returns the assignments that would be performed.
     
     - Parameters:
         - windows: The windows to apply the layout algorithm to.
         - screen: The screen on which those windows should reside.
     
     - Returns:
     The assignments that would be performed given those windows on that screen.
     */
    func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        fatalError("Must be implemented by subclass")
    }

    /**
     Brings the layout's stored state in line with the windows of a layout pass, once per pass before `frameAssignments`.

     - Returns: The windows in a new order when some must move in the list (a new window joining its pane), `nil` otherwise.
     */
    func reconcile(windowIDs: [Window.WindowID]) -> [Window.WindowID]? {
        return nil
    }
}

/**
 A layout whose panes each hold several windows, with their sizes stored (`PaneCounts`) so warp can grow and shrink them.

 `mainPaneCount` is the maximum main holds; `paneCounts.main` is what it holds now. Subclasses override `paneCount` and lay
 windows out with `paneCounts(forWindowCount:)`.
 */
class PaneCountedLayout<Window: WindowType>: Layout<Window> {
    /// How many panes the layout has, main included.
    class var paneCount: Int { fatalError("Must be implemented by subclass") }

    private enum CodingKeys: String, CodingKey {
        case mainPaneCount
        case mainPaneRatio
        case paneCounts
    }

    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.5
    private var paneState = PaneState<Window.WindowID>(counts: PaneCounts([]))

    /// The windows per pane at the last layout pass, main first.
    var paneCounts: PaneCounts { paneState.counts }

    required init() {
        super.init()
        paneState = PaneState(counts: PaneCounts(paneCount: type(of: self).paneCount))
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.mainPaneCount = try values.decode(Int.self, forKey: .mainPaneCount)
        self.mainPaneRatio = try values.decode(CGFloat.self, forKey: .mainPaneRatio)
        let savedCounts = try values.decodeIfPresent(PaneCounts.self, forKey: .paneCounts)
        super.init()

        // Saved before warp, or by a layout with another number of panes: the balanced split.
        let paneCount = type(of: self).paneCount
        if let savedCounts, savedCounts.paneCount == paneCount {
            paneState = PaneState(counts: savedCounts, restored: true)
        } else {
            paneState = PaneState(counts: PaneCounts(paneCount: paneCount))
        }
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mainPaneCount, forKey: .mainPaneCount)
        try container.encode(mainPaneRatio, forKey: .mainPaneRatio)
        try container.encode(paneState.counts, forKey: .paneCounts)
    }

    override func adoptState(from twin: Layout<Window>) {
        guard let twin = twin as? PaneCountedLayout<Window>, type(of: twin).paneCount == type(of: self).paneCount else {
            return
        }

        mainPaneCount = twin.mainPaneCount
        mainPaneRatio = twin.mainPaneRatio
        paneState = twin.paneState
    }

    /// The pane sizes to lay out this many windows with: the stored ones, fitted if the window set differs from the last pass.
    func fittedPaneCounts(windowCount: Int) -> PaneCounts {
        return paneState.counts.fitted(to: windowCount, maxMain: mainPaneCount)
    }

    override func reconcile(windowIDs: [Window.WindowID]) -> [Window.WindowID]? {
        let before = paneState.counts
        let reconciliation = paneState.reconcile(windowIDs: windowIDs, maxMain: mainPaneCount)
        if reconciliation.counts != before {
            log.debug("\(layoutName) panes \(before) → \(reconciliation.counts) (main max \(mainPaneCount))")
        }
        return reconciliation.reorderedIDs
    }

    /// The frames of side panes that hold no window but keep their column: warp can move a window into them.
    func emptyPaneFrames(windowCount: Int, on screen: Screen) -> [Int: CGRect] {
        return [:]
    }

    /// What warping the window at `index` to `target` does, among `windowCount` windows (`PaneCounts.warp`).
    func warpPlan(from index: Int, to target: PaneCounts.WarpTarget, windowCount: Int, intoMainAtFront: Bool) -> PaneCounts.WarpPlan? {
        return fittedPaneCounts(windowCount: windowCount).warp(from: index, to: target, intoMainAtFront: intoMainAtFront)
    }

    /// What `warp-main` does with the window at `index` among `windowCount` windows (`PaneCounts.warpIntoMain`).
    func warpIntoMainPlan(from index: Int, windowCount: Int, intoMainAtFront: Bool) -> PaneCounts.WarpPlan? {
        return fittedPaneCounts(windowCount: windowCount).warpIntoMain(from: index, intoMainAtFront: intoMainAtFront)
    }

    /// Takes the sizes after a warp moved a window. A warp into a full main raises the maximum to match; a warp out of
    /// main lowers it by one (Hans, 2026-10-14), so the maximum follows how main is arranged instead of only growing.
    func applyWarp(_ counts: PaneCounts) {
        let mainBefore = fittedPaneCounts(windowCount: counts.total).main
        paneState.setCounts(counts)
        if counts.main < mainBefore {
            mainPaneCount = max(1, mainPaneCount - 1)
        } else {
            mainPaneCount = max(mainPaneCount, counts.main)
        }
    }

    /// "x of y": the windows main holds and its maximum.
    var mainPaneCountDescription: String {
        return "\(min(paneState.counts.main, mainPaneCount)) of \(mainPaneCount)"
    }

    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        mainPaneRatio = rawRatio
    }

    /// Raises the maximum only; nothing moves. Main fills by warp or by windows arriving at `main-arrival-position: first`.
    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    /// Lowers the maximum; windows main holds beyond it go to the first side pane at the next pass.
    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}

/// Errors occurring when decoding a layout
enum LayoutDecodingError: Error {
    /**
     Something about the layout was structurally unsound.
     
     Notable example: bsp layout cannot recover if some windows are no longer present, so if we fail to decode a node the layout is no longer sound.
     */
    case invalidLayout
}

// MARK: Window Querying

extension Layout {
    /**
     Determines what window the layout would put at a given point.
     
     - Parameters:
         - point: The point to test for location.
         - windows: The windows to apply the layout algorithm to.
         - screen: The screen on which those windows should reside.
     
     - Returns:
     The window that the layout would intend to put at `point`.
     
     - Note: This does not necessarily correspond to the final position of the window as windows do not necessarily take the exact frame the layout provides.
     */
    func windowAtPoint(_ point: CGPoint, of windowSet: WindowSet<Window>, on screen: Screen) -> LayoutWindow<Window>? {
        return frameAssignments(windowSet, on: screen)?
            .map { $0.frameAssignment }
            .first { $0.frame.contains(point) }?
            .window
    }

    /**
     Determines what frame the layout would apply to a given window.
     
     - Parameters:
         - window: The window to test for frame.
         - windows: The windows to apply the layout algorithm to.
         - screen: The screen on which those windows should reside.
     
     - Returns:
     The `FrameAssignment` object defining the size and location that the layout would assign to `window`.
     
     - Note: This does not necessarily correspond to the final frame of the window as windows do not necessarily take the exact frame the layout provides.
     */
    func assignedFrame(_ window: Window, of windowSet: WindowSet<Window>, on screen: Screen) -> FrameAssignment<Window>? {
        guard let assignments = frameAssignments(windowSet, on: screen) else {
            return nil
        }

        return assignments.map { $0.frameAssignment }.first { $0.window.id == window.id() }
    }
}

/**
 A particular kind of layout that organizes windows into a main pane and any number of sub-panes.
 
 - Note:
 The definition is intentionally somewhat layout. This is more intended to demonstrate the expected interface for a fairly common paradigm in Amethyst layouts.
 */
protocol PanedLayout {
    /**
     The ratio of the size of the main pane to the size of the sub-panes.
     
     - Requires:
     The value must be between 0 and 1, inclusive.
     */
    var mainPaneRatio: CGFloat { get }

    /// The number of windows that make up the main pane.
    var mainPaneCount: Int { get }

    /**
     Takes a direct recommendation for a change in ratio.
     
     - Parameters:
        - rawRatio: The ratio recommended by the caller.
     
     - Requires:
     `rawRatio` must be a valid ratio.
     
     - Note: This method should generally be reserved for internal use by the layout.
     */
    func recommendMainPaneRawRatio(rawRatio: CGFloat)

    /// Reduces the visual footprint of the main pane relative to the sub-panes.
    func shrinkMainPane()

    /// Increases the visual footprint of the main pane relative to the sub-panes.
    func expandMainPane()

    /// Increases the number of windows that make up the main pane.
    func increaseMainPaneCount()

    /// Decreases the number of windows that make up the main pane.
    func decreaseMainPaneCount()

    /// The main pane count for the palette and the HUD: "x of y" where main's size is stored (warp), otherwise the count.
    var mainPaneCountDescription: String { get }
}

extension PanedLayout {
    /// Sets the number of windows in the main pane by stepping it up or down, so each layout keeps its own rules (a minimum of 1, a fixed count). Stops once the count stops changing.
    func setMainPaneCount(_ count: Int) {
        while mainPaneCount != count {
            let previousCount = mainPaneCount
            if mainPaneCount < count {
                increaseMainPaneCount()
            } else {
                decreaseMainPaneCount()
            }

            guard mainPaneCount != previousCount else {
                return
            }
        }
    }

    var mainPaneCountDescription: String {
        return "\(mainPaneCount)"
    }

    /// The default debug layout description for paned layouts. It describes the ratio and number of main pane windows.
    var layoutDescription: String {
        return "(\(mainPaneRatio), \(mainPaneCount))"
    }

    /**
     Takes a recommendation for a change in ratio, but can modify the ratio to adjust for internal state.
     
     - Parameters:
        - ratio: The ratio recommended by the caller.
     */
    func recommendMainPaneRatio(_ ratio: CGFloat) {
        recommendMainPaneRawRatio(rawRatio: Self.clampedMainPaneRatio(ratio))
    }

    /// Keeps both panes on screen: at 0 or 1 one of them would be zero wide (repeated shrink-main, a mouse resize to the edge).
    static func clampedMainPaneRatio(_ ratio: CGFloat) -> CGFloat {
        guard ratio.isFinite else {
            return 0.5
        }
        return min(max(ratio, 0.05), 0.95)
    }

    /// The default behavior of main pane expansion that simply recommends an increase in ratio by the configured resize step.
    func expandMainPane() {
        recommendMainPaneRatio(mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    /// The default behavior of main pane shrinking that simply recommends a decrease in ratio by the configured resize step.
    func shrinkMainPane() {
        recommendMainPaneRatio(mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }
}

/**
 A base class for specific layout algorithms that maintain internal state for defining size and position of windows.
 
 - Requires:
 Specific layouts must subclass and override the following properties and methods:
 - `updateWithChange(_ windowChange: WindowChange<Window>)`
 - `nextWindowIDCounterClockwise() -> CGWindowID?`
 - `nextWindowIDClockwise() -> CGWindowID?`
 
 Notably, the latter two are necessary for the window manager to determine flow of windows. By default layouts are a simple linear list, but more complex layouts may have different logic.
 */
class StatefulLayout<Window: WindowType>: Layout<Window> {
    /**
     Updates internal state of the layout based on a window change.
     
     - Parameters:
        - windowChange: A `WindowChange`.
     */
    func updateWithChange(_ windowChange: Change<Window>) {
        fatalError("Must be implemented by subclass")
    }

    /**
     Determines the window that is before the current window.
     
     - Returns:
     The ID of the window before the current window.
     */
    func nextWindowIDCounterClockwise() -> Window.WindowID? {
        fatalError("Must be implemented by subclass")
    }

    /**
     Determines the window that is after the current window.
     
     - Returns:
     The ID of the window after the current window.
     */
    func nextWindowIDClockwise() -> Window.WindowID? {
        fatalError("Must be implemented by subclass")
    }
}
