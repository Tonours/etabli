#!/usr/bin/env bash
# Fixtures for claude/hooks/proof-shadow.mjs: real-envelope claim resolution.
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HOOK="$ROOT_DIR/claude/hooks/proof-shadow.mjs"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export TMPDIR="$TMP_DIR/tmp"
mkdir -p "$TMPDIR"

# Build a REAL-envelope transcript (mirrors
# tests/fixtures/harness-traces/claude/session.jsonl):
#   mktranscript OUT VAR=val... < spec-lines
# spec line:  text|TS|TEXT  |  bash|TS|ID|COMMAND  |  result|TS|ID|IS_ERROR
mktranscript() {
  local out="$1" spec
  shift
  spec="$(cat)"
  python3 - "$out" "$spec" <<'PYEOF'
import io, json, sys
out = sys.argv[1]
spec = sys.argv[2].split('\n')
uuid_n = [0]
def entry(kind, ts, role, content):
    uuid_n[0] += 1
    parent = f'u-{uuid_n[0]-1}' if uuid_n[0] > 1 else None
    return {'type': kind, 'uuid': f'u-{uuid_n[0]}', 'parentUuid': parent,
            'sessionId': 'smoke-session', 'timestamp': ts,
            'message': {'role': role, 'content': content}}
lines = []
for raw in spec:
    if not raw:
        continue
    parts = raw.split('|')
    if parts[0] == 'text':
        _, ts, text = parts
        lines.append(entry('assistant', ts, 'assistant', [{'type': 'text', 'text': text}]))
    elif parts[0] == 'bash':
        _, ts, tid, cmd = parts
        lines.append(entry('assistant', ts, 'assistant',
                           [{'type': 'tool_use', 'id': tid, 'name': 'Bash', 'input': {'command': cmd}}]))
    elif parts[0] == 'result':
        _, ts, tid, is_err = parts
        lines.append(entry('user', ts, 'user',
                           [{'type': 'tool_result', 'tool_use_id': tid, 'content': 'out',
                             'is_error': is_err == 'true'}]))
    else:
        raise SystemExit(f'bad spec: {raw}')
io.open(out, 'w', encoding='utf-8').write('\n'.join(json.dumps(l) for l in lines) + '\n')
PYEOF
}

mkrepo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

run_hook() {
  local transcript="$1" cwd="$2" session="$3"
  printf '{"transcript_path":"%s","cwd":"%s","session_id":"%s"}' "$transcript" "$cwd" "$session" \
    | node "$HOOK" >/dev/null 2>&1
}

# 1. real-envelope substantiated (tests-pass, clean tree, TMPDIR sink).
R1="$TMP_DIR/r1"
mkrepo "$R1"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
bash|2026-03-01T10:00:00Z|tool-1|bun test ./x.test.ts
result|2026-03-01T10:00:05Z|tool-1|false
text|2026-03-01T10:01:00Z|All done, tests pass on the branch.
EOF
run_hook "$TMP_DIR/t.jsonl" "$R1" "s1"
SINK1="$TMPDIR/proof-shadow-s1.jsonl"
[ -f "$SINK1" ] || fail "case1: no TMPDIR sink record"
jq -e 'select(.verdict == "substantiated" and .class == "tests-pass" and .claim == "tests pass" and .command == "bun test ./x.test.ts" and .tool_use_id == "tool-1" and .schema_version == 1)' "$SINK1" >/dev/null \
  || fail "case1: expected substantiated tests-pass record"

# 2. hallucinated: claim without any run.
R2="$TMP_DIR/r2"
mkrepo "$R2"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|Verified, all good.
EOF
run_hook "$TMP_DIR/t.jsonl" "$R2" "s2"
jq -e 'select(.verdict == "unsubstantiated" and .class == "verified" and .reason == "no-matching-passing-run")' \
  "$TMPDIR/proof-shadow-s2.jsonl" >/dev/null || fail "case2: expected unsubstantiated verified record"

# gh stub: canned JSON array on stdout.
mkstub() {
  printf '#!/bin/sh\ncat "%s"\n' "$2" >"$1"
  chmod +x "$1"
}

# 3. gh-stub substantiated CI-green on a clean tracked tree.
R3="$TMP_DIR/r3"
mkrepo "$R3"
printf 'code\n' >"$R3/f.txt"
git -C "$R3" add f.txt && git -C "$R3" -c user.email=t@t -c user.name=t commit -qm f
SHA3="$(git -C "$R3" rev-parse HEAD)"
printf '[{"status":"completed","conclusion":"success","headSha":"%s"}]' "$SHA3" >"$R3/runs.json"
mkstub "$R3/gh" "$R3/runs.json"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|Pushed, CI green on the PR.
EOF
PROOF_SHADOW_GH="$R3/gh" run_hook "$TMP_DIR/t.jsonl" "$R3" "s3"
jq -e --arg sha "$SHA3" 'select(.verdict == "substantiated" and .class == "ci-green" and .head_sha == $sha and .reason == "gh-all-conclusions-success")' \
  "$TMPDIR/proof-shadow-s3.jsonl" >/dev/null || fail "case3: expected substantiated ci-green record"

# 3b. mixed conclusions: one failure sinks the claim.
R3B="$TMP_DIR/r3b"
mkrepo "$R3B"
SHA3B="$(git -C "$R3B" rev-parse HEAD)"
printf '[{"status":"completed","conclusion":"success","headSha":"%s"},{"status":"completed","conclusion":"failure","headSha":"%s"}]' "$SHA3B" "$SHA3B" >"$R3B/runs.json"
mkstub "$R3B/gh" "$R3B/runs.json"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|CI green, merging.
EOF
PROOF_SHADOW_GH="$R3B/gh" run_hook "$TMP_DIR/t.jsonl" "$R3B" "s3b"
jq -e 'select(.verdict == "unsubstantiated" and .reason == "gh-conclusion-failure")' \
  "$TMPDIR/proof-shadow-s3b.jsonl" >/dev/null || fail "case3b: mixed conclusions must sink CI-green"

# 4. no runs for SHA.
R4="$TMP_DIR/r4"
mkrepo "$R4"
printf '[]' >"$R4/runs.json"
mkstub "$R4/gh" "$R4/runs.json"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|CI green, I think.
EOF
PROOF_SHADOW_GH="$R4/gh" run_hook "$TMP_DIR/t.jsonl" "$R4" "s4"
jq -e 'select(.verdict == "unsubstantiated" and .reason == "no-runs-for-sha")' \
  "$TMPDIR/proof-shadow-s4.jsonl" >/dev/null || fail "case4: expected no-runs unsubstantiated"

# 5. dirty tracked tree -> unverifiable, gh stub must NOT run.
R5="$TMP_DIR/r5"
mkrepo "$R5"
printf 'code\n' >"$R5/f.txt"
git -C "$R5" add f.txt && git -C "$R5" -c user.email=t@t -c user.name=t commit -qm f
printf 'dirty\n' >>"$R5/f.txt"
printf '#!/bin/sh\ntouch "%s/called"\nexit 1\n' "$R5" >"$R5/gh"
chmod +x "$R5/gh"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|CI green.
EOF
PROOF_SHADOW_GH="$R5/gh" run_hook "$TMP_DIR/t.jsonl" "$R5" "s5"
jq -e 'select(.verdict == "unverifiable" and .reason == "dirty-tree-vs-head")' \
  "$TMPDIR/proof-shadow-s5.jsonl" >/dev/null || fail "case5: expected dirty-tree unverifiable"
[ ! -e "$R5/called" ] || fail "case5: gh must not run on a dirty tree"

# 6. gh failure -> unverifiable.
R6="$TMP_DIR/r6"
mkrepo "$R6"
printf '#!/bin/sh\nexit 1\n' >"$R6/gh"
chmod +x "$R6/gh"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|CI green?
EOF
PROOF_SHADOW_GH="$R6/gh" run_hook "$TMP_DIR/t.jsonl" "$R6" "s6"
jq -e 'select(.verdict == "unverifiable" and .reason == "gh-failed")' \
  "$TMPDIR/proof-shadow-s6.jsonl" >/dev/null || fail "case6: expected gh-failed unverifiable"

# 7. stale run: tree newer than the passing run.
R7="$TMP_DIR/r7"
mkrepo "$R7"
printf 'code\n' >"$R7/f.txt"
git -C "$R7" add f.txt && git -C "$R7" -c user.email=t@t -c user.name=t commit -qm f
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
bash|2020-01-01T10:00:00Z|tool-9|scripts/verify-agentic-infra core
result|2020-01-01T10:00:05Z|tool-9|false
text|2026-03-01T10:01:00Z|tests pass, ship it.
EOF
printf 'newer\n' >>"$R7/f.txt"
run_hook "$TMP_DIR/t.jsonl" "$R7" "s7"
jq -e 'select(.verdict == "unsubstantiated" and .reason == "run-not-newer-than-tree")' \
  "$TMPDIR/proof-shadow-s7.jsonl" >/dev/null || fail "case7: expected stale-run unsubstantiated"

# 7b. exact-tie mtime -> unsubstantiated (strict-greater rule).
R7B="$TMP_DIR/r7b"
mkrepo "$R7B"
printf 'code\n' >"$R7B/f.txt"
git -C "$R7B" add f.txt && git -C "$R7B" -c user.email=t@t -c user.name=t commit -qm f
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
bash|2026-01-02T00:00:00Z|tool-9|make test
result|2026-01-02T00:00:05Z|tool-9|false
text|2026-03-01T10:01:00Z|tests pass.
EOF
printf 'tie\n' >>"$R7B/f.txt"
TZ=UTC touch -t 202601020000.05 "$R7B/f.txt"
run_hook "$TMP_DIR/t.jsonl" "$R7B" "s7b"
jq -e 'select(.verdict == "unsubstantiated" and .reason == "run-not-newer-than-tree")' \
  "$TMPDIR/proof-shadow-s7b.jsonl" >/dev/null || fail "case7b: tie must be unsubstantiated"

# 7c. claim before the run: later evidence cannot substantiate it.
R7C="$TMP_DIR/r7c"
mkrepo "$R7C"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:00:00Z|tests pass, obviously.
bash|2026-03-01T10:02:00Z|tool-7|bun test
result|2026-03-01T10:02:05Z|tool-7|false
EOF
run_hook "$TMP_DIR/t.jsonl" "$R7C" "s7c"
jq -e 'select(.verdict == "unsubstantiated" and .reason == "no-prior-passing-run")' \
  "$TMPDIR/proof-shadow-s7c.jsonl" >/dev/null || fail "case7c: claim-before-run must be unsubstantiated"

# 8. malformed transcript + malformed stdin: exit 0, no crash.
R8="$TMP_DIR/r8"
mkrepo "$R8"
printf 'not json\n{"broken": \n' >"$TMP_DIR/t.jsonl"
printf '{"transcript_path":"%s","cwd":"%s","session_id":"s8"}' "$TMP_DIR/t.jsonl" "$R8" \
  | node "$HOOK" >/dev/null 2>&1 || fail "case8a: malformed transcript must exit 0"
printf 'garbage{{{' | node "$HOOK" >/dev/null 2>&1 || fail "case8b: malformed stdin must exit 0"
printf '' | node "$HOOK" >/dev/null 2>&1 || fail "case8c: empty stdin must exit 0"

# 9. ledger-dir sink when a run pointer exists.
R9="$TMP_DIR/r9"
mkrepo "$R9"
mkdir -p "$R9/.workflow/run-1"
printf '{"schema_version":1,"run":"run-1"}' >"$R9/.workflow/active-run.json"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|smoke vert ici.
EOF
run_hook "$TMP_DIR/t.jsonl" "$R9" "s9"
[ -f "$R9/.workflow/run-1/proof-shadow.jsonl" ] || fail "case9: no ledger-dir sink record"
jq -e 'select(.class == "smoke" and .claim == "smoke vert")' "$R9/.workflow/run-1/proof-shadow.jsonl" >/dev/null \
  || fail "case9: expected smoke record in ledger dir"

# 10. rotation at 200 records.
R10="$TMP_DIR/r10"
mkrepo "$R10"
mktranscript "$TMP_DIR/t.jsonl" <<'EOF'
text|2026-03-01T10:01:00Z|all green.
EOF
SINK10="$TMPDIR/proof-shadow-s10.jsonl"
python3 - "$SINK10" <<'PYEOF'
import io, sys
io.open(sys.argv[1], 'w', encoding='utf-8').write('{"fill":true}\n' * 200)
PYEOF
run_hook "$TMP_DIR/t.jsonl" "$R10" "s10"
[ -f "$SINK10.1" ] || fail "case10: rotation .1 missing"
[ "$(wc -l <"$SINK10.1" | tr -d ' ')" = "200" ] || fail "case10: rotated file must hold 200"
jq -e 'select(.class == "all-green")' "$SINK10" >/dev/null || fail "case10: fresh record missing"

# 11. schema over every produced record.
for sink in "$TMPDIR"/proof-shadow-s*.jsonl "$R9/.workflow/run-1/proof-shadow.jsonl"; do
  [ -s "$sink" ] || fail "empty sink $sink"
  jq -ne 'reduce inputs as $r (true; . and ($r.schema_version == 1 and ($r.verdict == "substantiated" or $r.verdict == "unsubstantiated" or $r.verdict == "unverifiable") and ($r.ts | type == "string") and ($r.session_id | type == "string") and ($r.claim | type == "string") and ($r.class | type == "string") and ($r.reason | type == "string"))) | select(. == true)' "$sink" >/dev/null \
    || fail "schema violation in $sink"
done

# 12. wiring: proof-shadow is third in the fragment Stop chain + hooks-check.
FRAG="$ROOT_DIR/claude/settings.workflow-hooks.json"
[ "$(jq -r '.hooks.Stop[2].hooks[0].command' "$FRAG")" = 'node "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/proof-shadow.mjs"' ] \
  || fail "fragment Stop[2] must be proof-shadow"
[ "$(jq -r '.hooks.Stop[2].hooks[0].timeout' "$FRAG")" = "5" ] \
  || fail "fragment proof-shadow timeout must be 5"
FAKE_HOME="$TMP_DIR/fakehome"
mkdir -p "$FAKE_HOME/.claude/hooks"
jq '{hooks: .hooks}' "$FRAG" >"$FAKE_HOME/.claude/settings.json"
for script in detect-adr-signal outcome-metric-emit proof-shadow plan-ready-guard no-comments-guard ledger-auto-emit; do
  touch "$FAKE_HOME/.claude/hooks/$script.mjs"
done
"$ROOT_DIR/scripts/claude-hooks-check" --home "$FAKE_HOME" >/dev/null 2>&1 \
  || fail "claude-hooks-check must pass with proof-shadow wired"

printf 'PASS: proof-shadow smoke (envelope fixtures, verdicts, sink, wiring)\n'
