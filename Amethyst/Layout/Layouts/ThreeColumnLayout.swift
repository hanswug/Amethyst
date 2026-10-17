//
//  ThreeColumnLayout.swift
//  Amethyst
//
//  Originally created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//
//  Modifications by Craig Disselkoen on 09/03/18.
//

import Silica

// we'd like to hide these structures and enums behind fileprivate, but
// https://bugs.swift.org/browse/SR-47

enum Column {
    case left
    case middle
    case right
}

enum Pane {
    case main
    case secondary
    case tertiary
}

struct TriplePaneArrangement {
    /// number of windows in pane
    private let paneCount: [Pane: UInt]

    /// height of windows in pane
    private let paneWindowHeight: [Pane: CGFloat]

    /// width of windows in pane
    private let paneWindowWidth: [Pane: CGFloat]

    // how panes relate to columns
    private let panePosition: [Pane: Column]

    /// how columns relate to panes
    private let columnDesignation: [Column: Pane]

    /**
     - Parameters:
        - mainPane: which Column is the main Pane
        - numWindows: how many windows total
        - numMainPane: how many windows in the main Pane
        - screenSize: total size of the screen
        - mainPaneRatio: ratio of the screen taken by main pane
     */
    init(mainPane: Column, numWindows: UInt, numMainPane: UInt, screenSize: CGSize, mainPaneRatio: CGFloat) {
        // calculate how many are in each type
        let mainPaneCount = min(numWindows, numMainPane)
        let nonMainCount: UInt = numWindows - mainPaneCount
        // we do tertiary first because a single window produces a zero in integer division by 2
        let tertiaryPaneCount = nonMainCount >> 1
        let secondaryPaneCount = nonMainCount - tertiaryPaneCount
        self.init(mainPane: mainPane, counts: [mainPaneCount, secondaryPaneCount, tertiaryPaneCount], screenSize: screenSize, mainPaneRatio: mainPaneRatio)
    }

    /**
     - Parameters:
        - mainPane: which Column is the main Pane
        - counts: how many windows each pane holds: main, secondary, tertiary
        - screenSize: total size of the screen
        - mainPaneRatio: ratio of the screen taken by main pane
     */
    init(mainPane: Column, counts: [UInt], screenSize: CGSize, mainPaneRatio: CGFloat) {
        // forward and reverse mapping of columns to their designations
        self.panePosition = {
            switch mainPane {
            case .left:   return [.main: .left, .secondary: .middle, .tertiary: .right]
            case .middle: return [.main: .middle, .secondary: .left, .tertiary: .right]
            case .right:  return [.main: .right, .secondary: .middle, .tertiary: .left]
            }
        }()
        // swap keys and values for reverse lookup
        self.columnDesignation = Dictionary(uniqueKeysWithValues: panePosition.map({ ($1, $0) }))

        let mainPaneCount = counts[0]
        let secondaryPaneCount = counts[1]
        let tertiaryPaneCount = counts[2]
        self.paneCount = [.main: mainPaneCount, .secondary: secondaryPaneCount, .tertiary: tertiaryPaneCount]

        // calculate heights
        let screenHeight = screenSize.height
        self.paneWindowHeight = [
            .main: round(screenHeight / CGFloat(mainPaneCount)),
            .secondary: secondaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(secondaryPaneCount)),
            .tertiary: tertiaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(tertiaryPaneCount))
        ]

        // calculate widths
        let screenWidth = screenSize.width
        let mainWindowWidth = secondaryPaneCount == 0 ? screenWidth : round(screenWidth * mainPaneRatio)
        // The last side column takes the rounding remainder, so the columns fill the screen exactly and twins mirror to the pixel.
        let secondaryWindowWidth = round((screenWidth - mainWindowWidth) / 2)
        self.paneWindowWidth = [
            .main: mainWindowWidth,
            .secondary: secondaryWindowWidth,
            .tertiary: screenWidth - mainWindowWidth - secondaryWindowWidth
        ]
   }

    func count(_ pane: Pane) -> UInt {
        return paneCount[pane]!
    }

    func height(_ pane: Pane) -> CGFloat {
        return paneWindowHeight[pane]!
    }

    func width(_ pane: Pane) -> CGFloat {
        return paneWindowWidth[pane]!
    }

    func firstIndex(_ pane: Pane) -> UInt {
        switch pane {
        case .main: return 0
        case .secondary: return count(.main)
        case .tertiary: return count(.main) + count(.secondary)
        }
    }

    func pane(ofIndex windowIndex: UInt) -> Pane {
        if windowIndex >= firstIndex(.tertiary) {
            return .tertiary
        }
        if windowIndex >= firstIndex(.secondary) {
            return .secondary
        }
        return .main
    }

    /// Given a window index, which Pane does it belong to, and which index within that Pane
    func coordinates(at windowIndex: UInt) -> (Pane, UInt) {
        let pane = self.pane(ofIndex: windowIndex)
        return (pane, windowIndex - firstIndex(pane))
    }

    /// Get the (height, width) dimensions for a window in the given Pane
    func windowDimensions(inPane pane: Pane) -> (CGFloat, CGFloat) {
        return (height(pane), width(pane))
    }

    /// Get the Column assignment for the given Pane
    func column(ofPane pane: Pane) -> Column {
        return panePosition[pane]!
    }

    func pane(ofColumn column: Column) -> Pane {
        return columnDesignation[column]!
    }

    /// Get the column widths in the order (left, middle, right)
    func widthsLeftToRight() -> (CGFloat, CGFloat, CGFloat) {
        return (width(pane(ofColumn: .left)), width(pane(ofColumn: .middle)), width(pane(ofColumn: .right)))
    }

    /// How far the pane's column starts from the screen's left edge.
    func offsetX(ofPane pane: Pane) -> CGFloat {
        let (leftPaneWidth, middlePaneWidth, _) = widthsLeftToRight()
        switch column(ofPane: pane) {
        case .left: return 0.0
        case .middle: return leftPaneWidth
        case .right: return leftPaneWidth + middlePaneWidth
        }
    }
}

// not an actual Layout, just a base class for the three actual Layouts below
class ThreeColumnLayout<Window: WindowType>: PaneCountedLayout<Window> {
    class var mainColumn: Column { fatalError("Must be implemented by subclass") }

    override class var paneCount: Int { return 3 }

    private static var panes: [Pane] { [.main, .secondary, .tertiary] }

    private func arrangement(windowCount: Int, screenSize: CGSize) -> TriplePaneArrangement {
        return TriplePaneArrangement(
            mainPane: type(of: self).mainColumn,
            counts: fittedPaneCounts(windowCount: windowCount).counts.map { UInt($0) },
            screenSize: screenSize,
            mainPaneRatio: mainPaneRatio
        )
    }

    /// A side column left without windows keeps its width (e.g. main count 3 took a side window into main).
    override func emptyPaneFrames(windowCount: Int, on screen: Screen) -> [Int: CGRect] {
        guard windowCount > 0 else {
            return [:]
        }

        let screenFrame = screen.adjustedFrame()
        let paneArrangement = arrangement(windowCount: windowCount, screenSize: screenFrame.size)
        var frames: [Int: CGRect] = [:]
        for (index, pane) in Self.panes.enumerated() where pane != .main && paneArrangement.count(pane) == 0 && paneArrangement.width(pane) > 0 {
            frames[index] = CGRect(
                x: screenFrame.origin.x + paneArrangement.offsetX(ofPane: pane),
                y: screenFrame.origin.y,
                width: paneArrangement.width(pane),
                height: screenFrame.height
            )
        }
        return frames
    }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let paneArrangement = arrangement(windowCount: windows.count, screenSize: screenFrame.size)

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignmentOperation<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex: UInt = UInt(frameAssignments.count)

            let (pane, paneIndex) = paneArrangement.coordinates(at: windowIndex)

            let (windowHeight, windowWidth): (CGFloat, CGFloat) = paneArrangement.windowDimensions(inPane: pane)

            let xorigin: CGFloat = screenFrame.origin.x + paneArrangement.offsetX(ofPane: pane)

            let scaleFactor: CGFloat = screenFrame.width / {
                if pane == .main {
                    return paneArrangement.width(.main)
                }
                return paneArrangement.width(.secondary) + paneArrangement.width(.tertiary)
            }()

            windowFrame.origin.x = xorigin
            windowFrame.origin.y = screenFrame.origin.y + (windowHeight * CGFloat(paneIndex))
            windowFrame.size.width = windowWidth
            windowFrame.size.height = windowHeight

            let isMain = windowIndex < paneArrangement.firstIndex(.secondary)

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment<Window>(
                frame: windowFrame,
                window: window,
                screenFrame: screenFrame,
                resizeRules: resizeRules
            )

            assignments.append(FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet))

            return assignments
        }
    }
}

// implement the three variants

class ThreeColumnLeftLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Left" }
    override static var layoutKey: String { return "3column-left" }
    override static var mainColumn: Column { return .left }
}

class ThreeColumnMiddleLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Middle" }
    override static var layoutKey: String { return "3column-middle" }
    override static var mainColumn: Column { return .middle }

    /**
     `flip-twin` for 3Column Middle, which has no twin (Hans, 2026-10-17): the left and right columns swap windows and sizes,
     so the picture is its mirror image. Needs both side columns to hold windows: an empty side column can only be the right.

     - Returns: The window order and pane sizes after the swap, or `nil` when it can't.
     */
    func sideSwap<ID>(of windowIDs: [ID]) -> (order: [ID], counts: PaneCounts)? {
        let counts = fittedPaneCounts(windowCount: windowIDs.count).counts
        let (main, left, right) = (counts[0], counts[1], counts[2])
        guard left > 0, right > 0 else {
            return nil
        }

        let order = Array(windowIDs[0 ..< main] + windowIDs[(main + left)...] + windowIDs[main ..< main + left])
        return (order, PaneCounts([main, right, left]))
    }
}

class ThreeColumnRightLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Right" }
    override static var layoutKey: String { return "3column-right" }
    override static var mainColumn: Column { return .right }
}
