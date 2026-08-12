# Implemented: Conversation-derived workflow skills

## Metadata
- Archived: 2026-08-12
- Source plan: Implement conversation-derived Etabli workflow recommendations
- Status: IMPLEMENTED
- Branch: `main`
- Publication state at archive time: validated locally; commit, push, and managed-local sync ordered next

## Outcome
- Added `conversation-retrospect`, a bounded read-only four-runtime parser and
  thin skill that emits only aggregates and opaque parent citations.
- Added a frozen-public skill evaluation contract and comparator with exact
  population checks, strict held-in gain, held-out/safety non-regression, and
  recomputed baseline/candidate artifact fingerprints.
- Added the shared `recurring-run` contract and skill, plus a maintenance and
  dependency-upgrade recipe for `goal-prompt-rewriter`.
- Added an offline-first runtime skill canary with separate source-lock, managed
  link, and opt-in live invocation evidence.
- Added a bounded read-only session handoff projection from `PLAN.md`, the
  active event ledger, and Git state.
- Registered and locked all four skills through the existing `agents_visible`
  surface, with focused fixtures, smoke tests, documentation, and full-profile
  integration.

## Context
- Source analysis: `docs/research/20260812-conversation-skill-projection.md`.
- Canonical skill surface: `workflow/runtime/skill-surface.tsv`.
- Canonical implementation checks: `workflow/runtime/agentic-infra-checks.tsv`.
- Grok safe-ops ownership remains outside Etabli; no harness, permission, or
  credential-policy expansion was made.

## Decisions

### Keep conversation evidence read-only and non-authoritative
- Context: local conversations may contain secrets, injected context, probes,
  duplicates, and situational preferences.
- Choice: fixed local roots, read-only SQLite/file access, recent-window and
  file/byte/message caps, aggregate classifications, and opaque citations.
- Rejected options: raw prompt output, obvault write-back, chat-driven edits,
  and automatic skill promotion.
- Rationale: conversation history can propose candidates but cannot authorize
  mutation or prove durable preference by itself.
- Consequences: missing or truncated sources remain explicit `partial` or
  `unavailable` evidence.

### Make skill comparisons falsifiable
- Context: comparable result JSON can otherwise self-report arbitrary artifact
  fingerprints or drift its task/evaluator population.
- Choice: hash the raw manifest, require exact task coverage and evaluator hash,
  and recompute both artifact fingerprints from explicit directories.
- Rejected options: average scores, candidate-authored held-out claims, or
  acceptance without strict held-in gain.
- Rationale: a promotion gate must reject unverifiable or incomparable runs.
- Consequences: callers retain an immutable baseline snapshot and disclose that
  tracked fixtures are frozen/public rather than confidentially isolated.

### Preserve one authoring and link surface
- Context: Etabli already manages shared skill links from Pi-authored sources.
- Choice: register the four skills as locked `agents_visible` Pi skills and
  extend existing link/deploy checks.
- Rejected options: new Codex/Grok harnesses, direct cross-harness duplicates,
  and a generic configuration doctor.
- Rationale: current catalog behavior already defines ownership and prevents
  parallel configuration sources.
- Consequences: runtime invocation proof remains distinct from source and link
  proof; provider-backed checks require explicit opt-in.

### Project handoff state instead of duplicating it
- Context: the active plan, event ledger, and Git state already hold resume
  evidence.
- Choice: generate a bounded projection and never mutate or archive the run.
- Rejected options: a new progress file, transcript summarization, or dashboard.
- Rationale: the ledger remains the sole durable execution record.
- Consequences: unavailable evidence is labeled and output fields are length
  bounded to preserve the one-screen contract.

## Accepted Drift
- Original recommendation: treat the runtime canary and session handoff as P2
  follow-ups.
- Implemented reality: both were included in the coherent implementation after
  the user explicitly asked to apply all recommendations.
- Why accepted: both remained narrow, reversible, testable, and shared the same
  catalog and validation integration work.

- Original projection: skill evaluation results carried artifact fingerprints.
- Implemented reality: the comparator also requires artifact directories and
  recomputes both hashes.
- Why accepted: fresh adversarial review showed that result JSON alone could
  create false proof.

## Review Evidence
- Fresh-context review: `CHANGES_REQUIRED`; all three medium findings were
  addressed with regression coverage for lock comparison,
  `<skill_information>` filtering, and unrelated validation success.
- Code-diff adversary: `GO`; accepted fixes recompute artifact fingerprints,
  bound handoff fields, and keep synthetic workflow fixtures tracked without
  committing active `PLAN.md` or `.workflow` paths.
- Simplification: shared policy stays in two canonical contracts; four skills
  remain thin adapters and helpers remain single-purpose CLIs.

## Validation Evidence
- Four runs of system `skill-creator` `quick_validate.py`:
  - result: all four new skills valid.
- Five focused smokes (`conversation-retrospect`, `recurring-run` goal pattern,
  `skill-eval`, `runtime-skill-canary`, and `session-handoff`):
  - result: all passed, including negative privacy, drift, stale-lock, live
    fail/unknown, and unresolved-blocker cases.
- Link/deploy/docs/manifest/settings/lock checks:
  - result: passed; 78 skill hashes verified.
- `scripts/verify-agentic-infra full`:
  - result: exit 0; 192 Pi tests passed, router eval 53/53, all historical and
    new full-profile checks passed.
- `scripts/research-proof-check` and `scripts/answer-quality-check --mode research`
  on the source report:
  - result: passed.
- `git diff --check`:
  - result: passed.

## Follow-up State
- Remaining operation: commit the coherent worktree and push normally to
  `origin/main`, then run the explicitly requested managed-local synchronization
  and prove a zero-drift second dry run.
- Remaining uncertainty: real provider-backed runtime invocation was not run;
  source and managed-link proof must not be reported as live invocation.
- Parking lot: Grok safe-ops remains blocked pending explicit ownership.
- Superseded docs/specs: none.
- Next links: `docs/research/20260812-conversation-skill-projection.md`,
  `workflow/skills/recurring-run.md`, and
  `workflow/skills/skill-evaluation.md`.
