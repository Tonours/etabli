/goal

Traite jusqu’au bout les huit actions de l’audit Claude Code pour rendre notre configuration plus fiable et maximiser le travail correctement terminé avec notre abonnement. Planifie, implémente, vérifie et mesure ; ne t’arrête pas à des recommandations.

## Sources et environnement

- Dépôt propriétaire : Etabli. Réutilise le worktree `/Users/tonours/.codex/worktrees/claude-efficiency-audit/etabli`. S’il n’est plus disponible, prépare un worktree isolé après vérification de l’état Git, sans déplacer ni écraser les changements existants.
- Source principale : `docs/research/20261002-claude-code-configuration-efficiency-audit.md` et les cinq JSON de `docs/research/claude-efficiency-20261002/`. Actualise uniquement les faits nécessaires qui ont changé depuis l’audit.
- Surfaces : code et documentation Claude dans Etabli, lancement local, configuration locale effectivement utilisée et configuration/conversations de `ssh macbook-work`. Chat et livrables en français ; code, commandes et commits en anglais.
- Lis les instructions du dépôt et le contrat mémoire applicable. Réutilise les lanceurs, résolveurs de vault, cockpit, mesures natives et harnesses existants avant d’ajouter un nouvel outil.

## Workflow et autonomie

Utilise la route `plan-implement`. Inspecte les sources avant de rédiger un seul `PLAN.md`. Trace les huit exigences, les fichiers concernés, les risques, les étapes, les résultats attendus et les preuves. Fais challenger le plan selon le contrat Etabli et passe à `Status: READY` avant toute implémentation. Respecte ensuite le check-freeze.

Le parent reste seul écrivain. Utilise uniquement les délégations de lecture/review nécessaires au contrat, sans équipe persistante. Enregistre baseline, décisions, mutations, vérifications, résultats expérimentaux et handoffs dans `.workflow/claude-efficiency-rollout/events.jsonl` avec les outils du dépôt. Préserve les preuves d’audit déjà présentes et tous les changements étrangers à cette tâche.

Lors de l’exécution de ce goal, les modifications versionables et les changements réversibles de configuration locale nécessaires à ces huit actions sont autorisés. Prépare leurs sauvegardes, diffs et rollback avant application, puis contrôle le résultat. Avance entre les lots sans demander de validation pour chaque choix d’implémentation réversible. Lorsqu’un checkpoint est nécessaire, termine d’abord les travaux indépendants et présente un résultat concret : diff, fichiers, cible, sauvegarde, rollback et validations. Une attente de réponse n’est pas une approbation.

## Huit exigences à traiter

1. **Corriger le profil lean.** Conserve les capacités de navigation utiles, dont le LSP TypeScript. Sélectionne le vault selon le dépôt avec le mécanisme canonique : Etabli → obvault, ForestAdmin → brain. Corrige le comportement et l’aide de `--no-strict-mcp`, y compris les interactions avec les MCP natifs. Vérifie le rendu temporaire, ses permissions et son nettoyage.

2. **Fiabiliser les lancements.** Identifie le CLI, sa version, le store et les points d’entrée réellement utilisés sur chaque machine, y compris Herdr et les appels non interactifs. Rends les choix explicites et vérifiables. Prépare une entrée quotidienne et une entrée pour les tâches difficiles en réutilisant les scripts existants. Préserve les flags explicites, les préférences par machine et les rôles des agents ; ne fusionne pas les stores. Vérifie le modèle et l’effort effectifs, pas seulement les settings sauvegardés.

3. **Mettre les teams en opt-in.** Pour le lancement quotidien local, désactive l’opt-in expérimental actuellement activé, tout en conservant les sous-agents ordinaires et une activation explicite des teams. Vérifie le comportement des agents nommés avec la version utilisée. N’impose pas un modèle unique aux agents et ne réduis pas arbitrairement leurs limites de tours.

4. **Rendre l’usage visible.** Complète le cockpit `/etabli` ou la statusline existante avec modèle, effort, contexte, compteurs de cache et quota natif 5h/7j lorsqu’ils sont disponibles. Distingue données du parent et des sous-agents, champs absents et valeurs nulles. Une donnée absente doit afficher « inconnu ». L’affichage ne doit pas ajouter d’appel d’inférence ni de lecture de credentials.

5. **Séparer les travaux indépendants.** Intègre au workflow existant une nouvelle session pour un nouveau travail et une reprise ciblée pour la continuité. Réutilise PLAN/ledger et un court handoff contenant objectif, état, fichiers, preuves et prochaine étape. Conserve ou compacte une conversation lorsque cela sert le même travail. Aucun reset automatique ni seuil de contexte ne doit interrompre une tâche en cours ou perdre son état.

6. **Cibler les lectures et recherches.** Favorise recherche de symboles, plages utiles, logs/diffs ciblés et résultats de ticket/documentation réutilisables dans une même tâche. Rafraîchis après changement pertinent et respecte les droits d’accès. Préserve les preuves complètes accessibles, les codes de sortie et les erreurs. Vérifie RTK et les wrappers avant de nettoyer les éléments historiques ; les usages lean-ctx distants observés ne doivent pas être supprimés par analogie avec la machine locale.

7. **Réorganiser les instructions héritées de macbook-work.** Examine le contenu et le graphe d’imports de `~/work/CLAUDE.md`, puis prépare une répartition entre règles communes indispensables, règles propres aux projets, règles conditionnelles avec `paths` et skills invocables. Préserve les exigences de sécurité, de qualité et les règles métier. Vérifie que les instructions déplacées restent disponibles au bon moment et que les règles conditionnelles ne sont pas réimportées globalement. Déplacer du texte entre fichiers toujours chargés n’est pas une réduction de contexte.

8. **Attribuer et optimiser les plugins.** Mesure les surfaces et usages effectifs avec `/context`, `/usage` et les metadata appropriées. Distingue plugins installés, activés et réellement chargés, ainsi que leurs skills/hooks/MCP. Prépare des activations par projet ou à la demande pour les capacités occasionnelles. Teste chaque changement avant de le retenir ; ne désactive pas aveuglément les onze plugins de macbook-work ni un LSP utile.

## Mesure de l’efficacité

Avant les changements, fige une baseline par machine : révision, version, points d’entrée, provider/mode d’authentification identifié sans secrets, modèle, effort, imports, plugins, MCP et critères de réussite. Garde Sonnet 5.5/Opus 5.5 `low` sur macbook-work comme préférence de référence ; un changement demande une comparaison concluante.

Réutilise `scripts/claude-agent-benchmark`, `scripts/claude-token-budget` ou `scripts/harness-token-eval` selon le parcours applicable. Commence par les fixtures et dry-runs. Sélectionne six tâches vérifiables couvrant recherche ciblée, correction, implémentation, review, reprise et usage d’un outil de travail. Sépare cas de travail et cas personnels ; conserve des cas jamais utilisés pour ajuster les candidats. Aucun envoi de contenu professionnel vers un autre provider/compte.

Compare une baseline et un candidat appariés, avec trois répétitions : six tâches × deux configurations × trois répétitions = 36 missions comparatives. Réserve jusqu’à six invocations auxiliaires séparées, soit un plafond total de 42 invocations Claude initiant une inférence et 120 minutes pour la campagne live. Une invocation est une mission distincte du CLI/harness ; ses requêtes internes et sous-agents entrent dans les mesures et la durée, sans devenir de nouvelles missions. Les retries et échecs consomment des slots ; les commandes sans inférence, fixtures et dry-runs n’en consomment pas. Fige cette allocation avant READY et marque les cellules non jouées comme telles si le plafond empêche les trois répétitions.

Un candidat change un seul levier expérimental ; ne compare pas un profil modifiant simultanément modèle, effort, contexte et plugins pour attribuer un gain à l’un d’eux. Si plusieurs leviers nécessitent des campagnes séparées, prépare les campagnes restantes et demande un budget supplémentaire seulement après présentation des résultats acquis.

Lors de l’exécution de ce goal, cette campagne de 42 invocations maximum est autorisée uniquement sur l’usage inclus de l’abonnement existant. Prépare le protocole reviewable, les tâches, les comptes concernés et les appels auxiliaires dans le PLAN avant READY ; toute opération provider auxiliaire lancée séparément entre dans ce plafond. Aucun achat, crédit supplémentaire, fast mode payant ni fallback vers une API facturée n’est autorisé. Si le harness disponible impose une autre facturation ou si le plafond est insuffisant, prépare les résultats et demande une autorisation supplémentaire concrète.

Mesure les livraisons acceptées, les reprises/échecs, la latence, les quatre composantes de tokens et les sous-agents. Pour l’objectif abonnement, compare le quota natif avant/après, en notant les activités concurrentes, resets et granularité. Vérifie d’abord si les deux machines utilisent le même compte ; ne somme pas leurs pourcentages de quota. N’utilise jamais les dollars API estimés ou les caractères comme équivalent de quota.

Ne retiens une optimisation que si les critères d’acceptation gelés restent satisfaits, sans régression critique ni perte de capacité nécessaire. Les tokens par livraison et les tailles de contexte restent des diagnostics. Si le quota est absent, trop grossier ou confondu par une activité concurrente, marque l’économie d’abonnement `INCONCLUSIVE` et conserve séparément les résultats techniques observés.

## Validations et checkpoints

- Tests ciblés pour les bugs corrigés, notamment MCP, sélection du vault, priorité des flags, nettoyage et champs absents de la statusline. Utilise un TMPDIR isolé pour les fixtures de profil.
- Vérifications appropriées : `scripts/claude-hooks-check`, `scripts/claude-skill-load-check`, son mode `--no-profile`, `scripts/workflow-context-budget`, `tests/claude-profile-smoke.sh`, `scripts/verify-agentic-infra core`, `git diff --check`. Exécute les tests Bun des extensions si cette surface est modifiée ; complète les checks selon les fichiers réellement touchés.
- Confirme les parcours réels après autorisation : lancement, modèle/effort, navigation LSP, mémoire du bon projet, reprise d’état et données natives. Les fixtures ne suffisent pas à valider le runtime ou une économie de quota.
- Avant application à macbook-work : sauvegardes privées, diff assaini, cible exacte, rollback testé et demande d’approbation finale. L’autorisation SSH de l’audit couvrait la lecture ; elle n’autorisait pas les mutations distantes. N’effectue pas cette application sans réponse affirmative. Continue entre-temps le code, la configuration locale et les validations indépendants de cette approbation.
- Aucun push, merge, déploiement ou écriture vers Slack/Linear/Telegram sans demande explicite supplémentaire. N’exporte pas les conversations brutes, le raisonnement privé, les identifiants de sessions ou les secrets ; garde les preuves professionnelles sensibles sur leur machine source.

## Succès, plafond et fin

Plafond du travail autonome : 6 heures de travail actif, hors attente d’approbation, et au maximum trois itérations de correction par lot. Les plafonds ne justifient jamais une déclaration de réussite. Les tokens globaux sont de la télémétrie, pas une condition d’arrêt. Arrête une hypothèse après deux échecs identiques, ou un check rouge trois fois sans nouveau diff, et documente le blocage plutôt que répéter.

Les huit exigences doivent avoir une disposition et des preuves : `implemented + verified`, optimisation évaluée puis rejetée avec baseline conservée, ou travail explicitement `pending approval` / `blocked` / `inconclusive`. Un diff préparé, une approbation manquante ou une expérience non jouée ne compte pas comme action implémentée. Termine les autres actions possibles avant le handoff.

La livraison complète exige les changements retenus implémentés et validés dans leur environnement cible, les huit dispositions justifiées, les checks appropriés verts, une review finale en contexte neuf et un rapport séparant résultats techniques et économie d’abonnement démontrée. Si une validation requise ou une application reste en attente, livre un état `PARTIAL` avec le prochain geste exact ; ne marque pas le goal terminé.

Une fois l’implémentation et les validations terminées, archive le PLAN selon le contrat du dépôt, puis nettoie uniquement son artefact racine avec l’outil prévu. Livre un tableau des huit actions, les fichiers modifiés, la baseline/candidat, les mesures avec unités, les régressions ou rollbacks, les limites, les décisions d’application et le mode d’emploi des profils. Aucun pourcentage d’économie inventé.
