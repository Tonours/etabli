#!/bin/bash
set -uo pipefail

usage() {
  echo "usage: run.sh <pr-number|url> [owner/repo] [--post] [--model <alias>] [--effort <level>]" >&2
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
CODEX_MODEL="${PR_COUNCIL_CODEX_MODEL:-gpt-6-astra}"
CODEX_EFFORT="${PR_COUNCIL_CODEX_EFFORT:-medium}"
USE_CODEX="${PR_COUNCIL_USE_CODEX:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --post) POST_MODE="post" ;;
    --model) shift; MODEL="${1:?--model needs a value}" ;;
    --effort) shift; EFFORT="${1:?--effort needs a value}" ;;
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

GH="$(command -v gh || echo /opt/homebrew/bin/gh)"
[ -x "$GH" ] || { echo "gh not found" >&2; exit 1; }
"$GH" auth status >/dev/null 2>&1 || { echo "gh is not authenticated" >&2; exit 1; }

CLAUDE=""
[ -r "$HOME/.claude/scripts/claude-bin.sh" ] && . "$HOME/.claude/scripts/claude-bin.sh"
[ -n "$CLAUDE" ] || { echo "claude binary not found" >&2; exit 1; }

PROMPT_FILE="$HOME/.claude/scripts/pr-council-review/council-prompt.md"
[ -f "$PROMPT_FILE" ] || PROMPT_FILE="$(dirname "$0")/council-prompt.md"
[ -f "$PROMPT_FILE" ] || { echo "council-prompt.md not found" >&2; exit 1; }

CODEX_PROMPT_FILE="$HOME/.claude/scripts/pr-council-review/codex-prompt.md"
[ -f "$CODEX_PROMPT_FILE" ] || CODEX_PROMPT_FILE="$(dirname "$0")/codex-prompt.md"

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

echo "=== pr-council-review $REPO#$PR_NUMBER ($PR_STATE) @${HEAD_SHA:0:8}"
echo "=== $PR_TITLE"
echo "=== $PR_URL"
echo "=== mode: $POST_MODE / model: $MODEL / effort: $EFFORT"
if [ "$USE_CODEX" = 1 ]; then
  echo "=== council: claude x2 + codex $CODEX_MODEL ($CODEX_EFFORT) — cross-family"
else
  echo "=== council: claude x2 — same-family, no codex member"
fi

git fetch -q origin "pull/$PR_NUMBER/head" || { echo "cannot fetch pull/$PR_NUMBER/head" >&2; exit 1; }
git fetch -q origin "$BASE_REF" || { echo "cannot fetch $BASE_REF" >&2; exit 1; }
MERGE_BASE="$(git merge-base FETCH_HEAD "$HEAD_SHA" 2>/dev/null)"
[ -n "$MERGE_BASE" ] || { echo "no merge base between $BASE_REF and $HEAD_SHA" >&2; exit 1; }
echo "=== merge-base ${MERGE_BASE:0:8}"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-council-$PR_NUMBER.XXXXXX")"
WORKTREE="$WORK_DIR/tree"
REPORT_QUALITY="$WORK_DIR/code-review.md"
REPORT_THERMO="$WORK_DIR/thermo.md"
REPORT_CODEX="$WORK_DIR/codex.md"

cleanup() {
  git worktree remove --force "$WORKTREE" >/dev/null 2>&1
  echo "=== reports kept in $WORK_DIR"
}
trap cleanup EXIT

git worktree add -q --detach "$WORKTREE" "$HEAD_SHA" || { echo "cannot create worktree" >&2; exit 1; }

CLAUDE_ARGS=(--dangerously-skip-permissions)
[ -n "$MODEL" ] && CLAUDE_ARGS+=(--model "$MODEL")
[ -n "$EFFORT" ] && CLAUDE_ARGS+=(--effort "$EFFORT")

echo
echo "=== phase A: /code-review, /thermo-nuclear-code-quality-review$([ "$USE_CODEX" = 1 ] && echo " and codex") (parallel, no GitHub write)"
(
  cd "$WORKTREE" || exit 1
  "$CLAUDE" -p "/code-review $MERGE_BASE" "${CLAUDE_ARGS[@]}" </dev/null
) >"$REPORT_QUALITY" 2>&1 &
PID_QUALITY=$!
(
  cd "$WORKTREE" || exit 1
  "$CLAUDE" -p "/thermo-nuclear-code-quality-review restrict the audit to the diff ${MERGE_BASE}...HEAD" "${CLAUDE_ARGS[@]}" </dev/null
) >"$REPORT_THERMO" 2>&1 &
PID_THERMO=$!

RC_CODEX=0
PID_CODEX=""
if [ "$USE_CODEX" = 1 ]; then
  CODEX_PROMPT="$(sed \
    -e "s|{{HEAD_SHA}}|$HEAD_SHA|g" \
    -e "s|{{MERGE_BASE}}|$MERGE_BASE|g" \
    "$CODEX_PROMPT_FILE")"
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

if [ "$USE_CODEX" = 1 ]; then
  CODEX_SECTION="- \`$REPORT_CODEX\` — a review by \`codex\` on \`$CODEX_MODEL\` (reasoning effort $CODEX_EFFORT), a non-Claude model. This is the council's only cross-family member, so treat a finding only it raised as the most interesting kind: the defect two Claude passes agreed to miss. It is still a candidate with no privilege, verified or discarded on the same criteria as the others, and it had no access to the Linear ticket, the documentation, the conventions pack or the ADRs either."
else
  CODEX_SECTION="The codex member did not run for this review, so phase A was same-family. Say so in the terminal report: do not describe this run as cross-model."
fi

PROMPT="$(sed \
  -e "s|{{CODEX_SECTION}}|$CODEX_SECTION|g" \
  -e "s|{{REPO}}|$REPO|g" \
  -e "s|{{PR_NUMBER}}|$PR_NUMBER|g" \
  -e "s|{{PR_URL}}|$PR_URL|g" \
  -e "s|{{HEAD_SHA}}|$HEAD_SHA|g" \
  -e "s|{{BASE_REF}}|$BASE_REF|g" \
  -e "s|{{MERGE_BASE}}|$MERGE_BASE|g" \
  -e "s|{{REPORT_QUALITY}}|$REPORT_QUALITY|g" \
  -e "s|{{REPORT_THERMO}}|$REPORT_THERMO|g" \
  -e "s|{{POST_MODE}}|$POST_MODE|g" \
  "$PROMPT_FILE")"

echo
echo "=== phase B: /validator with phase A findings as extra step 6 candidates"
"$CLAUDE" -p "$PROMPT" "${CLAUDE_ARGS[@]}" </dev/null
RC_VALIDATOR=$?

echo
echo "=== done (validator exit $RC_VALIDATOR)"
exit "$RC_VALIDATOR"
