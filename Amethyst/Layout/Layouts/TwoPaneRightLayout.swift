//
//  TwoPaneRightLayout.swift
//  Amethyst
//
//  Created by Anja on 16.06.23.
//  Copyright © 2023 Ian Ynda-Hummel. All rights reserved.
//

import Silica

/// Two Pane A's twin: main second along the screen's long side (on the right, or at the bottom on a portrait screen).
/// Everything else is A's, including every other window waiting behind the secondary pane.
class TwoPaneRightLayout<Window: WindowType>: TwoPaneLayout<Window> {
    override static var layoutName: String { return "Two Pane B" }
    override static var layoutKey: String { return "two-pane-b" }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let screenFrame = screen.adjustedFrame()
        let isHorizontal = (screenFrame.size.width / screenFrame.size.height) >= 1
        return super.frameAssignments(windowSet, on: screen)?.map { $0.mirrored(isHorizontal ? .horizontal : .vertical) }
    }
}
