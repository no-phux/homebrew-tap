# Architecture

This repository is the narrowly scoped, official Homebrew tap for Phux. It
contains the CLI formula and macOS desktop DMG cask released from
[`no-phux/phux`](https://github.com/no-phux/phux). Mobile apps, FFI archives,
agent integrations and brand assets are not Homebrew packages.

## Generated and verified

Do not edit files in `Formula/` or `Casks/` by hand. Each one is generated
from a public release and CI rejects a file that does not reproduce exactly.

[`update-packages.yml`](../.github/workflows/update-packages.yml) discovers
new releases every fifteen minutes and also accepts `tap-release`,
`phux-release`, and `phux-desktop-release` dispatches. For each package it:

1. resolves the matching, stable, non-draft release;
2. verifies every artifact URL and SHA-256 digest;
3. renders the formula or cask; and
4. commits the update with a race-safe rebase-and-push retry.

`tools/phux.json` selects `vX.Y.Z` CLI releases; `tools/phux-desktop.json`
selects `desktop-vX.Y.Z` independently of GitHub's global Latest flag. Both
verify downloaded artifacts against their release-side `.sha256` sidecars.
Artifact URLs must match the exact canonical GitHub release URL, so a
repository move is a validation failure, not a silent trust change.

The desktop cask installs `Phux.app` from the signed, notarized arm64 DMG and
requires macOS 26 or newer, matching the bundle's minimum version. It does not
clear quarantine or depend on the separate CLI formula. `cask_renames.json`
migrates the retired Cockpit cask; no Cockpit release is polled or rendered.

## Local verification

The verification scripts need `gh`, `jq`, Ruby, and an authenticated GitHub
session:

```sh
bash .github/scripts/verify-renders.sh
bash .github/scripts/test/all.sh
```

The first command re-renders the versions committed in this repository and
diffs them. The second exercises dispatch selection, resolver failure modes,
the desktop cask contract, and adding a package to scheduled discovery.
