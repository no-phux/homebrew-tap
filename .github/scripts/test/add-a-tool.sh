#!/usr/bin/env bash
# Adding a package must need a manifest and a renderer — and no YAML edits.
#
# Drops both in, confirms the scheduled matrix picks the tool up by itself, runs
# the full resolve → verify → render path for it, then removes it and checks the
# tap is exactly as it was. Uses a real repository so the resolver runs for real.
set -uo pipefail
cd "$(cd "$(dirname "$0")/../../.." && pwd)" || exit 1

FAILED=0
PROBE=zzz-probe
cleanup() { rm -f "tools/$PROBE.json" ".github/scripts/render/$PROBE.sh"; }
trap cleanup EXIT

manifest_count() { find tools -maxdepth 1 -name '*.json' | wc -l | tr -d ' '; }

before="$(manifest_count)"

cat > "tools/$PROBE.json" <<'JSON'
{
	"tool": "zzz-probe",
	"repo": "no-phux/phux",
	"path": "Formula/zzz-probe.rb",
	"message": "Brew formula update for zzz-probe",
	"assets": { "LINUX_X64": { "name": "phux-{tag}-x86_64-unknown-linux-gnu.tar.gz", "sidecar": true } }
}
JSON

cat > ".github/scripts/render/$PROBE.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
out="$1"
cat > "$out" <<RUBY
class ZzzProbe < Formula
  desc "probe"
  homepage "https://example.invalid"
  url "https://github.com/no-phux/phux/releases/download/${TAG}/phux-${TAG}-x86_64-unknown-linux-gnu.tar.gz"
  sha256 "${LINUX_X64_SHA256}"
end
RUBY
SH

after="$(manifest_count)"
if [[ "$after" == "$((before + 1))" ]]; then
	echo "ok   manifest discovered without touching any workflow ($before -> $after)"
else
	echo "FAIL manifest not discovered"; FAILED=1
fi

# The scheduled run derives its matrix from tools/, so it must include the new
# tool with no other change anywhere.
matrix="$(bash .github/scripts/select-tools.sh "" "" "" 2>/dev/null)"
if jq -e --arg t "$PROBE" '.tool | index($t)' <<< "$matrix" >/dev/null; then
	echo "ok   scheduled matrix includes it: $matrix"
else
	echo "FAIL scheduled matrix missing it: $matrix"; FAILED=1
fi

rendered="$(mktemp)"
if bash .github/scripts/update-tool.sh "$PROBE" "$rendered" >/dev/null 2>&1 &&
	grep -qE 'sha256 "[0-9a-f]{64}"' "$rendered"; then
	echo "ok   resolve + verify + render ran end to end"
else
	echo "FAIL the shared pipeline did not produce a verified formula"; FAILED=1
fi
rm -f "$rendered"

cleanup
trap - EXIT
if [[ "$(manifest_count)" == "$before" ]]; then
	echo "ok   removal restores the original package set"
else
	echo "FAIL removal left residue"; FAILED=1
fi

exit "$FAILED"
