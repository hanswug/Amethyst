//
//  CommandPaletteTests.swift
//  AmethystTests
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class CommandPaletteTests: QuickSpec {
    override func spec() {
        let swapMain = CommandPaletteEntry(name: "Swap focused window with main window", commandKey: "swap-main", shortcut: "⌃⌥⌘M")
        let cyclePadding = CommandPaletteEntry(name: "Cycle padding mode forward", commandKey: "cycle-padding-mode", shortcut: "⌃⌥⇧⌘0")
        let select27 = CommandPaletteEntry(name: "Select 27 padding mode", commandKey: "select-27-padding-mode", shortcut: nil)
        let all = [swapMain, cyclePadding, select27]

        describe("filtering") {
            it("keeps everything, in order, for an empty query") {
                expect(CommandPalette.filter(all, query: "")).to(equal(all))
                expect(CommandPalette.filter(all, query: "   ")).to(equal(all))
            }

            it("ignores case") {
                expect(CommandPalette.filter(all, query: "SWAP")).to(equal([swapMain]))
            }

            it("needs every word to match") {
                expect(CommandPalette.filter(all, query: "pad 27")).to(equal([select27]))
                expect(CommandPalette.filter(all, query: "padding")).to(equal([cyclePadding, select27]))
            }

            it("matches command keys") {
                expect(CommandPalette.filter(all, query: "swap-main")).to(equal([swapMain]))
            }

            it("returns nothing when nothing matches") {
                expect(CommandPalette.filter(all, query: "warp")).to(beEmpty())
            }
        }

        describe("notes") {
            it("adds a note only to the entries that have one, keeping the order") {
                let annotated = CommandPalette.annotating(all, notes: ["cycle-padding-mode": "now wide", "not-listed": "now 1"])
                expect(annotated.map { $0.name }).to(equal([
                    "Swap focused window with main window",
                    "Cycle padding mode forward (now wide)",
                    "Select 27 padding mode"
                ]))
                expect(annotated.map { $0.commandKey }).to(equal(all.map { $0.commandKey }))
                expect(annotated[1].shortcut).to(equal(cyclePadding.shortcut))
            }
        }

        describe("entries") {
            let namesAndKeys = [
                ["Swap focused window with main window", "swap-main"],
                ["Select 27 padding mode", "select-27-padding-mode"],
                ["Not set up", "not-set-up"],
                ["Show command palette", CommandKey.showCommandPalette.rawValue]
            ]
            let registered: Set<String> = ["swap-main", "select-27-padding-mode", CommandKey.showCommandPalette.rawValue]

            it("lists registered commands in order, with their shortcuts, but not the palette itself") {
                let entries = CommandPalette.entries(from: namesAndKeys, registered: registered) { $0 == "swap-main" ? "⌃⌥⌘M" : nil }
                expect(entries).to(equal([
                    CommandPaletteEntry(name: "Swap focused window with main window", commandKey: "swap-main", shortcut: "⌃⌥⌘M"),
                    CommandPaletteEntry(name: "Select 27 padding mode", commandKey: "select-27-padding-mode", shortcut: nil)
                ]))
            }

            it("leaves out layouts the configuration doesn't use") {
                let hidden = CommandPalette.unconfiguredLayoutCommands(
                    availableLayoutKeys: ["tall", "4column", "two-pane"],
                    configuredLayoutKeys: ["two-pane", "tall"]
                )
                expect(hidden).to(equal(["select-4column-layout"]))
            }

            it("names every command, the palette included") {
                let keys = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey().map { $0[1] }
                expect(keys).to(contain(CommandKey.showCommandPalette.rawValue))
                expect(Set(keys).count).to(equal(keys.count))
            }
        }
    }
}
