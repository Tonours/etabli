# Implemented: /ship thermo-nuclear phase + write-direct PR body; unslop vendored

## Metadata

- Archived: 2026-08-28
- Source plan: `PLAN.md` — /ship gains thermo-nuclear review phase + write-direct PR body style; unslop vendored
- Source plan SHA-256: `2feb71c875e228023745ce8665bc7dc7fe674e01413c9c256806b12c2f111ec6`
- Status: IMPLEMENTED
- Commits: `76c6565`, `a667332`, ship/test commits through the keepList bump (base `main` @ `f552497`)

## Outcome

- `pi/skills/thermo-nuclear-code-quality-review/` — the user's
  machine-local skill vendored verbatim (byte-identical, backup retained at
  /tmp), cataloged `pi 1 1 1`, added to the `local:etabli-workflow` package
  in `pi/agent/settings.json`, keepList test updated 17→18, deployed as
  managed symlinks on `~/.pi/agent/skills`, `~/.claude/skills`,
  `~/.agents/skills` (real dir replaced after identity check).
- `vendor/sources.tsv` pstack row extended with `unslop` (upstream moved
  `397c866` → `68836dd`; zero content drift on the 31 existing skills);
  cataloged `pstack 0 0 1`; skills-lock +2 entries; linked on three
  surfaces.
- `workflow/skills/ship.md`:
  - new **phase 6 — thermo-nuclear quality review** on the cumulative
    branch diff (structural bar: no regression, no missed judo, no
    file-size explosion, no spaghetti, no hacky abstraction), findings
    folded like adversary findings, `thermo_nuclear: clean |
    findings:<n>-folded | unavailable` recorded — never skipped silently;
  - **step 9 PR body** rewritten: free-text sections answer what/why/how,
    drafted with the write-direct qualities (direct, concrete, zero
    filler, honest status), then an `unslop` pass when exposed;
    `pr_body_style` recorded;
  - report (step 14) and Completion Evidence name both fields; steps
    renumbered 6→15 with zero external step-number references (verified).

## Decisions

- **write-direct qualities, not invocation**: the skill's own SKILL.md
  excludes PR-template bodies and mandates French tutoiement while
  `pr-body-contract.md` mandates English + intact template — the contract
  references the tone rules applicable within the template instead of the
  literal invocation (adversary fold F4).
- **Vendor unslop now** rather than binding the contract to a wave-3 maybe
  (fold F5).
- **Lockstep surfaces**: adding a pi_core skill requires settings.json +
  keepList test + catalog together; the consistency test caught the first
  partial state (kept green by design).

## Validation Evidence

- `scripts/verify-agentic-infra core` → 18/18 (after keepList sync)
- `bun test pi/extensions/__tests__/` → 242 pass
- `bash scripts/fix-links` → 0 unresolved · `node scripts/validate-adrs .` → ok
- Logic hunter ×2 (fresh contexts): **No findings**, GO/GO WITH NOTES,
  deciding-code tables complete; Spec hunter parent clean.
- Process lesson re-confirmed: `cmd | tail -1` in a `&&` chain swallowed a
  failing exit code (update:skills-lock) — caught by the core gate, not by
  the pipe.

## Follow-up State

- Queue from the user: (1) Matt Pocock "ask matt" skill suite — research
  and vendor; (2) wave 3 pstack — plan to READY.
- Next links: `workflow/skills/ship.md`, `docs/pstack-strategy.md`.
