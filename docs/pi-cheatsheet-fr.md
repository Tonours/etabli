# Pi Coding Agent — Cheatsheet (FR)

## Installation & démarrage

```bash
npm i -g @mariozechner/pi-coding-agent
pi
```

Authentification :

```bash
/login
# ou
export ANTHROPIC_API_KEY=...
pi
```

## Commandes interactives utiles

- `/model` : changer de modèle
- `/settings` : modifier les réglages
- `/new` : nouvelle session
- `/resume` : reprendre une session
- `/tree` : naviguer l’historique en arbre
- `/fork` : fork vers une nouvelle session
- `/compact` : compacter le contexte
- `/reload` : recharger extensions/skills/prompts
- `/name <nom>` : nommer la session
- `/export [fichier]` : export HTML
- `/share` : générer un lien partageable
- `/quit` : quitter

## Raccourcis clavier essentiels

- `Ctrl+L` : sélecteur de modèle
- `Ctrl+P` / `Shift+Ctrl+P` : cycle modèles
- `Shift+Tab` : niveau de thinking
- `Esc` : interrompre
- `Esc` x2 : ouvrir `/tree`
- `Ctrl+O` : replier/déplier les outils
- `Ctrl+T` : replier/déplier le thinking
- `Alt+Enter` : file d’attente follow-up
- `Alt+Up` : récupérer la file d’attente

## Entrées power-user

- `@fichier` : injecter un fichier
- `!commande` : exécuter bash + envoyer sortie au modèle
- `!!commande` : exécuter bash sans envoyer la sortie
- `Shift+Enter` : nouvelle ligne
- `Ctrl+V` : coller une image

## CLI rapide

```bash
pi -p "question"                 # mode print
pi --mode json "question"        # stream JSON
pi --mode rpc                     # mode RPC
pi -c                             # reprendre dernière session
pi -r                             # sélecteur de session
pi --no-session                   # session éphémère
pi --tools read,grep,find,ls      # mode lecture seule
```

## Raccourcis utiles dans ce repo

```bash
# workflow plan
/skill:plan <feature>
/skill:plan-review
/skill:plan-loop <feature>
/skill:plan-implement <feature>

# workflow agentic
/review [uncommitted|branch <base>|commit <sha>]
/handoff [path]
/scout <task>
/worker <task>
/reviewer <task>

# workflow worktree/tmux
cw new <repo> <task> [prefix]
cw open <repo> [branch|path|name]
cw ls <repo>
cw attach <repo> [branch|path|name]
cw merge <repo> [branch|path|name] --yes
cw rm <repo> [branch|path|name] --yes
cw pick <repo>          # UI légère fzf/fzf-tmux
cw-clean <repo> --yes   # nettoyage batch
```

Notes repo :
- `cw pick` est l'UI légère actuelle ; pas de commande `cw ui`
- `cw merge` et `cw rm` sont en dry-run par défaut sans `--yes`
- les worktrees vivent sous `./.worktrees/` quand `cw` est lancé depuis le repo

## Flow agentic recommandé sur ce repo

1. `scout` ou lecture directe pour comprendre la zone à modifier
2. `/skill:plan` + `/skill:plan-review` jusqu'à `PLAN.md` en `READY`
3. implémentation dans la session principale ou via `/worker <task>` si la tâche est bornée
4. `/review` ou `/skill:review` pour la vérification finale
5. `/handoff` si tu changes de contexte ou t'arrêtes en cours de route

Rôles :
- `scout` : reconnaissance read-only
- `worker` : implémentation read/write
- `reviewer` : revue read-only

## Fichiers de configuration importants

- `~/.pi/agent/settings.json` (global)
- `.pi/settings.json` (projet)
- `~/.pi/agent/auth.json` (auth)
- `~/.pi/agent/models.json` (providers/modèles custom)
- `~/.pi/agent/keybindings.json` (raccourcis)
- `~/.pi/agent/{extensions,skills,prompts,themes}/`
- `.pi/{extensions,skills,prompts,themes}/`
- `AGENTS.md` / `CLAUDE.md` (contexte)
- `.pi/SYSTEM.md` (override system prompt)

## Packages Pi

```bash
pi install npm:@scope/pkg
pi install git:github.com/user/repo@v1
pi remove npm:@scope/pkg
pi list
pi update
pi config
```

> `-l` pour installer en scope projet.

## SDK / RPC (ultra-court)

- SDK TypeScript : `createAgentSession(...)` puis `session.prompt(...)`
- RPC : `pi --mode rpc` puis commandes JSON (`prompt`, `steer`, `follow_up`, `get_state`, etc.)
