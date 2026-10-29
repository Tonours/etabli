# Implemented: pr-council-review reads linked pull requests

## Metadata
- Archived: 2026-10-29
- Source plan: `PLAN.md` — pr-council-review sees linked pull requests across repositories
- Source plan SHA-256: `4a2fd03f4a82d2d27110615705a82a360dfde9a30e684c3b98cec469d48eac25`
- Status: IMPLEMENTED
- Commit / branch: `88c34fc5` on `main`, based on `e282d1f2`
- Workflow initiative: none

## Outcome
- `lib.sh` `linked_prs` collects open PRs of the target's owner that ship with
  it: timeline cross-references, body references, and the ticket its body
  declares. It keeps members' and collaborators' PRs only, inspects at most 8
  and keeps 5, and pins each diff to its head SHA (at most 5000 lines). Each
  `gh` call is limited to 20 s, and any failure skips that source or PR.
- `linked-prompt.md` goes into both gate prompts. When a linked PR already
  fixes a finding, the finding is still posted at its severity, written as a
  merge dependency on that PR. Phase A only keeps one such finding when the
  validator's comment missed the linked PR.

## Context
On `ForestAdmin/forestadmin-server#8675`, the 16:56Z review posted a Should
fix asking for a front change. `ForestAdmin/forestadmin#10155` had already made
that change at 10:21Z, and the owner had to answer with the merge order by hand.

## Decisions
- Keep the finding instead of dropping it: dropping would let the watcher
  auto-approve and lose the merge order.
- Gate-only context: phase A passes get no linked diffs.
- Ticket ID comes from the body only. Branch slugs would add search noise.

## Accepted Drift
- None.

## Validation Evidence
- `bash tests/pr-review-flow-smoke.sh`: ok, with 14 linked checks. The 3 mutation probes (owner filter, open check, member check) were all killed.
- Live: #8675 finds #10155 @c69bb1c4 (3.8 s); #10155 finds #8675 @0cc59c40.
- AC-6 replay on opus, one run each: the run with the linked section names #10155 and the merge order; the control asks for a front PR; phase A only keeps one finding naming #10155. 3/3 hit.
- `scripts/verify-agentic-infra shell-docs`: 38/38.
- Plan adversary codex gpt-6.1-sol: P1 CHALLENGED (6), P2 CHALLENGED (1), P3 READY.
- Hunters zai/glm-5.3: Logic GO; Spec 3 handled; Threat GO WITH NOTES (2 accepted).
- Code-diff adversary codex gpt-6.1-sol: T1 PASS, D1 PASS.
- simplify: clean; quality: clean (1 mechanical fix); mutation: 3/3 killed.

## Follow-up State
- Delta reviews on later pushes (`pr-review-watch`) do not read linked PRs yet.
