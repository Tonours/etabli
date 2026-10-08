#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HELPER="$ROOT_DIR/scripts/pi-review-hunter"

fail() {
  printf 'pi-review-hunter-smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$HELPER" ] || fail "scripts/pi-review-hunter must be executable. Remediation: chmod +x scripts/pi-review-hunter"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

PROMPT_FILE="$TMP_DIR/prompt.md"
PATCH_FILE="$TMP_DIR/patch.diff"
printf 'Axis: Logic\n' >"$PROMPT_FILE"
printf 'diff --git a/x b/x\n+ok\n' >"$PATCH_FILE"

# --print-argv must work without GNU timeout, pi, or a leaked timeout env var.
out="$(env -u PI_REVIEW_HUNTER_TIMEOUT PATH=/usr/bin:/bin "$HELPER" --print-argv --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --model 'cursor/claude-opus-5-5@300k')"

printf '%s\n' "$out" | grep -Fx -- '--no-session' >/dev/null || fail "expected --no-session in argv"
printf '%s\n' "$out" | grep -Fx -- '-p' >/dev/null || fail "expected -p in argv"
printf '%s\n' "$out" | grep -Fx -- '--append-system-prompt' >/dev/null || fail "expected --append-system-prompt in argv"
printf '%s\n' "$out" | grep -Fx -- "$PROMPT_FILE" >/dev/null || fail "expected prompt file in argv"
printf '%s\n' "$out" | grep -Fx -- '--no-skills' >/dev/null || fail "expected --no-skills in argv"
printf '%s\n' "$out" | grep -Fx -- '--no-extensions' >/dev/null || fail "expected --no-extensions in argv"
printf '%s\n' "$out" | grep -Fx -- '--no-context-files' >/dev/null || fail "expected --no-context-files in argv"
real_root="$(cd -P "$ROOT_DIR" && pwd)"
printf '%s\n' "$out" | grep -Fx -- "$real_root/pi/extensions/filter-output.ts" >/dev/null || fail "expected the redaction extension in argv"
mkdir -p "$TMP_DIR/linked-dir" "$TMP_DIR/linked-file"
ln -s "$ROOT_DIR/scripts" "$TMP_DIR/linked-dir/scripts"
ln -s "$HELPER" "$TMP_DIR/linked-file/pi-review-hunter"
for linked in "$TMP_DIR/linked-dir/scripts/pi-review-hunter" "$TMP_DIR/linked-file/pi-review-hunter"; do
  linked_out="$("$linked" --print-argv --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE")"
  printf '%s\n' "$linked_out" | grep -Fx -- "$real_root/pi/extensions/filter-output.ts" >/dev/null ||
    fail "redaction extension path must resolve through $linked"
done
printf '%s\n' "$out" | grep -Fx -- '--mode' >/dev/null || fail "expected --mode in argv"
printf '%s\n' "$out" | grep -Fx -- 'json' >/dev/null || fail "expected native JSON mode in argv"
printf '%s\n' "$out" | grep -Fx -- 'read,grep' >/dev/null || fail "expected read,grep tools in argv"
printf '%s\n' "$out" | grep -Fq -- "@${PATCH_FILE}" || fail "expected @patch transport in argv"
printf '%s\n' "$out" | grep -Eq '^TIMEOUT=600$' || fail "expected TIMEOUT=600 header"
if printf '%s\n' "$out" | grep -Fq -- '--model'; then
  fail "cursor/ model must be omitted from argv"
fi

bad_timeout_rc=0
PATH=/usr/bin:/bin "$HELPER" --print-argv --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --timeout abc >/dev/null 2>"$TMP_DIR/bad-timeout.err" || bad_timeout_rc=$?
[ "$bad_timeout_rc" -eq 2 ] || fail "non-integer --timeout must exit 2"
grep -Fq 'timeout must be a positive integer' "$TMP_DIR/bad-timeout.err" || fail "non-integer --timeout must print a diagnostic"

empty_patch="$TMP_DIR/empty.diff"
: >"$empty_patch"
empty_rc=0
PATH=/usr/bin:/bin "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$empty_patch" >/dev/null 2>"$TMP_DIR/empty-patch.err" || empty_rc=$?
[ "$empty_rc" -eq 2 ] || fail "empty patch must exit 2"
grep -Fq 'empty patch is not a clean hunt' "$TMP_DIR/empty-patch.err" || fail "empty patch must print a diagnostic"

missing_pi_rc=0
PATH=/usr/bin:/bin "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" >/dev/null 2>"$TMP_DIR/missing-pi.err" || missing_pi_rc=$?
[ "$missing_pi_rc" -eq 2 ] || fail "missing pi must exit 2"
grep -Fq 'pi not on PATH' "$TMP_DIR/missing-pi.err" || fail "missing pi must print HUNTER_SPAWN_UNAVAILABLE"

out_model="$("$HELPER" --print-argv --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --model 'zai/glm-5.3')"
printf '%s\n' "$out_model" | grep -Fx -- '--model' >/dev/null || fail "non-cursor model must be passed"
printf '%s\n' "$out_model" | grep -Fx -- 'zai/glm-5.3' >/dev/null || fail "expected resolved model id"

review_md="$ROOT_DIR/workflow/skills/review.md"
pi_review="$ROOT_DIR/pi/skills/review/SKILL.md"
for pin in --no-session --no-skills --no-extensions --no-context-files read,grep '--mode text'; do
  grep -Fq -- "$pin" "$review_md" || fail "workflow/skills/review.md missing argv pin $pin"
  grep -Fq -- "$pin" "$pi_review" || fail "pi/skills/review/SKILL.md missing argv pin $pin"
done

# Real wrapper/capture, simulated native stream: no provider claim.
mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/pi" <<'PI'
#!/usr/bin/env node
if(process.env.FIXTURE_JSON==="bad")process.stdout.write("bad-json\\n");
const usage={input:10,output:3,cacheRead:7,cacheWrite:0,totalTokens:20};
const emit=event=>process.stdout.write(JSON.stringify(event)+"\n");
const assistant=(responseId,stopReason,content)=>({type:"message_end",message:{role:"assistant",responseId,provider:"fixture",model:"fixture",stopReason,content,usage:process.env.FIXTURE_USAGE==="missing"?undefined:usage,timestamp:1}});
emit(assistant("smoke-call","toolUse",[{type:"toolCall",id:"smoke-read",name:"read",arguments:{path:"missing-sibling.mjs"}}]));
emit({type:"message_end",message:{role:"toolResult",toolCallId:"smoke-read",toolName:"read",isError:process.env.FIXTURE_READ_ERROR!=="false",timestamp:2,content:[{type:"text",text:"fixture result"}]}});
emit(assistant("smoke-final","stop",[{type:"text",text:process.env.FIXTURE_VERDICT||"Verdict: GO"}]));
PI
chmod +x "$TMP_DIR/bin/pi"
capture="$TMP_DIR/failed-read-capture"
capture_rc=0
PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" \
  --capture-dir "$capture" --pass-id wrapper-failed-read --role logic \
  >"$TMP_DIR/capture.stdout" 2>"$TMP_DIR/capture.stderr" || capture_rc=$?
[ "$capture_rc" -eq 2 ] || fail "GO after failed Read must exit 2"
[ ! -s "$TMP_DIR/capture.stdout" ] || fail "inadmissible GO leaked to stdout"
grep -Fq HUNTER_INSPECTION_INCOMPLETE "$TMP_DIR/capture.stderr" || fail "expected inspection diagnostic"
node - "$capture" <<'CHECK'
const assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path");
const root=process.argv[2],json=name=>JSON.parse(fs.readFileSync(path.join(root,name),"utf8"));
const receipt=json("receipt.json");
assert.equal(receipt.terminal,"succeeded");assert.equal(receipt.measured,true);assert.equal(receipt.review_admissible,false);
assert.equal(receipt.usage.total_tokens,40);assert.deepEqual(receipt.measurement_errors,[]);
assert.equal(receipt.inspection.unresolved.length,1);assert.equal(receipt.inspection.unresolved[0].reason,"tool_error");
assert.equal(fs.readFileSync(path.join(root,"final.txt"),"utf8").trim(),"Verdict: GO");
const event=json("usage-event.json");assert.equal(event.success,true);assert.equal(event.success_kind,"run_terminal");assert.equal(event.review_admissible,false);
CHECK
FIXTURE_VERDICT='Verdict: BLOCK' PATH="$TMP_DIR/bin:$PATH" "$HELPER" \
 --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --capture-dir "$TMP_DIR/block-capture" \
 --pass-id wrapper-block --role logic >"$TMP_DIR/block.stdout"
grep -Fxq 'Verdict: BLOCK' "$TMP_DIR/block.stdout" || fail "negative report should remain admissible"
FIXTURE_READ_ERROR=false FIXTURE_VERDICT='Verdict: READY' PATH="$TMP_DIR/bin:$PATH" "$HELPER" \
 --prompt-file "$PROMPT_FILE" --patch "$ROOT_DIR/tests/fixtures/execution-quality/ready-plan.md" \
 --capture-dir "$TMP_DIR/plan-capture" --pass-id wrapper-plan --role adversary-plan >"$TMP_DIR/plan.stdout"
expected_hash="$($ROOT_DIR/scripts/plan-review-check --hash "$ROOT_DIR/tests/fixtures/execution-quality/ready-plan.md")"
jq -e --arg hash "$expected_hash" '.review_admissible and .plan_contract_sha256 == $hash' "$TMP_DIR/plan-capture/receipt.json" >/dev/null || fail "plan capture must bind frozen reviewed contract"

# Default invocation must use the same admission, without imposing measurement.
mkdir -p "$TMP_DIR/auto"
default_rc=0
TMPDIR="$TMP_DIR/auto" PATH="$TMP_DIR/bin:$PATH" "$HELPER" --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" \
 >"$TMP_DIR/default.stdout" 2>"$TMP_DIR/default.stderr" || default_rc=$?
[ "$default_rc" -eq 2 ] && [ ! -s "$TMP_DIR/default.stdout" ] || fail "default GO must reject failed Read"
grep -Fq HUNTER_INSPECTION_INCOMPLETE "$TMP_DIR/default.stderr" || fail "default admission diagnostic missing"
FIXTURE_READ_ERROR=false FIXTURE_USAGE=missing TMPDIR="$TMP_DIR/auto" PATH="$TMP_DIR/bin:$PATH" "$HELPER" \
 --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" >"$TMP_DIR/default-ok.stdout" 2>"$TMP_DIR/default-ok.stderr"
grep -Fxq 'Verdict: GO' "$TMP_DIR/default-ok.stdout" || fail "default transport compatibility lost"
auto_capture="$(sed -n 's/^HUNTER_CAPTURE: //p' "$TMP_DIR/default-ok.stderr")"
jq -e '.terminal=="succeeded" and .review_admissible and (.measured|not) and (.measurement_required|not)' "$auto_capture/receipt.json" >/dev/null || fail "measurement must stay honest and separate"
explicit_rc=0
FIXTURE_READ_ERROR=false FIXTURE_USAGE=missing PATH="$TMP_DIR/bin:$PATH" "$HELPER" \
 --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" --capture-dir "$TMP_DIR/explicit-unmeasured" \
 --pass-id explicit-unmeasured --role logic >"$TMP_DIR/unmeasured.stdout" 2>"$TMP_DIR/unmeasured.stderr" || explicit_rc=$?
[ "$explicit_rc" -eq 2 ] || fail "explicit capture must retain measurement requirement"

malformed_rc=0
FIXTURE_READ_ERROR=false FIXTURE_JSON=bad TMPDIR="$TMP_DIR/auto" PATH="$TMP_DIR/bin:$PATH" "$HELPER" \
 --prompt-file "$PROMPT_FILE" --patch "$PATCH_FILE" >"$TMP_DIR/malformed.stdout" 2>"$TMP_DIR/malformed.stderr" || malformed_rc=$?
[ "$malformed_rc" -eq 2 ] && [ ! -s "$TMP_DIR/malformed.stdout" ] || fail "unmeasured policy must not admit malformed native JSON"

printf 'pi-review-hunter smoke test: ok\n'
