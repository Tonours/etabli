# Claim check v2 — Robustesse & self-improvement

**Date :** 2026-08-01
**Méthode :** sources du worktree courant + reproductions de décision de guard dans des répertoires temporaires. Les reproductions n'ont jamais exécuté de commande mutante contre ce dépôt.
**Labels :** `confirmed` | `historical` | `proxy_supported` | `blocked` | `unknown` | `proposal`.

## Claims critiques ajoutés par la revue adversariale

| ID | Claim | Source / preuve actuelle | Label |
| --- | --- | --- | --- |
| A1 | READY et no_progress sont contournables par des mutations Bash non reconnues | `claude/hooks/workflow-router-lib.mjs:173-175,900-952`; appels contrôlés à `planMutationGuardDecision` : `node -e`, `python3 -c`, `git apply`, `install` → `allow`, tandis que redirection → `deny` | **confirmed** |
| A2 | Un ledger corrompu ou terminé prématurément peut désactiver le deny no_progress | `scripts/lib/no-progress-guard.mjs:20-64,147-184`; reproduction : JSON invalide → `allow`, `completed` puis `no_progress` → `allow` | **confirmed** |
| A3 | Le profil `autonomous-completed` accepte une auto-attestation structurelle | `scripts/workflow-event:220-230`, `scripts/lib/workflow-event-detail.jq:210-280`; ledger synthétique de 12 événements, faux chemin/commande/review, `validate --profile autonomous-completed` → `12 events, ok` | **confirmed** |
| A4 | Les held-out vNext marked sealed sont publics dans le worktree | `git ls-files workflow/vnext/tasks.json`; `jq` compte 13 entrées `split=held_out && sealed=true` | **confirmed** |
| A5 | Une validation harness accepted peut utiliser population/candidate arbitraires et total 1 | `workflow-event-detail.jq` accepte chaînes non vides; reproduction avec populations non enregistrées → `1 events, ok` | **confirmed** |
| A6 | `project-autonomy` est un contrôleur de ledger, pas l'enforcement des actions réelles | `scripts/lib/project-autonomy.mjs:120-175,260-420` valide déclaration/event `file_changed`; aucune ingestion de tool_call ou diff Git observé | **confirmed** |

## Claims des documents originaux, revalidés ou requalifiés

| ID | Claim | Source / preuve actuelle | Label |
| --- | --- | --- | --- |
| R1 | Multi-exec Pi devient `pending` selon `hasAgentTools`, sans capability matrix | `pi/extensions/lib/workflow-router-runtime.ts:106-141` | **confirmed** |
| R2 | `supports_subagents` est `unknown` pour Pi et Claude; Claude structured task est `blocked` | `workflow/runtime-capabilities.json` | **confirmed** |
| R3 | One-writer est documenté comme protocole, pas OS lock | `workflow/agent-quick-card.md`, `workflow/skills/multi-model-orchestration.md`, `tests/one-writer-portfolio-smoke.sh` | **confirmed** |
| R4 | Pi restreint les rôles portfolio via `guardPortfolioCall`; ce n'est pas une garde générale pour tout enfant | `pi/extensions/workflow-router.ts:78-192,302-324,397-429` | **confirmed** |
| R5 | Il n'y a pas de garde portfolio équivalente dans `claude/hooks/` | Recherche `portfolio`/`guardPortfolio` dans `claude/hooks/*.mjs` vide; `workflow/runtime-capabilities.json` | **confirmed** |
| R6 | Claude/Pi auto-émettent les failures uniquement pour Bash | `claude/hooks/ledger-auto-emit.mjs:23`; `pi/extensions/workflow-router.ts:431-472` | **confirmed** |
| R7 | `outcome_metric.measured:false` est structurellement valide | `workflow/events.md`, `workflow-event-detail.jq`; `tests/project-autonomy-smoke.sh` l'emploie dans un succès final déterministe | **confirmed** |
| R8 | `review_completed` ne contient structurellement que status + evidence | `scripts/lib/workflow-event-detail.jq:210-211` | **confirmed** |
| R9 | `workflow-retrospect` classe un `harness_failure_pattern` en `contract_patch` | `scripts/workflow-retrospect:230-290` | **confirmed** |
| R10 | Le mining actuel a peu de signaux typed et aucune récurrence confirmée | Comptage `.workflow/*/events.jsonl` : 1 pattern, 2 proposals, 3 validations; `scripts/workflow-retrospect --json` : 236 observés / 0 confirmés | **confirmed** |
| R11 | Le panel live était moins bon que baseline sur l'artefact A/B | `docs/harness-optimization-bench/live-ab-tokens-throughput.json` | **historical** — artefact lu, pas de live rerun dans cette passe |
| R12 | Pi structured task est covered par tests | `workflow/runtime-capabilities.json`, `pi/extensions/__tests__/tasks-till-done*.test.ts`; `scripts/verify-agentic-infra core` a passé | **proxy_supported** pour une session live, **confirmed** pour la suite locale |
| R13 | `scripts/verify-agentic-infra core` est vert | Commande exécutée cette session, exit 0 | **confirmed** |

## Claims explicitement non faits

| Assertion évitée | Raison |
| --- | --- |
| « Les guards ne protègent rien » | Faux : ils bloquent les chemins reconnus; la finding concerne le fail-open des chemins non reconnus. |
| « one-writer est un OS sandbox » | Aucune preuve d'isolation runtime/OS. |
| « held-out sealed est secret » | Le corpus est versionné et lisible; seul son contenu est figé. |
| « `measured:false` invalide une réussite » | Les tests déterministes/offline légitimes l'utilisent; le besoin est un grader/receipt, pas des tokens obligatoires. |
| « les P0 sont déjà corrigés » | Ce document décrit des constats et propositions, aucun patch de harness n'a été appliqué. |
| « le live multi-model est actuellement dégradé » | L'artefact est historique; aucun rerun live n'a été effectué ici. |

## Validation de l'artefact

- `scripts/verify-agentic-infra core` : **exit 0** (baseline actuelle).
- `scripts/answer-quality-check --mode repo` : à rejouer après la présente mise à jour avec les quatre autres artefacts.
- État Git : les cinq docs d'audit sont **untracked** ; leur contenu n'est pas encore validé par CI.
