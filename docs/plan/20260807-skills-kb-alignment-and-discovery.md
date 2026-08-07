# Implemented: skills realigned on the knowledge base, and made reachable by agents and commands

## Metadata
- Archived: 2026-08-07
- Source plan: Réaligner les skills sur la knowledge base et câbler leur découverte dans les agents et les commandes
- Status: IMPLEMENTED
- Commit / branch: `main`, staged on top of `d90bd62`

## Outcome

- Four employer/personal skills that lived only in `~/.claude/skills/` as real
  directories are now tracked in `claude/scopes/work/skills/` and symlinked back:
  `sec-pr` (412 L), `pr-qa` (232 L + 2 reference files), `bug-check`,
  `week-roadmap`. A machine reset would have lost them.
- New `employer-backend-suite` router skill covers the half of the knowledge base
  that had no skill at all: BFF, auth/permissions, MCP/capabilities, Zendesk,
  workflow executor/orchestrator. 48 note pointers, all verified to resolve.
- `scout`, `worker`, and `reviewer` declare `Skill` and pick a domain skill
  themselves; `/ship`, `/plan-loop`, `/plan-implement` do the same as their first
  step. `/recap` gained `Skill` (it already invoked `write-direct` in prose) and
  `Bash`, which it needed for the `git log`/`gh` it was already told to run.
- The contract-vs-skill duplication on five names is now documented instead of
  looking like drift.

## Context

- `~/work/brain/kb`: 58 notes — bff 11, zendesk 8, employer 7, mfe 6, agent 5,
  workflow 4, mcp 4. Roughly half backend/integration.
- `claude/scopes/work/skills/`: was 15 skills, 13 of them Ember frontend. The
  domain carrying most of the work had no skill.
- `claude/hooks/workflow-router-lib.mjs:405-827`: classifies workflow routes; no
  skill name appears in any decision object. Skill selection was never wired.
- `claude/scopes/shared/commands/`: 2 of 26 commands declared `Skill`
  (`front-quality.md:5`, `spec-guide.md:5`).
- `claude/README.md:97-99`: `allowed-tools` is a permission pre-approval, not a
  sandbox — so adding `Skill` only widens what is pre-approved.
- `scripts/check-fix-symlinks.sh:90-94` (`repair_link`): moves a real directory
  to `<path>.bak.<timestamp>` before linking; `rm -rf` only ever hits symlinks.
- `tests/workflow-contract-coverage-smoke.sh:35-58`: every
  `workflow/skills/*.md` contract must stay referenced from `claude/`, `pi/`,
  `docs/`, or `spec.md`.

## Decisions

### No hook suggests a skill
- Context: the obvious fix for "agents don't find skills" is a router hook.
- Choice: leave selection to the model, via descriptions and explicit router
  skills.
- Rejected options: a `UserPromptSubmit` hook injecting a skill hint per prompt.
- Rationale: ADR-0014 removed per-prompt route-context injection for cost and
  noise. Rebuilding it for skills would replay the same mistake under a new name.
- Consequences: selection stays probabilistic. The router skills and the
  first-step instructions in the commands are what make it reliable.

### One backend router, not five domain skills
- Context: the KB splits into BFF, auth, MCP, Zendesk, workflow.
- Choice: a single `employer-backend-suite`.
- Rejected options: five separate skills, one per domain.
- Rationale: `ember-employer-suite` proves the router pattern works, and one
  router costs one namespace entry instead of five in an already crowded space.
- Consequences: the router grows a row per new domain rather than a new file.

### The router cites note names, never their content
- Context: notes carry `file:line` evidence that ages.
- Choice: point at note names only; re-verify `file:line` against current HEAD.
- Rejected options: inlining the findings into the skill.
- Rationale: a daily cron updates the vault; duplicated content would drift
  silently and be trusted anyway.
- Consequences: the skill stays useful only while note names are stable — which
  the vault contract already guarantees (no duplicate basenames).

### Contract and skill keep the same name on purpose
- Context: `bug-check`, `pr-qa`, `pr-review`, `sec-pr`, `review` each exist as a
  `workflow/skills/` contract, a command, and a skill, with divergent content.
- Choice: keep all three; document the split in `claude/README.md`.
- Rejected options: collapse contract into skill, as the plan first proposed.
- Rationale: the contracts have real Pi consumers (`pi/skills/pr-review/SKILL.md`,
  `pi/skills/github-pr-review/SKILL.md`) and Pi cannot see Claude skills.
  Collapsing them would have broken Pi silently.
- Consequences: duplication remains, deliberately. The rule for which one to edit
  is now written down.

## Accepted Drift

- Original plan: step 2 would "reduce the contract to what stays true for Pi".
- Implemented reality: no contract file was touched. Each imported skill names
  its contract in its opening lines, and `claude/README.md` states the rule.
- Why accepted: reading the contracts showed live Pi consumers. Editing them was
  a regression risk with no upside for the stated goal.

- Original plan: keep `.bak` directories as a safety net until validation.
- Implemented reality: removed as soon as content was confirmed identical.
- Why accepted: the harness loads `~/.claude/skills/*.bak.*` as real skills,
  which polluted the namespace with four duplicates. The net had become the risk;
  git is the actual net.

- Original plan: the fresh-context review would come from a dispatched reviewer.
- Implemented reality: two dispatched reviewers stopped without returning a
  verdict. Both adversary and diff review were run by the main session and are
  recorded as same-family, never as cross-model.

## Validation Evidence

- command: `scripts/verify-agentic-infra core`
  - result: exit 0 — 16 groups PASS, 0 FAIL (`workflow-contract-coverage-smoke`
    143 s). Baseline before the change was also green, so the comparison holds.
- command: `scripts/route-context-manifest-check`
  - result: `ok (17 routes)`, exit 0.
- command: `scripts/check-fix-symlinks.sh` (read-only)
  - result: exit 0; the 5 new skills resolve to `claude/scopes/work/skills/`.
- command: pointer sweep over `employer-backend-suite/SKILL.md`
  - result: 48 note names cited, 48 resolve under `~/work/brain/{kb,ref}/`, 0 dead.
- command: `diff -r` between each imported skill and its pre-move copy
  - result: identical except the intended provenance lines.
- command: secret/identifier scan over the 5 new skills before tracking
  - result: no secret pattern; only company domains, which belong in `work`.

## Follow-up State

- Remaining risks:
  - **Unverified**: that adding `Skill` to `tools:` actually exposes the tool to
    a subagent. No installed agent declared it before, so there is no local
    precedent, and the empirical probe failed for an unrelated reason — the agent
    registry is frozen at session start (`Agent type 'skilltest-tmp' not found`
    for an agent created mid-session). Settle it by dispatching a `scout` in a
    fresh session and reading its `Skill` output line. If false, agents keep
    their current behaviour; nothing regresses.
  - The router ages with the vault. A note renamed upstream becomes a dead
    pointer with no mechanical check to catch it.
- Parking lot:
  - `plan-ready-guard.mjs` does not run on this machine: it is wired in
    `claude/settings.workflow-hooks.json`, never merged into
    `~/.claude/settings.json`. `claude/README.md:119-121` classes it as
    *optional*, so this is a choice, not a bug — worth knowing, since the
    "no writes outside READY" protection is often assumed active.
  - `scripts/lib/install-main.sh:1221-1230` bootstraps `shared/skills` only,
    while `claude/README.md:16-17` documents scope-complete behaviour. A fresh
    machine gets `work` skills only after `check-fix-symlinks.sh --fix`.
  - 30 third-party skills remain untracked in `~/.claude/skills/` (the
    `impeccable` design suite, `lean-ctx`, `frontend-design`). Reinstallable from
    source; deliberately left alone.
- Superseded docs/specs: none.
- Next links: `claude/README.md` § "Contracts and skills carry the same name on
  purpose"; `workflow/spec.md` § Routing rules (route and skill are orthogonal).
