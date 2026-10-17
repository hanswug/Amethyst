# Features

Everything Ametrine does, one section each. Settings and commands are described in full in [configuration-files.md](configuration-files.md); how layouts work, main first, in [layouts.md](layouts.md).

- [One config file](#one-config-file) · [Layouts](#layouts) · [Move by direction](#move-by-direction) · [Flip](#flip) · [Command palette](#command-palette) · [Command URL](#command-url) · [Padding modes](#padding-modes) · [Floating secondary windows](#floating-secondary-windows) · [Window limit](#window-limit) · [The mouse](#the-mouse) · [Focus border](#focus-border) · [Fullscreen toggle](#fullscreen-toggle) · [Feedback](#feedback) · [Not included](#not-included)

## One config file

The config file is the only source of settings and keys.

- It's read from `~/.config/ametrine/ametrine.yml` (or `~/.ametrine.yml`, or `~/.ametrine`). [ametrine.sample.yml](../ametrine.sample.yml) is a complete, real one.
- There's no preferences window: the menu has **Edit Config…** (opens the file) and **Reload Config** (relaunches).
- There are no built-in key bindings. A command is bound only if the file binds it; leaving it out, or setting it to `false` or `<NONE>`, leaves it unbound.
- A missing or broken config file shows an alert with the path, and Ametrine quits.
- `layouts:` decides which layouts the Layouts menu shows, the palette offers and `cycle-layout` steps through. It doesn't switch the others off: `toggle-fullscreen` and `flip-twin` work whether or not their layout is listed.

## Layouts

Windows are tiled per Space, by the layout each Space is on. Every layout is built around the **main pane**, the big tile for the window you're working in, and named by where main is: Tall Left, Wide Top, 3Column Middle, and so on. Each Space keeps its own layout, main count, ratio and pane sizes, also across restarts. `layout-names` gives a layout the name you see, e.g. `tall-left: "Coding"`.

See [layouts.md](layouts.md): main first, then every layout with a diagram.

## Move by direction

h/j/k/l with one modifier focuses the window to the west, south, north or east; with another it warps or swaps there. There's no clockwise order to remember, and no Alt-Tab to reach the window next to you.

- **Focus and swap** (`focus-<direction>`, `swap-<direction>`) reach the visible tiled window in that direction. Ties go to the window you used last, so east, west, east comes back to the same window. At the screen edge nothing happens. In Fullscreen, west and east cycle through the windows; in Two Pane, north and south browse the windows waiting behind the secondary pane.
- **Warp** (`warp-<direction>`, `warp-main`) moves the focused window into the pane in that direction, or into main from anywhere, so columns grow and shrink (3Column 1/2/2 → 1/3/1). A warp never empties a pane; a window warped into main lands at `main-arrival-position`.

See [directional-navigation.md](directional-navigation.md).

## Flip

- `flip-twin` shows the layout's mirror image: Tall Left ↔ Tall Right, with main count, ratio and pane sizes carried over (in 3Column Middle, the side columns swap).
- `flip-rows` and `flip-columns` reverse the order inside panes, to bring the windows at the far end closer.

See [flip](layouts.md#flip).

## Command palette

`show-command-palette` (Super+Y in the sample config) lists every command with its shortcut, plus current values such as the window max count and main pane count. Type to filter, ↑/↓ to select, Enter runs, Esc closes. It works like Spotlight: the app you're in stays in front.

Commands that take a number (`set-window-max-count`, `set-main-pane-count`) turn the search field into a number field: pick the command, type the number, Enter.

## Command URL

`open -g "ametrine://command/<command-key>"` runs any command, bound or not, from scripts or launchers such as Raycast. Unknown keys are ignored. Commands that take a number get it as `?value=<n>`, e.g. `ametrine://command/set-window-max-count?value=6`.

## Padding modes

Named virtual monitors on a large display, e.g. `full`, `wide` (21:9) and `27` (a centred 27"), anchored to the bottom edge. Switch with `cycle-padding-mode` or `select-<name>-padding-mode`, or from the Padding menu. The change applies at once to the current Space; each Space keeps its own mode, also across restarts, and starts on `padding-mode` until you pick one. The built-in display stays unpadded.

## Floating secondary windows

For apps in `floating-secondary-windows`, the first window on a Space tiles; that app's other windows (Settings, dialogs, Open panels) float. No title rules needed.

`explain-window` shows in a HUD whether the focused window is tiled, floating or not managed, and why. Launched with `--log`, Ametrine writes every such decision to `~/Library/Logs/Ametrine/Ametrine.log` (see [troubleshooting](troubleshooting.md)).

## Window limit

`window-max-count` caps how many windows tile on a screen. With `window-overflow: float`, the newest window over the limit floats, centred, and the tiles stay as they are; with `minimize`, it's minimised. See [window-limit.md](window-limit.md).

When an app refuses its tile (its window stays bigger than the tile, because of the app's minimum size), a short HUD says so, once per window and tile size (`enables-refused-tile-hud`).

## The mouse

- `mouse-swaps-windows`: drag a window onto another to swap them.
- `mouse-warps-windows`: hold Shift as you drop to warp the window into the pane under the cursor instead.
- `mouse-resizes-windows`: dragging main's edge changes the ratio.
- `snap-back-windows` (on by default): a drag or resize the layout doesn't take puts the window back on its tile, and so does a move or resize by another app (Raycast, scripts). Show desktop, native full screen and apps adjusting their own size are left alone.

## Focus border

`focus-border: true` draws a ring just outside the focused window, never over it. `glow` (default) is a thin ring with a soft halo like the macOS focus ring, in the system accent colour; `solid` and `gradient` (purple to gold) are the alternatives. It follows each window's own corners and keeps up with drags and resizes. Width, colour and a fallback corner radius are in the config. There's no border on tiled windows in the Fullscreen layout or in native full screen. `toggle-focus-border` and `cycle-focus-border-style` switch it until Reload Config.

## Fullscreen toggle

`toggle-fullscreen` switches a Space between its layout and Fullscreen, with the focused window in front (it doesn't become main), and back with every window in its tile.

## Feedback

- The current layout's name next to the menu bar icon.
- A short on-screen message (HUD) when the layout, padding mode, window max count or main pane count changes; main shows "x of y" (the windows it holds, of its maximum).
- Every app switch lays the screen out again, also for apps that don't announce it through Accessibility, and quitting an app frees all its tiles.

## Not included

- Auto-updates and default key bindings.
- Moving windows between displays or Spaces. Each display and Space is tiled on its own; dedicated apps do the moving well, and moving a window to another Space needs simulated mouse drags, because macOS has no public API for it.
