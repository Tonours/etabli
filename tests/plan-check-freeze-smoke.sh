#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CLI="$ROOT_DIR/scripts/plan-check-freeze"
FIX="$ROOT_DIR/tests/fixtures/plan-check-freeze"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'plan-check-freeze smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$CLI" ] || fail "CLI not executable"

# Strengthen-only: add a check while READY → pass
set +e
"$CLI" --previous "$FIX/ready-baseline.md" --current "$FIX/ready-strengthened.md" >"$TMP/ok.json" 2>"$TMP/ok.err"
ok_status=$?
set -e
[ "$ok_status" -eq 0 ] || fail "strengthen-only should pass: $(cat "$TMP/ok.err" "$TMP/ok.json")"
jq -e '.ok == true' "$TMP/ok.json" >/dev/null

# Weaken READY without CHALLENGED → fail
set +e
"$CLI" --previous "$FIX/ready-baseline.md" --current "$FIX/ready-weakened.md" >"$TMP/bad.json" 2>"$TMP/bad.err"
bad_status=$?
set -e
[ "$bad_status" -ne 0 ] || fail "weaken READY should fail"
jq -e '.ok == false and (.removed | length) >= 1' "$TMP/bad.json" >/dev/null ||
  fail "expected removed checks: $(cat "$TMP/bad.json")"

# Weaken after CHALLENGED + Decision Log rationale → pass
set +e
"$CLI" --previous "$FIX/ready-baseline.md" --current "$FIX/challenged-weaken-ok.md" >"$TMP/ch.json" 2>"$TMP/ch.err"
ch_status=$?
set -e
[ "$ch_status" -eq 0 ] || fail "challenged weaken with rationale should pass: $(cat "$TMP/ch.json")"
jq -e '.demote_mode == "keyword"' "$TMP/ch.json" >/dev/null ||
  fail "expected demote_mode keyword: $(cat "$TMP/ch.json")"

# Structured check_freeze_demote: line
set +e
"$CLI" --previous "$FIX/ready-baseline.md" --current "$FIX/challenged-weaken-structured-ok.md" >"$TMP/st.json" 2>"$TMP/st.err"
st_status=$?
set -e
[ "$st_status" -eq 0 ] || fail "structured demote should pass: $(cat "$TMP/st.json")"
jq -e '.demote_mode == "structured" and (.demote_reason | type) == "string" and (.demote_reason | length) > 0' "$TMP/st.json" >/dev/null ||
  fail "expected structured demote fields: $(cat "$TMP/st.json")"

# Acceptance Criteria are frozen the same way as Checks
set +e
"$CLI" --previous "$FIX/ready-with-ac-baseline.md" --current "$FIX/ready-ac-weakened.md" >"$TMP/ac-bad.json" 2>"$TMP/ac-bad.err"
ac_bad=$?
set -e
[ "$ac_bad" -ne 0 ] || fail "Acceptance Criteria weaken READY should fail"
jq -e '.ok == false and (.removed | length) >= 1' "$TMP/ac-bad.json" >/dev/null ||
  fail "expected removed acceptance criteria: $(cat "$TMP/ac-bad.json")"

set +e
"$CLI" --previous "$FIX/ready-with-ac-baseline.md" --current "$FIX/ready-ac-strengthened.md" >"$TMP/ac-ok.json" 2>"$TMP/ac-ok.err"
ac_ok=$?
set -e
[ "$ac_ok" -eq 0 ] || fail "Acceptance Criteria strengthen should pass: $(cat "$TMP/ac-ok.json")"
jq -e '.ok == true' "$TMP/ac-ok.json" >/dev/null

# Nested expected results and the full-template Validation Plan are frozen.
cat >"$TMP/expected-before.md" <<'MD'
- Status: READY
## Checks
- command: npm test
  - expected: all tests pass
  - last run: not run
MD
cat >"$TMP/expected-weakened.md" <<'MD'
- Status: READY
## Checks
- command: npm test
  - expected: one test passes
  - last run: not run
MD
if "$CLI" --previous "$TMP/expected-before.md" --current "$TMP/expected-weakened.md" >"$TMP/expected.json"; then
  fail "weakening a nested expected result should fail"
fi
jq -e '.removed | length == 1' "$TMP/expected.json" >/dev/null ||
  fail "expected-result removal was not reported: $(cat "$TMP/expected.json")"

cat >"$TMP/html-comment-command-before.md" <<'MD'
- Status: READY
## Checks
- command: grep '<!--alpha-->' source.html
  - expected: matches <!--alpha--> output
MD
cat >"$TMP/html-comment-command-after.md" <<'MD'
- Status: READY
## Checks
- command: grep '<!--beta-->' source.html
  - expected: matches <!--beta--> output
MD
if "$CLI" --previous "$TMP/html-comment-command-before.md" --current "$TMP/html-comment-command-after.md" >"$TMP/html-comment-command.json"; then
  fail "changing raw HTML-comment bytes in a command and expected result should fail"
fi
jq -e '.removed | length == 2' "$TMP/html-comment-command.json" >/dev/null ||
  fail "raw command and expected identities were not preserved: $(cat "$TMP/html-comment-command.json")"

cat >"$TMP/commented-label-before.md" <<'MD'
- Status: READY
## Checks
- com<!-- label -->mand: grep '<!--alpha-->' source.html
MD
cat >"$TMP/commented-label-after.md" <<'MD'
- Status: READY
## Checks
- com<!-- label -->mand: grep '<!--beta-->' source.html
MD
if "$CLI" --previous "$TMP/commented-label-before.md" --current "$TMP/commented-label-after.md" >"$TMP/commented-label.json"; then
  fail "changing raw command bytes after a commented label should fail"
fi
jq -e '.removed | length == 1' "$TMP/commented-label.json" >/dev/null ||
  fail "commented-label command identity was not preserved: $(cat "$TMP/commented-label.json")"

cat >"$TMP/comment-pipe-table-before.md" <<'MD'
- Status: READY
## Checks
| ID | Check | Expected |
| --- | --- | --- |
| t<!--x|y--> | npm test | all pass |
MD
cat >"$TMP/comment-pipe-table-after.md" <<'MD'
- Status: READY
## Checks
| ID | Check | Expected |
| --- | --- | --- |
| t<!--x|y--> | npm --version | version printed |
MD
if "$CLI" --previous "$TMP/comment-pipe-table-before.md" --current "$TMP/comment-pipe-table-after.md" >"$TMP/comment-pipe-table.json"; then
  fail "changing a table command after a comment-contained pipe should fail"
fi
jq -e '.removed | length == 2' "$TMP/comment-pipe-table.json" >/dev/null ||
  fail "raw table row identities were not preserved: $(cat "$TMP/comment-pipe-table.json")"

cat >"$TMP/validation-before.md" <<'MD'
- Status: READY
## Acceptance Criteria
- feature works
## Validation Plan
- Automated checks: npm test
- Evidence required for done: green test output
MD
cat >"$TMP/validation-removed.md" <<'MD'
- Status: READY
## Acceptance Criteria
- feature works
## Validation Plan
MD
if "$CLI" --previous "$TMP/validation-before.md" --current "$TMP/validation-removed.md" >"$TMP/validation.json"; then
  fail "removing the Validation Plan should fail"
fi
jq -e '.removed | length == 2' "$TMP/validation.json" >/dev/null ||
  fail "validation-plan removals were not reported: $(cat "$TMP/validation.json")"

cat >"$TMP/fenced-before.md" <<'MD'
- Status: READY
## Checks
```bash
npm test
```
MD
cat >"$TMP/fenced-after.md" <<'MD'
- Status: READY
## Checks
```bash
true
```
MD
if "$CLI" --previous "$TMP/fenced-before.md" --current "$TMP/fenced-after.md" >"$TMP/fenced.json"; then
  fail "weakening a fenced check should fail"
fi
jq -e '.removed | length == 1' "$TMP/fenced.json" >/dev/null ||
  fail "fenced check removal was not reported: $(cat "$TMP/fenced.json")"

cat >"$TMP/table-before.md" <<'MD'
- Status: READY
## Checks
| Command | Expected |
| --- | --- |
| npm test | pass |
MD
cat >"$TMP/table-after.md" <<'MD'
- Status: READY
## Checks
| Command | Expected |
| --- | --- |
| true | pass |
MD
if "$CLI" --previous "$TMP/table-before.md" --current "$TMP/table-after.md" >"$TMP/table.json"; then
  fail "weakening a tabular check should fail"
fi
jq -e '.removed | length == 2' "$TMP/table.json" >/dev/null ||
  fail "tabular check removal was not reported: $(cat "$TMP/table.json")"

cat >"$TMP/table-pending.md" <<'MD'
- Status: READY
## Checks
| Check | Expected |
| --- | --- |
| npm test | pending |
MD
cat >"$TMP/table-concrete.md" <<'MD'
- Status: READY
## Checks
| Check | Expected |
| --- | --- |
| npm test | exit 0 |
MD
"$CLI" --previous "$TMP/table-pending.md" --current "$TMP/table-concrete.md" >"$TMP/table-strengthen.json" ||
  fail "filling a placeholder table expectation should strengthen the frozen checks"
if "$CLI" --previous "$TMP/table-concrete.md" --current "$TMP/table-pending.md" >"$TMP/table-weaken.json"; then
  fail "replacing a concrete table expectation with a placeholder should fail"
fi
jq -e '.removed | length == 1' "$TMP/table-weaken.json" >/dev/null ||
  fail "concrete table expectation removal was not reported: $(cat "$TMP/table-weaken.json")"

cat >"$TMP/table-dash-before.md" <<'MD'
- Status: READY
## Checks
| Check | Expected |
| --- | --- |
| npm test | - PASS |
MD
cat >"$TMP/table-dash-after.md" <<'MD'
- Status: READY
## Checks
| Check | Expected |
| --- | --- |
| npm test | PASS |
MD
if "$CLI" --previous "$TMP/table-dash-before.md" --current "$TMP/table-dash-after.md" >"$TMP/table-dash.json"; then
  fail "changing literal table expectation text should fail"
fi
jq -e '.removed | length == 1' "$TMP/table-dash.json" >/dev/null ||
  fail "literal table expectation change was not reported: $(cat "$TMP/table-dash.json")"

cat >"$TMP/id-table-before.md" <<'MD'
- Status: READY
## Checks
| ID | Command | Expected |
| --- | --- | --- |
| C1 | npm run test:unit | pass |
MD
cat >"$TMP/id-table-after.md" <<'MD'
- Status: READY
## Checks
| ID | Command | Expected |
| --- | --- | --- |
| C1 | true | pass |
MD
if "$CLI" --previous "$TMP/id-table-before.md" --current "$TMP/id-table-after.md" >"$TMP/id-table.json"; then
  fail "weakening a tabular check after an ID column should fail"
fi
jq -e '.removed | length == 2' "$TMP/id-table.json" >/dev/null ||
  fail "ID-prefixed tabular check removal was not reported: $(cat "$TMP/id-table.json")"

cat >"$TMP/wrapped-before.md" <<'MD'
- Status: READY
## Checks
- command: npm run test:unit | tee unit.log
npm run test:unit | tee plain.log
- npm run test:unit | tee listed.log
rtk proxy npm run test:unit
env CI=1 npm run test:unit
- command: npm test
MD
cat >"$TMP/wrapped-after.md" <<'MD'
- Status: READY
## Checks
- command: npm test
MD
if "$CLI" --previous "$TMP/wrapped-before.md" --current "$TMP/wrapped-after.md" >"$TMP/wrapped.json"; then
  fail "removing pipeline and wrapped checks should fail"
fi
jq -e '.removed | length == 5' "$TMP/wrapped.json" >/dev/null ||
  fail "pipeline and wrapped check removals were not reported: $(cat "$TMP/wrapped.json")"

cat >"$TMP/plain-before.md" <<'MD'
- Status: READY
## Checks
npm test
MD
cat >"$TMP/plain-after.md" <<'MD'
- Status: READY
## Checks
true
MD
if "$CLI" --previous "$TMP/plain-before.md" --current "$TMP/plain-after.md" >"$TMP/plain.json"; then
  fail "weakening a plain check should fail"
fi
jq -e '.removed | length == 1' "$TMP/plain.json" >/dev/null ||
  fail "plain check removal was not reported: $(cat "$TMP/plain.json")"

cat >"$TMP/ordered-before.md" <<'MD'
- Status: READY
## Checks
```bash
set -e
false
set +e
```
MD
cat >"$TMP/ordered-after.md" <<'MD'
- Status: READY
## Checks
```bash
set +e
false
set -e
```
MD
if "$CLI" --previous "$TMP/ordered-before.md" --current "$TMP/ordered-after.md" >"$TMP/ordered.json"; then
  fail "reordering a fenced check should fail"
fi
jq -e '.removed | length == 1' "$TMP/ordered.json" >/dev/null ||
  fail "ordered fenced check removal was not reported: $(cat "$TMP/ordered.json")"

cat >"$TMP/indented-before.md" <<'MD'
- Status: READY
## Checks
    set -e
    false
    set +e
MD
cat >"$TMP/indented-after.md" <<'MD'
- Status: READY
## Checks
    set +e
    false
    set -e
MD
if "$CLI" --previous "$TMP/indented-before.md" --current "$TMP/indented-after.md" >"$TMP/indented.json"; then
  fail "reordering an indented check should fail"
fi
jq -e '.removed | length == 1' "$TMP/indented.json" >/dev/null ||
  fail "ordered indented check removal was not reported: $(cat "$TMP/indented.json")"

cat >"$TMP/expected-exact-before.md" <<'MD'
- Status: READY
## Checks
- command: printf foo
    - expected: stdout exactly FOO  BAR
MD
cat >"$TMP/expected-exact-after.md" <<'MD'
- Status: READY
## Checks
- command: printf foo
    - expected: stdout exactly foo BAR
MD
if "$CLI" --previous "$TMP/expected-exact-before.md" --current "$TMP/expected-exact-after.md" >"$TMP/expected-exact.json"; then
  fail "weakening an exact expected result should fail"
fi
jq -e '.removed | length == 1' "$TMP/expected-exact.json" >/dev/null ||
  fail "exact expected-result removal was not reported: $(cat "$TMP/expected-exact.json")"

cat >"$TMP/indented-blank-before.md" <<'MD'
- Status: READY
## Checks
    set -e

    false

    set +e
MD
cat >"$TMP/indented-blank-after.md" <<'MD'
- Status: READY
## Checks
    set +e

    false

    set -e
MD
if "$CLI" --previous "$TMP/indented-blank-before.md" --current "$TMP/indented-blank-after.md" >"$TMP/indented-blank.json"; then
  fail "reordering an indented check across blank lines should fail"
fi
jq -e '.removed | length == 1' "$TMP/indented-blank.json" >/dev/null ||
  fail "blank-preserving indented removal was not reported: $(cat "$TMP/indented-blank.json")"

cat >"$TMP/expected-parent-before.md" <<'MD'
- Status: READY
## Checks
npm test
- expected: exit 0
npm run lint
MD
cat >"$TMP/expected-parent-after.md" <<'MD'
- Status: READY
## Checks
npm test
npm run lint
- expected: exit 0
MD
if "$CLI" --previous "$TMP/expected-parent-before.md" --current "$TMP/expected-parent-after.md" >"$TMP/expected-parent.json"; then
  fail "moving an expected result between checks should fail"
fi
jq -e '.removed | length == 1' "$TMP/expected-parent.json" >/dev/null ||
  fail "parent-linked expected removal was not reported: $(cat "$TMP/expected-parent.json")"

printf 'plan-check-freeze smoke test: ok\n'
