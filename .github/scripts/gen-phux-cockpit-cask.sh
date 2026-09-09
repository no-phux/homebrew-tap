#!/usr/bin/env bash
set -euo pipefail

tag="${1:?usage: gen-phux-cockpit-cask.sh <tag> <sha256> <notarized> [out-file]}"
sha256="${2:?usage: gen-phux-cockpit-cask.sh <tag> <sha256> <notarized> [out-file]}"
notarized="${3:?usage: gen-phux-cockpit-cask.sh <tag> <sha256> <notarized> [out-file]}"
out="${4:-}"

if [[ "$tag" =~ ^v(([0-9]+)\.([0-9]+)\.([0-9]+))$ ]]; then
  version="${BASH_REMATCH[1]}"
  major="${BASH_REMATCH[2]}"
  minor="${BASH_REMATCH[3]}"
  repo="no-phux/phux-cockpit"
  release_tag='v#{version}'
  homepage="https://github.com/no-phux/phux-cockpit"
  livecheck_regex=""
elif [[ "$tag" =~ ^cockpit-v(([0-9]+)\.([0-9]+)\.([0-9]+))$ ]]; then
  version="${BASH_REMATCH[1]}"
  major="${BASH_REMATCH[2]}"
  minor="${BASH_REMATCH[3]}"
  repo="no-phux/phux"
  release_tag='cockpit-v#{version}'
  homepage="https://github.com/no-phux/phux/tree/main/clients/cockpit"
  livecheck_regex='    regex(/^cockpit-v(\d+(?:\.\d+)+)$/i)'
else
  echo "error: tag must be vMAJOR.MINOR.PATCH or cockpit-vMAJOR.MINOR.PATCH" >&2
  exit 1
fi
spatial_runtime=false
description="Native companion for the phux terminal control plane"
if (( major > 0 || minor >= 3 )); then
  spatial_runtime=true
  description="Native spatial runtime for terminal and web surfaces"
fi
if [ "${#sha256}" -ne 64 ]; then
  echo "error: sha256 must contain exactly 64 lowercase hexadecimal characters" >&2
  exit 1
fi
case "$sha256" in
  *[!0-9a-f]*) echo "error: sha256 contains non-hexadecimal characters" >&2; exit 1 ;;
esac
[[ "$notarized" == true || "$notarized" == false ]]

emit() {
  cat <<EOF
# Generated from tools/phux-cockpit.json. Do not edit by hand.
cask "phux-cockpit" do
  version "${version}"
  sha256 "${sha256}"

  url "https://github.com/${repo}/releases/download/${release_tag}/phux-cockpit-#{version}-macos-arm64.zip"
  name "Phux Cockpit"
  desc "${description}"
  homepage "${homepage}"

  livecheck do
    url :url
EOF

  if [[ -n "$livecheck_regex" ]]; then
    printf '%s\n' "$livecheck_regex"
  fi

  cat <<'EOF'
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :big_sur
EOF

  if [ "$spatial_runtime" == false ]; then
    cat <<'EOF'
  depends_on formula: "no-phux/tap/phux"
EOF
  fi

  cat <<'EOF'

  app "Phux Cockpit.app"
EOF

  if [ "$notarized" == false ]; then
    cat <<'EOF'

  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-dr", "com.apple.quarantine", "#{appdir}/Phux Cockpit.app"]
  end

  caveats <<~EOS
EOF
    if [ "$spatial_runtime" == true ]; then
      cat <<'EOF'
    Phux Cockpit provides native terminal tabs, split panes, and a focused
    system-WebKit surface. Terminal processes and layout are not restored
    when the app restarts.
EOF
    else
      cat <<'EOF'
    Phux Cockpit runs the installed phux TUI in its Workspace pane and an
    ephemeral local shell beside it. Workspace state is managed by phux;
    Local Shell history is not restored when the app restarts.
EOF
    fi
    cat <<'EOF'

    This release is ad-hoc signed and not Apple-notarized. The cask clears
    its quarantine attribute so macOS can launch it without a Developer ID
    certificate.
  EOS
EOF
  else
    cat <<'EOF'

  caveats <<~EOS
EOF
    if [ "$spatial_runtime" == true ]; then
      cat <<'EOF'
    Phux Cockpit provides native terminal tabs, split panes, and a focused
    system-WebKit surface. Terminal processes and layout are not restored
    when the app restarts.
EOF
    else
      cat <<'EOF'
    Phux Cockpit runs the installed phux TUI in its Workspace pane and an
    ephemeral local shell beside it. Workspace state is managed by phux;
    Local Shell history is not restored when the app restarts.
EOF
    fi
    cat <<'EOF'
  EOS
EOF
  fi

  echo "end"
}

if [ -n "$out" ]; then
  emit > "$out"
  echo "wrote $out" >&2
else
  emit
fi
