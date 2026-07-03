# Plan 008: Add a cheap pre-gate to filter-output so clean tool results skip the full redaction sweep

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- pi/extensions/filter-output.ts pi/extensions/__tests__/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.
>
> **SECURITY NOTE**: this extension is a guardrail (`pi/AGENTS.md`: "Pi
> extensions such as `filter-output` … are guardrails. Do not bypass them").
> The optimization must be provably redaction-preserving: the pre-gate may
> only skip work that cannot match. When in doubt, don't skip.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

`pi/extensions/filter-output.ts` registers a `tool_result` handler that runs on EVERY tool result in every Pi session. For each text block it executes ~26 token-pattern `.replace` passes plus ~12 structural-pattern `.replace` passes — ~38 full regex scans even when the output is a plain source-file read with no secret-shaped content. On large reads and verbose command output this is the hot path of every tool call. Most outputs contain none of the trigger substrings, so a single cheap pre-gate (one scan) can skip the other ~37. The bash command-analysis path also re-scans `command` with several `matchAll` passes per fragment; it is bounded by command length (small), so it is NOT changed here.

## Current state

`pi/extensions/filter-output.ts` (491 lines):

- Lines 14-60 — `tokenPatterns`: 26 entries, each with a distinctive prefix (e.g. `sk-ant-`, `sk-`, `ghp_`/`gho_`/`ghs_`/`ghu_`/`ghr_`, `github_pat_`, `xox`, `AKIA`, `ASIA`, `sk_live`/`sk_test`/`rk_`/`pk_`/`whsec_`, `vercel_`, `sbp_`, `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.`, `cf_`, `npm_`, `pypi-`, `SK` (Twilio, hex), `SG.`, `AIza`, `dp.`, `AGE-SECRET-KEY-`, `glc_`, `lin_api_`, `re_`).
- Lines 65-104 — `structuralPatterns`: 12 entries keyed on context words: `api_key`/`api-key`/`apikey` variants, `secret`, `private_key`, `token`, `credential`, `password`/`passwd`/`pwd`/`pass`, `bearer`, `Authorization:`, DB URI schemes (`mongodb`, `postgres`, `mysql`, `redis`, `amqp`, `nats`, `clickhouse`), `-----BEGIN … PRIVATE KEY-----`, `aws_secret_access_key`.
- Lines 175-206 — `redactTokens` / `redactStructural`: sequential `.replace` over the full text per pattern.
- Lines 433-489 — the `tool_result` handler: sensitive-file block (read), sensitive-command block (bash), then unconditional `redactTokens` + `redactStructural` on every text content item.
- Tests: `pi/extensions/__tests__/` contains the extension suite (run `cd pi && bun test ./extensions/__tests__/*.test.ts`; find the filter-output test file with `ls pi/extensions/__tests__ | grep -i filter`).

Repo conventions: TypeScript strict, no `any`, no comments (this file's existing header/section comments predate the rule — do not add new ones), functions small.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Extension tests | `cd pi && bun test ./extensions/__tests__/*.test.ts` | all pass |
| Import smoke | `cd pi && bun -e 'await import("./extensions/filter-output.ts")'` | exit 0 |
| Micro-benchmark | see step 1 | numbers recorded |

## Scope

**In scope**:
- `pi/extensions/filter-output.ts`
- `pi/extensions/__tests__/` (add fast-path tests; find and extend the existing filter-output test file)

**Out of scope**:
- Removing/weakening ANY pattern, the sensitive-file list, or the bash command analysis.
- Length caps on scanned output (rejected: a truncated scan is a redaction hole — a secret at byte 1M+ would pass through).
- Other extensions.

## Git workflow

- Branch: `advisor/008-filter-output-fast-path`
- Commit: `perf(pi): pre-gate filter-output redaction sweep`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Measure the baseline

Write a throwaway script (do not commit it) that imports the two redact helpers' logic indirectly: simplest is to inline-copy the current `tokenPatterns`/`structuralPatterns` + `redactTokens`/`redactStructural` into a bench file under `/tmp`, then run them 100× over (a) a 1MB string of TypeScript-like source with no secrets, (b) the same with 3 planted secrets (`sk-ant-` + `password=` + PEM block). Record ms/iteration for both.

**Verify**: numbers captured in your report (expected order: several ms per MB per full sweep).

### Step 2: Build the pre-gate

In `filter-output.ts`, derive two gate checks computed ONCE per text block:

1. `tokenGate`: a single combined regex of the distinctive literal prefixes listed in "Current state" (alternation of plain strings, case-sensitive where the patterns are, e.g. `/sk-ant-|sk-|ghp_|gho_|ghs_|ghu_|ghr_|github_pat_|xox|AKIA|ASIA|k_live_|k_test_|pk_live|pk_test|whsec_|vercel_|sbp_|eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.|cf_|npm_|pypi-|SK|SG\.|AIza|dp\.|AGE-SECRET-KEY-|glc_|lin_api_|re_/`). IMPORTANT: derive the list from the actual `tokenPatterns` in the live file, not from this plan — every pattern must have at least one of its mandatory literal substrings in the gate. If a pattern has no mandatory literal (inspect each), it CANNOT be gated — in that case run that pattern unconditionally (split patterns into `gated` and `ungated` arrays).
2. `structuralGate`: a case-insensitive regex of the context keywords: `/key|secret|token|credential|passw|pwd|pass|bearer|authorization|mongodb|postgres|mysql|redis|amqp|nats|clickhouse|BEGIN|aws_secret/i`. Same rule: every structural pattern must be unmatchable when its gate keyword is absent; verify per pattern, move any exception to `ungated`.

Then in the handler (lines 466-478 region): run `redactTokens` only if `tokenGate.test(text)`, `redactStructural` only if `structuralGate.test(text)` (plus always run the `ungated` arrays if non-empty).

**Verify**: `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass unchanged.

### Step 3: Prove redaction equivalence with a differential test

Add to the filter-output test file a differential property test: for a corpus of ≥30 strings — every existing test's input, one sample per token pattern (synthesize a fake matching string per pattern, e.g. `sk-ant-` + 24 alphanumerics), one sample per structural pattern, plus 5 clean strings — assert `gatedRedact(s) === ungatedRedact(s)` where `ungatedRedact` applies all patterns unconditionally (export the pattern arrays or replicate minimal helpers in the test — mirror how the existing tests access internals).

**Verify**: `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass, new differential test included.

### Step 4: Re-measure

Re-run the step-1 bench with the gate logic. Expected: clean-input case ≥5× faster; planted-secrets case unchanged within noise.

**Verify**: numbers in report; if clean-case speedup < 2×, note it and still land (correctness unaffected) but flag for review.

## Test plan

- Differential equivalence test (step 3) — the core safety artifact.
- All existing filter-output tests unchanged and green.
- One regression case per gate: a string matching a token pattern whose prefix is mid-text (not at start), and a structural secret with unusual casing (`PASSWORD=...`) — both must still redact.

## Done criteria

- [ ] Gate arrays derived pattern-by-pattern with any ungatable pattern kept unconditional (list the split in your report)
- [ ] `cd pi && bun test ./extensions/__tests__/*.test.ts` exits 0, including the new differential test
- [ ] Bench before/after numbers recorded (clean + planted cases)
- [ ] `cd pi && bun -e 'await import("./extensions/filter-output.ts")'` exits 0
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Any token/structural pattern has NO mandatory literal substring and would dominate runtime anyway (gate impossible + hot) — report with the pattern; do not weaken it.
- The differential test finds ANY input where gated ≠ ungated — that is a redaction hole; stop immediately and report the input (do not "fix" by loosening the gate ad hoc without re-running the whole differential corpus).
- The existing test suite fails at baseline.

## Maintenance notes

- INVARIANT for future edits: adding a pattern to `tokenPatterns`/`structuralPatterns` requires adding its literal to the corresponding gate (or to the ungated array). The differential test enforces this — keep it synthesizing one sample per pattern so a forgotten gate literal fails CI.
- Reviewer must check the gate derivation table in the executor's report against the live pattern list, pattern by pattern.
