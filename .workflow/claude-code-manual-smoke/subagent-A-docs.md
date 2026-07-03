# Subagent A — docs accuracy review (verbatim findings)

Agent: general-purpose, model opus. Read-only. Files reviewed:
- claude/CLAUDE.md
- claude/README.md
- workflow/skills/orchestration.md

## ACCEPTED
- CLAUDE.md:36 — "Use PLAN.md as the only execution artifact" — consistent with README:95.
- CLAUDE.md:37 — "Implement only from Status: READY" — consistent with plan-ready-guard.mjs (README:67-68) and /implement route (README:28, CLAUDE.md:42).
- CLAUDE.md:40-51 — route list matches README:26-37 (12 shared routes identical).
- CLAUDE.md:63 — docs/plan/YYYYMMDD-short-slug.md archive after READY implementation.
- CLAUDE.md:64-65 — /verify-workflow must not shadow native /verify — confirmed README:49-50.
- CLAUDE.md:66-67 — /goal for long loops with measurable condition — confirmed orchestration.md:14,108 and README:79-86.
- CLAUDE.md:68-70 — orchestration.md as parity reference, Task* Pi-only — confirmed orchestration.md:11-14 and README:88-91.
- README:7-17 — Claude Code install surfaces (commands/*.md, hooks/*.mjs, settings.workflow-hooks.json) match real surfaces.
- README:63-77 — three hooks activate the three native Claude Code surfaces.
- README:88-91 — Claude parity via /goal, commands, hooks; Task* Pi-only.
- orchestration.md:14,108 — /goal is Claude's native till-done mechanism.
- orchestration.md:113-114 — "Claude has no Pi Task* equivalent unless runtime exposes one" — correct phrasing.

## REJECTED
None.

## CONFLICTS (omissions, not contradictions)
- README:52-57 vs README:7-14 — /adr skill + detect-adr-signal.mjs hook in README but absent from CLAUDE.md route list.
- README:38-48 — local commands (/adversary, /commit, /cross-repo-audit, /linear-project-setup, /spec-guide, /spec-verify) not in CLAUDE.md:40-51.
- README:61 — /github-pr-review alias for /pr-review listed separately, not referenced in CLAUDE.md:48.

## DRIFT
None. All referenced paths internal and consistent. Codex mentioned as third runtime (declared out of scope by design).

## VERDICT
DOCS_CONSISTENT — three docs agree on routes, artifacts, hooks, Pi/Claude parity; deviations are unilateral README omissions not reflected in CLAUDE.md, with no factual contradiction and no Pi-only primitive wrongly attributed to Claude.
