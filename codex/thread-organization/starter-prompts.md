# Thread Starter Prompts

Use these prompts to keep threads aligned with the workflow lanes.

## Project Control Thread

```text
Use codex-dynamic-workflows.
Lane: SYSTEM.
Objective: establish the current state of <project> and maintain a compact action queue.
Out of scope: do not implement changes yet.
Validation: inspect current repo state, recent thread index entries, open PR/issues if relevant, and produce NOW/NEXT/WAITING/REFERENCE.
Stop condition: report the queue, risks, and the next recommended SHIP/REVIEW/GATE/OPS/RESEARCH thread.
```

## Ship Thread

```text
Use codex-dynamic-workflows.
Lane: SHIP.
Profile: Issue Implementation Worker.
Objective: implement <one behavior or issue>.
Out of scope: unrelated refactors, unrelated features, commit/push/merge unless explicitly requested.
Validation: define expected behavior, add/update focused tests when viable, run targeted validation then broader gates by blast radius.
Delegation: spawn workers only for disjoint files/modules; parent owns integration.
Stop condition: behavior implemented and verified, or blocked with evidence and next input needed.
```

## Review Thread

```text
Use codex-dynamic-workflows.
Lane: REVIEW.
Profile: PR Review Auditor.
Objective: review <PR, issue set, commits, or diff> for real bugs, regressions, security risks, drift, and missing tests.
Out of scope: fixing code unless explicitly promoted to SHIP.
Validation: findings are evidence-backed with file/line or exact surface; state no actionable findings if true.
Delegation: spawn explorers by concern if the review is broad.
Stop condition: prioritized findings, questions, and residual validation gaps.
```

## Gate Thread

```text
Use codex-dynamic-workflows.
Lane: GATE.
Profile: CI / PR Gatekeeper.
Objective: determine whether <PR/branch> is ready and handle only directly related blockers.
Out of scope: unrelated cleanup, merge/push/force-push unless explicitly authorized.
Validation: inspect authoritative CI/PR/review state, name failed checks/logs, retest narrow then broad.
Delegation: explorer first; worker only for narrow fixes with explicit ownership.
Stop condition: ready, not ready, blocked, or unknown with evidence.
```

## Ops Thread

```text
Use codex-dynamic-workflows.
Lane: OPS.
Profile: Ops & Runtime Safety Scout.
Objective: diagnose <host/service/runtime/app issue> safely.
Out of scope: destructive commands, restarts, upgrades, migrations, secrets, prod data, or external mutation without approval.
Validation: facts from commands/logs/config, assumptions marked, rollback and before/after checks for any proposed mutation.
Delegation: read-only explorer first.
Stop condition: diagnosis, safe next steps, risk gates, rollback, verification commands.
```

## Research Thread

```text
Use codex-dynamic-workflows.
Lane: RESEARCH.
Profile: Product / Workflow Research Analyst.
Objective: answer <decision question> with evidence.
Out of scope: public posting, outreach, spending, signups, or implementation.
Validation: claims labeled confirmed/approximate/proxy-supported/blocked/unknown; primary or recent sources when relevant.
Delegation: explorer packets by question, not by duplicate broad searches.
Stop condition: decision-oriented synthesis, alternatives, MVP/experiment, kill criteria, open questions.
```

## Thread Closeout

```text
Close out this thread.
Produce: final state, files/artifacts changed, validation evidence, remaining risks, follow-up thread lane if any.
Do not start new work unless the next action is trivial and clearly in scope.
```
