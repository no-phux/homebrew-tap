# Generated from tools/phux-desktop.json. Do not edit by hand.
cask "phux-desktop" do
  version "0.56.1"
  sha256 "9721e383d71a43a4df16ff3d24e7d81575c86d98138830dfb285ecd165d40a69"

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
