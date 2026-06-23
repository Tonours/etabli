---
description: Adversarially verify a spec against the real code — every claim CONFIRMED/REFUTED/NUANCED with file:line and a certainty
argument-hint: [spec path or Slite/Linear URL] [repos to check]
allowed-tools: [Read, Glob, Grep, Bash, WebFetch, Task]
---

# Spec Verify

User request: $ARGUMENTS

Verify a spec against what the code actually does. Read-only on source. No fix,
no edit unless explicitly asked. The goal is certainty, not plausibility.

Invariants (non-negotiable):
- Every claim must be sourced with `file:line`. No assumption passes as fact.
- Two passes: a first verification pass, then an adversarial pass that tries to
  REFUTE each confirmed claim.
- Default a claim to REFUTED / NUANCED when evidence is missing or partial.

Phases:

1. Load the spec (local `.md`, or fetch the Slite/Linear URL). Extract it into a
   numbered list of atomic, checkable claims (C1, C2, …).
2. Resolve the target repos. If none given, infer from the spec's paths.
3. Fan out one subagent per claim cluster (Task tool). Each subagent locates
   evidence in the code and returns `file:line` excerpts — never a summary alone.
4. First verdict per claim: CONFIRMED / REFUTED / NUANCED, with the evidence.
5. Adversarial pass: for every CONFIRMED claim, spawn a skeptic subagent prompted
   to refute it. Downgrade to NUANCED/REFUTED if the refutation holds.
6. Output one table: `Claim | Verdict | Evidence (file:line) | Certainty %`.
7. List the spec's blind spots: claims with no code backing, and real behaviors
   the spec omits.

8. Memory (offer, don't force). If `~/work/brain/kb/` exists, offer to persist any
   CONFIRMED mechanic as a `kb/` note per that vault's `CLAUDE.md` contract:
   strict frontmatter, `sources:` with `file:line`, update the existing note
   instead of duplicating. Never persist REFUTED/NUANCED claims.

End on the table and the blind-spot list. Do not silently widen scope.
