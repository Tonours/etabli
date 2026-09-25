# Implemented Plan Archives

Canonical convention for implemented plan memory.

## Location

Use `docs/plan/`. Store one implemented plan per Markdown file, named:

```text
YYYYMMDD-short-slug.md
```

The singular directory name is intentional.

## When To Archive

Archive a plan if and only if it was implemented and validation ran.

- Do not archive `DRAFT` plans as implemented.
- Do not archive `CHALLENGED` plans as implemented.
- Do not archive abandoned `READY` plans as implemented.
- Do not archive during planning commands.
- Do archive after implementation commands finish the planned work and run focused checks.

`PLAN.md` remains the only execution artifact while work is in progress. Files in `docs/plan/` are post-implementation memory records, not active plans.

## Immutability

An archive is immutable once written: post-archive fixes, ship outcomes,
and late discoveries live in the ship ledger + report, never rewritten
into the archive. (Prose rule — `plan-cleanup` does not refuse rewrites;
ship re-checks the captured hash and blocks on divergence.)

## When To Discard (unrelated / abandoned)

If root `PLAN.md` does not match the current user request, do not stay blocked.
Discard it and continue (or write a new plan for the new scope):

```bash
scripts/plan-cleanup --discard <reason-slug>
```

- Allowed from any plan status (`DRAFT`, `CHALLENGED`, `READY`, unknown).
- Writes `docs/plan/YYYYMMDD-discarded-<reason-slug>.md` with `Status: DISCARDED`.
- Removes root `PLAN.md` so ordinary work or a fresh plan can proceed.
- Do **not** use `--discard` after a successful implementation — use `--archive` with a validated implemented record instead.

## Stale Plans

A root `PLAN.md` that nobody finished is not harmless. A stale valid `READY`
plan is a permanently open implementation gate. A present plan carrying a
status outside `DRAFT` / `CHALLENGED` / `READY`, or an incomplete `READY`
contract, fails the mutation gate closed. Only a genuinely missing plan leaves
ordinary no-plan work available.

`Status: DONE` is **not** a valid status. Finished work is archived, not relabelled.

Surface the state of the current repo's plan:

```bash
scripts/plan-cleanup --status                    # default threshold: 30 days
scripts/plan-cleanup --status --max-age-days 90  # long-running plan
```

It reads only the current repo, never writes, and never deletes. No `PLAN.md` is a
valid state and exits 0. It exits non-zero when any of these hold:

- the plan is older than the threshold (`stale`);
- the router cannot read its status (`gateVisible: false`) — an unknown word, a
  decorated line such as `Status: READY — all slices done`, or no `Status:` line at
  all. The gate matches `- Status: DRAFT|CHALLENGED|READY` and nothing else; a
  decorated status is rejected until the root plan is repaired or discarded;
- the date is in the future by more than a day (`futureDated`).

A missing or impossible `Last revised:` date reports `ageDays: null` rather than
guessing an age. Keep the status line bare and put commentary elsewhere.

When it flags a plan, pick one:

- implemented and validated → archive it (`--archive`), then delete the root plan;
- unrelated, superseded, or abandoned → `--discard <reason-slug>`;
- genuinely still active → update `Last revised:`, or raise `--max-age-days`.

Staleness is surfaced, not enforced: nothing blocks on it today.

## Archive Format

Do not raw-copy `PLAN.md` by default. Distill it into a memory-first implementation record.

Three lines are enforced by `scripts/plan-cleanup --archive`, not just conventional:
the `# Implemented:` title, `- Source plan: \`PLAN.md\``, and `- Status: IMPLEMENTED`,
plus a `- Source plan SHA-256: \`<hash>\`` line matching the exact bytes of the root
plan being archived. Get the hash with `shasum -a 256 PLAN.md`. A mismatch is
refused, which is the point: an archive cannot silently describe a different plan.

```md
# Implemented: <outcome>

## Metadata
- Archived: YYYY-MM-DD
- Source plan: `PLAN.md` — <subject>
- Source plan SHA-256: `<sha256 of the exact root PLAN.md bytes>`
- Status: IMPLEMENTED
- Commit / branch: <when available>
- Workflow initiative: <event-ledger slug, or none>

## Outcome
- ...

## Context
- path/source: fact that mattered

## Decisions
### <decision>
- Context:
- Choice:
- Rejected options:
- Rationale:
- Consequences:

## Accepted Drift
- Original plan/spec:
- Implemented reality:
- Why accepted:

## Validation Evidence
- command:
  - result:

## Follow-up State
- Remaining risks:
- Parking lot:
- Superseded docs/specs:
- Next links:
```

## What To Omit

- unchecked planning scaffolding;
- obsolete assumptions after they are resolved;
- step-by-step progress logs unless they explain a decision;
- rollback notes that no longer matter after validation;
- chat-only context that cannot be verified from repo state or cited sources.

## Multi-Repo Plans

One piece of work spanning two or more repos still gets **one plan**.

- Exactly one repo is the **owner**: it holds root `PLAN.md` and, later, the single
  archive under its `docs/plan/`.
- Every other repo is a **satellite**: named in the plan, never holding its own root
  plan for the same work.
- The archive is **never duplicated**. One implemented plan, one record, one place.

Picking the owner — the rule, since nothing enforces it:

> The owner is the repo holding the artifact the user asked for. If you are working
> in a repo you believe is a satellite and you find a root `PLAN.md` there, stop and
> reconcile before writing a second one.

Declare the repos in the plan so the information has one home instead of being
spread across prose:

```md
## Repos
- Owner: `<repo-name>` (this repo)
- Satellite: `<repo-name>` — <what changes there>
```

No `## Repos` section means single-repo. No script parses this block; it is written
for the next reader.

Two consequences worth stating plainly:

- **The satellite side has no gate.** The READY gate resolves `PLAN.md` from the
  current directory only. In a satellite repo there is no root plan, so the guard
  allows everything — weaker than single-repo work. Do not assume the owner's
  `READY` protects the satellite.
- **A satellite remainder is new work.** If the owner archives while satellite work
  is deliberately unfinished, record it in the archive and treat the remainder as a
  *new* task. The former satellite may then open its own single-repo plan; it is no
  longer the same work.

Anything in `scripts/plan-cleanup` reaches a project only after `deploy-workflow`
runs there again — the script is copied per project, not linked. In a project that
has not been redeployed, the written discipline above is the only thing holding.

When one archive summarizes findings from several workflow initiatives, prefix
each such finding with `[initiative:<ledger-slug>]`. `workflow-retrospect` uses
the archive's `Workflow initiative` as the default and this inline marker as a
per-finding override; duplicate lines from one initiative remain one recurrence.

## Relationship To Agent Memory

Use `docs/plan/` for implemented plan history.

Use `docs/agent-memory/` for reusable lessons that should change future agent behavior across tasks.
