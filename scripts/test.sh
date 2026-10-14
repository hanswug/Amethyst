#!/usr/bin/env bash
#
# Runs the unit tests (Debug, ad-hoc signed; no certificate needed).
#
# The test host is the Debug app, which loads the Amethyst config and persists
# it into its preferences domain. Some layout tests assume the defaults (e.g.
# no window margins), so run against an empty config and a clean domain to keep
# results independent of this Mac's setup. Debug has its own bundle ID, so the
# installed Release app's preferences are never touched.
#
# Extra arguments go to xcodebuild, e.g. -only-testing:AmethystTests/TallLayoutTests

set -euo pipefail

TEST_HOST_BUNDLE_ID="com.ark.Ametrine.debug"
# Upstream targets macOS 11, which Xcode 27 no longer accepts (minimum 12).
DEPLOYMENT_TARGET="12.0"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

EMPTY_CONFIG_HOME="$(mktemp -d)"
cleanup() {
    rm -rf "$EMPTY_CONFIG_HOME"
    defaults delete "$TEST_HOST_BUNDLE_ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT
defaults delete "$TEST_HOST_BUNDLE_ID" >/dev/null 2>&1 || true

TEST_RUNNER_XDG_CONFIG_HOME="$EMPTY_CONFIG_HOME" xcodebuild \
    -workspace Amethyst.xcworkspace \
    -scheme Amethyst \
    -configuration Debug \
    -derivedDataPath build/DerivedData \
    -quiet \
    MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    -resultBundlePath "$EMPTY_CONFIG_HOME/result.xcresult" \
    test "$@" || status=$?

xcrun xcresulttool get test-results summary --path "$EMPTY_CONFIG_HOME/result.xcresult" 2>/dev/null \
    | python3 -c 'import json, sys; d = json.load(sys.stdin); print("==> {}: {} passed, {} failed, {} skipped".format(d["result"], d["passedTests"], d["failedTests"], d["skippedTests"]))' \
    || echo "==> no test results (build failed?)"
exit "${status:-0}"
