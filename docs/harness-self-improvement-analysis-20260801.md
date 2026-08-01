# Analyse v2 — Self-improvement des agents et du harness (Etabli)

**Date :** 2026-08-01
**Scope :** boucle locale d'amélioration du harness et des comportements agent (routing, skills, checks), sans auto-apply.
**État :** recommandations après revue adversariale ; aucun mécanisme proposé n'est déployé par ce document.
**Sources primaires :** `workflow/skills/self-improvement-loop.md`, `workflow/events.md`, `scripts/workflow-event`, `scripts/workflow-retrospect`, `scripts/lib/project-autonomy.mjs`, `workflow/vnext/*`, et ledgers `.workflow/*`.

## Résumé exécutif

Etabli possède de bons **freins de gouvernance** : READY, check-freeze, no auto-apply, schéma de comparaison, vNext offline et contrôleur project-autonomy read-only. Mais une boucle d'apprentissage fiable a besoin de plus qu'un événement syntaxiquement valide : elle doit rattacher le changement, l'évaluateur et les résultats à des preuves observables et suffisamment indépendantes.

La principale correction de cette v2 est donc : **ne pas promouvoir la self-improvement tant que l'autorité de mutation, le ledger et l'évaluateur peuvent être auto-attestés ou optimisés directement par le candidat.**

## 1. Ce qui est déjà solide

| Invariant | Preuve locale | Label |
| --- | --- | --- |
| Contrat mine → propose → validate → reject, READY-gated | `workflow/skills/self-improvement-loop.md` | confirmed |
| Interdiction d'auto-apply par `workflow-retrospect` | `scripts/workflow-retrospect` read-only | confirmed |
| Événements typés de proposition/validation/rejet | `workflow/events.md`, `workflow-event-detail.jq` | confirmed (structure) |
| Gain held-in strict + non-régression held-out dans le schéma | `workflow/events.md`, `workflow-event-detail.jq` | confirmed (structure) |
| Grader final distinct de la fin de driver | `scripts/workflow-loop-adherence`, `tests/vnext-suite-smoke.sh` | confirmed |
| Controller project-autonomy non-executor | `workflow/project-autonomy-envelope.md` | confirmed |
| Labels de capacités et non-claim de runtime | `workflow/runtime-capabilities.json` | confirmed |

**Limite transversale :** les tableaux ci-dessus prouvent surtout le contrat et les formats, pas l'indépendance de l'évidence. Un schema pass ne rend pas une assertion vraie.

## 2. Données observées et limites du moteur actuel

| Signal | Observation actuelle | Conséquence |
| --- | --- | --- |
| Events riches | Les ledgers contiennent 1 `harness_failure_pattern`, 2 `harness_proposal`, 3 `harness_validation_completed`, 3 `harness_candidate_rejected`, contre 26 `self_improvement_candidate`. | Le mining est largement nourri de signaux génériques, pas de mécanismes causaux exploitables. |
| Recurrence | `scripts/workflow-retrospect --json` : 236 observations, **0 issue confirmée** au `min-count` par défaut. | Ne pas présenter les recommandations comme des patterns récurrents prouvés. |
| Comparaison | Un `harness_validation_completed` accepted accepte des IDs de population/candidat arbitraires et un total 1. | Gain statistiquement fragile, non lié à un manifest ni à un diff. |
| Held-out | Les cas `sealed:true` sont lisibles dans le corpus tracké. | Le corpus est figé/public, pas isolé de l'agent qui change le harness. |
| Controller | `project-autonomy` valide les déclarations de chemin/tool dans le ledger, pas les tool calls ni le diff réellement produit. | C'est un séquenceur d'obligations, pas un enforceur d'autorisation. |
| Terminal | Un ledger synthétique passe `autonomous-completed` avec preuves textuelles arbitraires. | La boucle peut apprendre d'un succès fabriqué. |

## 3. Findings adversariaux acceptés

### 3.1 Structural validity ≠ provenance

`workflow-event` vérifie les champs et l'ordre. Il ne lie pas un `file_changed` au diff Git, un `validation_run` à un process/exit observable, une review à une identité distincte, ni une archive au fichier sur disque. Une auto-attestation peut donc satisfaire le profil. Sources : `scripts/workflow-event:220-230`, `scripts/lib/workflow-event-detail.jq:210-280`.

### 3.2 Frozen public held-out ≠ sealed evaluator

`workflow/vnext/tasks.json` est versionné, et le smoke en fige le hash. C'est utile contre la dérive accidentelle, mais pas contre le leakage : le candidat peut lire les prompts et graders avant l'optimisation. Le vocabulaire doit devenir **frozen-public-held-out** tant qu'un runner/evaluator distinct ne garantit pas l'isolation.

### 3.3 `measured:true` ≠ meilleure intégrité

`outcome_metric.measured:false` est le comportement honnête lorsqu'il n'y a pas de données de tokens. Les tests project-autonomy autorisent une sortie finale déterministe non mesurée. La politique correcte est : un **grader final lié à un reçu** est requis; la couverture tokens est rapportée séparément.

### 3.4 Le contrôleur n'applique pas l'enveloppe au runtime

`allowed_files` et `allowed_tools` sont validés dans l'enveloppe et comparés aux `file_changed` déclarés, mais l'enveloppe ne reçoit pas les événements de tool_call ni une observation du worktree. Elle doit rester labellisée `proxy_supported` jusqu'à l'intégration de reçus hôte.

## 4. Priorités v2 pour une vraie boucle d'amélioration

### SI-0 — P0 : Pré-requis d'intégrité du run et de l'évidence

| | |
| --- | --- |
| **Problème** | Les échecs READY/no_progress peuvent être contournés par des mutations Bash non reconnues ; les ledgers invalides/terminés prématurément sont fail-open. |
| **Changement** | D'abord rendre l'autorité de mutation fail-closed, puis valider/attester le ledger actif avant qu'il contrôle planification, no_progress ou promotion. |
| **Pourquoi avant le reste** | Une boucle d'apprentissage sur une chronologie modifiable apprend des succès et échecs non fiables. |
| **Preuves** | `claude/hooks/workflow-router-lib.mjs`, `scripts/lib/no-progress-guard.mjs`, reproductions contrôlées documentées dans le claim check. |

### SI-1 — P0 : Rendre les candidats et leurs résultats vérifiables de bout en bout

| | |
| --- | --- |
| **Problème** | `candidate`, `editable_surfaces`, `checks` et `evidence` sont du texte ; un résultat accepted n'est pas lié au commit, diff, runner, grader ou sortie réelle. |
| **Changement** | Ajout d'un `candidate_revision`/diff hash, base SHA, config/runtime fingerprint, manifest hash, runner/grader hash et artefact/output hash produits par le host. Le validator refuse une promotion sans ces liens. |
| **Gain** | Attribution causale, reproductibilité et mémoire de rejet fiable. |
| **Preuve** | `harness_proposal`/`harness_validation_completed` dans `workflow/events.md` et `workflow-event-detail.jq` n'exigent aujourd'hui pas ces champs. |

### SI-2 — P0 : Séparer le candidat de l'évaluateur et corriger la terminologie held-out

| | |
| --- | --- |
| **Problème** | Graders et held-out vNext sont visibles et modifiables depuis le même worktree; `sealed:true` ne crée pas d'isolation. |
| **Changement** | À court terme : nommer l'état `frozen-public-held-out`, protéger les surfaces grader/population par une gate distincte et rendre toute modification du grader non comparable. À moyen terme : runner isolé, corpus rotatif/différé et évaluation indépendante. |
| **Gain** | Réduit le reward-hack et le test leakage. |
| **Limite** | Un évaluateur réellement secret/isolé nécessite une frontière de runtime hors de cette documentation. |

### SI-3 — P0 : Pré-enregistrer une décision statistique, pas seulement un gain de compteur

| | |
| --- | --- |
| **Problème** | Une comparaison 0/1 → 1/1 est accepted; le nombre de candidats et les catégories ne sont pas reliés au seuil de promotion global. |
| **Changement** | Manifest versionné de populations, minimum par catégorie, seuil d'effet, règle de non-régression, budget de comparaisons, réplication de la candidate gagnante et décision `inconclusive` si la puissance est insuffisante. |
| **Gain** | Moins de sélection opportuniste et de faux gains. |
| **Preuve** | Reproduction contrôlée : population arbitraire et total 1 passent le schéma actuel. |

### SI-4 — P1 : Rendre le terminal self-improvement diff-derived et non event-derived

| | |
| --- | --- |
| **Problème** | `autonomous-completed` ne sait pas qu'un diff touche une surface de contrôle si l'événement `file_changed` l'omet ou le déclare autrement. |
| **Changement** | Profil `self-improvement-completed` dérivé du diff réel : require `harness_proposal`, comparaison/échec explicite, receipts de validation et review fraîche pour toute surface `workflow/`, `scripts/`, `pi/extensions/`, `claude/hooks/`. |
| **Gain** | Évite le patch harness sans scorecard ou sans review indépendante. |
| **Preuve** | `scripts/workflow-event` ne lit pas le diff et les `file_changed` sont textuels. |

### SI-5 — P1 : Pipeline mining → pattern → candidate → mémoire de rejet avec ownership

| | |
| --- | --- |
| **Problème** | Peu de patterns typés ; `workflow-retrospect` mappe un `harness_failure_pattern` vers `contract_patch` et ne crée ni candidate liée au diff ni index de rejet. |
| **Changement** | Helper read-only qui propose un pattern causal puis une candidate avec owner surface, mécanisme, diff hash attendu, held-in/out et validation; index append-only des rejets et `supersedes` obligatoire pour un retry équivalent. |
| **Gain** | Le système apprend également de ses résultats négatifs sans auto-apply. |
| **Preuve** | `scripts/workflow-retrospect:230-290`; 0 récurrence confirmée actuellement. |

### SI-6 — P1 : Évaluer les skills et comportements agent comme des candidats distincts

| | |
| --- | --- |
| **Problème** | Modifier un skill/agent revient aujourd'hui à éditer un prompt, sans population spécifique, grader d'état, ni comparaison hors corpus. |
| **Changement** | Population agent-scénarios par surface (routing, tools, preuve, stop, injection), candidate skill/agent fingerprintée, checks déterministes + qualité live opt-in séparée, et promotion interdite si guards/one-writer régressent. |
| **Gain** | Aligne l'amélioration comportementale des agents avec les exigences du harness. |
| **Statut** | Proposal ; vNext couvre déjà certaines catégories, mais n'est pas une boucle dédiée aux skills. |

### SI-7 — P2 : Rollout, canary, calibration humaine et observabilité de couverture

| | |
| --- | --- |
| **Problème** | Même une candidate validée offline peut dégrader des tâches longues, la sécurité ou l'expérience; aucune politique de champion/challenger n'a été trouvée dans les surfaces auditées. |
| **Changement** | Promotion opt-in/canary, métriques par catégorie, rollback vers baseline, revue humaine échantillonnée pour calibrer le grader, et dashboard de couverture (types d'échec observés, non comparables, rejets, données manquantes). |
| **Gain** | Boucle stable après validation, pas seulement pendant l'expérience. |
| **Statut** | Proposal ; ne pas affirmer que ce rollout existe aujourd'hui. |

## 5. Ordre de dépendance

```text
SI-0 (mutation + ledger)
  → SI-1 (provenance des candidats/résultats)
  → SI-2 (évaluateur séparé ou honnêtement public)
  → SI-3 (règle statistique)
  → SI-4 (terminal diff-derived)
  → SI-5 (mining/rejets)
  → SI-6 (agents/skills)
  → SI-7 (canary/calibration)
```

Les éléments SI-5 à SI-7 n'améliorent pas la qualité réelle tant que SI-0 à SI-4 ne protègent pas la vérité des données qu'ils consomment.

## 6. Règles de comportement agent à conserver

1. Ne jamais auto-appliquer une sortie de retrospect.
2. Déclarer `unknown`, `blocked` et `proxy_supported` au lieu de les transformer en succès.
3. Ne jamais faire passer `measured:true` pour un grade de succès.
4. Ne pas compter un held-out public comme une frontière d'évaluation secrète.
5. Ne pas muter le grader/corpus avec la candidate sans reclassification non comparable et contrôle humain.
6. Garder un seul writer et qualifier honnêtement la protection tant qu'elle n'est pas une isolation runtime.
7. Ne proposer une règle mécanique qu'après une preuve répétable, une ownership claire et un test qui échoue réellement.

## 7. À ne pas faire

- Auto-apply, swarm ou optimiseur autonome hors PLAN READY.
- Promotion sur held-in seul ou sur un compteur sans seuil/replication.
- Grader éditable par l'agent évalué sans séparation ni disclosure.
- Effacer/masquer les rejets ou convertir une preuve non comparable en `accepted`.
- Prétendre que `project-autonomy` exécute, sandboxe ou observe les mutations réelles.

## Sources locales principales

- `workflow/skills/self-improvement-loop.md`
- `workflow/events.md`
- `scripts/workflow-event`, `scripts/lib/workflow-event-detail.jq`
- `scripts/workflow-retrospect`, `scripts/workflow-metrics`
- `scripts/lib/no-progress-guard.mjs`, `scripts/lib/project-autonomy.mjs`
- `workflow/project-autonomy-envelope.md`
- `workflow/vnext/population.json`, `workflow/vnext/tasks.json`, `scripts/lib/vnext-suite.mjs`
- `docs/harness-robustness-top5-claim-check-20260801.md`
