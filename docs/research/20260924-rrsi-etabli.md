# RRSI et Etabli : ce qui mérite un essai

Date : 2026-09-24. Statut : recherche et comparaison de contrats ; aucun gain
Etabli mesuré ici, aucun changement du harness proposé à la promotion.

## Question et périmètre

Le papier [RRSI, Xia et al. (2026)](https://arxiv.org/html/2609.24972v1)
justifie-t-il des changements dans la boucle d'amélioration d'Etabli ? La
comparaison porte sur la proposition, la sélection et l'évaluation des
modifications du harness. La qualité du runtime Pi/Claude/Codex en production
et le bénéfice d'un candidat concret restent **not verified**.

## Résultat du papier et limites

**Confirmed (papier).** RRSI limite le nombre de modifications indépendantes
dans une proposition, garde les résultats négatifs des essais, filtre les
modifications propres aux tâches d'entraînement, compare le score au bruit de la
baseline, exige qu'une hausse de coût soit justifiée par un gain, et suggère de
retirer les composants devenus improductifs (§3, annexe C). Sur les tâches
« agentic workspace », le score moyen hors distribution est 43,6 contre 39,7
pour le harness initial et 40,3 pour l'évolution sans régularisation. Le coût
est 2,42 millions de policy tokens par essai contre 1,56 million pour l'initial
et 3,80 millions pour l'évolution sans régularisation (tableau 2). Il serait
donc faux de présenter RRSI comme moins coûteux que le harness initial.

**Limite.** C'est un préprint v1, soumis le 21 septembre 2026. Les auteurs
précisent que le résultat dépend d'un ensemble fini de tâches, des paramètres
de régularisation et du budget de recherche ; le transfert vers d'autres
architectures et des boucles plus longues reste à tester (§6). Le résultat ne
constitue aucune mesure d'Etabli.

Deux autres travaux éclairent le choix :

- [Wang et al., *Rethinking the Evaluation of Harness Evolution for Agents*
  (2026)](https://arxiv.org/abs/2607.12227) constatent que l'évolution ne bat
  pas systématiquement des méthodes simples de recherche à budget comparable et
  généralise peu dans leurs essais. **Confirmed** pour leurs essais, pas pour
  Etabli. Il faut comparer un changement à une baseline simple, à budget de
  feedback et d'inférence identique.
- [Dwork et al., *Generalization in Adaptive Data Analysis and Holdout Reuse*
  (2015)](https://arxiv.org/abs/1506.02629) expliquent pourquoi un holdout
  consulté de façon répétée pendant la sélection devient lui aussi adaptatif.
  **Confirmed** : la séparation « held-out » ne suffit pas si son résultat
  influence les itérations.
- [Anthropic, *Quantifying infrastructure noise in agentic coding evals*
  (2026)](https://www.anthropic.com/engineering/infrastructure-noise) mesure
  jusqu'à six points de différence sur Terminal-Bench 2.0 entre configurations
  de ressources. **Confirmed** pour cette expérience : figer ressources,
  timeouts, concurrence et environnement avant de créditer le harness d'un gain.

## Correspondance avec le dépôt

| Principe | État observé dans Etabli | Verdict |
| --- | --- | --- |
| Hypothèse et édition bornées | `workflow/skills/self-improvement-loop.md:69-74` demande causes vérifiées, changements étroits et essais antérieurs. | **No change** au contrat de base. |
| Preuve négative et anti-triche | `workflow/skills/self-improvement-loop.md:88-94,124-128` journalise les rejets, refuse la récompense d'un test étroit et distingue validation adaptative et évaluation scellée. | **No change** au principe. |
| Comparateur objectif, coût et sûreté | `workflow/skills/skill-evaluation.md:9-31,54-77` fige manifeste, objectif et empreintes ; `scripts/lib/skill-eval.mjs:230-263` applique les comparaisons. Les fixtures suivies sont publiques, donc visibles par le candidat. | **Change** à envisager pour les campagnes réelles, pas pour le smoke du comparateur. |
| Mesure du bruit | `workflow/skills/skill-evaluation.md:15-20` exige des échantillons répétés pour l'efficacité/fiabilité, mais n'estime pas explicitement une bande de bruit de la baseline inchangée avant la recherche. | **Change** à essayer. |
| Coût combiné à la réussite | Le comparateur fige un seul objectif, puis protège les autres résultats. Il ne calcule pas une frontière qualité/coût ni le coût par tâche réussie ; `workflow/skills/self-improvement-loop.md:139-173` distingue à juste titre budget statique et usage mesuré. | **Change** à essayer dans les rapports d'évaluation. |
| Retrait d'un mécanisme devenu inutile | Les candidats peuvent supprimer du code, mais il n'y a pas de revue périodique mesurant l'effet d'une suppression de composant sur les mêmes tâches. | **Change** : expérimentation ciblée, sans suppression automatique. |
| Mutation autonome | `workflow/trace-self-improvement.md:110-135` borne l'observation/diagnostic et n'autorise aucune promotion automatique. | **No change** : RRSI ne justifie pas de franchir cette limite. |

Le rapport local `docs/research/20260924-skill-reliability-token-economy.md`
reste en cours dans le worktree. Ses mesures de traces et propositions sont une
source de candidats, pas une preuve causale qu'une modification inspirée de RRSI
améliorerait Etabli. Le cas Jev archivé
`docs/plan/20260921-jev-plan-implement-self-improvement.md` indique lui-même
que sa population adaptative de trois tâches n'est pas une preuve scellée de
généralisation.

## Essai recommandé, par ordre de priorité

1. **Protocole de campagne (priorité haute).** Pour un seul mécanisme et une
   seule route (par exemple le chargement de skills Pi), figer modèle, tâches,
   ressources, timeouts, évaluateur et budget. Répéter le harness inchangé avant
   toute proposition pour estimer son bruit. Comparer ensuite baseline et
   candidat sur les mêmes tâches et échantillons, avec réussite, sécurité,
   policy tokens réellement consommés, temps et coût par tâche réussie.
   Conserver une famille de tâches indépendante et scellée, consultée une fois
   après la sélection. Un résultat non comparable ou trop proche du bruit reste
   **inconclusive**.
2. **Journal des hypothèses (priorité moyenne).** Étendre les reçus de campagne
   avec `component`, hypothèse falsifiable, empreinte du diff, tâches visibles,
   delta de score/coût, décision et raison du rejet. Garder ces reçus privés ou
   agrégés selon `workflow/skills/self-improvement-loop.md:12-18`. Ce journal
   aide à choisir un essai différent quand les précédents ont échoué ; il ne
   donne aucune autorité de mutation.
3. **Essai de retrait (priorité moyenne, après mesures).** Pour un composant
   coûteux sans bénéfice constaté, comparer sa version actuelle à une version
   sans ce composant sur le protocole ci-dessus. Retirer seulement si la
   sécurité et les réussites ne régressent pas et si le coût baisse au-delà du
   bruit. Garder le rollback disponible.

Ne pas copier le calendrier cosinus ni les seuils numériques de RRSI : ils ont
été réglés pour leurs benchmarks et leur budget, pas pour Etabli. Ne pas créer
d'optimiseur récursif autonome avant qu'un pilote local complet montre un gain
sur des tâches réellement indépendantes. Ces décisions sont des **inferences**
à partir des sources et du contrat local, pas des résultats mesurés.

## Validation de cette recherche

Sources primaires : article et code des auteurs
([google-research/rrsi](https://github.com/google-research/rrsi)), articles des
autres auteurs et code/contrats locaux cités ci-dessus. Recherche documentaire
et lecture du dépôt uniquement. Aucun A/B, test de performance, appel modèle ou
publication effectués. Le worktree comportait déjà des modifications ; elles
ont été laissées intactes.
