#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cask="$root/Casks/phux-cockpit.rb"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/phux-cockpit-cask-check.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

version="$(awk -F'"' '/^  version "/ { print $2; exit }' "$cask")"
sha256="$(awk -F'"' '/^  sha256 "/ { print $2; exit }' "$cask")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$sha256" =~ ^[0-9a-f]{64}$ ]]
notarized=true
if grep -Fq '  postflight_steps do' "$cask"; then
  notarized=false
fi
tag="v$version"
if grep -Fq 'github.com/no-phux/phux/releases/download/cockpit-v#{version}/' "$cask"; then
  tag="cockpit-v$version"
fi

bash "$root/.github/scripts/gen-phux-cockpit-cask.sh" "$tag" "$sha256" "$notarized" "$tmp/phux-cockpit.rb" >/dev/null
if ! cmp -s "$cask" "$tmp/phux-cockpit.rb"; then
  echo "Casks/phux-cockpit.rb does not match its generator" >&2
  diff -u "$cask" "$tmp/phux-cockpit.rb" >&2 || true
  exit 1
fi

if bash "$root/.github/scripts/gen-phux-cockpit-cask.sh" "v$version" not-a-checksum "$notarized" "$tmp/invalid.rb" >/dev/null 2>&1; then
  echo "gen-phux-cockpit-cask.sh accepted a malformed checksum" >&2
  exit 1
fi

for notarized_mode in false true; do
  generated="$tmp/phux-cockpit-0.3.0-$notarized_mode.rb"
  bash "$root/.github/scripts/gen-phux-cockpit-cask.sh" \
    v0.3.0 \
    0000000000000000000000000000000000000000000000000000000000000000 \
    "$notarized_mode" \
    "$generated" >/dev/null
  grep -Fq 'desc "Native spatial runtime for terminal and web surfaces"' "$generated"
  grep -Fq 'Phux Cockpit provides native terminal tabs, split panes, and a focused' "$generated"
  if grep -Fq 'depends_on formula: "no-phux/tap/phux"' "$generated"; then
    echo "v0.3.0 cask unexpectedly depends on phux" >&2
    exit 1
  fi
  if [[ "$notarized_mode" == false ]]; then
    grep -Fq '  postflight_steps do' "$generated"
  elif grep -Fq '  postflight_steps do' "$generated"; then
    echo "notarized v0.3.0 cask unexpectedly clears quarantine" >&2
    exit 1
  fi
done

canonical="$tmp/phux-cockpit-canonical.rb"
bash "$root/.github/scripts/gen-phux-cockpit-cask.sh" \
  cockpit-v0.16.2 \
  0000000000000000000000000000000000000000000000000000000000000000 \
  false \
  "$canonical" >/dev/null
ruby -c "$canonical" >/dev/null
grep -Fq 'url "https://github.com/no-phux/phux/releases/download/cockpit-v#{version}/' "$canonical"
grep -Fq 'homepage "https://github.com/no-phux/phux/tree/main/clients/cockpit"' "$canonical"
grep -Fq 'regex(/^cockpit-v(' "$canonical"

echo "Phux Cockpit cask regeneration check passed"
