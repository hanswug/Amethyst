//
//  SecondaryWindowAnchorsTests.swift
//  AmethystTests
//

@testable import Amethyst
import Nimble
import Quick

class SecondaryWindowAnchorsTests: QuickSpec {
    override func spec() {
        typealias Anchors = SecondaryWindowAnchors<Int>

        let obsidianHere = Anchors.Slot(pid: 100, space: 1)
        let obsidianThere = Anchors.Slot(pid: 100, space: 2)
        let otherAppHere = Anchors.Slot(pid: 200, space: 1)

        describe("claiming") {
            it("makes the first window the anchor") {
                var anchors = Anchors()

                expect(anchors.claim(obsidianHere, for: 1)).to(beTrue())
                expect(anchors.anchor(for: obsidianHere)).to(equal(1))
            }

            it("keeps the existing anchor") {
                var anchors = Anchors()
                anchors.claim(obsidianHere, for: 1)

                expect(anchors.claim(obsidianHere, for: 2)).to(beFalse())
                expect(anchors.anchor(for: obsidianHere)).to(equal(1))
            }

            it("keeps one anchor per application and space") {
                var anchors = Anchors()

                anchors.claim(obsidianHere, for: 1)
                anchors.claim(obsidianThere, for: 2)
                anchors.claim(otherAppHere, for: 3)

                expect(anchors.anchor(for: obsidianHere)).to(equal(1))
                expect(anchors.anchor(for: obsidianThere)).to(equal(2))
                expect(anchors.anchor(for: otherAppHere)).to(equal(3))
            }
        }

        describe("releasing") {
            it("frees the anchor's slot") {
                var anchors = Anchors()
                anchors.claim(obsidianHere, for: 1)

                expect(anchors.release(1)).to(equal(obsidianHere))
                expect(anchors.anchor(for: obsidianHere)).to(beNil())
                expect(anchors.claim(obsidianHere, for: 2)).to(beTrue())
            }

            it("ignores windows that aren't anchors") {
                var anchors = Anchors()
                anchors.claim(obsidianHere, for: 1)

                expect(anchors.release(2)).to(beNil())
                expect(anchors.anchor(for: obsidianHere)).to(equal(1))
            }

            it("leaves other slots alone") {
                var anchors = Anchors()
                anchors.claim(obsidianHere, for: 1)
                anchors.claim(obsidianThere, for: 2)

                anchors.release(1)

                expect(anchors.anchor(for: obsidianThere)).to(equal(2))
                expect(anchors.slot(anchoredBy: 2)).to(equal(obsidianThere))
            }
        }
    }
}
