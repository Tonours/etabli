# Implemented: eligible review reuse and explicit Fleet worker effort

## Metadata
- Archived: 2026-11-10
- Source plan: `PLAN.md` - Etabli owner, Fleet satellite and macbook-work configuration
- Source plan SHA-256: `87f8899b2ffee1f86753a329a55a5def1044210df44d1e2736ce20188dbc2edf`
- Status: IMPLEMENTED
- Commit / branch: scoped local edits on main; Etabli base f084e216e93205e7d74d2c41bc8e5e9f144eeba3, Fleet base 375c3f329a07bf164e13a777204d29ee5af2149b; uncommitted, not pushed
- Workflow initiative: token-efficiency-rollout
- Risk tier: high-risk

## Outcome
- Shared implementation guidance keeps explicit plan gates and permits optional fresh-context workers and user-chosen READY handoff. No automatic clear, compaction or restart; Pi remains parent-only.
- Council recorder adds explicit `--eligible-review` attestation and private atomic JSON receipts under `~/.pr-council-reuse/`. `--post` discovers eligible same-checkout/merge-base/patch records for one hour, including after an archive commit. Exact report bytes are base64 encoded; unsafe or invalid records fall back to full phase A. `--no-reuse` forces refresh; legacy explicit receipts remain supported.
- Council defaults remain high. `PR_COUNCIL_VALIDATOR_EFFORT` is opt-in for phase B only; explicit `--effort` and phase-a-only forcing take precedence. Validator author/approval gates are unchanged.
- Fleet reference docs add opt-in worker-opus-medium and worker-sonnet profiles. Six remote configuration files gained four profiles and effort-only medium args on five Claude projects, preserving worker models/settings/permissions.

## Decisions / Accepted Drift
- Reconciled the historical plan against current sources. Reused existing pr-review-flow-smoke and the actual pi skill-lock scripts rather than nonexistent paths.
- Removed viewer-marker detection: its proposed marker was absent and combining viewer approvals with bot state was unsafe.
- Preserved the owner's earlier council-high decision; medium is opt-in. Workers are optional and explicit plan requests keep their route.
- Cache identity uses patch plus merge-base and canonical checkout rather than HEAD, preserving archive-only commits. Eligibility remains a caller assertion, not certification; same-UID forgery is outside the claimed boundary. Discovery may skip phase flags unless --no-reuse, as documented.
- Removed pruning because it does not reduce tokens and would be irreversible. No broad remote Etabli deployment, commits or pushes.

## Validation Evidence
- Etabli shell-docs: 45/45 checks passed on the state before the tiny T2 delta. Final delta is only an orphan-word correction and replacing BSD stat with Node in a test; final targeted suite passes25/25 assertions, plus final workflow contracts, entry budget401/405 and Bash syntax. No claim of45/45 on final bytes.
- Skills:31 hashes verified;18 first-party locked trees pass coverage. Only the two modified skills changed hashes.
- Mutation:13 unique shell mutants; initial12 killed/1 survivor. Added repo-subdirectory regression, reran both lib mutants and killed2/2, leaving0 surviving unique mutants. The probe does not mutate embedded JavaScript heredocs. Test fixture cache directory is the sole allow-write exception.
- Fleet reference TOML parses with4 profiles, including2 medium worker profiles.
- Remote activation: backed up and staged6 files; prechecked binary/harness kinds, symlinks, original hashes and absence of one-shots. One actual restart succeeded, daemon PID17451 ->65179;6/6 config readbacks match staged hashes;7/7 existing pane PIDs survive. Backup: macbook-work ~/.local/state/etabli-token-rollout/20261110-231336. No new Claude session observed after activation, so fresh launch argv is unverified.
- Rust-suite limit: full cargo run interrupted130 after roughly20min compiling119 integration targets; narrowed config+harness_kinds run also interrupted after >5min, three rustc processes in I/O wait with about2s CPU each. Neither suite is a pass. No Rust source changed; actual daemon config loading/readback is the decisive Fleet evidence. Rust test coverage remains inconclusive.
- Preservation manifests: no unexpected changed or added files in Claudine, Etabli or Fleet; pre-existing dirty work preserved. Both Claudine repositories excluded from all writes.
- simplify: clean; quality: pass (code-quality and sibling atomic recorder/fail-closed parser patterns).
- T1 and T2 fresh Logic/Spec/Threat hunters used inline templates and effective claude-sonnet-5-5 via claudeAgent. Logic deciding-code tables complete; parent dispositions accepted by closing adversary. T2 cross-family adversary effective claude-opus-5-5 via claudeAgent, GO WITH NOTES, no remaining runtime/contract defect. Author family OpenAI; review family Anthropic.
- Final reviewed cumulative patch SHA-256:729abf805dcfe5eaf1f9ea4ba04341d8a0d891817012a5d42af3fb882baee17e. Raw checks, provenance and reports remain private under /tmp/etabli-token-rollout-evidence/.

## Follow-up State
- Local Etabli/Fleet edits remain uncommitted and unpushed. No remote Etabli source sync performed.
- Existing Fleet sessions retain old launch args. Verify a naturally created new session before claiming launch-argv proof.
- Token savings and quality equivalence are unmeasured. Rust test suites are inconclusive because compilation stalled on I/O.
- Archive belongs only to the owner Etabli repository; Fleet has no duplicate plan/archive.
