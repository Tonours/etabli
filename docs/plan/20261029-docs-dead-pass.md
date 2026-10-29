# Implemented: README and docs pass, dead docs and stale claims

## Metadata
- Archived: 2026-10-29
- Source plan: `PLAN.md` — README and docs pass: drop dead docs, fix stale claims, report dead-code census
- Source plan SHA-256: `dbdf395be522f11388a6f0e4f50a3e60c5943794679931e0a24570a312274b24`
- Status: IMPLEMENTED
- Commit / branch: `a3fbce8c` on `main`, based on `d581a167`
- Workflow initiative: none

## Outcome
- `README.md` rewritten in second person: quick start, what you get, how work
  flows, repository map with `skills/` and `extras/`, everyday commands.
- `docs/symlink-layout.md` lists every link `scripts/lib/surfaces.mjs` makes,
  separates copies and merges, and drops lines dotfiles owns.
- `docs/mcp-strategy.md` describes the alambic engine as it serves vaults today
  and names the full `.githooks/scan-secrets` command.
- `vendor/README.md` drops the prune history and the stale `pi_core` claim.
- `claude/README.md` fixes the symlink check, verify-skill and machine-local
  skill instructions.
- `workflow/skills/obvault-memory.md` points at the renamed `kb/alambic-*` notes.

## Context
The docs carried history narrative, dead vault pointers and instructions that
no longer matched the scripts.

## Decisions
- Docs stay English (public repo); only the voice rules apply.
- No code deleted: `refs.sh` and `syms.sh` found no unreferenced file or
  uncalled symbol beyond glob-run tests and name-loaded profiles.
- Zero-use skills (`spec`, `linear-project-setup`, `prototype`, `wizard`,
  `improve-codebase-architecture`) are flagged for the owner, not deleted: the
  census is heuristic.

## Accepted Drift
- None.

## Validation Evidence
- `/tmp/census/doc-paths.sh .`: checked 157 across 13 docs, dead 0.
- `/tmp/census/vault-pointers.sh workflow/skills/obvault-memory.md ~/work/obvault`: 6 pointers, dead 0.
- `AGENTIC_INFRA_JOBS=4 scripts/verify-agentic-infra shell-docs`: 38/38.
- `.githooks/scan-secrets "$(git rev-parse origin/main)" "--all --full-history --diff-merges=first-parent"`: no leaks found.
- Plan adversary codex gpt-6.1-sol: P1 and P2 CHALLENGED (9 accepted), P3 READY.
- Hunters zai/glm-5.3: Logic GO WITH NOTES (1 folded), Spec 3 accepted.
- Code-diff adversary codex gpt-6.1-sol: T1 BLOCK (6), D1 BLOCK (2), D2 BLOCK (2), all accepted; D3 PASS.
- simplify: clean; quality: skipped (pure docs); mutation: n/a (docs only).

## Follow-up State
- Owner decision pending on the five zero-use skills.
