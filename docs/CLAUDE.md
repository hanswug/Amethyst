# Amethyst fork (personal)

A personal fork of Amethyst, the tiling window manager, for Hans. The full plan, every decision and all specs are in `docs/AMETHYST_FORK_HANDOFF.md`. That file is the source of truth.

## At the start of every session

1. Read `docs/AMETHYST_FORK_HANDOFF.md` §1–§4 (context, locked decisions, ground rules, build plan).
2. Read the spec section for the **current phase** (see Status below).
3. Check `git status` and the current branch before changing anything.

## How we work

- **One phase per session**, one branch per phase, named as in §4 of the handover, branched off `fork/main` (not `development`; see §3 rule 1). When the phase is done and tested, merge it into `fork/main` and rebuild with `scripts/build.sh` from `fork/main`.
- **Plan first.** Propose the plan for the phase and wait for Hans to approve it before editing files.
- **Decisions are locked.** If the code contradicts the handover (wrong path, different behaviour, a decision that can't work), stop and ask Hans. Don't improvise a different design.
- **Hans does the GUI steps himself:** creating the self-signed certificate in Keychain Access, granting Accessibility, picking the fork's name and bundle ID. Stop and tell him exactly what to do.
- **Never use the `fastlane` lane.** It signs with upstream's Developer ID team. Build with `scripts/build.sh` once phase 0 has created it.
- **Tests:** add or extend unit tests for every behaviour change, and run the test suite with `scripts/test.sh` before declaring a phase done. Plain `xcodebuild test` fails on this machine: Xcode 27 rejects upstream's macOS 11 deployment target, and 4 Fullscreen layout tests pick up Hans's real YAML margins. The script handles both.
- **Fork facts:** the app is `/Applications/hw-Amethyst.app`, bundle ID `com.ark.Amethyst`; Debug/test host is `com.ark.Amethyst.debug`. The executable and module are still `Amethyst`. Config: the fork reads `~/.config/hw-amethyst/amethyst.yml` only; upstream's `~/.config/amethyst/amethyst.yml` is its frozen fallback config and is never edited. Upstream `Amethyst.app` (brew cask) stays installed as a fallback; never run both at once.
- **Installs:** use Homebrew when a brew route exists (SwiftLint, needed by the Lint build phase, comes from brew).
- **Commits** end with `Co-Authored-By: HW+CC`.
- **Profiling:** `scripts/profile.sh` when something feels slow; see `docs/PROFILING.md`.
- **With no new config keys set, the fork must behave exactly like upstream** (ground rule 6).
- **When a phase is done,** update Status below, summarise what changed, and list anything Hans must do by hand (bindings, config, re-granting permissions).

## Status

- [x] Phase 0: fork setup and baseline (§5.0) — branch `fork/setup`
- [x] Phase 1: padding modes (§5.1) — Super+0 (mod4 = ⇧⌃⌥⌘) cycles natively; both Raycast padding scripts are retired
- [x] Phase 3: float secondary windows (§5.3) — `floating-secondary-windows: [md.obsidian]`; the Obsidian title rule is commented out in the fork config
- [ ] Phase 4: directional focus and swap (§5.4)
- [ ] Phase 5: warp (§5.5)
- [ ] Phase 6: rotate / mirror (§5.6)
- [x] Phase 2: command URL (§5.2) — built early as a detour; `open -g "amethyst://command/<key>"` runs any command

**Current phase:** detour — command palette (Super+Y = `show-command-palette` with `mod4` + `y`), built on the phase 2 command registry. **Then back to phase 4** (directional focus and swap), then 5, 6, then the Raycast extension.

**Command palette (detour, next):** an in-app panel listing every registered command (`HotKeyManager.commandHandlers`, names from `hotKeyNameToDefaultsKey()`) with its current shortcut; type to filter, Enter runs. It must close and give focus back to the previously focused window before running the command. Bound to Super+Y; check that Raycast doesn't hold that key.

**After all phases succeed:** build a dedicated Raycast extension for hw-Amethyst on top of the command URL. The Raycast dropdown script was retired (moved to the Trash). `~/raycast-scripts/cycle-amethyst-padding.sh` is the old upstream version: it rewrites upstream's config, kills hw-Amethyst and launches upstream. It ran by accident on 2026-10-10 10:18; never run it.
