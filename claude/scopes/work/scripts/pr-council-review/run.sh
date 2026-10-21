#!/bin/bash
set -uo pipefail

usage() {
  echo "usage: run.sh <pr-number|url> [owner/repo] [--post] [--model <alias>] [--effort <level>]" >&2
  echo "                              [--phase-a-model <alias>] [--phase-a-effort <level>]" >&2
  echo "                              [--codex] [--codex-model <model>] [--codex-effort <level>]" >&2
  exit 2
}

[ $# -ge 1 ] || usage
case "$1" in
  -h|--help|-*) usage ;;
esac
PR_ARG="$1"; shift

REPO=""
POST_MODE="dry-run"
MODEL="${PR_COUNCIL_MODEL:-opus}"
EFFORT="${PR_COUNCIL_EFFORT:-low}"
PHASE_A_MODEL="${PR_COUNCIL_PHASE_A_MODEL:-sonnet}"
PHASE_A_EFFORT="${PR_COUNCIL_PHASE_A_EFFORT:-}"
REVIEW_LEVEL="${PR_COUNCIL_REVIEW_LEVEL:-high}"
CODEX_MODEL="${PR_COUNCIL_CODEX_MODEL:-gpt-6-astra}"
CODEX_EFFORT="${PR_COUNCIL_CODEX_EFFORT:-medium}"
USE_CODEX="${PR_COUNCIL_USE_CODEX:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --post) POST_MODE="post" ;;
    --model) shift; MODEL="${1:?--model needs a value}" ;;
    --effort) shift; EFFORT="${1:?--effort needs a value}" ;;
    --phase-a-model) shift; PHASE_A_MODEL="${1:?--phase-a-model needs a value}" ;;
    --phase-a-effort) shift; PHASE_A_EFFORT="${1:?--phase-a-effort needs a value}" ;;
    --codex-model) shift; CODEX_MODEL="${1:?--codex-model needs a value}" ;;
    --codex-effort) shift; CODEX_EFFORT="${1:?--codex-effort needs a value}" ;;
    --codex) USE_CODEX=1 ;;
    --no-codex) USE_CODEX=0 ;;
    -h|--help) usage ;;
    *)
      if [[ "$1" == *"/"* ]]; then
        REPO="$1"
      else
        echo "unknown argument: $1" >&2
        usage
      fi
      ;;
  esac
  shift
done

[ -n "$PHASE_A_EFFORT" ] || PHASE_A_EFFORT="$EFFORT"

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

GH="$(command -v gh || echo /opt/homebrew/bin/gh)"
[ -x "$GH" ] || { echo "gh not found" >&2; exit 1; }
"$GH" auth status >/dev/null 2>&1 || { echo "gh is not authenticated" >&2; exit 1; }

CLAUDE=""
[ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
CLAUDE="${PR_COUNCIL_CLAUDE:-$CLAUDE}"
[ -n "$CLAUDE" ] || { echo "claude binary not found" >&2; exit 1; }

PROMPT_FILE="$HOME/.claude/scripts/pr-council-review/council-prompt.md"
[ -f "$PROMPT_FILE" ] || PROMPT_FILE="$HERE/council-prompt.md"
[ -f "$PROMPT_FILE" ] || { echo "council-prompt.md not found" >&2; exit 1; }

THERMO_SKILL_FILE=""
for candidate in \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/thermo-nuclear-code-quality-review/SKILL.md" \
  "$HOME/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md" \
  "$HOME/.pi/agent/skills/thermo-nuclear-code-quality-review/SKILL.md"
do
  [ -f "$candidate" ] && { THERMO_SKILL_FILE="$candidate"; break; }
done
[ -n "$THERMO_SKILL_FILE" ] || { echo "thermo-nuclear-code-quality-review SKILL.md not found" >&2; exit 1; }

CODEX_PROMPT_FILE="$HOME/.claude/scripts/pr-council-review/codex-prompt.md"
[ -f "$CODEX_PROMPT_FILE" ] || CODEX_PROMPT_FILE="$HERE/codex-prompt.md"

CODEX="$(command -v codex || echo "$HOME/.local/bin/codex")"
if [ "$USE_CODEX" = 1 ]; then
  if [ ! -x "$CODEX" ]; then
    echo "=== codex not found, running a Claude-only council" >&2
    USE_CODEX=0
  elif [ ! -f "$CODEX_PROMPT_FILE" ]; then
    echo "=== codex-prompt.md not found, running a Claude-only council" >&2
    USE_CODEX=0
  fi
fi

[ -n "$REPO" ] || REPO="$("$GH" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -n "$REPO" ] || { echo "cannot resolve repo; pass owner/repo" >&2; exit 1; }

META="$("$GH" pr view "$PR_ARG" --repo "$REPO" \
  --json number,headRefOid,baseRefName,url,title,state \
  --jq '[.number,.headRefOid,.baseRefName,.url,.state,.title] | @tsv' 2>/dev/null)"
[ -n "$META" ] || { echo "cannot read PR $PR_ARG on $REPO" >&2; exit 1; }
IFS=$'\t' read -r PR_NUMBER HEAD_SHA BASE_REF PR_URL PR_STATE PR_TITLE <<< "$META"
case "$PR_NUMBER" in
  ''|*[!0-9]*) echo "gh returned no usable PR number for $PR_ARG on $REPO" >&2; exit 1 ;;
esac
[ "$PR_STATE" = "OPEN" ] || { echo "$REPO#$PR_NUMBER is $PR_STATE, nothing to review" >&2; exit 1; }

echo "=== pr-council-review $REPO#$PR_NUMBER ($PR_STATE) @${HEAD_SHA:0:8}"
printf '=== %s\n' "$PR_TITLE" | strip_control_chars
echo "=== $PR_URL"
echo "=== mode: $POST_MODE / phase A: $PHASE_A_MODEL ($PHASE_A_EFFORT) / validator: $MODEL ($EFFORT)"
if [ "$USE_CODEX" = 1 ]; then
  echo "=== council: claude x2 + codex $CODEX_MODEL ($CODEX_EFFORT) — cross-family"
else
  echo "=== council: claude x2 — same-family, no codex member"
fi

git worktree prune
purge_old_dirs "${TMPDIR:-/tmp}" "pr-council-*" 7
git fetch -q origin "+refs/pull/$PR_NUMBER/head:refs/remotes/origin/pr/$PR_NUMBER" \
  "+refs/heads/$BASE_REF:refs/remotes/origin/$BASE_REF" || { echo "cannot fetch $REPO#$PR_NUMBER and $BASE_REF" >&2; exit 1; }
MERGE_BASE="$(git merge-base "refs/remotes/origin/$BASE_REF" "$HEAD_SHA" 2>/dev/null)"
[ -n "$MERGE_BASE" ] || { echo "no merge base between $BASE_REF and $HEAD_SHA" >&2; exit 1; }
echo "=== merge-base ${MERGE_BASE:0:8}"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-council-$PR_NUMBER.XXXXXX")"
WORKTREE="$WORK_DIR/tree"
REPORT_QUALITY="$WORK_DIR/code-review.md"
REPORT_THERMO="$WORK_DIR/thermo.md"
REPORT_CODEX="$WORK_DIR/codex.md"
RAW_QUALITY="$WORK_DIR/code-review.json"
RAW_THERMO="$WORK_DIR/thermo.json"
RAW_VALIDATOR="$WORK_DIR/validator.json"

cleanup() {
  git worktree remove --force "$WORKTREE" >/dev/null 2>&1
  echo "=== reports kept in $WORK_DIR"
}
interrupt() {
  trap - INT TERM
  echo "=== interrupted, stopping every pass" >&2
  local child
  for child in $(pgrep -P $$); do
    kill_tree "$child" TERM
  done
  exit 130
}
trap cleanup EXIT
trap interrupt INT TERM

git worktree add -q --detach "$WORKTREE" "$HEAD_SHA" || { echo "cannot create worktree" >&2; exit 1; }
git -C "$WORKTREE" reset -q --soft "$MERGE_BASE" || { echo "cannot stage the PR diff in the worktree" >&2; exit 1; }
neutralize_author_config "$WORKTREE" "$MERGE_BASE"

THERMO_PROMPT="Run the thermo-nuclear code quality review defined below on the PR diff only: it is staged in this worktree (\`git diff --cached\`, i.e. ${MERGE_BASE}...${HEAD_SHA}); the working tree is the PR head. Stay read-only: report findings, edit nothing.

$(cat "$THERMO_SKILL_FILE")"

CLAUDE_ARGS=(--dangerously-skip-permissions --output-format json)
[ -n "$MODEL" ] && CLAUDE_ARGS+=(--model "$MODEL")
[ -n "$EFFORT" ] && CLAUDE_ARGS+=(--effort "$EFFORT")
PHASE_A_ARGS=(--permission-mode auto --disallowedTools=Edit,Write,NotebookEdit --output-format json
  --settings '{"disableAllHooks":true}' --strict-mcp-config --setting-sources project,local)
[ -n "$PHASE_A_MODEL" ] && PHASE_A_ARGS+=(--model "$PHASE_A_MODEL")
[ -n "$PHASE_A_EFFORT" ] && PHASE_A_ARGS+=(--effort "$PHASE_A_EFFORT")

echo
echo "=== phase A: /code-review, /thermo-nuclear-code-quality-review$([ "$USE_CODEX" = 1 ] && echo " and codex") (parallel, no GitHub write)"
(
  cd "$WORKTREE" || exit 1
  "$CLAUDE" -p "/code-review $REVIEW_LEVEL" "${PHASE_A_ARGS[@]}" </dev/null
) >"$RAW_QUALITY" 2>"$RAW_QUALITY.err" &
PID_QUALITY=$!
(
  cd "$WORKTREE" || exit 1
  "$CLAUDE" -p "$THERMO_PROMPT" "${PHASE_A_ARGS[@]}" </dev/null
) >"$RAW_THERMO" 2>"$RAW_THERMO.err" &
PID_THERMO=$!

RC_CODEX=0
PID_CODEX=""
if [ "$USE_CODEX" = 1 ]; then
  CODEX_PROMPT="$(render_template "$CODEX_PROMPT_FILE" HEAD_SHA="$HEAD_SHA" MERGE_BASE="$MERGE_BASE")"
  (
    "$CODEX" exec \
      --cd "$WORKTREE" \
      --sandbox read-only \
      --model "$CODEX_MODEL" \
      -c model_reasoning_effort="\"$CODEX_EFFORT\"" \
      --color never \
      "$CODEX_PROMPT" </dev/null
  ) >"$REPORT_CODEX" 2>&1 &
  PID_CODEX=$!
fi

RC_QUALITY=0; RC_THERMO=0
wait "$PID_QUALITY" || RC_QUALITY=$?
wait "$PID_THERMO" || RC_THERMO=$?
[ -n "$PID_CODEX" ] && { wait "$PID_CODEX" || RC_CODEX=$?; }
extract_result "$RAW_QUALITY" >"$REPORT_QUALITY" || RC_QUALITY=1
extract_result "$RAW_THERMO" >"$REPORT_THERMO" || RC_THERMO=1
check_denials "$RAW_QUALITY" || RC_QUALITY=1
check_denials "$RAW_THERMO" || RC_THERMO=1

echo
echo "----- /code-review (exit $RC_QUALITY) -----"
cat "$REPORT_QUALITY"
echo
echo "----- /thermo-nuclear-code-quality-review (exit $RC_THERMO) -----"
cat "$REPORT_THERMO"
if [ "$USE_CODEX" = 1 ]; then
  echo
  echo "----- codex $CODEX_MODEL (exit $RC_CODEX) -----"
  cat "$REPORT_CODEX"
  if [ "$RC_CODEX" -ne 0 ]; then
    echo "=== codex pass failed; the validator will run without it" >&2
    USE_CODEX=0
  fi
fi

if [ "$RC_QUALITY" -ne 0 ] && [ "$RC_THERMO" -ne 0 ]; then
  echo "both Claude phase A passes failed; not running the validator" >&2
  exit 1
fi
PHASE_A_GAPS=""
[ "$RC_QUALITY" -eq 0 ] || PHASE_A_GAPS="The /code-review pass failed: its report is not a review, ignore it and say in the terminal report that phase A ran without it."
[ "$RC_THERMO" -eq 0 ] || PHASE_A_GAPS="$PHASE_A_GAPS The thermo-nuclear pass failed: its report is not a review, ignore it and say in the terminal report that phase A ran without it."
VALIDATOR_FLAGS=""
[ "$POST_MODE" = "dry-run" ] && VALIDATOR_FLAGS=" --dry-run"

if [ "$USE_CODEX" = 1 ]; then
  CODEX_SECTION="- \`$REPORT_CODEX\` — a review by \`codex\` on \`$CODEX_MODEL\` (reasoning effort $CODEX_EFFORT), a non-Claude model. This is the council's only cross-family member, so treat a finding only it raised as the most interesting kind: the defect two Claude passes agreed to miss. It is still a candidate with no privilege, verified or discarded on the same criteria as the others, and it had no access to the Linear ticket, the documentation, the conventions pack or the ADRs either."
else
  CODEX_SECTION="The codex member did not run for this review, so phase A was same-family. Say so in the terminal report: do not describe this run as cross-model."
fi

PROMPT="$(render_template "$PROMPT_FILE" \
  CODEX_SECTION="$CODEX_SECTION" PHASE_A_GAPS="$PHASE_A_GAPS" VALIDATOR_FLAGS="$VALIDATOR_FLAGS" \
  REPO="$REPO" PR_NUMBER="$PR_NUMBER" PR_URL="$PR_URL" HEAD_SHA="$HEAD_SHA" BASE_REF="$BASE_REF" \
  MERGE_BASE="$MERGE_BASE" REPORT_QUALITY="$REPORT_QUALITY" REPORT_THERMO="$REPORT_THERMO" POST_MODE="$POST_MODE")"

echo
echo "=== phase B: /validator with phase A findings as extra step 6 candidates"
"$CLAUDE" -p "$PROMPT" "${CLAUDE_ARGS[@]}" </dev/null >"$RAW_VALIDATOR" 2>"$RAW_VALIDATOR.err"
RC_VALIDATOR=$?
extract_result "$RAW_VALIDATOR" || RC_VALIDATOR=1
RUN_MARKER="$(session_run_marker "$RAW_VALIDATOR" "$HEAD_SHA")"
[ -z "$RUN_MARKER" ] || echo "=== run marker: $RUN_MARKER"

echo
record_usage "$RAW_QUALITY" "code-review" "$REPO#$PR_NUMBER"
record_usage "$RAW_THERMO" "thermo" "$REPO#$PR_NUMBER"
record_usage "$RAW_VALIDATOR" "validator" "$REPO#$PR_NUMBER"

echo
echo "=== done (validator exit $RC_VALIDATOR)"
exit "$RC_VALIDATOR"
