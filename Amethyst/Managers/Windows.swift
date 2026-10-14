//
//  Windows.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/15/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

/**
 The anchor window of each application on each space, for `floating-secondary-windows`.

 The anchor is the one real tiled window of a listed application on a space; while it exists, the application's other windows on that space float. macOS doesn't reliably say which window opened which, so the model is order-based: the first tiled window claims the slot.
 */
struct SecondaryWindowAnchors<WindowID: Hashable> {
    struct Slot: Hashable {
        let pid: pid_t
        let space: CGSSpaceID
    }

    private var anchors: [Slot: WindowID] = [:]

    func anchor(for slot: Slot) -> WindowID? {
        return anchors[slot]
    }

    func slot(anchoredBy windowID: WindowID) -> Slot? {
        return anchors.first { $0.value == windowID }?.key
    }

    /// Makes the window the slot's anchor unless the slot already has one. Returns whether it did.
    @discardableResult mutating func claim(_ slot: Slot, for windowID: WindowID) -> Bool {
        guard anchors[slot] == nil else {
            return false
        }

        anchors[slot] = windowID
        return true
    }

    /// Frees the slot the window anchors, if any, and returns it.
    @discardableResult mutating func release(_ windowID: WindowID) -> Slot? {
        guard let slot = slot(anchoredBy: windowID) else {
            return nil
        }

        anchors.removeValue(forKey: slot)
        return slot
    }
}

/// A window as saved when Ametrine quits. Other applications keep running across a relaunch, so pid and window number find it again.
struct SavedWindowID: Codable, Hashable {
    let pid: pid_t
    let windowID: CGWindowID
}

/**
 The window order saved when Ametrine quit, applied while windows arrive after a relaunch, so the main pane keeps its window.

 Windows arrive in no particular order (by application, with retries), so each saved window is inserted among those already there by its saved position. Windows that weren't saved (opened while Ametrine wasn't running) go after the saved ones.
 */
struct RestoredWindowOrder<Key: Hashable> {
    private let ranks: [Key: Int]
    private var pending: Set<Key>

    init(_ order: [Key]) {
        ranks = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        pending = Set(order)
    }

    /// Every saved window has arrived.
    var isDone: Bool {
        return pending.isEmpty
    }

    /// Where an arriving saved window goes among the windows already there, or `nil` for a window that wasn't saved.
    func insertionIndex(for key: Key, among existing: [Key]) -> Int? {
        guard pending.contains(key), let rank = ranks[key] else {
            return nil
        }

        return existing.firstIndex { (ranks[$0] ?? Int.max) > rank } ?? existing.count
    }

    mutating func arrived(_ key: Key) {
        pending.remove(key)
    }
}

/// The window each Space last had in main (what `swap-main` from main swaps back to), saved when Ametrine quit and reconnected as windows arrive.
struct PendingLastMainWindows<Key: Hashable> {
    private var spacesByWindow: [Key: [CGSSpaceID]]

    init(_ windowsBySpace: [CGSSpaceID: Key]) {
        spacesByWindow = Dictionary(grouping: windowsBySpace.keys) { windowsBySpace[$0]! }
    }

    var isEmpty: Bool {
        return spacesByWindow.isEmpty
    }

    /// The Spaces the arriving window was the last main window of; each window is handed back once.
    mutating func takeSpaces(for key: Key) -> [CGSSpaceID] {
        return spacesByWindow.removeValue(forKey: key) ?? []
    }
}

extension WindowManager {
    class Windows {
        private(set) var windows: [Window] = []
        private(set) var lastMainWindows: [CGSSpaceID: Window?] = [:]
        /// Recently focused windows per space, most recent first: the tie-break for directional navigation.
        private(set) var recentlyFocused: [CGSSpaceID: [Window.WindowID]] = [:]
        private var activeIDCache: Set<CGWindowID> = Set()
        private var deactivatedPIDs: Set<pid_t> = Set()
        private var floatingMap: [Window.WindowID: Bool] = [:]
        private var placementReasons: [Window.WindowID: PlacementReason] = [:]
        /// When each window was added, increasing, for `window-overflow: float` (the newest windows float).
        private var additionOrder: [Window.WindowID: Int] = [:]
        private var nextAdditionOrder = 0
        var secondaryWindowAnchors = SecondaryWindowAnchors<Window.WindowID>()
        /// The order to restore after a relaunch, until every saved window has arrived or it's given up on.
        private var restoredOrder: RestoredWindowOrder<SavedWindowID>?
        private var pendingLastMainWindows: PendingLastMainWindows<SavedWindowID>?

        // MARK: Window Filters

        func window(withID id: Window.WindowID) -> Window? {
            return windows.first { $0.id() == id }
        }

        func windows(forApplicationWithPID applicationPID: pid_t) -> [Window] {
            return windows.filter { $0.pid() == applicationPID }
        }

        func windows(onScreen screen: Screen) -> [Window] {
            return windows.filter { $0.screen() == screen }
        }

        func activeWindows(onScreen screen: Screen) -> [Window] {
            guard let screenID = screen.screenID() else {
                return []
            }

            guard let currentSpace = CGSpacesInfo<Window>.currentSpaceForScreen(screen) else {
                log.warning("Could not find a space for screen: \(screenID)")
                return []
            }

            let screenWindows = windows.filter { window in
                let space = CGWindowsInfo.windowSpace(window)

                guard let windowScreen = window.screen(), currentSpace.id == space else {
                    return false
                }

                let isActive = self.isWindowActive(window)
                let isHidden = self.isWindowHidden(window)
                let isFloating = self.isWindowFloating(window)

                return windowScreen.screenID() == screen.screenID() && isActive && !isHidden && !isFloating
            }

            return screenWindows
        }

        func activeWindowOnCurrentScreen(atIndex: Int) -> Window? {
            guard let focusedWindow = Window.currentlyFocused(),
                  let currentScreen = focusedWindow.screen() else {
                return nil
            }
            let activeWindows = activeWindows(onScreen: currentScreen)

            return activeWindows.indices.contains(atIndex) ? activeWindows[atIndex] : nil
        }

        // MARK: Adding and Removing

        private func recordAddition(of window: Window) {
            additionOrder[window.id()] = nextAdditionOrder
            nextAdditionOrder += 1
        }

        /// The newest of the windows over the limit, oldest of them first.
        func newestWindows(_ windows: [Window], over limit: Int) -> [Window] {
            let byID = Dictionary(windows.map { ($0.id(), $0) }, uniquingKeysWith: { first, _ in first })
            return OverflowWindows.newest(windows.map { $0.id() }, order: additionOrder, over: limit).compactMap { byID[$0] }
        }

        func add(window: Window, atFront shouldInsertAtFront: Bool) {
            recordAddition(of: window)
            reconnectLastMain(window)

            if var order = restoredOrder, let index = order.insertionIndex(for: savedID(of: window), among: windows.map(savedID(of:))) {
                windows.insert(window, at: index)
                order.arrived(savedID(of: window))
                restoredOrder = order.isDone ? nil : order
                return
            }
            if shouldInsertAtFront {
                if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
                   let firstActiveWindow = activeWindowOnCurrentScreen(atIndex: 0) {
                    lastMainWindows[currentFocusedSpace.id] = firstActiveWindow
                }

                windows.insert(window, at: 0)
            } else {
                windows.append(window)
            }
        }

        func add(window: Window, afterWindow otherWindow: Window) -> Bool {
            guard let otherWindowIndex = windows.firstIndex(of: otherWindow) else {
                return false
            }

            recordAddition(of: window)

            windows.insert(window, at: otherWindowIndex)

            return true
        }

        func remove(window: Window) {
            for (_, lastMainWindow) in lastMainWindows where lastMainWindow?.id() == window.id() {
                if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace() {
                    let secondWindow = activeWindowOnCurrentScreen(atIndex: 1)
                    lastMainWindows[currentFocusedSpace.id] = secondWindow
                }
            }

            placementReasons.removeValue(forKey: window.id())
            additionOrder.removeValue(forKey: window.id())
            for space in recentlyFocused.keys {
                recentlyFocused[space]?.removeAll { $0 == window.id() }
            }

            guard let windowIndex = windows.firstIndex(where: { $0.id() == window.id() }) else {
                return
            }

            windows.remove(at: windowIndex)
        }

        @discardableResult func replace(window: Window, withWindow otherWindow: Window) -> Bool {
            // A tab taking another tab's place is as old as that one.
            if additionOrder[window.id()] == nil {
                if let otherOrder = additionOrder[otherWindow.id()] {
                    additionOrder[window.id()] = otherOrder
                } else {
                    recordAddition(of: window)
                }
            }

            if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
               let firstActiveWindow = activeWindowOnCurrentScreen(atIndex: 0) {
                if firstActiveWindow == window || firstActiveWindow == otherWindow {
                    lastMainWindows[currentFocusedSpace.id] = firstActiveWindow
                }
            }

            guard let otherWindowIndex = windows.firstIndex(of: otherWindow) else {
                windows.append(otherWindow)
                return false
            }

            let windowIndex = windows.firstIndex(of: window)
            windows[otherWindowIndex] = window

            if let windowIndex {
                windows.remove(at: windowIndex)
            }

            return true
        }

        @discardableResult func swap(window: Window, withWindow otherWindow: Window) -> Bool {
            if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
               let firstActiveWindow = activeWindowOnCurrentScreen(atIndex: 0) {
                if firstActiveWindow.id() == window.id() || firstActiveWindow.id() == otherWindow.id() {
                    lastMainWindows[currentFocusedSpace.id] = firstActiveWindow
                }
            }

            if windows.firstIndex(of: window) == nil {
                windows.append(window)
            }

            guard let windowIndex = windows.firstIndex(of: window), let otherWindowIndex = windows.firstIndex(of: otherWindow) else {
                return false
            }

            guard windowIndex != otherWindowIndex else {
                return false
            }

            windows[windowIndex] = otherWindow
            windows[otherWindowIndex] = window

            return true
        }

        // MARK: Restoring the Order

        private func savedID(of window: Window) -> SavedWindowID {
            return SavedWindowID(pid: window.pid(), windowID: window.cgID())
        }

        /// The window order to save when Ametrine quits.
        var savedOrder: [SavedWindowID] {
            return windows.map(savedID(of:))
        }

        func restoreOrder(_ order: [SavedWindowID]) {
            restoredOrder = order.isEmpty ? nil : RestoredWindowOrder(order)
        }

        /// The last main window per Space to save when Ametrine quits.
        var savedLastMainWindows: [CGSSpaceID: SavedWindowID] {
            return lastMainWindows.compactMapValues { $0.map(savedID(of:)) }
        }

        func restoreLastMainWindows(_ saved: [CGSSpaceID: SavedWindowID]) {
            pendingLastMainWindows = saved.isEmpty ? nil : PendingLastMainWindows(saved)
        }

        private func reconnectLastMain(_ window: Window) {
            guard var pending = pendingLastMainWindows else {
                return
            }

            for space in pending.takeSpaces(for: savedID(of: window)) {
                lastMainWindows[space] = window
            }
            pendingLastMainWindows = pending.isEmpty ? nil : pending
        }

        /// Windows arriving from now on are added as usual.
        func stopRestoringOrder() {
            restoredOrder = nil
            pendingLastMainWindows = nil
        }

        // MARK: Focus History

        private let recentlyFocusedLimit = 16

        func recordFocus(of window: Window) {
            guard let space = CGWindowsInfo.windowSpace(window) else {
                return
            }

            var history = recentlyFocused[space] ?? []
            history.removeAll { $0 == window.id() }
            history.insert(window.id(), at: 0)
            recentlyFocused[space] = Array(history.prefix(recentlyFocusedLimit))
        }

        // MARK: Window States

        func isWindowTracked(_ window: Window) -> Bool {
            return windows.contains(where: { $0.id() == window.id() })
        }

        func isWindowActive(_ window: Window) -> Bool {
            return window.isActive() && activeIDCache.contains(window.cgID())
        }

        func isWindowHidden(_ window: Window) -> Bool {
            return deactivatedPIDs.contains(window.pid())
        }

        func isWindowFloating(_ window: Window) -> Bool {
            return floatingMap[window.id()] ?? false
        }

        /// Why the window tiles or floats, as recorded by `setFloating(_:forWindow:reason:)`.
        func placementReason(for window: Window) -> PlacementReason? {
            return placementReasons[window.id()]
        }

        func setFloating(_ floating: Bool, forWindow window: Window, reason: PlacementReason) {
            floatingMap[window.id()] = floating
            placementReasons[window.id()] = reason
        }

        func activateApplication(withPID pid: pid_t) {
            deactivatedPIDs.remove(pid)
        }

        func deactivateApplication(withPID pid: pid_t) {
            deactivatedPIDs.insert(pid)
        }

        func regenerateActiveIDCache() {
            let windowDescriptions = CGWindowsInfo<Window>(options: .optionOnScreenOnly, windowID: CGWindowID(0))
            activeIDCache = windowDescriptions?.activeIDs() ?? Set()
        }

        // MARK: Window Sets

        func windowSet(forWindowsOnScreen screen: Screen) -> WindowSet<Window> {
            return windowSet(forWindows: windows(onScreen: screen))
        }

        func windowSet(forActiveWindowsOnScreen screen: Screen) -> WindowSet<Window> {
            return windowSet(forWindows: activeWindows(onScreen: screen))
        }

        func windowSet(forWindows windows: [Window]) -> WindowSet<Window> {
            let layoutWindows: [LayoutWindow<Window>] = windows.map {
                LayoutWindow(id: $0.id(), frame: $0.frame(), isFocused: $0.isFocused())
            }

            let snapshotFloatingMap = floatingMap
            let snapshotActiveIDCache = activeIDCache
            let snapshotWindowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id(), $0) })

            return WindowSet<Window>(
                windows: layoutWindows,
                isWindowWithIDActive: { id -> Bool in
                    guard let window = snapshotWindowsByID[id] else {
                        return false
                    }
                    return window.isActive() && snapshotActiveIDCache.contains(window.cgID())
                },
                isWindowWithIDFloating: { windowID -> Bool in
                    return snapshotFloatingMap[windowID] ?? false
                },
                windowForID: { windowID -> Window? in
                    return snapshotWindowsByID[windowID]
                }
            )
        }
    }
}
