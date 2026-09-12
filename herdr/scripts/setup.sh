#!/usr/bin/env bash
set -euo pipefail

TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---check}"
case "$MODE" in --links|--install|--check) ;; *) echo 'usage: setup.sh [--links|--install|--check]' >&2; exit 2 ;; esac
[[ $# -le 1 ]] || exit 2
fail() { printf 'herdr setup: %s\n' "$*" >&2; exit 1; }

link_file() {
  local source="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" ]]; then
    rm "$target"
  elif [[ -e "$target" ]]; then
    mv "$target" "$target.bak.$(date +%Y%m%d-%H%M%S).$$"
  fi
  ln -s "$source" "$target"
}

if [[ "$MODE" != --check ]]; then
  link_file "$TREE/config.toml" "$HOME/.config/herdr/config.toml"
  link_file "$TREE/layouts/sessionizer.config.toml" "$HOME/.config/herdr/plugins/config/sessionizer/config.toml"
  for dir in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.config/devin/skills" "$HOME/.agents/skills" "$HOME/.pi/agent/skills"; do
    link_file "$TREE/skills/herdr" "$dir/herdr"
  done
fi
[[ "$MODE" != --links ]] || exit 0

for bin in herdr python3 node git fzf pi; do
  command -v "$bin" >/dev/null 2>&1 || fail "missing $bin; install it on this host"
done
HERDR_BIN="$(command -v herdr)"
version="$("$HERDR_BIN" --version)"
python3 - "$version" <<'PY'
import re, sys
v = re.search(r'(\d+)\.(\d+)\.(\d+)', sys.argv[1])
if not v or tuple(map(int, v.groups())) < (0, 9, 0):
    sys.exit('Herdr >= 0.9.0 is required; update explicitly before setup')
PY

plugin_matches() {
  "$HERDR_BIN" plugin list --json | python3 -c '
import json,sys,os
data=json.load(sys.stdin)
plugins=data["result"]["plugins"]
p=next((p for p in plugins if p["plugin_id"]==sys.argv[1]), None)
ok=p is not None and p["enabled"] and not p.get("warnings")
if ok and sys.argv[2]:
    ok=p.get("source",{}).get("resolved_commit")==sys.argv[2]
if ok and len(sys.argv)>3 and sys.argv[3]:
    ok=os.path.realpath(p["plugin_root"])==os.path.realpath(sys.argv[3])
if ok and sys.argv[1]=="sessionizer":
    ok=os.access(os.path.join(p["plugin_root"], "dist/sessionizer"), os.X_OK)
sys.exit(0 if ok else 1)
' "$1" "${2:-}" "${3:-}"
}

if [[ "$MODE" == --install ]]; then
  for bin in bun; do command -v "$bin" >/dev/null 2>&1 || fail "missing $bin for host-local plugin builds"; done
  while IFS=$'\t' read -r id source pin; do
    [[ -n "$id" && "$id" != \#* ]] || continue
    [[ "$pin" =~ ^[a-f0-9]{40}$ ]] || fail "invalid plugin pin for $id"
    if ! plugin_matches "$id" "$pin"; then
      previous_root="$("$HERDR_BIN" plugin list --json | python3 -c '
import json,sys
for p in json.load(sys.stdin)["result"]["plugins"]:
    if p["plugin_id"]==sys.argv[1] and p.get("source",{}).get("kind")=="local":
        print(p["plugin_root"])
' "$id")"
      # Legacy Mini sync registered copied checkouts as local plugins. Unlink
      # only their registry entry; keep source/config/state and restore on failure.
      if [[ -n "$previous_root" ]]; then "$HERDR_BIN" plugin unlink "$id"; fi
      if ! "$HERDR_BIN" plugin install "$source" --ref "$pin" --yes; then
        if [[ -n "$previous_root" ]]; then "$HERDR_BIN" plugin link "$previous_root" || true; fi
        fail "installation failed for $id; inspect plugin list before retrying"
      fi
    fi
  done < "$TREE/plugins.lock.tsv"
  "$HERDR_BIN" plugin link "$TREE/plugins/etabli-obvault"
  "$HERDR_BIN" plugin link "$TREE/plugins/claude-relaunch"
  for agent in pi claude codex grok opencode devin; do
    if command -v "$agent" >/dev/null 2>&1; then "$HERDR_BIN" integration install "$agent"; fi
  done
  if command -v agent >/dev/null 2>&1; then "$HERDR_BIN" integration install cursor; fi
fi

python3 - "$TREE" <<'PY'
from pathlib import Path
import sys
tree=Path(sys.argv[1])
home=Path.home()
links={home/'.config/herdr/config.toml': tree/'config.toml',
       home/'.config/herdr/plugins/config/sessionizer/config.toml': tree/'layouts/sessionizer.config.toml'}
for dest, src in links.items():
    if not dest.is_symlink() or dest.resolve() != src.resolve():
        sys.exit(f'{dest}: stale link; rerun setup.sh --links')
resolver=tree.parent/'workflow/runtime/obvault-topic-resolver.mjs'
if not resolver.is_file() and not (tree/'runtime/obvault-topic-resolver.mjs').is_file():
    sys.exit('Missing Etabli vault resolver; rerun sync from the complete repo')
PY
"$HERDR_BIN" config check
while IFS=$'\t' read -r id source pin; do
  [[ -n "$id" && "$id" != \#* ]] || continue
  plugin_matches "$id" "$pin" || fail "$id missing, disabled or stale; run setup.sh --install"
done < "$TREE/plugins.lock.tsv"
plugin_matches etabli.obvault "" "$TREE/plugins/etabli-obvault" || fail "Obvault plugin missing or linked to another tree; run setup.sh --install"
plugin_matches etabli.claude-relaunch "" "$TREE/plugins/claude-relaunch" || fail "Claude relaunch plugin missing or linked to another tree; run setup.sh --install"
integrations="$("$HERDR_BIN" integration status)"
printf '%s\n' "$integrations"
for agent in pi claude codex grok opencode devin; do
  if command -v "$agent" >/dev/null 2>&1; then
    [[ "$integrations" == *"$agent: current ("* ]] || fail "integration $agent needs installation/repair"
  fi
done
if command -v agent >/dev/null 2>&1; then
  [[ "$integrations" == *'cursor: current ('* ]] || fail 'integration cursor needs installation/repair'
fi
for bin in gh claude lazygit nvim; do
  command -v "$bin" >/dev/null 2>&1 || printf 'NOTE: %s unavailable; its optional shortcut needs it\n' "$bin"
done
printf 'Herdr setup verified (%s). No server restart or watcher activation.\n' "$version"
