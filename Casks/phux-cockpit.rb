# Generated from tools/phux-cockpit.json. Do not edit by hand.
cask "phux-cockpit" do
  version "0.17.0"
  sha256 "2315c1cbeac9bb228e6adabac05c8becc5e5bd131611c23ab3d9926b54a0a05b"

  url "https://github.com/no-phux/phux/releases/download/cockpit-v#{version}/phux-cockpit-#{version}-macos-arm64.zip"
  name "Phux Cockpit"
  desc "Native spatial runtime for terminal and web surfaces"
  homepage "https://github.com/no-phux/phux/tree/main/clients/cockpit"

  livecheck do
    url :url
    regex(/^cockpit-v(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :big_sur

  app "Phux Cockpit.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Phux Cockpit.app"],
                   sudo: false
  end

  caveats <<~EOS
    Phux Cockpit provides native terminal tabs, split panes, and a focused
    system-WebKit surface. Terminal processes and layout are not restored
    when the app restarts.

    This release is ad-hoc signed and not Apple-notarized. The cask clears
    its quarantine attribute so macOS can launch it without a Developer ID
    certificate.
  EOS
end
