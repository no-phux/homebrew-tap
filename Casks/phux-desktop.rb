# Generated from tools/phux-desktop.json. Do not edit by hand.
cask "phux-desktop" do
  version "0.53.0"
  sha256 "16b269eccbe8ae46408601333a10a51b4adaa4e76f4798aec5ab837c4558ed3e"

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
