---
description: "Sourced read-only audit across the Forest repos — misalignment table with file:line evidence and an adversarial pass"
argument-hint: "[topic/behavior to audit] [optional: subset of repos]"
allowed-tools: [Read, Glob, Grep, Bash, Agent]
---

# Cross-Repo Audit

User request: $ARGUMENTS

Audit one behavior across the Forest stack and surface where the repos disagree.
Read-only on source. Never code. The output is evidence, not opinion.

Default repos (override if the request narrows them):

- Front: `~/work/forestadmin-bugfixes`
- Orchestrator: `~/work/forestadmin-server`
- Executor / agent: `~/work/agent-nodejs`

Invariants (non-negotiable):

- Every finding sourced with `file:line`. No assumption, only certainty.
- After the first pass, run an adversarial pass that challenges each finding.
- Delegate breadth to subagents (Agent tool) — one per repo or per sub-question —
  and have each return `file:line` excerpts, not prose summaries.

Phases:

1. Restate the behavior under audit as concrete questions to answer per repo.
2. Fan out: one subagent per repo (or per question), each mapping how that repo
   implements the behavior, returning `file:line` evidence.
3. Cross-compare the per-repo findings and build a misalignment table:
   `Aspect | Front | Orchestrator | Executor | Aligned?`
4. Adversarial pass: spawn skeptic subagents to refute each claimed misalignment
   and each claimed alignment. Keep only what survives.
5. Report: the misalignment table first, then a short list of confirmed gaps with
   their `file:line` anchors, then open questions that code alone can't resolve.

6. Memory (offer, don't force). If `~/work/obvault/kb/` exists, offer to persist any
   confirmed mechanic as a `kb/` note per that vault's `CLAUDE.md` contract:
   strict frontmatter, `sources:` with `file:line`, update the existing note
   instead of duplicating. Only write what survived the adversarial pass.

End on the table and gaps. Do not propose fixes unless asked.
