# Implemented: Robust evidence and large-program control plane

## Metadata

- Archived: 2026-08-20
- Source plan: `PLAN.md` — Make Etabli stronger at real-product proof, large programs, and investigations
- Source plan SHA-256: `db07d4d21a461597e1287d528f4736233daf2495066bd33732e2206298e1973e`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `refactor/skill-default-load`

## Outcome

- Added `scripts/evidence-proof`, a fail-closed capture and validation kernel for product, UI, investigation, and performance claims. It binds the executed bytes, subject, environment, artifacts, and observed state without treating pack integrity as execution proof.
- Added `scripts/program-state`, a read-only reducer for immutable program manifests and the canonical append-only event ledger. It validates bounded concurrency, unit DAGs, authority, retries, zombies, current heads, writer-scope overlap, and independent verification.
- Hardened `scripts/workflow-event` with native `lockf`/`flock` locking, a PID-checked `shlock` fallback, bounded acquisition, lock-owner verification, schema checks inside the lock, and exact idempotent program retries even after terminal state.
- Added shared investigation and benchmark contracts that require controlled causal interventions for confirmed causes and frozen, comparable sampling protocols for performance claims.
- Dogfooded the product proof against the real `scripts/scaffold-project "$RUN_TMP/project" --new` flow. The retained pack validates as `VERIFIED` with `parent_observed_execution`.
- Converged the existing managed skill surface, removed only duplicate default Codex entrypoints, and compacted nine routing descriptions. No task, plan, output, or global model-token ceiling was introduced.

## Context

- Etabli already had stronger permissions and a smaller default surface than the benchmark, but real-product evidence was mostly contractual, large-program state lacked a durable DAG reducer, and investigation/performance proof was fragmented.
-  was used only to identify benchmark properties: replayable units, head-aware retries, and tactical investigation depth. Its prose, skill catalog, file layout, Cursor/Graphite coupling, and broader external-write model were not copied.
- The local Codex warning was caused by the aggregate prompt-visible skill metadata, not by large plans or task output. Correcting the installed surface was therefore separate from limiting user work.

## Decisions

### Keep two small mechanical kernels

- Context: evidence capture and orchestration state need different trust boundaries.
- Choice: use one explicit-argv proof tool and one read-only reducer over the existing canonical ledger.
- Rejected options: a new scheduler, mutable status board, browser/profiler service, default route, or default-loaded skill.
- Rationale: these kernels improve proof and replay without creating a second orchestration architecture.
- Consequences: runtime execution and external UI observation remain separate adapters and cannot be inferred from replay or integrity.

### Serialize canonical program writes

- Context: concurrent program workers cannot safely mutate one append-only ledger directly.
- Choice: require one mechanical writer, OS-backed exclusive locking where available, ownership metadata, validation while locked, and idempotent event IDs.
- Rejected options: optimistic multi-writer appends, stealing a live lock, or trusting worker-declared provenance.
- Rationale: replay is deterministic only if the canonical input cannot contain races or ambiguous duplicates.
- Consequences: workers emit immutable result artifacts; the coordinator alone ingests canonical events.

### Treat causal and performance claims as evidence protocols

- Context: source inspection and successful commands can support a hypothesis without proving it.
- Choice: reserve `CAUSE_CONFIRMED` for reproduced symptoms plus a controlled intervention, and predeclare performance fixtures, units, thresholds, sampling, warmups, and arm order.
- Rejected options: prose confidence, post-hoc outlier removal, or population p95 claims from small samples.
- Rationale: this makes strong conclusions falsifiable and repeatable.
- Consequences: incomplete or non-comparable evidence ends as `CAUSE_SUPPORTED` or `INCONCLUSIVE`.

### Fix Codex routing metadata without limiting work

- Context: after managed-link convergence, Codex still had duplicate names and shortened prompt descriptions.
- Choice: disable only three duplicate shadow entrypoints while keeping their canonical copies enabled, then compact exactly nine managed description scalars with body and referenced-file integrity checks.
- Rejected options: uninstalling plugins, masking unique suite leaves, adding a lazy-loading architecture, or imposing a token ceiling on plans/tasks/output.
- Rationale: the warning concerned metadata competing for prompt context, not the legitimate size of the user's programs.
- Consequences: the fresh surface has 89 enabled entries, including 2 explicit-only entries, and exactly 87 prompt-eligible entries matching 87 advertised entries.

## Accepted Drift

- Original plan/spec: prove the UI adapter behavior.
- Implemented reality: deterministic UI contract fixtures are proved, but no external live UI artifact was in scope; the result remains `proxy_supported`, never live-confirmed.
- Why accepted: reporting the observation boundary is safer than manufacturing a live pass.

- Original plan/spec: compare enabled Codex skills with advertised prompt skills.
- Implemented reality: 89 entries are enabled, while `html-prototype` and `review-agent` are intentionally explicit-only; the binding implicit-routing comparison is 87 prompt-eligible versus 87 advertised.
- Why accepted: enabled installation state and implicit model visibility are distinct semantics.

- Original plan/spec: prove the exact local Codex config roundtrip.
- Implemented reality: the owned marked block roundtripped exactly, then unrelated surrounding config changed. The current whole-file SHA-256 is `09a99587f8b6c1aa88dae430cec0fc1a08229823435f7d5ffddd919973f29819`; the Etabli block is independently bound and surrounding config is not claimed.
- Why accepted: the mutation scope was only the marked three-stanza block.

- Original plan/spec: implement after successful adversarial review.
- Implemented reality: implementation review found and fixed a direct internal lock bypass, post-execution executable/subject hashing, and terminal-state retry ordering before the final two independent `GO` samples.
- Why accepted: all findings gained negative regression fixtures and the final cumulative reviews found zero remaining issue.

## Validation Evidence

- `scripts/verify-agentic-infra full`:
  - exit `0` after the final review fixes.
  - router `53/53`;  `34/34` with `8/8` attacks blocked; Pi `192/192`; vendor skill lock `79` hashes.
- `bash tests/evidence-proof-smoke.sh`:
  - pass, including self-mutating executable/subject rejection before receipt creation.
- `bash tests/program-state-smoke.sh`:
  - pass, including a 128-unit replay, prefix/interleaving convergence, retries, zombies, overlapping-head rejection, and 128 serialized appends.
- `bash tests/workflow-event-smoke.sh`:
  - pass, including native lock-owner death, direct internal-call rejection, exact terminal retry, collision rejection, and stale-PID `shlock` recovery.
- `scripts/evidence-proof validate --pack .workflow/etabli-evidence-program/product-proof-v3/pack.json --root /Volumes/Crucial/work/etabli --assert`:
  - `validation=valid`, `integrity=integrity_valid`, `verdict=VERIFIED`, `execution=parent_observed_execution`, 4 artifacts.
- Codex surface aggregate:
  - 89 enabled; 2 explicit-only; 87 prompt-eligible; 87 advertised; zero duplicate names; zero shortened descriptions.
  - prompt-visible/full descriptions: 15,560 bytes; observed prior render: 15,951 bytes; headroom: 391 bytes.
  - nine compacted descriptions total 901 UTF-8 bytes; their skill bodies and all referenced files remain byte-identical.
- Managed-link convergence:
  - exact 33-path preflight matched; 31 stale managed links removed, 2 missing declared links added; postflight reports zero issue and retains a rollback receipt.
- Pi metadata:
  - unchanged at 14 skills / 3,329 bytes.
- Review:
  - final code-diff adversary `GO`, zero actionable finding.
  - final fresh cumulative review `GO`, 9/9 deciding runtime behaviors inspected, zero finding.
- `git diff --check HEAD` and `bash tests/workflow-docs-smoke.sh`:
  - pass.

## Follow-up State

- Remaining risks:
  - Codex plugin or skill updates can change the fresh aggregate; rerun the aggregate diagnostic after surface updates.
  - A real external UI/product still needs its own observable adapter and evidence artifacts; no live external UI result is claimed here.
  - Program replay is mechanically proved, while live worker/model provenance remains `proxy_supported` until a launcher integration supplies independent runtime evidence.
  - The local config outside the marked Etabli block is user-owned and may continue to change independently.
- Parking lot:
  - Add a live UI adapter only when a concrete product and observable interaction are in scope.
  - Add launcher integration only with an explicit permission and provenance contract; no launcher, billing, production, or external write was used here.
- Superseded docs/specs:
  - Pre-schema dogfood captures are retained under `.workflow/etabli-evidence-program/superseded-invalid/` as diagnostic-only artifacts.
- Next links:
  - `workflow/skills/product-dogfood.md`
  - `workflow/skills/program-orchestration.md`
  - `workflow/skills/investigation.md`
  - `.workflow/etabli-evidence-program/product-proof-v3/pack.json`
  - `.workflow/etabli-evidence-program/codex-surface/config-roundtrip.json`
