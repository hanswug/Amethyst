//
//  TallLayoutTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 9/21/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class TallLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        describe("layout") {
            it("separates into a main pane and a secondary pane") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TallLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000))
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 1000, height: 500)
                ])
            }

            it("handles non-origin screen") {
                let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TallLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 100, y: 100, width: 1000, height: 1000)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 1100, y: 100, width: 1000, height: 500),
                    CGRect(x: 1100, y: 600, width: 1000, height: 500)
                ])
            }

            it("increases and decreases windows in the main pane") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TallLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 333),
                    CGRect(x: 1000, y: 333, width: 1000, height: 333),
                    CGRect(x: 1000, y: 666, width: 1000, height: 333)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(2))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<2])
                secondaryAssignments = frameAssignments.forWindows(windows[2...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 500),
                    CGRect(x: 0, y: 500, width: 1000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 1000, height: 500)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(3))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<3])
                secondaryAssignments = frameAssignments.forWindows(windows[3...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 333),
                    CGRect(x: 0, y: 333, width: 1000, height: 333),
                    CGRect(x: 0, y: 666, width: 1000, height: 333)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])
            }

            it("changes distribution based on pane ratio") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TallLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 1000, height: 500)
                ])

                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.75))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1500, y: 0, width: 500, height: 500),
                    CGRect(x: 1500, y: 500, width: 500, height: 500)
                ])

                layout.recommendMainPaneRatio(0.25)
                expect(layout.mainPaneRatio).to(equal(0.25))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1500, height: 500),
                    CGRect(x: 500, y: 500, width: 1500, height: 500)
                ])
            }
        }

        describe("coding") {
            it("encodes and decodes") {
                let layout = TallLayout<TestWindow>()
                layout.increaseMainPaneCount()
                layout.recommendMainPaneRatio(0.45)

                expect(layout.mainPaneCount).to(equal(2))
                expect(layout.mainPaneRatio).to(equal(0.45))

                let encodedLayout = try! JSONEncoder().encode(layout)
                let decodedLayout = try! JSONDecoder().decode(TallLayout<TestWindow>.self, from: encodedLayout)

                expect(decodedLayout.mainPaneCount).to(equal(2))
                expect(decodedLayout.mainPaneRatio).to(equal(0.45))
            }
        }

        describe("setting the main pane count") {
            it("steps up and down to the count, never below 1") {
                let layout = TallLayout<TestWindow>()

                layout.setMainPaneCount(3)
                expect(layout.mainPaneCount).to(equal(3))

                layout.setMainPaneCount(2)
                expect(layout.mainPaneCount).to(equal(2))

                layout.setMainPaneCount(0)
                expect(layout.mainPaneCount).to(equal(1))
            }

            it("leaves a fixed count alone") {
                let layout = TwoPaneLayout<TestWindow>()

                layout.setMainPaneCount(3)
                expect(layout.mainPaneCount).to(equal(1))
            }
        }

        describe("stored pane sizes") {
            func windowSet(_ windows: [TestWindow]) -> WindowSet<TestWindow> {
                return WindowSet<TestWindow>(
                    windows: windows.map { LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false) },
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
            }

            it("raising the maximum moves nothing") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]
                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layout = TallLayout<TestWindow>()

                _ = layout.reconcile(windowIDs: windows.map { $0.id() })
                layout.increaseMainPaneCount()
                _ = layout.reconcile(windowIDs: windows.map { $0.id() })

                expect(layout.paneCounts.counts).to(equal([1, 2]))
                expect(layout.mainPaneCountDescription).to(equal("1 of 2"))
                layout.frameAssignments(windowSet(windows), on: screen)!.forWindows(windows[..<1]).verify(frames: [
                    CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000))
                ])
            }

            it("grows main by warp from the stack and shrinks it back") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]
                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layout = TallLayout<TestWindow>()
                _ = layout.reconcile(windowIDs: windows.map { $0.id() })

                // Warp west from the bottom of the stack: it lands at the bottom of main.
                let plan = layout.warpPlan(from: 2, to: .window(0), windowCount: 3, intoMainAtFront: false)
                expect(plan).to(equal(.move(toIndex: 1, counts: PaneCounts([2, 1]))))
                layout.applyWarp(PaneCounts([2, 1]))
                expect(layout.mainPaneCount).to(equal(2))

                let warped = [windows[0], windows[2], windows[1]]
                let assignments = layout.frameAssignments(windowSet(warped), on: screen)!
                assignments.forWindows(warped[..<2]).verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 500),
                    CGRect(x: 0, y: 500, width: 1000, height: 500)
                ])
                assignments.forWindows(warped[2...]).verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])

                // Warp east from main's bottom window: it joins the stack after its neighbour.
                expect(layout.warpPlan(from: 1, to: .window(2), windowCount: 3, intoMainAtFront: false))
                    .to(equal(.move(toIndex: 2, counts: PaneCounts([1, 2]))))
            }

            it("decodes a layout saved before warp and keeps the sizes it saves") {
                let saved = Data("{\"mainPaneCount\": 2, \"mainPaneRatio\": 0.5}".utf8)
                let decoded = try! JSONDecoder().decode(TallLayout<TestWindow>.self, from: saved)
                expect(decoded.mainPaneCount).to(equal(2))
                expect(decoded.paneCounts.counts).to(equal([0, 0]))

                decoded.applyWarp(PaneCounts([1, 3]))
                let roundTrip = try! JSONDecoder().decode(TallLayout<TestWindow>.self, from: try! JSONEncoder().encode(decoded))
                expect(roundTrip.paneCounts.counts).to(equal([1, 3]))
            }
        }
    }
}
