//
//  ScreenManagerTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 2/11/20.
//  Copyright © 2020 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica
import XCTest

private final class TestDelegate: ScreenManagerDelegate {
    typealias Window = TestWindow

    func applyWindowLimit(forScreenManager screenManager: ScreenManager<TestDelegate>, minimizingIn range: (Int) -> Range<Int>) {
        fatalError()
    }
    func floatOverflowWindows(forScreenManager screenManager: ScreenManager<TestDelegate>, limit: Int) {
        fatalError()
    }
    func activeWindowSet(forScreenManager screenManager: ScreenManager<TestDelegate>, on screen: TestScreen) -> WindowSet<TestWindow> {
        fatalError()
    }
    func onReflowInitiation() {
        fatalError()
    }
    func onReflowCompletion() {
        fatalError()
    }
    func windowsLeftView(_ windowIDs: [TestWindow.WindowID]) {
        fatalError()
    }
    func windowsCameBack(_ windowIDs: [TestWindow.WindowID]) -> Bool {
        fatalError()
    }
}

class ScreenManagerTests: QuickSpec {
    override func spec() {
        describe("coding") {
            describe("the selected layout per Space") {
                let layoutsBySpaceUUID: [String: [Layout<TestWindow>]] = [
                    "space-a": [FullscreenLayout<TestWindow>(), ThreeColumnMiddleLayout<TestWindow>(), TallLayout<TestWindow>()],
                    "space-b": [FullscreenLayout<TestWindow>(), ThreeColumnMiddleLayout<TestWindow>(), TallLayout<TestWindow>()]
                ]

                it("is saved by layout key and restored as the same index") {
                    let keys = ScreenManager<TestDelegate>.layoutKeys(byIndex: ["space-a": 1, "space-b": 2], layoutsBySpaceUUID: layoutsBySpaceUUID)
                    expect(keys).to(equal(["space-a": ThreeColumnMiddleLayout<TestWindow>.layoutKey, "space-b": TallLayout<TestWindow>.layoutKey]))

                    let indices = ScreenManager<TestDelegate>.layoutIndices(byKey: keys, layoutsBySpaceUUID: layoutsBySpaceUUID)
                    expect(indices).to(equal(["space-a": 1, "space-b": 2]))
                }

                it("follows the layout when layouts: is reordered") {
                    let reordered: [String: [Layout<TestWindow>]] = ["space-a": [TallLayout<TestWindow>(), FullscreenLayout<TestWindow>(), ThreeColumnMiddleLayout<TestWindow>()]]
                    let indices = ScreenManager<TestDelegate>.layoutIndices(byKey: ["space-a": ThreeColumnMiddleLayout<TestWindow>.layoutKey], layoutsBySpaceUUID: reordered)
                    expect(indices).to(equal(["space-a": 2]))
                }

                it("drops a layout no longer listed, and unknown Spaces or indices") {
                    let indices = ScreenManager<TestDelegate>.layoutIndices(
                        byKey: ["space-a": "bsp", "space-c": TallLayout<TestWindow>.layoutKey],
                        layoutsBySpaceUUID: layoutsBySpaceUUID
                    )
                    expect(indices).to(beEmpty())

                    let keys = ScreenManager<TestDelegate>.layoutKeys(byIndex: ["space-a": 7, "space-c": 0], layoutsBySpaceUUID: layoutsBySpaceUUID)
                    expect(keys).to(beEmpty())
                }
            }

            it("decodes layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys(LayoutType<TestWindow>.standardLayoutClasses().map { $0.layoutKey })

                let layouts = LayoutType<TestWindow>.standardLayoutClasses().map { $0.init() }
                let encoder = JSONEncoder()
                let encodedLayouts = layouts.map { ["key": $0.layoutKey.data(using: .utf8)!, "data": try! encoder.encode($0)] }
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect(decodedLayouts.count).to(equal(layouts.count))
                expect(decodedLayouts.count).to(equal(encodedLayouts.count))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(layouts.map { $0.layoutKey }))
            }

            it("replaces incorrectly encoded layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([FullscreenLayout<TestWindow>.layoutKey, TallLayout<TestWindow>.layoutKey])

                let encoder = JSONEncoder()
                let encodedLayouts = [
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                    ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(["incorrect": "encoding"])]
                ]
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect {
                    try JSONDecoder().decode(TallLayout<TestWindow>.self, from: encodedLayouts[1]["data"]!)
                }.to(throwError())

                expect(decodedLayouts.count).to(equal(2))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
            }

            it("replaces incorrectly keyed layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([FullscreenLayout<TestWindow>.layoutKey, TallLayout<TestWindow>.layoutKey])

                let encoder = JSONEncoder()
                let encodedLayouts = [
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(TallLayout<TestWindow>())]
                ]
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect(decodedLayouts.count).to(equal(2))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
            }

            context("layout list changes") {
                it("maintains encoded layouts on insertions") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        FullscreenLayout<TestWindow>.layoutKey,
                        WideLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains encoded layouts on appends") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        FullscreenLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey,
                        WideLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts[1] as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains encoded layouts on prepends") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        WideLayout<TestWindow>.layoutKey,
                        FullscreenLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains existing layouts on deletes") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        WideLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let wideLayout = WideLayout<TestWindow>()
                    let tallLayout = TallLayout<TestWindow>()
                    wideLayout.increaseMainPaneCount()
                    tallLayout.increaseMainPaneCount()

                    expect(wideLayout.mainPaneCount).to(equal(2))
                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": WideLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(wideLayout)],
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(2))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.first as? WideLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }
            }
        }
        describe("windows leaving and coming back into view") {
            // Main count 3: left 1, main 3, right 1 in list order main | left | right.
            let previous = ["m1", "m2", "m3", "left", "right"]

            it("shrinks main when a main window leaves, whatever the reason") {
                let change = VisibleWindowChange(previous: previous, previousMainCount: 3, current: ["m1", "m3", "left", "right"])
                expect(change.left).to(equal(["m2"]))
                expect(change.mainShrink).to(equal(1))
            }

            it("leaves main alone when a side window leaves") {
                let change = VisibleWindowChange(previous: previous, previousMainCount: 3, current: ["m1", "m2", "m3", "left"])
                expect(change.mainShrink).to(equal(0))
            }

            it("shrinks by every main window that left at once (an app hidden)") {
                let change = VisibleWindowChange(previous: previous, previousMainCount: 3, current: ["m3", "left", "right"])
                expect(change.mainShrink).to(equal(2))
            }

            it("treats a tab switch as one window in another's place") {
                let change = VisibleWindowChange(previous: previous, previousMainCount: 3, current: ["m1", "tab", "m3", "left", "right"])
                expect(change.left).to(beEmpty())
                expect(change.appeared).to(beEmpty())
                expect(change.mainShrink).to(equal(0))
            }

            it("leaves main alone when a window closes and another opens in the same pass") {
                let change = VisibleWindowChange(previous: previous, previousMainCount: 3, current: ["m1", "m3", "left", "right", "new"])
                expect(change.mainShrink).to(equal(0))
                expect(change.appeared).to(equal(["new"]))
            }

            it("reports windows that appeared") {
                let change = VisibleWindowChange(previous: ["m1", "left"], previousMainCount: 1, current: ["m1", "back", "left"])
                expect(change.appeared).to(equal(["back"]))
                expect(change.mainShrink).to(equal(0))
            }
        }

        describe("windows arriving again") {
            it("go last, in their order") {
                expect(WindowArrival.order(["a", "b", "c", "d"], returning: ["c", "a"], atFront: false)).to(equal(["b", "d", "a", "c"]))
            }

            it("go first, in their order") {
                expect(WindowArrival.order(["a", "b", "c", "d"], returning: ["d", "b"], atFront: true)).to(equal(["b", "d", "a", "c"]))
            }
        }

    }
}

/// A relaunch decodes the saved state, then the first Space update picks the layout. `@MainActor` because a screen manager
/// owns the layout HUD's window controller (Quick's specs run off the main thread).
class ScreenManagerRestoreTests: XCTestCase {
    private struct SavedState: Encodable {
        let layoutsBySpaceUUID: [String: [[String: Data]]]
        let currentLayoutKeyBySpaceUUID: [String: String]?
    }

    @MainActor func testARelaunchComesBackOnTheSelectedLayout() throws {
        let configuration = UserConfiguration.shared
        let previousLayoutKeys = configuration.layoutKeys()
        let layouts: [Layout<TestWindow>] = [FullscreenLayout(), ThreeColumnMiddleLayout(), TallLayout()]
        configuration.setLayoutKeys(layouts.map { $0.layoutKey })
        defer { configuration.setLayoutKeys(previousLayoutKeys) }

        // The main Space's UUID is often empty.
        let space = Space(id: 1, type: CGSSpaceTypeUser, uuid: "")
        let encoder = JSONEncoder()
        let encodedLayouts = try layouts.map { ["key": $0.layoutKey.data(using: .utf8)!, "data": try LayoutType.encoded(layout: $0)] }

        func relaunched(withSelection selection: [String: String]?) throws -> ScreenManager<TestDelegate> {
            let saved = try encoder.encode(SavedState(layoutsBySpaceUUID: [space.uuid: encodedLayouts], currentLayoutKeyBySpaceUUID: selection))
            let screenManager = try JSONDecoder().decode(ScreenManager<TestDelegate>.self, from: saved)
            screenManager.updateSpace(to: space)
            return screenManager
        }

        let restored = try relaunched(withSelection: [space.uuid: ThreeColumnMiddleLayout<TestWindow>.layoutKey])
        XCTAssertEqual(restored.currentLayout?.layoutKey, ThreeColumnMiddleLayout<TestWindow>.layoutKey)

        // Saved before the selection was saved: the first layout, as before.
        let older = try relaunched(withSelection: nil)
        XCTAssertEqual(older.currentLayout?.layoutKey, FullscreenLayout<TestWindow>.layoutKey)
    }
}
