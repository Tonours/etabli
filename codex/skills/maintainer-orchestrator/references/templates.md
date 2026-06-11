# Maintainer Orchestrator Templates

Use these templates when `$maintainer-orchestrator` needs worker prompts, owner decision briefs, ledgers, or heartbeat prompts. Keep outputs concise and adapt to repo instructions.

## Worker Prompt

```text
Context:
- Repo/workspace:
- Assigned item:
- Current known state:
- Source-of-truth docs/issues/PRs:
- Granted permissions: triage=<yes/no>, local edits=<yes/no>, commit=<yes/no>, push=<yes/no>, CI rerun/fix=<yes/no>, merge/close=<yes/no>, release=<yes/no>.

Objective:
- Complete exactly this repo-scoped task to the authorized boundary.

Rules:
- Do not create subworkers, delegate work, or manage other Codex threads.
- Do not touch unrelated repos or unrelated changes.
- Preserve user changes. Check git status before edits and before commit.
- Follow repo AGENTS/CLAUDE/workflow docs.
- Stop before any action outside granted permissions.

Expected workflow:
- Read the full issue/PR discussion, relevant docs, and relevant code.
- State expected behavior before editing.
- Implement the smallest maintainable candidate that satisfies the behavior.
- Add or update focused tests when behavior is testable.
- Run validation matched to blast radius.
- For UI, verify visually when possible.
- For external integrations, perform real live proof when safe credentials/targets are available; otherwise state the exact missing access.
- Run review/autoreview when the repo workflow expects it.

Final report:
- Files changed.
- Validation commands and results.
- CI/review/live proof state.
- Remaining blocker or exact owner decision needed.
- Current branch/worktree status.
```

## Owner Decision Brief

```text
Decision needed:
- URL/title:
- Repo:
- Decision type: land/delete/close/access/waiver/choose option/release.

Observed facts:
- What changed:
- Who benefits:
- Why now:
- Proof completed:
- CI/review/mergeability:

Risks/tradeoffs:
- 

Recommendation:
- 

Choices:
- A: ... Result:
- B: ... Result:

Exact next action after your choice:
- 
```

## Triage Item Card

```text
<full canonical URL> - <title>
Type/Fit/Risk: <bug|feature|dependency|docs|internal> / <good|mixed|poor> / <low|medium|high> because ...
Trust: <author facts when relevant; do not treat trust as proof>
Proof: <CI/repro/test/live/current-main state>
Blocker: <none|missing key|unclear product direction|failing check|conflict|no repro|...>
Class: <Autonomous|Needs owner|Waiting gate|Defer/close|Ignored by owner>
Next: <exact next action>
```

## Ledger Entry

```text
## YYYY-MM-DD HH:MM <timezone>

Scope:
- 

Authorizations:
- 

Active:
- Repo:
- Item:
- Worker:
- Phase:

Waiting gate:
- 

Needs owner:
- 

Decisions/actions:
- 

Next:
- 
```

## Heartbeat Prompt

Use this only when the user asks to keep monitoring or continue later.

```text
Use $maintainer-orchestrator to continue this orchestrator thread.

Before acting:
- Read the latest thread state and any local ledger/memory.
- Do not create, rename, archive, or steer worker threads before reading their latest state.
- Do not edit files, push, rerun/fix CI, merge, close, or release unless explicit permission is already recorded for that exact action.

Task:
- Refresh active workers and gates.
- Intervene only for blockers, completed work, risk, or clear course deviation.
- Report meaningful changes, owner decisions needed, and next action.
- Update the ledger/memory with meaningful actions only.
```

