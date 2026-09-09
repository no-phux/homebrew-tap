#!/usr/bin/env bash
#
# Prove the generated pipeline reproduces what is committed.
#
# For every tools/*.json: resolve the release pinned by the committed formula or
# cask, render it to a temporary file, and diff the two. Pinning makes validation
# deterministic when another tool publishes a release during the run; finding
# newer releases remains the update workflow's job.
#
# A run that differs means the tap drifted from its generator or the pinned
# release's assets changed. Both are worth a red build.
#
# Usage: verify-renders.sh [tool ...]     (default: every manifest)

set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

tools=("$@")
if (( ${#tools[@]} == 0 )); then
	for manifest in tools/*.json; do
		tools+=("$(basename "$manifest" .json)")
	done
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failed=()
for tool in "${tools[@]}"; do
	path="$(jq -er '.path' "tools/$tool.json")"
	rendered="$work/$tool.rb"
	version="$(grep -Eom1 '^[[:space:]]*version "[0-9]+\.[0-9]+\.[0-9]+"' "$path" | cut -d'"' -f2 || true)"
	tag="$(grep -Eom1 'releases/download/[^/]+/' "$path" | cut -d/ -f3 || true)"
	if [[ -n "$tag" && -n "$version" ]]; then
		tag="${tag/\#\{version\}/$version}"
	elif [[ -z "$tag" ]]; then
		prefix="$(jq -r '."tag-prefix" // "v"' "tools/$tool.json")"
		[[ -n "$version" ]] && tag="${prefix}${version}"
	fi
	if [[ -z "$tag" ]]; then
		echo "FAIL $tool — could not determine the pinned release tag from $path" >&2
		failed+=("$tool")
		continue
	fi

	if ! bash .github/scripts/update-tool.sh "$tool" "$rendered" "$tag" >/dev/null; then
		echo "FAIL $tool — render failed" >&2
		failed+=("$tool")
		continue
	fi

	if diff -u "$path" "$rendered" > "$work/$tool.diff"; then
		echo "ok   $tool — $path matches"
	else
		echo "FAIL $tool — $path differs from a fresh render:" >&2
		cat "$work/$tool.diff" >&2
		failed+=("$tool")
	fi
done

if (( ${#failed[@]} > 0 )); then
	echo >&2
	echo "error: ${#failed[@]} of ${#tools[@]} did not match: ${failed[*]}" >&2
	exit 1
fi

echo
echo "All ${#tools[@]} packages reproduce byte for byte."
