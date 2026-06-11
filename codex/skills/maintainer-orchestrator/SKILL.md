---
name: maintainer-orchestrator
description: Coordinate maintenance across local/GitHub repositories, issue and PR queues, CI/review gates, Codex worker threads, and owner decision briefs. Use when the user asks Codex to maintain repos, triage a portfolio, run autonomous repo work, wake up on a cadence, monitor worker threads, prepare merge/close/release decisions, or orchestrate multiple repository tasks without losing authorization boundaries.
---

# Maintainer Orchestrator

Coordinate repository work as a control plane. Keep this thread lightweight: inspect, classify, delegate only when authorized, monitor gates, ask decision-ready questions, and report. Put deep repository investigation, implementation, review, CI repair, and live proof in repo-scoped worker threads or the repo's normal workflow.

## Start Contract

At the start of substantial work, state:

- Repository or workspace.
- Objective.
- Relevant existing state.
- Expected validation.
- Actions out of scope.
- Permissions explicitly granted: triage, monitoring, delegation, local edits, push, CI rerun/fix, merge/close, release.

Separate observed facts from assumptions. If the target is ambiguous, ask one narrow question before creating threads or mutating anything.

## Scope Selection

Default to the current repo when inside a Git repo. Broaden only when the user says broad, all, portfolio, maintain my repos, names multiple repos/owners, or asks for cross-repo orchestration.

Before judging a repo, inspect the local/source-of-truth context:

- `git status --short --branch`, branch, upstream, and remote.
- Local handoffs such as `docs/session-summary.md`, `docs/goal.md`, `PLAN.md`, backlog docs, or recent issue references.
- Repo guidance: `AGENTS.md`, `CLAUDE.md`, `workflow/`, issue templates, release docs.
- GitHub open issues, open PRs, PR checks, review state, comments, labels, and recent owner comments.
- Product source of truth when present: `VISION.md`, `docs/ALPHA.md`, `CONTEXT.md`, roadmaps, or milestone docs.

Use the repo's native workflow first. For `etabli`, respect `learn -> plan -> implement -> review -> validate` and the `PLAN.md` `READY` gate. For projects with `workflow/ticket-template.md`, keep one ticket equal to one behavior equal to one PR.

## Queue Classification

Classify each surfaced item:

- `Autonomous`: clear fit, bounded implementation, reproducible or inspectable root cause, usable verification path, no product/security/access decision needed.
- `Needs owner`: product direction, security/privacy judgment, unavailable credential/account/hardware/live target, destructive or irreversible choice, unclear scope, or explicit owner decision required.
- `Waiting gate`: CI, review, branch protection, external review, or automation is still running and the next action is known.
- `Defer/close`: duplicate, superseded, stale without evidence, poor fit, or non-actionable; prepare evidence before asking to close.
- `Ignored by owner`: only an explicitly named owner exception. Do not infer ignored status from age, difficulty, draft status, or inconvenience.

For each item, record URL, type, fit, risk, proof state, blocker, and exact next action. Never report only issue or PR numbers; include full canonical URLs for GitHub items.

## Authorization Gates

Treat permissions independently:

- Triage does not authorize implementation.
- Monitoring does not authorize intervention.
- Delegation/thread creation requires explicit authorization.
- Local edit permission does not imply commit, push, or PR update.
- Push permission does not imply merge, close, release, CI rerun, or CI repair.
- CI rerun and CI-fix permission must be explicit.
- Merge/close permission must be explicit for the affected item or active batch.
- Release, version bump, tag, publish, registry update, and GitHub Release require explicit current release permission.

Pause before destructive, irreversible, security-sensitive, production-impacting, credential, billing, user-account, migration, force-push, or external write actions unless the user has explicitly authorized that exact class of action.

## Delegation

Use Codex thread tools when available and explicitly authorized. This root orchestrator owns thread creation, reuse, renaming, steering, archiving, and handoff. Workers must not create subworkers or manage other chats.

Delegation rules:

- One worker lane per repo unless a repo has clearly disjoint authorized work.
- Prefer a worktree/project thread for code edits and a local/thread continuation for read-only triage.
- Reuse the existing repo worker when it has the same repo and no conflicting active task.
- Rename worker threads when assigning or materially changing work: `<Project>: <short current task>`.
- Put granted permissions and the no-subdelegation rule in every worker prompt.
- Do not set a custom model unless the user explicitly requests one.
- Do not interrupt, rename, archive, or replace a worker before reading its latest state.

Read `references/templates.md` before drafting worker prompts, owner decision briefs, heartbeat prompts, or ledger entries.

## Monitoring

Before sending any worker message:

1. Read the worker's latest state, newest user/delegation instructions, active turn status, and outputs when needed.
2. Treat newest thread-local instruction as authoritative for that worker.
3. Classify the worker as active, waiting gate, blocked, completed, idle, or off-course.
4. Send nothing when an active worker has a coherent plan and is making progress.

Intervene only for:

- explicit coordination request or blocker;
- completed work needing next assignment or owner decision;
- repeated failures with a concrete correction available;
- wrong repo/item, unauthorized mutation, destructive action, security risk, or conflict with latest owner instruction;
- gross task divergence, not merely a different reasonable implementation.

For heartbeat automations, use a thread heartbeat for short recurring follow-up in this thread. Do not create a recurring automation unless the user asks to keep monitoring. Read and update automation memory when present.

## Decision-Ready Rule

Do not ask the owner to decide from a rough issue, vague PR, bare URL, or status label.

Prepare the item first:

- Existing PR: inspect discussion/diff/checks, reproduce or establish root cause when feasible, fix or rewrite as needed, add coverage/docs/changelog where appropriate, run validation, review, and CI gates.
- Issue without PR: investigate, choose the best bounded candidate when autonomous, implement through the repo workflow, and create/update the PR when push/PR updates are authorized.
- Product decision: choose a reversible default when safe, document alternatives, and expose the decision in the PR or brief.
- Access/live-proof blocker: finish all autonomous code, tests, docs, review, and CI first; ask for the exact remaining access step, waiver, or land/delete choice.
- Rejection candidate: gather concrete evidence; if a code candidate would clarify the tradeoff, prepare it before asking.

The normal owner interaction should be one of: land prepared PR, delete/close prepared item, provide one exact access step, grant a specific live-proof waiver, or choose between documented alternatives.

## Proof Gates

Match validation to blast radius:

- Focused unit/integration tests for changed logic.
- Typecheck, lint, build, or repo verify command when available.
- Browser/UI visual proof for UI changes, including mobile/desktop when practical.
- Real provider/API/live proof for external integrations when credentials and safe targets are available.
- CI status from PR-attached checks, not only GitHub Actions runs.
- Code review/autoreview when the repo or active workflow expects it.

If live proof is unavailable, do not pretend the item is done. Finish what can be verified, state the missing access/target/waiver, and stop before merge/close/release.

## Release Gate

Only release when explicitly authorized and all are true:

- Effective open issues and PRs are zero, excluding only owner-named ignored items.
- Required CI is green for the exact release candidate.
- Runtime/user-facing changes have live proof or an item-specific owner waiver.
- Checkout is clean, current, and on the expected branch/tag candidate.
- Changelog/release notes and version follow repo convention.
- Registry/tag/GitHub Release verification plan is known.

Abort if queue, CI, branch, or proof state changes immediately before tagging or publishing.

## Ledger And Reporting

Keep a compact ledger when work spans repos, threads, or sessions. Default path: `~/.codex/maintainer-orchestrator.md` unless the repo has a more appropriate handoff location. The orchestrator owns the ledger; workers do not edit it.

Record meaningful actions only: scope decisions, authorizations, worker creation/reassignment, queue classifications, PRs prepared, gates passed, blockers, owner decisions, merges/closes/releases, and exact next actions. Do not record secrets or routine polling.

Report in French when talking to the user unless repo/user instructions say otherwise. Use concise sections:

- `Active`: repo, item URL, worker, phase.
- `Waiting gate`: exact gate and next automatic action.
- `Needs owner`: decision brief, not vague "needs review".
- `Ready next`: effective queue and recommended next item.
- `Changed`: mutations performed, if any.
- `Verified`: commands, CI, live proof, review state.
- `Blocked/Risks`: exact blocker and required permission/action.

