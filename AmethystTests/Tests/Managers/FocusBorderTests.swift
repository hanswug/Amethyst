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

            it("stays in top-left coordinates for the window server") {
                let appearance = FocusBorderAppearance(style: .solid, width: 5, radius: 12, color: .accent, gradient: [])

                expect(appearance.windowServerFrame(forWindowFrame: windowFrame)).to(equal(CGRect(x: 95, y: 45, width: 810, height: 610)))
            }

            it("rounds out to whole points, as the window server places windows") {
                let appearance = FocusBorderAppearance(style: .gradient, width: 1.5, radius: 12, color: .accent, gradient: [])

                expect(appearance.windowServerFrame(forWindowFrame: windowFrame)).to(equal(CGRect(x: 98, y: 48, width: 804, height: 604)))
            }
        }

        describe("the border pieces") {
            let appearance = FocusBorderAppearance(style: .gradient, width: 1.5, radius: 16, color: .accent, gradient: [])
            let window = CGRect(x: 100, y: 50, width: 800, height: 600)
            let pieces = FocusBorderPieces(windowFrame: window, appearance: appearance)

            it("reaches as far as the overlay, in whole points") {
                // 1.5 pt rounds out to 2 on every side.
                expect([pieces.left, pieces.top, pieces.right, pieces.bottom]).to(equal([2, 2, 2, 2]))
                expect(pieces.corner).to(equal(16))
            }

            it("tiles the overlay's outline without gaps") {
                let rects = pieces.rects(around: window)
                expect(rects[.topLeft]).to(equal(CGRect(x: 98, y: 48, width: 18, height: 18)))
                expect(rects[.top]).to(equal(CGRect(x: 116, y: 48, width: 768, height: 2)))
                expect(rects[.topRight]).to(equal(CGRect(x: 884, y: 48, width: 18, height: 18)))
                expect(rects[.right]).to(equal(CGRect(x: 900, y: 66, width: 2, height: 568)))
                expect(rects[.bottomRight]).to(equal(CGRect(x: 884, y: 634, width: 18, height: 18)))
                expect(rects[.bottom]).to(equal(CGRect(x: 116, y: 650, width: 768, height: 2)))
                expect(rects[.bottomLeft]).to(equal(CGRect(x: 98, y: 634, width: 18, height: 18)))
                expect(rects[.left]).to(equal(CGRect(x: 98, y: 66, width: 2, height: 568)))
            }

            it("keeps the corners and stretches the edges when the window resizes") {
                let rects = pieces.rects(around: CGRect(x: 100, y: 50, width: 1000, height: 600))
                expect(rects[.topLeft]?.size).to(equal(CGSize(width: 18, height: 18)))
                expect(rects[.top]?.width).to(equal(968))
                expect(rects[.topRight]?.minX).to(equal(1084))
            }

            it("maps screen points onto a piece drawn at another length") {
                let transform = FocusBorderPieces.transform(showing: CGSize(width: 768, height: 2), in: CGRect(x: 116, y: 48, width: 968, height: 2))
                expect(CGPoint(x: 116, y: 48).applying(transform)).to(equal(.zero))
                expect(CGPoint(x: 1084, y: 50).applying(transform).x).to(beCloseTo(768))
                expect(CGPoint(x: 1084, y: 50).applying(transform).y).to(beCloseTo(2))
            }
        }

        describe("the drawing") {
            let size = CGSize(width: 120, height: 100)

            func alpha(at point: CGPoint, style: FocusBorderStyle) -> UInt8 {
                let appearance = FocusBorderAppearance(
                    style: style, width: 5, radius: 12, color: .rgba(red: 1, green: 0, blue: 0, alpha: 1),
                    gradient: FocusBorderAppearance.defaultGradient
                )
                let context = CGContext(
                    data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )!
                let windowRect = CGRect(origin: .zero, size: size).insetBy(dx: appearance.reach, dy: appearance.reach)
                FocusBorderDrawing.draw(in: context, size: size, windowRect: windowRect, appearance: appearance)
                let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
                // Bitmap rows run top to bottom; the drawing's origin is bottom left.
                let row = Int(size.height) - 1 - Int(point.y)
                return pixels[row * context.bytesPerRow + Int(point.x) * 4 + 3]
            }

            it("draws the ring just outside the window and nothing over the window") {
                for style in FocusBorderStyle.allCases {
                    let reach = FocusBorderAppearance(style: style, width: 5, radius: 12, color: .accent, gradient: []).reach
                    // Just outside the left edge, half way up; then the window's centre.
                    expect(alpha(at: CGPoint(x: reach - 1, y: 50), style: style)).to(beGreaterThan(0), description: style.rawValue)
                    expect(alpha(at: CGPoint(x: 60, y: 50), style: style)).to(equal(0), description: style.rawValue)
                    expect(alpha(at: CGPoint(x: reach + 1, y: 50), style: style)).to(equal(0), description: style.rawValue)
                }
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
