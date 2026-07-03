# Orchestration: orchestrator subagents loop hardening

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.

## Branching Rules

- If live Codex conflict files differ only by missing tracked hardening, back up
  then sync/merge the tracked content.
- If a live conflict contains user-only material, preserve it and document the
  manual merge requirement instead of overwriting.
- If external research contradicts current workflow behavior, prefer local
  runtime evidence for current harness mechanics and use research only to harden
  generic loop controls.
- If real agent scenarios fail with provider/rate-limit symptoms, rerun once; if
  still failing, record `blocked` with raw signal and continue non-provider
  validation.

## Packet Prompts

### P1-live-codex-sync

Inspect `scripts/deploy-codex --dry-run`, compare each conflicting live file
against the tracked source, back up non-secret live files before changes, and
make the dry-run clean if a safe merge exists.

### P2-source-research

Collect primary/local sources for agentic loops, subagent delegation,
retry/error handling, completion evidence, and harness-specific constraints.
Return claim, source, confidence label, and concrete implication for Etabli.

### P3-hardening-design

Map accepted source-backed implications to repo changes. Reject generic advice
that does not improve an existing rule, test, or operator doc.

### P4-implementation

Apply minimal accepted changes in workflow docs, tests, or harness docs while
preserving current architecture and runtime labels.

### P5-validation-review

Run targeted and broad validations, review diffs against the goal, and produce
the final GO/NO-GO matrix.

## Completion Audit

- Every previous finding has a resolved, blocked, or rejected status.
- Every external source used maps to at least one concrete accepted/rejected
  decision.
- Live sync, repo tests, workflow verification, and real scenarios have current
  evidence.
