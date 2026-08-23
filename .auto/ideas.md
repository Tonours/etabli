# Ideas backlog — simplify-etabli

Session targets all exceeded (surface −70%, skills_md −55%, verify −70%).
Remaining items are viable but marginal: each touches contract tests or the
repo's core product for a small win. Pruned of done/refuted entries
(vercel pack removed; dead-scripts hypothesis refuted; stack-suite deleted).

- **linear-* family merge (~200 lines + 2 skills)** — merge
  linear-project-setup/ticket-create/work into one skill. Touches:
  skill-surface.tsv, `pi/agent/settings.json` keepList, the hardcoded
  keepList in `pi/extensions/__tests__/settings-consistency.test.ts` (14→13),
  `workflow/spec.md` routing table, agent-quick-card, contract-details.
- **review family audit** — pr-review / review / sec-pr are distinct
  contracts (diff review vs GitHub PR flow vs security PR); verify real
  overlap before merging — may be a no-op.
- **workflow loop-docs deep merge** — top-level workflow/*.md is only 1.9k
  lines and each contract is coverage-smoke-guarded; only worth it if true
  duplication is found between implementation-loop / pr-maintenance-loop /
  recurring-run scaffolding sections.
