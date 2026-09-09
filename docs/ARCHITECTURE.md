# Architecture

This repository is the narrowly scoped, official Homebrew tap for Phux. It
contains only the packages released from [`no-phux/phux`](https://github.com/no-phux/phux):
the CLI formula and the native Cockpit cask.

## Generated and verified

Do not edit files in `Formula/` or `Casks/` by hand. Each one is generated
from a public release and CI rejects a file that does not reproduce exactly.

[`update-packages.yml`](../.github/workflows/update-packages.yml) discovers
new releases every fifteen minutes and also accepts `tap-release`,
`phux-release`, and `phux-cockpit-release` dispatches. For each package it:

1. resolves the matching, non-draft release;
2. verifies every artifact URL and SHA-256 digest;
3. renders the formula or cask; and
4. commits the update with a race-safe rebase-and-push retry.

`Formula/phux.rb` verifies each artifact against its release-side `.sha256`
sidecar. `Casks/phux-cockpit.rb` verifies its archive against the release's
combined `SHA256SUMS` manifest. Artifact URLs must match the exact canonical
GitHub release URL, so a redirect or repository move is a validation failure,
not a silent trust change.

## Local verification

The verification scripts need `gh`, `jq`, Ruby, and an authenticated GitHub
session:

```sh
bash .github/scripts/verify-renders.sh
bash .github/scripts/test/all.sh
```

The first command re-renders the versions committed in this repository and
diffs them. The second exercises dispatch selection and resolver failure modes.
