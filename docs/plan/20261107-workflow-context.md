# Implemented: slimmer skills and explicit workflow handoffs

## Metadata
- Archived: 2026-11-07
- Source plan: `PLAN.md` - Etabli context optimization
- Source plan SHA-256: `8e73c0b669b4e4376da43e4ef0164cc066ccfd035715519b49bf69bc406120c6`
- Status: IMPLEMENTED
- Commit / branch: `refactor/workflow-context`, base `1b664f3d9269098073cae48275b8dba8596f3ff9`
- Workflow initiative: workflow-context

## Outcome
- Remove the repeated mutation/simplification/quality paragraphs from `implement` and `plan-implement`; the shared implementation contract still owns the mandatory gates. Delivery and exact-patch review reuse remain intact.
- Keep a current handoff with goal/phase, branch/SHA, proved checks, open findings, evidence paths, next action and do-not-redo. The canonical spec points to that contract; both deployable plan templates expose the same fields.
- Clarify explicit RTK for parent/writer display commands and raw data. Read-only agents retain policy-compatible forms. No guard, parser, launcher, hunter, model or production settings changed.
- Read the existing harness-filed council log with the exact `phase_b_output` invocation; when output stays inline, read its phase B directly. Preserve the full watcher stream, denial/run markers and incomplete outcomes; zero process exit is not approval.

## Context
- `workflow/skills/implementation-loop.md` already owns mutation, simplify and quality; duplicating the same paragraph in wrappers added payload without another gate.
- `claude/hooks/read-only-agent-guard.mjs` strips only a leading RTK prefix for approved commands. Plain read-only compounds can pass, while an interior RTK prefix remains denied. New corpus cases exercise the actual hook for RTK tokens, with a plain compound positive control.
- `claude/scopes/work/scripts/pr-council-review/lib.sh` already has exact-patch reuse and a phase-B extractor that refuses zero or multiple headers. Reuse these mechanisms instead of adding another report wrapper/cache.

## Measurements
Static Unicode character inventories of the named source files, not native context usage or billed-token savings:

| Files / bundle | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Two implementation skill wrappers | 4641 | 3737 | -904 |
| plan-implement + implementation-loop + RTK | 17165 | 17105 | -60 |
| implement + implementation-loop + RTK | 15078 | 15018 | -60 |
| council skill + RTK | 7143 | 7733 | +590 |
| All eight changed Markdown sources | 39719 | 39854 | +135 |

The council documentation grows to state how to read the report safely. These overlapping bundles are file sums, not additive categories or a decomposition of an actual API request. Tests, generated hashes and this archive are outside the Markdown source total. Private `baseline.json`, `final-inventory.json` and `route-inventory.json` cover every changed implementation path; source counts can be recomputed from the base and reviewed patch.

## Decisions
### Keep RTK boundaries and existing council isolation
- Check common Git command support on RTK 0.39.0 and 1.0.1; do not pool their analytics or infer realized savings from raw command eligibility.
- No guard expansion, enabling hooks in isolated council passes, RTK upgrade or second review cache.
- Omit gain/discover CLI tips from always-loaded guidance to bound payload. The commands remain available unchanged. Codex's unmanaged local RTK instructions are outside this change.

### No unmeasured summary subsystem
- A new council summary launcher was removed during plan review: its incremental end-to-end benefit was not established. Existing file-backed output and the canonical phase-B helper suffice for this change.
- The watcher keeps its canonical stream. No signal forwarding or argument parsing behavior changes.

### Caveman adoption remains inconclusive
- Response-only source pinned to [caveman skill at 4bf8898](https://github.com/juliusbrussee/caveman/blob/4bf8898b31c93326a5e5d90999241a1c15b52ed2/skills/caveman/SKILL.md).
- Freeze six synthetic cases, two repetitions and two arms before calls: maximum 24 subjects, 30 minutes, USD 0.15 per-call native budget, USD 3.60 aggregate ceiling. Baseline follows the existing concise-answer contract; the other arm adds only the pinned voice prompt. Model alias and effort remain `sonnet` / `medium`.
- Require exact facts, paths, numbers, statuses, negations and French accents; no invented execution. Record native input/cache-write/cache-read/output and estimated cost separately. Any fidelity loss, incomplete evidence or absent weekly need rejects default adoption.
- Actual result: 24 attempted subjects, 0 usable. Native CLI authentication expired and could not refresh; every receipt reports `is_error=true` with empty `modelUsage`. Reported zero cost is failed-auth telemetry, not an economic result. No fallback, installation, proxy, router or memory layer.
- Private trial fixtures, hashes, specification and receipts remain outside Git (`trial-spec.json`, `cases.json`, `trial-rows.json`, `trial-result.json`). Retry is separate work after authentication is restored; this diagnostic does not justify adoption.

## Accepted Drift
- The owner changed the earlier analysis-only scope to implementation. Fleet remains excluded.
- Drop the unproved summary wrapper instead of building a subsystem. The retained report-reading change is documentation over existing code.
- Align `workflow/spec.md` and regenerate the three changed skill hashes as necessary consequences of the approved handoff/skill changes.
- Caveman evaluation is unavailable, not a measured rejection or a pending global installation. Historical native Grep/Glob failures were not reproduced in the same runtime; no tool definitions changed.

## Validation Evidence
- `scripts/verify-agentic-infra full`: 46/46 checks pass on the final frozen implementation; private receipt `full-checks-D1.log`. Initial stale assertion/hash failures were corrected before final validation.
- Plan adversary: requested/effective `claudeAgent` / `claude-opus-5-5` (Anthropic, T3); first plan SHA `f8c41f4d008945e1953f17ef4a1b332db8ee4c6e1701bea531e52dd91daf06c5` CHALLENGED, narrowed plan SHA `cd6cd7f5bd017d7d8b066400a7346de2a009d06d12ab9a1854c431f03c5a429c` READY.
- Cumulative code reviews: T1 patch `381920553b7afe55827751a1127dc781146626c95f7aac5680b413244d39defd`, T2 patch `160b8983676c87101d29f4ac1c5837748054d3a6e02f84ea30e5ad42b0aa45b9`; findings folded. D1 corrective delta `f2cbf4dcd28c8c1bbe0fa27aeb3fff9a6eac899f9486de427607fcf7eea3dbdf`, final cumulative implementation `4ddb3def8e263e19386da9408eb2412d2f1fdac47ebbccc45b50abe60f761262`: fresh Logic GO, Spec GO, cross-family adversary GO, lead GO. Requested/effective reviewers `claudeAgent` / `claude-opus-5-5` (Anthropic, T3), author family OpenAI. One malformed Logic completion marker was void and rerun once on the same pin; closing report complete, mandatory tables and deciding-code complete. Hunter templates inline; Threat not triggered (no access/trust/public API decision changed).
- Focused contract, skill, hook and scaffold smoke; entry-chain budget 400/405; skill verifier 31 hashes; native skill-load 4283 characters, hooks check green; RTK runtime 25/25 tests and 215 assertions.
- Existing PR flow smoke passes, including exact-patch reuse refusal, denial/incomplete gates and process interruption.
- Exact documented phase-B command tested with a spaced log path: one header returns the findings/denial unchanged, missing or duplicate headers return 1.
- `mutation: n/a (no mutable lines)` from the existing automated probe. A private manual unanchored-prefix mutant changes the new negative case from deny to allow while the leading-RTK positive control remains allow; this is a separate diagnostic, not a scored automated mutant.
- `simplify: clean`; `quality: pass` via code-quality and existing smoke/corpus conventions. No new tool dependency: Ruby was already used by the skill smoke.

## Follow-up State
- Review status: GO. No open findings.
- No live deployment or merge. Active sessions keep their already-loaded instructions; copied project templates require the ordinary project deployment path after merge.
- Remaining risks: static payload reduction is small; no measured API cost benefit, native context decomposition or held-out production Caveman result. No promise of output-token savings or improved review recall.
- Parking lot: retry the frozen voice diagnostic only after native authentication is restored and weekly need remains; attribute native tool failures before changing runtime definitions.
- The original checkout is preserved. The isolated branch/worktree stays available for PR review.
