# Implemented: measured Jev batching and guarded review tooling

## Metadata

- Archived: 2026-09-22
- Source plan: `PLAN.md`
- Source plan SHA-256: `ca11feb0a70727d429ff5d89114faf3f9d72a2f57b133a065a96e36686413510`
- Status: IMPLEMENTED
- Implementation commit: `108010ce6d7e5d8e42e06262329e89d77a7f0e7b`
- Branch: `perf/jev-review`, integrated locally into `main`
- Workflow initiative: jev-review-live
- Implementation author family: `openai`
- Review tier: `high-risk`; one cross-family adversary per review cell

## Outcome

The implementation, real claim/review pilots, final independent review and local
installed activation are complete. Review efficiency did not meet the frozen
targets: tooling is installed, but automatic Jev review triage is not promoted.

- Versioned Jev claim batching reuses identical evidence, confines file access,
  preserves uncertainty/materiality and returns native usage receipts.
- Review tooling builds immutable evidence packs, grades bounded findings and
  obligations, groups findings without dropping original references, and retains
  required Logic, Spec, lead and adversary roles.
- Native capture tracks prompt origins, provider coverage, child dispatch binding,
  failed-run costs, retries and replay identity; incomplete evidence prevents
  efficiency conclusions and promotion.
- Transport uses a total deadline, bounded retries and explicit live egress.
  Health distinguishes configured policy from valid promotion and historical drift.

## Measured outcomes

`docs/jev-claim-pilot-20260922.json`: 50 small synthetic claims, three repetitions,
225 native requests. Singleton: 99,339 Jev tokens / 41,858 ms summed HTTP latency;
batch: 65,475 tokens / 22,181 ms. Observed reductions: 34.09% tokens and 47.01%
summed HTTP latency. Held-out accepted precision 100% in both arms; coverage 27/30
versus 25/30 (two additional abstentions). These are not end-to-end LLM savings.

`docs/jev-review-pilot-20260922.json`: 12 synthetic patches, three repetitions,
108 measured cells. A retains required passes; B adds deterministic evidence;
C adds Jev to B. All roles use direct `zai/glm-5.3`, high except adversary max.
The frozen manifest has author_family=openai, tier=high-risk and exactly one each
parent/Logic/Spec/adversary-code per cell; the author-relative cross-family rule
is satisfied. 440 main/canary Pi captures plus 15 preparation captures =455 total;
preparation costs remain separate. Main/canary native responses: 717; Jev calls: 29.

| Arm | LLM tokens | Jev tokens | Combined tokens | Median ms | p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 757846 | 0 | 757846 | 79427.5 | 131244 |
| B | 827493 | 0 | 827493 | 98543 | 162115 |
| C | 863557 | 74370 | 937927 | 91954 | 133395 |

C/A: LLM+13.95%, combined+23.76%, median+15.77%; C/B combined+13.35%.
Frozen efficiency gates rejected; quality gate passed: 54/54 critical detections,
108/108 correct final verdicts, zero false GO/BLOCK. Exact retained-ID scoring:
A 35/36, B 35/36, C 36/36 (one extra style-note ID in A and B). Small populations and
correlated repetitions limit generalization. Three observation-parser pauses
remain in primary timings; no paid rerun or sealed-label/threshold retuning.
Raw private receipts, original collectors and manifests remain in the owner
worktree under `.workflow/jev-review-live/`; public summaries contain their hashes.

## Independent review

Final cumulative patch SHA-256:
`ecdcd66eb07f2afadb4790c1c7049d3198ab72508806461689d8a7bb162bc625`.
Logic GO; Spec high/medium independently rejected by direct Z.ai GLM-5.3 max.
Final adversary: **GO WITH NOTES**, 28 native requests, 842.256 seconds, exit 0,
no timeout; every observed wire request has reasoning_effort=max. All N1-N9
corrections confirmed and prior high/medium fixes checked for regression.
Private report: `.workflow/jev-review-live/adversary-glm-v11/report.md`;
SHA-256:`29e0acd40021a107bdc353f04814383d5fa8e8e6cbb34a152b290fe9637003af`.
This final implementation review consumed 3,827,334 known native tokens including
cache reads; it is separate review overhead, not included in pilot efficiency.

The rejected Spec high compared reviewers to one another instead of to the
OpenAI implementation author. Canonical high-risk requires cross-family review;
standard may use same-family double-sampling. Replaying the shipped comparator
on the original 108 cells exactly reproduces the published result with no issues.
The rejected medium relied on stale prose: legacy policy was already disabled.

Nonblocking notes: incomplete protected failures stop and persist non-comparable
rows rather than throwing away evidence; promotion remains impossible. Future
adapters may provide stronger structured prompt-origin attribution. A suggested
duplicate-ID excerpt issue was refuted: membership filtering does not duplicate
pack excerpts. No accepted concrete failure remains. simplify: clean.

## Validation evidence

- `scripts/verify-agentic-infra core`: 22/22 (`core-v11.log`).
- Focused Jev review tests: 21/21 (`nested-state-green.log`); scalar materiality
  and malformed nested states reproduced before fixes; invalid shapes make no
  provider calls.
- `bun test pi/extensions/__tests__/`: 321/321; typecheck passed
  (`validation-extra.log`); no later TypeScript changes.
- Offline native request equivalence: all 225 claim receipts (75 shapes) and all 29
  review requests match final code state/question fingerprints. Zero network
  calls; historical evaluator identities were not rewritten.
- Installed source verification: 57/57 reviewed files match implementation commit
  and installed checkout; the unrelated untracked Pi mobile bridge is unchanged.
- Fresh `~/.pi/scripts/jev-judge evaluate-claims --live` with a conclusion:
  supported/contradicted, scalar materiality, one measured `jev-1.13.0` HTTP request,
  991 tokens, 856 ms, exit 0 (`installed-live-canary/verification.json`). This is a real
  installed CLI invocation, not proof of refresh inside existing Pi sessions.
- `scripts/runtime-skill-canary --json`: offline source lock and managed link pass;
  generic Codex/Pi/Claude/Grok skill invocation skipped (`installed-canary-after.json`).
- Git diff check, READY check-freeze and durable answer-quality checks passed.

## Activation and remaining limits

Local installed links now resolve to the integrated implementation. No push,
remote deployment or external publication was performed. Automatic review
triage remains opt-in because its measured efficiency regressed. Diagnosis stays
level 2; the capsule three-arm protocol is prepared offline but its new live
campaign was not run. Source drift invalidates historical capsule promotion and
correctly selects deterministic fallback; historical hashes were not refreshed
cosmetically. Legacy selector stays disabled.

No generalized production gain is established; dollar costs are unavailable.
Historical `verify-reports --all` still exposes the pre-existing skill-suggestion
identity mismatch. The next optimization target is lead context: Logic token
savings were outweighed by lead growth (A 300645 to C 423731 tokens).
Root PLAN.md is removed through `plan-cleanup --archive` after preserving its exact
source hash; the owner and installed checkout share this one archive.
