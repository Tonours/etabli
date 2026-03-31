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

- `Ctrl+L` : sélecteur de modèle/provider
- `Ctrl+P` / `Shift+Ctrl+P` : cycle modèles
- `Ctrl+R` : lancer la review runtime (mitsupi)
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

## Contrat canonique du repo

- workflow : `workflow/spec.md`
- statuts : `workflow/statuses.md`
- review : `workflow/review-rubric.md`
- handoff : `workflow/handoff-template.md`
- profils : `profiles/README.md`
- guide profils : `docs/profiles.md`
- mémoire projet : `memory/projects/README.md`

## Raccourcis utiles dans ce repo

```bash
# workflow plan
/skill:plan <feature>
/skill:plan-review
/skill:implement
/skill:plan-loop <feature>
/skill:plan-implement <feature>

# workflow agentic
/review [uncommitted|branch <base>|commit <sha>]
/handoff [path]
/handoff-implement [path]
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
scripts/cw-mode <simple|standard|option-compare> <repo|path> "<task>"
```

Notes repo :
- `cw pick` est l'UI légère actuelle ; pas de commande `cw ui`
- `cw merge` et `cw rm` sont en dry-run par défaut sans `--yes`
- les worktrees vivent sous `./.worktrees/` quand `cw` est lancé depuis le repo
- `scripts/cw-mode` est le lanceur protocolaire : il prépare les worktrees attendus puis imprime les prochaines étapes Claude/Pi
- ajoute `--print-shell` si tu veux des variables shell réutilisables dans un alias, un wrapper tmux, ou un `eval "$(...)"`
- ajoute `--print-tmux` si tu veux un snippet léger pour te rattacher directement à la cible tmux principale
- source `scripts/cw-mode-aliases.sh` pour récupérer `cws`, `cwstd`, `cwcmp`, et `cwtmux` (ou laisse `scripts/install.sh` ajouter le sourcing dans `~/.bashrc` / `~/.zshrc`)

## OPS snapshot partagé

- Neovim exporte aussi une projection légère de tâche par worktree vers `~/.pi/status/<sanitized-cwd>.task.json`
- Neovim exporte un snapshot OPS dérivé par worktree vers `~/.pi/status/<sanitized-cwd>.ops.json`
- Pi le lit via l'extension ambient `ops-status`
- Claude peut lire le même snapshot via `claude/commands/ops-status.md`
- le snapshot OPS embarque aussi cette projection de tâche pour exposer le titre courant, l'état du plan, et la prochaine action sans recalcul coûteux
- ce snapshot est **read-only** et **display-only** : pas de recalcul OPS, pas de refresh review live implicite, pas d'écriture d'artefacts workflow
- `:OPSRefreshReview` dans Neovim reste le seul chemin coûteux explicite pour remettre à jour la review live
- si le snapshot est absent ou invalide, Pi et Claude doivent échouer proprement avec un message explicite

## Vérification locale OPS

Depuis la racine du repo :

```bash
./scripts/test-ops-local.sh
```

Le runner enchaîne :
- tests Bun ciblés OPS
- smoke Neovim OPS
- smoke Neovim review
- suite complète des extensions Pi
- `git diff --check`

La validation réelle de Claude `/ops-status` reste manuelle.

## Raccourcis review diff dans Neovim

Actions sur le hunk courant :

- `<leader>ri` : ouvrir l'inbox review Git
- `<leader>rh` : prévisualiser le hunk courant
- `<leader>ra` : annoter le hunk courant
- `<leader>rs` : choisir un statut (`new`, `accepted`, `needs-rework`, `question`, `ignore`)
- `<leader>rA` : accepter directement le hunk courant
- `<leader>rc` / `<leader>rC` : lancer Claude avec un prompt `revise` / `explain`
- `<leader>rp` / `<leader>rP` : lancer Pi avec un prompt `revise` / `explain`
- `<leader>rbc` / `<leader>rbp` : préparer le batch `needs-rework` pour Claude / Pi

Dans l'inbox Telescope :

- `<Tab>` / `<S-Tab>` : marquer plusieurs hunks
- `<CR>` : ouvrir une vue diff du hunk vivant sélectionné
- `<C-a>` : annoter le hunk sélectionné
- `<C-s>` : changer son statut
- `<C-y>` : accepter le hunk sélectionné ou la sélection multiple
- `<C-c>` / `<C-p>` : lancer Claude / Pi directement avec le diff sélectionné
- `<C-r>` : rafraîchir l'inbox
- `?` : ouvrir l'aide review en overlay ; `q` / `Esc` rouvre l'inbox

Commandes associées :

```vim
:ReviewInbox [status]
:ReviewCurrentHunk
:ReviewAnnotate
:ReviewStatus [new|accepted|needs-rework|question|ignore]
:ReviewAccept
:ReviewClaude [revise|explain]
:ReviewPi [revise|explain]
:ReviewClaudeBatch [status]
:ReviewPiBatch [status]
```

## Flow agentic recommandé sur ce repo

Référence canonique : `workflow/spec.md` + `workflow/statuses.md`

Mode opératoire quotidien : `workflow/operating-model.md`

1. `scout` ou lecture directe pour comprendre la zone à modifier
2. `/skill:plan` + `/skill:plan-review` jusqu'à `PLAN.md` en `READY`
3. `/skill:implement` dans la session principale, ou `/worker <task>` si la tâche est bornée
4. `/review` ou `/skill:review` pour la vérification finale
5. `/handoff` pour une reprise générique, ou `/handoff-implement` si tu stoppes une implémentation déjà cadrée par un `PLAN.md` `READY`

Modes d'exécution conseillés :
- simple : 1 session principale + 1 worker
- standard : 1 session principale + scout/worker/reviewer en parallèle borné
- option-compare : 1 session principale + 2-3 workers isolés par worktree pour comparer plusieurs options

Boucle zéro temps mort :
- pendant qu'un worker tourne, prépare la QA manuelle, relis la slice précédente, annote l'inbox review, ou compare une option concurrente
- n'utilise pas plusieurs workers sur la même zone sans isolation claire par worktree

Rôles :
- `scout` : reconnaissance read-only
- `worker` : implémentation read/write avec `todo` persistant, `lsp` quand dispo, et plan state quand utile ; un seul worker à la fois par défaut sauf isolation explicite
- `reviewer` : revue read-only

Profils :
- `profiles/personal/` : posture perso Pi-first
- `profiles/work/` : posture travail Claude-first
- `docs/profiles.md` : quand choisir chaque profil ; sélection encore manuelle

Protocole worker recommandé :
- `todo claim` au début si une tâche persistante existe
- `todo get` pour relire le détail exact
- `todo append` / `todo update` pendant l'exécution si besoin
- `todo close` en fin de tâche validée

## Fichiers de configuration importants

- Repo source : `pi/settings.json`, `pi/models.json`, `pi/agent/settings.json` (bootstrap par défaut)
- Repo source : `pi/{extensions,skills,themes}/`
- Installé : `~/.pi/settings.json`, `~/.pi/agent/settings.json` (local, non symlinké au repo)
- Installé : `~/.pi/agent/models.json`, `~/.pi/agent/auth.json`, `~/.pi/agent/keybindings.json`
- Installé : `~/.pi/agent/{extensions,skills,prompts,themes}/`
- Contexte : `AGENTS.md`, `pi/AGENTS.md`, `claude/README.md`

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
