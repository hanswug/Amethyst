# Troubleshooting

## Nothing is working!

Here are some common problems and their solutions.

### Why does this window tile (or float)?

Run **Explain this window** from the command palette (or bind `explain-window`, or `open -g "ametrine://command/explain-window"`). A HUD says whether the focused window is tiled, floating or not managed, and why: a `floating` entry or title rule, `floating-secondary-windows`, `float-small-windows`, a manual `toggle-float`, the Floating layout, or tiling being off. Tiled windows also show how many windows tile against `window-max-count`.

### Logging

Launch with `--log` to write a log file, including one line per tile/float decision with its reason:

```sh
open -a Ametrine --args --log
tail -f ~/Library/Logs/Ametrine/Ametrine.log
```

The file also shows up in Console.app under Log Reports. It keeps at most three files of 5 MB.

### "Always float"

Ametrine can float every application except the ones listed. When this mode is on by accident, it looks as if nothing is working. It's set by `floating-is-blacklist` in the config file:

```yaml
floating-is-blacklist: true   # the apps in `floating` float, everything else tiles (the default)
```

With `false`, the list is inverted: only the apps in `floating` tile.

### A reopened window floats where it used to be

macOS reopens a window at the size it had when the app quit. With `float-small-windows: true`, a window that opens smaller than `small-window-size` in both width and height floats. A small tile, such as a deep BSP split, can therefore come back as a floating window that no layout moves, and **Reevaluate windows** leaves it floating.

Fixes: set `float-small-windows: false` (Ametrine's sample config does), change `small-window-size`, or toggle float on that window.

### Windows from another Space show up after App Exposé

This is a known macOS 27 bug, and it happens with Ametrine quit too. Open App Exposé (Application Windows, for example from a hot corner) and leave it. Windows from other Spaces are then drawn on the current Space, at the frames they have on their own Space, until you click any window. It happens every time, and a restart doesn't clear it.

The window server lists them as on screen while they still belong to their own Spaces, and the current Space doesn't change. Ametrine gets no event for this and moves none of those windows (checked with `--log`, 2026-10-16). Clicking a window clears it.

## One application isn't working!

### "Assign To All Desktops"

macOS has the option to assign an application specifically to no Desktops, one Desktop, or all Desktops. Ametrine does not handle the last option very well.

To change this setting you can right click (or control click or whatever gesture you may have associated with right click) on the application icon in the Dock. Under Options there is an Assign To section. See the screenshot below for reference.

<img src="./images/desktop-assignment.png" width="50%">

### A window looks floating but is tiled

Many apps (Safari, for example) have a minimum window size. When the layout gives such a window a smaller tile (a narrow column, many rows, a deep BSP split), macOS keeps it at its minimum. It then sticks out of its tile and overlaps its neighbours, so it looks as if it floated.

It is still tiled: it moves when the layout changes, and focus and swap commands reach it. `toggle-float` would float it for real. This is expected: Ametrine can't make an app smaller than the app allows.

Ametrine says so when it happens: a HUD such as `Safari doesn't fit its tile · needs 700 × 420 · tile 520 × 420`, once per window and tile size (it shows again if the tile changes to another size the window doesn't fit). `enables-refused-tile-hud: false` turns the HUD off; launched with `--log`, the log still records each case.

What helps: fewer windows on that screen, or a layout that gives it a bigger tile (the main pane, Two Pane). The planned `max-column-rows` setting is meant to keep side columns above most apps' minimum height.
