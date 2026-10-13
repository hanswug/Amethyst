#!/usr/bin/env bash
#
# Publishes the current fork/main build as a GitHub release: a zip of
# hw-Amethyst.app signed with the local self-signed certificate (not
# notarised). For now this is how hw-Amethyst gets onto other Macs without
# building there.
#
# Runs the tests, then scripts/build.sh (which also installs and relaunches
# the app here), so the zip is exactly what runs on this Mac.

set -euo pipefail

APP_NAME="hw-Amethyst"
BRANCH="fork/main"
TAG_PREFIX="hw-"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT="${REPO_ROOT}/build/DerivedData/Build/Products/Release/Amethyst.app"
STAGING="${REPO_ROOT}/build/release"

cd "$REPO_ROOT"

echo "==> Checking the repository"
if [[ "$(git branch --show-current)" != "$BRANCH" ]]; then
    echo "error: release from ${BRANCH} only." >&2
    exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: the working tree has uncommitted changes." >&2
    exit 1
fi
git fetch --quiet --tags origin "$BRANCH"
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/${BRANCH}")" ]]; then
    echo "error: ${BRANCH} isn't in sync with origin; push or pull first." >&2
    exit 1
fi
gh auth status >/dev/null 2>&1 || { echo "error: gh isn't logged in (gh auth login)." >&2; exit 1; }
# The fork, not upstream: gh would otherwise pick the parent repository.
REPO="$(gh repo view "$(git remote get-url origin)" --json nameWithOwner --jq .nameWithOwner)"

# One tag per day, with .2, .3, … for further releases that day.
DATE="$(date +%Y.%m.%d)"
TAG="${TAG_PREFIX}${DATE}"
n=2
while git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; do
    TAG="${TAG_PREFIX}${DATE}.${n}"
    n=$((n + 1))
done
PREVIOUS_TAG="$(git tag --list "${TAG_PREFIX}*" --sort=-creatordate | head -n 1)"

echo "==> Running the tests"
scripts/test.sh

scripts/build.sh

echo "==> Zipping ${APP_NAME}.app"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$PRODUCT" "${STAGING}/${APP_NAME}.app"
ZIP="${STAGING}/${APP_NAME}-${TAG#"$TAG_PREFIX"}.zip"
ditto -c -k --keepParent "${STAGING}/${APP_NAME}.app" "$ZIP"

if [[ -n "$PREVIOUS_TAG" ]]; then
    CHANGES="$(git log --no-merges --format='- %s' "${PREVIOUS_TAG}..HEAD")"
else
    CHANGES="- First release."
fi

NOTES_FILE="${STAGING}/notes.md"
cat > "$NOTES_FILE" <<EOF
## Changes

${CHANGES}

## Install

Signed with a self-signed certificate, not notarised, so macOS blocks the first launch.

1. Unzip and move \`${APP_NAME}.app\` to /Applications. Quit upstream Amethyst if it's running; never run both at once.
2. Open ${APP_NAME}. When macOS blocks it, go to System Settings → Privacy & Security and click **Open Anyway**.
3. Grant Accessibility when asked. On a Mac where a differently signed ${APP_NAME} had it, remove the old entry and grant it again.
4. The config lives at \`~/.config/hw-amethyst/amethyst.yml\`; start from [hw-amethyst.sample.yml](https://github.com/${REPO}/blob/${BRANCH}/hw-amethyst.sample.yml).
EOF

echo "==> Publishing ${TAG}"
gh release create "$TAG" "$ZIP" \
    --repo "$REPO" \
    --target "$(git rev-parse HEAD)" \
    --title "${APP_NAME} ${DATE//./-}" \
    --notes-file "$NOTES_FILE"
git fetch --quiet origin "refs/tags/${TAG}:refs/tags/${TAG}"

echo "==> Done: https://github.com/${REPO}/releases/tag/${TAG}"
