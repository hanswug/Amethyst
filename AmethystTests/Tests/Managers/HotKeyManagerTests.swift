//
//  HotKeyManagerTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/18/17.
//  Copyright © 2017 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class HotKeyManagerTests: QuickSpec {
    override func spec() {
        describe("hotKeyNameToDefaultsKey") {
            it("has the right number of screens") {
                let keyMapping = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey()
                let screenCommands = keyMapping.filter { $0[1].hasPrefix(CommandKey.focusScreenPrefix.rawValue) }
                expect(screenCommands.count).to(equal(7))
            }
        }

        describe("command URL") {
            func commandKey(_ string: String) -> String? {
                return URL(string: string).flatMap { CommandURL.commandKey(from: $0) }
            }

            it("reads the command key") {
                expect(commandKey("amethyst://command/cycle-padding-mode")).to(equal("cycle-padding-mode"))
                expect(commandKey("amethyst://command/select-middle-wide-layout/")).to(equal("select-middle-wide-layout"))
                expect(commandKey("AMETHYST://Command/swap-main")).to(equal("swap-main"))
            }

            it("decodes percent-encoded keys") {
                expect(commandKey("amethyst://command/select-my%20mode-padding-mode")).to(equal("select-my mode-padding-mode"))
            }

            it("rejects other URLs") {
                expect(commandKey("amethyst://command/")).to(beNil())
                expect(commandKey("amethyst://command")).to(beNil())
                expect(commandKey("amethyst://command/a/b")).to(beNil())
                expect(commandKey("amethyst://config/cycle-padding-mode")).to(beNil())
                expect(commandKey("https://command/cycle-padding-mode")).to(beNil())
            }
        }
    }
}
