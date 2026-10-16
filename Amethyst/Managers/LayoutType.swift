//
//  LayoutManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum LayoutType<Window: WindowType> {
    enum Error: Swift.Error {
        case unknownLayout
    }

    case tall
    case tallRight
    case wide
    case wideBottom
    case twoPane
    case twoPaneRight
    case threeColumnLeft
    case threeColumnMiddle
    case threeColumnRight
    case fourColumnLeft
    case fourColumnRight
    case fullscreen
    case column
    case columnRight
    case row
    case rowBottom
    case floating
    case widescreenTallLeft
    case widescreenTallRight
    case binarySpacePartitioning

    static var standardLayouts: [LayoutType<Window>] {
        return [
            .tall,
            .tallRight,
            .wide,
            .wideBottom,
            .twoPane,
            .twoPaneRight,
            .threeColumnLeft,
            .threeColumnMiddle,
            .threeColumnRight,
            .fourColumnLeft,
            .fourColumnRight,
            .fullscreen,
            .column,
            .columnRight,
            .row,
            .rowBottom,
            .floating,
            .widescreenTallLeft,
            .widescreenTallRight,
            .binarySpacePartitioning
        ]
    }

    var key: String {
        switch self {
        case .tall:
            return "tall-left"
        case .tallRight:
            return "tall-right"
        case .wide:
            return "wide-top"
        case .wideBottom:
            return "wide-bottom"
        case .twoPane:
            return "two-pane-a"
        case .twoPaneRight:
            return "two-pane-b"
        case .threeColumnLeft:
            return "3column-left"
        case .threeColumnMiddle:
            return "3column-middle"
        case .threeColumnRight:
            return "3column-right"
        case .fourColumnLeft:
            return "4column-left"
        case .fourColumnRight:
            return "4column-right"
        case .fullscreen:
            return "fullscreen"
        case .column:
            return "column-left"
        case .columnRight:
            return "column-right"
        case .row:
            return "row-top"
        case .rowBottom:
            return "row-bottom"
        case .floating:
            return "floating"
        case .widescreenTallLeft:
            return "widescreen-tall-left"
        case .widescreenTallRight:
            return "widescreen-tall-right"
        case .binarySpacePartitioning:
            return "bsp"
        }
    }

    var layoutClass: Layout<Window>.Type {
        switch self {
        case .tall:
            return TallLayout<Window>.self
        case .tallRight:
            return TallRightLayout<Window>.self
        case .wide:
            return WideLayout<Window>.self
        case .wideBottom:
            return WideBottomLayout<Window>.self
        case .twoPane:
            return TwoPaneLayout<Window>.self
        case .twoPaneRight:
            return TwoPaneRightLayout<Window>.self
        case .threeColumnLeft:
            return ThreeColumnLeftLayout<Window>.self
        case .threeColumnMiddle:
            return ThreeColumnMiddleLayout<Window>.self
        case .threeColumnRight:
            return ThreeColumnRightLayout<Window>.self
        case .fourColumnLeft:
            return FourColumnLeftLayout<Window>.self
        case .fourColumnRight:
            return FourColumnRightLayout<Window>.self
        case .fullscreen:
            return FullscreenLayout<Window>.self
        case .column:
            return ColumnLayout<Window>.self
        case .columnRight:
            return ColumnRightLayout<Window>.self
        case .row:
            return RowLayout<Window>.self
        case .rowBottom:
            return RowBottomLayout<Window>.self
        case .floating:
            return FloatingLayout<Window>.self
        case .widescreenTallLeft:
            return WidescreenTallLayoutLeft<Window>.self
        case .widescreenTallRight:
            return WidescreenTallLayoutRight<Window>.self
        case .binarySpacePartitioning:
            return BinarySpacePartitioningLayout<Window>.self
        }
    }

    /// The layout type with that key, or `nil` for an unknown key.
    static func from(key: String) -> LayoutType<Window>? {
        return standardLayouts.first { $0.key == key }
    }

    static func layoutForKey(_ layoutKey: String) -> Layout<Window>? {
        return from(key: layoutKey)?.layoutClass.init()
    }

    static func layoutNameForKey(_ layoutKey: String) -> String? {
        return from(key: layoutKey)?.layoutClass.layoutName
    }

    static func standardLayoutClasses() -> [Layout<Window>.Type] {
        return standardLayouts.compactMap { $0.layoutClass }
    }

    // Returns a list of (key, name) pairs, with the names shown to the user (`layout-names`)
    static func availableLayoutStrings() -> [(key: String, name: String)] {
        return standardLayouts.map { ($0.key, UserConfiguration.shared.layoutDisplayName(forKey: $0.key)) }
    }

    static func layoutsWithConfiguration(_ userConfiguration: UserConfiguration) -> [Layout<Window>] {
        let layoutKeys: [String] = userConfiguration.layoutKeys()
        let layouts = layoutKeys.map { layoutKey -> Layout<Window>? in
            guard let layout = LayoutType.layoutForKey(layoutKey) else {
                log.warning("Unrecognized layout key \(layoutKey)")
                return nil
            }

            return layout
        }

        return layouts.compactMap { $0 }
    }

    static func encoded(layout: Layout<Window>) throws -> Data {
        return try JSONEncoder().encode(layout)
    }

    static func decoded(data: Data, key: String) throws -> Layout<Window> {
        guard let layoutType = LayoutType<Window>.from(key: key) else {
            throw Error.unknownLayout
        }
        return try JSONDecoder().decode(layoutType.layoutClass, from: data)
    }
}
