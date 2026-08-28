#!/bin/bash
# watchdog.sh — checks that the local cron routines actually ran and succeeded.
# Pure bash for the verdict; spawns a one-shot claude ONLY to post a Slack alert
# when something is wrong. Silent when everything is healthy.
# Scheduled by launchd (com.<account>.routine-watchdog), runs late evening.
set -u

LOGDIR="$HOME/.claude/logs"
BRAIN_LOG="$HOME/work/brain/_meta/cron.log"
SELF_LOG="$LOGDIR/routine-watchdog.log"
mkdir -p "$LOGDIR"

now=$(date +%s)
problems=()

# check <name> <logfile> <success-regex> <max-age-hours> <fail-regex>
# Flags a problem when: log missing, OR newest line matching success|fail is a
# fail, OR the last success is older than max-age-hours.
check() {
  local name="$1" log="$2" ok_re="$3" max_h="$4" fail_re="$5"
  if [ ! -f "$log" ]; then problems+=("$name : log absent ($log)"); return; fi

  local last_status last_ok_epoch
  # last line that is either a success or a failure marker
  last_status=$(grep -nE "$ok_re|$fail_re" "$log" 2>/dev/null | tail -1)
  if [ -z "$last_status" ]; then problems+=("$name : aucun marqueur succès/échec dans le log"); return; fi

  if echo "$last_status" | grep -qE "$fail_re"; then
    problems+=("$name : dernier run en ÉCHEC ($(echo "$last_status" | sed -E 's/^[0-9]+://' | cut -c1-80))")
    return
  fi

  # success: check freshness via file mtime (proxy for last write)
  last_ok_epoch=$(/usr/bin/stat -f%m "$log" 2>/dev/null || echo 0)
  local age_h=$(( (now - last_ok_epoch) / 3600 ))
  if [ "$age_h" -gt "$max_h" ]; then
    problems+=("$name : silencieux depuis ${age_h}h (seuil ${max_h}h)")
  fi
}

# name                  log                                  ok          maxH  fail
check "sessions-report" "$LOGDIR/sessions-report.log"        "done OK"   28    "TIMEOUT"
check "brain"           "$BRAIN_LOG"                         "=== done|no new conversations" 28 "Killed|No such file|TIMEOUT"
check "babysit"         "$LOGDIR/routine-babysit.log"        "done OK"   28    "TIMEOUT"
check "ci-health"       "$LOGDIR/routine-ci-health.log"      "done OK"   28    "TIMEOUT"
check "pendant"         "$LOGDIR/routine-pendant-que-tu-codais.log" "done OK" 28 "TIMEOUT"
# zombie-prs: weekly (friday). tolerate 8 days of silence.
check "zombie-prs"      "$LOGDIR/routine-zombie-prs.log"     "done OK"   192   "TIMEOUT"

echo "=== $(date '+%F %T') watchdog: ${#problems[@]} problème(s) ===" >> "$SELF_LOG"

if [ "${#problems[@]}" -eq 0 ]; then
  echo "all healthy" >> "$SELF_LOG"
  exit 0
fi

# build alert body
body=""
for p in "${problems[@]}"; do
  body="${body}• ${p}"$'\n'
  echo "  PROBLEM: $p" >> "$SELF_LOG"
done

# spawn one-shot claude to post on Slack (only path that needs Claude/MCP)
CLAUDE=""
[ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
if [ -z "$CLAUDE" ]; then echo "  claude introuvable, pas d'alerte Slack" >> "$SELF_LOG"; exit 1; fi

DATE=$(date '+%d/%m')
PROMPT="Poste UN message Slack dans le canal #routines (channel ID C0BA49W3U6Q) via mcp__claude_ai_Slack__slack_send_message, puis exécute via Bash \`touch /tmp/routine-watchdog.done\` et ne fais rien d'autre. Le message, EXACTEMENT (première ligne puis ligne vide puis corps), sans rien ajouter :

:rotating_light: *CRON WATCHDOG* · ${DATE} · 🔴 — ${#problems[@]} cron(s) en défaut

${body}
Vérifie les logs dans ~/.claude/logs/ et relance le cron concerné."

rm -f /tmp/routine-watchdog.done
PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/watchdog-prompt.XXXXXX")"
printf '%s' "$PROMPT" > "$PROMPT_FILE"
TMUX_BIN="/opt/homebrew/bin/tmux"
SESSION="routine-watchdog-post"
$TMUX_BIN kill-session -t "$SESSION" 2>/dev/null
$TMUX_BIN new-session -d -s "$SESSION" "cd $HOME && '$CLAUDE' --dangerously-skip-permissions \"\$(cat '$PROMPT_FILE')\""

elapsed=0
while [ "$elapsed" -lt 420 ]; do
  [ -f /tmp/routine-watchdog.done ] && break
  sleep 10; elapsed=$((elapsed + 10))
done
$TMUX_BIN kill-session -t "$SESSION" 2>/dev/null
rm -f "$PROMPT_FILE"
[ -f /tmp/routine-watchdog.done ] && echo "  alerte postée" >> "$SELF_LOG" || echo "  alerte NON postée (timeout)" >> "$SELF_LOG"
