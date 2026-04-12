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
- `/compact` : compacter le contexte
- `/reload` : recharger extensions/skills/prompts
- `/name <nom>` : nommer la session
- `/export [fichier]` : export HTML
- `/share` : générer un lien partageable
- `/quit` : quitter

## Raccourcis clavier essentiels

- `Ctrl+L` : sélecteur de modèle/provider
- `Ctrl+P` / `Shift+Ctrl+P` : cycle modèles
- `Shift+Tab` : niveau de thinking
- `Esc` : interrompre
- `Esc` x2 : ouvrir `/tree`
- `Ctrl+O` : replier/déplier les outils
- `Ctrl+T` : replier/déplier le thinking

## Entrées power-user

- `@fichier` : injecter un fichier
- `!commande` : exécuter bash + envoyer sortie au modèle
- `!!commande` : exécuter bash sans envoyer la sortie
- `Shift+Enter` : nouvelle ligne
- `Ctrl+V` : coller une image

## Contrat canonique du repo

- workflow : `workflow/spec.md`
- statuts : `workflow/statuses.md`
- review : `workflow/review-rubric.md`
- profils : `profiles/README.md`
- guide profils : `docs/profiles.md`
- mémoire projet : `memory/projects/README.md`

## Raccourcis utiles dans ce repo

```bash
/skill:plan-loop <feature>
/skill:plan-implement <feature>
/skill:implement
/skill:caveman [lite|full|ultra]
/skill:ui
/review [uncommitted|branch <base>|commit <sha>]

git status --short
git log --oneline -3
PLAN.md
```

Notes repo :

- le workflow recommandé part du repo ou cwd courant
- garde le focus sur `PLAN.md`, review, validation ciblée, et QA manuelle
- la config Pi par défaut est maintenant volontairement petite
- `rtk` reste activé pour réduire le bruit shell et le coût token

## Vérification locale workflow

Depuis la racine du repo :

```bash
./scripts/test-ops-local.sh
```

Tests utiles côté `pi/` :

```bash
bun test ./extensions/__tests__/*.test.ts
bun run test:workflow
bun run test:workflow-coverage
```

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

## Auto-Validation

Checks automatiques :

- présence de `PLAN.md`
- statut `PLAN.md`
- working tree Git
- marqueurs de conflit
- compilation TypeScript des surfaces maintenues
- gros fichiers inattendus

## Flow recommandé sur ce repo

1. lecture directe pour comprendre la zone à modifier
2. `/skill:plan-loop` jusqu'à `PLAN.md` en `READY`, ou `/skill:plan-implement` pour tout enchaîner
3. `/skill:implement` si un `PLAN.md` `READY` existe déjà
4. `/review` ou `/skill:review` pour la vérification finale

Le runtime Pi du repo reste volontairement petit :

- pas de subagents
- pas de TillDone
- pas de handoff Pi local
- pas de `plan` ou `plan-review` séparés

## Fichiers de configuration importants

- Repo source : `pi/settings.json`, `pi/models.json`, `pi/agent/settings.json`
- Repo source : `pi/{extensions,skills,themes}/`
- Installé : `~/.pi/settings.json`, `~/.pi/agent/settings.json` (local, non symlinké au repo)
- Installé : `~/.pi/agent/models.json`, `~/.pi/agent/auth.json`, `~/.pi/agent/keybindings.json`
- Installé : `~/.pi/agent/{extensions,skills,prompts,themes}/`
- Contexte : `AGENTS.md`, `pi/AGENTS.md`, `claude/README.md`
