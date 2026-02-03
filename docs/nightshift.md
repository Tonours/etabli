# Night Shift (Local Runner)

`scripts/nightshift` est un runner local fait pour bosser pendant que tu dors:
- tu prepares 1-3 taches avant de quitter le bureau
- la machine execute (LLM ou pas) dans des worktrees
- ca fait `commit + push` (pas de PR, pas de merge)

## Installation

Si tu as installe opencode via `scripts/install.sh`, tu dois avoir `nightshift` dans ton PATH.

## Routine

Prep (vers 17:00-17:30):
- `nightshift init`
- edite `~/.local/state/nightshift/tasks.md`
- `nightshift run --dry-run` pour valider le parsing

Avant de partir (19:30 ou quand tu veux):
- `nightshift run`

Le matin:
- `nightshift status`

## Format des taches

Chaque tache est un bloc:

```md
## TASK fix-login-redirect
repo: my-repo
base: main
branch: night/fix-login-redirect
engine: codex
verify:
- bun test
- bun run lint
prompt:
Fix the login redirect loop.

Context:
- Users on /app are redirected back to /login even after auth.

DoD:
- tests pass
- no new lints
- minimal diff
ENDPROMPT
```

Champs:
- `repo:` nom d'un repo sous `$CLAUDE_PROJECT_ROOT` (par defaut `~/projects`)
- `path:` chemin absolu vers le repo (override `repo:`)
- `base:` branche de base (defaut `main`)
- `branch:` branche cible (defaut `night/<id>`)
- `engine:` `codex` (defaut) | `claude` | `none`
- `verify:` liste de commandes a executer apres l'implementation (facultatif mais recommande)
- `prompt:` bloc multi-ligne termine par `ENDPROMPT`

## Worktrees / branches

Pour chaque tache:
- un worktree est cree/reutilise sous `$CLAUDE_WORKTREE_ROOT` (defaut: `~/projects/worktrees`)
- la branche est creee si besoin et push a la fin

## Engines

### engine: codex

Utilise `codex exec --full-auto` dans le worktree.

### engine: claude

Utilise Claude Code en mode non-interactif (`claude -p`) avec bypass permissions (workstation only).

### engine: none

Ne lance pas de LLM. Utile si tu veux juste pre-creer worktree+branche.

## Gardes-fous / limitations

- pas de PR
- pas de merge
- pas de browser
- bruit faible: logs dans `~/.local/state/nightshift/logs/`

## Troubleshooting

- verifier que la machine ne se met pas en veille (macOS: Energy/Battery settings)
- verifier `nightshift list` et `nightshift run --dry-run`
- lire le log: `~/.local/state/nightshift/logs/<task>-<timestamp>.log`

