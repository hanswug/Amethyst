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
            it("has no screen or space commands") {
                let keys = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey().map { $0[1] }
                expect(keys.filter { $0.contains("-screen") || $0.hasPrefix("throw-space") }).to(beEmpty())
            }

            it("lists the directional commands") {
                let keys = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey().map { $0[1] }
                let directional = Direction.allCases.flatMap { ["focus-\($0.rawValue)", "swap-\($0.rawValue)"] }

                expect(keys).to(contain(directional))
                expect(directional.compactMap { CommandKey(rawValue: $0) }.count).to(equal(8))
            }

            it("lists the focus border commands") {
                let keys = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey().map { $0[1] }
                expect(keys).to(contain([CommandKey.toggleFocusBorder.rawValue, CommandKey.cycleFocusBorderStyle.rawValue]))
            }

            it("has no custom layout commands") {
                let keys = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey().map { $0[1] }

                expect(keys.filter { ["command1", "command2", "command3", "command4"].contains($0) }).to(beEmpty())
            }
        }

        describe("command URL") {
            func commandKey(_ string: String) -> String? {
                return URL(string: string).flatMap { CommandURL.commandKey(from: $0) }
            }

            it("reads the command key") {
                expect(commandKey("ametrine://command/cycle-padding-mode")).to(equal("cycle-padding-mode"))
                expect(commandKey("ametrine://command/select-middle-wide-layout/")).to(equal("select-middle-wide-layout"))
                expect(commandKey("AMETRINE://Command/swap-main")).to(equal("swap-main"))
            }

            it("decodes percent-encoded keys") {
                expect(commandKey("ametrine://command/select-my%20mode-padding-mode")).to(equal("select-my mode-padding-mode"))
            }

            it("rejects other URLs") {
                expect(commandKey("ametrine://command/")).to(beNil())
                expect(commandKey("ametrine://command")).to(beNil())
                expect(commandKey("ametrine://command/a/b")).to(beNil())
                expect(commandKey("ametrine://config/cycle-padding-mode")).to(beNil())
                expect(commandKey("amethyst://command/cycle-padding-mode")).to(beNil())
                expect(commandKey("https://command/cycle-padding-mode")).to(beNil())
            }

            it("reads the value of commands that take a number") {
                func value(_ string: String) -> String? {
                    return URL(string: string).flatMap { CommandURL.value(from: $0) }
                }

                expect(commandKey("ametrine://command/set-window-max-count?value=8")).to(equal("set-window-max-count"))
                expect(value("ametrine://command/set-window-max-count?value=8")).to(equal("8"))
                expect(value("ametrine://command/set-window-max-count?other=1&value=0")).to(equal("0"))
                expect(value("ametrine://command/set-window-max-count")).to(beNil())
                expect(value("ametrine://command/set-window-max-count?count=8")).to(beNil())
            }
        }
    }
}
