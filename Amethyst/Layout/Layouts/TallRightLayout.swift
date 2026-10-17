//
//  TallRightLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

/// Tall Left's twin, mirrored: main on the right, both columns filled top to bottom.
class TallRightLayout<Window: WindowType>: TallLayout<Window> {
    override static var layoutName: String { return "Tall Right" }
    override static var layoutKey: String { return "tall-right" }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        return super.frameAssignments(windowSet, on: screen)?.map { $0.mirrored(.horizontal) }
    }
}
