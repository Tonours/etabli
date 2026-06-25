# Orchestration: PLAN.md ADR review

## Execution Rules

- Keep the original objective intact.
- Ask for approval before risky, expensive, external, or destructive actions.
- Keep immediate blocking work local.
- Delegate only bounded, disjoint, materially useful packets.
- Integrate packet results before final verification.

## Branching Rules
- If local repo evidence contradicts `PLAN.md`, mark the issue as blocking unless the plan already scopes it out.
- If web docs contradict hook or skill behavior, prefer the web primary source and mark the affected acceptance criteria/checks as suspect.
- If only third-party ADR guidance disagrees, mark as advisory unless it threatens the core behavior.
- If `PLAN.md` contains stale internal contradictions, mark readiness risk even when implementation might still be possible.

## Packet Prompts
- P1: Read only the files needed to verify repo claims: `PLAN.md`, `claude/README.md`, `claude/settings.workflow-hooks.json`, hook files, skill examples, and install script slices. Output observed matches/mismatches.
- P2: Review `PLAN.md` adversarially. Assume implementation will fail unless the plan proves behavior, validation, and rollback. Output severity-ranked findings.
- P3: Search current web sources for Claude Code hooks, Stop hook semantics, skill behavior, and ADR record conventions. Output cited claims and implications.
- P4: Integrate P1-P3, reject weak claims, and produce `final-report.md`.

## Completion Audit
- All packet result files exist.
- Final report distinguishes observed facts, sourced facts, assumptions, findings, and recommended decision on `READY`.
- Final answer cites web sources used.
