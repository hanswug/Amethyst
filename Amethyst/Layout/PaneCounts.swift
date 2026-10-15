//
//  PaneCounts.swift
//  Amethyst
//
//  How many windows each pane of a paned layout holds, stored so warp can grow and shrink panes.
//

import Foundation

/**
 The windows per pane of a paned layout, in window-list order: main first, then the side panes.

 The window list stays pane-contiguous: the first `counts[0]` windows are main, the next `counts[1]` the first side pane,
 and so on. Swap, swap-main and drag-swap work on list order and keep these sizes; warp and arriving or departing windows
 change them.

 The layout's main pane count is a maximum: main holds at most that many windows. It fills by warp, by a window arriving
 at the front of the list (`main-arrival-position: first`), or by new windows while the side panes are empty.
 */
struct PaneCounts: Codable, Equatable, CustomStringConvertible {
    private(set) var counts: [Int]

    init(_ counts: [Int]) {
        self.counts = counts
    }

    /// Empty panes.
    init(paneCount: Int) {
        self.counts = Array(repeating: 0, count: paneCount)
    }

    var paneCount: Int { counts.count }
    var total: Int { counts.reduce(0, +) }
    var main: Int { counts.first ?? 0 }

    subscript(pane: Int) -> Int {
        return counts.indices.contains(pane) ? counts[pane] : 0
    }

    /// Main on the left, then the side panes, e.g. `1|2|2`.
    var description: String {
        return counts.map(String.init).joined(separator: "|")
    }

    /// The list index of the pane's first window.
    func startIndex(ofPane pane: Int) -> Int {
        return counts.prefix(pane).reduce(0, +)
    }

    /// The pane holding the window at `index` in the list.
    func pane(ofIndex index: Int) -> Int {
        var end = 0
        for (pane, count) in counts.enumerated() {
            end += count
            if index < end {
                return pane
            }
        }
        return max(0, paneCount - 1)
    }

    /// Side panes that hold no window.
    var emptySidePanes: [Int] {
        return counts.indices.dropFirst().filter { counts[$0] == 0 }
    }

    // MARK: Fitting to a window count

    /**
     These sizes made to hold exactly `windowCount` windows, without knowing which windows: for laying out a window set
     the stored sizes don't match, and for adopting the stored sizes on the first pass (launch, restore, first use).

     Too many: side panes lose windows from the last one back, main last. Too few: the extra windows arrive one at a
     time, as new windows do (`adding`). From empty panes this gives the balanced split, e.g. 1|2|2 for five windows.
     */
    func fitted(to windowCount: Int, maxMain: Int) -> PaneCounts {
        var counts = self.counts
        var excess = total - windowCount
        for pane in counts.indices.reversed() where excess > 0 {
            let removed = min(counts[pane], excess)
            counts[pane] -= removed
            excess -= removed
        }

        var fitted = PaneCounts(counts)
        while fitted.total < windowCount {
            fitted = fitted.adding(maxMain: maxMain)
        }
        return fitted.normalized(maxMain: maxMain)
    }

    /// One new window: main while main has room and the side panes are empty, otherwise the shortest side pane, ties to the first.
    func adding(maxMain: Int) -> PaneCounts {
        var counts = self.counts
        counts[PaneCounts.paneForNewWindow(counts, maxMain: maxMain)] += 1
        return PaneCounts(counts)
    }

    static func paneForNewWindow(_ counts: [Int], maxMain: Int) -> Int {
        let sides = counts.indices.dropFirst()
        if counts[0] == 0 || (counts[0] < max(1, maxMain) && sides.allSatisfy { counts[$0] == 0 }) {
            return 0
        }
        return sides.min { counts[$0] < counts[$1] } ?? 0
    }

    /**
     The sizes after the rules every pass keeps:
     - main holds at most `maxMain`; the extra windows go to the first side pane;
     - main never empties while there are windows: the first side window slides in;
     - an empty side pane takes a window from a later one (1|0|2 → 1|1|1), so a side pane is empty only when there
       aren't enough windows.

     The list is pane-contiguous, so these moves change no window order, only where the pane boundaries are.
     */
    func normalized(maxMain: Int) -> PaneCounts {
        var counts = self.counts
        PaneCounts.normalize(&counts, maxMain: maxMain) { _, _ in }
        return PaneCounts(counts)
    }

    /// Applies `normalized`'s rules; `move(source, destination)` reports each window moved between panes.
    fileprivate static func normalize(_ counts: inout [Int], maxMain: Int, move: (_ source: Int, _ destination: Int) -> Void) {
        guard counts.count > 1 else {
            return
        }

        let maxMain = max(1, maxMain)
        while counts[0] > maxMain {
            counts[0] -= 1
            counts[1] += 1
            move(0, 1)
        }

        if counts[0] == 0, let pane = counts.indices.dropFirst().first(where: { counts[$0] > 0 }) {
            counts[pane] -= 1
            counts[0] += 1
            move(pane, 0)
        }

        for pane in counts.indices.dropFirst() where counts[pane] == 0 {
            guard let later = (pane + 1 ..< counts.count).first(where: { counts[$0] > 0 }) else {
                break
            }
            counts[later] -= 1
            counts[pane] += 1
            move(later, pane)
        }
    }

    // MARK: Warp

    enum WarpTarget: Equatable {
        /// The neighbour window, by its index in the list.
        case window(Int)
        /// A side pane with no window, which still has its column.
        case emptyPane(Int)
    }

    enum WarpPlan: Equatable {
        /// Swap with the window at this index; the sizes stay.
        case swap(Int)
        /// Remove the window, insert it at `index` (counted after the removal), and take these sizes.
        case move(toIndex: Int, counts: PaneCounts)
    }

    /**
     What a warp from the window at `index` does (handover §5.5, as agreed 2026-10-14):
     - neighbour in the same pane → swap;
     - the window is its pane's last → swap (a warp never empties a pane); into an empty pane it does nothing;
     - otherwise it joins the neighbour's pane right after the neighbour; into main, at the top (`intoMainAtFront`) or
       the bottom, wherever the neighbour is. An empty pane gets it as its only window.

     Main may end up holding more than the maximum; the layout raises the maximum to match.
     */
    func warp(from index: Int, to target: WarpTarget, intoMainAtFront: Bool) -> WarpPlan? {
        guard index >= 0, index < total else {
            return nil
        }

        let sourcePane = pane(ofIndex: index)
        let targetPane: Int
        switch target {
        case let .window(targetIndex):
            guard targetIndex >= 0, targetIndex < total, targetIndex != index else {
                return nil
            }
            targetPane = pane(ofIndex: targetIndex)
            if targetPane == sourcePane || counts[sourcePane] == 1 {
                return .swap(targetIndex)
            }
        case let .emptyPane(pane):
            guard counts.indices.contains(pane), pane != sourcePane, counts[pane] == 0, counts[sourcePane] > 1 else {
                return nil
            }
            targetPane = pane
        }

        var newCounts = counts
        newCounts[sourcePane] -= 1

        let destination: Int
        switch target {
        case let .window(targetIndex) where targetPane != 0:
            let neighbourAfterRemoval = targetIndex > index ? targetIndex - 1 : targetIndex
            destination = neighbourAfterRemoval + 1
        case .window:
            destination = intoMainAtFront ? 0 : newCounts[0]
        case .emptyPane:
            destination = newCounts.prefix(targetPane).reduce(0, +)
        }

        newCounts[targetPane] += 1
        return .move(toIndex: destination, counts: PaneCounts(newCounts))
    }

    /**
     What `warp-main` does with the window at `index` (agreed 2026-10-14): it joins main from wherever it is, at the top
     (`intoMainAtFront`) or the bottom. A window already in main stays; the last window of a side pane swaps with main's
     top window instead (a warp never empties a pane).
     */
    func warpIntoMain(from index: Int, intoMainAtFront: Bool) -> WarpPlan? {
        guard index >= 0, index < total else {
            return nil
        }

        let sourcePane = pane(ofIndex: index)
        guard sourcePane != 0 else {
            return nil
        }
        if counts[sourcePane] == 1 {
            return .swap(0)
        }

        var newCounts = counts
        newCounts[sourcePane] -= 1
        newCounts[0] += 1
        return .move(toIndex: intoMainAtFront ? 0 : counts[0], counts: PaneCounts(newCounts))
    }
}

/**
 A paned layout's stored sizes together with which pane each window was in at the last pass, so the sizes follow the
 window set even when events are lost (hiding an app, a window closed on another Space): the BSP lesson.
 */
struct PaneState<ID: Hashable> {
    private(set) var counts: PaneCounts
    /// The pane each window was in at the last pass. Never saved: window IDs don't survive a relaunch.
    private(set) var snapshot: [ID: Int] = [:]
    /// The windows at the last pass, in order: a window taking a gone window's place is a tab switch.
    private var previousOrder: [ID] = []
    /// Sizes restored from saved state, kept while the windows trickle in after a relaunch, so the sizes come back
    /// whatever order the windows arrive in. Dropped once they're all there, a window leaves, or a warp sets sizes.
    private var restoredCounts: PaneCounts?

    init(counts: PaneCounts, restored: Bool = false) {
        self.counts = counts
        self.restoredCounts = restored && counts.total > 0 ? counts : nil
    }

    struct Reconciliation: Equatable {
        /// The windows in their new order, when some had to move to reach their pane.
        let reorderedIDs: [ID]?
        let counts: PaneCounts
    }

    /**
     Brings the sizes in line with the windows of this pass, in list order:
     - a window gone since the last pass shrinks the pane it was in;
     - a new window at the front (`main-arrival-position: first`, or put there by the restored order) joins main;
     - a new window at the end joins main while main has room and the side panes are empty, otherwise the shortest side
       pane (ties to the first), moved in the list to that pane's end;
     - a new window between others joins the pane of the window before it;
     - then the `PaneCounts.normalized` rules.

     A new window in the place of one that's gone (a tab switch) takes that window's pane.

     With no snapshot (launch, restore, first use) or none of its windows left, the stored sizes are fitted to the
     window count and no window moves. So they are while restored windows are still arriving after a relaunch.
     */
    mutating func reconcile(windowIDs: [ID], maxMain: Int) -> Reconciliation {
        let present = Set(windowIDs)
        if let restored = restoredCounts {
            let windowLeft = previousOrder.contains { !present.contains($0) }
            if windowLeft || windowIDs.count >= restored.total {
                restoredCounts = nil
            }
            if !windowLeft && windowIDs.count <= restored.total {
                return adopt(restored, windowIDs: windowIDs, maxMain: maxMain)
            }
        }

        // A tab switch: the new tab is where the old one was, and takes its pane.
        let previousSet = Set(previousOrder)
        for index in previousOrder.indices where index < windowIDs.count {
            let previousID = previousOrder[index]
            let currentID = windowIDs[index]
            if !present.contains(previousID), !previousSet.contains(currentID), let pane = snapshot[previousID] {
                snapshot[currentID] = pane
                snapshot[previousID] = nil
            }
        }

        let knownIDs = windowIDs.filter { snapshot[$0] != nil }
        guard !knownIDs.isEmpty else {
            return adopt(counts, windowIDs: windowIDs, maxMain: maxMain)
        }

        var sizes = counts.counts
        for (id, pane) in snapshot where !present.contains(id) && sizes.indices.contains(pane) {
            sizes[pane] = max(0, sizes[pane] - 1)
        }
        if sizes.reduce(0, +) != knownIDs.count {
            log.warning("Pane sizes \(PaneCounts(sizes)) don't match \(knownIDs.count) known windows; refitting")
            sizes = PaneCounts(sizes).fitted(to: knownIDs.count, maxMain: maxMain).counts
        }

        var panes: [[ID]] = []
        var start = 0
        for size in sizes {
            panes.append(Array(knownIDs[start ..< start + size]))
            start += size
        }

        let firstKnownIndex = windowIDs.firstIndex { snapshot[$0] != nil } ?? 0
        let lastKnownIndex = windowIDs.lastIndex { snapshot[$0] != nil } ?? 0
        var frontArrivals = 0

        for (index, id) in windowIDs.enumerated() where snapshot[id] == nil {
            if index < firstKnownIndex {
                panes[0].insert(id, at: frontArrivals)
                frontArrivals += 1
            } else if index > lastKnownIndex {
                let pane = PaneCounts.paneForNewWindow(panes.map(\.count), maxMain: maxMain)
                panes[pane].append(id)
            } else {
                let previousID = windowIDs[index - 1]
                for pane in panes.indices {
                    if let position = panes[pane].firstIndex(of: previousID) {
                        panes[pane].insert(id, at: position + 1)
                        break
                    }
                }
            }
        }

        var normalizedSizes = panes.map(\.count)
        PaneCounts.normalize(&normalizedSizes, maxMain: maxMain) { source, destination in
            // Main's overflow goes to the front of the next pane; any other move takes a pane's first window to the end
            // of an earlier one.
            if source < destination {
                panes[destination].insert(panes[source].removeLast(), at: 0)
            } else {
                panes[destination].append(panes[source].removeFirst())
            }
        }

        let order = panes.flatMap { $0 }
        counts = PaneCounts(panes.map(\.count))
        takeSnapshot(of: order)
        return Reconciliation(reorderedIDs: order == windowIDs ? nil : order, counts: counts)
    }

    /// Takes the sizes a warp decided; the snapshot follows at the next pass.
    mutating func setCounts(_ counts: PaneCounts) {
        self.counts = counts
        restoredCounts = nil
    }

    /// The sizes fitted to the window count, no window moved.
    private mutating func adopt(_ counts: PaneCounts, windowIDs: [ID], maxMain: Int) -> Reconciliation {
        self.counts = counts.fitted(to: windowIDs.count, maxMain: maxMain)
        takeSnapshot(of: windowIDs)
        return Reconciliation(reorderedIDs: nil, counts: self.counts)
    }

    private mutating func takeSnapshot(of windowIDs: [ID]) {
        previousOrder = windowIDs
        snapshot = [:]
        for (index, id) in windowIDs.enumerated() {
            snapshot[id] = counts.pane(ofIndex: index)
        }
    }
}
