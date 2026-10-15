# Configuration file

Ametrine is configured only through its config file. There is no preferences window.

## Where it lives

The first file that exists is used:

1. `~/.ametrine.yml`
2. `~/.config/ametrine/ametrine.yml` (or `$XDG_CONFIG_HOME/ametrine/ametrine.yml`)
3. `~/.ametrine` (JSON)

- **Missing or broken file:** if there's no file, or it can't be read, Ametrine shows an alert with the path and quits.
- **Menu:** **Edit Config…** opens the file in its default editor. **Reload Config** relaunches the app so changes apply.
- **Defaults:** settings the file leaves out get the built-in defaults below, on every load.
- **Examples:** the [README](../README.md#configuration) has a short one; [ametrine.sample.yml](../ametrine.sample.yml) is a complete, real config.

## Settings

| Key | Description |
| -- | -- |
| `layouts` | Ordered list of layouts to use, by layout key (default `tall`, `wide`, `fullscreen`, `column`). See the [README](../README.md#layouts) for the keys. |
| `mod1` | First modifier combination, a list of `option`, `control`, `shift`, `command` (default `option` + `shift`). Required. |
| `mod2` | Second modifier combination (default `option` + `shift` + `control`). Required. |
| `mod3` | Third modifier combination (optional, none by default). |
| `mod4` | Fourth modifier combination (optional, none by default). |
| `window-max-count` | The max number of windows visible on a screen at once; more are minimised or float (`window-overflow`). `0` turns the limit off (default `0`). |
| `window-overflow` | What happens to windows over `window-max-count`: `minimize` (the oldest window outside the main pane) or `float` (the newest windows float, centred, and the tiles stay as they are). Default `minimize`. See [window limit](window-limit.md). |
| `window-overflow-size` | The size of a window floated over the limit: `reasonable` (60% × 70% of the screen's usable area) or `fixed` (`window-overflow-width` × `window-overflow-height`). Default `reasonable`. |
| `window-overflow-reasonable-width` / `window-overflow-reasonable-height` | The `reasonable` overflow window size, in percent of the screen's usable width and height (1–100; defaults `60` and `70`). |
| `window-overflow-width` / `window-overflow-height` | The `fixed` overflow window size in points; never bigger than the screen. `0` = not set, and `fixed` then falls back to `reasonable` (default `0`). |
| `window-margins` | `true` to add margins between and around windows (default `false`). |
| `smart-window-margins` | `true` to drop the margins when there is only one window on the screen, if margins are on (default `false`). |
| `window-margin-size` | Size of the margins between and around windows (in px, default `0`). |
| `window-minimum-height` | Smallest height a window can be sized to, regardless of its layout frame (in px, default `0`). |
| `window-minimum-width` | Smallest width a window can be sized to, regardless of its layout frame (in px, default `0`). |
| `floating` | Applications that float (or tile, see `floating-is-blacklist`), by bundle identifier (default `[]`). An entry is an id (exact, or a `*` glob) or `{id: ..., window-titles: [...]}` to match only some windows. Titles are unanchored, case-sensitive regexes: use `^…$` and `(?i)`. The first matching entry wins. |
| `floating-is-blacklist` | `true` if the apps in `floating` float and all others tile; `false` for the opposite (default `true`). |
| `floating-secondary-windows` | Applications whose first window on a Space tiles while their other windows (Settings, dialogs, Open panels) float. Ids match like `floating`. It's a separate list, so `floating`'s "first match wins" rule doesn't apply (default `[]`). |
| `ignore-menu-bar` | `true` to lay windows out over the whole screen, menu bar and Dock area included (default `false`). |
| `float-small-windows` | `true` if windows smaller than `small-window-size` should float (default `true`). A valid option on its own; it also used to serve as a workaround for secondary windows that Electron and similar apps draw as normal windows, which `floating-secondary-windows` now handles. The size is checked when a window opens, and macOS reopens windows at their last size, so a window from a small tile can come back floating; see [troubleshooting](troubleshooting.md#a-reopened-window-floats-where-it-used-to-be). |
| `small-window-size` | Threshold for `float-small-windows`: windows below this width and height are small (in px, default `500`). |
| `mouse-follows-focus` | `true` to move the mouse to the centre of a window when it gets focus (default `false`). Largely incompatible with `focus-follows-mouse`. |
| `focus-follows-mouse` | `true` to focus the window under the mouse as it moves (default `false`). Largely incompatible with `mouse-follows-focus`. |
| `mouse-swaps-windows` | `true` to swap windows by dragging one onto another (default `false`). |
| `mouse-resizes-windows` | `true` to update the layout when a window is resized with the mouse (default `false`). Not every layout can follow. |
| `enables-layout-hud` | `true` to show a short on-screen message when the layout, padding mode or main pane count changes (default `true`). |
| `enables-layout-hud-on-space-change` | `true` to show the layout name when moving to another Space (default `true`). |
| `enables-window-count-hud` | `true` to show the new window max count on screen after increasing or decreasing it (default `false`). |
| `enables-refused-tile-hud` | `true` to show a short message when a tiled window stays bigger than its tile (an app's minimum size), once per window and tile size (default `true`). |
| `focus-border` | `true` to draw a border around the focused window (default `false`). Only windows Ametrine manages, tiled or floating; none for tiled windows in the Fullscreen layout or in native full screen. It sits just outside the window, in the margin, and never covers the window itself. |
| `focus-border-style` | `glow` (a thin ring with a soft glow, like the macOS focus ring), `solid` or `gradient` (default `glow`). |
| `focus-border-width` | Points: the ring width for `solid` and `gradient`, and how far the glow reaches (default `5`). |
| `focus-border-color` | `accent` (the system accent colour, following System Settings), `"#RRGGBB"` or `"#AARRGGBB"` (default `accent`). Quote hex colours in YAML. |
| `focus-border-gradient` | The two colours of the `gradient` style, top left to bottom right (default `["#9B5DE5", "#F4B942"]`, purple to gold). |
| `focus-border-radius` | Corner radius in points (default `12`), used when the window server doesn't report the window's own radius; normally the border follows each window's own corners. |
| `main-arrival-position` | Where a window arriving in the main pane goes: `first` or `last` (default `last`). `first`: on top of main (left when main's windows are side by side); with main full, its last window moves out. `last`: at the end; it joins main only while main has room, so main stays as it is. Swaps (`swap-main`, `swap-<direction>`) don't use it: they exchange two windows' places. Replaces `new-windows-to-main` (`true` = `first`, `false` = `last`). |
| `window-resize-step` | Percentage of the screen size by which `shrink-main` and `expand-main` change the main pane (default `5`). |
| `padding-modes` | Named sets of screen paddings, e.g. `- {name: wide, top: 540}`. Sides left out are `0`. Switch with the padding commands or the Padding menu (default none). |
| `padding-mode` | The mode to use until one has been selected. After that, the last selected mode survives restarts (default none). |
| `screen-padding-left` | Space between windows and the left screen edge, used when no padding mode is active (in px, default `0`). |
| `screen-padding-right` | Same for the right edge (in px, default `0`). |
| `screen-padding-top` | Same for the top edge (in px, default `0`). |
| `screen-padding-bottom` | Same for the bottom edge (in px, default `0`). |
| `disable-padding-on-builtin-display` | `true` to apply no screen padding on a built-in display (default `false`). |
| `restore-layouts-on-launch` | `true` to keep layouts across restarts and Reload Config (default `true`): each Space comes back on the layout it was on, with its main pane size, main pane count and column sizes, and the windows keep their places (main pane included); `swap-main` from the main window still swaps back with the window that was there before. Windows opened while Ametrine wasn't running go after them. A layout no longer in `layouts` falls back to the first one. |
| `debug-layout-info` | `true` to add debug information to the layout HUD (default `false`). |
| `hide-menu-bar-icon` | `true` to hide the menu bar icon, and with it the current layout's name shown next to it (default `false`). |

## Commands

A command is bound to a key only if the file binds it, with an object holding `mod` and `key`:

```yaml
cycle-layout:
  mod: mod1
  key: "."
```

| Key | Description |
| --- | ----------- |
| `mod` | `mod1`, `mod2`, `mod3` or `mod4`. |
| `key` | The key: a character (quote digits and symbols, e.g. `"0"`), or `space`, `enter`, `up`, `down`, `left`, `right`, `delete`. |

- **No built-in keys.** Leaving a command out, setting it to `false`, or binding it to `<NONE>` leaves it unbound.
- **Unbound still runs.** Every command, bound or not, can be run from the command palette or with `open -g "ametrine://command/<command-key>"`.
- **Commands that take a number** (`set-window-max-count`, `set-main-pane-count`) have no key. In the palette, picking one turns the search field into a number field: type the number and press Enter (Esc goes back to the list). By URL, pass the number as `value`, e.g. `open -g "ametrine://command/set-window-max-count?value=8"`; a missing or invalid value is logged and ignored.

### Command keys

| Command | Description |
| ------- | ------------|
| `cycle-layout` | Move to the next layout in the list. |
| `cycle-layout-backward` | Move to the previous layout in the list. |
| `select-<layout-key>-layout` | Switch to that layout, e.g. `select-tall-layout`. Only works for layouts listed in `layouts`. Custom layouts too. |
| `shrink-main` | Shrink the main pane by `window-resize-step`, down to 5% of the screen (so neither pane disappears). Not every layout responds. |
| `expand-main` | Expand the main pane by `window-resize-step`, up to 95% of the screen. Not every layout responds. |
| `increase-main` | Add a window to the main pane, and show the new count. Only layouts with a main pane respond. |
| `decrease-main` | Remove a window from the main pane, and show the new count. Only layouts with a main pane respond. |
| `set-main-pane-count` | Set the number of windows in the main pane (1–99), and show it. Palette and URL only. Only layouts with an adjustable main pane respond. |
| `increase-window-max-count` | Raise `window-max-count` by one until Reload Config, and show it if `enables-window-count-hud` is on. |
| `decrease-window-max-count` | Lower `window-max-count` by one until Reload Config, and show it if `enables-window-count-hud` is on. |
| `toggle-window-overflow` | Switch `window-overflow` between `minimize` and `float` until Reload Config, and show it if `enables-window-count-hud` is on. Windows already minimised or floated stay so. |
| `toggle-window-overflow-size` | Switch `window-overflow-size` between `reasonable` and `fixed` until Reload Config (stays `reasonable` without a configured size), and show it if `enables-window-count-hud` is on. |
| `toggle-focus-border` | Turn `focus-border` on or off until Reload Config, and show it if `enables-layout-hud` is on. |
| `cycle-focus-border-style` | Switch `focus-border-style` to the next style (glow, solid, gradient) until Reload Config, and show it if `enables-layout-hud` is on. |
| `toggle-main-arrival-position` | Switch `main-arrival-position` between `first` and `last` until Reload Config, and show it if `enables-layout-hud` is on. |
| `set-window-max-count` | Set `window-max-count` (0–99, `0` = unlimited) until Reload Config, and show it if `enables-window-count-hud` is on. Palette and URL only. |
| `focus-ccw` | Focus the next window counter-clockwise. |
| `focus-cw` | Focus the next window clockwise. |
| `focus-main` | Focus the main window. |
| `swap-ccw` | Swap the focused window with the next one counter-clockwise. |
| `swap-cw` | Swap the focused window with the next one clockwise. |
| `swap-main` | Swap the focused window with the main window. |
| `focus-west` … `focus-south` | Focus the tiled window in that direction (`west`, `east`, `north`, `south`). Only visible windows count: of windows stacked in one tile (Two Pane's secondary) only the front one is reached. Ties go to the window used most recently. From a floating window it reaches the nearest tile in that direction; floating windows are never a target. At the screen edge nothing happens (no wrap-around, no other display). In Fullscreen, west/east cycle through the windows and north/south do nothing. See [directional focus and swap](directional-navigation.md). |
| `swap-west` … `swap-south` | Swap the focused window with the tiled window in that direction (found as for `focus-<direction>`). Focus and, with `mouse-follows-focus`, the cursor go with the window. Nothing happens from a floating window or in Fullscreen. |
| `toggle-float` | Toggle floating for the focused window. |
| `explain-window` | Show in a HUD whether the focused window is tiled, floating or not managed, and why. |
| `display-current-layout` | Show the layout HUD with the current layout. |
| `toggle-tiling` | Turn tiling on or off. |
| `enable-tiling` | Turn tiling on. |
| `disable-tiling` | Turn tiling off. |
| `reevaluate-windows` | Re-check which windows are managed and lay them out again. |
| `toggle-focus-follows-mouse` | Turn `focus-follows-mouse` on or off. |
| `cycle-padding-mode` | Switch to the next padding mode (wraps around). |
| `cycle-padding-mode-backward` | Switch to the previous padding mode (wraps around). |
| `select-<name>-padding-mode` | Switch to that padding mode, e.g. `select-wide-padding-mode`. |
| `show-command-palette` | Open (or close) the command palette. |
| `relaunch-ametrine` | Quit and reopen Ametrine (also what Reload Config does). |
| `command1` … `command4` | General-purpose commands for custom layouts. They exist only when at least one custom layout is installed. |
