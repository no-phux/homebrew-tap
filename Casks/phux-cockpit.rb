# Generated from tools/phux-cockpit.json. Do not edit by hand.
cask "phux-cockpit" do
  version "0.22.0"
  sha256 "d22c8e630c8a6a1270cda5fcdd5b2b6c03006e5564e882bb5b613ac838983268"

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

  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-dr", "com.apple.quarantine", "{{appdir}}/Phux Cockpit.app"]
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
