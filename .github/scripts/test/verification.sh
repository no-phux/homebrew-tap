#!/usr/bin/env bash
# The point of centralising the checks is that they cannot be skipped. Prove
# each one actually fails a build rather than degrading quietly.
set -uo pipefail
cd "$(cd "$(dirname "$0")/../../.." && pwd)" || exit 1

FAILED=0
work="$(mktemp -d)"
trap 'rm -rf "$work" tools/zzz-neg.json' EXIT

expect_fail() {
	local label="$1" manifest="$2" pattern="$3" out
	out="$(bash .github/scripts/resolve-release.sh "$manifest" "$work/$(basename "$manifest" .json)" 2>&1)"
	local status=$?
	if (( status == 0 )); then
		echo "FAIL $label — resolver exited 0 when it should have refused"; FAILED=1
	elif ! grep -qi -- "$pattern" <<< "$out"; then
		echo "FAIL $label — failed, but not for the expected reason:"; printf '%s\n' "${out//$'\n'/$'\n'       }"; FAILED=1
	else
		echo "ok   $label"
	fi
}

expect_pass() {
	local label="$1" manifest="$2" tag="${3:-}"
	if bash .github/scripts/resolve-release.sh "$manifest" "$work/pass-$(basename "$manifest" .json)" "$tag" >/dev/null 2>&1; then
		echo "ok   $label"
	else
		echo "FAIL $label — resolver refused a legitimate release"; FAILED=1
	fi
}

# A required asset the release never published must stop the build, not render
# a formula with a missing platform.
cat > tools/zzz-neg.json <<'JSON'
{
	"tool": "zzz-neg", "repo": "no-phux/phux", "path": "Formula/zzz-neg.rb", "message": "x",
	"assets": { "GHOST": { "name": "phux-solaris-sparc.tar.gz" } }
}
JSON
expect_fail "missing required asset is fatal" tools/zzz-neg.json "missing required asset"

# The same asset declared optional should be skipped — but with nothing left,
# the resolver must still refuse rather than render an empty formula.
cat > tools/zzz-neg.json <<'JSON'
{
	"tool": "zzz-neg", "repo": "no-phux/phux", "path": "Formula/zzz-neg.rb", "message": "x",
	"assets": { "GHOST": { "name": "phux-solaris-sparc.tar.gz", "required": false } }
}
JSON
expect_fail "a release with no expected artifacts is fatal" tools/zzz-neg.json "published none of the expected artifacts"

# A manifest demanding a combined checksum file the release does not publish
# must fail rather than silently skipping the cross-check.
cat > tools/zzz-neg.json <<'JSON'
{
	"tool": "zzz-neg", "repo": "no-phux/phux", "path": "Formula/zzz-neg.rb", "message": "x",
	"sums": "SHA256SUMS",
	"assets": { "LINUX_X64": { "name": "phux-v0.27.1-x86_64-unknown-linux-gnu.tar.gz" } }
}
JSON
expect_fail "a missing checksum manifest is fatal" tools/zzz-neg.json "error"

# A sidecar demand the release cannot satisfy must fail too.
cat > tools/zzz-neg.json <<'JSON'
{
	"tool": "zzz-neg", "repo": "no-phux/phux", "tag-prefix": "desktop-v", "path": "Formula/zzz-neg.rb", "message": "x",
	"assets": { "ARCHIVE": { "name": "SHA256SUMS", "sidecar": true } }
}
JSON
expect_fail "an unverifiable sidecar is fatal" tools/zzz-neg.json "no verifiable"

# Positive control: Phux publishes sidecars, so demanding one must pass. Without
# this, every negative check above could be passing by accident.
expect_pass "a real release with matching sidecars passes" tools/phux.json
expect_pass "a pinned release with matching sidecars passes" tools/phux.json v0.27.1

# Desktop must follow its own stable channel, not the CLI GitHub Latest flag.
expect_pass "a pinned desktop DMG with matching sidecar passes" tools/phux-desktop.json desktop-v0.49.0
if bash .github/scripts/resolve-release.sh tools/phux-desktop.json "$work/desktop-latest" > "$work/desktop.env" &&
	grep -qE '^TAG=desktop-v[0-9]+\.[0-9]+\.[0-9]+$' "$work/desktop.env"; then
	echo "ok   desktop latest selects the independent component tag"
else
	echo "FAIL desktop latest did not resolve a verified desktop-v release"; FAILED=1
fi
if bash .github/scripts/resolve-release.sh tools/phux-desktop.json "$work/wrong-channel" v0.113.1 >/dev/null 2>&1; then
	echo "FAIL desktop accepted a CLI release tag"; FAILED=1
else
	echo "ok   desktop refuses a CLI release tag"
fi

exit "$FAILED"
