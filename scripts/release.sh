#!/usr/bin/env bash
#
# Saves the current fork/main build as a draft GitHub release: a zip of
# hw-Amethyst.app signed with the local self-signed certificate (not
# notarised). Drafts are visible only to the repository owner; this is how
# hw-Amethyst gets onto Hans's other Macs without building there.
#
# Usage: scripts/release.sh major|minor|patch|current [--dry-run]
#
#   major, minor, patch  bump MARKETING_VERSION (semantic versioning, with the
#                        config file as the interface: a change that needs
#                        config edits is major), commit and push the bump,
#                        then release it as v<version>
#   current              release the version as it stands (e.g. the first one)
#   --dry-run            print what would be released and stop
#
# A draft creates no git tag, so earlier releases are read through gh.
#
# Runs the tests, then scripts/build.sh (which also installs and relaunches
# the app here), so the zip is exactly what runs on this Mac.

set -euo pipefail

APP_NAME="hw-Amethyst"
BRANCH="fork/main"
TAG_PREFIX="v"
# Releases before version numbers were named hw-YYYY.MM.DD.
OLD_TAG_PREFIX="hw-"
PROJECT_FILE="Amethyst.xcodeproj/project.pbxproj"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT="${REPO_ROOT}/build/DerivedData/Build/Products/Release/Amethyst.app"
STAGING="${REPO_ROOT}/build/release"

cd "$REPO_ROOT"

# The version in the project, which both build configurations must agree on.
current_version() {
    local versions
    versions="$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \(.*\);$/\1/p' "$PROJECT_FILE" | sort -u)"
    if [[ "$(wc -l <<< "$versions" | tr -d ' ')" != "1" || ! "$versions" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "error: MARKETING_VERSION in ${PROJECT_FILE} must be one X.Y.Z value, found: $(tr '\n' ' ' <<< "$versions")" >&2
        exit 1
    fi
    echo "$versions"
}

usage() {
    echo "usage: scripts/release.sh major|minor|patch|current [--dry-run]" >&2
    echo "current version: $(current_version)" >&2
    exit 1
}

BUMP=""
DRY_RUN=false
for argument in "$@"; do
    case "$argument" in
        major|minor|patch|current) BUMP="$argument" ;;
        --dry-run) DRY_RUN=true ;;
        *) usage ;;
    esac
done
[[ -n "$BUMP" ]] || usage

echo "==> Checking the repository"
if [[ "$(git branch --show-current)" != "$BRANCH" ]]; then
    echo "error: release from ${BRANCH} only." >&2
    exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: the working tree has uncommitted changes." >&2
    exit 1
fi
git fetch --quiet origin "$BRANCH"
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/${BRANCH}")" ]]; then
    echo "error: ${BRANCH} isn't in sync with origin; push or pull first." >&2
    exit 1
fi
gh auth status >/dev/null 2>&1 || { echo "error: gh isn't logged in (gh auth login)." >&2; exit 1; }
# The fork, not upstream: gh would otherwise pick the parent repository.
REPO="$(gh repo view "$(git remote get-url origin)" --json nameWithOwner --jq .nameWithOwner)"

CURRENT="$(current_version)"
IFS=. read -r MAJOR MINOR PATCH <<< "$CURRENT"
case "$BUMP" in
    major) VERSION="$((MAJOR + 1)).0.0" ;;
    minor) VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
    patch) VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
    current) VERSION="$CURRENT" ;;
esac
TAG="${TAG_PREFIX}${VERSION}"

# Earlier releases, drafts included, newest first.
RELEASES="$(gh release list --repo "$REPO" --limit 200 --json tagName,createdAt \
    --jq 'sort_by(.createdAt) | reverse | .[].tagName' \
    | grep -E "^(${TAG_PREFIX}[0-9]|${OLD_TAG_PREFIX})" || true)"

if grep -qxF "$TAG" <<< "$RELEASES"; then
    echo "error: ${TAG} is already released (or saved as a draft)." >&2
    exit 1
fi

# The commit the previous release was built from, for the list of changes.
PREVIOUS_SHA=""
PREVIOUS_TAG="$(head -n 1 <<< "$RELEASES")"
if [[ -n "$PREVIOUS_TAG" ]]; then
    PREVIOUS_SHA="$(gh release view "$PREVIOUS_TAG" --repo "$REPO" --json targetCommitish --jq .targetCommitish)"
    git cat-file -e "${PREVIOUS_SHA}^{commit}" 2>/dev/null || PREVIOUS_SHA=""
fi

echo "    version:  ${CURRENT} → ${VERSION} (${BUMP})"
echo "    release:  ${TAG}"
echo "    previous: ${PREVIOUS_TAG:-none}"
if [[ "$DRY_RUN" == true ]]; then
    echo "==> Dry run: nothing changed"
    exit 0
fi

echo "==> Running the tests"
scripts/test.sh

if [[ "$VERSION" != "$CURRENT" ]]; then
    echo "==> Setting the version to ${VERSION}"
    # Until the bump is committed, any failure puts the project file back.
    trap 'git checkout -- "$PROJECT_FILE"; echo "note: version bump undone." >&2' EXIT
    sed -i '' "s/MARKETING_VERSION = ${CURRENT};/MARKETING_VERSION = ${VERSION};/" "$PROJECT_FILE"
fi

scripts/build.sh

echo "==> Zipping ${APP_NAME}.app"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$PRODUCT" "${STAGING}/${APP_NAME}.app"
ZIP="${STAGING}/${APP_NAME}-${VERSION}.zip"
ditto -c -k --keepParent "${STAGING}/${APP_NAME}.app" "$ZIP"

if [[ "$VERSION" != "$CURRENT" ]]; then
    echo "==> Committing and pushing the version bump"
    git commit --quiet -m "Release ${TAG}" -m "Co-Authored-By: HW+CC" -- "$PROJECT_FILE"
    trap - EXIT
    git push --quiet origin "$BRANCH"
fi

if [[ -n "$PREVIOUS_SHA" ]]; then
    CHANGES="$(git log --no-merges --format='- %s' "${PREVIOUS_SHA}..HEAD" | grep -v "^- Release ${TAG_PREFIX}" || true)"
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

echo "==> Saving draft release ${TAG}"
URL="$(gh release create "$TAG" "$ZIP" \
    --repo "$REPO" \
    --draft \
    --target "$(git rev-parse HEAD)" \
    --title "${APP_NAME} ${VERSION}" \
    --notes-file "$NOTES_FILE")"

echo "==> Done (draft, visible only to you): ${URL}"
