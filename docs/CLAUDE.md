# Amethyst fork (personal)

A personal fork of Amethyst, the tiling window manager, for Hans. The full plan, every decision and all specs are in `docs/AMETHYST_FORK_HANDOFF.md`. That file is the source of truth.

## At the start of every session

1. Read `docs/AMETHYST_FORK_HANDOFF.md` §1–§4 (context, locked decisions, ground rules, build plan).
2. Read the spec section for the **current phase** (see Status below).
3. Check `git status` and the current branch before changing anything.

## How we work

- **One phase per session**, one branch per phase, named as in §4 of the handover, branched off `fork/main` (not `development`; see §3 rule 1). When the phase is done and tested, merge it into `fork/main` and rebuild with `scripts/build.sh` from `fork/main`.
- **Plan first.** Propose the plan for the phase and wait for Hans to approve it before editing files.
- **Trial before merge (from 2026-10-10, for unexplored features: palette, directional navigation, warp, overflow policy, …).** Not hardcore: small steps instead of letting features flow into `fork/main`. Keep the feature on its branch, build and install **from that branch**, let Hans give it a couple of tries, and merge into `fork/main` only when he says to keep it. Regret = rebuild `fork/main`. Where cheap, give behaviour changes a config on/off key so old and new can be compared without rebuilding. If two trials overlap, build a temporary combination branch; `fork/main` stays "approved only". We're now in quality-of-life territory: prefer small, reversible steps.
- **Decisions are locked.** If the code contradicts the handover (wrong path, different behaviour, a decision that can't work), stop and ask Hans. Don't improvise a different design.
- **Hans does the GUI steps himself:** creating the self-signed certificate in Keychain Access, granting Accessibility, picking the fork's name and bundle ID. Stop and tell him exactly what to do.
- **Never use the `fastlane` lane.** It signs with upstream's Developer ID team. Build with `scripts/build.sh` once phase 0 has created it.
- **Tests:** add or extend unit tests for every behaviour change, and run the test suite with `scripts/test.sh` before declaring a phase done. Plain `xcodebuild test` fails on this machine: Xcode 27 rejects upstream's macOS 11 deployment target, and 4 Fullscreen layout tests pick up Hans's real YAML margins. The script handles both.
- **Fork facts:** the app is `/Applications/hw-Amethyst.app`, bundle ID `com.ark.Amethyst`; Debug/test host is `com.ark.Amethyst.debug`. The executable and module are still `Amethyst`. Config: the fork reads `~/.config/hw-amethyst/amethyst.yml` only; upstream's `~/.config/amethyst/amethyst.yml` is its frozen fallback config and is never edited. Upstream `Amethyst.app` (brew cask) stays installed as a fallback; never run both at once.
- **Config-only (2026-10-10):** the config file is the only source of settings and keys. A command is bound only if the file binds it (left out, `false` or `<NONE>` = unbound; no built-in default keys), and with a file present, keys it leaves out get built-in defaults on every load, never leftovers. There is no preferences window: the menu has **Edit Config…** (opens the file) and **Reload Config** (relaunch). The menu bar shows the current layout's name next to the icon.
- **Installs:** use Homebrew when a brew route exists (SwiftLint, needed by the Lint build phase, comes from brew).
- **Commits** end with `Co-Authored-By: HW+CC`.
- **Profiling:** `scripts/profile.sh` when something feels slow; see `docs/PROFILING.md`.
- **hw-Amethyst is its own app** (ground rules 2 and 6): design for Hans's setup, no hidden inherited defaults; upstream is only the fallback app and a source of occasional fixes. Don't frame decisions or wording around upstream.
- **When a phase is done,** update Status below, summarise what changed, and list anything Hans must do by hand (bindings, config, re-granting permissions).

## Start here (next session)

1. **Command palette** on branch `feat/command-palette` off `fork/main`, under the trial rule (install from the branch, Hans tries it, merge only on "keep it"). Command `show-command-palette`, bound in Hans's config to Super+Y (`mod4` + `y`). Lists every command from `HotKeyManager.commandHandlers` with names from `hotKeyNameToDefaultsKey()` and current keys; type to filter, Enter runs; closes and restores focus to the previous window before running.
2. **Phase 4: directional focus and swap** (§5.4), designed by §3b: ≤ 8 windows, a mental ≤ 4×2 grid, simple rules, only visible windows, Two Pane = main + slot, Fullscreen = west/east cycle. Bindings per §6: focus on ⌃⌥ + h/j/k/l, swap on ⌃⌥⌘ + h/j/k/l; test on spare keys first, rebind h/j/k/l only at the end.
3. **Backlog of small ideas** (each behind a config switch where cheap): overflow policy (9th window floats instead of minimising the oldest, `ScreenManager.minimizeWindows`); `max-column-rows: 3` for side columns; fix the `debug windows` crash (`Amethyst/Debug/WindowsInfo.swift` force-unwrap).
4. **Hans's side, optional:** make Zed the default for `.yml` (Finder → ⌘I → Open with → Change All) so Edit Config… opens Zed.

Repo: `origin` = github.com/hanswug/Amethyst (public fork, `fork/main` pushed), `upstream` = ianyh/Amethyst. `gh` is installed and logged in. Discussion with Ian: github.com/ianyh/Amethyst/discussions/1895.

## Status

- [x] Phase 0: fork setup and baseline (§5.0) — branch `fork/setup`
- [x] Phase 1: padding modes (§5.1) — Super+0 (mod4 = ⇧⌃⌥⌘) cycles natively; both Raycast padding scripts are retired
- [x] Phase 3: float secondary windows (§5.3) — `floating-secondary-windows: [md.obsidian]`; the Obsidian title rule is commented out in the fork config
- [ ] Phase 4: directional focus and swap (§5.4)
- [ ] Phase 5: warp (§5.5)
- [ ] Phase 6: rotate / mirror (§5.6)
- [x] Phase 2: command URL (§5.2) — built early as a detour; `open -g "amethyst://command/<key>"` runs any command

**Current phase:** detour — config-only is done (slices 1–2 + layout title); a broken config file now shows "Error in configuration file" + path and quits (no debugging help by design); no config file → "No configuration file found" + path, quit; the preferences-window code is deleted. Next: the command palette (Super+Y = `show-command-palette`), **then back to phase 4** (directional focus and swap), then 5, 6, then the Raycast extension.

**Command palette (detour, next):** an in-app panel listing every registered command (`HotKeyManager.commandHandlers`, names from `hotKeyNameToDefaultsKey()`) with its current shortcut; type to filter, Enter runs. It must close and give focus back to the previously focused window before running the command. Bound to Super+Y; check that Raycast doesn't hold that key.

**After all phases succeed:** build a dedicated Raycast extension for hw-Amethyst on top of the command URL. The Raycast dropdown script was retired (moved to the Trash). `~/raycast-scripts/cycle-amethyst-padding.sh` is the old upstream version: it rewrites upstream's config, kills hw-Amethyst and launches upstream. It ran by accident on 2026-10-10 10:18. It ran again at 10:47 despite its execute bit being removed (Raycast runs scripts through their interpreter), so it is now renamed `cycle-amethyst-padding.sh.old`: kept as a reminder of the starting point, invisible to Raycast; never run it.
