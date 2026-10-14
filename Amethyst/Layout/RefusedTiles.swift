//
//  RefusedTiles.swift
//  Amethyst
//

import Foundation

/// How a tiled window's size after a layout pass compares with its tile. Apps with a minimum size (e.g. Safari) can stay bigger than a narrow tile.
struct TileFit<WindowID: Hashable> {
    /// How much bigger than its tile a window may be before it counts as refusing it, e.g. for rounding.
    static var tolerance: CGFloat { return 4 }

    let windowID: WindowID
    let applicationName: String
    let tile: CGSize
    let actual: CGSize

    /// Whether the window stayed wider or taller than its tile. Smaller never counts (e.g. Terminal's character grid).
    var refused: Bool {
        return actual.width > tile.width + TileFit.tolerance || actual.height > tile.height + TileFit.tolerance
    }
}

/**
 Which refused tiles to report: a window is reported when it first refuses its tile, and again only when its tile changes to another size it refuses. A window that fits is forgotten.

 Layout passes run often (every application switch), so re-applying the same tiles stays silent.
 */
struct RefusedTileTracker<WindowID: Hashable> {
    /// The tile size each window currently refuses, rounded to whole points.
    private var refusedTiles: [WindowID: CGSize] = [:]

    /// Records a layout pass and returns the refusals to report.
    mutating func update(_ fits: [TileFit<WindowID>]) -> [TileFit<WindowID>] {
        var report: [TileFit<WindowID>] = []

        for fit in fits {
            guard fit.refused else {
                refusedTiles.removeValue(forKey: fit.windowID)
                continue
            }

            let tile = CGSize(width: fit.tile.width.rounded(), height: fit.tile.height.rounded())
            if refusedTiles[fit.windowID] != tile {
                refusedTiles[fit.windowID] = tile
                report.append(fit)
            }
        }

        return report
    }
}

enum RefusedTileHUD {
    static func text<WindowID>(for refusals: [TileFit<WindowID>]) -> (title: String, description: String) {
        guard refusals.count == 1, let refusal = refusals.first else {
            let names = refusals.map { $0.applicationName }
            return ("\(refusals.count) windows don't fit their tiles", names.joined(separator: ", "))
        }

        return ("\(refusal.applicationName) doesn't fit its tile", "needs \(size(refusal.actual)) · tile \(size(refusal.tile))")
    }

    static func size(_ size: CGSize) -> String {
        return "\(Int(size.width.rounded())) × \(Int(size.height.rounded()))"
    }
}
