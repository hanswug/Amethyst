# Ametrine

A personal tiling window manager for macOS, built on [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel.

It was born out of the need to handle many windows on large displays, such as a 4K 55" screen or an ultrawide, and to stay simple on the go: on a laptop's built-in display, a full-screen stack or two panes side by side is all it takes.

- **Move by direction.** ⌃⌥ + h/j/k/l focuses the window to the west, south, north or east; add ⌘ and the window swaps there. No clockwise order to remember, no Alt-Tab to reach the window next to you. Warp moves a window into the pane next to it, by key or by Shift-drag.
- **Keyboard first.** Every command can have a key, and the command palette lists them all with their shortcuts while you build the muscle memory.
- **No hidden state.** A window is either visible or deliberately gone; nothing is parked where you have to remember it.
- **One display and one Space at a time.** Each Space and each display is tiled on its own, so using several still works, but there are no commands to move windows between them. Dedicated apps (Raycast, for example) do that well, and moving a window to another Space needs simulated mouse drags because macOS has no public API for it.

**There are no public releases.** Builds are signed with a self-signed certificate, not notarised (that needs a paid Apple Developer ID). I keep them as draft releases, visible only to me, to install Ametrine on my other Macs without building there. You can build it yourself (see [Build and install](#build-and-install)) or take any of the ideas for your own setup.

## What it does

- **Tiles windows per Space**, using the layouts listed in the config. Daily set: Fullscreen, Two Pane A, 3Column Left, 3Column Middle, Tall Left.
- **Fullscreen toggle:** `toggle-fullscreen` switches a Space between its layout and Fullscreen with the focused window in front, and back with every window in its tile.
- **The config file is the only source of settings and keys.**
  - It's read from `~/.config/ametrine/ametrine.yml` (or `~/.ametrine.yml`, or `~/.ametrine`).
  - There's no preferences window: the menu has **Edit Config…** (opens the file) and **Reload Config** (relaunches).
  - There are no built-in key bindings. A command is bound only if the file binds it; leaving it out, or setting it to `false` or `<NONE>`, leaves it unbound.
  - A missing or broken config file shows an alert with the path and quits.
- **Directional focus and swap:** `focus-west/east/north/south` and `swap-west/east/north/south` reach the visible tiled window in that direction. Ties go to the window you used last, so east, west, east comes back to the same window. At the screen edge nothing happens. In Fullscreen, west/east cycle through the windows. See [docs/directional-navigation.md](docs/directional-navigation.md).
- **Warp:** `warp-west/east/north/south` moves the focused window into the pane in that direction, and `warp-main` into main from anywhere, so columns grow and shrink (3Column 1/2/2 → 1/3/1). A warp never empties a pane, and a window warped into main lands at `main-arrival-position`. The main pane count is a maximum: `increase-main` moves nothing, warping into a full main or out of main moves it by one, and the HUD shows "x of y". With `mouse-warps-windows`, holding Shift as you drop a dragged window warps it into the pane under the cursor instead of swapping. See [warp](docs/directional-navigation.md#warp).
- **Command palette** (`show-command-palette`, Super+Y here): lists every command with its shortcut, plus current values such as the window max count and main pane count. Type to filter, ↑/↓ to select, Enter runs, Esc closes. Works like Spotlight: the app you're in stays in front.
- **Command URL:** `open -g "ametrine://command/<command-key>"` runs any command, bound or not, from scripts or launchers. Unknown keys are ignored.
- **Padding modes:** named virtual monitors on a large display, e.g. `full`, `wide` (21:9) and `27` (a centred 27"), anchored to the bottom edge. Switch with `cycle-padding-mode` or `select-<name>-padding-mode`, or from the Padding menu. The change applies instantly to the current Space; each Space keeps its own mode, which survives restarts. The built-in display stays unpadded.
- **Floating secondary windows:** for apps in `floating-secondary-windows`, the first window on a Space tiles. That app's other windows (Settings, dialogs, Open panels) float, with no title rules.
- **Keeps up with app switches:** every switch to another app re-lays out the screen, also for apps that don't announce it through Accessibility. Quitting an app frees all its tiles.
- **Focus border** (`focus-border: true`): a ring just outside the focused window, never over it. `glow` (default) is a thin ring with a soft halo like the macOS focus ring, in the system accent colour; `solid` and `gradient` (purple to gold) are the alternatives. It follows each window's own corners and keeps up with drags and resizes, like JankyBorders. Width, colour and a fallback corner radius are in the config. No border on tiled windows in the Fullscreen layout or in native full screen. `toggle-focus-border` and `cycle-focus-border-style` switch it until Reload Config.
- **Feedback:** the current layout's name next to the menu bar icon, and a short on-screen message (HUD) when the layout, padding mode, window max count or main pane count changes.
- **Not included:** auto-updates and default key bindings; moving windows between displays or Spaces (see above).

## Status

- [x] Fork setup: own name and bundle ID (`com.ark.Ametrine`), own config file, no auto-updates, local signing
- [x] Padding modes, per Space since 4.3.0
- [x] Floating secondary windows
- [x] Command URL
- [x] Config file only: no preferences window, no built-in keys, layout name in the menu bar
- [x] Command palette, with current counts and count HUDs
- [x] BSP fixes (see [BSP](docs/layouts.md#bsp))
- [x] Renamed from hw-Amethyst to Ametrine (3.0.0), with a purple-to-gold icon
- [x] Directional focus and swap (3.1.0): `focus-west/east/north/south`, `swap-west/east/north/south` (only visible windows; Fullscreen cycles west/east). See [docs/directional-navigation.md](docs/directional-navigation.md)
- [x] Warp (4.2.0): `warp-<direction>` and `warp-main` move a window into the neighbouring pane, or into main, in every tiled layout (swaps in Two Pane, Column and Row; splits the neighbour's tile in BSP), into an empty column too; pane sizes are remembered and the main pane count is a maximum
- [x] Custom (JavaScript) layouts removed (6.0.0): they gave little beyond the built-in layouts, needed code, and skipped warp, remembered pane sizes and flip
- [x] Flip: `flip-twin` shows the layout's mirror image (its twin, or 3Column Middle's side columns swapped), `flip-rows` and `flip-columns` reverse the order inside panes; see [flip](docs/layouts.md#flip)
  - [x] Step 1 (5.0.0): every layout named by where main is (`tall-left`, `wide-top`, `two-pane-a`, `3column-middle`, `column-left`, `row-top`, …), the missing twins Wide Bottom, Column Right and Row Bottom, and `layout-names` for your own names
  - [x] Twins (6.2.0): every twin is its layout's exact mirror image (Tall Right, 3Column Right and Widescreen Tall Right fixed), and a layout and its twin share main count, ratio and pane sizes
- [x] Focus border: a soft glow (or a solid or gradient ring) around the focused window, in the accent colour or your own; `toggle-focus-border`, `cycle-focus-border-style`; hidden in Fullscreen
- [ ] A Raycast extension built on the command URL
- [ ] Backlog:
  - [x] `window-overflow: minimize | float`: what happens to a window over `window-max-count`. `float` floats the newest window, centred at 60% × 70% of the screen (or `window-overflow-width/height`), and leaves the tiles alone; both toggle from the palette
  - [ ] `max-column-rows: 3` for side columns, and its twin `max-row-columns` for panes split into columns (Wide Top/Bottom, Widescreen Tall's main)
  - [x] Warp with the mouse: hold Shift as you drop a dragged window to warp it instead of swapping (6.1.0, `mouse-warps-windows`); a drop or resize the layout doesn't take, or a move by another app (6.1.1), snaps the window back to its tile (`snap-back-windows`, `toggle-snap-back-windows`)
  - [x] Upstream leftovers removed (4.3.1): fastlane, CI and community files, unused images, and the unused Sparkle, Cartography and MASShortcut libraries
  - [ ] Clean config file: reads like a complete settings file in logical sections, every setting and command listed, so binding something needs no trip to the docs
  - [x] `toggle-fullscreen` (5.1.0): a Space's layout ↔ Fullscreen, the focused window in front without becoming main, and back with every window in its tile
  - [x] Two Pane: focus north/south browses the windows waiting behind the secondary pane (5.0.0)
  - [x] `layout-names` (5.0.0): the name shown for each layout
  - [x] `main-arrival-position: first | last` (was `new-windows-to-main: true | false`): whether a new window goes on top of main or at the end; `toggle-main-arrival-position` switches it from the palette
  - [x] Fix the `debug windows` crash (Finder lists the desktop as a window)
  - [x] Explain this window (`explain-window`): a HUD that says whether the focused window is tiled, floating or not managed, and why. `--log` writes to `~/Library/Logs/Ametrine/Ametrine.log`
  - [x] Set window max count and main pane count from the palette: pick the command, type a number (`0` = unlimited for the window count), Enter. Also `ametrine://command/set-window-max-count?value=<n>`
  - [x] A HUD when an app refuses its tile (its window stays bigger than the tile), once per window and tile size; `enables-refused-tile-hud`
  - [x] Version numbers: semantic versioning for Ametrine itself, matching the release names (see [Versions](#versions))

## Configuration

A short example of the Ametrine-specific keys:

```yaml
mod1: [option, control]                     # everyday commands
mod2: [option, control, command]            # transformations
mod4: [option, control, shift, command]     # "Super"

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
enables-window-count-hud: true

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

[ametrine.sample.yml](ametrine.sample.yml) is a complete, real config. Every setting and command is described in [docs/configuration-files.md](docs/configuration-files.md).

## Layouts

How layouts work, main first, with a diagram of each: [docs/layouts.md](docs/layouts.md).

| Layout | Key | What it does |
|---|---|---|
| Tall Left / Right | `tall-left`, `tall-right` | Main pane on the left (or right), the rest stacked in rows beside it |
| Wide Top / Bottom | `wide-top`, `wide-bottom` | Main pane on top (or at the bottom), the rest in columns beside it |
| Two Pane A / B | `two-pane-a`, `two-pane-b` | Main pane plus one visible secondary pane; every other window waits behind it; focus north/south browses them. A puts main first (left, or top on a portrait screen), B second (right, or bottom) |
| 3Column Left / Middle / Right | `3column-left`, `3column-middle`, `3column-right` | Main pane plus two side columns, shared out as evenly as possible |
| 4Column Left / Right | `4column-left`, `4column-right` | Main pane plus three side columns |
| Widescreen Tall Left / Right | `widescreen-tall-left`, `widescreen-tall-right` | Tall Left (or Right), but several main windows split into columns |
| Fullscreen | `fullscreen` | The focused window fills the screen |
| Column Left / Right | `column-left`, `column-right` | One column per window, the first on the left (or right) |
| Row Top / Bottom | `row-top`, `row-bottom` | One row per window, the first on top (or at the bottom) |
| Floating | `floating` | Nothing is tiled |
| Binary Space Partitioning | `bsp` | Each new window splits the focused pane along its longer side |

Each name says where main is. The pairs are twins: the same layout mirrored, every window on its mirror spot, sharing main count, ratio and pane sizes, so switching to the twin by select or cycle shows the same arrangement on the other side. `flip-twin` switches between them, whether or not the twin is in your `layouts`. `layout-names` gives each layout the name you see, e.g. `tall-left: "Coding"`; without one, a layout shows its key.

**A word of advice:** I strongly suggest not using all the available layouts. Bind only the ones you are really going to use, learn their behaviour thoroughly, and have fun!

## Build and install

1. **One time per Mac:** in Keychain Access, create a self-signed certificate (Certificate Assistant → Create a Certificate…, type **Code Signing**) named `Amethyst Local Signing`, and set it to Always Trust for code signing. The Accessibility permission sticks to this identity across rebuilds.
2. `scripts/build.sh` builds the Release app, installs `/Applications/Ametrine.app` and launches it. Grant it Accessibility on first launch.
3. `scripts/release.sh major|minor|patch` bumps the version, runs the tests, builds and installs as above, commits and pushes the bump, and saves that build as a draft GitHub release `v<version>` (a signed zip, visible only to the repository owner). `current` releases the version as it stands; `--dry-run` shows what would happen.
4. Before merging a change to window tracking, focus or floating, run the [manual tests](docs/manual-tests.md): the cases unit tests can't reach.
5. `scripts/test.sh` runs the unit tests against a clean, empty config. `scripts/profile.sh` records a Time Profiler trace when something feels slow (see [docs/PROFILING.md](docs/PROFILING.md)).

Upstream Amethyst can stay installed as a fallback with its own config, but never run both at once.

## Versions

Ametrine uses [semantic versioning](https://semver.org), with the config file as its interface: a change that needs edits to an existing config is a major version, a new feature a minor one, a fix a patch. Releases are named `v<version>`; the build number (in parentheses in the menu) is the commit count.

Numbering started at 2.4.0 and was counted back to the fork's first build:

| Version | What |
| ------- | ---- |
| 1.0.0 | hw-Amethyst: its own name, bundle ID and config file, self-signed, no auto-update |
| 1.1.0 | Padding modes |
| 1.2.0 | Float secondary windows |
| 1.3.0 | Command URL |
| 2.0.0 | Config only: no preferences window, no built-in keys, quits without a config file |
| 2.1.0 | Command palette; screen and throw-to-space commands dropped |
| 2.1.1 | BSP fixes; re-layout on every app switch |
| 2.2.0 | Explain this window; `--log` writes a file |
| 2.3.0 | Set window max count and main pane count |
| 2.4.0 | Refused-tile HUD |
| 3.0.0 | Renamed from hw-Amethyst to Ametrine, with a new icon: the app, bundle ID `com.ark.Ametrine`, config `~/.config/ametrine/ametrine.yml` (move the old `~/.config/hw-amethyst/amethyst.yml` there), `ametrine://` command URL, log `~/Library/Logs/Ametrine/`; `relaunch-amethyst` is now `relaunch-ametrine` |
| 3.1.0 | Directional focus and swap: `focus-west/east/north/south`, `swap-west/east/north/south` |
| 3.2.0 | Focus border: `focus-border` with `glow`, `solid` or `gradient` styles; `toggle-focus-border`, `cycle-focus-border-style` |
| 3.2.1 | A relaunch (Reload Config, an update) keeps each Space's layout and the window order, so the main pane keeps its window |
| 3.2.2 | `swap-main` from the main window swaps back after a relaunch; the focus border stays on top after a click inside its window |
| 3.2.3 | Fewer accessibility calls: windows already in place aren't set again, and an app switch lays out once; the main pane stays within 5–95% of the screen |
| 4.0.0 | `new-windows-to-main: true \| false` is now `main-arrival-position: first \| last` (rename it in your config); `toggle-main-arrival-position`. The focus border is rebuilt: it follows each window's own corners and keeps up with drags and resizes, and the palette shows its state and style. `--log` traces each layout pass |
| 4.1.0 | Main shrinks when one of its windows leaves view (closed, quit, hidden, minimised, another Space, floated), and a window coming back arrives at `main-arrival-position`; the focus border catches a window moved right after it was focused |
| 4.2.0 | Warp: `warp-west/east/north/south` moves a window into the pane in that direction (3Column 1/2/2 → 1/3/1), into an empty column too, and `warp-main` into main from anywhere; swaps where a pane would empty or holds one window; splits the neighbour's tile in BSP. Pane sizes are remembered per layout and survive a relaunch. The main pane count is a maximum: `increase-main` moves nothing, warps in and out move it by one, and the HUD shows "x of y" |
| 4.3.0 | Padding modes per Space: each Space keeps the mode picked on it, also across restarts, and starts on `padding-mode` until one is picked; the padding commands and the Padding menu act on the current Space. `--log` logs how long each Space change takes |
| 4.3.1 | Upstream leftovers removed: fastlane, CI and community files, unused images, and the unused Sparkle, Cartography and MASShortcut libraries (the app shrinks from 32 to 28 MB). No visible change |
| 5.0.0 | Layouts named by where main is: `tall-left`, `wide-top`, `two-pane-a`/`-b`, `3column-middle`, `widescreen-tall-left`, `column-left`, `row-top` (**config edit**: rename the keys in `layouts:` and `select-<key>-layout`). New twins Wide Bottom, Column Right and Row Bottom; Two Pane B is A mirrored along the long side. `layout-names` sets the name shown for each layout (without one, its key). In Two Pane, focus north/south browses the windows behind the secondary pane |
| 5.1.0 | `toggle-fullscreen`: a Space's layout ↔ Fullscreen in place, the focused window in front without becoming main, and back with every window in its tile (works without `fullscreen` in `layouts`). Selecting the current layout again goes back to the previous one per Space |
| 6.0.0 | Custom (JavaScript) layouts removed, with `command1`–`command4` (**config**: drop them and any custom layout key from `layouts`). BSP no longer logs a decode error on launch for a Space without windows |
| 6.1.0 | Warp with the mouse: hold Shift as you drop a dragged window to warp it into the pane under the cursor (`mouse-warps-windows`; BSP takes the half dropped on). `snap-back-windows` (default on) puts a window back on its tile after a drag or resize the layout doesn't take; `toggle-snap-back-windows`. Resizes from a layout pass during a drag no longer count as yours |
| 6.1.1 | `snap-back-windows` also puts back windows moved or resized by other apps (Raycast, scripts), leaving show desktop, native full screen and apps adjusting their own size alone. Fix: a window dropped on its own tile (in Fullscreen, anywhere) now snaps back instead of staying put or swapping with a hidden window |
| 6.2.0 | Twins are exact mirrors: Tall Right's stack now fills from the top, 3Column Right's first side column is next to main, and Widescreen Tall Right's first main window is at the right edge. A layout and its twin share main count, ratio and pane sizes, so switching between them mirrors the arrangement. 3Column and 4Column columns fill the screen exactly (they could run 1–2 px past the edge) |
| 6.3.0 | Flip: `flip-twin` shows the layout's mirror image (its twin with main count, ratio and pane sizes, or 3Column Middle's side columns swapped), also when the twin isn't in `layouts` (the entry becomes the twin in place and survives a restart); `flip-rows` and `flip-columns` reverse the order inside panes, and mirror BSP along that axis. The Layouts menu lists `layouts` as written |

## Credits and licence

Based on [Amethyst](https://github.com/ianyh/Amethyst) by Ian Ynda-Hummel and its contributors. MIT licence, see [LICENSE.md](LICENSE.md).
