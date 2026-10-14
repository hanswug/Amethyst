# Window limit

## How to enable

Set `window-max-count` in the config file to the number of windows allowed on a screen. `0` turns the limit off.

```yaml
window-max-count: 8
enables-window-count-hud: true   # show the new count after changing it
```

- **Adjusting it:** `increase-window-max-count` and `decrease-window-max-count` change the limit until the next Reload Config; then the file's value applies again.
- **Seeing it:** the command palette shows the current count next to both commands. With `enables-window-count-hud: true`, a short on-screen message shows the new count.

## Overflow: minimise or float

`window-overflow` decides what happens to windows over the limit:

```yaml
window-overflow: float            # default minimize
window-overflow-size: reasonable  # 60% × 70% of the screen; fixed = the size below
window-overflow-width: 1600       # used by fixed (0 = not set)
window-overflow-height: 1100
```

* **`minimize`** (default): the oldest window outside the main pane is minimised (see Behavior below).
* **`float`**: the newest windows over the limit float, and the tiles stay as they are. "Newest" is the order windows were opened, not their place in the layout, so a window swapped to the end isn't mistaken for the new one.
  * A floated window is centred in the screen's usable area (padding mode included) at 60% × 70%, or at the `fixed` size. Apps with a minimum size stay bigger and are centred anyway. Each further overflow window still open goes 30 pt down and right of the last; a slot frees up when its window closes or tiles.
  * Lowering the limit follows the same rule: the newest windows over it float.
  * It stays floating when a tile frees up; `toggle-float` tiles it again.
  * **Explain this window** says "over the window limit".
* `toggle-window-overflow` and `toggle-window-overflow-size` switch both settings from the command palette until Reload Config.

## Behavior

* Floating windows aren't counted or minimised.
* Main-pane windows aren't minimised. With `new-windows-to-main: true`, the oldest window cycles out. With `false`, the main pane acts as a persistent workspace and the oldest of the other windows is minimised.
* In layouts without a main pane (Fullscreen, Floating, …), windows are minimised from the back of the list.
* The limit applies per screen.
* Turning tiling off (`toggle-tiling`, `disable-tiling`) turns the limit off too. Use the Floating layout to keep the limit without tiling.

## Recommendations

Turn on "Minimise windows into application icon" in System Settings → Desktop & Dock, so minimised windows don't clutter the Dock.

An iPad-like setup:
* Set `window-max-count: 2` and list just `fullscreen` and one paned layout in `layouts`. Cycle layouts to switch between full screen and split view.
* Set `mouse-swaps-windows: true` and `mouse-resizes-windows: true`.
* Float a window (`toggle-float`) to use it like slide-over.

## Limitations

* The limit may not be enforced when windows move between screens. Creating a new window corrects it.
