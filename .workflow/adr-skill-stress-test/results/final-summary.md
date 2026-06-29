# Result: ADR skill stress matrix

Latest passing run:
`.workflow/adr-skill-stress-test/results/run-20260626-204903`

Observed final result:
- Stress matrix: 7/7 passed.
- Base E2E matrix after fix: 7/7 passed.
- Failure found: S4 initially allowed a pre-existing duplicated `CLAUDE.md` ADR
  index to be normalized while writing a new ADR.
- Fix applied: `claude/skills/adr/SKILL.md` now makes pre-existing ADR/index
  validation failures a hard stop for the ADR write path.
- Narrow S4 verification after fix:
  `.workflow/adr-skill-stress-test/results/narrow-s4-20260626-204731`.

See `../final-report.md` for full commands, costs, and residual risks.
