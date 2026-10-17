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
    func reorderWindows(_ windowIDs: [TestWindow.WindowID]) -> Bool {
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

        describe("reordering a screen's windows") {
            it("puts them in the new order in the places they hold; other windows keep theirs") {
                expect(WindowArrival.reordered(["a", "x", "b", "c", "y"], as: ["a", "c", "b"])).to(equal(["a", "x", "c", "b", "y"]))
            }

            it("leaves the list alone when the new order isn't a reordering of windows in it") {
                expect(WindowArrival.reordered(["a", "b", "c"], as: ["a", "z"])).to(equal(["a", "b", "c"]))
                expect(WindowArrival.reordered(["a", "b", "c"], as: ["a", "a"])).to(equal(["a", "b", "c"]))
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

/// A layout and its twin share one state: leaving one hands main count, ratio and pane sizes to the other.
class ScreenManagerTwinStateTests: XCTestCase {
    private struct SavedState: Encodable {
        let layoutsBySpaceUUID: [String: [[String: Data]]]
    }

    private let spaceA = Space(id: 1, type: CGSSpaceTypeUser, uuid: "SPACE-A")
    private let spaceB = Space(id: 2, type: CGSSpaceTypeUser, uuid: "SPACE-B")
    private var previousLayoutKeys: [String] = []

    override func setUp() {
        previousLayoutKeys = UserConfiguration.shared.layoutKeys()
    }

    override func tearDown() {
        UserConfiguration.shared.setLayoutKeys(previousLayoutKeys)
    }

    @MainActor private func screenManager(_ keys: [String]) throws -> ScreenManager<TestDelegate> {
        UserConfiguration.shared.setLayoutKeys(keys)
        let saved = try JSONEncoder().encode(SavedState(layoutsBySpaceUUID: [:]))
        let screenManager = try JSONDecoder().decode(ScreenManager<TestDelegate>.self, from: saved)
        screenManager.updateSpace(to: spaceA)
        return screenManager
    }

    @MainActor func testTheTwinShowsTheSameStateHoweverItIsReached() throws {
        let screenManager = try screenManager(["tall-left", "wide-top", "tall-right"])
        let left = try XCTUnwrap(screenManager.currentLayout as? TallLayout<TestWindow>)
        left.increaseMainPaneCount()
        left.recommendMainPaneRawRatio(rawRatio: 0.6)

        // Through another layout: Tall Left was left first, so Tall Right has its state.
        screenManager.cycleLayoutForward()
        screenManager.cycleLayoutForward()
        let right = try XCTUnwrap(screenManager.currentLayout as? TallRightLayout<TestWindow>)
        XCTAssertEqual(right.mainPaneCount, 2)
        XCTAssertEqual(right.mainPaneRatio, 0.6)

        // And back, directly.
        right.decreaseMainPaneCount()
        screenManager.selectLayout("tall-left")
        XCTAssertTrue(screenManager.currentLayout === left)
        XCTAssertEqual(left.mainPaneCount, 1)
    }

    @MainActor func testLeavesOtherLayoutsAndOtherSpacesAlone() throws {
        let screenManager = try screenManager(["tall-left", "wide-top", "tall-right"])
        let left = try XCTUnwrap(screenManager.currentLayout as? TallLayout<TestWindow>)
        left.increaseMainPaneCount()

        screenManager.selectLayout("wide-top")
        let wide = try XCTUnwrap(screenManager.currentLayout as? WideLayout<TestWindow>)
        XCTAssertEqual(wide.mainPaneCount, 1)

        screenManager.updateSpace(to: spaceB)
        screenManager.selectLayout("tall-right")
        let otherSpaceRight = try XCTUnwrap(screenManager.currentLayout as? TallRightLayout<TestWindow>)
        XCTAssertEqual(otherSpaceRight.mainPaneCount, 1)
    }

    // MARK: flip-twin

    @MainActor func testFlipGoesToTheTwinsEntryWhenItIsListed() throws {
        let screenManager = try screenManager(["tall-left", "wide-top", "tall-right"])
        let left = try XCTUnwrap(screenManager.currentLayout as? TallLayout<TestWindow>)
        left.increaseMainPaneCount()

        screenManager.flipToTwin()

        XCTAssertEqual(screenManager.currentLayout?.layoutKey, "tall-right")
        XCTAssertEqual((screenManager.currentLayout as? TallRightLayout<TestWindow>)?.mainPaneCount, 2)
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["tall-left", "wide-top", "tall-right"])

        screenManager.flipToTwin()
        XCTAssertTrue(screenManager.currentLayout === left)
    }

    @MainActor func testFlipTurnsTheEntryIntoAnUnlistedTwinInPlaceAndBack() throws {
        let screenManager = try screenManager(["tall-left", "wide-top"])
        let left = try XCTUnwrap(screenManager.currentLayout as? TallLayout<TestWindow>)
        left.increaseMainPaneCount()
        left.recommendMainPaneRawRatio(rawRatio: 0.6)

        screenManager.flipToTwin()
        let right = try XCTUnwrap(screenManager.currentLayout as? TallRightLayout<TestWindow>)
        XCTAssertEqual(right.mainPaneCount, 2)
        XCTAssertEqual(right.mainPaneRatio, 0.6)
        // The Layouts menu lists the config as written, with the flipped entry checked.
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["tall-left", "wide-top"])
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.name }, ["tall-left", "wide-top"].map { UserConfiguration.shared.layoutDisplayName(forKey: $0) })
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.isSelected }, [true, false])

        right.decreaseMainPaneCount()
        screenManager.flipToTwin()
        XCTAssertEqual(screenManager.currentLayout?.layoutKey, "tall-left")
        XCTAssertEqual((screenManager.currentLayout as? TallLayout<TestWindow>)?.mainPaneCount, 1)
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["tall-left", "wide-top"])
    }

    @MainActor func testSelectingTheListedLayoutTurnsAFlippedEntryBack() throws {
        let screenManager = try screenManager(["tall-left", "wide-top"])
        screenManager.flipToTwin()
        screenManager.selectLayout("wide-top")

        screenManager.selectLayout("tall-left")

        XCTAssertEqual(screenManager.currentLayout?.layoutKey, "tall-left")
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["tall-left", "wide-top"])
    }

    @MainActor func testAFlippedEntrySurvivesARelaunch() throws {
        let screenManager = try screenManager(["tall-left", "wide-top"])
        (screenManager.currentLayout as? TallLayout<TestWindow>)?.increaseMainPaneCount()
        screenManager.flipToTwin()

        let saved = try JSONEncoder().encode(screenManager)
        let restored = try JSONDecoder().decode(ScreenManager<TestDelegate>.self, from: saved)
        restored.updateSpace(to: spaceA)

        XCTAssertEqual(restored.currentLayout?.layoutKey, "tall-right")
        XCTAssertEqual((restored.currentLayout as? TallRightLayout<TestWindow>)?.mainPaneCount, 2)
        XCTAssertEqual(restored.layoutsInfo.map { $0.key }, ["tall-left", "wide-top"])
    }

    @MainActor func testFlipDoesNothingWithoutATwin() throws {
        for key in ["3column-middle", "bsp", "fullscreen", "floating"] {
            let screenManager = try screenManager([key, "wide-top"])
            screenManager.flipToTwin()
            XCTAssertEqual(screenManager.currentLayout?.layoutKey, key)
            XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, [key, "wide-top"])
        }
    }

    @MainActor func testFlipFromAToggledFullscreenFlipsTheEntryBehindIt() throws {
        let screenManager = try screenManager(["wide-top", "tall-left"])
        screenManager.toggleFullscreen()

        screenManager.flipToTwin()

        XCTAssertEqual(screenManager.currentLayout?.layoutKey, "wide-bottom")
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["wide-top", "tall-left"])
    }
}

/// `toggle-fullscreen` and going back by selecting the current layout again, per Space.
class ScreenManagerFullscreenToggleTests: XCTestCase {
    private struct SavedState: Encodable {
        let layoutsBySpaceUUID: [String: [[String: Data]]]
    }

    private let spaceA = Space(id: 1, type: CGSSpaceTypeUser, uuid: "SPACE-A")
    private let spaceB = Space(id: 2, type: CGSSpaceTypeUser, uuid: "SPACE-B")
    private var previousLayoutKeys: [String] = []

    override func setUp() {
        previousLayoutKeys = UserConfiguration.shared.layoutKeys()
    }

    override func tearDown() {
        UserConfiguration.shared.setLayoutKeys(previousLayoutKeys)
    }

    /// A screen manager on `spaceA` whose layouts are `keys`, built the way a relaunch builds one.
    @MainActor private func screenManager(_ keys: [String]) throws -> ScreenManager<TestDelegate> {
        UserConfiguration.shared.setLayoutKeys(keys)
        let saved = try JSONEncoder().encode(SavedState(layoutsBySpaceUUID: [:]))
        let screenManager = try JSONDecoder().decode(ScreenManager<TestDelegate>.self, from: saved)
        screenManager.updateSpace(to: spaceA)
        return screenManager
    }

    @MainActor func testTogglesToFullscreenInPlaceAndBackToTheSameLayout() throws {
        let screenManager = try screenManager(["3column-left", "tall-left"])
        screenManager.cycleLayoutForward()
        let tall = try XCTUnwrap(screenManager.currentLayout as? TallLayout<TestWindow>)
        tall.increaseMainPaneCount()

        screenManager.toggleFullscreen()
        XCTAssertTrue(screenManager.currentLayout is FullscreenLayout<TestWindow>)
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["3column-left", "fullscreen"])

        screenManager.toggleFullscreen()
        XCTAssertTrue(screenManager.currentLayout === tall)
        XCTAssertEqual(tall.mainPaneCount, 2)
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["3column-left", "tall-left"])
    }

    @MainActor func testCyclingEndsTheToggleAndMovesOnFromTheSlot() throws {
        let screenManager = try screenManager(["tall-left", "3column-middle", "wide-top"])

        screenManager.toggleFullscreen()
        screenManager.cycleLayoutForward()

        XCTAssertEqual(screenManager.currentLayout?.layoutKey, "3column-middle")
        XCTAssertEqual(screenManager.layoutsInfo.map { $0.key }, ["tall-left", "3column-middle", "wide-top"])
    }

    @MainActor func testSavesTheSlotsOwnLayoutWhileToggled() throws {
        let screenManager = try screenManager(["tall-left", "wide-top"])
        screenManager.toggleFullscreen()

        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(screenManager)) as? [String: Any]
        let selection = saved?["currentLayoutKeyBySpaceUUID"] as? [String: String]

        XCTAssertEqual(selection?[spaceA.uuid], "tall-left")
    }

    @MainActor func testGoesBackFromAFullscreenSelectedTheUsualWayPerSpace() throws {
        let screenManager = try screenManager(["tall-left", "wide-top", "fullscreen"])

        screenManager.selectLayout("wide-top")
        screenManager.selectLayout("fullscreen")
        screenManager.updateSpace(to: spaceB)
        screenManager.selectLayout("fullscreen")
        screenManager.updateSpace(to: spaceA)

        screenManager.toggleFullscreen()
        XCTAssertEqual(screenManager.currentLayout?.layoutKey, "wide-top")

        screenManager.updateSpace(to: spaceB)
        screenManager.selectLayout("fullscreen")
        XCTAssertEqual(screenManager.currentLayout?.layoutKey, "tall-left")
    }
}
