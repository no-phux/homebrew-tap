#!/usr/bin/env bash
#
# Decide which tools a run should update, and print the job matrix.
#
# Lives here rather than inline in update-packages.yml so the tests exercise the
# real selection logic instead of a copy of it that drifts.
#
# Usage: select-tools.sh <dispatch-event-action> <dispatch-payload-tool> <manual-input-tool>
#
#   phui-release  ""      ""            -> just phui   (per-tool dispatch)
#   tap-release   phbv    ""            -> just phbv   (generic dispatch)
#   tap-release   ""      ""            -> everything
#   ""            ""      token-tach    -> just token-tach (manual run)
#   ""            ""      ""            -> everything   (schedule)
#
# An unrecognised tool is an error: quietly updating everything because a name
# was misspelled would hide the mistake behind a green run.

set -euo pipefail

action="${1-}"
payload_tool="${2-}"
input_tool="${3-}"

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

all="$(find tools -maxdepth 1 -name '*.json' -exec basename {} .json \; | sort)"
[[ -n "$all" ]] || { echo "error: no manifests in tools/" >&2; exit 1; }

wanted=""
case "$action" in
	tap-release) wanted="$payload_tool" ;;
	*-release) wanted="${action%-release}" ;;
esac
[[ -n "$wanted" ]] || wanted="$input_tool"

if [[ -n "$wanted" ]]; then
	grep -qx -- "$wanted" <<< "$all" || {
		echo "error: no manifest at tools/$wanted.json" >&2
		exit 1
	}
	selected="$wanted"
else
	selected="$all"
fi

jq -cn --arg tools "$selected" '{tool: ($tools | split("\n") | map(select(length > 0)))}'
