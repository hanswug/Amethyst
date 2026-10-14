//
//  RefusedTilesTests.swift
//  AmethystTests
//

@testable import Amethyst
import Foundation
import Nimble
import Quick

class RefusedTilesTests: QuickSpec {
    override func spec() {
        func fit(_ id: Int, _ name: String = "Safari", tile: CGSize, actual: CGSize) -> TileFit<Int> {
            return TileFit(windowID: id, applicationName: name, tile: tile, actual: actual)
        }

        let narrow = CGSize(width: 520, height: 420)
        let narrower = CGSize(width: 400, height: 420)
        let wide = CGSize(width: 900, height: 420)
        let safari = CGSize(width: 700, height: 420)

        describe("refusing a tile") {
            it("allows a few points of rounding") {
                expect(fit(1, tile: narrow, actual: CGSize(width: 524, height: 424)).refused).to(beFalse())
                expect(fit(1, tile: narrow, actual: CGSize(width: 525, height: 420)).refused).to(beTrue())
                expect(fit(1, tile: narrow, actual: CGSize(width: 520, height: 425)).refused).to(beTrue())
            }

            it("never counts a smaller window") {
                expect(fit(1, tile: narrow, actual: CGSize(width: 510, height: 400)).refused).to(beFalse())
            }
        }

        describe("tracking") {
            it("reports a window once per tile size") {
                var tracker = RefusedTileTracker<Int>()

                expect(tracker.update([fit(1, tile: narrow, actual: safari)]).map { $0.windowID }).to(equal([1]))
                expect(tracker.update([fit(1, tile: narrow, actual: safari)])).to(beEmpty())
                expect(tracker.update([fit(1, tile: CGSize(width: 520.3, height: 419.8), actual: safari)])).to(beEmpty())
                expect(tracker.update([fit(1, tile: narrower, actual: safari)]).map { $0.windowID }).to(equal([1]))
            }

            it("forgets a window once it fits") {
                var tracker = RefusedTileTracker<Int>()

                _ = tracker.update([fit(1, tile: narrow, actual: safari)])
                expect(tracker.update([fit(1, tile: wide, actual: wide)])).to(beEmpty())
                expect(tracker.update([fit(1, tile: narrow, actual: safari)]).map { $0.windowID }).to(equal([1]))
            }

            it("reports several windows of one pass together") {
                var tracker = RefusedTileTracker<Int>()

                let report = tracker.update([
                    fit(1, tile: narrow, actual: safari),
                    fit(2, "Zed", tile: wide, actual: wide),
                    fit(3, "Zed", tile: narrow, actual: safari)
                ])
                expect(report.map { $0.windowID }).to(equal([1, 3]))
            }
        }

        describe("HUD text") {
            it("names the app and both sizes for one window") {
                let text = RefusedTileHUD.text(for: [fit(1, tile: narrow, actual: safari)])
                expect(text.title).to(equal("Safari doesn't fit its tile"))
                expect(text.description).to(equal("needs 700 × 420 · tile 520 × 420"))
            }

            it("lists the apps for several windows") {
                let text = RefusedTileHUD.text(for: [fit(1, tile: narrow, actual: safari), fit(2, "Zed", tile: narrow, actual: safari)])
                expect(text.title).to(equal("2 windows don't fit their tiles"))
                expect(text.description).to(equal("Safari, Zed"))
            }
        }

        describe("configuration") {
            it("shows the HUD by default") {
                let path = Bundle.main.path(forResource: "default", ofType: "amethyst")
                let data = path.flatMap { FileManager.default.contents(atPath: $0) }
                let defaults = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                expect(defaults?["enables-refused-tile-hud"] as? Bool).to(beTrue())
            }
        }
    }
}
