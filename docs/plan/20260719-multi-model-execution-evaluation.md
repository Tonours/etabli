# Implemented: Bounded Multi-Model Portfolio With Opt-In Panels

## Metadata

- Archived: 2026-07-19
- Source plan: Bounded Multi-Model Execution Evaluation
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main`

## Outcome

- Deployed bounded read-only Pi roles for GPT-5.6 Luna, Terra, and Sol,
  GLM-5.2, plus a clearly labelled Kimi K2.6 fallback.
- Preserved the user's Pi defaults and unrelated enabled models while replacing
  the invalid generic GPT-5.6 allowlist entry with exact model IDs.
- Kept single-agent execution as the default. The panel remains available only
  for explicit multi-model intent because the frozen blind benchmark exceeded
  its 4x latency cap in four of six panel repetitions.
- Kept Kimi K3 blocked because it is absent from the active registry and has no
  verified multi-turn reasoning-history compatibility.

## Context

- `workflow/spec.md`: shared workflow and one-writer safety contract.
- `workflow/skills/multi-model-orchestration.md`: portfolio, selection,
  fallback, provenance, and evidence rules.
- `workflow/runtime-capabilities.json`: direct Pi Agent and TaskExecute tracking
  remain separate claims.
- `tests/fixtures/multi-model-quality/`: agent-visible fixture payload and
  harness-only score key are separated; only the payload is copied into the
  random benchmark working directory.

## Decisions

### Centralized fan-out/fan-in, never free-form debate

- Context: independent model passes can broaden review but increase latency,
  cost, and correlated-error risk.
- Choice: maximum three blind sidecars, depth one, parent-only integration and
  mutation, deterministic checks first, and one Sol adjudication round.
- Rejected options: recursive swarms, mandatory consensus, concurrent writers,
  or treating Sol/Terra/Luna as independent provider-family votes.
- Rationale: this keeps accountability and worktree safety with explicit
  provenance and fallback labels.
- Consequences: Pi uses true OpenAI + ZAI cross-family panels; Codex remains on
  its proven provider-native collaboration surface.

### Automatic triggering rolled back to explicit opt-in

- Context: the blind A/B gate compared Terra-high alone, Terra-high + GLM-xhigh,
  and a Sol-xhigh ceiling on three fixtures with three planted defects each.
- Choice: retain the role portfolio but require explicit `multi-model`, `panel`,
  `cross-model`, or equivalent intent.
- Rejected options: weakening the 4x cap, keeping a silent automatic panel, or
  claiming the first contaminated benchmark as proof.
- Rationale: all variants reached recall 1.0 with zero false positives and zero
  recall variance, while panel latency reached 100.4s and 127.6s against a
  16.0s tenant-cache baseline, and 75.0s and 73.9s against a 14.3s webhook
  baseline. Only account-transfer stayed under the cap at 38.5s and 46.1s
  against 12.1s.
- Consequences: the post-deploy probe reports sidecar counts 0 for an ordinary
  eligible review, 3 for an explicit panel, and 0 for a trivial prompt.

### Runtime claims require observed provenance

- Context: tool availability alone does not prove a role, provider, or model
  actually ran.
- Choice: route injection starts at `pending`; only observed tool results can
  produce confirmed, degraded, or blocked evidence.
- Rejected options: model self-report or `Agent` tool presence as confirmation.
- Rationale: live probes returned matching provider/model evidence for Luna,
  Terra, Sol, GLM-5.2, and Kimi K2.6.
- Consequences: `multi_execution_completed` accepts only the tracked model IDs,
  matching families, at most three participants, Sol-only adjudication, bounded
  verdicts, and complete measured usage fields.

## Accepted Drift

- Original plan/spec: make adaptive multi-model execution automatic on eligible
  non-trivial phases.
- Implemented reality: single-agent remains the default; panels are opt-in.
- Why accepted: the rollback rule was frozen before the blind runs and four of
  six panel repetitions violated its latency cap without a quality gain.

## Validation Evidence

- `scripts/verify-agentic-infra all`:
  - result: PASS; 211 Pi tests, 0 failures, 558 expectations; router dataset
    32/32 with alignment 1.0; all shell/docs/deploy/Nvim groups passed.
- `RUN_REAL_MULTI_MODEL=1 PI_BIN=/Users/tonours/.asdf/shims/pi bash tests/multi-model-real-smoke.sh --probe-only`:
  - result: PASS; five exact model provenances; sidecar counts default/explicit/
    trivial = 0/3/0; worktree unchanged.
- `RUN_REAL_MULTI_MODEL=1 PI_BIN=/Users/tonours/.asdf/shims/pi bash tests/multi-model-real-smoke.sh --quality`:
  - result: expected `ROLLBACK_TO_OPT_IN`; recall 1.0 and zero false positives
    for baseline, panel, and Sol; four latency-cap failures; token caps passed.
- `RUN_REAL_MULTI_MODEL=1 PI_BIN=/Users/tonours/.asdf/shims/pi bash tests/multi-model-real-smoke.sh --task-rpc`:
  - result: PASS; spawn, completion, and TaskGet result confirmed; TaskStop
    remains unconfirmed.
- Fresh-context Sol review:
  - result: `VERDICT: READY`, no actionable finding.
- GLM-5.2 xhigh code-diff adversary through `etabli-glm-challenger`:
  - result: `VERDICT: READY`; exact payload and `glm-5.2` provenance verified;
    duration 75.1s, 20.8k total tokens.
- `git diff --check` and instruction budget:
  - result: PASS; 1,887 estimated entrypoint tokens, within the 1,891-token
    stretch target.

## Follow-up State

- Remaining risks: the live Pi package install reported 9 npm audit findings
  (3 low, 3 moderate, 2 high, 1 critical); they were not auto-fixed because
  dependency remediation was outside this change. GLM xhigh direct parent
  reviews were substantially slower than the custom sidecar path.
- Parking lot: re-evaluate automatic panels only with harder blind fixtures that
  show a quality gain within the frozen cost caps; prove TaskStop separately;
  evaluate Kimi K3 only after registry and reasoning-history support exist.
- Superseded docs/specs: automatic-panel wording was replaced by the opt-in
  contract in `workflow/spec.md` and the orchestration documents.
- Next links: `workflow/skills/multi-model-orchestration.md`,
  `workflow/runtime-capabilities.json`, and
  `tests/multi-model-real-smoke.mjs`.
