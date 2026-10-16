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

    /// BSP: whether a window dropped at `point` takes the first half of `tile`. BSP splits a wide tile into left and right
    /// and a tall one into top and bottom, so that's the left or the top half.
    static func takesFirstHalf(at point: CGPoint, of tile: CGRect) -> Bool {
        return tile.width > tile.height ? point.x < tile.midX : point.y < tile.midY
    }
}
