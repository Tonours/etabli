# Implemented: Essai borné TesterArmy e2e sous contrat trust — preuve croisée tri-source livrée

## Metadata
- Archived: 2026-10-06
- Source plan: `PLAN.md` — Essai borné TesterArmy e2e sous contrat trust (test scripté déterministe, scénario unique, adaptateur-result)
- Source plan SHA-256: `ebdb702446615b68ac1e0a5c2e14877e74793500fa63f9883791369515fa1efa`
- Status: IMPLEMENTED
- Commit / branch: uncommitted working tree (essai jetable ; suppression de `verification/*` et des snapshots `.workflow/project-verification/<id>/subject` planifiée à la clôture formelle)
- Workflow initiative: `.workflow/testerarmy-trial/` (T1→F2 enregistrés, F2 BLOCK documentaire) + clôture dédiée `.workflow/testerarmy-trial-close/` (T1 GO → F1 BLOCK 2 mots → FD → F2)

## Outcome
- Le parcours value→save→reload piloté par TesterArmy `e2e@0.17.0` (test scripté déterministe, zéro appel modèle, aucune connexion sortante **observée — claim non instrumentée**) est prouvé sur la fixture locale : croisée tri-source `run_status=="passed"` × `browser_value=="verified"` × `state_value=="verified"`, rapport octet-exact retenu (`raw_report_text`, sha vérifiée), classify `accept` asserté en première assertion par le checker Etabli (`/classify/verdict=="accept"`).
- 5 négatifs refusés avec signatures distinctes et observables : broken (`cli_failed`, exit 1, valeurs initiales, texte d'assertion semé), nofocus (`/checks/focus==false` seul), foreign (`pre_existing`, CLI non lancé, stdout vide), timeout (`timed_out:true`, hash stdout `cli-launched\n`, marker vu à 1078 ms du début de l'action), interruption (SIGINT parent → receipt `signal:SIGTERM`, `timed_out:false`, durée 883 ms ≪ 120 s) — chiffres de la campagne -6 sur l'arbre final.
- Checker officiel : `status: passed`, `run_id: trial-valid-6`, critères **AC-T1, AC-T2** ; oracle 16 fixtures (dont discriminante « toutes assertions vertes sauf classify ») exit 0 ; init `env -i` vert (kill authentique ×3 via `createVerificationProcesses`, 0 orphelin, GO).
- Verdict produit : **aucun chemin faux-vert identifié** par la passe F1 (arbre gelé vérifié 1054/1054 hashes).

## Context
- Runner (`scripts/lib/*`) inchangé : décision = vêtement trust pur, juge = checker Etabli, moteur = CLI externe (`run.mjs:36-44` API `recipePath`/`runId` explicites).
- `e2e` refuse `--output` hors racine projet (`INVALID_CONFIG`) : la sortie vit nécessairement dans le trial dir (snapshot), purgée par run par le drive, rapport copié octet-par-octet vers `ETABLI_RUN_DIR/e2e-out/report.json`.
- Runner conserve : receipts (hash stdout) pour action/cleanup, contenu pour result/persistence/ui (`run.mjs:277-284`) ; l'orchestrateur n'évalue QUE des artefacts réellement retenus.

## Decisions
### Orchestration par API avec runIds explicites
- Context: la CLI `scripts/project-verification` n'expose que `run --plan` (recipe fixe) ; gel des écritures dès run 1.
- Choice: orchestrateur parent importe `runProjectVerification({planPath, recipePath, runId})` + recipes variantes immuables figées avant run 1.
- Rejected options: swaps de recipe.json entre runs (écritures mid-essai) ; CLI seule (impossible).
- Rationale: zéro écriture dépôt pendant les runs, runId connu a priori (marker, gate `pack.run_id`, archives).
- Consequences: checker officiel lancé par l'orchestrateur après CHAQUE run (exit attendu par variante, `run_id` lié pour le valide) ; rapport par run persisté `orchestrator-report.json`.

### Preuve = croisée, jamais le rapport seul
- Context: le rapport e2e n'a pas d'identité native ; le hash stdout action = seul canal action retenu.
- Choice: `classify` pur partagé (adapter + oracle), prédicats figés, `/classify/verdict` en TÊTE des assertions (arrêt-premier-échec), marqueurs octets fixes (`cli-launched\n` / vide), orphelins par diff baseline/post filtré `ms-playwright` + stabilisation 5 s + contrôle positif non-vacuité.
- Rejected options: confiance au `run.status` seul ; signatures sur stdout cleanup/stderr runner (non retenus).
- Rationale: chaque refus prouvé par artefact existant ; doublons/clés invalides/tests extra refusés (fail-closed).
- Consequences: oracle 16 fixtures vertes ; fixture discriminante prouve que classify seul bloque.

## Accepted Drift
- Original plan: « outputDir jamais à côté de la config » — **impossible avec ce moteur** (`INVALID_CONFIG` hors racine projet).
  Implemented reality: sortie dans le trial dir du snapshot, purgée par le drive avant chaque spawn, rapport copié vers le run dir ; zéro pollution repo (init isolé par kill-projects).
- Original plan: `test.setTimeout(0)`, `test/`, `orchestrate.mjs`, `persistence-observe.mjs`.
  Implemented reality: `{timeout: 300000}` (0 rejeté par le moteur ; 300 s dépasse tous les budgets qui encadrent la CLI — action ≤ 120 s), `tests/`, `orchestrator.mjs`, `observe-json.mjs` réutilisé. Écarts de lettre équivalents.
- Original plan: AC-07 zéro écriture dès run 1.
  Implemented reality: cycles de calibration ont édité le code entre runs pendant T1→T2 (violations réelles détectées par les passes) ; **compensé par des campagnes complètes re-exécutées** — la campagne -3 sur l'arbre intermédiaire post-fixes T1 (`source_sha256 5c6b1c82…`, encore porteur du faux positif clavier dénoncé en T2), la campagne -6 sur l'arbre final gelé (`b8bf9a16…`, celle qui fait preuve). Seule la dernière tentative de chaque runId survit (les relances sous même runId ont écrasé les tentatives en échec, constaté T1 H2) ; l'init a été exécuté avec succès deux fois (la preuve du premier effacée par le rmSync du second) et sa ré-exécution de 08:31 a réécrit `observed.json` et `foreign-report.json` dans l'arbre après le run 1 — écriture déclarée ici comme écart AC-07 supplémentaire, sans effet sur la campagne -6 qui a tourné sur ces octets-là.
- Original plan: SIGINT envoyé au runner.
  Implemented reality: SIGINT au processus orchestrateur (handler noop local), le runner aborte et termine le groupe par SIGTERM → receipt `signal:SIGTERM`, `timed_out:false` — **conforme à la lettre du plan** (l'hypothèse d'une divergence runner `timed_out:true` sur signaux était fausse : elle provenait d'un bug d'ordonnancement local, corrigé).
- Environnement : 4 symlinks versionnés déliés pour l'inventaire du runner (`claude/skills/herdr`, `pi/skills/herdr`, `pi/skills/write-direct`, `pi/extensions/pi-mobile-bridge.ts`), autorisés par human_checkpoint, **à restaurer uniquement après l'événement `completed`** (obligation de clôture ; les restaurer avant casserait la revalidation du manifeste).
- Preuve clavier UI : **atteinte par Tab + activation Enter + POST intercepté ; la frappe elle-même n'est pas discriminée** (la valeur est pré-remplie identique après le run du CLI ; un `readonly` laisserait le check vert). Affirmation volontairement dégradée à ce que la preuve soutient.
- Latent accepté : go/no-go init tolère 1 orphelin sur 3 (majorité) alors qu'AC-04 dit tout-orphelin-échoue — 0 orphelin observé ici ; `perTestStatuses` mappés depuis le schéma pour les statuts non observés (`skipped`, `timed-out`, `interrupted`, consignés `statusesFromSchemaOnly`).

## Validation Evidence
- `scripts/project-verification-check` → `{status: passed, run_id: trial-valid-6, criteria: [AC-T1, AC-T2]}`
- `node verification/testerarmy-trial/orchestrator.mjs {broken,nofocus,foreign,timeout,interrupt,valid}` → 6× `failures: []`, `orphans: []` (campagne -6, arbre gelé, `source_sha256 b8bf9a16…` commun aux 6 packs)
- `node verification/testerarmy-trial/adapter-checks.mjs` → `{fixtures: 16, discriminating: ok, recipe_identity: ok, constants: ok}`
- `node verification/testerarmy-trial/init-run.mjs` (exécuté avec succès deux fois, la dernière à 08:31Z avant la campagne -6 — **ne pas relancer avant la clôture formelle : il réécrit `observed.json` et `foreign-report.json` dans l'arbre gelé et invaliderait le manifeste `b8bf9a16`**) → hold marker 809 ms, CLI vivante >15 s, kill ×3 `orphanRuns: 0` `verdict: go`, rapport persisté `manual-init/init-report.json`
- Preuves conservées : `.workflow/testerarmy-trial/valid/` (pack + artifacts + orchestrator-report), `negatives/<runId>/` (packs, artifacts, rapports), attestations timeout/interruption (`processSample` 4 PIDs hors baseline), `manual-init/`
- Tours de revue : T1 BLOCK → T2 BLOCK → D1 clean → F1 GO-avec-réserves → FD BLOCK documentaire (corrigé) → F2 **BLOCK documentaire** (3 constats, corrigés après la passe) → clôture dédiée `testerarmy-trial-close` : T1 GO (codex e8319af9) → F1 BLOCK (2 mots, corrigés) → FD → F2

## Follow-up State
- Remaining risks: preuve clavier non discriminante (drift déclaré) ; négatifs non rejouables a posteriori hors chemin déclaré (le checker refuse tout pack déplacé — by design) ; provenance des reviewers déclarative (opus: anthropic/claude-opus-5-5, codex: GPT-6 déclaré non attesté).
- Parking lot: si généralisation, instrumenter la discrimination clavier (vider l'input avant frappe via evaluate) ; considérer l'upstream e2e pour un output hors racine ; statuts `skipped`/`timed-out` à observer réellement.
- Superseded docs/specs: `docs/tmp/20261005-testerarmy-trust.md` (note d'origine, statut « not verified » → essai maintenant prouvé borné).
- Next links: aucun — généralisation interdite avant décision explicite post-essai.
