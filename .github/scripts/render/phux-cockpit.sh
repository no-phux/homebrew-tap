#!/usr/bin/env bash
# Renders Casks/phux-cockpit.rb.
#
# The notarization state changes the cask body (quarantine postflight + a
# different caveat), and the only place it is recorded is the release notes.
# Sniffing that is rendering policy, not artifact verification, so it lives here
# rather than in resolve-release.sh — which is why renderers are handed
# $RELEASE_JSON.
set -euo pipefail

out="${1:?usage: phux-cockpit.sh <out-file>}"
: "${TAG:?}" "${ARCHIVE_SHA256:?}" "${RELEASE_JSON:?}"

notarized=false
if jq -er '.body // ""' "$RELEASE_JSON" | grep -Fq 'This release is Developer ID signed and Apple-notarized.'; then
	notarized=true
fi

bash "$(dirname "$0")/../gen-phux-cockpit-cask.sh" "$TAG" "$ARCHIVE_SHA256" "$notarized" "$out"
