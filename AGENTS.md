# AGENTS.md — etabli (dotfiles repo)

## Architecture
- `pi/extensions/` — Pi extensions (TypeScript, auto-loaded from ~/.pi/agent/extensions/)
- `pi/extensions/lib/` — Shared utilities between extensions
- `pi/extensions/__tests__/` — Extension-level tests
- `pi/agent/settings.json` — Pi agent settings (packages, model, theme)
- `pi/settings.json` — Pi root settings (theme, editor)
- `pi/models.json` — Custom model definitions
- `pi/skills/` — Pi skills (Markdown SKILL.md)
- `pi/themes/` — Custom themes (JSON)
- `scripts/` — Install & dev scripts (Bash)

## Extension conventions
- Un fichier = une extension dans `pi/extensions/`
- Helpers partagés dans `pi/extensions/lib/`
- Chargement auto depuis `~/.pi/agent/extensions/` (symlinked to `pi/extensions/`)
- Packages externes déclarés dans `pi/agent/settings.json` packages
- Guardrails par défaut : filter-output (redaction post-exécution), block-google-providers (policy provider)
- damage-control désactivé intentionnellement.

## Symlink layout (~/.pi/)
- `~/.pi/agent/extensions/` → `pi/extensions/` (auto-loaded by Pi)
- `~/.pi/agent/settings.json` stays local (bootstrapped from `pi/agent/settings.json` on install)
- `~/.pi/agent/models.json` → `pi/models.json`
- `~/.pi/agent/AGENTS.md` → `pi/AGENTS.md` (global coding preferences)
- `~/.pi/settings.json` → `pi/settings.json`
- `~/.pi/themes/` → `pi/themes/`
- `pi/extensions/node_modules/` = symlink local ignoré créé par install.sh → `~/.pi/npm/node_modules/`
- Ne PAS créer `~/.pi/extensions/` — conflit de double-chargement

## Style
- Direct. Pas de hedge, pas de "I think maybe". Pas de filler praise.
- Si je me trompe, dis-le. Si t'es d'accord, agis — ne performe pas l'accord.
- Challenge mes propositions. Pushback avec des contre-arguments concrets.
- Valide seulement quand plus aucune objection substantielle ne reste.

## Cognition
- Charge cognitive = contrainte first-class. Systèmes ADHD-compatibles : visibles, légers, faciles à reprendre.
- Preuve d'abord : repo state, logs, artefacts. Pas de certitude sans preuve.
- Petits pas réversibles. Fermer les boucles. Nommer la prochaine action.
- Un seul défaut recommandé quand les options sont proches.

## Code
- YAGNI, KISS, DRY. TypeScript strict, no `any`. ES modules. Functions < 50 lines, files < 300 lines.
- Composition over inheritance. Explicit errors.

## Tickets
- Format : `workflow/ticket-template.md`. Un ticket = un comportement = un PR.
- User story + contexte embarqué + acceptance criteria vérifiables.
- Lisible par humain ET LLM sans lookup externe.

## Testing
- Extension tests : `bun test pi/extensions/__tests__/`

## Commit
- `feat|fix|refactor|test|docs|chore(scope): description` — atomique, un par fix.

## Ne pas
- Pas de features au-delà de la demande.
- Pas de refactor de code inchangé.
- Pas de design pour le futur hypothétique.
