# Implemented: close the 2026-09-10 Etabli analysis feedback (scaffold, guard parity, symlink policy, test hygiene, lock coverage, doc drift)

## Metadata
- Archived: 2026-09-10
- Source plan: `PLAN.md` — implement the analysis feedback on Etabli (scaffold, guard parity, symlink policy, test hygiene, lock coverage, doc/vocabulary drift)
- Source plan SHA-256: `6f1c7e3d7a966e42df04ed6eeb51f3140e0468698a65696fe16a4b2bd8d03a87`
- Status: IMPLEMENTED
- Commit / branch: not committed (run on `main` over two pre-existing user workstreams)

## Outcome

Eight slices implemented, every one backed by a focused check and the full
`scripts/verify-agentic-infra core` group (18/18). The deployed workflow
scaffold is self-contained again, Pi and Claude share the same `PLAN.md` commit
guard, the vendor surface policy is single-sourced in
`scripts/lib/vendor-surfaces.sh`, orphan tests are wired, the Codex description
smoke no longer grades itself, `skills-lock` covers 83 trees (was 66), and the
contract/vocabulary drift called out by the analysis is fixed.

## Context

- The analysis (2026-09-10) reported: a scaffold with dead references despite
  ADR-0005, Pi missing the shared commit guard, three disagreeing vendor-link
  policies, a tautological test, an installer never exercised past its embedded
  smoke branch, 17 unpinned skill trees, and vocabulary/doc drift. Each item had
  a validation surface except the ones listed under Follow-up State.
- Working tree was already dirty with two user workstreams (ADR-0024 Devin
  surface, token-rate extraction) touching some of the same files. Baseline
  copies per edited file (`.workflow/20260910-retours-analyse/baseline/`) kept
  this run's patch isolatable from those hunks.

## Decisions

### Keep route `verify` and document the `/verify-workflow` alias
- Context: `spec.md` named the route `verify`, the classifier emits
  `verify-workflow`, and router-eval fixtures pin `verify`.
- Choice: document the alias instead of renaming the contract route.
- Rejected options: renaming the classifier route (fixture churn, no gain).
- Rationale: the route vocabulary stays stable; only the presentation differs.
- Consequences: one sentence in `spec.md`; fixtures unchanged.

### Single vendor-surface policy helper
- Context: install/deploy/check each encoded which surfaces get a vendor skill.
- Choice: `scripts/lib/vendor-surfaces.sh` with `vendor_surface_expected`,
  `vendor_link_skill_surfaces`, `vendor_prune_unexpected_skill_surfaces`.
- Rejected options: full structural convergence of the three tools (ADR-0018
  defers that; too large for this evidence).
- Rationale: smallest change that removes the actual disagreement.
- Consequences: duplicate predicates deleted; prune only removes links whose
  target is the managed skill dir; empty scope fails closed.

### Namespaced extra lock keys
- Context: scoped Claude skill names collide with catalog names
  (`bug-check`, `pr-qa`, `sec-pr`, CSS skills).
- Choice: `claude-scope/<scope>/<name>` and `herdr/herdr`; write mode prunes
  obsolete lock keys.
- Consequences: lock grew 66 -> 83; a new scoped skill cannot ship unpinned.

## Accepted Drift

- Original plan/spec: deploy exactly the documents referenced by deployed docs.
- Implemented reality: nine documents plus a JSON template were added to the
  deploy set; `runtime/**`, `run/**`, `self-improvement/**`,
  `runtime-capabilities.json` and `program-orchestration.md` are explicit
  etabli-only allowlist entries, now enforced by a project-wide reference scan.
- Why accepted: those four are harness state, not project-facing contracts.

## Validation Evidence

- command: `scripts/verify-agentic-infra core`
  - result: 18/18 pass, before and after the review fixes
- command: `bash tests/dual-runtime-guard-matrix-smoke.sh && cd pi && bun test ./extensions/__tests__/workflow-router-extension.test.ts`
  - result: matrix ok (named/staged/DRAFT, Claude + Pi schemas); 23 tests pass; typecheck clean
- command: `bash tests/workflow-scaffold-smoke.sh`
  - result: ok; project-wide dangling-reference scan with allowlist
- command: `bash tests/vendor-surface-policy-smoke.sh && bash tests/vendor-prune-modes-smoke.sh`
  - result: ok; pi_core gate, migration prune, target check, fail-closed scope
- command: `bash tests/agentic-infra-manifest-smoke.sh && node --test tests/harness-token-usage.test.mjs`
  - result: manifest ok; 33 node tests pass
- command: `bash tests/codex-skill-description-smoke.sh`
  - result: ok (1 skill, 142 bytes, proxy_supported); synthetic classifier removed
- command: `(cd pi && bun run verify:skills) && bash tests/skills-lock-coverage-smoke.sh`
  - result: 83 hashes verified; 17 pinned trees independently derived and hashed
- command: `bash tests/workflow-docs-smoke.sh`
  - result: ok; spec 203/220, contract-details 310/340 line caps
- review: fresh-context Logic + Spec hunters; high finding (Pi `tool_call` has no
  `cwd`) fixed via handler `ctx.cwd` plus a production-shape test
- adversary: cross-model (Claude, read-only) `GO WITH NOTES`; four low notes
  accepted and fixed, one named as pre-existing workstream overlap
- ledger: `.workflow/20260910-retours-analyse/events.jsonl` valid under
  `--profile autonomous-completed`

## Follow-up State

- Remaining risks:
  - Full real-path `install.sh` coverage is still absent (D1): the script mixes
    system package installs and network in one linear path; it needs
    decomposition into testable stages before CI can run it.
  - `tests/fix-links-smoke.sh` hangs on the current dirty tree; reproduced
    against the pre-change baseline, so it belongs to the in-flight ADR-0024
    Devin workstream, not this run.
  - `runtime-capabilities.json` still has expired `unknown`/`blocked` entries
    (D2); enforcing freshness needs live probes, and faking `verified_at` is not
    acceptable.
- Parking lot:
  - structural convergence of install/deploy/check symlink tools (D4);
  - split of the 935-line `workflow-docs-smoke.sh` (D5);
  - contract prose de-duplication beyond the new caps (D6);
  - git workstream hygiene for the two uncommitted user workstreams (D3).
- Superseded docs/specs: none.
- Next links: `docs/plan/README.md`, `.workflow/20260910-retours-analyse/events.jsonl`.
