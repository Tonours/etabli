# Implemented: Offline harness-trace self-improvement foundation

## Metadata
- Archived: 2026-09-20
- Source plan: `PLAN.md` — harness traces for bounded self-improvement
- Source plan SHA-256: `7752153ea063b77b1b167df50d02acc7a276f02d043a2fc962b43aeaa898a58e`
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main` at `0a91866`
- Workflow initiative: `trace-self-improvement`

## Outcome
- Added a read-only offline CLI for explicitly supplied Pi or Claude JSONL traces plus one terminal Etabli ledger.
- Added a versioned sanitized observation schema, bounded regular-file reads, closed error codes, identity/lineage/time checks, and synthetic regression fixtures.
- Added deterministic `no_op` or non-causal `recommendation` mapping for complete episodes only.
- Closed the Jev boundary to canonical state tuples and pinned its `shadow`, `private_opt_in`, deterministic-owner envelope across caller policy injection and asynchronous mutation.
- Defined four maturity levels. Only `prototype_offline` is available; levels 2–3 remain unavailable and level 4 remains blocked behind an isolated external promotion controller.

## Context
- Pi provides the richer native trajectory, including linked entries and compaction metadata; Claude transcripts provide parent-linked user, assistant, and tool rows but require strict exclusion of meta and sidechain rows.
- Raw prompts, commands, output, paths, session identifiers, content-derived hashes, and verifier text are deliberately absent from observations.
- No live trace store, provider call, credential read, automatic edit, promotion, commit, push, or deployment occurred.

## Decisions
### Keep Jev inside a typed shadow boundary
- Context: Jev can classify a bounded candidate, but a model judgment is not evidence that a change should be applied.
- Choice: serialize only closed enum/count tuples and preserve deterministic policy ownership.
- Rejected options: free-text trace excerpts, provider-owned promotion, and caller-controlled authority labels.
- Rationale: the model may help frame decisions without becoming the authority that mutates its own rules.
- Consequences: level 1 can prepare a safe Jev request; provider use and promotion remain separate authorized steps.

### Treat level 4 as a separate control plane
- Context: strong observation, diagnosis, and reviewed proposal stages do not establish an independent root of trust.
- Choice: require a frozen base, external isolated evaluator, allow/deny surfaces, held-out and safety gates, atomic rollback, and explicit human authority.
- Rejected options: same-repository manifest as root of trust or automatic promotion after recurrence alone.
- Rationale: the component proposing a self-change must not also be the sole authority validating and applying it.
- Consequences: `promote_automatic` is mechanically unavailable and explicitly blocked.

## Accepted Drift
- Original plan/spec: support known Pi and Claude trace shapes with fail-closed completeness.
- Implemented reality: Pi accepts only version 3; Claude additionally rejects meta and sidechain rows. Unknown or inconsistent shapes become `unavailable`.
- Why accepted: fresh Logic, Spec, and adversarial reviews found concrete ambiguity and authority bypasses; stricter admission preserves the intended safety contract.

## Validation Evidence
- `bash tests/harness-trace-retrospect-smoke.sh`: passed, including malformed, cap, symlink/FIFO, mutation, lineage, version, time, meta, privacy, and capability cases.
- `bun test pi/extensions/__tests__/semantic-profiles.test.ts`: 15 tests passed with 104 assertions.
- `scripts/verify-agentic-infra core`: 22/22 checks passed; Pi suite 302/302 and router evaluation 212/212.
- Jev, workflow retrospect, workflow docs, context budget, frozen plan checks, research proof, privacy inspection, and `git diff --check`: passed.
- Final Logic and Spec reviews: GO with no findings on patch `37c5a3c0b45f86fac0aee4d2e65c62ed1be75b3dd73d6d8b8b8802b2fe62aebd`.
- Fresh adversary: GO WITH NOTES with no remaining findings on the same pinned patch; exact serving-model identity was not exposed.

## Follow-up State
- Remaining risks: compatibility is proven only on synthetic fixtures; private real-format canaries are required before level 2.
- Parking lot: recurrent multi-initiative aggregation, live shadow diagnosis, reviewed proposal generation, and the external promotion controller.
- Superseded docs/specs: none.
- Next links: `workflow/trace-self-improvement.md`, `docs/research/20260920-harness-traces-self-improvement.md`, `scripts/harness-trace-retrospect`.
