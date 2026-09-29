# Phase 0 — S6 handoff: herdr `agent-status-history` (dotfiles)

> **Reconstruction.** Le plan source (`PLAN.md`, Phase 0, §Slice 6) a été
> supprimé après archive sans avoir jamais été commité ; son texte verbatim est
> perdu (erratum tracé dans `.audit/phase0-fleet-trust.tsv`). Ce document
> reconstruit l'essentiel du handoff depuis le contexte de session du
> 2026-09-29. Il sert de PLAN.md seed à la session dotfiles dédiée.

## Contexte

- Livré côté etabli (branche `feat/phase0-fleet-trust`, non poussée) :
  `scripts/workflow-ship-metrics report --herdr-history <file>` consomme un
  historique de transitions d'état d'agents.
- Le consommateur attend une ligne JSON par transition :
  `{ts, host, pane_id, state_change_seq}` — `host` imposé (groupement
  host+pane ; un `pane_id` seul peut être recyclé entre hôtes),
  `state_change_seq` numérique pour l'exclusion des trous, `ts` ISO8601.
- Sémantique du lecteur : intervalles construits sur paires consécutives de la
  même (host, pane) ; trou de seq ⇒ intervalle ignoré et compté (`holes`) ;
  durée connue = somme des intervalles contigus **clippés à la fenêtre**
  [--since, --until] ; lignes invalides ⇒ état `partial`, jamais un faux zéro.

## Étape 0 — vérifier les hypothèses de payload AVANT de coder

1. Capturer un événement `pane.agent_status_changed` réel de herdr et vérifier :
   - présence et nom exact de `state_change_seq` (hypothèse non confirmée) ;
   - identité d'agent disponible (nom/model) — à journaliser si présent ;
   - unicité de `pane_id` par hôte (sinon ajouter l'hôte au path/aux lignes).
2. Si l'hypothèse est fausse : adapter le format des lignes ET, si besoin, le
   lecteur etabli (le lecteur reste la référence ; ne pas dupliquer la
   sémantique dans le plugin).

## Spécification du plugin (dotfiles)

- Nouveau plugin : `herdr/plugins/agent-status-history/` (même forme que
  `claude-relaunch/` : `plugins.json`, scripts, lib).
- Hook : `pane.agent_status_changed`.
- Écriture : append JSONL (une ligne par transition, schéma ci-dessus, `host`
  toujours rempli) vers
  `~/.local/state/herdr/plugins/etabli.agent-status-history/history.jsonl`.
- Parsing des payloads herdr : **jq uniquement, jamais grep** sur du JSON
  (précédent incident `rtk-grep` ; cf. archive etabli 20260826).
- Rotation simple acceptée (fichier daté quotidien optionnel ; le lecteur etabli
  prend un chemin unique — garder UN fichier tant que la taille le permet).
- Reader de trous : petit script listant les `state_change_seq` manquants par
  (host, pane_id) pour diagnostiquer les pertes d'événements.
- Ne pas relinker `plugins.json` global sans vérifier la convention de chargement
  actuelle de herdr (voir comment `claude-relaunch` est enregistré).

## Non-objectifs / do-not-redo

- Pas d'écriture dans etabli depuis cette session dotfiles.
- Pas de polling : historique append-only, lecture à la demande par `report`.
- Ne pas réintroduire de types d'événements métriques (leçon T2/T3, ADR-0013).
- Ne pas reconstruire le plan Phase 0 perdu : l'archive fait foi pour S1–S5.

## Critère de fin (session dotfiles)

1. Un événement réel produit une ligne valide dans `history.jsonl`.
2. `scripts/workflow-ship-metrics report --since <jour> --herdr-history
   ~/.local/state/herdr/plugins/etabli.agent-status-history/history.jsonl
   --json` (depuis etabli, lecture seule) rend `herdr` `available` avec
   `known_seconds > 0` et `holes == 0` sur une session sans perte.
3. Le reader de trous rend zéro trou sur la même fenêtre.
