#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPTS="$ROOT_DIR/claude/scopes/work/scripts"
mkdir -p "$HOME/.cache"
TMP_DIR="$(mktemp -d "$HOME/.cache/pr-review-gates-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

failures=0
expect() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s: expected [%s], got [%s]\n' "$label" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") printf '%s\n' "$FAKE_PR_JSON" ;;
  "pr checks") printf '%s\n' "$FAKE_BUCKETS" ;;
  "api graphql") [ -z "${FAKE_GRAPHQL_FAIL:-}" ] || exit 1; i=0; while [ "$i" -lt "$FAKE_UNRESOLVED" ]; do echo 1; i=$((i + 1)); done ;;
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$TMP_DIR/bin/gh"

run_gates() {
  PATH="$TMP_DIR/bin:$PATH" PR_REVIEW_WATCH_STATE_DIR="$TMP_DIR/state" PR_REVIEW_WATCH_CI_WAIT=0 \
    REPO=owner/repo NUMBER=7 ME=me SHA=abc bash -c ". '$SCRIPTS/pr-review-watch/gates.sh'; $1"
}

pr_json() {
  printf '{"state":"%s","isDraft":%s,"headRefOid":"%s","latestReviews":[%s]}' "$1" "$2" "$3" "${4:-}"
}

export FAKE_UNRESOLVED=0 FAKE_BUCKETS="pass,skipping"
export FAKE_PR_JSON="$(pr_json OPEN false abc)"
expect "objective: all green approves" "" "$(run_gates objective_blocker)"
FAKE_PR_JSON="$(pr_json OPEN false def)" expect "objective: moved head blocks" "head moved to def" "$(FAKE_PR_JSON="$(pr_json OPEN false def)" run_gates objective_blocker)"
expect "objective: merged PR blocks" "PR is MERGED" "$(FAKE_PR_JSON="$(pr_json MERGED false abc)" run_gates objective_blocker)"
expect "objective: draft blocks" "PR is a draft" "$(FAKE_PR_JSON="$(pr_json OPEN true abc)" run_gates objective_blocker)"
expect "objective: other reviewer's changes requested blocks" "changes requested by alice" \
  "$(FAKE_PR_JSON="$(pr_json OPEN false abc '{"state":"CHANGES_REQUESTED","author":{"login":"alice"}}')" run_gates objective_blocker)"
expect "objective: own changes requested does not block" "" \
  "$(FAKE_PR_JSON="$(pr_json OPEN false abc '{"state":"CHANGES_REQUESTED","author":{"login":"me"}}')" run_gates objective_blocker)"
expect "objective: unresolved threads block" "2 unresolved review threads" "$(FAKE_UNRESOLVED=2 run_gates objective_blocker)"
expect "objective: thread lookup failure blocks" "unknown unresolved review threads" "$(FAKE_GRAPHQL_FAIL=1 run_gates objective_blocker)"
expect "objective: failing CI blocks" "CI is fail" "$(FAKE_BUCKETS="pass,fail" run_gates objective_blocker)"
expect "objective: pending CI blocks after the wait" "CI is pending" "$(FAKE_BUCKETS="pending" run_gates objective_blocker)"
expect "objective: no CI blocks by default" "CI is none" "$(FAKE_BUCKETS="" run_gates objective_blocker)"
expect "objective: no CI allowed when opted in" "" "$(FAKE_BUCKETS="" PR_REVIEW_WATCH_ALLOW_NO_CI=1 run_gates objective_blocker)"
mkdir -p "$TMP_DIR/state" && touch "$TMP_DIR/state/off"
expect "objective: kill switch blocks" "kill switch is on" "$(run_gates objective_blocker)"
rm -f "$TMP_DIR/state/off"

verdict() { printf 'report\nVERIFY_VERDICT reviewed=%s reopened=%s regressions=%s complete=%s confident=%s\n' "$@" >"$TMP_DIR/verify.log"; }
verdict 2 0 0 true true
expect "verify: settled and confident approves" "" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"
expect "verify: delta findings block" "delta review posted 1 findings" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 1")"
expect "verify: unknown delta count blocks" "delta review posted unknown findings" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' ''")"
verdict 0 0 0 true true
expect "verify: empty finding set after a clean review approves" "" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"
verdict 2 1 0 true true
expect "verify: reopened blocks" "findings reopened" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"
verdict 2 0 1 true true
expect "verify: regressions block" "regressions raised" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"
verdict 2 0 0 false true
expect "verify: incomplete set blocks" "finding set incomplete" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"
verdict 2 0 0 true false
expect "verify: not confident blocks" "reviewer not confident" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"
verdict x 0 0 true true
expect "verify: unreadable count blocks" "unreadable finding count" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"
printf 'no verdict\n' >"$TMP_DIR/verify.log"
expect "verify: missing verdict blocks" "no VERIFY_VERDICT line" "$(run_gates "verify_blocker '$TMP_DIR/verify.log' 0")"

printf 'DELTA_FINDINGS 0\nDELTA_CONFIDENT value=true\n' >"$TMP_DIR/delta.log"
expect "clean: confident delta approves" "" "$(run_gates "clean_blocker '$TMP_DIR/delta.log' 0")"
printf 'DELTA_FINDINGS 0\nDELTA_CONFIDENT value=false\n' >"$TMP_DIR/delta.log"
expect "clean: unconfident delta blocks" "reviewer not confident" "$(run_gates "clean_blocker '$TMP_DIR/delta.log' 0")"

lib() { bash -c ". '$SCRIPTS/pr-council-review/lib.sh'; $1"; }
printf '{"result":"r","permission_denials":[{"tool_name":"Bash","tool_input":{"command":"curl x"}}]}' >"$TMP_DIR/denials-some.json"
printf '{"result":"r","permission_denials":[]}' >"$TMP_DIR/denials-none.json"
expect "denials: a denied call fails the pass" "1" "$(lib "check_denials '$TMP_DIR/denials-some.json' 2>/dev/null; echo \$?")"
expect "denials: the denied call is listed" "Bash: curl x" "$(lib "check_denials '$TMP_DIR/denials-some.json'" 2>&1 >/dev/null | tail -1)"
printf '{"result":"r","permission_denials":[]}\ntrailer\n' >"$TMP_DIR/denials-unreadable.json"
expect "denials: unreadable output fails the pass" "1" "$(lib "check_denials '$TMP_DIR/denials-unreadable.json' 2>/dev/null; echo \$?")"
expect "denials: none passes silently" "0" "$(lib "check_denials '$TMP_DIR/denials-none.json' 2>&1; echo \$?")"
printf '<!-- claudine:v1 {"kind":"run","run":"r","pr":7,"sha":"abc","findings":0,"floor":"should-fix"} -->\n' >"$TMP_DIR/council.log"
expect "run marker: findings for the reviewed sha" "0" "$(lib "validator_run_findings '$TMP_DIR/council.log' abc")"
expect "run marker: other sha is not clean" "" "$(lib "validator_run_findings '$TMP_DIR/council.log' def")"
marker='{"kind":"run","run":"7-x-me","pr":7,"sha":"abc","findings":0,"floor":"should-fix","suppressed":1,"security":"clean","lenses":{"linear":"ran","conventions":"narrowed"}}'
printf '=== run marker: claudine:v1 %s --\n' "$marker" >"$TMP_DIR/clean.log"
expect "approval body: validator format with its run marker" \
  "$(printf 'Approved after /validator run 7-x-me: nothing at or above `should-fix` posted, 1 suppressed.\n<!-- claudine:v1 %s -->' "$marker")" \
  "$(lib "validator_approval_body '$TMP_DIR/clean.log' abc")"
printf '<!-- claudine:v1 %s -->\n' "${marker/\"conventions\":\"narrowed\"/\"conventions\":\"pending\"}" >"$TMP_DIR/pending.log"
expect "approval body: pending lens withholds" "a validator lens is still pending" "$(lib "validator_approval_body '$TMP_DIR/pending.log' abc" 2>&1)"
printf '<!-- claudine:v1 %s -->\n' "${marker/\"security\":\"clean\"/\"security\":\"ticketed\"}" >"$TMP_DIR/ticketed.log"
expect "approval body: ticketed security withholds" "a security finding waits on a ticket" "$(lib "validator_approval_body '$TMP_DIR/ticketed.log' abc" 2>&1)"
printf 'a={{A}} b={{B}} c={{C}}\n' >"$TMP_DIR/template.md"
expect "template: special characters survive" 'a=R&D|x b=$HOME c={{C}}' "$(lib "render_template '$TMP_DIR/template.md' 'A=R&D|x' 'B=\$HOME'")"

cfg="$TMP_DIR/cfgrepo"
git init -q "$cfg"
gitc() { git -C "$cfg" -c user.name=t -c user.email=t@t "$@"; }
printf 'trusted\n' >"$cfg/CLAUDE.md"; printf 'a\n' >"$cfg/app.txt"
gitc add -A && gitc commit -q -m base && cfg_base="$(gitc rev-parse HEAD)"
mkdir -p "$cfg/.claude" "$cfg/sub"
printf 'poisoned\n' >"$cfg/CLAUDE.md"; printf '{"hooks":{}}\n' >"$cfg/.claude/settings.json"
printf 'poisoned\n' >"$cfg/sub/AGENTS.md"; printf '{}\n' >"$cfg/.mcp.json"
gitc add -A && gitc commit -q -m poison && cfg_since="$(gitc rev-parse HEAD)"
printf 'b\n' >"$cfg/app.txt"
gitc add -A && gitc commit -q -m delta && cfg_head="$(gitc rev-parse HEAD)"
cfg_state() {
  printf '%s|%s|%s|%s' "$(cat "$1/CLAUDE.md")" "$([ -e "$1/.claude/settings.json" ] && echo hooks || echo none)" \
    "$([ -e "$1/sub/AGENTS.md" ] && echo agents || echo none)" "$([ -e "$1/.mcp.json" ] && echo mcp || echo none)"
}
gitc worktree add -q --detach "$TMP_DIR/delta-tree" "$cfg_head"
git -C "$TMP_DIR/delta-tree" reset -q --soft "$cfg_since"
lib "neutralize_author_config '$TMP_DIR/delta-tree' '$cfg_since' '$cfg_base'" >/dev/null
expect "config: delta pass resets config poisoned before the delta" "trusted|none|none|none" "$(cfg_state "$TMP_DIR/delta-tree")"
expect "config: delta diff keeps only the delta" "app.txt" "$(git -C "$TMP_DIR/delta-tree" diff --cached --name-only)"
gitc worktree add -q --detach "$TMP_DIR/verify-tree" "$cfg_head"
lib "neutralize_author_config '$TMP_DIR/verify-tree' '$cfg_head' '$cfg_base'" >/dev/null
expect "config: verify pass resets config to the merge base" "trusted|none|none|none" "$(cfg_state "$TMP_DIR/verify-tree")"
expect "config: verify pass keeps the PR code" "b" "$(cat "$TMP_DIR/verify-tree/app.txt")"
verify_fn="$(sed -n '/^run_verify_fixes() {/,/^}/p' "$SCRIPTS/pr-review-watch/review-run.sh")"
expect "verify: neutralizes author config before claude" "1" "$(printf '%s\n' "$verify_fn" | grep -c 'neutralize_author_config "\$tree"')"
expect "verify: hooks, mcp and setting sources restricted" "1" \
  "$(printf '%s\n' "$verify_fn" | tr -d '\\\n' | grep -c "disableAllHooks.*--strict-mcp-config.*--setting-sources project,local")"

fake_home="$TMP_DIR/home"
mkdir -p "$fake_home/.claude/scripts/pr-autoreview" "$fake_home/.claude/state/pr-autoreview"
printf 'owner/repo\tprofile\n' >"$fake_home/.claude/state/pr-autoreview/repos.tsv"
printf '#!/bin/sh\necho "$@" >>"%s/calls"\n' "$TMP_DIR" >"$fake_home/.claude/scripts/pr-autoreview/run.sh"
chmod +x "$fake_home/.claude/scripts/pr-autoreview/run.sh"
printf '#!/bin/sh\n. "%s"\necho "stdin=$(wc -l | tr -d " ")"\n' "$SCRIPTS/pr-autoreview/hook-entry.sh" >"$TMP_DIR/pre-push"
chmod +x "$TMP_DIR/pre-push"
git -C "$TMP_DIR" init -q hookrepo
hook_out="$(cd "$TMP_DIR/hookrepo" && printf '%s\n' \
  'refs/heads/local 1111111111111111111111111111111111111111 refs/heads/feat/remote-name 0000000000000000000000000000000000000000' \
  'refs/tags/v1 2222222222222222222222222222222222222222 refs/tags/v1 0000000000000000000000000000000000000000' \
  'refs/heads/main 3333333333333333333333333333333333333333 refs/heads/main 0000000000000000000000000000000000000000' \
  | env -u hook_name HOME="$fake_home" "$TMP_DIR/pre-push" origin git@github.com:owner/repo.git)"
sleep 1
expect "hook: husky v9 fires and keeps stdin for the real hook" "stdin=3" "$hook_out"
expect "hook: branch comes from the remote ref, tags and main skipped" \
  "owner/repo profile feat/remote-name 1111111111111111111111111111111111111111" \
  "$(cut -d' ' -f1-4 "$TMP_DIR/calls" 2>/dev/null)"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
echo "all pr-review gate checks passed"
