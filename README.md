# hw-Amethyst

A personal tiling window manager for macOS, built on [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel.

It was born out of the need to handle many windows on large displays, such as a 4K 55" screen or an ultrawide.

- **Keyboard first.** Every command can have a key, and the command palette lists them all with their shortcuts while you build the muscle memory. Directional focus, swap and warp are planned.
- **No hidden state.** A window is either visible or deliberately gone; nothing is parked where you have to remember it.
- **One display and one Space at a time.** Each Space and each display is tiled on its own, so using several still works, but there are no commands to move windows between them. Dedicated apps (Raycast, for example) do that well, and moving a window to another Space needs simulated mouse drags because macOS has no public API for it.

**There are no public releases.** Builds are signed with a self-signed certificate, not notarised (that needs a paid Apple Developer ID). I keep them as draft releases, visible only to me, to install hw-Amethyst on my other Macs without building there. You can build it yourself (see [Build and install](#build-and-install)) or take any of the ideas for your own setup.

## What it does

- **Tiles windows per Space**, using the layouts listed in the config. Daily set: Fullscreen, Two Pane, 3Column Left, 3Column Middle, Tall.
- **The config file is the only source of settings and keys.**
  - It's read from `~/.config/hw-amethyst/amethyst.yml` (or `~/.hw-amethyst.yml`, or `~/.hw-amethyst`).
  - There's no preferences window: the menu has **Edit Config…** (opens the file) and **Reload Config** (relaunches).
  - There are no built-in key bindings. A command is bound only if the file binds it; leaving it out, or setting it to `false` or `<NONE>`, leaves it unbound.
  - A missing or broken config file shows an alert with the path and quits.
- **Command palette** (`show-command-palette`, Super+Y here): lists every command with its shortcut, plus current values such as the window max count and main pane count. Type to filter, ↑/↓ to select, Enter runs, Esc closes. Works like Spotlight: the app you're in stays in front.
- **Command URL:** `open -g "amethyst://command/<command-key>"` runs any command, bound or not, from scripts or launchers. Unknown keys are ignored.
- **Padding modes:** named virtual monitors on a large display, e.g. `full`, `wide` (21:9) and `27` (a centred 27"), anchored to the bottom edge. Switch with `cycle-padding-mode` or `select-<name>-padding-mode`, or from the Padding menu. The change applies instantly, and the last mode survives restarts. The built-in display stays unpadded.
- **Floating secondary windows:** for apps in `floating-secondary-windows`, the first window on a Space tiles. That app's other windows (Settings, dialogs, Open panels) float, with no title rules.
- **Keeps up with app switches:** every switch to another app re-lays out the screen, also for apps that don't announce it through Accessibility. Quitting an app frees all its tiles.
- **Feedback:** the current layout's name next to the menu bar icon, and a short on-screen message (HUD) when the layout, padding mode, window max count or main pane count changes.
- **Not included:** auto-updates and default key bindings; moving windows between displays or Spaces (see above).

## Status

- [x] Fork setup: own name and bundle ID (`com.ark.Amethyst`), own config file, no auto-updates, local signing
- [x] Padding modes
- [x] Floating secondary windows
- [x] Command URL
- [x] Config file only: no preferences window, no built-in keys, layout name in the menu bar
- [x] Command palette, with current counts and count HUDs
- [x] BSP fixes (see [Layouts](#bsp-in-hw-amethyst))
- [ ] Directional focus and swap: `focus-west/east/north/south`, `swap-west/east/north/south` (only visible windows; Fullscreen cycles west/east)
- [ ] Warp: `warp-<direction>` moves a window into the neighbouring column (3Column, Tall, Two Pane)
- [ ] Flip: `flip-left-right` and `flip-top-bottom`. One switches to the layout's twin (Tall Left ↔ Tall Right, …), the other reverses the rows or columns; the main pane is kept
- [ ] A Raycast extension built on the command URL
- [ ] Backlog:
  - [ ] `window-overflow: minimize | float`: what happens to a window over `window-max-count` (or, later, over a full side column). `float` floats the new window and leaves the tiles alone
  - [ ] `max-column-rows: 3` for side columns
  - [ ] Fix the `debug windows` crash
  - [x] Explain this window (`explain-window`): a HUD that says whether the focused window is tiled, floating or not managed, and why. `--log` writes to `~/Library/Logs/hw-Amethyst/hw-Amethyst.log`
  - [x] Set window max count and main pane count from the palette: pick the command, type a number (`0` = unlimited for the window count), Enter. Also `amethyst://command/set-window-max-count?value=<n>`
  - [x] A HUD when an app refuses its tile (its window stays bigger than the tile), once per window and tile size; `enables-refused-tile-hud`
  - [ ] Version numbers: semantic versioning for hw-Amethyst itself, matching the release names (the app still reports upstream's 0.24.3)

## Configuration

A short example of the hw-Amethyst-specific keys:

```yaml
mod1: [option, control]                     # everyday commands
mod2: [option, control, command]            # transformations
mod4: [option, control, shift, command]     # "Super"

layouts: [fullscreen, two-pane, 3column-left, middle-wide, tall]

show-command-palette: {mod: mod4, key: y}

padding-modes:
  - name: full
  - name: wide
    top: 540
  - name: "27"            # quoted: a bare 27 is a number in YAML
    left: 640
    right: 640
    top: 720
padding-mode: wide        # used only until a mode has been selected
cycle-padding-mode: {mod: mod4, key: "0"}

floating-secondary-windows: [md.obsidian]

window-max-count: 8
enables-window-count-hud: true

focus-cw: false           # unbound, same as leaving it out or <NONE>
```

[hw-amethyst.sample.yml](hw-amethyst.sample.yml) is a complete, real config. Every setting and command is described in [docs/configuration-files.md](docs/configuration-files.md).

## Layouts

| Layout | Key | What it does |
|---|---|---|
| Tall | `tall` | Main pane on the left, the rest stacked in rows on the right |
| Tall Right | `tall-right` | Tall, with the main pane on the right |
| Wide | `wide` | Main pane on top, the rest in columns below |
| Two Pane | `two-pane` | Main pane plus one visible secondary pane; the other windows wait behind it |
| Two Pane Right | `two-pane-right` | Two Pane, with the main pane on the right |
| 3Column Left / Middle / Right | `3column-left`, `middle-wide`, `3column-right` | Main pane plus two side columns, shared out as evenly as possible |
| 4Column Left / Right | `4column-left`, `4column-right` | Main pane plus three side columns |
| Widescreen Tall / Tall Right | `widescreen-tall`, `widescreen-tall-right` | Tall (or Tall Right), but several main windows split into columns |
| Fullscreen | `fullscreen` | The focused window fills the screen |
| Column / Row | `column`, `row` | One column (or row) per window |
| Floating | `floating` | Nothing is tiled |
| Binary Space Partitioning | `bsp` | Each new window splits the focused pane along its longer side |
| Custom | file name | JavaScript layouts in `~/Library/Application Support/Amethyst/Layouts/*.js`; see [docs/custom-layouts.md](docs/custom-layouts.md) |

### BSP in hw-Amethyst

Binary Space Partitioning keeps a tree of windows: a new window splits the focused one in half, and a closed window's space goes to the window it was split from. Sizes follow the order windows were opened in; nothing rebalances. hw-Amethyst fixes a few ways it strayed from that design:

- **The tree follows the windows actually on screen.** Hidden, closed or moved windows no longer leave an empty tile, and a window the tree missed still gets one. A hidden app's windows come back at the focused window, not at their old spot.
- **A new window splits the window you last focused**, also when you got there by clicking into another app.
- **Closing one of the first windows no longer reshuffles the layout:** the windows next to it take over its space.
- **Quitting an app frees all its tiles**, including windows opened after hw-Amethyst started. This applies to every layout.

Layouts in the config are cycled with `cycle-layout` / `cycle-layout-backward` or selected with `select-<key>-layout`. Commands that change the main pane (`shrink-main`, `expand-main`, `increase-main`, `decrease-main`) work in layouts that have one.

## Build and install

1. **One time per Mac:** in Keychain Access, create a self-signed certificate (Certificate Assistant → Create a Certificate…, type **Code Signing**) named `Amethyst Local Signing`, and set it to Always Trust for code signing. The Accessibility permission sticks to this identity across rebuilds.
2. `scripts/build.sh` builds the Release app, installs `/Applications/hw-Amethyst.app` and launches it. Grant it Accessibility on first launch.
3. `scripts/release.sh` runs the tests, builds and installs as above, and saves that build as a draft GitHub release (a signed zip, visible only to the repository owner).
4. Before merging a change to window tracking, focus or floating, run the [manual tests](docs/manual-tests.md): the cases unit tests can't reach.
5. `scripts/test.sh` runs the unit tests against a clean, empty config. `scripts/profile.sh` records a Time Profiler trace when something feels slow (see [docs/PROFILING.md](docs/PROFILING.md)).

Don't use the fastlane lane: it signs for a Developer ID team this fork doesn't have. Upstream Amethyst can stay installed as a fallback with its own config, but never run both at once.

## Credits and licence

Based on [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel and its contributors. MIT licence, see [LICENSE.md](LICENSE.md).
