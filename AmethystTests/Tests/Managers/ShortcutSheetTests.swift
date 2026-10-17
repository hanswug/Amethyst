//
//  ShortcutSheetTests.swift
//  AmethystTests
//
//  The shortcut sheet: your own keys at a glance (Hans, 2026-10-17).
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class ShortcutSheetTests: QuickSpec {
    override func spec() {
        func entry(_ commandKey: String, _ shortcut: String?, name: String? = nil, takesNumber: Bool = false) -> CommandPaletteEntry {
            var entry = CommandPaletteEntry(name: name ?? commandKey, commandKey: commandKey, shortcut: shortcut)
            if takesNumber {
                entry.value = CommandPaletteValue(prompt: "", range: 0...99)
            }
            return entry
        }

        describe("splitting a shortcut") {
            it("separates the modifier glyphs from the key") {
                expect(ShortcutSheet.splitModifiers("⌃⌥H").modifiers).to(equal("⌃⌥"))
                expect(ShortcutSheet.splitModifiers("⌃⌥H").key).to(equal("H"))
                expect(ShortcutSheet.splitModifiers("⇧⌃⌥⌘F").modifiers).to(equal("⇧⌃⌥⌘"))
                expect(ShortcutSheet.splitModifiers("⇧⌃⌥⌘F").key).to(equal("F"))
                expect(ShortcutSheet.splitModifiers("⌃⌥←").modifiers).to(equal("⌃⌥"))
                expect(ShortcutSheet.splitModifiers("⌃⌥←").key).to(equal("←"))
                expect(ShortcutSheet.splitModifiers("F5").modifiers).to(equal(""))
                expect(ShortcutSheet.splitModifiers("F5").key).to(equal("F5"))
            }
        }

        describe("the direction grid") {
            it("shows a row's shared modifiers once and only keys in the cells") {
                let grid = ShortcutSheet.grid(shortcuts: [
                    "focus-west": "⌃⌥H", "focus-east": "⌃⌥L", "focus-main": "⌃⌥M",
                    "warp-west": "⌃⌥⌘H", "warp-east": "⌃⌥⌘L"
                ])

                expect(grid?.columns).to(equal(["west", "east", "main"]))
                expect(grid?.rows).to(equal([
                    ShortcutSheet.Grid.Row(title: "focus", modifiers: "⌃⌥", cells: ["H", "L", "M"]),
                    ShortcutSheet.Grid.Row(title: "warp", modifiers: "⌃⌥⌘", cells: ["H", "L", nil])
                ]))
            }

            it("shows whole shortcuts in a row with mixed modifiers, and drops unbound rows") {
                let grid = ShortcutSheet.grid(shortcuts: ["swap-west": "⌃⌘H", "swap-east": "⌃⌥L"])

                expect(grid?.rows).to(equal([ShortcutSheet.Grid.Row(title: "swap", modifiers: nil, cells: ["⌃⌘H", "⌃⌥L"])]))
            }

            it("is left out with nothing bound") {
                expect(ShortcutSheet.grid(shortcuts: ["cycle-layout": "⌃⌥."])).to(beNil())
            }
        }

        describe("the groups") {
            it("lists bound commands only, in the config's order, with short labels") {
                let sheet = ShortcutSheet.sheet(entries: [
                    entry("shrink-main", "⌃⌥-"),
                    entry("select-tall-left-layout", nil),
                    entry("cycle-layout", "⌃⌥."),
                    entry("select-fullscreen-layout", "⌃⌥1"),
                    entry("flip-twin", "⇧⌃⌥⌘F"),
                    entry("explain-window", nil),
                    entry("select-wide-padding-mode", "⌃⌥W"),
                    entry("focus-west", "⌃⌥H")
                ], labels: ["select-fullscreen-layout": "Fullscreen", "select-wide-padding-mode": "Padding wide"])

                expect(sheet.groups).to(equal([
                    ShortcutSheet.Group(title: "Layouts", entries: [
                        ShortcutSheet.Entry(name: "Next layout", shortcut: "⌃⌥."),
                        ShortcutSheet.Entry(name: "Fullscreen", shortcut: "⌃⌥1"),
                        ShortcutSheet.Entry(name: "Flip to twin", shortcut: "⇧⌃⌥⌘F")
                    ]),
                    ShortcutSheet.Group(title: "Main pane", entries: [ShortcutSheet.Entry(name: "Shrink main", shortcut: "⌃⌥-")]),
                    ShortcutSheet.Group(title: "Screen space", entries: [ShortcutSheet.Entry(name: "Padding wide", shortcut: "⌃⌥W")])
                ]))
                expect(sheet.grid?.rows.map(\.title)).to(equal(["focus"]))
            }

            it("counts the commands without a key, not those that take a number, and finds the palette's key") {
                let sheet = ShortcutSheet.sheet(entries: [
                    entry("explain-window", nil),
                    entry("toggle-tiling", nil),
                    entry("set-window-max-count", nil, takesNumber: true),
                    entry("show-command-palette", "⌃⌥P")
                ], labels: [:])

                expect(sheet.unboundCount).to(equal(2))
                expect(sheet.paletteShortcut).to(equal("⌃⌥P"))
            }

            it("has a group for every command there is") {
                let commandKeys = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey().map { $0[1] }
                let entries = commandKeys.map { entry($0, "⌃⌥X") }
                let sheet = ShortcutSheet.sheet(entries: entries, labels: [:])

                expect(sheet.groups.map(\.title)).toNot(contain("Other"))
            }

            it("splits the groups into columns of about the same height, keeping their order") {
                let groups = [3, 1, 1, 4, 2].enumerated().map { index, count in
                    ShortcutSheet.Group(title: "\(index)", entries: Array(repeating: ShortcutSheet.Entry(name: "", shortcut: ""), count: count))
                }

                let columns = ShortcutSheet.columns(of: groups, count: 3)
                expect(columns.map { $0.map(\.title) }).to(equal([["0", "1"], ["2", "3"], ["4"]]))
            }
        }
    }
}
