//
//  OverflowWindowsTests.swift
//  AmethystTests
//

@testable import Amethyst
import Foundation
import Nimble
import Quick

class OverflowWindowsTests: QuickSpec {
    override func spec() {
        describe("choosing the windows to float") {
            it("floats the newest windows over the limit, oldest of them first") {
                let order = ["a": 0, "b": 1, "c": 2, "d": 3]
                expect(OverflowWindows.newest(["a", "b", "c", "d"], order: order, over: 3)).to(equal(["d"]))
                expect(OverflowWindows.newest(["a", "b", "c", "d"], order: order, over: 2)).to(equal(["c", "d"]))
            }

            it("goes by when windows were added, not where they are in the layout") {
                // "d" is the newest even after being swapped into the main pane.
                let order = ["a": 0, "b": 1, "c": 2, "d": 3]
                expect(OverflowWindows.newest(["d", "a", "b", "c"], order: order, over: 3)).to(equal(["d"]))
            }

            it("floats nothing at or under the limit") {
                let order = ["a": 0, "b": 1]
                expect(OverflowWindows.newest(["a", "b"], order: order, over: 2)).to(beEmpty())
                expect(OverflowWindows.newest(["a", "b"], order: order, over: 5)).to(beEmpty())
            }

            it("counts windows without an order as oldest") {
                let order = ["b": 1, "c": 2]
                expect(OverflowWindows.newest(["a", "b", "c"], order: order, over: 1)).to(equal(["b", "c"]))
            }
        }

        describe("sizing") {
            let area = CGRect(x: 0, y: 0, width: 3840, height: 1620)

            it("takes 60% × 70% of the usable area by default") {
                expect(OverflowWindows.size(in: area, mode: .reasonable, fixedSize: nil)).to(equal(CGSize(width: 2304, height: 1134)))
                expect(OverflowWindows.size(in: area, mode: .reasonable, fixedSize: CGSize(width: 1600, height: 1100)))
                    .to(equal(CGSize(width: 2304, height: 1134)))
            }

            it("uses the configured size, never bigger than the area") {
                expect(OverflowWindows.size(in: area, mode: .fixed, fixedSize: CGSize(width: 1600, height: 1100))).to(equal(CGSize(width: 1600, height: 1100)))
                expect(OverflowWindows.size(in: area, mode: .fixed, fixedSize: CGSize(width: 5000, height: 2000))).to(equal(CGSize(width: 3840, height: 1620)))
            }

            it("falls back to 60% × 70% without a configured size") {
                expect(OverflowWindows.size(in: area, mode: .fixed, fixedSize: nil)).to(equal(CGSize(width: 2304, height: 1134)))
            }

            it("describes the size") {
                expect(OverflowWindows.sizeDescription(mode: .reasonable, fixedSize: CGSize(width: 1600, height: 1100))).to(equal("60% × 70%"))
                expect(OverflowWindows.sizeDescription(mode: .fixed, fixedSize: CGSize(width: 1600, height: 1100))).to(equal("1600 × 1100"))
                expect(OverflowWindows.sizeDescription(mode: .fixed, fixedSize: nil)).to(equal("60% × 70%"))
            }
        }

        describe("placing") {
            let area = CGRect(x: 640, y: 720, width: 2560, height: 1440)
            let size = CGSize(width: 1000, height: 800)

            it("centres the window in the area") {
                expect(OverflowWindows.frame(size: size, centeredIn: area, cascade: 0)).to(equal(CGRect(x: 1420, y: 1040, width: 1000, height: 800)))
            }

            it("moves each further window down and right") {
                expect(OverflowWindows.frame(size: size, centeredIn: area, cascade: 2)).to(equal(CGRect(x: 1480, y: 1100, width: 1000, height: 800)))
            }

            it("keeps the window inside the area") {
                let large = CGSize(width: 2500, height: 1400)
                expect(OverflowWindows.frame(size: large, centeredIn: area, cascade: 5)).to(equal(CGRect(x: 700, y: 760, width: 2500, height: 1400)))
            }
        }

        describe("explaining") {
            it("names the window limit") {
                expect(WindowExplanation.reasonText(.windowLimit, floating: true, allowList: false)).to(equal("over the window limit (window-overflow: float)"))
            }
        }
    }
}
