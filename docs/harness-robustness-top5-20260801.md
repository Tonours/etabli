# Top 5 v2 — Robustesse du harness Etabli

**Date :** 2026-08-01
**Scope :** contrôles Pi + Claude, mutation, ledger, complétion et délégation.
**Méthode :** audit path-backed + reproductions contrôlées de décisions de guard ; aucune commande mutante de reproduction n'a été exécutée dans le worktree.
**Baseline :** `scripts/verify-agentic-infra core` → exit 0 dans cette session. Cette baseline ne remplace pas les tests ciblés du présent audit.

> **Statut de l'artefact :** ce document est actuellement untracked. Ses constats sont validés localement, mais ne deviennent pas une preuve CI/PR avant une demande séparée de commit/PR.

## Résultat de la revue adversariale

La version initiale identifiait correctement le multi-exec non prouvé, one-writer proxy, les complétions faibles et l'auto-emit Bash-only. Elle sous-estimait toutefois une couche plus fondamentale : les guards de mutation et de no_progress peuvent être contournés avant que ces contrôles supérieurs ne jouent leur rôle.

**Verdict de roadmap initiale : BLOCK jusqu'à correction des priorités.** Les recommandations ci-dessous remplacent le classement initial ; les idées non supprimées sont conservées dans le backlog.

## 1 — P0 : Passer d'une regex de mutation à une autorité fail-closed

| Champ | Contenu |
| --- | --- |
| **Problème confirmé** | `isMutatingBashCommand` repose sur `MUTATING_BASH_PATTERN` + redirections. Sous un PLAN DRAFT/CHALLENGED ou no_progress, des écritures via interpréteurs/outils non couverts sont traitées comme non mutantes. Les outils non normalisés ne passent pas par `Write/Edit/MultiEdit/Bash`. |
| **Preuve contrôlée** | Appels à `planMutationGuardDecision`, sans exécuter les commandes : `node -e "fs.writeFileSync"`, `python3 -c "open(...,'w')"`, `git apply`, `install` → `allow`; `echo x > x` → `deny`. Sources : `claude/hooks/workflow-router-lib.mjs:173-175,900-952,1088-1115`. |
| **Changement proposé** | Pendant DRAFT/CHALLENGED et no_progress, autoriser uniquement une allowlist de commandes prouvées read-only ; tout shell inconnu/interpréteur/outillage custom est denied avec remédiation. Introduire un registre de mutabilité pour les tools/MCP : inconnu = deny ou checkpoint explicite. |
| **Gain attendu** | Ferme les contournements directs des deux invariants les plus importants. |
| **Validation** | Corpus négatif `node`, `python`, `git apply`, `install`, redirections, alias/tool custom ; parité Pi/Claude ; régression des commandes de lecture acceptées. |
| **Limite** | Ce n'est pas un sandbox OS : un processus parent ayant déjà l'autorité filesystem reste hors de cette garantie. |

## 2 — P0 : Rendre l'état de ledger invalide bloquant, pas silencieusement ignorable

| Champ | Contenu |
| --- | --- |
| **Problème confirmé** | `parseLedgerEvents` ignore les lignes invalides et `isTerminalLedger` retourne vrai dès qu'il rencontre un `completed`/`blocked`, même avant un `no_progress` ultérieur. `findActiveLedgers` ne lie aucun ledger à la session actuelle. |
| **Preuve contrôlée** | Un `events.jsonl` corrompu, ou un ledger `{completed}` puis `{no_progress}`, laisse `planMutationGuardDecision` renvoyer `allow`. Source : `scripts/lib/no-progress-guard.mjs:20-64,147-184`. |
| **Changement proposé** | Valider le ledger v2 complet avant tout allow ; invalidité, événement hors ordre ou terminal non final → deny de mutation + chemin de recovery. Ajouter run/session/lease actif, séquence monotone et append atomique ; ne scanner les autres slugs que lorsqu'ils sont explicitement attachés. |
| **Gain attendu** | Plus de fail-open après crash, corruption, terminal prématuré ou ledger étranger ; moins de deny global involontaire. |
| **Validation** | Fixtures corruption, JSON tronqué, terminal hors ordre, double writer, horodatage inversé, multi-slug et reprise. |
| **Limite** | Hash-chain/lease détectent la dérive ; une vraie attestation cryptographique exige une identité ou un stockage hors du parent. |

## 3 — P0 : Exiger des preuves de complétion observées et liées au diff

| Champ | Contenu |
| --- | --- |
| **Problème confirmé** | Le profil `autonomous-completed` exige des événements et leur ordre, mais ne vérifie pas que leurs textes correspondent à des fichiers, une commande exécutée, une sortie de test ou un reviewer indépendant. |
| **Preuve contrôlée** | Un ledger de 12 événements avec `does-not-exist.md`, `not actually run`, evidence `self` et `measured:false` passe `workflow-event validate --profile autonomous-completed`. Sources : `scripts/workflow-event:220-230`, `scripts/lib/workflow-event-detail.jq:210-280`. |
| **Changement proposé** | Receipts issus des hooks pour diff/HEAD, commande, exit, hash de sortie, archive et reviewer; validation de ces reçus contre le worktree et les artefacts. Séparer : (a) grade final sémantique, (b) review fraîche/attestée, (c) couverture de télémétrie. |
| **Correction de l'ancienne recommandation** | Ne pas imposer `outcome_metric.measured:true` à toute complétion : le deterministic/offline peut rester `measured:false`, mais ne doit jamais servir seul de preuve de succès. |
| **Validation** | Rejeter faux chemin, sortie absente, check antérieur au dernier diff, archive absente, reviewer parent-only et reçu invalidé après mutation. |

## 4 — P1 : Gater la délégation par primitive réelle et réduire le one-writer proxy

| Champ | Contenu |
| --- | --- |
| **Problème confirmé** | `runtimeStatusFor` passe à `pending` selon `hasAgentTools`, sans capability matrix, tandis que `supports_subagents` est `unknown`. `guardPortfolioCall` ne gouverne que les rôles portfolio ; one-writer reste explicitement un protocole, pas un verrou OS. |
| **Preuves** | `pi/extensions/lib/workflow-router-runtime.ts:106-141`, `workflow/runtime-capabilities.json`, `pi/extensions/workflow-router.ts:78-192,397-429`, `tests/one-writer-portfolio-smoke.sh`. |
| **Changement proposé** | Distinguer `direct Agent`, portfolio multi-model, TaskExecute et goal state; capturer une attestation de capacité par session, puis dégrader lorsque la primitive précise est inconnue. Deny les enfants non allowlistés sur les surfaces mutantes si le runtime le permet; sinon conserver le label proxy/blocked, jamais « enforcement ». |
| **Gain attendu** | Évite de transformer un `unknown` global en confiance implicite, sans interdire abusivement une primitive réellement prouvée. |
| **Validation** | Smokes par primitive, rôle inconnu, override modèle, resume, provenance runtime et tentative de write child. |

## 5 — P1 : Étendre la télémétrie d'échec sans polluer `no_progress`

| Champ | Contenu |
| --- | --- |
| **Problème confirmé** | Claude `ledger-auto-emit` sort immédiatement si le tool n'est pas Bash; Pi ne dérive le failure qu'en branche Bash. Les échecs non-Bash n'alimentent pas le guard. |
| **Preuves** | `claude/hooks/ledger-auto-emit.mjs:23`, `pi/extensions/workflow-router.ts:431-472`, `scripts/lib/ledger-auto-emit.mjs`. |
| **Changement proposé** | Ajouter des producteurs pour runners de validation identifiés et erreurs de tool structurées, avec `source`, `execution_id`, `command_hash`, classe retryable/non-retryable et lien au dernier diff. Ne pas convertir tout tool error en validation_failed. |
| **Gain attendu** | Les boucles stoppent plus tôt sur de vrais reds sans transformer une panne réseau ou un outil de lecture en no_progress. |
| **Validation** | Positifs/négatifs Bash, test runner non-Bash, erreur provider, erreur read-only, erreurs dupliquées et recovery après nouveau diff. |

## Backlog robuste supplémentaire

| Priorité | Amélioration | Raison |
| --- | --- | --- |
| P1 | Lier `project-autonomy` aux events issus de hooks réels | Le contrôleur vérifie un ledger valide et les chemins déclarés, mais n'observe pas les véritables tool calls/diffs (`scripts/lib/project-autonomy.mjs:120-175,260-420`). |
| P1 | Receipts à append atomique + fil de séquence | `appendFileSync` sans ownership/sequence fournit une source de course et une traçabilité faible (`scripts/lib/ledger-auto-emit.mjs`). |
| P1 | Corpus adversarial de guards dans CI | Les smokes actuels prouvent surtout les chemins attendus; ajouter les contournements reproduits garantit la non-régression. |
| P2 | Politique de capability/tool surface générée | Inventorier les tools chargés et leur mutabilité évite que l'ajout d'un plugin/MCP ouvre une surface non classée. |
| P2 | Contrôle de dérive déploiement | Vérifier que les symlinks, settings et extensions déployés correspondent au contenu versionné avant de déclarer une garde active. |

## Éléments initialement top 5, conservés mais reclassés

| Élément initial | Statut v2 |
| --- | --- |
| Multi-exec fail-closed sur `supports_subagents` | Conservé dans #4, mais découplé par primitive pour ne pas confondre `Agent` direct et TaskExecute. |
| One-writer mécanique / Claude parity | Conservé dans #4 ; ne pas promettre un verrou OS si le runtime ne l'offre pas. |
| Terminal outcome mesuré + review | Reformulé dans #3 : grade et reçu réels d'abord, métriques d'usage ensuite. |
| Auto-télémétrie hors Bash | Conservé dans #5 avec taxonomie pour éviter les faux positifs. |
| Goal/Task parity Claude | Partie de #4 ; un ledger-backed goal state reste proxy tant qu'il n'est pas lié à une session/receipts. |

## Forces à préserver

- READY, check-freeze et ops-stop comme invariants de politique.
- `workflow-retrospect` read-only et absence d'auto-apply.
- Labels `confirmed | proxy_supported | blocked | unknown` et leur fraîcheur.
- `task_grader` distinct des tokens dans les métriques.
- Smokes dual-runtime,  et capability matrix déjà existants.

## Sources locales

- `claude/hooks/workflow-router-lib.mjs`
- `scripts/lib/no-progress-guard.mjs`
- `scripts/workflow-event`, `scripts/lib/workflow-event-detail.jq`
- `scripts/lib/ledger-auto-emit.mjs`
- `pi/extensions/workflow-router.ts`, `pi/extensions/lib/workflow-router-runtime.ts`
- `workflow/runtime-capabilities.json`, `workflow/events.md`
- `scripts/lib/project-autonomy.mjs`
