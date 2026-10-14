//
//  WindowExplanationTests.swift
//  AmethystTests
//

@testable import Amethyst
import Nimble
import Quick

class WindowExplanationTests: QuickSpec {
    override func spec() {
        func text(_ input: WindowExplanation.Input) -> [String] {
            let text = WindowExplanation.text(for: input)
            return [text.title, text.description]
        }

        describe("windows that aren't managed") {
            it("names dialogs and panels") {
                expect(text(.init(state: .notStandard))).to(equal(["Not managed", "not a standard window (dialog, sheet or panel)"]))
            }

            it("points untracked windows to reevaluate-windows") {
                expect(text(.init(state: .notTracked))).to(equal(["Not managed", "not tracked yet · try reevaluate-windows"]))
            }
        }

        describe("floating windows") {
            it("names the floating rule") {
                expect(text(.init(state: .floating, reason: .listed(id: "com.apple.systempreferences"))))
                    .to(equal(["Floating", "in floating list (com.apple.systempreferences)"]))
                expect(text(.init(state: .floating, reason: .titleMatched(pattern: "^Settings$", id: "md.obsidian"))))
                    .to(equal(["Floating", "title rule ^Settings$ (md.obsidian)"]))
            }

            it("marks allow-list decisions") {
                expect(text(.init(state: .floating, reason: .notListed, floatingIsAllowList: true)))
                    .to(equal(["Floating", "not in floating list (allow list)"]))
                expect(text(.init(state: .floating, reason: .titleNotMatched(id: "md.obsidian"), floatingIsAllowList: true)))
                    .to(equal(["Floating", "no title rule matches (md.obsidian) (allow list)"]))
            }

            it("names the other reasons") {
                expect(text(.init(state: .floating, reason: .smallWindow(threshold: 500)))).to(equal(["Floating", "small window (under 500 pt)"]))
                expect(text(.init(state: .floating, reason: .secondaryWindow))).to(equal(["Floating", "secondary window (floating-secondary-windows)"]))
                expect(text(.init(state: .floating, reason: .secondaryWindowSpaceUnknown)))
                    .to(equal(["Floating", "secondary window, space unknown (floating-secondary-windows)"]))
                expect(text(.init(state: .floating, reason: .noRunningApplication))).to(equal(["Floating", "its app isn't running"]))
                expect(text(.init(state: .floating, reason: .toggled))).to(equal(["Floating", "floated by hand (toggle-float)"]))
                expect(text(.init(state: .floating))).to(equal(["Floating", "reason not recorded"]))
            }
        }

        describe("tiled windows") {
            it("adds the window count and limit") {
                expect(text(.init(state: .tiled, reason: .notListed, tiledCount: 5, windowMaxCount: 8)))
                    .to(equal(["Tiled", "no floating rule · 5 of 8 windows"]))
                expect(text(.init(state: .tiled, reason: .notListed, tiledCount: 5)))
                    .to(equal(["Tiled", "no floating rule · 5 windows, no limit"]))
            }

            it("names manual tiling, allow lists and the secondary window anchor") {
                expect(text(.init(state: .tiled, reason: .toggled, tiledCount: 2, windowMaxCount: 8)))
                    .to(equal(["Tiled", "tiled by hand (toggle-float) · 2 of 8 windows"]))
                expect(text(.init(state: .tiled, reason: .listed(id: "md.obsidian"), floatingIsAllowList: true, tiledCount: 1, windowMaxCount: 8)))
                    .to(equal(["Tiled", "in floating list (md.obsidian) (allow list) · 1 of 8 windows"]))
                expect(text(.init(state: .tiled, reason: .titleNotMatched(id: "md.obsidian"), isSecondaryWindowAnchor: true, tiledCount: 3, windowMaxCount: 8)))
                    .to(equal(["Tiled", "no title rule matches (md.obsidian) · anchor of its app on this space · 3 of 8 windows"]))
            }

            it("says when nothing tiles") {
                expect(text(.init(state: .tiled, reason: .notListed, tilingEnabled: false))).to(equal(["Floating", "tiling is off"]))
                expect(text(.init(state: .tiled, reason: .notListed, isFloatingLayout: true))).to(equal(["Floating", "Floating layout"]))
            }
        }
    }
}
