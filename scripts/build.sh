#!/usr/bin/env bash
#
# Builds the fork in Release, signed with the local self-signed certificate,
# and installs it to /Applications.
#
# One-time setup per Mac: create a self-signed "Code Signing" certificate named
# $SIGNING_IDENTITY in Keychain Access and set it to "Always Trust" for code
# signing. See docs/AMETHYST_FORK_HANDOFF.md §5.0.

set -euo pipefail

SIGNING_IDENTITY="Amethyst Local Signing"
APP_NAME="Ametrine"
BUNDLE_ID="com.ark.Ametrine"
INSTALL_PATH="/Applications/${APP_NAME}.app"
# Upstream targets macOS 11, which Xcode 27 no longer accepts (minimum 12).
DEPLOYMENT_TARGET="12.0"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${REPO_ROOT}/build/DerivedData"
PRODUCT="${DERIVED_DATA}/Build/Products/Release/Amethyst.app"

cd "$REPO_ROOT"

if ! security find-identity -p codesigning | grep -q "\"${SIGNING_IDENTITY}\""; then
    echo "error: no code-signing identity named \"${SIGNING_IDENTITY}\" in your keychain." >&2
    echo "Create it in Keychain Access → Certificate Assistant → Create a Certificate…" >&2
    echo "(Identity Type: Self-Signed Root, Certificate Type: Code Signing), then set" >&2
    echo "Trust → Code Signing to \"Always Trust\"." >&2
    exit 1
fi

# The build number is the commit count: it only grows and needs no bumping.
BUILD_NUMBER="$(git rev-list --count HEAD)"

echo "==> Building Release (build ${BUILD_NUMBER})"
xcodebuild \
    -workspace Amethyst.xcworkspace \
    -scheme Amethyst \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    build

echo "==> Verifying signature"
codesign --verify --deep --strict "$PRODUCT"
codesign -dvv "$PRODUCT" 2>&1 | grep -E '^(Identifier|Authority)='

echo "==> Installing to ${INSTALL_PATH}"
osascript -e "quit app id \"${BUNDLE_ID}\"" >/dev/null 2>&1 || true
while pgrep -f "${INSTALL_PATH}/Contents/MacOS/" >/dev/null; do
    sleep 0.2
done
rm -rf "$INSTALL_PATH"
ditto "$PRODUCT" "$INSTALL_PATH"

if [[ "${1:-}" != "--no-launch" ]]; then
    if pgrep -xf "/Applications/Amethyst.app/Contents/MacOS/Amethyst" >/dev/null; then
        echo "note: upstream Amethyst is running; quit it before using ${APP_NAME}. Not launching."
    else
        open "$INSTALL_PATH"
    fi
fi

echo "==> Done: ${INSTALL_PATH}"
