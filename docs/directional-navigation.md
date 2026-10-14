# Directional focus and swap

Move around the layout by direction, the way you'd point at the screen: "the window to the right", "the one above". You don't have to remember the order windows were opened in, and you don't need Alt-Tab to reach the window next to you.

## How to enable

The commands are unbound until the config binds them. With vim keys, the modifier picks the verb and h/j/k/l the direction:

```yaml
mod1: [option, control]             # everyday: focus
mod2: [option, control, command]    # transformations: swap

focus-west:  {mod: mod1, key: h}
focus-south: {mod: mod1, key: j}
focus-north: {mod: mod1, key: k}
focus-east:  {mod: mod1, key: l}

swap-west:   {mod: mod2, key: h}
swap-south:  {mod: mod2, key: j}
swap-north:  {mod: mod2, key: k}
swap-east:   {mod: mod2, key: l}

focus-ccw: false      # previous/next freed h and l
focus-cw:  false
swap-ccw:  false
swap-cw:   false
```

Arrow keys work too (`left`, `down`, `up`, `right`). All eight commands are also in the command palette and on the command URL, e.g. `open -g "ametrine://command/focus-east"`.

## What it does

* **`focus-<direction>`** focuses the tiled window in that direction. With `mouse-follows-focus: true` the cursor goes with it.
* **`swap-<direction>`** swaps the focused window with that neighbour. Focus stays on the moved window, and with `mouse-follows-focus` the cursor follows it to its new tile. Swapping only reorders: 3Column's column sizes and the main pane's size don't change.

In 3Column Left with a main window, three windows in the middle column and one on the right:

```
┌──────────┬──────────┬──────────┐
│          │    A     │          │
│          ├──────────┤          │
│   Main   │    B     │  Right   │
│          ├──────────┤          │
│          │    C     │          │
└──────────┴──────────┴──────────┘
```

* From Main, east goes to the middle column: to the window you used there last, or B if you haven't used any.
* From Right, west goes to the middle column as well, not past it to Main.
* From C, north goes to B, then A; north from A does nothing.
* East, west, east comes back to the same window.

## The rules

* **Only visible windows.** Hidden and minimised windows aren't reachable. When several windows share a tile, like Two Pane's secondary pane, only the one in front is reached.
* **Nearest first.** Of the windows in that direction, the closest column (or row) wins, then the one that lines up best with the focused window, then the one you used most recently, then the nearest centre.
* **From a floating window** (Settings, a dialog), focus goes to the nearest tile in that direction. Floating windows are never a target, and swap does nothing from one.
* **Screen edge:** nothing happens. There's no wrap-around and no jump to another display.
* **Fullscreen** is the exception: every window fills the screen, so west/east cycle through the windows (wrapping around) and north/south do nothing. Swap does nothing in Fullscreen.
* Directions use the tiles the layout assigned, before window margins, so an app that won't shrink to its tile doesn't confuse them.
