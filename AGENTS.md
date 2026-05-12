# AGENTS.md — etabli (dotfiles repo)

## Architecture
- `pi/extensions/` — Pi extensions (TypeScript, auto-loaded from ~/.pi/agent/extensions/)
- `pi/extensions/lib/` — Shared utilities
- `pi/extensions/__tests__/` — Extension tests
- `pi/agent/settings.json` — Pi agent settings (packages, model, theme)
- `pi/settings.json` — Pi root settings (theme, editor)
- `pi/models.json` — Custom model definitions
- `pi/skills/` — Pi skills (SKILL.md)
- `pi/themes/` — Custom themes (JSON)
- `scripts/` — Install & dev scripts (Bash)

## Extension conventions
- Un fichier = une extension dans `pi/extensions/`
- Helpers dans `pi/extensions/lib/`
- Auto-loaded depuis `~/.pi/agent/extensions/` (symlinked)
- Packages externes dans `pi/agent/settings.json`
- Guardrails : filter-output (redaction), block-google-providers (provider policy)
- damage-control désactivé intentionnellement.

## Symlink layout (~/.pi/)
- `~/.pi/agent/extensions/` → `pi/extensions/` (auto-loaded)
- `~/.pi/agent/settings.json` stays local (bootstrapped from `pi/agent/settings.json`)
- `~/.pi/agent/models.json` → `pi/models.json`
- `~/.pi/agent/AGENTS.md` → `pi/AGENTS.md`
- `~/.pi/settings.json` → `pi/settings.json`
- `~/.pi/themes/` → `pi/themes/`
- `pi/extensions/node_modules/` → `~/.pi/npm/node_modules/` (install.sh)
- Ne PAS créer `~/.pi/extensions/` — conflit double-chargement

## Style
- FR communication, EN code. Direct. No hedge. Pas de filler praise. Moins assistant, plus opérateur.
- Si je me trompe, dis-le. Si d'accord, agis — ne performe pas l'accord.
- Challenge mes propositions. Pushback concret.
- Valide quand plus aucune objection substantielle.
- Ne pas blender les registres : chat direct ≠ email formel.

## Cognition
- Charge cognitive = contrainte first-class. ADHD-compatible : visibles, légers, reprise facile.
- Preuve d'abord : repo state, logs, artefacts. Pas de certitude sans preuve.
- Petits pas réversibles. Fermer les boucles. Nommer la prochaine action.
- Un seul défaut recommandé quand les options sont proches.

## Code
- YAGNI, KISS, DRY. TypeScript strict, no `any`. ES modules. Functions < 50 lines, files < 300 lines.
- Composition over inheritance. Explicit errors.

## Tickets
- `workflow/ticket-template.md`. Un ticket = un comportement = un PR.
- User story + contexte + acceptance criteria vérifiables. Lisible humain + LLM.

## Testing
- `bun test pi/extensions/__tests__/`

## Commit
- `feat|fix|refactor|test|docs|chore(scope): description` — atomique, un par fix.
