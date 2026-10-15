//
//  DirectionalNavigation.swift
//  Amethyst
//
//  Directional focus and swap: finds the window west, east, north or south of another.
//

import CoreGraphics
import Foundation

enum Direction: String, CaseIterable {
    case west
    case east
    case north
    case south
}

/**
 The neighbour finder for `focus-<direction>` and `swap-<direction>` (and later `warp-<direction>`).

 Works on the layout's assigned frames, before window margins, so neighbours share an exact edge. Frames are in screen coordinates with the origin at the top left: north is a smaller y.
 */
enum DirectionalNavigation {
    /// Points of slack when comparing edges and sizes.
    static let tolerance: CGFloat = 1

    /**
     The window in `direction` from `focused`, or `nil` at the screen edge.

     - Parameters:
        - focused: The frame to start from: the focused window's assigned frame, or a floating window's live frame.
        - frames: The candidate windows' assigned frames, without the focused window.
        - frontToBack: Window order on screen, frontmost first. Of windows sharing a frame, only the frontmost is reachable.
        - mru: Recently focused windows, most recent first.
     */
    static func neighbor<ID: Hashable>(of focused: CGRect, direction: Direction, frames: [ID: CGRect], frontToBack: [ID], mru: [ID]) -> ID? {
        let candidates = visible(frames.filter { isStrictly(direction, of: focused, $0.value) }, frontToBack: frontToBack)

        guard !candidates.isEmpty else {
            return nil
        }

        let overlapping = candidates.filter { overlap(focused, $0.frame, direction) > tolerance }

        guard !overlapping.isEmpty else {
            return candidates.min { centreDistance(focused, $0.frame) < centreDistance(focused, $1.frame) }?.id
        }

        let mruIndex = Dictionary(mru.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

        // The nearest column (or row) first: from 3Column's right column, west is the middle column, not main.
        return overlapping.min { lhs, rhs in
            let lhsGap = gap(focused, lhs.frame, direction)
            let rhsGap = gap(focused, rhs.frame, direction)
            if abs(lhsGap - rhsGap) > tolerance {
                return lhsGap < rhsGap
            }

            let lhsOverlap = overlap(focused, lhs.frame, direction)
            let rhsOverlap = overlap(focused, rhs.frame, direction)
            if abs(lhsOverlap - rhsOverlap) > tolerance {
                return lhsOverlap > rhsOverlap
            }

            let lhsRecency = mruIndex[lhs.id] ?? Int.max
            let rhsRecency = mruIndex[rhs.id] ?? Int.max
            if lhsRecency != rhsRecency {
                return lhsRecency < rhsRecency
            }

            return centreDistance(focused, lhs.frame) < centreDistance(focused, rhs.frame)
        }?.id
    }

    static func isStrictly(_ direction: Direction, of focused: CGRect, _ candidate: CGRect) -> Bool {
        switch direction {
        case .west:
            return candidate.maxX <= focused.minX + tolerance
        case .east:
            return candidate.minX >= focused.maxX - tolerance
        case .north:
            return candidate.maxY <= focused.minY + tolerance
        case .south:
            return candidate.minY >= focused.maxY - tolerance
        }
    }

    /// Of candidates sharing a frame (e.g. Two Pane's secondary stack), keeps only the frontmost.
    private static func visible<ID: Hashable>(_ frames: [ID: CGRect], frontToBack: [ID]) -> [(id: ID, frame: CGRect)] {
        let depth = Dictionary(frontToBack.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let byDepth = frames.map { (id: $0.key, frame: $0.value) }.sorted { (depth[$0.id] ?? Int.max) < (depth[$1.id] ?? Int.max) }

        var kept: [(id: ID, frame: CGRect)] = []
        for candidate in byDepth where !kept.contains(where: { sameFrame($0.frame, candidate.frame) }) {
            kept.append(candidate)
        }
        return kept
    }

    private static func sameFrame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        return abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    /// Overlap on the axis perpendicular to the direction: vertical overlap for west and east.
    private static func overlap(_ focused: CGRect, _ candidate: CGRect, _ direction: Direction) -> CGFloat {
        switch direction {
        case .west, .east:
            return max(0, min(focused.maxY, candidate.maxY) - max(focused.minY, candidate.minY))
        case .north, .south:
            return max(0, min(focused.maxX, candidate.maxX) - max(focused.minX, candidate.minX))
        }
    }

    /// Distance along the direction between the facing edges.
    private static func gap(_ focused: CGRect, _ candidate: CGRect, _ direction: Direction) -> CGFloat {
        switch direction {
        case .west:
            return max(0, focused.minX - candidate.maxX)
        case .east:
            return max(0, candidate.minX - focused.maxX)
        case .north:
            return max(0, focused.minY - candidate.maxY)
        case .south:
            return max(0, candidate.minY - focused.maxY)
        }
    }

    private static func centreDistance(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        return hypot(lhs.midX - rhs.midX, lhs.midY - rhs.midY)
    }

    /**
     Browsing a stack of windows that share one tile (Two Pane's secondary pane): the next or previous window, wrapping around.

     - Parameters:
        - stack: The stacked windows in window order.
        - current: The focused window. From outside the stack (main), the step starts at `front`, or at the first window.
        - front: The stacked window in front, if known.
        - forward: Next (`true`) or previous.
     */
    static func stackStep<ID: Hashable>(stack: [ID], current: ID, front: ID?, forward: Bool) -> ID? {
        guard !stack.isEmpty else {
            return nil
        }

        let start = stack.firstIndex(of: current) ?? front.flatMap { stack.firstIndex(of: $0) } ?? 0
        return stack[(start + (forward ? 1 : stack.count - 1)) % stack.count]
    }

    /// Whether `direction` browses Two Pane's stack: forward, backward, or `nil` when it stays spatial. The browsing axis is the one that
    /// crosses no pane: north/south when the panes sit side by side (landscape), west/east when they're stacked (portrait).
    static func stackBrowse(_ direction: Direction, isLandscape: Bool) -> Bool? {
        switch (direction, isLandscape) {
        case (.north, true), (.west, false):
            return false
        case (.south, true), (.east, false):
            return true
        default:
            return nil
        }
    }
}
