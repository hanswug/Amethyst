#!/usr/bin/env bash
#
# Records a Time Profiler trace of the running fork and prints a summary.
# Run it when Amethyst feels slow, then keep using the Mac normally.
#
#   scripts/profile.sh [duration]     # duration as xctrace takes it; default 10m
#
# Traces go to build/profiles/ (gitignored). Open a .trace in Instruments for
# the full call tree. See docs/PROFILING.md.

set -euo pipefail

DURATION="${1:-10m}"
APP_PATH="/Applications/Ametrine.app"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${REPO_ROOT}/build/profiles"
STAMP="$(date +%Y%m%d-%H%M%S)"
TRACE="${OUT_DIR}/amethyst-${STAMP}.trace"

PID="$(pgrep -f "${APP_PATH}/Contents/MacOS/Amethyst" | head -1 || true)"
if [[ -z "$PID" ]]; then
    echo "error: ${APP_PATH} is not running." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
echo "==> Recording ${DURATION} of Time Profiler on pid ${PID} → ${TRACE}"
xcrun xctrace record --template 'Time Profiler' --attach "$PID" \
    --time-limit "$DURATION" --output "$TRACE"

echo "==> Summary"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
xcrun xctrace export --input "$TRACE" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > "$TMP/tp.xml"
xcrun xctrace export --input "$TRACE" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="potential-hangs"]' > "$TMP/hangs.xml"
python3 "${REPO_ROOT}/scripts/analyze-time-profile.py" "$TMP/tp.xml" "$TMP/hangs.xml"
