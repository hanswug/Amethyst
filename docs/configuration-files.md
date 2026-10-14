# Configuration file

hw-Amethyst is configured only through its config file. There is no preferences window.

## Where it lives

The first file that exists is used:

1. `~/.hw-amethyst.yml`
2. `~/.config/hw-amethyst/amethyst.yml` (or `$XDG_CONFIG_HOME/hw-amethyst/amethyst.yml`)
3. `~/.hw-amethyst` (JSON)

- **Missing or broken file:** if there's no file, or it can't be read, hw-Amethyst shows an alert with the path and quits.
- **Menu:** **Edit Config…** opens the file in its default editor. **Reload Config** relaunches the app so changes apply.
- **Defaults:** settings the file leaves out get the built-in defaults below, on every load.
- **Examples:** the [README](../README.md#configuration) has a short one; [hw-amethyst.sample.yml](../hw-amethyst.sample.yml) is a complete, real config.

## Settings

| Key | Description |
| -- | -- |
| `layouts` | Ordered list of layouts to use, by layout key (default `tall`, `wide`, `fullscreen`, `column`). See the [README](../README.md#layouts) for the keys. |
| `mod1` | First modifier combination, a list of `option`, `control`, `shift`, `command` (default `option` + `shift`). Required. |
| `mod2` | Second modifier combination (default `option` + `shift` + `control`). Required. |
| `mod3` | Third modifier combination (optional, none by default). |
| `mod4` | Fourth modifier combination (optional, none by default). |
| `window-max-count` | The max number of windows visible on a screen at once; more are minimised. `0` turns the limit off (default `0`). |
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
| `new-windows-to-main` | `true` to insert new windows in the first position, `false` for the last (default `false`). |
| `window-resize-step` | Percentage of the screen size by which `shrink-main` and `expand-main` change the main pane (default `5`). |
| `padding-modes` | Named sets of screen paddings, e.g. `- {name: wide, top: 540}`. Sides left out are `0`. Switch with the padding commands or the Padding menu (default none). |
| `padding-mode` | The mode to use until one has been selected. After that, the last selected mode survives restarts (default none). |
| `screen-padding-left` | Space between windows and the left screen edge, used when no padding mode is active (in px, default `0`). |
| `screen-padding-right` | Same for the right edge (in px, default `0`). |
| `screen-padding-top` | Same for the top edge (in px, default `0`). |
| `screen-padding-bottom` | Same for the bottom edge (in px, default `0`). |
| `disable-padding-on-builtin-display` | `true` to apply no screen padding on a built-in display (default `false`). |
| `restore-layouts-on-launch` | `true` to keep layout state across restarts (default `true`). |
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
- **Unbound still runs.** Every command, bound or not, can be run from the command palette or with `open -g "amethyst://command/<command-key>"`.

### Command keys

| Command | Description |
| ------- | ------------|
| `cycle-layout` | Move to the next layout in the list. |
| `cycle-layout-backward` | Move to the previous layout in the list. |
| `select-<layout-key>-layout` | Switch to that layout, e.g. `select-tall-layout`. Only works for layouts listed in `layouts`. Custom layouts too. |
| `shrink-main` | Shrink the main pane by `window-resize-step`. Not every layout responds. |
| `expand-main` | Expand the main pane by `window-resize-step`. Not every layout responds. |
| `increase-main` | Add a window to the main pane, and show the new count. Only layouts with a main pane respond. |
| `decrease-main` | Remove a window from the main pane, and show the new count. Only layouts with a main pane respond. |
| `increase-window-max-count` | Raise `window-max-count` by one until Reload Config, and show it if `enables-window-count-hud` is on. |
| `decrease-window-max-count` | Lower `window-max-count` by one until Reload Config, and show it if `enables-window-count-hud` is on. |
| `focus-ccw` | Focus the next window counter-clockwise. |
| `focus-cw` | Focus the next window clockwise. |
| `focus-main` | Focus the main window. |
| `swap-ccw` | Swap the focused window with the next one counter-clockwise. |
| `swap-cw` | Swap the focused window with the next one clockwise. |
| `swap-main` | Swap the focused window with the main window. |
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
| `relaunch-amethyst` | Quit and reopen hw-Amethyst (also what Reload Config does). |
| `command1` … `command4` | General-purpose commands for custom layouts. They exist only when at least one custom layout is installed. |
