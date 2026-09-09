#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
formula="$root/Formula/phux.rb"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/phux-formula-check.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

tag="$(grep -Eo 'releases/download/v[0-9]+\.[0-9]+\.[0-9]+/' "$formula" | head -1 | cut -d/ -f3)"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]

found=0
for target in \
  aarch64-apple-darwin \
  x86_64-unknown-linux-gnu \
  aarch64-unknown-linux-gnu; do
  line="$(grep -n -m1 "phux-$tag-$target.tar.gz\"" "$formula" | cut -d: -f1 || true)"
  if [ -z "$line" ]; then
    continue
  fi
  sha="$(tail -n "+$line" "$formula" | grep -m1 -E '^[[:space:]]+sha256 "[0-9a-f]{64}"$' | cut -d'"' -f2)"
  [[ "$sha" =~ ^[0-9a-f]{64}$ ]]
  printf '%s  phux-%s-%s.tar.gz\n' "$sha" "$tag" "$target" \
    > "$tmp/phux-$tag-$target.tar.gz.sha256"
  found=$((found + 1))
done
(( found > 0 ))

bash "$root/.github/scripts/gen-phux-formula.sh" "$tag" "$tmp" "$tmp/phux.rb" >/dev/null
if ! cmp -s "$formula" "$tmp/phux.rb"; then
  echo "Formula/phux.rb does not match .github/scripts/gen-phux-formula.sh" >&2
  diff -u "$formula" "$tmp/phux.rb" >&2 || true
  exit 1
fi

printf 'not-a-checksum  phux-%s-aarch64-apple-darwin.tar.gz\n' "$tag" \
  > "$tmp/phux-$tag-aarch64-apple-darwin.tar.gz.sha256"
if bash "$root/.github/scripts/gen-phux-formula.sh" "$tag" "$tmp" "$tmp/invalid.rb" >/dev/null 2>&1; then
  echo "gen-phux-formula.sh accepted a malformed checksum sidecar" >&2
  exit 1
fi

echo "phux formula regeneration check passed"
