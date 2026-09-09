#!/usr/bin/env bash
#
# Resolve → render → syntax-check one tool. The whole per-tool pipeline, minus
# the commit, so the same code path can run as a dry run (see verify-renders.sh)
# without any ability to write to the repository.
#
# Usage: update-tool.sh <tool> [out-file] [tag]
#
# With no out-file the tool's manifest `path` is written in place — that is the
# CI update. With one, the render goes there instead and nothing in the working
# tree is touched.

set -euo pipefail

tool="${1:?usage: update-tool.sh <tool> [out-file]}"
release_tag="${3:-}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
manifest="$root/tools/$tool.json"
renderer="$root/.github/scripts/render/$tool.sh"

[[ -f "$manifest" ]] || { echo "error: no manifest at tools/$tool.json" >&2; exit 1; }
[[ -f "$renderer" ]] || { echo "error: no renderer at .github/scripts/render/$tool.sh" >&2; exit 1; }

path="$(jq -er '.path' "$manifest")"
case "$path" in
	Formula/*.rb | Casks/*.rb) ;;
	*) echo "error: $tool: manifest path must be Formula/*.rb or Casks/*.rb, got $path" >&2; exit 1 ;;
esac

out="${2:-$root/$path}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# `set -a` so the KEY=value lines resolve-release.sh emits become environment
# for the renderer without this script having to know any tool's asset keys.
set -a
# shellcheck disable=SC1090
source <(bash "$root/.github/scripts/resolve-release.sh" "$manifest" "$work" "$release_tag")
set +a

bash "$renderer" "$out"
ruby -c "$out" >/dev/null

printf '%s\n' "TAG=$TAG"
