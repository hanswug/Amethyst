//
//  AppArgumentsTests.swift
//  AmethystTests
//

@testable import Amethyst
import Nimble
import Quick

class AppArgumentsTests: QuickSpec {
    override func spec() {
        describe("launch arguments") {
            it("accepts --log") {
                expect { try App.parse(["--log"]) }.toNot(throwError())
                expect(try? App.parse(["--log"]).logging).to(beTrue())
            }

            it("runs without arguments") {
                expect(try? App.parse([]).logging).to(beFalse())
            }

            it("still rejects unknown options") {
                expect { try App.parse(["--nonsense"]) }.to(throwError())
            }
        }
    }
}
