# Generated from tools/phux-desktop.json. Do not edit by hand.
cask "phux-desktop" do
  version "0.54.0"
  sha256 "2caf4d0f09568d26ef11d2dbad7aa11eab357a727a8845a1931c52f0afe1c7b6"

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
