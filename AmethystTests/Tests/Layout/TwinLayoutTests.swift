//
//  TwinLayoutTests.swift
//  AmethystTests
//
//  The twins added for flip (Wide Bottom, Column Right, Row Bottom) and the layout keys.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class TwinLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        func frames(_ layout: Layout<TestWindow>, windowCount: Int, on screen: TestScreen) -> [CGRect] {
            let windows = (0..<windowCount).map { _ in TestWindow(element: nil)! }
            let windowSet = WindowSet<TestWindow>(
                windows: windows.map { LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false) },
                isWindowWithIDActive: { _ in return true },
                isWindowWithIDFloating: { _ in return false },
                windowForID: { id in return windows.first { $0.id() == id } }
            )
            let assignments = layout.frameAssignments(windowSet, on: screen)!
            return windows.map { window in assignments.first { $0.frameAssignment.window.id == window.id() }!.frameAssignment.frame }
        }

        func mirrored(_ frame: CGRect, _ axis: MirrorAxis, in screenFrame: CGRect) -> CGRect {
            var mirrored = frame
            switch axis {
            case .horizontal:
                mirrored.origin.x = screenFrame.minX + screenFrame.maxX - frame.maxX
            case .vertical:
                mirrored.origin.y = screenFrame.minY + screenFrame.maxY - frame.maxY
            }
            return mirrored
        }

        // The original and its twin, with the same main pane count.
        let pairs: [(name: String, axis: MirrorAxis, make: (Int) -> (Layout<TestWindow>, Layout<TestWindow>))] = [
            ("Wide Bottom", .vertical, { mainCount in
                let original = WideLayout<TestWindow>(), twin = WideBottomLayout<TestWindow>()
                (1..<mainCount).forEach { _ in original.increaseMainPaneCount(); twin.increaseMainPaneCount() }
                return (original, twin)
            }),
            ("Column Right", .horizontal, { mainCount in
                let original = ColumnLayout<TestWindow>(), twin = ColumnRightLayout<TestWindow>()
                (1..<mainCount).forEach { _ in original.increaseMainPaneCount(); twin.increaseMainPaneCount() }
                return (original, twin)
            }),
            ("Row Bottom", .vertical, { mainCount in
                let original = RowLayout<TestWindow>(), twin = RowBottomLayout<TestWindow>()
                (1..<mainCount).forEach { _ in original.increaseMainPaneCount(); twin.increaseMainPaneCount() }
                return (original, twin)
            })
        ]

        describe("twins") {
            for pair in pairs {
                it("\(pair.name) mirrors its original") {
                    let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
                    TestScreen.availableScreens = [screen]

                    for mainCount in [1, 2] {
                        for windowCount in [1, 2, 4] {
                            let (original, twin) = pair.make(mainCount)
                            let expected = frames(original, windowCount: windowCount, on: screen).map {
                                mirrored($0, pair.axis, in: screen.adjustedFrame())
                            }

                            expect(frames(twin, windowCount: windowCount, on: screen)).to(equal(expected))
                        }
                    }
                }
            }

            it("mirrors Two Pane A along the screen's long side for Two Pane B") {
                let landscape = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
                let portrait = TestScreen(frame: CGRect(x: 100, y: 100, width: 1000, height: 2000))

                for (screen, axis) in [(landscape, MirrorAxis.horizontal), (portrait, MirrorAxis.vertical)] {
                    TestScreen.availableScreens = [screen]
                    for windowCount in [1, 2, 4] {
                        let expected = frames(TwoPaneLayout<TestWindow>(), windowCount: windowCount, on: screen).map {
                            mirrored($0, axis, in: screen.adjustedFrame())
                        }

                        expect(frames(TwoPaneRightLayout<TestWindow>(), windowCount: windowCount, on: screen)).to(equal(expected))
                    }
                }
            }

            it("keeps every other window waiting behind Two Pane B's secondary pane, main second") {
                let landscape = TestScreen(frame: CGRect(x: 0, y: 0, width: 2000, height: 1000))
                TestScreen.availableScreens = [landscape]
                let landscapeFrames = frames(TwoPaneRightLayout<TestWindow>(), windowCount: 4, on: landscape)

                expect(landscapeFrames[0]).to(equal(CGRect(x: 1000, y: 0, width: 1000, height: 1000)))
                expect(Set(landscapeFrames[1...].map { NSStringFromRect($0) })).to(equal([NSStringFromRect(CGRect(x: 0, y: 0, width: 1000, height: 1000))]))

                let portrait = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 2000))
                TestScreen.availableScreens = [portrait]
                let portraitFrames = frames(TwoPaneRightLayout<TestWindow>(), windowCount: 4, on: portrait)

                expect(portraitFrames[0]).to(equal(CGRect(x: 0, y: 1000, width: 1000, height: 1000)))
                expect(Set(portraitFrames[1...].map { NSStringFromRect($0) })).to(equal([NSStringFromRect(CGRect(x: 0, y: 0, width: 1000, height: 1000))]))
            }

            it("puts Wide Bottom's main pane at the bottom") {
                let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                expect(frames(WideBottomLayout<TestWindow>(), windowCount: 3, on: screen)).to(equal([
                    CGRect(x: 100, y: 600, width: 2000, height: 500),
                    CGRect(x: 100, y: 100, width: 1000, height: 500),
                    CGRect(x: 1100, y: 100, width: 1000, height: 500)
                ]))
            }

            it("puts Column Right's first window on the far right") {
                let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                expect(frames(ColumnRightLayout<TestWindow>(), windowCount: 3, on: screen).map { $0.minX }).to(equal([1000, 500, 0]))
            }

            it("puts Row Bottom's first window at the bottom") {
                let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                expect(frames(RowBottomLayout<TestWindow>(), windowCount: 3, on: screen).map { $0.minY }).to(equal([500, 250, 0]))
            }
        }

        describe("keys") {
            it("names every layout by where main is") {
                let keys = LayoutType<TestWindow>.standardLayouts.map { $0.key }

                expect(keys).to(equal([
                    "tall-left", "tall-right", "wide-top", "wide-bottom", "two-pane-a", "two-pane-b",
                    "3column-left", "3column-middle", "3column-right", "4column-left", "4column-right",
                    "fullscreen", "column-left", "column-right", "row-top", "row-bottom", "floating",
                    "widescreen-tall-left", "widescreen-tall-right", "bsp"
                ]))
            }

            it("builds each layout from its key, with a matching class key") {
                for type in LayoutType<TestWindow>.standardLayouts {
                    expect(LayoutType<TestWindow>.layoutForKey(type.key)?.layoutKey).to(equal(type.key))
                }
            }

            it("has display names that say where main is") {
                let names = ["tall-left", "wide-bottom", "two-pane-b", "3column-middle", "widescreen-tall-left", "column-right", "row-top"]
                    .map { LayoutType<TestWindow>.layoutNameForKey($0) }

                expect(names).to(equal(["Tall Left", "Wide Bottom", "Two Pane B", "3Column Middle", "Widescreen Tall Left", "Column Right", "Row Top"]))
            }

            it("knows no layout outside the built-in ones") {
                expect(LayoutType<TestWindow>.from(key: "my-layout")).to(beNil())
                expect(LayoutType<TestWindow>.layoutForKey("my-layout")).to(beNil())
                expect(LayoutType<TestWindow>.layoutNameForKey("my-layout")).to(beNil())
            }

            it("no longer knows the old keys") {
                for oldKey in ["tall", "wide", "two-pane", "two-pane-right", "middle-wide", "widescreen-tall", "column", "row"] {
                    expect(LayoutType<TestWindow>.layoutForKey(oldKey)).to(beNil())
                }
            }
        }
    }
}
