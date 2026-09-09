# no-phux Homebrew tap

Official Homebrew tap for [Phux](https://github.com/no-phux/phux): terminals
as objects on a wire.

```sh
brew trust --tap no-phux/tap # Homebrew 6+
brew tap no-phux/tap
brew install no-phux/tap/phux
brew install --cask no-phux/tap/phux-cockpit
```

| Package | What |
|---|---|
| [`phux`](Formula/phux.rb) | Libghostty-backed terminal control plane |
| [`phux-cockpit`](Casks/phux-cockpit.rb) | Native macOS companion for Phux |

## Moving from `phall1/tap`

The Phux packages now live here. Install this tap and reinstall each Phux
package from its canonical name:

```sh
brew trust --tap no-phux/tap # Homebrew 6+
brew tap no-phux/tap
brew reinstall no-phux/tap/phux
brew reinstall --cask no-phux/tap/phux-cockpit
```

Do not untap `phall1/tap`: it continues to provide its other tools.

Every package is generated from a verified public GitHub release. CI proves the
committed files reproduce byte-for-byte; see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the update and verification
contract.
