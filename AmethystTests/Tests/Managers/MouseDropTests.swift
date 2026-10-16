//
//  MouseDropTests.swift
//  AmethystTests
//

@testable import Amethyst
import Cocoa
import Nimble
import Quick

private final class DropRecorder: MouseStateKeeperDelegate {
    typealias Window = TestWindow

    var ratios: [CGFloat] = []
    var drops: [(window: TestWindow, modifiers: NSEvent.ModifierFlags)] = []
    var snapBacks = 0

    func recommendMainPaneRatio(_ ratio: CGFloat) {
        ratios.append(ratio)
    }

    func dropDraggedWindow(_ draggedWindow: TestWindow, modifiers: NSEvent.ModifierFlags) {
        drops.append((draggedWindow, modifiers))
    }

    func snapBack(on screen: TestScreen) {
        snapBacks += 1
    }
}

class MouseDropTests: QuickSpec {
    override func spec() {
        func mouseUp(_ modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
            return NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 0
            )!
        }

        describe("which drops warp") {
            it("warps with Shift alone") {
                expect(MouseDrop.isWarp(.shift)).to(beTrue())
                expect(MouseDrop.isWarp([.shift, .capsLock])).to(beTrue())
            }

            it("swaps without Shift or with Shift and another modifier") {
                expect(MouseDrop.isWarp([])).to(beFalse())
                expect(MouseDrop.isWarp(.option)).to(beFalse())
                expect(MouseDrop.isWarp([.shift, .command])).to(beFalse())
                expect(MouseDrop.isWarp([.shift, .control])).to(beFalse())
            }
        }

        describe("where a warp lands") {
            // 3Column Middle: left | main | right, with the right column empty.
            let tiles: [(index: Int, frame: CGRect)] = [
                (index: 0, frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000)),
                (index: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 500)),
                (index: 2, frame: CGRect(x: 0, y: 500, width: 1000, height: 500))
            ]
            let emptyPaneFrames = [2: CGRect(x: 2000, y: 0, width: 1000, height: 1000)]

            it("lands on the window whose tile is under the point") {
                expect(MouseDrop.warpTarget(at: CGPoint(x: 500, y: 700), tiles: tiles, emptyPaneFrames: emptyPaneFrames)).to(equal(.window(2)))
                expect(MouseDrop.warpTarget(at: CGPoint(x: 1500, y: 100), tiles: tiles, emptyPaneFrames: emptyPaneFrames)).to(equal(.window(0)))
            }

            it("lands in an empty pane under the point") {
                expect(MouseDrop.warpTarget(at: CGPoint(x: 2500, y: 500), tiles: tiles, emptyPaneFrames: emptyPaneFrames)).to(equal(.emptyPane(2)))
            }

            it("picks the first of stacked windows") {
                let stacked: [(index: Int, frame: CGRect)] = [
                    (index: 0, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000)),
                    (index: 1, frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000)),
                    (index: 2, frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000))
                ]
                expect(MouseDrop.warpTarget(at: CGPoint(x: 1500, y: 500), tiles: stacked, emptyPaneFrames: [:])).to(equal(.window(1)))
            }

            it("has no target outside every tile and pane") {
                expect(MouseDrop.warpTarget(at: CGPoint(x: 3500, y: 500), tiles: tiles, emptyPaneFrames: emptyPaneFrames)).to(beNil())
            }
        }

        describe("which half of a BSP tile") {
            it("is left or right on a wide tile") {
                let tile = CGRect(x: 0, y: 0, width: 2000, height: 1000)
                expect(MouseDrop.takesFirstHalf(at: CGPoint(x: 900, y: 900), of: tile)).to(beTrue())
                expect(MouseDrop.takesFirstHalf(at: CGPoint(x: 1100, y: 100), of: tile)).to(beFalse())
            }

            it("is top or bottom on a tall tile") {
                let tile = CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                expect(MouseDrop.takesFirstHalf(at: CGPoint(x: 1900, y: 400), of: tile)).to(beTrue())
                expect(MouseDrop.takesFirstHalf(at: CGPoint(x: 1100, y: 600), of: tile)).to(beFalse())
            }
        }

        describe("the mouse state on button up") {
            it("drops a moving window with the modifiers held") {
                let recorder = DropRecorder()
                let keeper = MouseStateKeeper(delegate: recorder)
                let window = TestWindow(element: nil)!

                keeper.state = .moving(window: window)
                keeper.handleMouseEvent(anEvent: mouseUp(.shift))

                expect(recorder.drops.count).to(equal(1))
                expect(recorder.drops.first?.window).to(be(window))
                expect(recorder.drops.first?.modifiers.contains(.shift)).to(beTrue())
            }

            it("keeps the modifiers for a move that arrives after the button came up") {
                let keeper = MouseStateKeeper(delegate: DropRecorder())

                keeper.state = .dragging
                keeper.handleMouseEvent(anEvent: mouseUp(.shift))

                guard case let .doneDragging(_, modifiers) = keeper.state else {
                    fail("expected doneDragging, got \(keeper.state)")
                    return
                }
                expect(modifiers.contains(.shift)).to(beTrue())
            }

            it("follows a resize the layout can take and snaps back one it can't") {
                let recorder = DropRecorder()
                let keeper = MouseStateKeeper(delegate: recorder)

                keeper.state = .resizing(screen: TestScreen(), ratio: 0.6)
                keeper.handleMouseEvent(anEvent: mouseUp())
                expect(recorder.ratios).to(equal([0.6]))
                expect(recorder.snapBacks).to(equal(0))

                keeper.state = .resizing(screen: TestScreen(), ratio: nil)
                keeper.handleMouseEvent(anEvent: mouseUp())
                expect(recorder.ratios).to(equal([0.6]))
                expect(recorder.snapBacks).to(equal(1))
            }
        }

        describe("snap-back setting") {
            it("toggles on and off") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())

                expect(configuration.snapBackWindows()).to(beFalse())
                expect(configuration.toggleSnapBackWindows()).to(beTrue())
                expect(configuration.snapBackWindows()).to(beTrue())
                expect(configuration.toggleSnapBackWindows()).to(beFalse())
            }
        }
    }
}
