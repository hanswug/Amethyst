# Changelog

Ametrine uses [semantic versioning](https://semver.org), with the config file as its interface: a change that needs edits to an existing config is a major version, a new feature a minor one, a fix a patch. Releases are named `v<version>`; the build number (in parentheses in the menu) is the commit count. A major version's line says which config edit it needs.

Numbering started at 2.4.0 and was counted back to the fork's first build. Newest first:

| Version | What |
| ------- | ---- |
| 6.4.0 | Shortcut sheet: `show-shortcuts` and **Shortcuts…** in the menu bar show your bound keys at a glance, the focus/warp/swap grid on top (each row's modifiers once) and the rest grouped like the config, with a count of the commands without a key. The sample config is one complete settings file in sections, every setting with its options and default |
| 6.3.0 | Flip: `flip-twin` shows the layout's mirror image (its twin with main count, ratio and pane sizes, or 3Column Middle's side columns swapped), also when the twin isn't in `layouts` (the entry becomes the twin in place and survives a restart); `flip-rows` and `flip-columns` reverse the order inside panes, and mirror BSP along that axis. The Layouts menu lists `layouts` as written |
| 6.2.0 | Twins are exact mirrors: Tall Right's stack now fills from the top, 3Column Right's first side column is next to main, and Widescreen Tall Right's first main window is at the right edge. A layout and its twin share main count, ratio and pane sizes, so switching between them mirrors the arrangement. 3Column and 4Column columns fill the screen exactly (they could run 1–2 px past the edge) |
| 6.1.1 | `snap-back-windows` also puts back windows moved or resized by other apps (Raycast, scripts), leaving show desktop, native full screen and apps adjusting their own size alone. Fix: a window dropped on its own tile (in Fullscreen, anywhere) now snaps back instead of staying put or swapping with a hidden window |
| 6.1.0 | Warp with the mouse: hold Shift as you drop a dragged window to warp it into the pane under the cursor (`mouse-warps-windows`; BSP takes the half dropped on). `snap-back-windows` (default on) puts a window back on its tile after a drag or resize the layout doesn't take; `toggle-snap-back-windows`. Resizes from a layout pass during a drag no longer count as yours |
| 6.0.0 | Custom (JavaScript) layouts removed, with `command1`–`command4` (**config**: drop them and any custom layout key from `layouts`). BSP no longer logs a decode error on launch for a Space without windows |
| 5.1.0 | `toggle-fullscreen`: a Space's layout ↔ Fullscreen in place, the focused window in front without becoming main, and back with every window in its tile (works without `fullscreen` in `layouts`). Selecting the current layout again goes back to the previous one per Space |
| 5.0.0 | Layouts named by where main is: `tall-left`, `wide-top`, `two-pane-a`/`-b`, `3column-middle`, `widescreen-tall-left`, `column-left`, `row-top` (**config edit**: rename the keys in `layouts:` and `select-<key>-layout`). New twins Wide Bottom, Column Right and Row Bottom; Two Pane B is A mirrored along the long side. `layout-names` sets the name shown for each layout (without one, its key). In Two Pane, focus north/south browses the windows behind the secondary pane |
| 4.3.1 | Upstream leftovers removed: fastlane, CI and community files, unused images, and the unused Sparkle, Cartography and MASShortcut libraries (the app shrinks from 32 to 28 MB). No visible change |
| 4.3.0 | Padding modes per Space: each Space keeps the mode picked on it, also across restarts, and starts on `padding-mode` until one is picked; the padding commands and the Padding menu act on the current Space. `--log` logs how long each Space change takes |
| 4.2.0 | Warp: `warp-west/east/north/south` moves a window into the pane in that direction (3Column 1/2/2 → 1/3/1), into an empty column too, and `warp-main` into main from anywhere; swaps where a pane would empty or holds one window; splits the neighbour's tile in BSP. Pane sizes are remembered per layout and survive a relaunch. The main pane count is a maximum: `increase-main` moves nothing, warps in and out move it by one, and the HUD shows "x of y" |
| 4.1.0 | Main shrinks when one of its windows leaves view (closed, quit, hidden, minimised, another Space, floated), and a window coming back arrives at `main-arrival-position`; the focus border catches a window moved right after it was focused |
| 4.0.0 | `new-windows-to-main: true \| false` is now `main-arrival-position: first \| last` (rename it in your config); `toggle-main-arrival-position`. The focus border is rebuilt: it follows each window's own corners and keeps up with drags and resizes, and the palette shows its state and style. `--log` traces each layout pass |
| 3.2.3 | Fewer accessibility calls: windows already in place aren't set again, and an app switch lays out once; the main pane stays within 5–95% of the screen |
| 3.2.2 | `swap-main` from the main window swaps back after a relaunch; the focus border stays on top after a click inside its window |
| 3.2.1 | A relaunch (Reload Config, an update) keeps each Space's layout and the window order, so the main pane keeps its window |
| 3.2.0 | Focus border: `focus-border` with `glow`, `solid` or `gradient` styles; `toggle-focus-border`, `cycle-focus-border-style` |
| 3.1.0 | Directional focus and swap: `focus-west/east/north/south`, `swap-west/east/north/south` |
| 3.0.0 | Renamed from hw-Amethyst to Ametrine, with a new icon: the app, bundle ID `com.ark.Ametrine`, config `~/.config/ametrine/ametrine.yml` (move the old `~/.config/hw-amethyst/amethyst.yml` there), `ametrine://` command URL, log `~/Library/Logs/Ametrine/`; `relaunch-amethyst` is now `relaunch-ametrine` |
| 2.4.0 | Refused-tile HUD |
| 2.3.0 | Set window max count and main pane count |
| 2.2.0 | Explain this window; `--log` writes a file |
| 2.1.1 | BSP fixes; re-layout on every app switch |
| 2.1.0 | Command palette; screen and throw-to-space commands dropped |
| 2.0.0 | Config only: no preferences window, no built-in keys, quits without a config file |
| 1.3.0 | Command URL |
| 1.2.0 | Float secondary windows |
| 1.1.0 | Padding modes |
| 1.0.0 | hw-Amethyst: its own name, bundle ID and config file, self-signed, no auto-update |
