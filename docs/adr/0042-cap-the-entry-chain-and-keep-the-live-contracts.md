---
status: accepted
date: 2026-11-04
tags: [workflow, simplification, checks]
affected_components: [workflow/spec.md, workflow/runtime/agentic-infra-checks.tsv, tests/entry-chain-budget-smoke.sh, GLOSSARY.md]
---

# Cap the entry chain and keep the live contracts

A 60-day transcript census on this machine (9 923 session files across
`~/.claude/projects`, `~/.pi/agent/sessions`, `~/.codex/sessions` and
`~/.local/share/muse/sessions`) and on macbook-work over ssh (9 283 files,
counts only, no content copied) inventoried references to `workflow/*.md`:
105 777 mentions locally, 181 767 on macbook-work. Every tracked
`workflow/*.md` carries at least 182 summed mentions; `workflow/spec.md`
carries 48 778 and `workflow/contract-details.md` 10 394.

These counts are a reference inventory, not evidence of effective reads:
injected prompts repeat the file lists, so mentions overcount opens. They
prove only that no tracked workflow contract is dead on either machine. On
that evidence, three proposed cuts are deferred, not refuted: deleting
`workflow/contract-details.md` (also pinned by the scaffold smoke), inlining
`workflow/skills/*.md` into the `SKILL.md` shims (the shims are 12-26 lines,
and the one long shim, `adversary` at 83 lines, carries runner binding absent
from the shared contract), and slimming `scripts/deploy-workflow` to a
pointer (macbook-work repos read their local scaffold copies; that migration
needs its own plan).

What ships instead is a cap on growth. The entry chain (`AGENTS.md`,
`workflow/spec.md`, `workflow/agent-rules.md`, `workflow/contract-details.md`)
grew from 112 lines on 2026-03-21 to 616 on 2026-08-30 before being
hand-trimmed to 412. ADR-0035 removed the former context-budget meta-checks;
the measured growth incident after that removal is the new evidence for this
narrower form: one `wc -l` smoke in the core group
(`tests/entry-chain-budget-smoke.sh`, cap 420) that self-tests its over-cap
failure. `workflow/skills/` stays out of the cap because it loads per route,
on demand.

`workflow/spec.md` also gains one rule: editorial edits under `workflow/`
that change no route, gate, or obligation are small tier (`answer` route,
self-review, core checks). Changes to a route, gate, or obligation stay
contractual, as `workflow/skills/implementation-loop.md` already requires.

## Consequences

- Raising the cap is a same-diff edit in the smoke, with the reason recorded
  in that run; the cap forces the conversation, it does not forbid growth.
- The deferred cuts stay available. A future census that can distinguish
  effective reads from injected mentions may justify them. On the review
  date, rerun the census; delete the cap if it never fired and the chain
  did not grow.
- Review date: 2027-01-04.
