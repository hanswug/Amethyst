//
//  MouseDrop.swift
//  Amethyst
//
//  What dropping a dragged window does: Shift makes it a warp, and the point decides where it lands.
//

import Cocoa

enum MouseDrop {
    /// Shift alone, held as the button comes up, turns a drop into a warp; with any other modifier it stays a swap.
    static func isWarp(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        return modifiers.intersection([.shift, .control, .option, .command]) == .shift
    }

    /**
     Where a warp dropped at `point` goes: the tile under it, else an empty side pane under it.

     - Parameters:
         - tiles: Each tiled window's index in the window list and its tile, in list order. Stacked windows share a tile;
           the first of them wins, as for a swap.
         - emptyPaneFrames: The frames of side panes that have no window (`Layout.emptyPaneFrames`).
     */
    static func warpTarget(at point: CGPoint, tiles: [(index: Int, frame: CGRect)], emptyPaneFrames: [Int: CGRect]) -> PaneCounts.WarpTarget? {
        if let tile = tiles.first(where: { $0.frame.contains(point) }) {
            return .window(tile.index)
        }
        if let pane = emptyPaneFrames.filter({ $0.value.contains(point) }).keys.min() {
            return .emptyPane(pane)
        }
        return nil
    }

    /// Whether a plain drop at `point` lands on the dragged window's own tile, and so changes nothing.
    static func dropsOnOwnTile(at point: CGPoint, ownTile: CGRect) -> Bool {
        return ownTile.contains(point)
    }

    /// BSP: whether a window dropped at `point` takes the first half of `tile`. BSP splits a wide tile into left and right
    /// and a tall one into top and bottom, so that's the left or the top half.
    static func takesFirstHalf(at point: CGPoint, of tile: CGRect) -> Bool {
        return tile.width > tile.height ? point.x < tile.midX : point.y < tile.midY
    }
}

/// Whether a tiled window moved or resized by another app (Raycast, a script), not the mouse, goes back to its tile
/// (`snap-back-windows`). The setting, the mouse buttons and whether the window tiles are checked by the caller.
enum ExternalSnapBack {
    /// Frame changes this soon after a layout pass are Ametrine's own (as for mouse drags).
    static let ownPassSeconds: TimeInterval = 0.15
    /// A window snaps back this way at most once in this time, so an app that won't take its tile can't start a loop.
    static let repeatSeconds: TimeInterval = 1
    /// Other apps move and resize in several steps; act once they're done.
    static let delaySeconds: TimeInterval = 0.25
    /// How much smaller than its tile a window must get, corner in place, to count as resized by another app.
    static let clearShrink: CGFloat = 40

    static func shouldSnapBack(frame: CGRect, tile: CGRect, screen: CGRect, sinceReflow: TimeInterval, sinceLastSnapBack: TimeInterval?) -> Bool {
        guard sinceReflow > ownPassSeconds else {
            return false
        }
        if let sinceLastSnapBack, sinceLastSnapBack < repeatSeconds {
            return false
        }

        // A window that kept its corner and grew past its tile, or shrank by a few points, is the app adjusting itself
        // (a minimum size, Terminal's character grid), which a snap back can't change. Raycast's "left half" keeps the
        // corner too, but shrinks clearly.
        let tolerance = TileFit<Int>.tolerance
        let cornerMoved = abs(frame.minX - tile.minX) > tolerance || abs(frame.minY - tile.minY) > tolerance
        if !cornerMoved {
            let grew = frame.width > tile.width + tolerance || frame.height > tile.height + tolerance
            let shrankClearly = frame.width < tile.width - clearShrink || frame.height < tile.height - clearShrink
            guard shrankClearly && !grew else {
                return false
            }
        }

        // Show desktop (click the wallpaper) pushes windows to the screen edges; leave windows mostly off screen alone.
        let visible = frame.intersection(screen)
        guard !visible.isNull, frame.width > 0, frame.height > 0 else {
            return false
        }
        return visible.width * visible.height >= frame.width * frame.height / 2
    }
}
