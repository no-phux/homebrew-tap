#!/usr/bin/env bash
# Offline renderer, platform floor, security and rename contracts.
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export TAG=desktop-v1.2.3 VERSION=1.2.3
export DMG_SHA256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
bash .github/scripts/render/phux-desktop.sh "$work/cask.rb"
ruby -c "$work/cask.rb" >/dev/null
for expected in \
  'cask "phux-desktop" do' \
  'version "1.2.3"' \
  "sha256 \"$DMG_SHA256\"" \
  'url "https://github.com/no-phux/phux/releases/download/desktop-v#{version}/phux-desktop-#{version}-macos-arm64.dmg"' \
  'regex(/^desktop-v(\d+(?:\.\d+)+)$/i)' \
  'strategy :github_releases' \
  'depends_on arch: :arm64' \
  'depends_on macos: :tahoe' \
  'app "Phux.app"'; do
  grep -Fq "$expected" "$work/cask.rb"
done
if grep -Eq 'quarantine|xattr|postflight|depends_on formula' "$work/cask.rb"; then
  echo "FAIL desktop cask bypasses security or requires a separate CLI" >&2
  exit 1
fi
if TAG=v1.2.3 bash .github/scripts/render/phux-desktop.sh "$work/wrong.rb" 2>/dev/null; then
  echo "FAIL renderer accepted a CLI tag" >&2; exit 1
fi
if DMG_SHA256=invalid bash .github/scripts/render/phux-desktop.sh "$work/wrong.rb" 2>/dev/null; then
  echo "FAIL renderer accepted an invalid checksum" >&2; exit 1
fi
jq -e '."phux-cockpit" == "phux-desktop"' cask_renames.json >/dev/null
[[ ! -e tools/phux-cockpit.json && ! -e Casks/phux-cockpit.rb ]]
echo "ok   desktop cask, platform floor, security and Cockpit migration"
