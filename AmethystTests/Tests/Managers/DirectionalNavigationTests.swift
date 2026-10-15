//
//  DirectionalNavigationTests.swift
//  AmethystTests
//

@testable import Amethyst
import CoreGraphics
import Nimble
import Quick

class DirectionalNavigationTests: QuickSpec {
    override func spec() {
        func neighbor(of focused: String, _ direction: Direction, in frames: [String: CGRect], frontToBack: [String] = [], mru: [String] = []) -> String? {
            var others = frames
            let start = others.removeValue(forKey: focused)!
            return DirectionalNavigation.neighbor(of: start, direction: direction, frames: others, frontToBack: frontToBack, mru: mru)
        }

        describe("3Column Left with columns 1/3/1") {
            let frames: [String: CGRect] = [
                "main": CGRect(x: 0, y: 0, width: 1000, height: 1500),
                "middle1": CGRect(x: 1000, y: 0, width: 1000, height: 500),
                "middle2": CGRect(x: 1000, y: 500, width: 1000, height: 500),
                "middle3": CGRect(x: 1000, y: 1000, width: 1000, height: 500),
                "right": CGRect(x: 2000, y: 0, width: 1000, height: 1500)
            ]

            it("goes east from main to the middle window when none was used") {
                expect(neighbor(of: "main", .east, in: frames)).to(equal("middle2"))
            }

            it("goes east from main to the last used middle window") {
                expect(neighbor(of: "main", .east, in: frames, mru: ["main", "middle3", "middle1"])).to(equal("middle3"))
            }

            it("goes west from the middle column to main") {
                expect(neighbor(of: "middle3", .west, in: frames)).to(equal("main"))
            }

            it("goes west from the right column to the last used middle window, not main") {
                expect(neighbor(of: "right", .west, in: frames, mru: ["right", "middle1", "main"])).to(equal("middle1"))
            }

            it("returns east, west, east to the same window") {
                let first = neighbor(of: "main", .east, in: frames, mru: ["main", "middle1"])
                expect(first).to(equal("middle1"))
                expect(neighbor(of: first!, .west, in: frames, mru: [first!, "main"])).to(equal("main"))
                expect(neighbor(of: "main", .east, in: frames, mru: ["main", first!])).to(equal(first))
            }

            it("moves north and south within a column") {
                expect(neighbor(of: "middle2", .north, in: frames)).to(equal("middle1"))
                expect(neighbor(of: "middle2", .south, in: frames)).to(equal("middle3"))
            }
        }

        describe("Tall") {
            let frames: [String: CGRect] = [
                "main": CGRect(x: 0, y: 0, width: 2000, height: 1500),
                "stack1": CGRect(x: 2000, y: 0, width: 1000, height: 750),
                "stack2": CGRect(x: 2000, y: 750, width: 1000, height: 750)
            ]

            it("crosses between main and the stack") {
                expect(neighbor(of: "main", .east, in: frames, mru: ["stack2"])).to(equal("stack2"))
                expect(neighbor(of: "stack1", .west, in: frames)).to(equal("main"))
            }

            it("moves within the stack") {
                expect(neighbor(of: "stack1", .south, in: frames)).to(equal("stack2"))
                expect(neighbor(of: "stack2", .north, in: frames)).to(equal("stack1"))
            }

            it("does nothing at the screen edge") {
                expect(neighbor(of: "main", .west, in: frames)).to(beNil())
                expect(neighbor(of: "main", .north, in: frames)).to(beNil())
                expect(neighbor(of: "stack1", .east, in: frames)).to(beNil())
                expect(neighbor(of: "stack1", .north, in: frames)).to(beNil())
            }
        }

        describe("Two Pane") {
            let secondary = CGRect(x: 1500, y: 0, width: 1500, height: 1500)
            let frames: [String: CGRect] = [
                "main": CGRect(x: 0, y: 0, width: 1500, height: 1500),
                "behind": secondary,
                "front": secondary,
                "back": secondary
            ]

            it("reaches only the frontmost window of the secondary stack") {
                expect(neighbor(of: "main", .east, in: frames, frontToBack: ["main", "front", "behind", "back"], mru: ["behind", "back"])).to(equal("front"))
            }

            it("goes west from the secondary to main") {
                expect(neighbor(of: "front", .west, in: frames)).to(equal("main"))
            }
        }

        describe("a floating start") {
            let frames: [String: CGRect] = [
                "main": CGRect(x: 0, y: 0, width: 1000, height: 1500),
                "middle": CGRect(x: 1000, y: 0, width: 1000, height: 1500),
                "right": CGRect(x: 2000, y: 0, width: 1000, height: 1500)
            ]
            let settings = CGRect(x: 1100, y: 400, width: 800, height: 600)

            it("reaches the nearest tile in that direction") {
                expect(DirectionalNavigation.neighbor(of: settings, direction: .west, frames: frames, frontToBack: [], mru: [])).to(equal("main"))
                expect(DirectionalNavigation.neighbor(of: settings, direction: .east, frames: frames, frontToBack: [], mru: [])).to(equal("right"))
                expect(DirectionalNavigation.neighbor(of: settings, direction: .north, frames: frames, frontToBack: [], mru: [])).to(beNil())
            }
        }

        describe("no overlap") {
            it("takes the nearest centre in that half-plane") {
                let frames: [String: CGRect] = [
                    "focused": CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    "near": CGRect(x: 0, y: 600, width: 900, height: 500),
                    "far": CGRect(x: 0, y: 1200, width: 900, height: 500)
                ]

                expect(neighbor(of: "focused", .west, in: frames)).to(equal("near"))
            }
        }

        describe("Two Pane stack browsing") {
            let stack = ["a", "b", "c"]

            it("steps to the next and previous window, wrapping around") {
                expect(DirectionalNavigation.stackStep(stack: stack, current: "a", front: "a", forward: true)).to(equal("b"))
                expect(DirectionalNavigation.stackStep(stack: stack, current: "c", front: "c", forward: true)).to(equal("a"))
                expect(DirectionalNavigation.stackStep(stack: stack, current: "a", front: "a", forward: false)).to(equal("c"))
                expect(DirectionalNavigation.stackStep(stack: stack, current: "b", front: "b", forward: false)).to(equal("a"))
            }

            it("enters the stack from main at the window after (or before) the one in front") {
                expect(DirectionalNavigation.stackStep(stack: stack, current: "main", front: "b", forward: true)).to(equal("c"))
                expect(DirectionalNavigation.stackStep(stack: stack, current: "main", front: "b", forward: false)).to(equal("a"))
            }

            it("starts at the first window when none is known to be in front") {
                expect(DirectionalNavigation.stackStep(stack: stack, current: "main", front: nil, forward: true)).to(equal("b"))
                expect(DirectionalNavigation.stackStep(stack: stack, current: "main", front: "gone", forward: false)).to(equal("c"))
            }

            it("does nothing without a stack, and stays put with one window") {
                expect(DirectionalNavigation.stackStep(stack: [String](), current: "main", front: nil, forward: true)).to(beNil())
                expect(DirectionalNavigation.stackStep(stack: ["a"], current: "a", front: "a", forward: true)).to(equal("a"))
            }

            it("browses with north/south on a landscape screen and west/east on a portrait one") {
                expect(DirectionalNavigation.stackBrowse(.north, isLandscape: true)).to(equal(false))
                expect(DirectionalNavigation.stackBrowse(.south, isLandscape: true)).to(equal(true))
                expect(DirectionalNavigation.stackBrowse(.west, isLandscape: true)).to(beNil())
                expect(DirectionalNavigation.stackBrowse(.east, isLandscape: true)).to(beNil())

                expect(DirectionalNavigation.stackBrowse(.west, isLandscape: false)).to(equal(false))
                expect(DirectionalNavigation.stackBrowse(.east, isLandscape: false)).to(equal(true))
                expect(DirectionalNavigation.stackBrowse(.north, isLandscape: false)).to(beNil())
                expect(DirectionalNavigation.stackBrowse(.south, isLandscape: false)).to(beNil())
            }
        }
    }
}
