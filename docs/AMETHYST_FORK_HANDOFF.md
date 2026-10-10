# Amethyst fork: handover & build plan

Owner: Hans · Prepared 2026-10-10 · Upstream baseline: `ianyh/Amethyst`, branch `development`, commit `6508ee2` (2026-08-19)

**For Claude Code:** every decision here has been made with Hans (§2). Build in the phase order of §4, one branch per phase, each off `fork/main` (§3 rule 1). Stop and ask Hans only if something in this document turns out to be false in the code. File paths and approximate line numbers were checked against the baseline commit; re-check them after rebasing.

**Scope: personal use.** No public release is planned (no Apple Developer account, and BetterStage already serves that market). Generic features may still go upstream as pull requests. Appendix A covers what a public release would take, in case that ever changes.

---

## 1. Context

- **Why this fork exists:** Hans wants **directional** navigation (west/east/north/south) for focus, swap and warp, instead of previous/next (clockwise/counter-clockwise). For switching windows in general he uses an Alt-Tab app; Amethyst doesn't need to replicate that.
- **Two Macs, one screen.** Hans plugs the **same** Samsung Odyssey Ark Gen 2 (55", 3840×2160, curved, can pivot to portrait "cockpit" mode) into either his **personal Mac** or his **work Mac**. Only one display is in use at a time: the Ark in clamshell, or a built-in panel. Both Macs run the fork and share the same YAML (dotfiles), so padding modes and every other decision apply to both unchanged.
- **Daily layouts** (`layouts:` order, selected with mod1 + 1…5): Fullscreen, Two Pane, 3Column Left, 3Column Middle (`middle-wide`), Tall.
- **"Main" means focus.** Hans puts the window he's working on in the main pane and enlarges it, and the others shrink. Nothing should change the main pane unless he asks.
- **Config:** the fork reads its own file, `~/.config/hw-amethyst/amethyst.yml` (§5.0). Upstream keeps `~/.config/amethyst/amethyst.yml`, frozen as the fallback's config. Either may be a symlink into a dotfiles repo; edit the real file.
- **Current bindings:**
  - Modifiers: mod1 = ⌥⌃, mod2 = ⌥⌃⌘.
  - mod1/mod2 + h/l: focus/swap counter-clockwise/clockwise.
  - mod1/mod2 + m: focus/swap main.
  - mod1 + `-`/`=`: shrink/expand main. mod2 + `-`/`=`: decrease/increase main count.
  - mod1 + `.` / mod2 + `,`: cycle layout forward/backward.
  - mod1 + t: toggle float. mod1 + i: layout HUD. mod2 + r: re-evaluate windows.
- **Settings that matter for the specs:**

| Setting | Value | Where it matters |
|---|---|---|
| `window-margins` / `window-margin-size` | `true` / `8` | §5.4 |
| `mouse-follows-focus` | `true` | §5.4 |
| `mouse-swaps-windows` | `true` | §5.4, §5.5 |
| `mouse-resizes-windows` | `true` | §5.4, §5.5 |
| `window-max-count` | `8` | §5.5 |
| `new-windows-to-main` | `false` | — |
| `restore-layouts-on-launch` | `true` | §3 rule 5 |
| `disable-padding-on-builtin-display` | `true` | §5.1 |

## 2. Decisions (locked)

| Topic | Decision | Why |
|---|---|---|
| Base | Fork Amethyst; not yabai, Hammerspoon or JS custom layouts | Amethyst already models list → layout → frames, with events, mouse and focus solved. BSP collapses on close; scripts react too late; JS `extends` freezes main count. |
| Fork identity | Rename the bundle ID and name; **turn off Sparkle**; **self-signed code-signing certificate, built locally on each Mac** | Upstream stays installed as a fallback; the fork can't auto-update itself back to upstream; the Accessibility permission survives rebuilds without an Apple Developer account. Local builds aren't quarantined, so Gatekeeper never prompts. |
| Build order | **Quick wins first:** padding → secondary windows → directional → warp → rotate → command URL → Raycast extension *(reordered 2026-10-10: the command URL moved last, since its main user is the Raycast extension and no phase depends on it)* | Daily payoff early. Directional comes before warp because warp reuses its neighbour finder. |
| Padding modes | In-app, global, last used mode survives restarts | Replaces two Raycast scripts that edit the YAML and restart Amethyst. |
| External control | `amethyst://command/<command-key>` runs any command | One handler; Raycast and shell scripts can call everything. |
| Secondary windows | Per-app list; anchor model, per space | Floats Settings, preference and Open windows with no title rules. |
| Directional commands | `focus-<dir>`, `swap-<dir>`, `warp-<dir>` for west/east/north/south | The reason for the fork. |
| How a direction is resolved | **Geometry** on the layout's assigned frames (before margins) | One implementation for every layout; stays correct after rotate/mirror; immune to apps that refuse their frame. |
| Visibility rule | **Directions only reach windows you can see** | Hidden and minimised windows are out of scope; windows stacked behind Two Pane's secondary are unreachable by direction. |
| Fullscreen | **The one exception:** west/east cycle through the stack (previous/next, wrapping); north/south, swap and warp do nothing | Muscle memory: h/l cycle Fullscreen today. |
| Previous/next | **Not built.** Upstream `focus-cw/ccw` and `swap-cw/ccw` stay in the code, unbound by Hans | An Alt-Tab app covers it better. |
| Screen edge | No-op: no wrap-around, no jumping to another display | Single-display use; documented as a limitation. |
| Warp in 3Column | Columns grow and shrink (stored column sizes) | 1/2/2 → warp → 1/3/1; closing a window shrinks only its own column. |
| Warp elsewhere | **Tall:** moves the main boundary. **Two Pane:** west/east swaps with main. Everything else: no-op | These are the layouts Hans uses. |
| New window in 3Column | Shorter side column, never main; ties go to the secondary pane | Main changes only on command; additions reproduce upstream's split exactly. |
| Hotkeys | All new commands ship **unbound**; Hans binds them in YAML (§6 has a suggested scheme) | No collisions; PR-friendly. |
| Dropped | Float by AX role/subrole; re-check float on title change; cross-display directions; public release | Covered by other features or out of scope. |

## 3. Ground rules

1. **Small, rebasable patches.** One branch per phase, off the private integration branch `fork/main` (= `development` + phase 0 + every finished phase). Upstream is active.
   - Finished, tested phases merge back into `fork/main`; the installed app is always built from `fork/main`.
   - Why not off `development`: on Xcode 27 a plain `development` branch can't build or test without `fork/setup`'s scripts (deployment target, test isolation), and later phases build on earlier ones (2 uses 1's commands, 5 reuses 4's neighbour finder).
   - To propose a feature upstream: `git rebase --onto development fork/main feat/<x>` (or cherry-pick its commits). Phase 0's commits only touch identity, signing, scripts and docs, so feature commits lift off cleanly. Keep feature commits free of fork-only changes so this stays true.
   - Rebasing on upstream: rebase `fork/main` onto the new `development`, then rebase any open phase branch onto `fork/main`.
2. **Upstream-friendly.** Padding modes, the command URL, secondary windows, directional navigation and warp should each be proposable upstream (open an issue first to ask whether it's wanted). Only the fork-identity changes (§5.0) stay private.
3. **Signing:** use a **self-signed code-signing certificate**, not ad-hoc signing (§5.0). macOS ties the Accessibility permission to the signing identity. Ad-hoc builds change identity on every build and force a re-grant.
4. **Build and test:** don't use the `fastlane` lane. It exports with method `developer-id` and upstream's team ID (`exportOptions.plist`), which Hans doesn't have. Build with `xcodebuild` and the self-signed identity (§5.0). Tests:
   - Layout: `AmethystTests/Tests/Layout/*` (including `ThreeColumnLayoutTests.swift` and `TallLayoutTests.swift`), with helpers in `AmethystTests/Helpers/FrameAssignmentVerification.swift`.
   - Config: `AmethystTests/Tests/Configuration/UserConfigurationTests.swift`.
5. **Saved state must keep decoding.** With `restore-layouts-on-launch: true`, layouts are decoded from saved state. New stored properties use `decodeIfPresent` with a default.
6. **Behave like upstream unless configured.** With none of the new keys or bindings set, the fork behaves exactly like upstream.

## 4. Build plan

| Phase | Branch | Deliverable | Size | Spec |
|---|---|---|---|---|
| 0 | `fork/setup` | Renamed app, Sparkle off, self-signed build script, profiling baseline | S | §5.0 |
| 1 | `feat/padding-modes` | Padding modes switch instantly in-app | S | §5.1 |
| 2 | `feat/command-url` | `amethyst://command/<key>`. **Built after phase 6**, just before the Raycast extension | S | §5.2 |
| 3 | `feat/secondary-windows` | `floating-secondary-windows`, anchor model | S–M | §5.3 |
| 4 | `feat/directional` | `focus-<dir>`, `swap-<dir>` and the shared neighbour finder | M | §5.4 |
| 5 | `feat/warp` | `warp-<dir>` in 3Column, Tall and Two Pane | L | §5.5 |
| 6 | `feat/rotate` | Rotate / mirror post-transform | M | §5.6 |

`fork/main` was created from `fork/setup` when phase 0 finished; phases 1–6 branch off it and merge back (§3 rule 1).

Phases keep their numbers but are built in the order 1, 3, 4, 5, 6, 2, then a Raycast extension for hw-Amethyst on top of the command URL. After phase 1, Hans retired both Raycast padding scripts (§7). After phase 3, the Obsidian title rule leaves his config (§6). After phase 4, he rebinds h/j/k/l (§6).

## 5. Specs

### 5.0 Fork setup and baseline

- **Identity:** change `PRODUCT_BUNDLE_IDENTIFIER` in `Amethyst.xcodeproj/project.pbxproj` (~L1062, ~L1108; currently `com.amethyst.${PRODUCT_NAME:rfc1034identifier}`) to `com.<handle>.Amethyst`, and give the product a distinct display name. **Hans picks both.** Upstream's `Amethyst.app` can then stay installed as a fallback, as long as the two apps **never run at the same time**.
- **Turn off Sparkle:** the feed lives in `Amethyst/Amethyst-Info.plist` (`SUFeedURL` ~L35, `SUCanaryFeedURL`) and is set in `AppDelegate.swift` (~L50–66). The "Check for Updates" action is in `AppDelegate.swift` (~L166). Remove both, or the fork can replace itself with upstream.
- **Signing without an Apple Developer account:**
  1. In Keychain Access, use Certificate Assistant → Create a Certificate… with Certificate Type "Code Signing". Give it a fixed name, e.g. `Amethyst Local Signing`.
  2. For the Release configuration, set `CODE_SIGN_STYLE = Manual`, `DEVELOPMENT_TEAM = ""` and `CODE_SIGN_IDENTITY = "Amethyst Local Signing"`. In the baseline, Release has `Apple Development` and upstream's team ID (~L1077–1085).
  3. Add a `scripts/build.sh` that runs `xcodebuild -workspace Amethyst.xcworkspace -scheme Amethyst -configuration Release build` and copies the `.app` to `/Applications`.
  - **Do this on both Macs.** Each Mac gets its own certificate **with the same name**, so the build script is identical, and each Mac's Accessibility permission sticks to its own certificate. No Apple account is involved, so the work Mac's different Apple ID doesn't matter (it's only needed to download Xcode).
  - **Work Mac:** before the first build, confirm that IT policy allows installing Xcode, running locally built apps, and granting them Accessibility.
  - Apps built on the same Mac aren't quarantined, so Gatekeeper never prompts. Signing only matters for keeping the Accessibility permission.
- **Consequences to tell Hans about:**
  - A new preferences domain means GUI preferences don't carry over. That's fine: the YAML is the source of truth.
  - Saved layout state starts fresh once.
  - Grant Accessibility to the new app, and switch the login item over.
- **Separate config files** *(changed 2026-10-10; originally one shared YAML)*:
  - The fork reads `~/.hw-amethyst.yml`, then `~/.config/hw-amethyst/amethyst.yml` (or `$XDG_CONFIG_HOME/hw-amethyst`), then `~/.hw-amethyst`. Upstream reads its own files, which it can keep unchanged.
  - The name comes from `AMConfigName` in `Amethyst-Info.plist`; without that key the code behaves as upstream's.
  - **Why the shared file was dropped:** it would degrade the fallback. The fork's config removes and renames settings upstream relies on: `screen-padding-top` gives way to padding modes in phase 1, and `focus-cw/ccw: false` comes in phase 4.
- **Profiling baseline:** Hans reports occasional slowdown and quirks. Run Instruments' Time Profiler during normal use, find out whether the cost is in Amethyst or in an app flooding it with Accessibility notifications, and record the findings in `docs/PROFILING.md`.
- **Debug CLI:** `<App>.app/Contents/MacOS/Amethyst debug windows` lists window titles and whether each is managed.

### 5.1 Padding modes

**What they are:** virtual monitors cut out of the Ark, anchored to the bottom because the top of a 55" panel sits above comfortable eye level. Values are in points; bottom is always 0.

| Mode | left | right | top | Usable area | Emulates |
|---|---|---|---|---|---|
| `full` | 0 | 0 | 0 | 3840 × 2160 | the whole Ark |
| `wide` | 0 | 0 | 540 | 3840 × 1620 | a 21:9 ultrawide |
| `27` | 640 | 640 | 720 | 2560 × 1440 | a 27" QHD, centred |

**Today:** two Raycast scripts `sed` the `screen-padding-*` keys and restart Amethyst.

**Why it's easy:** padding is read live. `AMScreen.adjustedFrame()` (`Model/Screen.swift` ~L109) reads `UserConfiguration.screenPaddingTop/Bottom/Left/Right()` (`Preferences/UserConfiguration.swift` ~L713–727) on every reflow. Change the value, call `markAllScreensForReflow()` (`Managers/WindowManager.swift` ~L354), and it applies immediately.

**Config:**

```yaml
padding-modes:
  - name: full
  - name: wide
    top: 540
  - name: "27"            # quoted: a bare 27 is a number in YAML
    left: 640
    right: 640
    top: 720
padding-mode: full        # used only when no mode has been selected yet
```

Omitted sides default to 0. With no `padding-modes` defined, behaviour is identical to upstream.

**Implementation:**
- **Config keys:** `paddingModes = "padding-modes"` and `paddingMode = "padding-mode"` in `ConfigurationKey` (near `screenPaddingLeft` ~L94). Parse a `PaddingMode` struct the way `FloatingBundle` is parsed (~L149, `from(_:)`).
- **Active mode:** stored in `UserDefaults` under a key that is **not** a `ConfigurationKey`, so `loadConfiguration()` never overwrites it. It survives restarts. The YAML `padding-mode` applies only when nothing has been stored yet.
- **Single choke point:** `screenPadding*()` return the active mode's values when a mode is active, and the plain `screen-padding-*` keys otherwise. `disable-padding-on-builtin-display` keeps working unchanged, so the built-in panel stays unpadded.
- **Switching:** set the mode → `markAllScreensForReflow()` → HUD via `ScreenManager.displayCustomHUD(title:description:)` (~L397), e.g. `Padding · 27`, respecting `enables-layout-hud`.
- **Commands (unbound):**
  - `cycle-padding-mode` and `cycle-padding-mode-backward`, in list order with wrap-around.
  - `select-<name>-padding-mode`, generated like `select-<layout>-layout` (`UserConfiguration.swift` ~L434; `Events/HotKeyManager.swift` ~L275–285, ~L443).
- **Menu (optional):** a "Padding" submenu next to the layouts menu (`AppDelegate.swift` ~L229).

**Acceptance:**
- Switching reflows immediately, with no restart.
- Cycling wraps around.
- The last mode survives a restart.
- An unknown active name falls back to the plain `screen-padding-*` values.
- The built-in panel stays unpadded.

### 5.2 Command URL

- **What:** `amethyst://command/<command-key>` runs any command, bound or unbound: `cycle-padding-mode`, `select-27-padding-mode`, `focus-west`, `warp-east`, `swap-main`, `select-middle-wide-layout`, and so on.
- **Registry:** `HotKeyManager.constructCommandWithCommandKey` (`Events/HotKeyManager.swift` ~L363) currently passes handlers only to the hotkey binder (`UserConfiguration.constructCommand` ~L437). Also store every handler in a `[String: HotKeyHandler]` registry. Dynamic commands (layouts, padding modes) go through the same function, so they're included automatically.
- **URL handling:**
  - Register an `NSAppleEventManager` handler for `kInternetEventClass` / `kAEGetURL` in `applicationDidFinishLaunching` (`AppDelegate.swift` ~L35).
  - Declare `CFBundleURLTypes` with scheme `amethyst` in `Amethyst-Info.plist`.
  - Parse `command/<key>` and run the handler on the main thread.
- **Safety:** only registered command keys run. Anything else is logged and ignored. No config writes over the URL.

**Acceptance:**
- `open -g "amethyst://command/cycle-padding-mode"` switches mode without moving focus.
- Unbound commands work.
- An unknown key only logs.

### 5.3 Float secondary windows (anchor model)

**Idea (from BetterStage):** besides the per-app `floating` list, a list of apps whose *additional* windows float. Their Settings, plugin browsers, preference and Open windows float, with no title rules.

**Terminology (keep separate in code):**
- **Main** is the layout's main pane: Hans's focus window(s). It's per screen and independent of app.
- **Anchor** is what Hans calls the *parent app window*: the one real tiled window of a listed app on a space. It can sit in any pane.
- Name it `anchor` in code, **not** `parent`. `AXParent` already exists (for a window it points to the application), and macOS doesn't reliably expose which window opened which. The model is therefore order-based.

**Config:**

```yaml
floating-secondary-windows:
  - md.obsidian
```

Same id matching as `floating` (exact or `*` glob; reuse `runningApplicationFloatingBundle`'s glob logic, `UserConfiguration.swift` ~L568). It's a separate list, so it isn't caught up in `floating`'s "first match wins" rule.

**Rules:**
- **New window of a listed app:** floats if the app already has an anchor on this space. Otherwise it tiles and becomes the anchor.
- **Anchor floated manually:** it stays the anchor, so the app's next Settings window still floats.
- **Anchor closes:** the slot frees. A window of that app the user manually tiled on the space becomes the anchor; otherwise the next new window does. Floating secondaries never become the anchor automatically.
- **Scope: per space.** A second Obsidian vault on another space tiles there.
- **Bias:** when in doubt, float. A wrongly tiled window reshuffles the layout and can shrink main; a wrongly floated one costs a single mod1 + t.

**Implementation:**
- **State:** an anchor map `[pid + spaceID → windowID]` in `Managers/Windows.swift`, next to `lastMainWindows` (~L15).
- **Decision point:** `WindowManager.determineFloatForWindow` (`Managers/WindowManager.swift` ~L491). It has access to `windows` (`windows(forApplicationWithPID:)`, `Windows.swift` ~L26; the space comes from `CGWindowsInfo.windowSpace`, used at ~L45). If the app is listed and has a live anchor on the window's space, return floating. Otherwise fall through to the existing rules, and register the window as anchor once it's tracked.
- **Only ever forces floating.** `floating`, title rules and `float-small-windows` still apply.
- **Removal:** `remove(window:)` (`Windows.swift` ~L96) clears the slot and promotes a manually tiled window if there is one.
- **Startup:** discovery order is arbitrary, so make the **largest** standard window of each listed app per space the anchor.
- **Manual toggle wins:** mod1 + t on a secondary tiles it, but it doesn't take the anchor role while the anchor is alive.
- **Known race:** an app restoring several windows at once may get more than one tiled. Acceptable; document it.
- **Known limitations (as built):**
  - The anchor role stays with a window's original space if the window is dragged to another space.
  - Minimising the anchor frees its slot; the next new window then tiles and becomes the anchor.
  - An app that only hides its window on close (keeps it alive, off every space) keeps the anchor role, so its later windows float. Liveness checks that the window still exists, not that it sits on a space. Treated as an edge case: Obsidian destroys its windows.
  - Floating secondaries don't count towards `window-max-count` (only tiled windows do). If the limit minimises the anchor, the slot frees as with a manual minimise.
  - Obsidian pop-out windows count as secondary windows and float (toggle-float tiles one).
  - The tests run inside the Debug app, which no longer manages windows or asks for Accessibility when hosting tests.

**Acceptance:**
- Obsidian main window tiles; Settings, Community plugins and Community themes float with **no** Obsidian `window-titles` entry.
- A second vault on another space tiles.
- Relaunching Amethyst with main + Settings open keeps main tiled and Settings floating.
- Floating the anchor, then opening Settings: Settings floats.
- Closing the anchor leaves Settings floating, and the next new window tiles as the new anchor.
- A floating secondary never changes the main pane, the ratio or the column sizes.
- Unlisted apps behave exactly like upstream.

### 5.4 Directional focus and swap

**Commands (unbound):** `focus-west`, `focus-east`, `focus-north`, `focus-south`, `swap-west`, `swap-east`, `swap-north`, `swap-south`. Warp (§5.5) reuses the same neighbour finder.

**The neighbour finder** is a pure function, easy to unit-test without windows. Put it in a new file, `Managers/DirectionalNavigation.swift`, with tests in `AmethystTests/Tests/Managers/DirectionalNavigationTests.swift`:

```
neighbor(of focused, direction, frames: [WindowID: CGRect], frontToBack: [WindowID], mru: [WindowID]) -> WindowID?
```

- **Frames:** use the layout's **assigned** frames, *before* window margins. `FrameAssignment.frame` is pre-margin; margins are applied when the assignment is performed (`Layout/ReflowOperation.swift` ~L129). Store the last assignment per screen in `ScreenManager.reflow()` (`Managers/ScreenManager.swift` ~L267). Neighbours then share an exact edge, so Hans's 8 pt margins can't confuse the comparison. Live frames are not used, because apps with minimum sizes can refuse their frame and overlap.
- **Candidates:** tiled windows on the same screen and space that lie **strictly** in the direction (for west: `candidate.maxX <= focused.minX + 1`).
- **Visibility rule:** directions only reach windows you can see.
  - Hidden and minimised windows (⌘H, minimise, `window-max-count`) are never tracked as active, so they're out of scope automatically.
  - When several candidates share an identical frame (Two Pane's secondary stack), only the **frontmost** counts. Use front-to-back order from `CGWindowsInfo` (`Model/CGInfo.swift`, `Model/WindowsInformation.swift`).
- **Ranking:**
  1. Largest overlap on the perpendicular axis (vertical overlap for west/east).
  2. Smallest gap along the direction.
  3. **Most recently focused.** Going east, then west, then east returns to the same window.
  4. Nearest centre.
  - If no candidate overlaps at all, take the nearest centre in that half-plane.
- **MRU list:** per space, updated on focus change (where `WindowManager` distributes `.focusChanged`). Keep it in `Windows.swift` next to `lastMainWindows`.
- **Floating windows:** allowed as the *starting* window (using its live frame, e.g. from Settings back into the layout), never as a target.
- **Screen edge:** no neighbour → no-op. No wrap-around and no crossing to another display. Document this as a known limitation.

**Behaviour per layout:**

| Layout | focus-west/east | focus-north/south | swap-<dir> |
|---|---|---|---|
| 3Column, Tall, others | spatial | spatial | spatial |
| Two Pane | spatial; east from main lands on the visible secondary | spatial (no-op in practice) | spatial |
| **Fullscreen (exception)** | previous/next through the stack, wrapping; reuse `FocusTransitionCoordinator.moveFocusCounterClockwise/Clockwise` (~L50–100) | no-op | no-op |

**Actions:**
- **focus:** call the target's `focus()` (`Model/Window.swift` ~L300). It already moves the cursor, matching Hans's `mouse-follows-focus: true`.
- **swap:** run the existing `.switchWindows(focused, target)` transition (`WindowManager.executeTransition` ~L918). Focus stays on the moved window, as with upstream swaps. In 3Column, column sizes don't change.

**Wiring:** command keys go in the `CommandKey` enum (`UserConfiguration.swift`, near `swapCW` ~L125). Hotkeys and the preferences label go in `HotKeyManager.swift` (~L186, ~L413).

**Acceptance:**
- **3Col Left with columns 1/3/1:**
  - From main, east → the window you last used in the middle column (the middle one if none).
  - West → main. East again → the same middle window.
  - From the right column, west → the most recently used middle window.
- **Tall:** west/east cross between main and the stack; north/south move within the stack.
- **Two Pane:** east from main → the visible secondary; hidden stacked windows are never reached.
- **Fullscreen:** west/east cycle through all windows with wrap-around; north/south do nothing.
- **Floating start:** from a floating Settings window, west/east reach the nearest tiled window in that direction.
- **Edge:** focus-west from a left-edge window does nothing.
- **Swap:** swap-east from main exchanges it with the chosen neighbour; the cursor follows.

### 5.5 Warp

**Commands (unbound):** `warp-west`, `warp-east`, `warp-north`, `warp-south`. The target is always found with the §5.4 neighbour finder, so warp stays correct after rotate/mirror.

**One implementation for all 3Column variants.** 3Column Left, Middle (`middle-wide`) and Right are thin subclasses of one base class, `ThreeColumnLayout` (~L148). They differ only in `class var mainColumn` (~L257–272). Build everything below **once, in the base class**; all three variants inherit it. The table below matters only for mapping directions to columns.

**3Column today** (`Layout/Layouts/ThreeColumnLayout.swift`, `TriplePaneArrangement` ~L29–145): the window list is split into contiguous slices `main | secondary | tertiary`, sized `M | ceil(r/2) | floor(r/2)` (r = n − M) and recalculated on every reflow.

| Pane | 3Col Left | 3Col Middle |
|---|---|---|
| main | left column | middle column |
| secondary | middle column | left column |
| tertiary | right column | right column |

**3Column model:**
- **Keep the list pane-contiguous**, as upstream. focus-cw/ccw, swap-main and mouse drag-swap then keep working unchanged, because they all operate on list order.
- **Column sizes are stored state:** the existing `mainPaneCount` plus a new `secondaryPaneCount`, with tertiary = n − main − secondary. If n shrinks without a remove event (hidden or minimised windows, `window-max-count`), clamp from tertiary first, then secondary.
- **Make `ThreeColumnLayout` a `StatefulLayout`** (`Layout/Layout.swift` ~L213) so it receives `.add` and `.remove`. Its `nextWindowIDClockwise/CounterClockwise` return `nil`, and focus then falls back to list order, exactly as `CustomLayout` (~L281) does. *(This corrects an earlier draft, which advised against `StatefulLayout`.)*
- **Snapshot:** keep a `windowID → pane` map from the last `frameAssignments` to attribute removals.
- **Remove from a side column:** that column shrinks by one.
- **Remove from main:** `mainPaneCount` is unchanged and secondary shrinks by one, so the first side window slides into main, as upstream does. Main never empties while windows exist.
- **Add:** the shorter side column; on a tie, secondary. Additions one at a time reproduce upstream exactly: 1/0/0 → 1/1/0 → 1/1/1 → 1/2/1 → 1/2/2. Never main.
  - Amethyst appends new windows at the list end, which is already the tertiary slice. For secondary, insert after the last secondary window.
  - Add a layout hook, e.g. `insertionIndex(forNewWindowAmong:) -> Int?` (default `nil` = append), consulted in `WindowManager.track(window:application:afterWindow:)` (~L505).
  - With `new-windows-to-main: true`, keep upstream's behaviour.

**Warp actions:**

| Layout | west/east | north/south |
|---|---|---|
| 3Column | The window joins the neighbour's column, placed **directly below the neighbour**. Sizes adjust (source −1, target +1); into main → `mainPaneCount + 1`, out of main → −1. If main would empty, the first window of the next column slides in. In 3Col Middle, west from the right column lands in main (centre). | Swap with the neighbour in the same column (existing `.switchWindows`). No-op at the column edge. |
| Tall | Same as 3Column with a single boundary. West from the stack joins main (`mainPaneCount + 1`); east from main joins the stack (−1; main never empties). No stored side sizes needed. | Swap within the same pane. |
| Two Pane | Swap with main (the `swapFocusedWindowToMain` path, `Managers/WindowTransitionCoordinator.swift` ~L45). | No-op. |
| Fullscreen, everything else | No-op. | No-op. |

**Plumbing:**

| What | Where |
|---|---|
| Transition `.warpWindow(window, direction)` + coordinator method | `Managers/WindowTransitionCoordinator.swift` (enum at top; method next to `swapFocusedWindowClockwise()` ~L91) |
| The layout computes the target index and new sizes (indices after removing the moving window) | `ThreeColumnLayout`, `TallLayout` |
| List move `move(window:toIndex:)` | `Managers/Windows.swift`, next to `swap` ~L134; mirror its `lastMainWindows` bookkeeping |
| Execute + reflow | `WindowManager.executeTransition` ~L918, following the `.switchWindows` pattern |
| Command keys + hotkeys | `UserConfiguration.swift` `CommandKey` (~L125); `HotKeyManager.swift` (~L186, ~L413) |

**Persistence:** encode `mainPaneCount`, `mainPaneRatio`, `secondaryPaneCount` (`decodeIfPresent`; missing means balanced). Never persist window IDs; clamp to the current n on restore.

**Acceptance:**
- 3Col Left, 5 windows, M = 1 → 1/2/2. Warp a right-column window west → 1/3/1. Close a middle-column window → 1/2/1 (right column untouched).
- Opening windows one at a time gives exactly upstream's sizes.
- Tall: warp west from the stack grows main to 2 windows; warp east shrinks it back.
- Two Pane: warp east from main swaps it with the visible secondary.
- increase/decrease main, focus/swap (directional and cw/ccw), swap-main, mouse drag-swap and drag-resize (`recommendMainPaneRawRatio` ~L242) all still behave.
- An upstream saved state decodes cleanly.
- Unit tests in `ThreeColumnLayoutTests.swift` and `TallLayoutTests.swift` cover add, remove, warp and clamping.

### 5.6 Rotate / mirror

- **Approach:** a post-transform on frame assignments, so every layout benefits (Tall rotated = Wide, 3Col → 3Row). Hook it in `ScreenManager.reflow()` (~L248) where `layout.frameAssignments(windows, on: screen)` is called (~L267), or put a helper on the `Layout` base class.
- **Transform:** work inside `FrameAssignment.screenFrame` (`Layout/ReflowOperation.swift` ~L129). That frame already has padding applied, so rotation stays inside the active padding mode.
  - Mirror-x: `x' = sx + sw − (x − sx) − w`.
  - Transpose: swap normalised x/y and scale by `sw/sh`.
- **Store the transformed frames** for the §5.4 neighbour finder, so directions stay visually correct.
- **Mouse resize:** flip `ResizeRules.unconstrainedDimension` (`ReflowOperation.swift` ~L28) when rotated.
- **State:** an orientation flag per layout instance, persisted with `decodeIfPresent`.
- **Commands (unbound):** `rotate`, `mirror-x`, `mirror-y`.
- **Cockpit mode:** Two Pane already switches orientation by itself on vertical screens, and the Ark can pivot. Make sure Two Pane's own switch and rotate don't fight.

## 6. Hans's config after the fork (target)

Add or replace these parts of the fork's `~/.config/hw-amethyst/amethyst.yml` as each phase lands (upstream's file stays as it is):

```yaml
# Phase 1 — padding modes (replaces screen-padding-top: 540 etc.)
padding-modes:
  - name: full
  - name: wide
    top: 540
  - name: "27"
    left: 640
    right: 640
    top: 720
cycle-padding-mode:
  mod: mod1
  key: p                   # suggestion; pick any free key

# Phase 3 — secondary windows (then drop the md.obsidian title entry)
floating-secondary-windows:
  - md.obsidian

floating: [
  "com.apple.calculator",
  "org.hammerspoon.Hammerspoon",
  "net.duoziwei.KeepTop",
  "com.aone.keka",
  "com.hegenberg.KeyboardCleanTool",
  "com.raycast.macos",
  "com.knollsoft.Hookshot",
  "cc.ffitch.shottr",
  "pro.betterdisplay.BetterDisplay",
  "com.apple.systempreferences",
  "com.apple.finder",
  {id: "*", window-titles: ["^(Open|Save)$"]}]   # fallback for apps not on the secondary list

# Phases 4–5 — suggested scheme: h/j/k/l = direction, modifier = verb
mod3:                      # new modifier set for warp
  - option
  - control
  - shift

focus-ccw: false           # previous/next retired: an Alt-Tab app covers it
focus-cw: false
swap-ccw: false
swap-cw: false

focus-west:  {mod: mod1, key: h}
focus-south: {mod: mod1, key: j}
focus-north: {mod: mod1, key: k}
focus-east:  {mod: mod1, key: l}

swap-west:   {mod: mod2, key: h}
swap-south:  {mod: mod2, key: j}
swap-north:  {mod: mod2, key: k}
swap-east:   {mod: mod2, key: l}

warp-west:   {mod: mod3, key: h}
warp-south:  {mod: mod3, key: j}
warp-north:  {mod: mod3, key: k}
warp-east:   {mod: mod3, key: l}
```

`focus-main` / `swap-main` (mod1/mod2 + m) and everything else stay as they are. Setting a command to `false` disables it (`UserConfiguration.constructCommand` ~L442).

## 7. Raycast after the fork

*(Updated after phase 1: cycling is bound natively in hw-Amethyst (Super+0 = `cycle-padding-mode` with `mod4: [option, control, shift, command]`), so the "Cycle Amethyst Layout Mode" script and its hotkey are retired. Hans then disabled the dropdown script as well; padding is switched only with Super+0 or the Padding submenu. The snippet below is kept for reference, in case a script is wanted again after phase 2.)*

The remaining dropdown script shrinks to one line, with no YAML edits and no restart:

```bash
# Amethyst Layout Mode (keep the existing @raycast.argument1 dropdown: full / wide / 27)
open -g "amethyst://command/select-$1-padding-mode"
```

## 8. Reference: things learned

- **`floating` matching** (blacklist mode, the default):
  - An entry with no `window-titles` floats every window of the app; with titles, only windows whose title matches float.
  - Patterns are regexes, **unanchored and case-sensitive**: use `^…$` and `(?i)`.
  - **The first matching entry wins; entries never combine.** Put specific entries before `"*"`.
- **Caret trap:** ⌥I on macOS produces `ˆ` (U+02C6), not `^` (⇧6).
- **Obsidian** (`md.obsidian`, v1.14.4) titles every window `<tab> - <vault> - Obsidian <version>`, Settings included.
- **Window titles of an app:** `osascript -e 'tell application "System Events" to get name of every window of process "<App>"'`.
- **Unspecified commands keep upstream's default key** under Hans's own mod definitions (`UserConfiguration.constructCommand` ~L446–453). Check for collisions when binding new keys.

---

## Appendix A: if this is ever released publicly

Not planned. Kept for reference.

- **Licence:** MIT. Keep `LICENSE.md` with "Copyright (c) 2015 Ian Ynda-Hummel" and add your own line. Ship an acknowledgements file for the dependencies (RxSwift, Yams, SwiftyJSON, SwiftyBeaver, Sparkle, Silica, Cartography, LoginServiceKit, swift-argument-parser; all permissive).
- **Identity:** the licence covers code, not name or icon. Use your own name and icon, and say "Based on Amethyst by Ian Ynda-Hummel" in the README and the About window.
- **Signing:** Apple Developer Program (US$99/year) → Developer ID certificate → sign, notarize and staple. Without it, macOS blocks downloaded copies.
- **Distribution and updates:** GitHub Releases plus your own Homebrew tap. Sparkle pointed at your own update feed, signed with your own key.
- **Support scope:** state the tested setup in the README (single display, macOS version). Cross-display directional navigation would become a requirement.
- **Courtesy:** tell the upstream maintainer about the fork; offer the generic features as pull requests.
