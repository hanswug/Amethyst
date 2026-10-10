# Amethyst fork (personal)

A personal fork of Amethyst, the tiling window manager, for Hans. The full plan, every decision and all specs are in `docs/AMETHYST_FORK_HANDOFF.md`. That file is the source of truth.

## At the start of every session

1. Read `docs/AMETHYST_FORK_HANDOFF.md` §1–§4 (context, locked decisions, ground rules, build plan).
2. Read the spec section for the **current phase** (see Status below).
3. Check `git status` and the current branch before changing anything.

## How we work

- **One phase per session**, one branch per phase, named as in §4 of the handover.
- **Plan first.** Propose the plan for the phase and wait for Hans to approve it before editing files.
- **Decisions are locked.** If the code contradicts the handover (wrong path, different behaviour, a decision that can't work), stop and ask Hans. Don't improvise a different design.
- **Hans does the GUI steps himself:** creating the self-signed certificate in Keychain Access, granting Accessibility, picking the fork's name and bundle ID. Stop and tell him exactly what to do.
- **Never use the `fastlane` lane.** It signs with upstream's Developer ID team. Build with `scripts/build.sh` once phase 0 has created it.
- **Tests:** add or extend unit tests for every behaviour change, and run the test suite before declaring a phase done.
- **With no new config keys set, the fork must behave exactly like upstream** (ground rule 6).
- **When a phase is done,** update Status below, summarise what changed, and list anything Hans must do by hand (bindings, config, re-granting permissions).

## Status

- [ ] Phase 0: fork setup and baseline (§5.0)
- [ ] Phase 1: padding modes (§5.1)
- [ ] Phase 2: command URL (§5.2)
- [ ] Phase 3: float secondary windows (§5.3)
- [ ] Phase 4: directional focus and swap (§5.4)
- [ ] Phase 5: warp (§5.5)
- [ ] Phase 6: rotate / mirror (§5.6)

**Current phase:** 0
