//
//  FourColumnLayout.swift
//  Amethyst
//
//  Originally created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//
//  Modifications by Craig Disselkoen on 09/03/18.
//  Modifications by Reyk Floeter on 10/28/21.
//

import Silica

// we'd like to hide these structures and enums behind fileprivate, but
// https://bugs.swift.org/browse/SR-47

enum FourColumn {
    case left
    case middleLeft
    case middleRight
    case right
}

enum FourPane {
    case main
    case secondary
    case tertiary
    case quaternary
}

struct FourPaneWidths {
    var left: CGFloat = 0
    var middleLeft: CGFloat = 0
    var middleRight: CGFloat = 0
    var right: CGFloat = 0
}

struct QuadruplePaneArrangement {
    /// number of windows in pane
    private let paneCount: [FourPane: UInt]

    /// height of windows in pane
    private let paneWindowHeight: [FourPane: CGFloat]

    /// width of windows in pane
    private let paneWindowWidth: [FourPane: CGFloat]

    // how panes relate to columns
    private let panePosition: [FourPane: FourColumn]

    /// how columns relate to panes
    private let columnDesignation: [FourColumn: FourPane]

    /**
     - Parameters:
        - mainPane: which Column is the main Pane
        - counts: how many windows each pane holds: main, secondary, tertiary, quaternary
        - screenSize: total size of the screen
        - mainPaneRatio: ratio of the screen taken by main pane
     */
    init(mainPane: FourColumn, counts: [UInt], screenSize: CGSize, mainPaneRatio: CGFloat) {
        // forward and reverse mapping of columns to their designations
        self.panePosition = {
            switch mainPane {
            case .left: return [.main: .left, .secondary: .middleLeft, .tertiary: .middleRight, .quaternary: .right]
            case .middleLeft: return [.main: .middleLeft, .secondary: .middleRight, .tertiary: .left, .quaternary: .right]
            case .middleRight: return [.main: .middleRight, .secondary: .middleLeft, .tertiary: .right, .quaternary: .left]
            case .right: return [.main: .right, .secondary: .middleRight, .tertiary: .middleLeft, .quaternary: .left]
            }
        }()
        // swap keys and values for reverse lookup
        self.columnDesignation = Dictionary(uniqueKeysWithValues: panePosition.map({ ($1, $0) }))

        let mainPaneCount = counts[0]
        let secondaryPaneCount = counts[1]
        let tertiaryPaneCount = counts[2]
        let quaternaryPaneCount = counts[3]
        self.paneCount = [.main: mainPaneCount, .secondary: secondaryPaneCount, .tertiary: tertiaryPaneCount, .quaternary: quaternaryPaneCount]

        // calculate heights
        let screenHeight = screenSize.height
        self.paneWindowHeight = [
            .main: round(screenHeight / CGFloat(mainPaneCount)),
            .secondary: secondaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(secondaryPaneCount)),
            .tertiary: tertiaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(tertiaryPaneCount)),
            .quaternary: quaternaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(quaternaryPaneCount))
        ]

        // calculate widths
        let screenWidth = screenSize.width
        let mainWindowWidth = round(screenWidth / 4)
        let nonMainWindowWidth = round(screenWidth / 4)
        // The last side column takes the rounding remainder, so the columns fill the screen exactly and twins mirror to the pixel.
        self.paneWindowWidth = [
            .main: mainWindowWidth,
            .secondary: nonMainWindowWidth,
            .tertiary: nonMainWindowWidth,
            .quaternary: screenWidth - mainWindowWidth - 2 * nonMainWindowWidth
        ]
   }

    func count(_ pane: FourPane) -> UInt {
        return paneCount[pane]!
    }

    func height(_ pane: FourPane) -> CGFloat {
        return paneWindowHeight[pane]!
    }

    func width(_ pane: FourPane) -> CGFloat {
        return paneWindowWidth[pane]!
    }

    func firstIndex(_ pane: FourPane) -> UInt {
        switch pane {
        case .main: return 0
        case .secondary: return count(.main)
        case .tertiary: return count(.main) + count(.secondary)
        case .quaternary: return count(.main) + count(.secondary) + count(.tertiary)
        }
    }

    func pane(ofIndex windowIndex: UInt) -> FourPane {
        if windowIndex >= firstIndex(.quaternary) {
            return .quaternary
        }
        if windowIndex >= firstIndex(.tertiary) {
            return .tertiary
        }
        if windowIndex >= firstIndex(.secondary) {
            return .secondary
        }
        return .main
    }

    /// Given a window index, which Pane does it belong to, and which index within that Pane
    func coordinates(at windowIndex: UInt) -> (FourPane, UInt) {
        let pane = self.pane(ofIndex: windowIndex)
        return (pane, windowIndex - firstIndex(pane))
    }

    /// Get the (height, width) dimensions for a window in the given Pane
    func windowDimensions(inPane pane: FourPane) -> (CGFloat, CGFloat) {
        return (height(pane), width(pane))
    }

    /// Get the Column assignment for the given Pane
    func column(ofPane pane: FourPane) -> FourColumn {
        return panePosition[pane]!
    }

    func pane(ofColumn column: FourColumn) -> FourPane {
        return columnDesignation[column]!
    }

    /// Get the column widths in the order (left, middle, right)
    func widthsLeftToRight() -> FourPaneWidths {
        return FourPaneWidths(
            left: width(pane(ofColumn: .left)),
            middleLeft: width(pane(ofColumn: .middleLeft)),
            middleRight: width(pane(ofColumn: .middleRight)),
            right: width(pane(ofColumn: .right))
        )
    }
}

// not an actual Layout, just a base class for the four actual Layouts below
class FourColumnLayout<Window: WindowType>: PaneCountedLayout<Window> {
    class var mainColumn: FourColumn { fatalError("Must be implemented by subclass") }

    override class var paneCount: Int { return 4 }

    private static var panes: [FourPane] { [.main, .secondary, .tertiary, .quaternary] }

    private func arrangement(windowCount: Int, screenSize: CGSize) -> QuadruplePaneArrangement {
        return QuadruplePaneArrangement(
            mainPane: type(of: self).mainColumn,
            counts: fittedPaneCounts(windowCount: windowCount).counts.map { UInt($0) },
            screenSize: screenSize,
            mainPaneRatio: mainPaneRatio
        )
    }

    private static func offsetX(of column: FourColumn, widths: FourPaneWidths) -> CGFloat {
        switch column {
        case .left: return 0.0
        case .middleLeft: return widths.left
        case .middleRight: return widths.left + widths.middleLeft
        case .right: return widths.left + widths.middleLeft + widths.middleRight
        }
    }

    /// Every column keeps its quarter of the screen, so a side column without windows is a warp target.
    override func emptyPaneFrames(windowCount: Int, on screen: Screen) -> [Int: CGRect] {
        guard windowCount > 0 else {
            return [:]
        }

        let screenFrame = screen.adjustedFrame()
        let paneArrangement = arrangement(windowCount: windowCount, screenSize: screenFrame.size)
        let widths = paneArrangement.widthsLeftToRight()
        var frames: [Int: CGRect] = [:]
        for (index, pane) in Self.panes.enumerated() where pane != .main && paneArrangement.count(pane) == 0 && paneArrangement.width(pane) > 0 {
            frames[index] = CGRect(
                x: screenFrame.origin.x + Self.offsetX(of: paneArrangement.column(ofPane: pane), widths: widths),
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
            let column: FourColumn = paneArrangement.column(ofPane: pane)

            let widths = paneArrangement.widthsLeftToRight()

            let xorigin: CGFloat = screenFrame.origin.x + Self.offsetX(of: column, widths: widths)

            let scaleFactor: CGFloat = screenFrame.width / {
                if pane == .main {
                    return paneArrangement.width(.main)
                }
                return paneArrangement.width(.secondary) + paneArrangement.width(.tertiary) + paneArrangement.width(.quaternary)
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

// implement the two variants
class FourColumnLeftLayout<Window: WindowType>: FourColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "4Column Left" }
    override static var layoutKey: String { return "4column-left" }
    override static var mainColumn: FourColumn { return .middleLeft }
}

class FourColumnRightLayout<Window: WindowType>: FourColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "4Column Right" }
    override static var layoutKey: String { return "4column-right" }
    override static var mainColumn: FourColumn { return .middleRight }
}
