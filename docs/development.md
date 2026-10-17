# Development

How Ametrine is built, tested and released. To build it for yourself, the README's [Getting started](../README.md#getting-started) is enough.

## Requirements

- Xcode (the project still uses Amethyst's names: the `Amethyst` project, target, scheme and executable, so upstream fixes cherry-pick cleanly).
- [SwiftLint](https://github.com/realm/SwiftLint) from Homebrew (`brew install swiftlint`): the Lint build phase runs it.
- A self-signed code-signing certificate named `Amethyst Local Signing`, set to Always Trust for code signing (Keychain Access → Certificate Assistant → Create a Certificate…, type **Code Signing**). The Accessibility permission sticks to this identity across rebuilds, so it's granted once per Mac.

## Scripts

| Script | What it does |
|---|---|
| `scripts/build.sh` | Builds the Release app signed with the local certificate, installs `/Applications/Ametrine.app` and launches it. The build number is the commit count. |
| `scripts/test.sh` | Runs the unit tests against a clean, empty config, so your own settings (margins, padding) don't leak into them. Extra arguments go to `xcodebuild`, e.g. `-only-testing:AmethystTests/TallLayoutTests`. |
| `scripts/release.sh major\|minor\|patch` | From a clean, pushed `fork/main`: bumps the version, runs the tests, builds and installs as above, commits and pushes the bump (`Release vX.Y.Z`), and saves the build as a draft GitHub release `vX.Y.Z` (a signed zip, visible only to the repository owner). `current` releases the version as it stands; `--dry-run` shows what would happen. |
| `scripts/profile.sh` | Records a Time Profiler trace when something feels slow; see [PROFILING.md](PROFILING.md). |
| `scripts/docs/fill.py` | Writes [layouts.md](layouts.md) from `scripts/docs/layouts.template.md` and the diagrams `scripts/docs/diagrams.py` draws from each layout's geometry. Edit those two, never `layouts.md` itself. |
| `scripts/icon/make-icon.swift` | Renders the app icon from `scripts/icon/gem-source.png`. |

## Versions

[Semantic versioning](https://semver.org) with the config file as the interface: a change that needs config edits is a major version, a feature a minor one, a fix a patch. Each release adds its line to [CHANGELOG.md](../CHANGELOG.md).

## Before merging

- `scripts/test.sh` passes, and every behaviour change has a unit test.
- A change to window tracking, focus or floating also runs the [manual tests](manual-tests.md): the Accessibility cases unit tests can't reach.
- Launched with `--log` (`open -a Ametrine --args --log`), Ametrine writes every layout pass, window decision and swap to `~/Library/Logs/Ametrine/Ametrine.log`; it's the quickest way to see what a change does live.

## Running next to Amethyst

Upstream Amethyst can stay installed as a fallback with its own config (`~/.config/amethyst/amethyst.yml`), but never run both at once.
