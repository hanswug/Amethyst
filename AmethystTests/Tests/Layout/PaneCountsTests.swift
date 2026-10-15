//
//  PaneCountsTests.swift
//  AmethystTests
//
//  Stored pane sizes and warp (handover §5.5).
//

@testable import Amethyst
import Nimble
import Quick

class PaneCountsTests: QuickSpec {
    override func spec() {
        describe("fitting") {
            it("reproduces the balanced split when windows open one at a time") {
                var counts = PaneCounts(paneCount: 3)
                var sizes: [[Int]] = []
                for windowCount in 1...5 {
                    counts = counts.fitted(to: windowCount, maxMain: 1)
                    sizes.append(counts.counts)
                }
                expect(sizes).to(equal([[1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 2, 1], [1, 2, 2]]))
            }

            it("fills main while it has room and the side pane is empty") {
                expect(PaneCounts(paneCount: 2).fitted(to: 1, maxMain: 2).counts).to(equal([1, 0]))
                expect(PaneCounts(paneCount: 2).fitted(to: 2, maxMain: 2).counts).to(equal([2, 0]))
                expect(PaneCounts(paneCount: 2).fitted(to: 3, maxMain: 2).counts).to(equal([2, 1]))
            }

            it("adds to the side once a side pane holds a window, even with room in main") {
                expect(PaneCounts([1, 1]).fitted(to: 3, maxMain: 2).counts).to(equal([1, 2]))
            }

            it("takes windows away from the last side pane first") {
                expect(PaneCounts([1, 3, 1]).fitted(to: 3, maxMain: 1).counts).to(equal([1, 2, 0]))
            }

            it("keeps sizes that already fit") {
                expect(PaneCounts([1, 3, 1]).fitted(to: 5, maxMain: 1).counts).to(equal([1, 3, 1]))
            }

            it("balances four panes the same way") {
                expect(PaneCounts(paneCount: 4).fitted(to: 6, maxMain: 1).counts).to(equal([1, 2, 2, 1]))
            }
        }

        describe("normalizing") {
            it("refills an empty side pane from a later one") {
                expect(PaneCounts([1, 0, 2]).normalized(maxMain: 1).counts).to(equal([1, 1, 1]))
                expect(PaneCounts([1, 0, 0, 3]).normalized(maxMain: 1).counts).to(equal([1, 1, 1, 1]))
            }

            it("pushes main's windows over the maximum to the first side pane") {
                expect(PaneCounts([3, 1, 0]).normalized(maxMain: 2).counts).to(equal([2, 2, 0]))
            }

            it("never leaves main empty") {
                expect(PaneCounts([0, 1, 1]).normalized(maxMain: 1).counts).to(equal([1, 1, 0]))
            }

            it("leaves the last side pane empty when there aren't enough windows") {
                expect(PaneCounts([3, 1, 0]).normalized(maxMain: 3).counts).to(equal([3, 1, 0]))
            }
        }

        describe("warp") {
            it("swaps within a pane") {
                expect(PaneCounts([1, 2, 2]).warp(from: 1, to: .window(2), intoMainAtFront: false)).to(equal(.swap(2)))
            }

            it("joins the neighbour's column, right after the neighbour") {
                // 3Column Left 1/2/2: a right-column window warps west into the middle.
                expect(PaneCounts([1, 2, 2]).warp(from: 4, to: .window(1), intoMainAtFront: false))
                    .to(equal(.move(toIndex: 2, counts: PaneCounts([1, 3, 1]))))
                expect(PaneCounts([1, 2, 2]).warp(from: 3, to: .window(2), intoMainAtFront: false))
                    .to(equal(.move(toIndex: 3, counts: PaneCounts([1, 3, 1]))))
            }

            it("joins a later column after the neighbour") {
                expect(PaneCounts([1, 3, 1]).warp(from: 1, to: .window(4), intoMainAtFront: false))
                    .to(equal(.move(toIndex: 4, counts: PaneCounts([1, 2, 2]))))
            }

            it("joins main at the bottom or the top, by main-arrival-position") {
                // Tall 1/2: warp west from the stack's bottom window.
                expect(PaneCounts([1, 2]).warp(from: 2, to: .window(0), intoMainAtFront: false))
                    .to(equal(.move(toIndex: 1, counts: PaneCounts([2, 1]))))
                expect(PaneCounts([1, 2]).warp(from: 2, to: .window(0), intoMainAtFront: true))
                    .to(equal(.move(toIndex: 0, counts: PaneCounts([2, 1]))))
            }

            it("leaves main after the neighbour") {
                expect(PaneCounts([2, 1]).warp(from: 0, to: .window(2), intoMainAtFront: false))
                    .to(equal(.move(toIndex: 2, counts: PaneCounts([1, 2]))))
            }

            it("swaps instead of emptying a pane") {
                expect(PaneCounts([1, 2]).warp(from: 0, to: .window(1), intoMainAtFront: false)).to(equal(.swap(1)))
                expect(PaneCounts([1, 1, 1]).warp(from: 1, to: .window(2), intoMainAtFront: false)).to(equal(.swap(2)))
                expect(PaneCounts([2, 1]).warp(from: 2, to: .window(1), intoMainAtFront: false)).to(equal(.swap(1)))
            }

            it("moves into an empty column as its only window") {
                // 3Column Middle 1/3/0 (left 1, main 3, right 0): a main window warps east.
                expect(PaneCounts([3, 1, 0]).warp(from: 1, to: .emptyPane(2), intoMainAtFront: false))
                    .to(equal(.move(toIndex: 3, counts: PaneCounts([2, 1, 1]))))
            }

            describe("into main") {
                it("joins main from any column, at the bottom or the top") {
                    // 3Column Left 1/2/2: the right column's last window warps into main.
                    expect(PaneCounts([1, 2, 2]).warpIntoMain(from: 4, intoMainAtFront: false))
                        .to(equal(.move(toIndex: 1, counts: PaneCounts([2, 2, 1]))))
                    expect(PaneCounts([1, 2, 2]).warpIntoMain(from: 4, intoMainAtFront: true))
                        .to(equal(.move(toIndex: 0, counts: PaneCounts([2, 2, 1]))))
                }

                it("swaps with main's top window from a pane's last window") {
                    expect(PaneCounts([2, 1, 1]).warpIntoMain(from: 3, intoMainAtFront: false)).to(equal(.swap(0)))
                }

                it("does nothing from main") {
                    expect(PaneCounts([2, 1, 1]).warpIntoMain(from: 1, intoMainAtFront: false)).to(beNil())
                }
            }

            it("does nothing into an empty column from a pane's last window") {
                expect(PaneCounts([2, 1, 0]).warp(from: 2, to: .emptyPane(2), intoMainAtFront: false)).to(beNil())
            }
        }

        describe("reconciling") {
            func state(_ counts: [Int], _ windowIDs: [String], maxMain: Int = 1) -> PaneState<String> {
                var state = PaneState<String>(counts: PaneCounts(counts))
                _ = state.reconcile(windowIDs: windowIDs, maxMain: maxMain)
                return state
            }

            it("adopts the stored sizes on the first pass without moving windows") {
                var paneState = PaneState<String>(counts: PaneCounts([1, 3, 1]))
                let result = paneState.reconcile(windowIDs: ["a", "b", "c", "d", "e"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 3, 1]))
                expect(result.reorderedIDs).to(beNil())
            }

            it("shrinks only the column a window left") {
                var paneState = state([1, 3, 1], ["a", "b", "c", "d", "e"])
                let result = paneState.reconcile(windowIDs: ["a", "b", "d", "e"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 2, 1]))
                expect(result.reorderedIDs).to(beNil())
            }

            it("refills a side column a window left empty from the later one") {
                var paneState = state([1, 1, 2], ["a", "b", "c", "d"])
                let result = paneState.reconcile(windowIDs: ["a", "c", "d"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 1, 1]))
            }

            it("puts a new window in the shorter side column, ties to the first") {
                var paneState = state([1, 1, 1], ["a", "b", "c"])
                let result = paneState.reconcile(windowIDs: ["a", "b", "c", "d"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 2, 1]))
                expect(result.reorderedIDs).to(equal(["a", "b", "d", "c"]))

                let next = paneState.reconcile(windowIDs: ["a", "b", "d", "c", "e"], maxMain: 1)
                expect(next.counts.counts).to(equal([1, 2, 2]))
                expect(next.reorderedIDs).to(beNil())
            }

            it("fills main with new windows while it has room and the side is empty") {
                var paneState = state([0, 0], ["a"], maxMain: 2)
                expect(paneState.reconcile(windowIDs: ["a", "b"], maxMain: 2).counts.counts).to(equal([2, 0]))
                expect(paneState.reconcile(windowIDs: ["a", "b", "c"], maxMain: 2).counts.counts).to(equal([2, 1]))
            }

            it("lowers main's size, not its maximum, when a main window leaves; new windows then go to the side") {
                var paneState = state([2, 1], ["a", "b", "c"], maxMain: 2)
                expect(paneState.reconcile(windowIDs: ["b", "c"], maxMain: 2).counts.counts).to(equal([1, 1]))
                expect(paneState.reconcile(windowIDs: ["b", "c", "d"], maxMain: 2).counts.counts).to(equal([1, 2]))
            }

            it("lets the first side window slide in when main's last window leaves") {
                var paneState = state([1, 2], ["a", "b", "c"])
                let result = paneState.reconcile(windowIDs: ["b", "c"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 1]))
                expect(result.reorderedIDs).to(beNil())
            }

            it("takes a window arriving at the front into main, pushing main's last window to the first side column") {
                var paneState = state([1, 1, 1], ["a", "b", "c"])
                let result = paneState.reconcile(windowIDs: ["x", "a", "b", "c"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 2, 1]))
                expect(result.reorderedIDs).to(beNil())
            }

            it("puts a window arriving between others in the pane of the window before it") {
                var paneState = state([1, 2, 1], ["a", "b", "c", "d"])
                let result = paneState.reconcile(windowIDs: ["a", "b", "x", "c", "d"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 3, 1]))
                expect(result.reorderedIDs).to(beNil())
            }

            it("pushes main's extra windows out when the maximum drops") {
                var paneState = state([2, 1], ["a", "b", "c"], maxMain: 2)
                expect(paneState.reconcile(windowIDs: ["a", "b", "c"], maxMain: 1).counts.counts).to(equal([1, 2]))
            }

            it("gives a new tab the pane of the tab it replaced") {
                var paneState = state([1, 2, 2], ["a", "b", "c", "d", "e"])
                let result = paneState.reconcile(windowIDs: ["a", "b", "c", "x", "e"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 2, 2]))
                expect(result.reorderedIDs).to(beNil())
            }

            it("brings restored sizes back whatever order the windows arrive in after a relaunch") {
                var paneState = PaneState<String>(counts: PaneCounts([1, 3, 1]), restored: true)
                expect(paneState.reconcile(windowIDs: ["a", "e"], maxMain: 1).counts.counts).to(equal([1, 1, 0]))
                expect(paneState.reconcile(windowIDs: ["a", "c", "e"], maxMain: 1).counts.counts).to(equal([1, 2, 0]))
                let result = paneState.reconcile(windowIDs: ["a", "b", "c", "d", "e"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 3, 1]))
                expect(result.reorderedIDs).to(beNil())

                // Restored; from now on new windows follow the usual rule.
                expect(paneState.reconcile(windowIDs: ["a", "b", "c", "d", "e", "f"], maxMain: 1).counts.counts).to(equal([1, 3, 2]))
            }

            it("keeps the sizes a warp set") {
                var paneState = state([1, 2, 2], ["a", "b", "c", "d", "e"])
                paneState.setCounts(PaneCounts([1, 3, 1]))
                let result = paneState.reconcile(windowIDs: ["a", "b", "c", "d", "e"], maxMain: 1)
                expect(result.counts.counts).to(equal([1, 3, 1]))

                // Closing a middle window afterwards leaves the right column alone.
                expect(paneState.reconcile(windowIDs: ["a", "b", "d", "e"], maxMain: 1).counts.counts).to(equal([1, 2, 1]))
            }
        }
    }
}
