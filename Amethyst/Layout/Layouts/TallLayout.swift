//
//  TallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class TallLayout<Window: WindowType>: PaneCountedLayout<Window>, PanedLayout {
    override static var layoutName: String { return "Tall Left" }
    override static var layoutKey: String { return "tall-left" }

    override class var paneCount: Int { return 2 }

    override var layoutDescription: String { return "" }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let counts = fittedPaneCounts(windowCount: windows.count)
        let mainPaneCount = counts[0]
        let secondaryPaneCount = counts[1]
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = round(screenFrame.size.height / CGFloat(mainPaneCount))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.size.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWindowWidth = round(screenFrame.size.width * (hasSecondaryPane ? CGFloat(mainPaneRatio) : 1.0))
        let secondaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth

        return windows.reduce([]) { acc, window -> [FrameAssignmentOperation<Window>] in
            var assignments = acc
            var windowFrame = CGRect.zero
            let isMain = acc.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.size.width / mainPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(acc.count))
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = screenFrame.size.width / secondaryPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(acc.count - mainPaneCount))
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
