#!/usr/bin/env bash
# Resolver failures after partial output must never reach the renderer.
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/.github/scripts/render" "$work/tools" "$work/bin"
cp "$root/.github/scripts/"{update-tool,resolve-release}.sh "$work/.github/scripts/"
cat > "$work/tools/probe.json" <<'JSON'
{
  "tool": "probe", "repo": "no-phux/phux", "path": "Casks/probe.rb",
  "assets": {
    "GOOD": { "name": "good.dmg" },
    "MISSING": { "name": "missing.dmg" }
  }
}
JSON
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '{"tag_name":"v1.2.3","assets":[{"name":"good.dmg","browser_download_url":"https://github.com/no-phux/phux/releases/download/v1.2.3/good.dmg"}]}'
SH
cat > "$work/bin/curl" <<'SH'
#!/usr/bin/env bash
while [[ "$1" != --output ]]; do shift; done
printf artifact > "$2"
SH
cat > "$work/.github/scripts/render/probe.sh" <<'SH'
#!/usr/bin/env bash
printf 'cask "probe" do\nend\n' > "$1"
SH
chmod +x "$work/bin/"*
if PATH="$work/bin:$PATH" bash "$work/.github/scripts/update-tool.sh" probe "$work/rendered.rb" v1.2.3 > "$work/log" 2>&1; then
  echo "FAIL update-tool swallowed a failed verification" >&2; exit 1
fi
grep -Fq 'missing required asset missing.dmg' "$work/log"
[[ ! -e "$work/rendered.rb" ]]
echo "ok   partial resolver output cannot trigger rendering"
