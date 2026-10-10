# Profiling baseline

Phase 0 baseline (handover §5.0). Question: when Amethyst feels slow or quirky, is the cost inside Amethyst, or is an app flooding it with Accessibility notifications?

## Baseline: 2026-10-10

| | |
|---|---|
| Build | `hw-Amethyst` (fork at `093deec`, functionally upstream `6508ee2`), Release |
| Machine | personal Mac, macOS 27.0, Xcode 27.0, Ark display |
| Method | Instruments Time Profiler attached to the running app, 20 min of normal work (`xctrace record --attach`) |

**Result: Amethyst is essentially idle. There's no measurable cost and no flood.**

- **CPU:** 274 ms over 20 min (≈ 0.02 %), 84 % of it on the main thread.
  - 220 ms of that fell in the first minute; every later minute stayed under 15 ms.
- **Hangs:** Instruments' potential-hangs table recorded none. The main thread was never unresponsive for ≥ 250 ms.
- **Terminal stall:** Hans noticed one about 3 min in. Amethyst used 1–7 ms of CPU per minute around then, so it wasn't the cause.
- **Where the little CPU went (inclusive):**
  - AX notification handling (`ApplicationObservation.handle`): 55 ms.
  - Computing active windows per screen (`Windows.activeWindows(onScreen:)`): 51 ms. It filters every window via `AXWindow.screen()` / `frame` / `pid()`, each an AX IPC round trip.
  - `application(_:didMoveWindow:)`: 38 ms.
  - Mouse drag-swap (`swapDraggedWindowWithDropzone`): 26 ms.
  - Reflow (`ScreenManager.setNeedsReflow`): 18 ms.
- **AX notification flood:** no sign of one. A flood would show up as sustained CPU in `observerCallback` → `ApplicationObservation.handle`, and the total was 55 ms in 20 min. A separate per-app notification count (`--log`) was therefore skipped.

### What this doesn't rule out

Time Profiler only samples threads that are **running**. When Amethyst waits on a synchronous AX call to an app that is busy or hung, its thread is blocked, not running, so the wait barely shows up as CPU. Such waits would cause sluggish tiling without CPU cost. If they reached 250 ms on the main thread, they would appear as potential hangs; none did in this session. The slowdown is occasional and simply didn't happen during this recording.

## When the slowdown happens again

1. As soon as it feels slow, run `scripts/profile.sh 5m` and keep doing whatever triggered it.
   - It attaches Time Profiler to the running `hw-Amethyst` and saves the trace to `build/profiles/`.
   - It then prints CPU per thread and per minute, the top self and inclusive frames, and the potential hangs (`scripts/analyze-time-profile.py`).
2. Read the result:
   - **High CPU in `observerCallback` / `ApplicationObservation.handle`, especially `didMoveWindow`/resize:** an app is flooding notifications. Find it with step 3.
   - **Potential hangs with `mach_msg` at the bottom of the main-thread stack:** Amethyst is blocked on a slow app's AX reply. Open the trace in Instruments and see which AX call; `-[SIAccessibilityElement …]` frames name the attribute.
   - **High CPU in `activeWindows(onScreen:)` / `windowSet(forWindowsOnScreen:)`:** the per-reflow window filtering is the cost. That's a candidate for caching screen membership.
   - **Nothing in Amethyst:** look elsewhere (WindowServer, the app itself), e.g. Activity Monitor or Instruments "All Processes".
3. Per-app notification count (only if step 2 points at a flood):
   - Quit hw-Amethyst and start it with logging, written to a file: `open --stdout build/profiles/amethyst.log --stderr build/profiles/amethyst.log -a /Applications/hw-Amethyst.app --args test --log`. (A bare `--log` is rejected by the argument parser; `test` is the entry point that skips it. Launching through `open` keeps it a normal app launch; started directly from a terminal it may not pick up every app.)
   - Reproduce, then count `Received notification for window:` lines grouped by window ID.
   - Map the IDs to apps with the window list, e.g. `.../Contents/MacOS/Amethyst debug windows --include-unmanaged`.
   - That CLI currently crashes; see below.

In zsh, `log` is a shell built-in; use `/usr/bin/log` for macOS's unified log. Amethyst's own messages appear there redacted (`<private>`), hence the file above.

## Known issue found while profiling

`Amethyst debug windows` exits with SIGTRAP (status 133) in `Windows.run()`, in the fork and in upstream 0.24.3 alike. It's likely the force-unwrap `AXWindow(element: window)!` in `Amethyst/Debug/WindowsInfo.swift`. It isn't fixed in phase 0; it's a small upstream PR candidate.
