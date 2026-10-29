#!/usr/bin/env bash
# Renders the signed, notarized macOS DMG. Never clear quarantine.
set -euo pipefail

out="${1:?usage: phux-desktop.sh <out-file>}"
: "${TAG:?}" "${VERSION:?}" "${DMG_SHA256:?}"
[[ "$TAG" == "desktop-v$VERSION" && "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$DMG_SHA256" =~ ^[0-9a-f]{64}$ ]]

cat > "$out" <<EOF
# Generated from tools/phux-desktop.json. Do not edit by hand.
cask "phux-desktop" do
  version "$VERSION"
  sha256 "$DMG_SHA256"

  url "https://github.com/no-phux/phux/releases/download/desktop-v#{version}/phux-desktop-#{version}-macos-arm64.dmg"
  name "Phux"
  desc "Native terminal workspace"
  homepage "https://phux.sh/"

  livecheck do
    url :url
    regex(/^desktop-v(\\d+(?:\\.\\d+)+)$/i)
    strategy :github_releases
  end

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Phux.app"
end
EOF
