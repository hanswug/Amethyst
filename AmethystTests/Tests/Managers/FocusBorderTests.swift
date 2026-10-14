//
//  FocusBorderTests.swift
//  AmethystTests
//

@testable import Amethyst
import AppKit
import Nimble
import Quick
import XCTest

class FocusBorderTests: QuickSpec {
    override func spec() {
        describe("colours") {
            it("reads #RRGGBB as opaque") {
                expect(FocusBorderColor("#FF453A")).to(equal(.rgba(red: 1, green: 0x45 / 255, blue: 0x3A / 255, alpha: 1)))
            }

            it("reads #AARRGGBB with its alpha") {
                expect(FocusBorderColor("#80FFFFFF")).to(equal(.rgba(red: 1, green: 1, blue: 1, alpha: 0x80 / 255)))
            }

            it("accepts lower case and a missing #") {
                expect(FocusBorderColor("ff453a")).to(equal(FocusBorderColor("#FF453A")))
            }

            it("knows the accent colour") {
                expect(FocusBorderColor("accent")).to(equal(.accent))
                expect(FocusBorderColor(" Accent ")).to(equal(.accent))
            }

            it("rejects anything else") {
                expect(FocusBorderColor("red")).to(beNil())
                expect(FocusBorderColor("#FF45")).to(beNil())
                expect(FocusBorderColor("#GG453A")).to(beNil())
                expect(FocusBorderColor("+FF453A")).to(beNil())
                expect(FocusBorderColor("")).to(beNil())
            }
        }

        describe("styles") {
            it("cycles glow, solid, gradient and wraps around") {
                expect(FocusBorderStyle.glow.next).to(equal(.solid))
                expect(FocusBorderStyle.solid.next).to(equal(.gradient))
                expect(FocusBorderStyle.gradient.next).to(equal(.glow))
            }
        }

        describe("the overlay frame") {
            let windowFrame = CGRect(x: 100, y: 50, width: 800, height: 600)

            it("surrounds the window by the ring width and flips to Cocoa coordinates") {
                let appearance = FocusBorderAppearance(style: .solid, width: 5, radius: 12, color: .accent, gradient: [])

                // Cocoa y = 2160 - (50 + 600) = 1510.
                expect(appearance.overlayFrame(forWindowFrame: windowFrame, primaryScreenHeight: 2160))
                    .to(equal(CGRect(x: 95, y: 1505, width: 810, height: 610)))
            }

            it("leaves room for the glow") {
                let appearance = FocusBorderAppearance(style: .glow, width: 5, radius: 12, color: .accent, gradient: [])

                expect(appearance.reach).to(equal(11.5))
                expect(appearance.ringWidth).to(equal(1.5))
                expect(appearance.overlayFrame(forWindowFrame: windowFrame, primaryScreenHeight: 2160))
                    .to(equal(CGRect(x: 88.5, y: 1498.5, width: 823, height: 623)))
            }
        }
    }
}

/// AppKit windows can only be made on the main thread, where XCTest runs `@MainActor` methods (Quick's specs run elsewhere).
class FocusBorderPanelTests: XCTestCase {
    @MainActor func testItIsNotPushedOutFromUnderTheMenuBar() {
        let frame = NSRect(x: 50, y: 2000, width: 400, height: 300)
        XCTAssertEqual(FocusBorderPanel().constrainFrameRect(frame, to: NSScreen.screens.first), frame)
    }
}
