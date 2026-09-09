#!/usr/bin/env bash
# Which tools does a given trigger update?
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 1

FAILED=0
ALL="$(find tools -maxdepth 1 -name '*.json' -exec basename {} .json \; | sort | jq -cRn '{tool: [inputs]}')"

check() {
	local label="$1" expected="$2"; shift 2
	local got
	got="$(bash .github/scripts/select-tools.sh "$@" 2>/dev/null)"
	if [[ "$got" == "$expected" ]]; then
		echo "ok   $label"
	else
		echo "FAIL $label"
		echo "     expected: $expected"
		echo "     got:      $got"
		FAILED=1
	fi
}

# The named events are retained while source release automation moves to the
# generic dispatch. A misspelled package must fail rather than updating both.
check "legacy per-tool dispatch (phux)"          '{"tool":["phux"]}'         phux-release "" ""
check "legacy per-tool dispatch (phux-cockpit)"  '{"tool":["phux-cockpit"]}' phux-cockpit-release "" ""
check "generic dispatch with a payload"          '{"tool":["phux"]}'         tap-release phux ""
check "generic dispatch with no payload"         "$ALL"                      tap-release "" ""
check "manual run with an input"                 '{"tool":["phux-cockpit"]}' "" "" phux-cockpit
check "schedule"                                "$ALL"                      "" "" ""

if bash .github/scripts/select-tools.sh nope-release "" "" >/dev/null 2>&1; then
	echo "FAIL an unknown tool should be rejected, not silently ignored"
	FAILED=1
else
	echo "ok   an unknown tool is rejected"
fi

exit "$FAILED"
