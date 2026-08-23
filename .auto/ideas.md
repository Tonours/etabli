# Ideas backlog — simplify-etabli

Remaining deletion/consolidation candidates, ranked by expected surface win.
Baseline after iterations 1-2: surface=31819, skills_md=263, script_lines=8054.

- **vercel-agent-skills pack (12.5k lines, 100 files)** — generic React/Next
  knowledge; user's daily stack is Ember/AdonisJS. Candidate for full removal
  (shared scope, would need smoke fixture repoint again). Biggest single
  remaining block.
- **Dead scripts pass (~8k lines)** — run `lens_diagnostics mode=full
  refreshRunners=all` + knip/dead-code over scripts/; several one-shot
  migration helpers likely orphaned.
- **linear-* family merge (~130 lines + 2 skills)** — merge
  linear-project-setup/ticket-create/work into one `linear` skill; update
  skill-surface.tsv (95->... rows), settings.json keepList test (14->13),
  contract-details/spec cross-refs.
- **review family consolidation** — pr-review / review / code-review /
  sec-pr overlap; merge to 2 skills (generic review + sec-specific).
- **workflow/*.md consolidation (5.2k lines, 63 files)** — per-loop docs
  (implementation-loop, reviewer-improvement-loop, pr-maintenance-loop,
  recurring-run) share boilerplate; single loop doc + matrix table.
