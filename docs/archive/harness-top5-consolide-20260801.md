# Top 5 consolidé v2 — Robustesse du harness + self-improvement (Etabli)

**Date :** 2026-08-01
**Statut :** audit mis à jour après revue adversariale ; recommandations uniquement, aucun contrôle ci-dessous n'est encore déployé.
**Périmètre :** Pi + Claude, ledgers, évaluations , et boucle locale de self-improvement.
**Validation locale :** `scripts/verify-agentic-infra core` → exit 0 ; les cinq documents d'audit restent **untracked**, donc cette validation n'est pas encore une preuve CI/PR.

## Méthode et niveau de preuve

- **Confirmed** : source actuelle inspectée et, pour les quatre P0, reproduction contrôlée sans exécuter de commande mutante dans le worktree.
- **Historical** : artefact local existant, non rejoué dans cette passe (ex. A/B live multi-model).
- **Proposal** : amélioration recommandée, non implémentée.

La première version avait correctement identifié les fausses complétions, la délégation non prouvée et le mining manuel. La revue adversariale ajoute un prérequis : ces mécanismes ne valent que si l'autorité de mutation et l'évidence du ledger résistent d'abord aux entrées malformées ou auto-attestées.

## Corrections importantes par rapport à la première version

1. **READY/no_progress n'est pas fail-closed pour Bash.** `MUTATING_BASH_PATTERN` est une denylist heuristique : `node -e`, `python3 -c`, `git apply` et `install` reçoivent `allow` en DRAFT et pendant `no_progress` dans un appel contrôlé à `planMutationGuardDecision`. Source : `claude/hooks/workflow-router-lib.mjs:173-175,900-952`.
2. **Un ledger syntaxiquement présent n'est pas nécessairement fiable.** Les lignes JSON invalides sont ignorées et n'importe quel `completed` rend le ledger terminal pour le guard. Un ledger corrompu, ou `completed` suivi de `no_progress`, laisse une mutation passer. Source : `scripts/lib/no-progress-guard.mjs:20-64,147-184`.
3. **Un terminal structurellement valide n'est pas une preuve d'exécution.** Un ledger synthétique de 12 événements avec chemins et commandes inexistants passe `workflow-event validate --profile autonomous-completed`. Source : `scripts/workflow-event:220-230`, `scripts/lib/workflow-event-detail.jq:210-280`.
4. **« sealed held-out » n'implique pas confidentialité.** Les 13 cas sealed held-out sont versionnés et lisibles dans `workflow//tasks.json`; le hash de corpus fige le contenu mais ne l'isole pas du candidat. Source : `workflow//tasks.json`, `tests/-suite-smoke.sh`.
5. **`measured:true` ne doit pas devenir un faux proxy de succès.** Les sorties déterministes/offline valides peuvent être `measured:false`; la preuve à renforcer est le grader final et ses artefacts, pas l'obligation universelle de télémétrie tokens. Source : `workflow/events.md`, `tests/project-autonomy-smoke.sh`.

## Top 5 révisé

### 1 — P0 : Rendre l'autorité de mutation réellement fail-closed

| Élément | Contenu |
| --- | --- |
| **Problème confirmé** | Les guards READY et no_progress reconnaissent une liste finie de mutations Bash ; un interpréteur ou outil non couvert est traité comme lecture. Les outils non normalisés échappent aussi au chemin `Write/Edit/MultiEdit/Bash`. |
| **Preuve** | Reproduction contrôlée : `node -e`, `python3 -c`, `git apply`, `install` → `allow` sous DRAFT et sous no_progress ; aucune commande mutante n'a été exécutée. |
| **Amélioration proposée** | Sous DRAFT/CHALLENGED ou no_progress : allowlist courte de commandes réellement read-only, sinon deny + message de remédiation. Ajouter un registre explicite de capacité/mutabilité pour tout tool/MCP ; un tool inconnu est denied ou exige une autorisation explicite. |
| **Validation attendue** | Corpus négatif de commandes/interpréteurs/redirections et d'outils custom ; mêmes résultats Pi et Claude. |
| **Limite** | Ce contrôle réduit les contournements au niveau hook ; il ne crée pas un sandbox OS contre un parent déjà autorisé à écrire. |

### 2 — P0 : Valider l'intégrité du ledger actif avant d'en faire une autorité

| Élément | Contenu |
| --- | --- |
| **Problème confirmé** | Le guard ignore les lignes invalides et considère un terminal n'importe où comme final. Un run actif peut donc être rendu inoffensif par corruption ou terminal prématuré ; inversement, un vieux ledger actif peut bloquer tout le worktree. |
| **Preuve** | Reproductions contrôlées : ledger JSON corrompu → `allow`; `completed` puis `no_progress` → `allow`. |
| **Amélioration proposée** | Valider strictement chaque ledger actif avant allow, considérer terminal uniquement s'il est le dernier événement v2 valide, et refuser la mutation si un ledger est invalide. Lier un run actif à une session/lease et utiliser un append séquencé/atomique avec chaîne de hash ou reçu hôte. |
| **Validation attendue** | Smokes corruption, terminal hors ordre, événements concurrents, multi-slug et reprise après crash. |
| **Limite** | Une chaîne de hash rend la falsification détectable ; sans stockage/identité hors du processus parent, elle ne devient pas une protection cryptographique absolue. |

### 3 — P0 : Fonder `completed` sur des reçus observés, pas sur l'auto-attestation

| Élément | Contenu |
| --- | --- |
| **Problème confirmé** | Le profil `autonomous-completed` vérifie l'ordre et la présence d'événements, pas que `file_changed`, `validation_run`, review ou archive correspondent à un diff, une commande et un reviewer réels. |
| **Preuve** | Un ledger synthétique de 12 événements passe le profil autonome avec `does-not-exist.md`, `not actually run` et une review `self`. |
| **Amélioration proposée** | Faire émettre par les hooks des reçus hôte : hash du diff/HEAD, commande + exit + hash de sortie, artefact de review, identité/runtime du reviewer. Le validator compare les reçus à l'état Git et aux artefacts, et distingue **grade sémantique** de **télémétrie d'usage**. |
| **Validation attendue** | Fixtures positives/négatives : faux chemin, faux exit, diff modifié après check, review parent-only et reçu manquant. |
| **Limite** | L'absence de télémétrie tokens reste honnête (`measured:false`) si un grader final indépendant et ses artefacts existent. |

### 4 — P0 : Protéger l'évaluation contre le Goodhart, le leakage et le faible échantillon

| Élément | Contenu |
| --- | --- |
| **Problème confirmé** | `harness_validation_completed` accepte des noms de population et de candidat arbitraires, y compris une comparaison 0/1 → 1/1 ; les cas held-out  sont publics dans le dépôt. |
| **Preuve** | Une validation accepted à populations non enregistrées et total 1 valide structurellement ; 13 cas marked sealed sont lisibles dans un fichier tracké. |
| **Amélioration proposée** | Versionner un manifest de population **et** lier chaque validation au hash du candidat/diff, du runner, du grader et des sorties. Renommer l'existant `frozen-public-held-out`; ne réserver `sealed` qu'à un évaluateur isolé. Exiger taille minimale, seuil d'effet pré-enregistré, non-régression par catégorie, réplication et budget de comparaisons. |
| **Validation attendue** | Refus d'un ID non enregistré, d'un total insuffisant, d'un grader modifié par le candidat, et d'un résultat sans reçu d'évaluation. |
| **Limite** | Un vrai held-out secret exige une frontière d'exécution distincte ; la présente analyse ne la déploie pas. |

### 5 — P1 : Attester les capacités de délégation et fermer la boucle d'apprentissage

| Élément | Contenu |
| --- | --- |
| **Problème confirmé** | `runtimeStatusFor` dépend de `hasAgentTools`, alors que `supports_subagents` reste `unknown`; `guardPortfolioCall` borne les rôles portfolio mais ne transforme pas le one-writer en isolation. Le mining dispose de peu de données riches : 1 `harness_failure_pattern`, 2 proposals, 3 validations ; `workflow-retrospect` retourne actuellement 0 récurrence confirmée au seuil par défaut. |
| **Amélioration proposée** | Distinguer `direct Agent`, portfolio multi-model, TaskExecute et goal state dans la matrice et les gates. Garder one-writer explicitement `proxy` tant qu'aucun sandbox n'est prouvé. Produire des failure patterns typés, lier candidate/diff/owner, mémoriser les rejets, puis évaluer les skills/agents sur des scénarios séparés. |
| **Validation attendue** | Smokes de capacité par primitive, corpus d'agent scenarios, and tests de duplication/rejet/mapping mechanism→action. |
| **Limite** | Le default single-agent demeure le choix sûr tant que les preuves runtime sont `unknown`; ce n'est pas une preuve que la délégation est impossible. |

## Backlog complémentaire, hors top 5

| Priorité | Sujet | Amélioration proposée | Statut de preuve |
| --- | --- | --- | --- |
| P1 | Télémétrie | Capturer les échecs de validation au-delà de Bash, mais via une taxonomie de source/commande et non tous les tool errors, afin d'éviter les faux no_progress. | Problème Bash-only confirmed ; design proposal. |
| P1 | `project-autonomy` | Transformer les `allowed_files`/`allowed_tools` déclaratifs en reçus issus des hooks ; aujourd'hui le contrôleur lit le ledger, il n'observe pas les tool calls réels. | Confirmed par `scripts/lib/project-autonomy.mjs`. |
| P1 | Negative learning | Indexer les candidats par hash de diff + mécanisme + surfaces, exiger `supersedes` pour un retry, et publier les validations nulles/non comparables. | Proposal ; rejet actuel trop textuel. |
| P2 | Rollout | Champion/challenger, canary local, seuil de rollback vers opt-in et revue humaine avant promotion large. | Proposal ; aucune boucle de rollout trouvée dans les surfaces auditées. |
| P2 | Calibration | Échantillon humain périodique pour calibrer le grader et mesurer faux positifs/faux négatifs, pas seulement les checks déterministes. | Proposal. |
| P2 | Auditabilité | Versionner/committer les rapports d'audit ou les inclure dans un artefact de PR ; les cinq documents actuels sont untracked. | Confirmed état Git ; proposal de gouvernance. |

## Séquence recommandée

1. **Autorité de mutation** et **intégrité du ledger** (1–2) avant toute autonomie supplémentaire.
2. **Reçus observés** et **intégrité de l'évaluation** (3–4) avant toute promotion self-improvement.
3. **Capacités/délégation** et **learning loop** (5), puis télémétrie classifiée et rollout contrôlé.

## À ne pas faire

- Auto-appliquer les sorties de `workflow-retrospect`.
- Transformer une fixture versionnée en « secret » par vocabulaire.
- Promouvoir un changement sur held-in seul, un total 1, ou des preuves textuelles non liées au candidat.
- Utiliser `measured:true` comme substitut d'un grader final.
- Affirmer one-writer, ledger ou review comme sécurité OS/cryptographique sans mécanisme correspondant.

## Sources locales principales

- `claude/hooks/workflow-router-lib.mjs`
- `scripts/lib/no-progress-guard.mjs`
- `scripts/workflow-event` et `scripts/lib/workflow-event-detail.jq`
- `workflow/events.md`, `workflow/runtime-capabilities.json`
- `scripts/lib/project-autonomy.mjs`
- `workflow//tasks.json`, `scripts/lib/-suite.mjs`
- `pi/extensions/lib/workflow-router-runtime.ts`, `pi/extensions/workflow-router.ts`
- `scripts/workflow-retrospect`
