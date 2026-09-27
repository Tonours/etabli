# Implemented: repo skills meet size and structure best practices

## Metadata
- Archived: 2026-09-27
- Source plan: `PLAN.md` — Suite audit 2 — skills du dépôt conformes aux bonnes pratiques de taille et de structure
- Source plan SHA-256: `79327140f0366c44e042972f40258552cfc757df3afc507c0616b6fde20636f9`
- Status: IMPLEMENTED
- Commit / branch: `refactor/skills-hygiene`, stacked on `feat/review-rounds-check` (base `1fcfe50`); not pushed
- Workflow initiative: `skills-hygiene` (completed at F1)

## Outcome
- `scripts/token-bench --skills` warnings dropped from 20 to 6. The 6 left are all upstream (vendor); owned skills have 0 warnings and 0 hard violations.
- `extras/skills/project-hunt`: SKILL.md went from about 6 307 to about 3 850 estimated tokens. "Capability and safety preflight" and "Phase 4 — deterministic rank" moved verbatim to `references/preflight.md` and `references/ranking.md`. Load-first step 3 reads the preflight now, before step 4 reads untrusted workspace content, and the ranking before scoring. An unreadable reference stops the hunt as `blocked`.
- `extras/skills/design`: `design-guidelines.md` is merged into SKILL.md, keeping its usage sentence and dropping only the H1. The two links to it now point to `#load-contract`, with unchanged text. The 39 `guidelines/*.md` files are one level deep, and the file is deleted.
- 12 long owned references gained a `## Contents` section listing their H2 titles outside code fences.
- `scripts/workflow-adapter-sync`:
  - no `pointer:` line for a canonical row (4 pi SKILL.md files);
  - `--check` refuses a stamped block outside the manifest, whatever the extension, anywhere under `pi/skills`, `extras/skills` and `claude/scopes`;
  - the 3 orphan blocks of `extras/skills/{coolify,grill-me,project-hunt}` are removed.
- `skills-lock.json` is regenerated.

## Context
- The orphan blocks came from the `c2bfe92` move. The old reverse scan only covered `pi/skills/*/SKILL.md` and `claude/scopes/shared/{commands,agents}`.
- Before the move, the preflight rules were in context as soon as SKILL.md loaded. They must still be in context before project-hunt reads workspace files.
- `scripts/pi-skill-load-check` can hang when stdin stays open (`pi -p --offline`); it passes at once with `</dev/null`. Older hung instances were left running on the host.

## Decisions
### Proof by rebuild, not by line multiset
- Context: plan passes R2 and R3 showed that a line multiset misses a reorder, such as swapping "Use For" and "Do Not Use For".
- Choice: one transformation script rebuilds every touched file from `git show HEAD:<path>` and compares byte for byte. It is the explicit list of allowed transformations (`--apply` and `--verify`).
- Consequences: each fold changed the script first, then the tree; `--verify` stays the proof.

### Retarget links instead of rewording
- Context: T1 Spec flagged the rewording of design Workflow step 2 as against AC2.
- Choice: keep every line; only the link targets change to `#load-contract`.

## Accepted Drift
- Original plan/spec: replay `tests/fixtures/project-hunt` scenarios (suggested at R1).
- Implemented reality: not replayed.
- Why accepted: paid live web research, disproportionate for a verbatim move proven by rebuild.

## Validation Evidence
- command: `bash tests/adapter-sync-smoke.sh`, `scripts/workflow-adapter-sync --check`
  - result: pass; the canonical-without-pointer and 4 orphan fixtures (`extras`, `claude/scopes`, `pi/skills/.../references`, `.markdown`) bite
- command: `scripts/token-bench --skills --json | jq -e …` (0 owned warnings or hard violations, 95 skills)
  - result: exit 0
- command: `python3 /tmp/sh-transform.py --verify`, `node /tmp/sh-verify.mjs`
  - result: 19/19 files match the HEAD rebuild; 0 errors on 12 long references. Both proofs bite on an injected reorder and on a wrong Contents entry.
- command: `bash tests/skills-lock-coverage-smoke.sh`, `scripts/pi-skill-load-check`, `scripts/claude-skill-load-check`, `scripts/token-bench --check`
  - result: pass
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 27/27 and 81/81
- Reviews:
  - Plan: 4 cross-family passes via `scripts/pi-review-hunter` (`openai-codex/gpt-6-astra`), the last READY.
  - Code: T1 findings (3 accepted), T2 findings (1 accepted), D1 clean, F1 clean (Logic GO, Spec GO, pi GO, capture `584b07e0`).
