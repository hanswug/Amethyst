//
//  CommandPalette.swift
//  Amethyst
//

import Cocoa
import Foundation

/// One command in the palette: its display name, its command key, and its current shortcut, if bound.
struct CommandPaletteEntry: Equatable {
    let name: String
    let commandKey: String
    let shortcut: String?
}

enum CommandPalette {
    /// The commands to list, in the order of `namesAndKeys` (`[name, command key]` pairs): only registered ones, never the palette itself.
    static func entries(from namesAndKeys: [[String]], registered: Set<String>, shortcut: (String) -> String?) -> [CommandPaletteEntry] {
        return namesAndKeys.compactMap { nameAndKey -> CommandPaletteEntry? in
            guard nameAndKey.count == 2 else {
                return nil
            }

            let (name, commandKey) = (nameAndKey[0], nameAndKey[1])
            guard commandKey != CommandKey.showCommandPalette.rawValue, registered.contains(commandKey) else {
                return nil
            }

            return CommandPaletteEntry(name: name, commandKey: commandKey, shortcut: shortcut(commandKey))
        }
    }

    /// The select-layout commands to leave out: selecting a layout only works for layouts in the configuration's `layouts`.
    static func unconfiguredLayoutCommands(availableLayoutKeys: [String], configuredLayoutKeys: [String]) -> Set<String> {
        let configured = Set(configuredLayoutKeys)
        return Set(availableLayoutKeys.filter { !configured.contains($0) }.map(UserConfiguration.constructLayoutKeyString))
    }

    /// Adds a note such as a current value to the names of the entries that have one, by command key: `Increase main pane count (now 2)`.
    static func annotating(_ entries: [CommandPaletteEntry], notes: [String: String]) -> [CommandPaletteEntry] {
        return entries.map { entry in
            guard let note = notes[entry.commandKey] else {
                return entry
            }

            return CommandPaletteEntry(name: "\(entry.name) (\(note))", commandKey: entry.commandKey, shortcut: entry.shortcut)
        }
    }

    /// The entries matching every word of the query in their name or command key, ignoring case. An empty query matches everything.
    static func filter(_ entries: [CommandPaletteEntry], query: String) -> [CommandPaletteEntry] {
        let words = query.lowercased().split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else {
            return entries
        }

        return entries.filter { entry in
            let haystack = "\(entry.name) \(entry.commandKey)".lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
    }
}

/// A panel that takes keyboard input without activating the app, the way Spotlight does, so the app you were in stays in front.
private class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

/// Keeps the selection highlighted in the accent colour while typing goes to the search field.
private class CommandPaletteRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { return true }
        set {}
    }
}

private class CommandPaletteCellView: NSTableCellView {
    let nameLabel = NSTextField(labelWithString: "")
    let shortcutLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        nameLabel.font = NSFont.systemFont(ofSize: 14)
        nameLabel.lineBreakMode = .byTruncatingTail
        shortcutLabel.font = NSFont.systemFont(ofSize: 13)
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.alignment = .right

        for label in [nameLabel, shortcutLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        textField = nameLabel
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        shortcutLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 12),
            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// The command palette: type to filter, ↑/↓ to select, Enter runs, Esc or a click elsewhere closes.
class CommandPaletteController: NSObject {
    private static let cellIdentifier = NSUserInterfaceItemIdentifier("CommandPaletteCell")

    private let run: (String) -> Void
    private let panel = CommandPalettePanel(
        contentRect: NSRect(x: 0, y: 0, width: 600, height: 380),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )
    private let searchField = NSTextField()
    private let tableView = NSTableView()

    private var entries: [CommandPaletteEntry] = []
    private var matches: [CommandPaletteEntry] = []

    var isVisible: Bool {
        return panel.isVisible
    }

    /// `run` gets the command key of the command picked, after the palette has closed.
    init(run: @escaping (String) -> Void) {
        self.run = run
        super.init()
        setUpPanel()
    }

    func show(entries: [CommandPaletteEntry]) {
        self.entries = entries
        searchField.stringValue = ""
        updateMatches()

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func close() {
        panel.orderOut(nil)
    }

    private func setUpPanel() {
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.blendingMode = .behindWindow
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        panel.contentView = background

        searchField.placeholderString = "Run a command"
        searchField.font = NSFont.systemFont(ofSize: 22)
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.cell?.usesSingleLineMode = true
        searchField.delegate = self

        let separator = NSBox()
        separator.boxType = .separator

        let column = NSTableColumn(identifier: CommandPaletteController.cellIdentifier)
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.backgroundColor = .clear
        tableView.refusesFirstResponder = true
        tableView.style = .inset
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(runClickedRow)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        for view in [searchField, separator, scrollView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(view)
        }

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            searchField.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            searchField.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -6)
        ])
    }

    private func updateMatches() {
        matches = CommandPalette.filter(entries, query: searchField.stringValue)
        tableView.reloadData()
        select(row: 0)
    }

    private func select(row: Int) {
        guard !matches.isEmpty else {
            return
        }

        let row = min(max(row, 0), matches.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func runCommand(at row: Int) {
        guard matches.indices.contains(row) else {
            return
        }

        let commandKey = matches[row].commandKey
        close()
        run(commandKey)
    }

    @objc private func runClickedRow() {
        runCommand(at: tableView.clickedRow)
    }
}

extension CommandPaletteController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

extension CommandPaletteController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateMatches()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            select(row: tableView.selectedRow - 1)
        case #selector(NSResponder.moveDown(_:)):
            select(row: tableView.selectedRow + 1)
        case #selector(NSResponder.insertNewline(_:)):
            runCommand(at: tableView.selectedRow)
        case #selector(NSResponder.cancelOperation(_:)):
            close()
        default:
            return false
        }
        return true
    }
}

extension CommandPaletteController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return matches.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return CommandPaletteRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: CommandPaletteController.cellIdentifier, owner: self) as? CommandPaletteCellView
            ?? CommandPaletteCellView(frame: .zero)
        cell.identifier = CommandPaletteController.cellIdentifier

        let entry = matches[row]
        cell.nameLabel.stringValue = entry.name
        cell.shortcutLabel.stringValue = entry.shortcut ?? ""
        return cell
    }
}
