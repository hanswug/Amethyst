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
- [x] Phase 1: padding modes (§5.1) — Super+0 (mod4 = ⇧⌃⌥⌘) cycles natively; the Raycast cycle script is retired
- [ ] Phase 2: command URL (§5.2)
- [ ] Phase 3: float secondary windows (§5.3)
- [ ] Phase 4: directional focus and swap (§5.4)
- [ ] Phase 5: warp (§5.5)
- [ ] Phase 6: rotate / mirror (§5.6)

**Current phase:** 2
