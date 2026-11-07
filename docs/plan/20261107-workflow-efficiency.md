# Implemented: bounded workflow payloads and safe review reuse

## Metadata
- Archived: 2026-11-07
- Source plan: `PLAN.md` - workflow efficiency and macbook-work rollout
- Source plan SHA-256: `d5c0d0a4343d57ed36c40408c0db3ced7777870848f61c2d86af385c35084f49`
- Status: IMPLEMENTED
- Commit / branch: `perf/workflow-efficiency`; source published directly to `main` through `9e783a2118e7a20564f114b85840d131ae663a94`
- Workflow initiative: workflow-efficiency

## Outcome
- Both plan templates and the implementation contract carry a current-state handoff targeted at 400 words, including owner decisions, constraints, criteria, open safety findings, proof references and next action. Indispensable state is retained with a justified overrun; no automatic reset or restart.
- Implementation and investigation guidance saves verbose results privately and reads decisive ranges. Command exits, failures, raw machine data, canonical council streams and required review tables stay authoritative.
- The existing council CLI gains `--record-review <base-ref> <report-file> <output-file>`. It packages exact report bytes and the committed-patch fingerprint into a private file using a same-directory temporary and Node's atomic rename. Failure preserves the previous destination, and a directory appearing concurrently is refused.
- Both manual fingerprint modes reject masked index flags, repository/index/object-store environment overrides, configured core.worktree and config-read errors; fsmonitor is disabled for inspection. Submodules conservatively use full phase A and retain their Git config.
- Council, watcher verification, delta and autoreview logs use `repo#PR@headSHA`. Legacy records remain unbound. No duplicate analyzer or automatic Fleet importer was added.
- The existing settings version guard also rejects a spawn error when exit status is zero. A deterministic oversized-output regression exposed ENOBUFS with status zero; the shared model env remains unset.

## Decisions
- Preserve current reviewer models, effort, turn limits, validator and review-reuse eligibility. Packaging is not review certification: matching criteria, two fresh reviews and cross-family provenance are still required.
- Use existing contracts, CLI and logs rather than a new hook, dashboard, analyzer or review-receipt subsystem. Fleet's independent analyzer task retains its ownership.
- Replace stdout packaging with an explicit atomic destination after a real partial-write attack left a valid header with truncated evidence. Replace BSD mv with renameSync after a controlled destination-directory race produced a false success.
- Preserve native Claude env and unrelated settings on rollout. The full remote update also includes the previously merged Pi retirement migration; its catalog/package changes are expected.
- Publish source first, verify the authorized remote rollout, then archive. The archive-only follow-up does not alter deployed runtime code.

## Validation Evidence
- `scripts/verify-agentic-infra full`: 46/46 on final source; surfaces 44/44; entry chain 401/405. Contract and skill-lock coverage pass.
- New recorder/head fixtures first failed 12 assertions; final focused and complete flow suites pass. Fixtures exercise literal bytes, private mode, invalid reports, dirty/hidden/index/config states, ordinary diff configuration, interrupted writes, directory races, cleanup and four head-attributed producers.
- Settings overflow: native single-builtin output produced status0 plus ENOBUFS in 80/80 diagnostic calls. The real guard regression failed before `!version.error` and passed after, alongside accepted versions and old/missing/failing controls. No actual model request.
- Mutation: 36 unique mutants scored; 35 killed, one equivalent justified. A supplemental full-surfaces run killed all nine version-expression variants, resolving two survivors from an overly narrow initial test selection. The remaining config-query fsmonitor flip does not invoke a hook; actual index/status calls still disable it. No invalid, denied or timeout outcomes.
- `simplify: clean`; `quality: pass` with code-quality and existing atomic-write/CLI patterns. Changed skill fingerprints recomputed from their source trees.
- Plan P1 CHALLENGED, P2 READY after explicit rollout/rollback boundaries. Fresh Logic/Spec/Threat reviews and code adversaries ran Claude Opus5.5, requested/effective Anthropic via T3, independent of the author family, with inline hunter templates and complete reports.
- Closing T2 adversary: GO WITH NOTES, STATUS complete. Final cumulative SHA-256 `0ab8c7f99f96a13a03385462199090cf3e0e06d68781b974e542a89c0110eef2`; final small fold `65e607152be83887c6cd5d95f0e6eb71fba7643115a76149737e534efc21f183`; captured plan `d58201e5b42d2e08b0d945a3da17cdcd65d40eed87b4524fa713eefedfaf56b9`. Complete tables and raw synthetic evidence remain private.
- macbook-work: clean fast-forward, dry-run with one expected Pi settings sync, apply/check exit0, zero unresolved, Claude/Pi skill-load checks pass. Claude env and unrelated settings preserved; only Pi packages changed.
- Fleet service PID/start/binary and all 12 observed Claude/Codex processes stayed present. Fleet checkout remained unchanged and clean. No restart.
- Installed remote recorder passed a synthetic real-script/native-rename smoke: correct header, exact bytes, mode0600. Private backup and rollback manifest retained on the remote machine.

## Follow-up State
- Real workload token/quota/cost savings are unmeasured. Existing logs now support per-head comparisons alongside Fleet measurements.
- Record preparation requires Node; missing Node fails safely. Configured submodule checkouts fall back to full phase A.
- No global Sonnet activation; existing local model values are preserved. Existing sessions retain their loaded context.
- Root PLAN.md is removed through the archive hash gate. The isolated worktree is retained for inspection; the original checkout and unrelated work are preserved.
