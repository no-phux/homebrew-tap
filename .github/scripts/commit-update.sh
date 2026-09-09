#!/usr/bin/env bash
set -euo pipefail

path="${1:?usage: commit-update.sh <Formula/file.rb|Casks/file.rb> <message>}"
message="${2:?usage: commit-update.sh <Formula/file.rb|Casks/file.rb> <message>}"
case "$path" in
  Formula/*.rb|Casks/*.rb) ;;
  *) echo "error: refusing to commit unexpected path: $path" >&2; exit 1 ;;
esac

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -- "$path"
if git diff --cached --quiet -- "$path"; then
  echo "$path is already up to date."
  exit 0
fi

git commit --only -m "$message" -- "$path"
for attempt in 1 2 3 4 5; do
  git fetch origin main
  if ! git rebase origin/main; then
    git rebase --abort || true
    echo "error: update conflicts with current main; a later scheduled run will retry from a fresh checkout" >&2
    exit 1
  fi
  if git push origin HEAD:main; then
    exit 0
  fi
  echo "push raced another tap update; retrying ($attempt/5)" >&2
  sleep $((attempt * 2))
done

echo "error: could not push $path after five attempts" >&2
exit 1
