# Implemented: per-route rule census with a duplicate guard

## Metadata
- Archived: 2026-09-27
- Source plan: `PLAN.md` — Suite audit 3 — recenser les règles normatives par route, et empêcher les doublons entre fichiers d'une même chaîne
- Source plan SHA-256: `75237f7ed6d8cd5b4094d18d48a0f833d150940f193b16ff740ede2a14f052c9`
- Status: IMPLEMENTED
- Commit / branch: `refactor/rule-dedupe`, stacked on `feat/escaped-defect-tier` (base `c1b32fa`); not pushed
- Workflow initiative: `rule-dedupe`, closed as documented `blocked` at F1. The D budget was spent; two medium findings from the final adversary are open (see Follow-up).

## Outcome
- `scripts/token-bench --rules [--json] [--check]` counts normative sentences per surface. A route is always-on plus its chain plus its conditional reads; spec-map is counted but not gated.
- `--check` fails on a near-duplicate normative sentence across files read together, unless the exact sentence pair is listed with a reason in `workflow/runtime/rule-census-allow.json` (7 entries). A stale entry also fails, and a malformed list exits 2.
- The frozen lexical proxy:
  - fences are stripped line by line (backticks or tildes, indented up to 3 spaces, unterminated fences strip the rest);
  - the keyword test ignores punctuation and collapsed blanks;
  - words keep Unicode letters and digits only, with length over 3;
  - a pair needs at least 6 distinct words each and a Jaccard index of at least 0.6.
- `workflow/skills/review.md` drops its two copies of rubric rules ("Never use `OK`…", "bounded read-only inspection…"). The harness fallback rubric is a link to `workflow/review-rubric.md` (`scripts/deploy-agent-workflow:483`), so every reader still gets them; `tests/workflow-docs-smoke.sh` pins both in the rubric and the step that reads it.
- Census (normative sentences / pairs, all allowed): always-on 38/0, plan-loop 58/0, plan-implement 231/1, implement 211/0, review 109/0, verify 49/0, spec-map 68 (ungated), ship 375/6.

## Context
- The audit expected deduplication to cut instructions. The census found only 8 cross-file pairs in the chains, 2 of them truly redundant (`review.md`). The others serve independent entry points:
  - the plan-implement adapter resumes a READY plan without `plan-loop.md`;
  - `/ci-fix` is a standalone entry;
  - `spec.md` and `contract-details.md` are separate entries, and `contract-details.md` carries more obligations.

## Decisions
### Guard instead of mass deduplication
- Choice: measure, allow the legitimate copies with a reason bound to the exact sentences, and fail on any new copy.
- Rejected options: deduplicating spec/contract-details and the adapters (independent readers would lose rules); substring allowances (they would cover new duplicates).

### Closed normalization
- Context: each review round found another punctuation escape (apostrophes, underscores, emphasis, `do **not**`, accents).
- Choice: drop every non-letter/digit/blank character (Unicode classes) instead of listing punctuation.

## Accepted Drift
- Original plan/spec: `completed` ledger.
- Implemented reality: `blocked` at F1. The two open findings are edge cases outside the repo's real use: the real-tree check passes and the smoke is green.
- Why accepted: the user asked to stop the review loop; the fixes are listed below instead of being applied without review.

## Validation Evidence
- command: `bash tests/token-bench-smoke.sh`
  - result: ok. Every AC4 fixture bites, and the real-tree `--rules --check` passes.
- command: `scripts/token-bench --rules --check`, `bash tests/workflow-docs-smoke.sh`, `scripts/workflow-context-budget`, `scripts/token-bench --check`
  - result: ok
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 27/27 and 81/81
- Reviews:
  - Plan: 7 cross-family passes via `scripts/pi-review-hunter` (`openai-codex/gpt-6-astra`), the last READY.
  - Code: T1, T2, D1 and D2 had findings, all folded. At F1, Logic GO and Spec GO, but pi BLOCK (capture `29e4b544`).

## Follow-up
- `runRules`: set `process.exitCode = 1` instead of `fail()` after writing `--json`, so a large piped output is not truncated.
- `rulesReport`: build `surfaces` with `Object.create(null)`, so a surface named `__proto__` is reported and checked; add a fixture.
