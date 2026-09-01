#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HOOK="$ROOT_DIR/claude/hooks/detect-adr-signal.mjs"
POLICY="$ROOT_DIR/claude/hooks/adr-signal-policy.mjs"
FIXTURES="$ROOT_DIR/tests/fixtures/adr-hook"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_contains() {
  case "$2" in
  *"$1"*) ;;
  *)
    printf 'expected output to contain: %s\n%s\noutput was:\n%s\n' "$1" "${3:-}" "$2" >&2
    exit 1
    ;;
  esac
}

assert_empty() {
  if [ -n "$1" ]; then
    printf '%s\nexpected empty output, got:\n%s\n' "$2" "$1" >&2
    exit 1
  fi
}

new_repo() {
  local dir="$TMP_DIR/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t.t
  git -C "$dir" config user.name t
  git -C "$dir" commit -q --allow-empty -m init
  printf '%s' "$dir"
}

run_hook() {
  local cwd="$1" msg="$2" transcript="${3:-/dev/null}" active="${4:-false}" hook="${HOOK_OVERRIDE:-$HOOK}" out status=0
  # without this, a hook that dies before reaching the guard under test reads as a pass:
  # inside out="$(run_hook ...)" a failing assignment does not abort, and printf returns 0
  out="$(
    node -e 'process.stdout.write(JSON.stringify({ cwd: process.argv[1], last_assistant_message: process.argv[2], transcript_path: process.argv[3], stop_hook_active: JSON.parse(process.argv[4]) }))' \
      "$cwd" "$msg" "$transcript" "$active" |
      node "$hook" 2>"$TMP_DIR/stderr"
  )" || status=$?
  if [ "$status" -ne 0 ]; then
    printf 'hook exited %s; a Stop hook must always exit 0\n' "$status" >&2
    exit 1
  fi
  if [ -s "$TMP_DIR/stderr" ]; then
    printf 'hook wrote to stderr, which Claude Code surfaces as a hook failure:\n%s\n' "$(cat "$TMP_DIR/stderr")" >&2
    exit 1
  fi
  printf '%s' "$out"
}

# M7 guard: the whole point of the change is a TOP-LEVEL decision/reason. A substring
# assertion passes on {"systemMessage":...,"ignored":{"decision":"block"}}, which reaches
# the model exactly as the old advisory did, so parse the payload instead.
assert_block_payload() {
  node -e '
    let payload;
    try { payload = JSON.parse(process.argv[1]); } catch { console.error("payload is not JSON"); process.exit(1); }
    for (const key of ["decision", "reason", "systemMessage"]) {
      if (!Object.prototype.hasOwnProperty.call(payload, key)) { console.error("missing top-level key: " + key); process.exit(1); }
    }
    if (payload.decision !== "block") { console.error("top-level decision is not block"); process.exit(1); }
    if (typeof payload.reason !== "string") { console.error("top-level reason is not a string"); process.exit(1); }
    for (const phrase of [
      "apply its three-condition gate",
      "If any condition fails, say so in one line and stop",
      "do not run git, do not read docs/adr",
    ]) {
      if (!payload.reason.includes(phrase)) { console.error("reason lost its contract: " + phrase); process.exit(1); }
    }
  ' "$1" || {
    printf '%s\n' "${2:-block payload is wrong}" >&2
    exit 1
  }
}

DECISION="We chose Postgres rather than Mongo for transactional consistency."

# 0. The nudge hands the skill to the model, so the skill must stay model-invocable.
#    Same guard as validator-smoke.sh:39 and verify-fixes-smoke.sh, applied to adr.
SKILL_DIR="$ROOT_DIR/claude/scopes/shared/skills/adr"
if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  printf 'the hook orders the model to invoke the adr skill, but %s/SKILL.md is missing\n' "$SKILL_DIR" >&2
  exit 1
fi
if grep -rq --include='*.md' '^disable-model-invocation:' "$SKILL_DIR"; then
  printf 'adr must stay model-invocable: the Stop hook blocks and tells the model to invoke it\n' >&2
  exit 1
fi

# 1. no signal: empty cwd, no decision marker -> silent
out="$(run_hook /tmp "hello")"
assert_empty "$out" "no-signal case should emit nothing"

# 2. primary path: structural untracked file + decision marker in last_assistant_message
repo="$(new_repo primary)"
echo '{}' >"$repo/package.json"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"systemMessage"' "$out"

# 2b. payload shape: the nudge must reach the MODEL, not only the human.
#     The phrases are pinned whole: "skip its three-condition gate" or "do not run git
#     before the full skill" would invert the contract while still containing the bare
#     words "gate" and "do not run git".
repo="$(new_repo payload-shape)"
echo '{}' >"$repo/package.json"
out="$(run_hook "$repo" "$DECISION")"
assert_block_payload "$out" "the block must be top-level, with the contract inside reason"

# 3. fallback path: no last_assistant_message, decision marker in transcript (flat envelope)
repo="$(new_repo fallback)"
echo '{}' >"$repo/package.json"
printf '%s\n' '{"role":"assistant","content":"On choisit Postgres plutôt que Mongo."}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "" "$repo/t.jsonl")"
assert_block_payload "$out" "the transcript fallback must emit the same top-level block"

# 3b. fallback path: real Claude Code transcript envelope {type,message:{role,content:[{type:text,text}]}}
repo="$(new_repo fallback-real-envelope)"
echo '{}' >"$repo/package.json"
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"We chose Postgres rather than Mongo."}]}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "" "$repo/t.jsonl")"
assert_block_payload "$out" "real transcript envelope should be parsed via transcript_path"

repo="$(new_repo fallback-adverb)"
echo '{}' >"$repo/package.json"
printf '%s\n' '{"role":"assistant","content":"Nous avons finalement décidé dutiliser Redis"}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "" "$repo/t.jsonl")"
assert_block_payload "$out" "the accented participle must arm through the fallback path"

# 4. non-structural change only (README) + decision marker -> silent (AND not satisfied)
repo="$(new_repo nonstructural)"
echo hi >"$repo/README.md"
out="$(run_hook "$repo" "$DECISION")"
assert_empty "$out" "non-structural change should not trigger"

# 5. structural change but no decision marker -> silent
repo="$(new_repo nomarker)"
echo '{}' >"$repo/package.json"
out="$(run_hook "$repo" "just renamed a variable, nothing notable")"
assert_empty "$out" "missing decision marker should not trigger"

# 6. an ADR already present in docs/adr must NOT suppress: the hook used to die after the
#    first recorded decision, which is the whole of issue 46.
repo="$(new_repo existing-adr-dirty)"
echo '{}' >"$repo/package.json"
mkdir -p "$repo/docs/adr"
echo '# x' >"$repo/docs/adr/2026-06-26-x.md"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"decision":"block"' "$out" "an uncommitted ADR must not suppress the nudge"

# 6b. same for a COMMITTED ADR: the old git ls-files branch is gone
repo="$(new_repo existing-adr-committed)"
mkdir -p "$repo/docs/adr"
echo '# x' >"$repo/docs/adr/2026-06-26-x.md"
git -C "$repo" add docs/adr/2026-06-26-x.md
git -C "$repo" commit -q -m "add adr"
echo '{}' >"$repo/package.json"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"decision":"block"' "$out" "a committed ADR must not suppress the nudge"

# 6c. re-entry guard: the Stop that follows our own block carries stop_hook_active true
repo="$(new_repo reentry)"
echo '{}' >"$repo/package.json"
out="$(run_hook "$repo" "$DECISION" /dev/null true)"
assert_empty "$out" "stop_hook_active must short-circuit, or a block re-enters itself"

repo="$(new_repo reentry-string)"
echo '{}' >"$repo/package.json"
out="$(
  node -e 'process.stdout.write(JSON.stringify({ cwd: process.argv[1], last_assistant_message: process.argv[2], transcript_path: "/dev/null", stop_hook_active: "true" }))' \
    "$repo" "$DECISION" |
    node "$HOOK" 2>"$TMP_DIR/stderr"
)"
assert_contains '"decision":"block"' "$out" "a string stop_hook_active must not short-circuit"

# 6d. already nudged this session, checked against the record Claude Code REALLY wrote.
#     See fixtures/adr-hook/PROVENANCE.md: captured from a live claude -p run, not
#     hand-built, so this case fails if the harness ever changes that shape.
repo="$(new_repo already-nudged)"
echo '{}' >"$repo/package.json"
cp "$FIXTURES/real-blocked-stop.jsonl" "$repo/t.jsonl"
out="$(run_hook "$repo" "$DECISION" "$repo/t.jsonl")"
assert_empty "$out" "the real harness block record must suppress the second nudge"

# 6d-bis. two bare substrings on one line are NOT a block record: reading this hook's own
#         source puts both into the transcript, and that must not kill the nudge.
repo="$(new_repo substring-lookalike)"
echo '{}' >"$repo/package.json"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"here is the file: line.includes(\"hook_blocking_error\") && line.includes(HOOK_FILENAME) in detect-adr-signal.mjs"}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "$DECISION" "$repo/t.jsonl")"
assert_contains '"decision":"block"' "$out" "a transcript line merely quoting the record format must not suppress"

# 6e. another hook's block must not suppress ours
repo="$(new_repo other-hook-blocked)"
echo '{}' >"$repo/package.json"
printf '%s\n' '{"type":"attachment","attachment":{"type":"hook_blocking_error","hookEvent":"Stop","blockingError":{"blockingError":"...","command":"node /somewhere/hooks/some-other-hook.mjs"}}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "$DECISION" "$repo/t.jsonl")"
assert_contains '"decision":"block"' "$out" "suppression must key on this hook, not on any blocking hook"

repo="$(new_repo wrong-type)"
echo '{}' >"$repo/package.json"
printf '%s\n' '{"type":"attachment","attachment":{"type":"other_event","hookEvent":"Stop","blockingError":{"command":"node /somewhere/detect-adr-signal.mjs"}}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "$DECISION" "$repo/t.jsonl")"
assert_contains '"decision":"block"' "$out" "a non-hook_blocking_error attachment must not suppress"

printf '%s\n' '{"type":"attachment","attachment":{"type":"hook_blocking_error","hookEvent":"PreToolUse","blockingError":{"command":"node /somewhere/detect-adr-signal.mjs"}}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "$DECISION" "$repo/t.jsonl")"
assert_contains '"decision":"block"' "$out" "a non-Stop hookEvent must not suppress"

printf '%s\n' '{"type":"attachment","attachment":{"type":"hook_blocking_error","hookEvent":"Stop","blockingError":{"command":42}}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "$DECISION" "$repo/t.jsonl")"
assert_contains '"decision":"block"' "$out" "a non-string command must not suppress"

# 6f. a candidate line that carries the marker but is not parseable JSON, and one that
#      parses but has no blockingError, must both be ignored rather than throw.
repo="$(new_repo malformed-candidates)"
echo '{}' >"$repo/package.json"
{
  printf '%s\n' '{"type":"attachment","attachment":{"type":"hook_blocking_error" TRUNCATED'
  printf '%s\n' '{"type":"attachment","attachment":{"type":"hook_blocking_error","hookEvent":"Stop"}}'
} >"$repo/t.jsonl"
out="$(run_hook "$repo" "$DECISION" "$repo/t.jsonl")"
assert_contains '"decision":"block"' "$out" "malformed or incomplete block records must not suppress"

repo="$(new_repo fallback-garbage)"
echo '{}' >"$repo/package.json"
{
  printf '%s\n' 'this line is not json at all'
  printf '%s\n' '42'
  printf '%s\n' '{"role":"assistant","content":"On choisit Postgres plutôt que Mongo."}'
} >"$repo/t.jsonl"
out="$(run_hook "$repo" "" "$repo/t.jsonl")"
assert_block_payload "$out" "the fallback must skip non-JSON and non-object lines"

printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{}}]}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "" "$repo/t.jsonl")"
assert_empty "$out" "tool-only content yields no text and must not arm"

printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"We chose Postgres."}]}}' >"$repo/t.jsonl"
out="$(run_hook "$repo" "" "$repo/t.jsonl")"
assert_empty "$out" "a transcript without an assistant line must not arm"

# 6g. a bare JSON primitive on stdin parses fine, then must not throw on property access.
#     Only the first assertion pins new behaviour; the second is regression cover for the
#     pre-existing try/catch and stays green on a revert, deliberately.
out="$(printf 'null' | node "$HOOK" 2>&1)"
assert_empty "$out" "stdin 'null' must exit quietly, not crash the hook"
out="$(printf 'not json at all' | node "$HOOK" 2>&1)"
assert_empty "$out" "unparseable stdin must exit quietly (pre-existing behaviour)"

repo="$(new_repo unreadable-transcript)"
echo '{}' >"$repo/package.json"
out="$(run_hook "$repo" "$DECISION" "$TMP_DIR/does-not-exist.jsonl")"
assert_empty "$out" "an unreadable transcript must suppress the nudge"

repo="$(new_repo no-cwd-field)"
echo '{}' >"$repo/package.json"
out="$(cd "$repo" && node -e 'process.stdout.write(JSON.stringify({ last_assistant_message: process.argv[1], transcript_path: "/dev/null" }))' "$DECISION" | node "$HOOK" 2>"$TMP_DIR/stderr")"
assert_contains '"decision":"block"' "$out" "a missing cwd must fall back to process.cwd"

# 7. anti-noise: files containing auth as a substring are not structural auth
repo="$(new_repo authfalsepositive)"
echo 'export {}' >"$repo/author-card.tsx"
out="$(run_hook "$repo" "$DECISION")"
assert_empty "$out" "author-card.tsx should not trigger the auth structural gate"

# 8. real auth and middleware paths remain structural
repo="$(new_repo authpath)"
mkdir -p "$repo/src/auth"
echo 'export {}' >"$repo/src/auth/session.ts"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"systemMessage"' "$out"

repo="$(new_repo middlewarefile)"
mkdir -p "$repo/src"
echo 'export {}' >"$repo/src/middleware.ts"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"systemMessage"' "$out"

# 9. the wiring, not just the file. Renaming the command in hooks.json breaks the hook at
#    runtime while this suite, which calls the script directly, would stay green.
SETTINGS="$ROOT_DIR/claude/settings.workflow-hooks.json"
WIRED_CMD="$(node -e '
  const doc = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const entry = (doc.hooks.Stop || []).flatMap((s) => s.hooks || []).find((h) => (h.command || "").includes("detect-adr-signal.mjs"));
  if (!entry) process.exit(1);
  process.stdout.write(entry.command);
' "$SETTINGS")" || { printf 'settings.workflow-hooks.json no longer wires the Stop nudge hook\n' >&2; exit 1; }
case "$WIRED_CMD" in
  *detect-adr-signal.mjs*) ;;
  *) printf 'the wired Stop command no longer points at the nudge hook: %s\n' "$WIRED_CMD" >&2; exit 1 ;;
esac
if [ ! -f "$HOOK" ]; then
  printf 'the wired Stop hook file does not exist: %s\n' "$HOOK" >&2
  exit 1
fi

# 10. every structural pattern must still arm the gate. Deleting one used to stay green.
i=0
for f in package.json tsconfig.build.json vite.config.ts schema.prisma migrations/001.sql \
  Dockerfile docker-compose.yml .github/workflows/ci.yml api/user.proto \
  src/auth/session.ts src/middleware.ts; do
  i=$((i + 1))
  repo="$(new_repo "structural-$i")"
  mkdir -p "$repo/$(dirname "$f")"
  echo 'x' >"$repo/$f"
  out="$(run_hook "$repo" "$DECISION")"
  assert_contains '"decision":"block"' "$out" "structural pattern no longer armed: $f"
done
PATTERN_COUNT="$(node -e '
  const src = require("fs").readFileSync(process.argv[1], "utf8");
  const body = src.slice(src.indexOf("const STRUCTURAL_PATTERNS = ["), src.indexOf("];", src.indexOf("const STRUCTURAL_PATTERNS = [")));
  process.stdout.write(String([...body.matchAll(/^\s+\//gm)].length));
' "$HOOK")"
if [ "$i" -ne "$PATTERN_COUNT" ]; then
  printf 'structural fixtures (%s) do not cover every pattern (%s); add a fixture\n' "$i" "$PATTERN_COUNT" >&2
  exit 1
fi

# 10b. a rename must arm the gate from EITHER side: keeping only the destination (the old
#      parser) made removing a structural file invisible. The second case pins unquotePath
#      instead — git quotes any path with a space, and the leading quote defeats every
#      STRUCTURAL_PATTERNS anchor.
repo="$(new_repo rename-source)"
echo '{}' >"$repo/package.json"
git -C "$repo" add package.json && git -C "$repo" commit -q -m "add package.json"
mkdir -p "$repo/cfg"
git -C "$repo" mv package.json cfg/renamed.json
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"decision":"block"' "$out" "a renamed-away structural file must arm the gate"

repo="$(new_repo quoted-path)"
mkdir -p "$repo/migrations"
echo 'x' >"$repo/migrations/002 space.sql"
out="$(run_hook "$repo" "$DECISION")"
assert_contains '"decision":"block"' "$out" "a quoted path must be unquoted before matching"

# 10c. a closed stdout must stay silent and exit 0. Without an error listener the write
#      raises an unhandled 'error' event: stack trace on stderr, exit 1, payload lost.
#      Unreachable from the cases above, because out="$(...)" always drains to EOF.
repo="$(new_repo closed-stdout)"
echo '{}' >"$repo/package.json"
node -e '
  const { spawn } = require("node:child_process");
  const [hook, cwd] = process.argv.slice(1);
  const p = spawn("node", [hook], { stdio: ["pipe", "pipe", "pipe"] });
  let err = "";
  p.stderr.on("data", (d) => (err += d));
  p.stdout.destroy();
  p.stdin.end(JSON.stringify({ cwd, last_assistant_message: "We chose Postgres rather than Mongo.", transcript_path: "/dev/null" }));
  p.on("exit", (code) => {
    if (code === 0 && err === "") process.exit(0);
    console.error(`closed stdout: exit=${code}, stderr=${err.split("\n")[0]}`);
    process.exit(1);
  });
' "$HOOK" "$repo" || {
  printf 'a closed stdout must exit 0 and silent, or every cancelled turn reports a hook failure\n' >&2
  exit 1
}

node --input-type=module -e '
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
const [policyPath, corpusPath] = process.argv.slice(1);
const policy = await import(pathToFileURL(policyPath).href);
const lines = readFileSync(corpusPath, "utf8").split("\n").filter(Boolean);
const lowerLines = lines.map((l) => l.toLowerCase());
const foldedLines = lowerLines.map((l) => policy.foldAccents(l));
const tokenLines = foldedLines.map((l) => l.split(/[^a-z0-9]+/).filter(Boolean));
const missing = [];
for (const m of policy.ACCENTED_MARKERS) {
  if (!lowerLines.some((l) => l.includes(m))) missing.push(m);
}
for (const m of policy.FOLDED_MARKERS) {
  if (!foldedLines.some((l) => l.includes(m))) missing.push(m);
}
for (const [subject, auxiliary] of policy.ACCENTLESS_SEQUENCES) {
  const hit = tokenLines.some((tokens) => {
    for (let i = 0; i + 1 < tokens.length; i += 1) {
      if (tokens[i] !== subject || tokens[i + 1] !== auxiliary) continue;
      for (let j = i + 2; j <= i + 4 && j < tokens.length; j += 1) {
        if (["decide", "decidee", "decidees"].includes(tokens[j])) return true;
      }
    }
    return false;
  });
  if (!hit) missing.push(subject + " " + auxiliary);
}
if (missing.length > 0) {
  console.error("marker without a corpus witness: " + missing.join(", "));
  process.exit(1);
}
' "$POLICY" "$FIXTURES/corpus-decide.txt" || {
  printf 'every declared marker needs at least one corpus-decide witness line\n' >&2
  exit 1
}

SILENT_MSGS=(
  "let you decide"
  "the caller decides"
  "undecided"
  "The AI decides which model to route to."
  "the AI decided to retry the request"
  "the front decides the layout"
  "there is a decided lack of tests here"
  "the media decide"
  "I'll let a human decide the rollback plan."
  "we'll let a bot decide the retry policy."
  "let a committee decide"
  "we insist that the AI decide promptly"
  "The ONT can decide which uplink to use."
  "Have a worker decide whether to retry."
  "it hinges on a flag we decide later"
  "The 'AI will decide' label is documentation."
  "j ai renomme une variable"
  "les tests passent, rien de notable"
)
quiet_repo="$(new_repo matrix-quiet)"
echo '{}' >"$quiet_repo/package.json"
for msg in "${SILENT_MSGS[@]}"; do
  out="$(run_hook "$quiet_repo" "$msg")"
  assert_empty "$out" "matrix silent row must not arm the nudge: $msg"
done

TRIGGER_MSGS=(
  "Nous avons finalement décidé d'utiliser Redis"
  "nous avons decide"
  "Nous avons peut-être décidé de migrer"
  "les options que nous avons décidées"
  "j'ai decide"
  "j ai decide de partir sur postgres"
  "j’ai décidé d’utiliser Redis"
  "ils ont decide de migrer"
  "On a décidé de partir sur Postgres"
  "on a finalement décidé de migrer"
  "on a ecarte Mongo"
  "plutot qu'un autre SGBD"
  "On choisit Postgres plutôt que Mongo"
  "l'option choisie"
  "les options choisies"
  "NOUS AVONS DÉCIDÉ"
  "nous avons peut-etre decide de migrer"
  "les options que nous avons decidees"
  "j’ai decide de partir sur la BDD"
  "Nous avons choisi PostgreSQL plutôt qu un autre SGBD."
  "On part sur Postgres plutôt qu un autre SGBD."
  "On part sur Redis plutot qu un autre cache."
  "J ai choisi Postgres."
  "Il a choisi Mongo."
  "On a opté pour Redis."
  "nous avons choisi plutot qu un autre"
  "We decided to drop MongoDB."
  "We chose Postgres."
  "the chosen index is btree"
  "Postgres rather than Mongo"
  "a real trade-off to record"
  "We opted for Redis."
  "Postgres instead of Mongo."
)
trigger_repo="$(new_repo matrix-trigger)"
echo '{}' >"$trigger_repo/package.json"
for msg in "${TRIGGER_MSGS[@]}"; do
  out="$(run_hook "$trigger_repo" "$msg")"
  assert_contains '"decision":"block"' "$out" "matrix trigger row must arm the nudge: $msg"
done

corpus_repo="$(new_repo corpus)"
echo '{}' >"$corpus_repo/package.json"
while IFS= read -r msg; do
  [ -n "$msg" ] || continue
  out="$(run_hook "$corpus_repo" "$msg")"
  assert_contains '"decision":"block"' "$out" "corpus-decide line must arm the nudge: $msg"
done <"$FIXTURES/corpus-decide.txt"
while IFS= read -r msg; do
  [ -n "$msg" ] || continue
  out="$(run_hook "$corpus_repo" "$msg")"
  assert_empty "$out" "corpus-quiet line must not arm the nudge: $msg"
done <"$FIXTURES/corpus-quiet.txt"

repo="$(new_repo self-arm)"
echo '{}' >"$repo/package.json"
out="$(run_hook "$repo" "$DECISION")"
assert_block_payload "$out" "self-arm round-trip needs the real payload"
reason="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).reason)' "$out")"
out="$(run_hook "$repo" "$reason")"
assert_empty "$out" "MODEL_INSTRUCTION must not itself arm the nudge"

stub="$TMP_DIR/failing-hook.mjs"
printf 'process.exit(1);\n' >"$stub"
stub_err="$TMP_DIR/stub-err"
if HOOK_OVERRIDE="$stub" out="$(run_hook /tmp hello 2>"$stub_err")"; then
  printf 'run_hook must abort when the hook exits non-zero\n' >&2
  exit 1
fi
if ! grep -q 'hook exited 1' "$stub_err"; then
  printf 'run_hook must name the non-zero exit code\n' >&2
  exit 1
fi

printf 'adr hook smoke test: ok\n'
