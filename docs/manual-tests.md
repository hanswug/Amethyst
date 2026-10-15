# Manual tests

The unit tests cover the layouts' arithmetic. They can't reach what happens between Ametrine and macOS: which events arrive, in which order, and which apps don't send them. Run these by hand before merging a trial branch into `fork/main`, and after any change to window tracking, focus or floating.

Use three or four everyday apps from different vendors (a terminal, a browser, an editor, an Electron app). The bugs found so far depended on the app.

## Window tracking

| Do | Expect |
|---|---|
| Hide one of three tiled apps with ⌘H | No empty tile; the others fill the screen. |
| Unhide it | It tiles again. |
| Quit an app that has a window you opened after Ametrine started | Its tile closes up. |
| Close a window while another Space is showing, then come back | No empty tile. |
| Minimise a tiled window, then restore it | It leaves and rejoins the layout. |

## Focus

| Do | Expect |
|---|---|
| Click a window of another app, then open a new window in a third app | Layouts that place new windows by focus (BSP) put it next to the window you clicked. |
| With a terminal in front, use focus and swap shortcuts | They act on the terminal's window. |
| 3Column 1/3/1: focus a lower middle window, focus west, then east | Back on the same middle window. |
| Two Pane with three windows: from main, focus east, then west and east again | Only the visible secondary is reached. |
| From a floating Settings window, focus west | The nearest tile to the west gets focus. |
| Fullscreen: focus west/east, then north/south | West/east cycle through all windows with wrap-around; north/south do nothing. |
| Swap east from main | Main and its neighbour trade places; focus and the cursor stay on the moved window. |
| With `focus-border: true`, move focus by key, then by clicking | The border follows; Ametrine never takes focus. |
| Drag and resize the focused window | The border follows it. |
| Click inside the focused window (Safari: the address bar, then the page) | The border stays on top, with no window shadow over it. |
| In CotEditor, select text with the mouse and with Shift+arrows; focus another app and move back (`focus-<direction>`, Alt-Tab) | The border stays on top of CotEditor throughout. |
| Drag a floating window (System Settings) around quickly, then resize it by an edge | The border stays visible and moves with the window, without trailing or flicker. |
| 3Column, main count 3: close the focused main window | The border goes to the newly focused window; no border is left behind at a window's old place. |
| Open a floating Settings window | It gets the border; the tile behind loses it. |
| Switch to the Fullscreen layout, then open a native full-screen app | No border in either. |
| ⌘H the focused app; switch Space | The border moves to the newly focused window (or disappears). |

## Floating

| Do | Expect |
|---|---|
| Open an app's Settings or a dialog (an app in `floating-secondary-windows`) | It floats; the app's first window stays tiled. |
| Quit an app whose window sat in a small tile, then reopen it | It tiles again (with `float-small-windows: false`). |
| Toggle float on a tiled window, then again | It floats, then rejoins the layout. |
| Tile Safari into a narrow tile | It sticks out at its minimum size but is still tiled: it moves with the layout (see [troubleshooting](troubleshooting.md#a-window-looks-floating-but-is-tiled)). |

## Window limit

| Do | Expect |
|---|---|
| Open one more window than `window-max-count` | The oldest window outside the main pane is minimised (or, once `window-overflow: float` exists, the new window floats). |
| Run `decrease-window-max-count` | The windows over the new limit follow the same rule. |
| 3Column Middle, main count 3 (left 1, main 3, right 1): close a main window | Main shrinks to 2; left and right keep their windows; no blank column. |
| Same, but ⌘H or minimise a main window instead | Main shrinks to 2. Unhide or unminimise it: it comes back at `main-arrival-position` (last: the end), not into main. |

## App-level

| Do | Expect |
|---|---|
| Reload Config | The app relaunches, keeps the current layout and applies the file. |
| Open the command palette, run a command | It runs; the app you were in stays in front. |
| Cycle the padding mode on the large display | The layout redraws in the new area instantly. |
| Launch with `--log` | The app starts (it used to exit). |
