# Generated from tools/phux-desktop.json. Do not edit by hand.
cask "phux-desktop" do
  version "0.57.0"
  sha256 "87ad80b989ba3ce561c37479853a2c4a7fe67c8e9dfc43fd020d94a1cf1bb8b7"

  url "https://github.com/no-phux/phux/releases/download/desktop-v#{version}/phux-desktop-#{version}-macos-arm64.dmg"
  name "Phux"
  desc "Native terminal workspace"
  homepage "https://phux.sh/"

  livecheck do
    url :url
    regex(/^desktop-v(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Phux.app"
end
