//
//  ShortcutSheet.swift
//  Amethyst
//
//  Your own keys at a glance (Hans, 2026-10-17): display only, bound commands only. The direction grid on top
//  (key = direction, modifier = verb), then the other keys grouped like the config's sections.
//

import Cocoa
import Foundation

enum ShortcutSheet {
    struct Entry: Equatable {
        let name: String
        let shortcut: String
    }

    struct Group: Equatable {
        let title: String
        let entries: [Entry]
    }

    /// Focus, warp and swap by direction. A row whose keys share their modifiers shows them once, in `modifiers`, and only
    /// the key in each cell; otherwise each cell has the whole shortcut.
    struct Grid: Equatable {
        struct Row: Equatable {
            let title: String
            let modifiers: String?
            let cells: [String?]
        }

        let columns: [String]
        let rows: [Row]
    }

    struct Sheet: Equatable {
        let grid: Grid?
        let groups: [Group]
        /// Commands without a key (those that take a number never have one, so they don't count).
        let unboundCount: Int
        let paletteShortcut: String?
    }

    static let gridColumns = ["west", "south", "north", "east", "main", "ccw", "cw"]
    static let gridRows: [(title: String, commandKeys: [String?])] = [
        ("focus", ["focus-west", "focus-south", "focus-north", "focus-east", "focus-main", "focus-ccw", "focus-cw"]),
        ("warp", ["warp-west", "warp-south", "warp-north", "warp-east", "warp-main", nil, nil]),
        ("swap", ["swap-west", "swap-south", "swap-north", "swap-east", "swap-main", "swap-ccw", "swap-cw"])
    ]

    /// Stands for every `select-<layout>-layout` / `select-<name>-padding-mode` in a group, in the palette's order.
    static let layoutSelections = "select-*-layout"
    static let paddingSelections = "select-*-padding-mode"

    /// The groups, in the config's order, each command with its short label.
    static let groupTable: [(title: String, commands: [(key: String, label: String)])] = [
        ("Layouts", [
            ("cycle-layout", "Next layout"), ("cycle-layout-backward", "Previous layout"), (layoutSelections, ""),
            ("toggle-fullscreen", "Fullscreen toggle"), ("flip-twin", "Flip to twin"), ("flip-rows", "Flip rows"),
            ("flip-columns", "Flip columns"), ("display-current-layout", "Show layout")
        ]),
        ("Main pane", [
            ("shrink-main", "Shrink main"), ("expand-main", "Expand main"), ("decrease-main", "Fewer in main"),
            ("increase-main", "More in main"), ("toggle-main-arrival-position", "Arrival first/last")
        ]),
        ("Screen space", [
            ("cycle-padding-mode", "Next padding"), ("cycle-padding-mode-backward", "Previous padding"), (paddingSelections, "")
        ]),
        ("Windows", [
            ("toggle-float", "Float / tile"), ("explain-window", "Explain window"), ("reevaluate-windows", "Re-check windows")
        ]),
        ("Window limit", [
            ("increase-window-max-count", "Raise limit"), ("decrease-window-max-count", "Lower limit"),
            ("toggle-window-overflow", "Overflow minimize/float"), ("toggle-window-overflow-size", "Overflow size")
        ]),
        ("Mouse", [
            ("toggle-snap-back-windows", "Snap-back on/off"), ("toggle-focus-follows-mouse", "Focus follows mouse")
        ]),
        ("Focus border", [
            ("toggle-focus-border", "Border on/off"), ("cycle-focus-border-style", "Border style")
        ]),
        ("App", [
            ("show-command-palette", "Command palette"), ("show-shortcuts", "Shortcuts"), ("toggle-tiling", "Tiling on/off"),
            ("enable-tiling", "Tiling on"), ("disable-tiling", "Tiling off"), ("relaunch-ametrine", "Relaunch")
        ])
    ]

    static var gridCommandKeys: Set<String> {
        return Set(gridRows.flatMap { $0.commandKeys.compactMap { $0 } })
    }

    /// What the sheet shows, from the palette's entries (plus the palette's own) and short labels for the select commands.
    static func sheet(entries: [CommandPaletteEntry], labels: [String: String]) -> Sheet {
        var shortcuts: [String: String] = [:]
        for entry in entries {
            if let shortcut = entry.shortcut {
                shortcuts[entry.commandKey] = shortcut
            }
        }

        var shown = gridCommandKeys
        var groups: [Group] = []
        for (title, commands) in groupTable {
            var groupEntries: [Entry] = []
            for (key, label) in commands {
                let selections: [CommandPaletteEntry]
                switch key {
                case layoutSelections:
                    selections = entries.filter { $0.commandKey.hasPrefix("select-") && $0.commandKey.hasSuffix("-layout") }
                case paddingSelections:
                    selections = entries.filter { $0.commandKey.hasPrefix("select-") && $0.commandKey.hasSuffix("-padding-mode") }
                default:
                    shown.insert(key)
                    if let shortcut = shortcuts[key] {
                        groupEntries.append(Entry(name: label, shortcut: shortcut))
                    }
                    continue
                }
                for selection in selections {
                    shown.insert(selection.commandKey)
                    if let shortcut = selection.shortcut {
                        groupEntries.append(Entry(name: labels[selection.commandKey] ?? selection.name, shortcut: shortcut))
                    }
                }
            }
            if !groupEntries.isEmpty {
                groups.append(Group(title: title, entries: groupEntries))
            }
        }

        let other = entries.filter { !shown.contains($0.commandKey) }.compactMap { entry in
            entry.shortcut.map { Entry(name: entry.name, shortcut: $0) }
        }
        if !other.isEmpty {
            groups.append(Group(title: "Other", entries: other))
        }

        return Sheet(
            grid: grid(shortcuts: shortcuts),
            groups: groups,
            unboundCount: entries.filter { $0.shortcut == nil && $0.value == nil }.count,
            paletteShortcut: shortcuts[CommandKey.showCommandPalette.rawValue]
        )
    }

    static func grid(shortcuts: [String: String]) -> Grid? {
        func shortcut(_ commandKey: String?) -> String? {
            guard let commandKey else {
                return nil
            }
            return shortcuts[commandKey]
        }

        let columns: [Int] = gridColumns.indices.filter { column in
            gridRows.contains { shortcut($0.commandKeys[column]) != nil }
        }
        let rows = gridRows.compactMap { title, commandKeys -> Grid.Row? in
            let cells: [String?] = columns.map { shortcut(commandKeys[$0]) }
            let bound: [String] = cells.compactMap { $0 }
            guard !bound.isEmpty else {
                return nil
            }

            let modifiers = Set(bound.map { splitModifiers($0).modifiers })
            guard modifiers.count == 1, let shared = modifiers.first, !shared.isEmpty else {
                return Grid.Row(title: title, modifiers: nil, cells: cells)
            }
            return Grid.Row(title: title, modifiers: shared, cells: cells.map { $0.map { splitModifiers($0).key } })
        }
        guard !rows.isEmpty else {
            return nil
        }
        return Grid(columns: columns.map { gridColumns[$0] }, rows: rows)
    }

    /// `⌃⌥H` → (`⌃⌥`, `H`): the leading modifier glyphs, and the key.
    static func splitModifiers(_ shortcut: String) -> (modifiers: String, key: String) {
        let glyphs: Set<Character> = ["⌃", "⌥", "⇧", "⌘", "🌐"]
        let modifiers = String(shortcut.prefix { glyphs.contains($0) })
        return (modifiers, String(shortcut.dropFirst(modifiers.count)))
    }

    /// Splits the groups into `count` columns of about the same height, keeping their order.
    static func columns(of groups: [Group], count: Int) -> [[Group]] {
        let height: (Group) -> Int = { $0.entries.count + 2 }
        let target = Int((Double(groups.map(height).reduce(0, +)) / Double(max(1, count))).rounded(.up))
        var columns: [[Group]] = [[]]
        var filled = 0
        for group in groups {
            if filled >= target, columns.count < count {
                columns.append([])
                filled = 0
            }
            columns[columns.count - 1].append(group)
            filled += height(group)
        }
        return columns
    }
}

/// A panel that shows without activating the app, like the palette; Esc closes it.
private class ShortcutSheetPanel: NSPanel {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool {
        return true
    }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onClose?()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// The shortcut sheet: display only. Esc, the same command again, or a click elsewhere closes it.
class ShortcutSheetController: NSObject {
    private let panel = ShortcutSheetPanel(
        contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )
    private let background = NSVisualEffectView()

    var isVisible: Bool {
        return panel.isVisible
    }

    override init() {
        super.init()
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.onClose = { [weak self] in self?.close() }

        background.material = .popover
        background.state = .active
        background.blendingMode = .behindWindow
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        panel.contentView = background
    }

    func show(_ sheet: ShortcutSheet.Sheet) {
        background.subviews.forEach { $0.removeFromSuperview() }

        let content = NSStackView(views: contentViews(for: sheet))
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        content.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor)
        ])

        panel.setContentSize(content.fittingSize)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.orderOut(nil)
    }

    private func contentViews(for sheet: ShortcutSheet.Sheet) -> [NSView] {
        var views: [NSView] = [label("Shortcuts", size: 15, weight: .semibold)]
        if let grid = sheet.grid {
            views.append(gridView(grid))
        }
        if !sheet.groups.isEmpty {
            let columns = ShortcutSheet.columns(of: sheet.groups, count: 3).map { groups -> NSView in
                let stack = NSStackView(views: groups.map(groupView))
                stack.orientation = .vertical
                stack.alignment = .leading
                stack.spacing = 14
                return stack
            }
            let row = NSStackView(views: columns)
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 32
            views.append(row)
        }
        if sheet.grid == nil && sheet.groups.isEmpty {
            views.append(label("No keys bound yet. Bind commands in the config file.", size: 13, color: .secondaryLabelColor))
        }
        if sheet.unboundCount > 0 {
            let palette = sheet.paletteShortcut.map { " (\($0))" } ?? ""
            let commands = sheet.unboundCount == 1 ? "1 more command has" : "\(sheet.unboundCount) more commands have"
            views.append(label("\(commands) no key; the command palette\(palette) runs them.", size: 12, color: .secondaryLabelColor))
        }
        return views
    }

    private func gridView(_ grid: ShortcutSheet.Grid) -> NSView {
        let header = [NSGridCell.emptyContentView, NSGridCell.emptyContentView] + grid.columns.map {
            label($0, size: 12, color: .secondaryLabelColor)
        }
        let rows = grid.rows.map { row -> [NSView] in
            let modifiers = label(row.modifiers ?? "", size: 13, color: .secondaryLabelColor)
            return [modifiers, label(row.title, size: 13, weight: .medium)] + row.cells.map { label($0 ?? "", size: 13) }
        }
        let gridView = NSGridView(views: [header] + rows)
        gridView.rowSpacing = 6
        gridView.columnSpacing = 18
        for column in 2 ..< gridView.numberOfColumns {
            gridView.column(at: column).xPlacement = .center
        }
        return gridView
    }

    private func groupView(_ group: ShortcutSheet.Group) -> NSView {
        let rows = group.entries.map { [label($0.name, size: 13), label($0.shortcut, size: 13, color: .secondaryLabelColor)] }
        let gridView = NSGridView(views: rows)
        gridView.rowSpacing = 4
        gridView.columnSpacing = 16
        gridView.column(at: 1).xPlacement = .trailing

        let stack = NSStackView(views: [label(group.title.uppercased(), size: 11, weight: .semibold, color: .secondaryLabelColor), gridView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }
}

extension ShortcutSheetController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
