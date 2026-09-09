#!/usr/bin/env bash
# Renders Formula/phux.rb.
#
# phux's formula body is genuinely conditional — which platforms a release
# shipped decides the `depends_on` lines and which `on_*` blocks exist — so the
# rendering lives in gen-phux-formula.sh, which is kept in sync with
# no-phux/phux/scripts/gen-formula.sh. This is the adapter: resolve-release.sh
# already wrote the .sha256 sidecars that generator reads out of $DIST.
set -euo pipefail

out="${1:?usage: phux.sh <out-file>}"
: "${TAG:?}" "${DIST:?}"

bash "$(dirname "$0")/../gen-phux-formula.sh" "$TAG" "$DIST" "$out"
