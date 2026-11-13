# no-phux Homebrew tap

Official Homebrew tap for [phux](https://github.com/no-phux/phux): terminals
as objects on a wire.

```sh
brew install no-phux/tap/phux
brew install --cask no-phux/tap/phux-desktop
```

On Homebrew 6 and later, `brew install no-phux/tap/phux` trusts only the
`phux` formula, and `brew install --cask no-phux/tap/phux-desktop` trusts
only the `phux-desktop` cask. Short names need `brew trust --formula` or
`brew trust --cask` first:

```sh
brew trust --formula no-phux/tap/phux
brew install phux
brew trust --cask no-phux/tap/phux-desktop
brew install --cask phux-desktop
```

| Package | What |
|---|---|
| [`phux`](Formula/phux.rb) | Libghostty-backed terminal control plane (macOS arm64, Linux arm64/x64) |
| [`phux-desktop`](Casks/phux-desktop.rb) | Phux.app from the signed, notarized DMG (Apple Silicon, macOS 26+) |

The CLI and desktop follow independent stable release channels. Both are
rediscovered automatically every fifteen minutes; no upstream tap token is
needed. GitHub may delay scheduled runs.

## Moving from Cockpit or `phall1/tap`

Cockpit is retired. `phux-desktop` replaces the old `phux-cockpit` cask;
Homebrew's cask rename metadata migrates existing installations on upgrade.
To switch explicitly:

```sh
brew uninstall --cask phux-cockpit
brew install --cask no-phux/tap/phux-desktop
```

If you still use `phall1/tap`, reinstall the CLI from its canonical name:

```sh
brew reinstall no-phux/tap/phux
```

Do not untap `phall1/tap`: it continues to provide its other tools.

Every package is generated from a verified public GitHub release. CI proves the
committed files reproduce byte-for-byte; see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the update and verification
contract.
