# Implemented: integrate Pi Durable with the advanced Etabli main

## Metadata
- Archived: 2026-10-02
- Source plan: `PLAN.md` — Pi Durable advanced-main publication
- Source plan SHA-256: `980cf50ca35b404805958ea8da7d08df7988d200bed20234b4fc17d5b86a0244`
- Status: IMPLEMENTED
- Commit / branch: Etabli `02c4b7635acaf2dc2463eab254c23e57e3fffcd3`; Pi Mobile `586c7abfc571775a7afec0d1a7818892b10f8f3d`; `feat/durable-workflow`
- Workflow initiative: pi-durable-main-refresh

## Outcome
The seven Durable workflow families and Pi Mobile admission/recovery changes are integrated with the independently published Claude session cockpit. Reviews retain results, missing reviewers and spent budgets; missions retain phases and validations; child tasks retain dependencies, cancellation and results; mobile messages retain admission identities; CI waits retain their initial deadline and check the current HEAD; experiments retain cells, failures and consumption; compaction and handoff retain coherent progress.

Code integration is implemented and reviewed. Publication is pending: actual pushes, local/remote main parity and terminal exact-head owner CI belong to `.workflow/pi-durable-publication/publication.json`. This immutable code archive does not attest later operations.

## Context
- Owner parents: reviewed delivery `df38618a767b7cfc935eb5972bb59c098427181b` and independently advanced main `1e79c3caa36ed634fcc2099285e00c253df065eb`. The conflict-free automatic merge includes 21 incoming paths; only README overlaps prior shipping paths.
- Satellite reviewed merge `586c7abfc571775a7afec0d1a7818892b10f8f3d`, current main `b9ee157fabdb99f846869c13be6e6314e05e98e3`, tree `583849234b2a2188c3d0bfa793d7bd72af1f3c0b`. Its 13 prerequisite M0 commits remain in ancestry. Its primary checkout stays on `feat/m0-integration-proof` at `694c187` with its unrelated tracked READY plan.
- Previous integration's full F2 passed, then the remote gate refused the independently advanced owner tip. Its 54-event ledger remains terminal blocked, SHA256 `1d6de2778a747f861eb7520685b3119019d96aebc5f2b2431deac4ee8cab18bd`. All four prior terminal ledgers and the original implemented archive remain immutable. Old gate refusal and frozen handoff are retained.

## Decisions
### Preserve the delivery and the incoming cockpit
The reviewed owner tree is `69aa633ec6ce6bff9b1da888ece26c8e67b47d19`. Compared with automatic merge `b52006cda78b01ab886f281528fd6df2ce23e78e`, only `workflow/durable-exports.md` changes. All 82 other prior shipping files are exact except the automatic README merge and that scoped paragraph; all 20 incoming non-README files remain verbatim. No new runtime, dependency, schema or permission correction was made. The satellite tree is unchanged.

### Keep lock documentation within observed guarantees
The cold paragraph states backend order lockf/flock/shlock/none, inherited parent-argument checks, optional descriptor proofs, cached native admission and the remaining cooperative same-UID window. Native descriptor proof checks FD0–9; the lsof fallback compares reported pathname and does not attest an old inode after replacement. The negated acquisition probe treats all acquisition failures, including backend errors, as lock evidence. Native lockf/flock checks are cached at commit; shlock separately rechecks its own PID file. These are limits of observed behavior, not security attestation.

### Review producers and readers on one full frozen source
Two independent full Logic/Spec hunters cover all seven workflows, eight incoming readers and 39 deciding-context files. The actual canonical projection preserved all 54 historical event objects across seven pages, including FD/F2, handoff and blocked; it selected the new active run and stayed projection-only. Source hashes bind reused runtime checks. The original full pin is `cf324a0dbd2def06e6dae0d1263b57abe4ca621f89df5e6f6033110ea1f6c39f`, 84 files, 23,150 lines, 1,092,726 bytes.

### Arbitrate the LOW display proposal against its contract
The completed full Anthropic adversary `0b0424ac-a274-4581-b486-c352de40bfc4` (`claude-opus-5-5`, firstParty) returned raw BLOCK for one LOW proposal F2-A1. Its normal report and coverage remain unchanged. Under `workflow/skills/adversary.md` code-diff arbitration, the parent rejected that proposal using `docs/claude-etabli-mod.md:31`, SHA256 `4a789deb61eed142f1843b5346159de6fdc53b8d61eec2608e3eef8da2258393`: Routing explicitly displays the last recorded route, which is exactly the reported output. Execution route authority is separately resolved. The final lead verdict is GO WITH NOTES, accepted findings none; it is not attributed to the model. Clearer review-budget routing text remains a UX note.

### Separate code closure from publication
Exact-base ancestry and two exact-SHA dry-runs passed before this archive. Hash-gated cleanup removes only the owner's root plan. A single archive-only owner commit, another full infrastructure group and repeated final remote gates must precede ordinary exact-SHA owner-first and satellite-second pushes. Preserve partial successes and uncertain timeouts; never force, rewrite or undo. The installed launcher keeps its worktree.

## Accepted Drift
- Advanced owner main required a new integration source/base scope after the previous run's remote refusal. No old results, consumed budgets or counters were reset.
- Review sequence: T1 clean, F1 findings, FD consuming D1 findings, one cold sentence fold, then full F2 clean after parent LOW arbitration. Supplemental sentence samples are not D2. A mistaken second FD append was refused and added no event; the original inaccurate next-round note remains immutable with a later correcting handoff.
- Original internal 180-minute cap started at 10:46UTC. Actual READY passes adopted +20 and +15 minutes, retained missed 13:45 and 14:15 checkpoints and handoffs, then actual finite READY `aa1622d3-6798-4bec-91dd-b6517bdd30a7` retired the operator clock stop under the human's reassessment instruction and commit/push authority. Native/model/request/cost limits and spent review attempts remain intact. At code archive 2026-10-02T15:05:04.563104+00:00, elapsed 15544s; overrun against original 180 minutes 4744s. Actual publication end is still unknown and will be recorded later.
- The first F2 adversary covered only the lock paragraph and was inadmissible; it is retained as incomplete. The second full review above is the counting independent pass. Supplemental factual verification `1d3e037e-04b3-40c0-bb9c-cce9301428b8` was refused by the individual Anthropic spend limit and is not a completed review. A prior supplemental startup had no observed init/result before temporary files disappeared; consumption is unknown, not reset. No third full review was used.
- Temporary report files disappeared during execution. Exact full source pin and both hunter reports were recovered from this task's scoped normal history; the full adversary normal report and actual provenance were recovered without exposing private reasoning. Recovered source and protected-tree checks pass.
- Standalone Bun could not load runtime-provided `claude-code/testing`; the official `claude plugin test` adapter passed the exact four cases. Optional typecheck initially lacked generated declarations, then passed using five existing ignored native-generated declarations from the primary checkout. Failed attempts remain failures; no dependency change was introduced.
- [initiative:pi-durable-main-integration] Exact canonical exports compare immutable original request details under the existing lock before re-enrichment and stale-plan checks. Reserved markers and inconsistent/non-product drift fail closed; product authority stays canonical.
- [initiative:pi-durable-main-integration] Nested commands copy frozen role inputs and recheck both export/preparation awaits. Existing phone Release remains available during connector or ownership conflict; its SDK release/retry API stays authoritative.

## Validation Evidence
- `npm test --prefix pi/durable`: 81/81; strict native unused-local/parameter typecheck exit0. Logs `native-full.log` and `native-types.log`.
- `AGENTIC_INFRA_JOBS=2 scripts/verify-agentic-infra full`: 84/84, including 444 classic extension tests, on the final corrected source; `infra-doc-final.log`. References and whitespace exit0. An additional final archive-only full group is a publication gate, still pending here.
- Incoming canonical session tests: 81/81; official Claude Mod adapter: 4/4; plugin validation and generated-declaration strict typecheck exit0. Logs `upstream-node.log`, `upstream-plugin-test.log`, `upstream-plugin-validate.log`, `upstream-plugin-types-final.log`.
- Unchanged satellite tests: 26/26 and strict types. Installed real SIGKILL/resume with exact-ID request count1 passed. Physical phone rendering, live provider quality and native Linux supervision are not inferred from those checks.
- Full source `cf324a0dbd2def06e6dae0d1263b57abe4ca621f89df5e6f6033110ea1f6c39f` and stable tree proofs pass. Four terminal ledgers, original archive, five default configs/entrypoints and five original unrelated documents retain hashes. A sixth unrelated primary research document was observed later and remains outside shipping; sync must preserve all current untracked documents.
- Final F2 Logic/Spec reports, deciding tables, raw full adversary, parent LOW arbitration, supplemental provider refusal and actual model metadata are retained under `.workflow/pi-durable-main-refresh/reviews/f2/`. Simplification and sibling/canonical-helper comparison are clean; no new production abstraction.
- Prearchive exact remote tips `1e79c3c` and `b9ee157`, ancestry and both dry-runs passed: `prearchive-gate.json`. Reviewed merge trees match frozen/tested sources.

## Follow-up State
- Pending publication: archive-only commit, final full/references/whitespace, repeated remote gates, both exact pushes, safe local-main fast-forward synchronization and terminal exact-owner-SHA `agentic-infra` CI. Pi Mobile has no main-push CI, N/A.
- Known residual M0 custom-config pairing, old-socket disconnect and concurrent-release/ownership limits remain separate scope. Native postlaunch effects need conservative reconciliation. Physical phone/live provider/native Linux process-supervision quality remains unverified.
- Any remote/source drift, protection refusal, failed final check or genuine final finding stops with an exact operational handoff. CI failure ends this finite scope; any correction requires a separate later scoped plan. No deployment, provider purchase, external messages, force push, history rewrite or worktree cleanup.
- Next evidence: `.workflow/pi-durable-publication/publication.json`, exact GitHub commits and terminal current-head owner CI. Publication remains pending until those postconditions succeed.
