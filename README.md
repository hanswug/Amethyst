# Ametrine

A tiling window manager for macOS, built on [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel, and designed around the **main pane**: the window you're working in gets the big tile, and everything else lines up beside it.

It was born out of the need to handle many windows on large displays, such as a 4K 55" screen or an ultrawide, and to stay simple on the go: on a laptop's built-in display, a full-screen stack or two panes side by side is all it takes.

> **There are no public releases.** Builds are signed with a self-signed certificate, not notarised (that needs a paid Apple Developer ID). You can [build it yourself](#getting-started) in a few minutes, or take any of the ideas for your own setup.

## Highlights

- **Layouts built around main.** Tall, Wide, Two Pane, 3Column, 4Column, Widescreen Tall, Column, Row, Fullscreen, Floating and BSP, each named by where main is, and each with a mirror-image twin. → [Layouts](docs/layouts.md)
- **Move by direction.** h/j/k/l with one modifier focuses the window to the west, south, north or east; with another the window warps or swaps there. → [Directional focus, swap and warp](docs/directional-navigation.md)
- **Flip.** Mirror the layout, or reverse the rows or columns, to bring the windows at the far end closer. → [Flip](docs/layouts.md#flip)
- **Padding modes.** Virtual monitors on a big display, such as a centred 27" or a 21:9 strip, picked per Space. → [Padding modes](docs/features.md#padding-modes)
- **Command palette and URL.** Every command, searchable, with its key; and `ametrine://command/<key>` for scripts and launchers. → [Palette](docs/features.md#command-palette)
- **Calm windows.** Settings and dialogs float on their own, a window limit keeps the tiles readable, and windows snap back to their tiles. → [Features](docs/features.md)
- **Focus border.** A soft glow around the focused window that follows its corners. → [Focus border](docs/features.md#focus-border)
- **One config file.** No preferences window and no built-in keys: the file binds what you use. → [Configuration](docs/configuration-files.md)

## Design principles

- **Main first.** The window you work in is the centre of every layout; the others are there to be brought in.
- **By direction, not by order.** You reach the window next to you, not the next one in a list. No clockwise order to remember, no Alt-Tab.
- **Keyboard first.** Every command can have a key, and the palette shows them all while you build the muscle memory.
- **No hidden state.** A window is either visible or deliberately gone; nothing is parked where you have to remember it.
- **One display and one Space at a time.** Each is tiled on its own. There are no commands to move windows between them: dedicated apps do that well, and macOS has no public API for moving a window to another Space.

## Getting started

1. **Create a signing certificate (once per Mac).** In Keychain Access, Certificate Assistant → Create a Certificate…, type **Code Signing**, named `Amethyst Local Signing`, and set it to Always Trust for code signing.
2. **Build and install.** With Xcode and SwiftLint (`brew install swiftlint`), run `scripts/build.sh`. It installs `/Applications/Ametrine.app` and launches it. Grant it Accessibility when asked.
3. **Add a config.** Copy [ametrine.sample.yml](ametrine.sample.yml) to `~/.config/ametrine/ametrine.yml` and edit it. The menu's **Edit Config…** opens it and **Reload Config** applies it. Without a config file, Ametrine shows where it looked and quits.
4. **Bind a few keys first:** `show-command-palette`, the `focus-<direction>` keys and `swap-main`. The palette runs everything else until you know what you use.

Working on Ametrine itself: [development](docs/development.md).

## Configuration

A short example of the main settings:

```yaml
mod1: [option, control]                    # everyday: focus
mod2: [option, control, command]           # warp
mod3: [control, command]                   # swap
mod4: [option, control, shift, command]    # "Super"

layouts: [fullscreen, two-pane-a, 3column-left, 3column-middle, tall-left]

show-command-palette: {mod: mod4, key: y}

padding-modes:
  - name: full
  - name: wide
    top: 540
  - name: "27"            # quoted: a bare 27 is a number in YAML
    left: 640
    right: 640
    top: 720
padding-mode: wide        # each Space starts on this until you pick a mode there
cycle-padding-mode: {mod: mod4, key: "0"}

floating-secondary-windows: [md.obsidian]

window-max-count: 8

focus-west:  {mod: mod1, key: h}         # h/j/k/l = direction, modifier = verb
focus-south: {mod: mod1, key: j}
focus-north: {mod: mod1, key: k}
focus-east:  {mod: mod1, key: l}
warp-west:   {mod: mod2, key: h}
warp-south:  {mod: mod2, key: j}
warp-north:  {mod: mod2, key: k}
warp-east:   {mod: mod2, key: l}
swap-west:   {mod: mod3, key: h}
swap-south:  {mod: mod3, key: j}
swap-north:  {mod: mod3, key: k}
swap-east:   {mod: mod3, key: l}

focus-cw: false           # unbound, same as leaving it out or <NONE>
```

[ametrine.sample.yml](ametrine.sample.yml) is a complete, real config: every setting with its options and default, every command, in sections. Every setting and command is described in [configuration-files.md](docs/configuration-files.md).

## Layouts

| Layout | Key | What it does |
|---|---|---|
| Tall Left / Right | `tall-left`, `tall-right` | Main on the left (or right), the rest stacked in rows beside it |
| Wide Top / Bottom | `wide-top`, `wide-bottom` | Main on top (or at the bottom), the rest in columns below (or above) it |
| Two Pane A / B | `two-pane-a`, `two-pane-b` | Main plus one visible secondary pane; every other window waits behind it |
| 3Column Left / Middle / Right | `3column-left`, `3column-middle`, `3column-right` | Main plus two side columns |
| 4Column Left / Right | `4column-left`, `4column-right` | Four equal columns, main next to the centre, for very wide screens |
| Widescreen Tall Left / Right | `widescreen-tall-left`, `widescreen-tall-right` | Tall, but main's windows side by side |
| Column Left / Right | `column-left`, `column-right` | One column per window |
| Row Top / Bottom | `row-top`, `row-bottom` | One row per window |
| Fullscreen | `fullscreen` | Every window fills the screen, the focused one in front |
| Floating | `floating` | Nothing is tiled |
| BSP | `bsp` | Each new window splits the focused one in half |

Each pair is a twin: the same layout mirrored. **A word of advice:** don't use them all. Bind only the ones you are really going to use, learn their behaviour thoroughly, and have fun! How they work, with a diagram of each: [docs/layouts.md](docs/layouts.md).

## Documentation

- [Layouts](docs/layouts.md): how main works, and every layout with diagrams
- [Features](docs/features.md): everything Ametrine does
- [Configuration file](docs/configuration-files.md): every setting and command
- [Directional focus, swap and warp](docs/directional-navigation.md)
- [Window limit](docs/window-limit.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Changelog](CHANGELOG.md)
- [Development](docs/development.md)

## Roadmap

- **Shortcut cheatsheet:** your own keys at a glance from the menu bar, with the h/j/k/l grid.
- **Raycast extension** on top of the command URL.
- **Agent integration (MCP):** tell your AI assistant "set up my coding space".

## Credits and licence

Based on [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel and its contributors. MIT licence, see [LICENSE.md](LICENSE.md).
