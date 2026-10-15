# Directional focus, swap and warp

Move around the layout by direction, the way you'd point at the screen: "the window to the right", "the one above". You don't have to remember the order windows were opened in, and you don't need Alt-Tab to reach the window next to you.

## How to enable

The commands are unbound until the config binds them. With vim keys, the modifier picks the verb and h/j/k/l the direction:

```yaml
mod1: [option, control]             # everyday: focus
mod2: [option, control, command]    # moving windows: warp
mod3: [control, command]            # swap

focus-west:  {mod: mod1, key: h}
focus-south: {mod: mod1, key: j}
focus-north: {mod: mod1, key: k}
focus-east:  {mod: mod1, key: l}

warp-west:   {mod: mod2, key: h}
warp-south:  {mod: mod2, key: j}
warp-north:  {mod: mod2, key: k}
warp-east:   {mod: mod2, key: l}
warp-main:   {mod: mod2, key: m}

swap-west:   {mod: mod3, key: h}
swap-south:  {mod: mod3, key: j}
swap-north:  {mod: mod3, key: k}
swap-east:   {mod: mod3, key: l}
swap-main:   {mod: mod3, key: m}

focus-ccw: false      # previous/next freed h and l
focus-cw:  false
swap-ccw:  false
swap-cw:   false
```

Arrow keys work too (`left`, `down`, `up`, `right`). All of them are also in the command palette and on the command URL, e.g. `open -g "ametrine://command/focus-east"`. Swap and warp shouldn't share a modifier; warp (below) is the more natural way to move windows, so it gets the easier one here.

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

## Warp

`warp-<direction>` moves the focused window into the pane next to it. Swap exchanges two windows and every pane keeps its size; warp makes one pane a window bigger and the other a window smaller.

The rules, the same in every layout:

* **Another pane:** the window joins it, right after the neighbour (below it, or to its right where a pane's windows are side by side). The neighbour is found as for focus, so it can be the window you used last in that column rather than the nearest one. If that isn't the spot you wanted, swap from there.
* **Into main:** the window lands on top of main with `main-arrival-position: first`, at the bottom with `last`, wherever its neighbour is. A warp into a full main raises the maximum by one, and a warp out of main lowers it by one, so the maximum follows how you arrange main.
* **The same pane:** a swap.
* **The last window of a pane** swaps instead: a warp never empties a pane.
* **An empty side column** (3Column, 4Column) can be warped into; the window becomes its only window. Focus and swap skip it.
* **Two Pane A/B, Column Left/Right, Row Top/Bottom:** each pane holds one window, so warp swaps.
* **BSP:** the window leaves its tile and splits the neighbour's, on the side it came from.
* **Fullscreen, Floating, custom layouts, a floating window:** nothing happens.

**`warp-main`** moves the focused window into main from wherever it is, without having to be next to main: on top of main or at the bottom by `main-arrival-position`, and its own pane shrinks. The last window of a pane swaps with main's top window instead; Two Pane, Column and Row (both twins of each) swap with main, like `swap-main`. From main, and in BSP (no main pane), nothing happens.

In 3Column Left with main, two windows in the middle column and two on the right (1/2/2), warping a right-column window west gives 1/3/1. Closing a middle window then gives 1/2/1: the right column keeps its window. In 3Column Middle with main count 3 and one window on the left, the right column is empty (1/3/0); warping a main window east gives 1/2/1.

Pane sizes are remembered per layout and Space, and survive a relaunch:

* A new window goes to the shorter side column (ties to the first), or into main while main has room and the side panes are still empty. Opened one at a time, windows get the usual balanced split.
* A window that leaves view (closed, quit, hidden, minimised, moved to another Space, floated) shrinks only its own pane. An emptied side column takes a window from the next one (1/0/2 becomes 1/1/1). A window coming back arrives like a new one, at `main-arrival-position`, not in its old column.
* `increase-main` and `set-main-pane-count` set the most windows main may hold; nothing moves. Warps in and out move it by one; a window leaving view doesn't, so its slot stays free for a window coming back. The HUD and the palette show "x of y": the windows in main, of the maximum. `decrease-main` below what main holds moves the extra windows to the first side pane.
