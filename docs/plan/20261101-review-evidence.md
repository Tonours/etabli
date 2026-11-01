# Implemented: Evidence-grounded review and SHA-bound delta approval

## Metadata
- Archived: 2026-11-01
- Source plan: `PLAN.md` — evidence-grounded review across local, council and push workflows
- Source plan SHA-256: `5122d25160c2de8b4ce7ff49b30c58d62e5ad05b2985f0a7416d521119e84fa4`
- Status: IMPLEMENTED
- Commit / branch: `feat/review-evidence`, based on `50c9e4bf`
- Workflow initiative: review-evidence

## Outcome
- Local Logic, lead, rubric, Claude reviewer, council and autoreview distinguish severity from verification. A concrete unresolved material Logic candidate is an open question and blocks both passing verdicts; Threat retains its existing proven/refuted/unproven rules.
- Delta candidates declare severity and confirmed/unverified classification. jq validates every item independently of CLI schema enforcement. Unverified candidates stay in the local report, cannot enter the GitHub payload and force confidence false. Both approval branches require delta confidence; confirmed severity remains visible locally.
- Model text is JSON-escaped in logs. The invoker no longer infers a clean delta from a human-readable no-op line; the producer emits its own native markers on every success/no-op path.
- The invoker passes its expected SHA. A different live head stops before model work/publication. Native `DELTA_HEAD` binds the existing cache to the reviewed commit; legacy or mismatched cache entries refresh, matching entries reuse the prior result.
- Existing review instructions cover concise project invariants, inspection by behavior and cross-group interactions. A cold comparison section reuses private cases and temporary drivers; no new evaluator subsystem, model default or permanent pass was added.
- Structural suggestions remain available in the strict-quality skill, but only proven correctness/operability failures block. Its one managed fingerprint was recomputed.

## Decisions
- Remove the mandatory per-lens candidate quota while preserving all lenses, deciding-code coverage and material-uncertainty gates. A quota combined with fail-closed uncertainty encourages invented blockers. The diagnostic below compares the whole Logic template; it does not isolate that sentence.
- Extend the bounded plan once after Threat discovered the existing head-selection race. The P4 cross-family plan review approved the expected-SHA/native-marker/cache design before implementation.
- Keep the existing incomplete rc4 for a moved head: no approval, owner notification and a stopped run for that SHA. A new push permits a new run. This explicitly accepted availability tradeoff includes the rare A→B→A force-push-back case.
- Keep all existing models and pass counts. The diagnostic does not establish a recall, speed or token benefit.

## Validation Evidence
- `scripts/verify-agentic-infra core`: **13/13**, including **62 Pi tests**.
- `scripts/verify-agentic-infra shell-docs`: **38/38**, including **368 flow assertions**, gate/signal/hunter/scaffold/agent tests.
- Red/green evidence: initial classification/gate changes produced 24 flow and 3 gate failures before correction. A later log-injection probe produced 4 wrong-approval failures; the head/cache-binding probe produced 7 failures before its correction. All corresponding final regression checks pass through real decision scripts with model/network fakes.
- Targeted mutation probes against `50c9e4bf`: **0 survived of 5 scored** (confidence gates 2/2 killed; expected-SHA guard 2/7 generated, both sampled killed; cache predicate 1/1 killed). No invalid, denied or timed-out scored mutants. Tests create unique fixture directories in `~/.cache`, explicitly permitted to the sandbox. A direct fixture invocation initially omitted its fake gh PATH; corrected before the final probes.
- `git diff --check`: pass. `simplify: clean`; `quality: pass` against existing `claude_pass`, `clean_blocker` and `run_council` patterns.
- One earlier concurrent shell group hit the unrelated RTK-hook timing ceiling; the final complete group passed unchanged. No timing threshold was weakened.

## Bounded Diagnostic
- Historical archive recovered, but reconstructed H3/T5/H7 trees did not match the historical content hashes: **replay: unavailable (tree-hash mismatch)**. Old hashes were not overwritten. The runs below use newly frozen, identical trees/patches between arms, with unchanged post-run content hashes.
- Logic only; known cases, **not held-out**; one run per arm/case, requested/effective `claude-sonnet-5-5`, effort high, read-only. Oracles and earlier reviews withheld from hunters; parent audited the reported mechanisms. One initial Read-denied attempt was void and rerun once with scoped case-directory access, excluded from scores.

| Arm | Complete | Target defects found | Control findings | Findings | Indeterminate | Median duration | Median total tokens including cache |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Base `50c9e4bf` | 3/3 | 1/2 | 0 | 4 | 2 | 52.587 s | 161395 |
| Candidate Logic template | 3/3 | 1/2 | 0 | 2 | 0 | 60.485 s | 217757 |

- Per case: H3 hit in both arms; T5 miss in both arms (other valid issues are not hits for its known mechanism); H7 control clean in both. No open questions or adjudicated false findings in either arm. Indeterminate classifications are source-inspection judgments, not calibrated population precision.
- Native input/output and cache token categories remain separate in private `diagnostic-results.json`; the table totals are not billed-token or monetary savings. No recall, latency or human-effort improvement is established.
- Private frozen inputs/results: `frozen/inputs.json`, `frozen/candidate.json`, `diagnostic-results.json`, and six baseline/candidate reports. Raw cases and oracles remain outside the tracked repository.

## Review
- Plan adversary: P1/P2 CHALLENGED, P3 READY; P4 narrow refresh READY. Requested/effective `claude-opus-5-5`, proven by native modelUsage, separate read-only contexts.
- T1 lead/adversary BLOCK: newline injection confirmed by Threat, independent adversary and parent attack runs; fixed and retested.
- T2 cumulative Logic GO; Threat GO WITH NOTES exposed the pre-existing head race; P4 dual code-diff adversary GO WITH NOTES approved its bounded plan.
- D1 final: Logic GO WITH NOTES, Spec complete with no material unmet criterion after source-backed filtering, Threat GO WITH NOTES (six tables complete), final cross-family adversary GO WITH NOTES with no remaining concrete failure. All native reports completed without denials. Parent lead GO WITH NOTES.
- Final cumulative source patch SHA-256: `334f5f13d35d7852cabb0ceeb53dc0e967983258c17a70bf550844dbd0faecc6`.
- Final D1 patch SHA-256: `9038fbf60e8f8dc6a44dd5e178803f061f04265cf9e33b92590c542021114436`. The only fixture adjustment after its first dispatch explicitly prefixed the fake gh PATH; final Spec/adversary covered it. Production code stayed unchanged.

## Follow-up State
- Root plan is removed only after the archive hash gate succeeds. The isolated worktree is retained for user inspection and local branch delivery; the original checkout and its unrelated untracked file stay untouched.
- No push, hosted CI, deployment, Slack message, PR write or project-copy update occurred. Installed surfaces continue using their existing copies until separately deployed.
- On later deployment, old unbound delta caches refresh once, which can repeat a confirmed COMMENT and incurs one model run; uncertain cached verdicts remain blocked. A moved head can require a new push as described above.
- Real-world recall, escaped defects, human effort, model/pass marginal yield and held-out performance remain unmeasured. The existing comparison contract specifies the next measurement; this change makes no efficacy promise beyond its observed guards and regression cases.
