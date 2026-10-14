//
//  ReflowTests.swift
//  AmethystTests
//

@testable import Amethyst
import CoreGraphics
import Nimble
import Quick

class ReflowTests: QuickSpec {
    override func spec() {
        describe("a window already in place") {
            let target = CGRect(x: 100, y: 50, width: 800, height: 600)

            it("is left alone within a point") {
                expect(FrameAssignment<TestWindow>.isInPlace(target, target)).to(beTrue())
                expect(FrameAssignment<TestWindow>.isInPlace(target.offsetBy(dx: 1, dy: -1), target)).to(beTrue())
                expect(FrameAssignment<TestWindow>.isInPlace(CGRect(x: 100.5, y: 50, width: 799, height: 601), target)).to(beTrue())
            }

            it("is moved or resized when it's further off") {
                expect(FrameAssignment<TestWindow>.isInPlace(target.offsetBy(dx: 2, dy: 0), target)).to(beFalse())
                expect(FrameAssignment<TestWindow>.isInPlace(CGRect(x: 100, y: 50, width: 800, height: 598), target)).to(beFalse())
            }
        }

        describe("the main pane ratio") {
            it("keeps both panes on screen") {
                expect(TallLayout<TestWindow>.clampedMainPaneRatio(0)).to(equal(0.05))
                expect(TallLayout<TestWindow>.clampedMainPaneRatio(1)).to(equal(0.95))
                expect(TallLayout<TestWindow>.clampedMainPaneRatio(-3)).to(equal(0.05))
                expect(TallLayout<TestWindow>.clampedMainPaneRatio(0.6)).to(equal(0.6))
                expect(TallLayout<TestWindow>.clampedMainPaneRatio(.nan)).to(equal(0.5))
            }

            it("never lets shrink-main or a mouse resize reach zero") {
                let layout = TallLayout<TestWindow>()
                layout.recommendMainPaneRatio(0)
                expect(layout.mainPaneRatio).to(equal(0.05))
                layout.recommendMainPaneRatio(1.4)
                expect(layout.mainPaneRatio).to(equal(0.95))
            }

            it("gives the secondary pane a width in Tall at the largest ratio") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]
                defer { TestScreen.availableScreens = [] }

                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!]
                let windowSet = WindowSet<TestWindow>(
                    windows: windows.map { LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false) },
                    isWindowWithIDActive: { _ in true },
                    isWindowWithIDFloating: { _ in false },
                    windowForID: { id in windows.first { $0.id() == id } }
                )
                let layout = TallLayout<TestWindow>()
                layout.recommendMainPaneRatio(1)

                let frames = layout.frameAssignments(windowSet, on: screen)!.map { $0.frameAssignment.frame }
                expect(frames[1].width).to(beGreaterThan(0))
                expect(frames[0].width).to(equal(1900))
            }
        }
    }
}
