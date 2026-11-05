# Generated from tools/phux-desktop.json. Do not edit by hand.
cask "phux-desktop" do
  version "0.55.0"
  sha256 "ff4652a32a3dbb77d9f0d99ea2fa9e54d7a160d98af66c876d8f34c09068805a"

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
