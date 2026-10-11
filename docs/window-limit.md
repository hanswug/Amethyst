# Window limit

## How to enable

Set `window-max-count` in the config file to the number of windows allowed on a screen. `0` turns the limit off.

```yaml
window-max-count: 8
enables-window-count-hud: true   # show the new count after changing it
```

- **Adjusting it:** `increase-window-max-count` and `decrease-window-max-count` change the limit until the next Reload Config; then the file's value applies again.
- **Seeing it:** the command palette shows the current count next to both commands. With `enables-window-count-hud: true`, a short on-screen message shows the new count.

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
