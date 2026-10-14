//
//  OverflowWindows.swift
//  Amethyst
//

import Foundation

/// `window-overflow: float`: which windows float when a screen has more tiled windows than `window-max-count`, and where they go.
enum OverflowWindows {
    /// The share of the screen's usable width and height a `reasonable` overflow window gets.
    static let reasonableShare = CGSize(width: 0.6, height: 0.7)

    /// How far each further window floating in the same pass is moved down and right.
    static let cascadeStep: CGFloat = 30

    /**
     The newest windows over the limit, oldest of them first. Newest means added most recently (`order`), not last in the layout, so a window
     moved to the end by a swap doesn't count as new. Windows without an order count as oldest.
     */
    static func newest<ID: Hashable>(_ ids: [ID], order: [ID: Int], over limit: Int) -> [ID] {
        let overflowCount = ids.count - max(0, limit)
        guard overflowCount > 0 else {
            return []
        }

        let byAge = ids.enumerated().sorted { lhs, rhs in
            let lhsOrder = order[lhs.element] ?? Int.min
            let rhsOrder = order[rhs.element] ?? Int.min
            return lhsOrder != rhsOrder ? lhsOrder < rhsOrder : lhs.offset < rhs.offset
        }
        return byAge.suffix(overflowCount).map { $0.element }
    }

    /// The size to give an overflow window in a screen's usable area, never bigger than the area.
    static func size(in area: CGRect, mode: WindowOverflowSize, fixedSize: CGSize?) -> CGSize {
        switch (mode, fixedSize) {
        case let (.fixed, fixedSize?):
            return CGSize(width: min(fixedSize.width, area.width), height: min(fixedSize.height, area.height))
        default:
            return CGSize(width: (area.width * reasonableShare.width).rounded(), height: (area.height * reasonableShare.height).rounded())
        }
    }

    /// A frame of the given size centred in the area, moved down and right by `cascade` steps, and kept inside the area where it fits.
    static func frame(size: CGSize, centeredIn area: CGRect, cascade: Int) -> CGRect {
        let offset = CGFloat(cascade) * cascadeStep
        var origin = CGPoint(x: (area.midX - size.width / 2 + offset).rounded(), y: (area.midY - size.height / 2 + offset).rounded())
        origin.x = max(area.minX, min(origin.x, area.maxX - size.width))
        origin.y = max(area.minY, min(origin.y, area.maxY - size.height))
        return CGRect(origin: origin, size: size)
    }

    /// How close a window's centre must be to a cascade slot's to take it.
    static let slotTolerance: CGFloat = 4

    /**
     The first cascade slot from `start` that no window floating over the limit takes yet: slot 0 is the area's centre, each further one 30 pt down and
     right. Slots are matched by centre, so windows of any size fit them, and a slot frees up when its window closes, tiles or is moved away.
     */
    static func cascadeIndex(occupiedCenters: [CGPoint], in area: CGRect, start: Int = 0) -> Int {
        let isOccupied = { (index: Int) -> Bool in
            let offset = CGFloat(index) * cascadeStep
            let center = CGPoint(x: area.midX + offset, y: area.midY + offset)
            return occupiedCenters.contains { abs($0.x - center.x) <= slotTolerance && abs($0.y - center.y) <= slotTolerance }
        }

        var index = start
        while isOccupied(index) && index < start + occupiedCenters.count {
            index += 1
        }
        return index
    }

    /// The overflow window size in words, for the palette and the HUD.
    static func sizeDescription(mode: WindowOverflowSize, fixedSize: CGSize?) -> String {
        guard mode == .fixed, let fixedSize else {
            return "\(Int(reasonableShare.width * 100))% × \(Int(reasonableShare.height * 100))%"
        }

        return "\(Int(fixedSize.width)) × \(Int(fixedSize.height))"
    }
}
