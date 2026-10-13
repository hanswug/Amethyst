# Troubleshooting

## Nothing is working!

Here are some common problems and their solutions.

### "Always float"

hw-Amethyst can float every application except the ones listed. When this mode is on by accident, it looks as if nothing is working. It's set by `floating-is-blacklist` in the config file:

```yaml
floating-is-blacklist: true   # the apps in `floating` float, everything else tiles (the default)
```

With `false`, the list is inverted: only the apps in `floating` tile.

### A reopened window floats where it used to be

macOS reopens a window at the size it had when the app quit. With `float-small-windows: true`, a window that opens smaller than `small-window-size` in both width and height floats. A small tile, such as a deep BSP split, can therefore come back as a floating window that no layout moves, and **Reevaluate windows** leaves it floating.

Fixes: set `float-small-windows: false` (hw-Amethyst's sample config does), change `small-window-size`, or toggle float on that window.

## One application isn't working!

### "Assign To All Desktops"

macOS has the option to assign an application specifically to no Desktops, one Desktop, or all Desktops. hw-Amethyst does not handle the last option very well.

To change this setting you can right click (or control click or whatever gesture you may have associated with right click) on the application icon in the Dock. Under Options there is an Assign To section. See the screenshot below for reference.

<img src="./images/desktop-assignment.png" width="50%">
