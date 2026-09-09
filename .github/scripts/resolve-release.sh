#!/usr/bin/env bash
#
# Resolve a tool's GitHub release and verify every artifact the tap is about to
# reference. The default is the latest release; callers may pin a tag when
# reproducing an already committed formula or cask.
#
# THIS IS THE ONLY COPY OF THE VERIFICATION RULES. It used to be hand-written
# once per tool, which meant a new tool could silently ship without the URL pin
# (the check that stops a release from redirecting a formula's download
# somewhere the tag does not name). Adding a tool now means adding a manifest,
# and the manifest cannot opt out of any of this.
#
# Every artifact must:
#   1. match exactly one asset on the release by name — not "at least one", so
#      a decoy asset with a colliding name is a hard failure, not a coin flip;
#   2. have a browser_download_url byte-equal to the canonical
#      https://github.com/<repo>/releases/download/<tag>/<name> — GitHub is
#      free to hand back a different host, and the formula must not follow it;
#   3. hash to 64 lowercase hex after download.
#
# Manifests may additionally demand the digest agree with what the release
# itself published, either per-asset (`sidecar: true` → <name>.sha256) or via
# one combined manifest (`sums: "SHA256SUMS"`). Those files are fetched through
# the same three checks — a checksum you fetched from an unpinned URL proves
# nothing.
#
# Usage: resolve-release.sh <manifest.json> <work-dir> [tag]
#
# Writes:      <work-dir>/release.json      the raw release payload
#              <work-dir>/dist/<asset>      each downloaded artifact
#              <work-dir>/dist/<asset>.sha256   "<digest>  <asset>"
#              <work-dir>/env               KEY=value lines
# Stdout:      the same KEY=value lines, for `eval` in a local dry run.
#
# Emitted keys: TAG, VERSION, RELEASE_JSON, DIST, and per present asset
# <KEY>_NAME and <KEY>_SHA256. An absent optional asset emits neither, so a
# renderer tests presence with `${FOO_SHA256:-}`.

set -euo pipefail

manifest="${1:?usage: resolve-release.sh <manifest.json> <work-dir>}"
work="${2:?usage: resolve-release.sh <manifest.json> <work-dir>}"
requested_tag="${3:-}"

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

# macOS ships shasum, not sha256sum. CI is Linux, but the dry run that proves
# this script reproduces the committed formulas has to work on a laptop too.
sha256_of() {
	if command -v sha256sum >/dev/null; then
		sha256sum "$1" | cut -d ' ' -f 1
	else
		shasum -a 256 "$1" | cut -d ' ' -f 1
	fi
}

json() { jq -er "$1" "$manifest"; }

tool="$(json '.tool')"
primary_repo="$(json '.repo')"
primary_prefix="$(jq -r '."tag-prefix" // "v"' "$manifest")"
legacy_repo="$(jq -r '.legacy.repo // ""' "$manifest")"
legacy_prefix="$(jq -r '.legacy."tag-prefix" // ""' "$manifest")"
sums_asset="$(jq -r '.sums // ""' "$manifest")"

valid_prefix() {
	[[ "$1" =~ ^[A-Za-z0-9._-]*v$ ]]
}

version_from_tag() {
	local candidate="$1" prefix="$2" version
	[[ "$candidate" == "$prefix"* ]] || return 1
	version="${candidate#"$prefix"}"
	[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
	printf '%s\n' "$version"
}

latest_tag_for() {
	local candidate_repo="$1" prefix="$2"
	gh api "repos/$candidate_repo/releases?per_page=100" --paginate --slurp |
		jq -r --arg prefix "$prefix" \
		'map(.[]) | [.[] | select(
			.draft == false and
			.prerelease == false and
			(.tag_name | startswith($prefix)) and
			(.tag_name | ltrimstr($prefix) | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
		)][0].tag_name // empty'
}

valid_prefix "$primary_prefix" || {
	echo "error: $tool: tag-prefix '$primary_prefix' is unsafe" >&2
	exit 1
}
if [[ -n "$legacy_repo" || -n "$legacy_prefix" ]]; then
	[[ -n "$legacy_repo" && -n "$legacy_prefix" ]] || {
		echo "error: $tool: legacy repo and tag-prefix must be configured together" >&2
		exit 1
	}
	valid_prefix "$legacy_prefix" || {
		echo "error: $tool: legacy tag-prefix '$legacy_prefix' is unsafe" >&2
		exit 1
	}
fi

dist="$work/dist"
release="$work/release.json"
envfile="$work/env"
mkdir -p "$dist"
: > "$envfile"

if [[ -n "$requested_tag" ]]; then
	if version_from_tag "$requested_tag" "$primary_prefix" >/dev/null; then
		repo="$primary_repo"
		tag_prefix="$primary_prefix"
	elif [[ -n "$legacy_repo" ]] && version_from_tag "$requested_tag" "$legacy_prefix" >/dev/null; then
		repo="$legacy_repo"
		tag_prefix="$legacy_prefix"
	else
		echo "error: $tool: requested release tag '$requested_tag' does not match an allowed tag prefix" >&2
		exit 1
	fi
	gh api "repos/$repo/releases/tags/$requested_tag" > "$release"
else
	# `releases/latest` is "most recently published release", full stop — a repo
	# that also cuts side-channel releases (a plugin, an extension) under a
	# different tag scheme can have one of those shadow the actual latest tool
	# version. Walk the release list instead and take the newest non-draft,
	# non-prerelease entry whose tag is actually vMAJOR.MINOR.PATCH.
	repo="$primary_repo"
	tag_prefix="$primary_prefix"
	latest_tag="$(latest_tag_for "$repo" "$tag_prefix")"
	if [[ -z "$latest_tag" && -n "$legacy_repo" ]]; then
		repo="$legacy_repo"
		tag_prefix="$legacy_prefix"
		latest_tag="$(latest_tag_for "$repo" "$tag_prefix")"
	fi
	[[ -n "$latest_tag" ]] || {
		echo "error: $tool: no release tag matching an allowed prefix found" >&2
		exit 1
	}
	gh api "repos/$repo/releases/tags/$latest_tag" > "$release"
fi

tag="$(jq -er '.tag_name' "$release")"
version="$(version_from_tag "$tag" "$tag_prefix")" || {
	echo "error: $tool: release tag '$tag' does not match '$tag_prefix'MAJOR.MINOR.PATCH" >&2
	exit 1
}
[[ -z "$requested_tag" || "$tag" == "$requested_tag" ]] || {
	echo "error: $tool: requested release $requested_tag resolved to $tag" >&2
	exit 1
}

# Resolve an asset to its canonical, pinned download URL — or fail.
asset_url() {
	local name="$1" count url
	count="$(jq --arg name "$name" '[.assets[] | select(.name == $name)] | length' "$release")"
	if [[ "$count" == 0 ]]; then
		return 2
	fi
	[[ "$count" == 1 ]] || {
		echo "error: $tool: release $tag has $count assets named $name" >&2
		return 1
	}
	url="$(jq -er --arg name "$name" '.assets[] | select(.name == $name) | .browser_download_url' "$release")"
	[[ "$url" == "https://github.com/$repo/releases/download/$tag/$name" ]] || {
		echo "error: $tool: $name resolves to an unexpected URL: $url" >&2
		echo "       expected: https://github.com/$repo/releases/download/$tag/$name" >&2
		# By far the likeliest cause, and the one that reads as a security
		# alarm when it is really a rename: GitHub redirects the old owner
		# after a transfer, so downloads keep working and this pin is the
		# only thing that notices. Say so, or the next transfer costs an
		# afternoon of chasing a checksum mismatch that does not exist.
		echo "       if the upstream repository moved, set \"repo\" in tools/$tool.json to the new owner" >&2
		return 1
	}
	printf '%s\n' "$url"
}

fetch() {
	curl --fail --silent --show-error --location "$1" --output "$2"
}

# The combined-manifest case: one SHA256SUMS covering every artifact. A
# manifest that asks for this and does not get it is a failure — silently
# skipping the cross-check is exactly the bug this file exists to prevent.
sums_file=""
if [[ -n "$sums_asset" ]]; then
	if sums_url="$(asset_url "$sums_asset")"; then
		sums_file="$work/$sums_asset"
		fetch "$sums_url" "$sums_file"
	else
		echo "error: $tool: release $tag does not publish $sums_asset" >&2
		exit 1
	fi
fi

emit() {
	printf '%s\n' "$1" >> "$envfile"
	printf '%s\n' "$1"
}

emit "TAG=$tag"
emit "VERSION=$version"
emit "RELEASE_JSON=$release"
emit "DIST=$dist"

found=0
required_missing=0

for key in $(jq -r '.assets | keys_unsorted[]' "$manifest"); do
	template="$(jq -er --arg k "$key" '.assets[$k].name' "$manifest")"
	# `has` rather than `//`: jq's alternative operator treats `false` as absent,
	# so `.required // true` reads an explicit `"required": false` as *true* and
	# silently turns an optional artifact into a mandatory one.
	required="$(jq -r --arg k "$key" '.assets[$k] | if has("required") then .required else true end' "$manifest")"
	sidecar="$(jq -r --arg k "$key" '.assets[$k] | if has("sidecar") then .sidecar else false end' "$manifest")"

	name="${template//\{tag\}/$tag}"
	name="${name//\{version\}/$version}"

	# Not `if ! url=$(...)`: inside the branch of a negated condition `$?` is the
	# *inverted* status, so the "absent" (2) and "malformed" (1) cases become
	# indistinguishable and every failure exits without saying why.
	url=""
	if url="$(asset_url "$name")"; then
		: # resolved and pinned
	else
		status=$?
		[[ $status == 2 ]] || exit 1
		if [[ "$required" == true ]]; then
			echo "error: $tool: release $tag is missing required asset $name" >&2
			required_missing=1
		else
			echo "note: $tool: release $tag has no $name; rendering without it." >&2
		fi
		continue
	fi

	fetch "$url" "$dist/$name"
	digest="$(sha256_of "$dist/$name")"
	[[ "$digest" =~ ^[0-9a-f]{64}$ ]] || {
		echo "error: $tool: computed a malformed digest for $name" >&2
		exit 1
	}

	# Cross-check against whatever the release published, if anything.
	if [[ "$sidecar" == true ]]; then
		sidecar_name="$name.sha256"
		sidecar_url="$(asset_url "$sidecar_name")" || {
			echo "error: $tool: $name has no verifiable $sidecar_name" >&2
			exit 1
		}
		fetch "$sidecar_url" "$work/$sidecar_name.upstream"
		expected="$(cut -d ' ' -f 1 < "$work/$sidecar_name.upstream")"
		[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || {
			echo "error: $tool: $sidecar_name does not contain a digest" >&2
			exit 1
		}
		[[ "$digest" == "$expected" ]] || {
			echo "error: $tool: $name hashes to $digest but $sidecar_name claims $expected" >&2
			exit 1
		}
	elif [[ -n "$sums_file" ]]; then
		expected="$(awk -v file="$name" '$2 == file { print $1 }' "$sums_file")"
		[[ "$expected" =~ ^[0-9a-f]{64}$ ]] || {
			echo "error: $tool: $sums_asset has no digest for $name" >&2
			exit 1
		}
		[[ "$digest" == "$expected" ]] || {
			echo "error: $tool: $name hashes to $digest but $sums_asset claims $expected" >&2
			exit 1
		}
	fi

	# Renderers that read a dist directory (phux) expect this sidecar layout.
	printf '%s  %s\n' "$digest" "$name" > "$dist/$name.sha256"

	emit "${key}_NAME=$name"
	emit "${key}_SHA256=$digest"
	found=$((found + 1))
done

(( required_missing == 0 )) || exit 1
(( found > 0 )) || {
	echo "error: $tool: release $tag published none of the expected artifacts" >&2
	exit 1
}
