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

            it("uses a configured share of the area") {
                let half = CGSize(width: 0.5, height: 0.5)
                expect(OverflowWindows.size(in: area, mode: .reasonable, fixedSize: nil, share: half)).to(equal(CGSize(width: 1920, height: 810)))
                expect(OverflowWindows.sizeDescription(mode: .reasonable, fixedSize: nil, share: half)).to(equal("50% × 50%"))
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

            it("keeps the slot's centre when re-centring on the size an app accepted") {
                let accepted = CGSize(width: 1200, height: 900)
                let target = OverflowWindows.frame(size: size, centeredIn: area, cascade: 1)
                let corrected = OverflowWindows.frame(size: accepted, centeredIn: area, cascade: 1)
                expect(corrected.midX).to(equal(target.midX))
                expect(corrected.midY).to(equal(target.midY))
            }

            it("keeps the window inside the area") {
                let large = CGSize(width: 2500, height: 1400)
                expect(OverflowWindows.frame(size: large, centeredIn: area, cascade: 5)).to(equal(CGRect(x: 700, y: 760, width: 2500, height: 1400)))
            }
        }

        describe("cascading") {
            let area = CGRect(x: 0, y: 0, width: 3000, height: 2000)
            let slot0 = CGPoint(x: 1500, y: 1000)
            let slot1 = CGPoint(x: 1530, y: 1030)

            it("starts at the centre") {
                expect(OverflowWindows.cascadeIndex(occupiedCenters: [], in: area)).to(equal(0))
            }

            it("takes the next free slot") {
                expect(OverflowWindows.cascadeIndex(occupiedCenters: [slot0], in: area)).to(equal(1))
                expect(OverflowWindows.cascadeIndex(occupiedCenters: [slot0, slot1], in: area)).to(equal(2))
            }

            it("reuses a slot that freed up") {
                expect(OverflowWindows.cascadeIndex(occupiedCenters: [slot1], in: area)).to(equal(0))
            }

            it("matches slots by centre, whatever the window's size, within a few points") {
                expect(OverflowWindows.cascadeIndex(occupiedCenters: [CGPoint(x: 1503, y: 998)], in: area)).to(equal(1))
            }

            it("ignores windows moved off their slot") {
                expect(OverflowWindows.cascadeIndex(occupiedCenters: [CGPoint(x: 900, y: 400)], in: area)).to(equal(0))
            }
        }

        describe("explaining") {
            it("names the window limit") {
                expect(WindowExplanation.reasonText(.windowLimit, floating: true, allowList: false)).to(equal("over the window limit (window-overflow: float)"))
            }
        }
    }
}
