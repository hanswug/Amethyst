//
//  WidescreenTallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class WidescreenTallLayout<Window: WindowType>: PaneCountedLayout<Window> {
    override class var paneCount: Int { return 2 }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        if windows.count == 0 {
            return []
        }

        let counts = fittedPaneCounts(windowCount: windows.count)
        let mainPaneCount = counts[0]
        let secondaryPaneCount = counts[1]

        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = screenFrame.height
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWidth = round(screenFrame.size.width * (hasSecondaryPane ? CGFloat(mainPaneRatio) : 1.0))
        let mainPaneWindowWidth = round(mainPaneWidth / CGFloat(mainPaneCount))
        let secondaryPaneWindowWidth = screenFrame.width - mainPaneWidth

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignmentOperation<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex = frameAssignments.count
            let isMain = windowIndex < mainPaneCount
            let scaleFactor: CGFloat

            if isMain {
                scaleFactor = CGFloat(screenFrame.size.width / mainPaneWindowWidth) / CGFloat(mainPaneCount)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(windowIndex)
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = CGFloat(screenFrame.size.width / secondaryPaneWindowWidth)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWidth
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(windowIndex - mainPaneCount))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

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

extension WidescreenTallLayout: PanedLayout {}

class WidescreenTallLayoutLeft<Window: WindowType>: WidescreenTallLayout<Window> {
    override static var layoutName: String { return "Widescreen Tall Left" }
    override static var layoutKey: String { return "widescreen-tall-left" }
}

/// Widescreen Tall Left's twin, mirrored: the stack on the left, the first main window at the right edge.
class WidescreenTallLayoutRight<Window: WindowType>: WidescreenTallLayout<Window> {
    override static var layoutName: String { return "Widescreen Tall Right" }
    override static var layoutKey: String { return "widescreen-tall-right" }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        return super.frameAssignments(windowSet, on: screen)?.map { $0.mirrored(.horizontal) }
    }
}
