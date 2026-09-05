# Goal — Minimiser les tokens, préserver la qualité des harness et skills

/goal Réduire autant que possible les tokens nécessaires pour accomplir correctement les tâches avec Etabli, Claude, Codex et Pi, tout en préservant ou améliorant la fiabilité, la pertinence des skills et la qualité des résultats.

Tu as carte blanche pour analyser, simplifier, restructurer, implémenter et tester les améliorations locales nécessaires. Travaille jusqu’à obtenir le meilleur résultat démontré dans les limites ci-dessous. Ne t’arrête pas après quelques descriptions raccourcies ou une première amélioration facile.

## Objectif et priorités

Optimise dans cet ordre :

1. Exactitude, respect de la demande, sécurité et réussite des tâches.
2. Fiabilité du routage, découverte des skills et accès aux capacités utiles.
3. Tokens réellement consommés pour livrer une tâche réussie.
4. Latence, coût monétaire et simplicité de maintenance.

Vise au moins 30 % de réduction des tokens par tâche réussie dans chacun des trois harness, depuis leur état actuel. C’est une cible à démontrer, jamais une raison de dégrader la qualité ou de modifier les critères. Continue au-delà si des gains crédibles restent accessibles.

## Point de départ

Travaille dans `/Volumes/Crucial/work/etabli`.

Lis les instructions applicables, `workflow/spec.md`, puis :

- `docs/harness-token-efficiency.md`
- `docs/plan/20260905-token-economy.md`

La précédente passe a prouvé des réductions de caractères et d’octets, pas une économie réelle par tâche. Pars de l’état actuel, y compris les modifications non commitées ; ne réutilise pas l’ancien état comme baseline pour compter deux fois les mêmes gains.

Fige une baseline restaurable : fichiers, configurations effectives, versions, modèles, effort choisi, catalogues complets, outils, plugins et commandes de mesure. Préserve les modifications préexistantes.

## Mesure principale

Pour chaque harness, mesure :

```text
E = total des tokens consommés par toutes les tentatives
    / nombre de tâches livrées avec succès selon un évaluateur indépendant.
```

Inclus les échecs, retries, corrections, délégations et revues nécessaires à la livraison. Un résultat tronqué, abandonné ou incorrect n’est pas une réussite.

Utilise la télémétrie réelle du fournisseur. Normalise les champs sans double comptage : entrée, cache, sortie et raisonnement peuvent se recouvrir selon le fournisseur. Compte aussi les entrées cachées dans la consommation totale et distingue leur tarif.

Publie séparément les tokens, le coût monétaire, la latence, les appels d’outils et les interventions humaines. Sépare le coût de cette campagne d’optimisation du coût opérationnel des tâches évaluées.

Des caractères, estimations ou compteurs de fournisseur factice restent des proxies. Une mesure indisponible vaut « non mesurée », jamais zéro.

## Qualité et comparaison

Avant les optimisations, constitue un corpus représentatif des usages réels : demandes simples, implémentation, diagnostic, revue, recherche de contexte, sélection de skills, invocation explicite, tâches longues et récupération après erreur.

Prévois au minimum 12 scénarios par harness :

- 6 accessibles pour développer les optimisations ;
- 6 réservés à la validation finale, scellés par un évaluateur indépendant.

Fige les consignes, critères de réussite, limites, fixtures et pondérations. Utilise des tests exécutables lorsque possible et une revue aveugle des livrables pour les critères éditoriaux ou qualitatifs.

Compare baseline et candidat dans des environnements isolés, avec trois répétitions appariées par scénario et un ordre A/B alterné. Garde les mêmes versions, modèles et conditions externes, sauf lorsqu’un changement constitue explicitement le traitement testé. Identifie les conditions de cache.

Exige :

- aucune nouvelle défaillance critique ;
- aucune régression observée de réussite ou de qualité sur le corpus ;
- conservation des capacités nécessaires, y compris celles rarement utilisées ;
- vérification des déclencheurs positifs et négatifs des skills modifiés ;
- conservation des permissions et des choix explicites de l’utilisateur.

Les répétitions ne remplacent pas la diversité des scénarios. Indique la dispersion, les limites du corpus et les résultats inconclusifs. Une absence de régression observée ne prouve pas une équivalence universelle.

Ne consulte le jeu réservé qu’après avoir sélectionné et figé le candidat final. Une correction guidée par ses résultats exige une nouvelle validation indépendante.

## Liberté d’implémentation

Explore toutes les sources de gaspillage étayées par les traces :

- instructions injectées systématiquement et doublons ;
- catalogues, descriptions, découverte et chargement des skills ;
- schémas d’outils, MCP, plugins et chargement à la demande ;
- lectures répétées, sorties inutiles et recherche trop large ;
- mémoire, récupération ciblée et compaction ;
- routage, délégation, transmissions et duplication des revues ;
- boucles de correction, reprises et erreurs évitables.

Tu peux remplacer une architecture, fusionner des mécanismes ou supprimer une couche si les preuves montrent une amélioration. Privilégie les possibilités natives.

Ne gagne pas en masquant silencieusement une capacité, en raccourcissant les livrables nécessaires, en affaiblissant les tests ou en reportant le travail sur l’utilisateur. Ne réduis pas un effort de raisonnement explicitement sélectionné.

## Boucle d’optimisation

Utilise le workflow Etabli avec un seul `PLAN.md`, READY avant implémentation, et un journal :

`.workflow/token-quality-optimum/events.jsonl`

Pour chaque candidat :

1. Nomme le gaspillage observé, son mécanisme et le gain attendu.
2. Réalise le plus petit changement permettant de tester cette hypothèse.
3. Compare au meilleur état validé sur le jeu de développement.
4. Conserve seulement les changements dont le compromis qualité/consommation est démontré.
5. Rejette ou annule proprement les autres, sans toucher aux modifications étrangères.

Évalue chaque harness séparément : un gain Pi ne compense pas une régression Codex. Mesure aussi le comportement des changements combinés.

Applique cette discipline à ton propre travail : lectures ciblées, contexte borné, réutilisation des preuves et délégation seulement lorsqu’elle apporte une valeur nette. Réutilise les outils d’évaluation existants avant d’en construire.

## Budget et arrêt

Plafonds de cette campagne : **8 heures, 24 hypothèses et 50 USD d’appels additionnels mesurables**, au premier plafond atteint. N’augmente pas ces plafonds automatiquement.

Mise à jour utilisateur du 5 septembre 2026 : le coût des essais GLM-5.3 ne doit
plus bloquer l'exécution, l'utilisateur disposant d'un usage quasi illimité.
Ces essais sont exemptés du plafond monétaire ; leurs tokens restent mesurés
pour comparer les résultats. Cette consigne ne modifie pas les autres modèles,
le plafond de temps ou les exigences de qualité.

À la reprise, les huit heures sont comptées comme temps de travail effectif
depuis le compteur du goal, hors période où il était bloqué. Le temps déjà
consommé reste déduit ; aucune nouvelle enveloppe de huit heures n'est créée.

Commence par un petit pilote pour estimer le coût du protocole complet. Réserve au moins 30 % des moyens à la validation finale ; ajuste l’exploration pour financer cette validation. Si la matrice ne tient pas dans le budget, signale-le sans réduire discrètement les exigences.

Arrête une piste après deux hypothèses réfutées ou trois échecs identiques. Réoriente l’exploration vers une autre source de gaspillage.

Arrête la recherche lorsque les pistes prioritaires ont été examinées et que trois candidats successifs n’apportent aucun gain supérieur au bruit mesuré, avec un seuil minimal pratique de 2 %. Ce plateau concerne le jeu de développement, pas le jeu réservé.

À l’épuisement du budget, conserve le meilleur état validé et fournis un bilan PARTIAL si l’objectif ou les preuves restent incomplets. Ne présente jamais un plafond atteint comme un objectif atteint.

## Validation et livraison

Exécute les contrôles pertinents du dépôt, les régressions nécessaires, une revue fraîche Logic/Spec et la contre-revue indépendante exigée par le risque. Corrige les findings acceptés et renouvelle les vérifications affectées.

Livre :

- les améliorations effectivement appliquées ;
- les résultats baseline/intermédiaire/final par harness ;
- les économies réelles par tâche réussie et les résultats de qualité ;
- les candidats rejetés et leurs preuves ;
- le coût de la campagne, les limites et les risques restants ;
- les commandes de reproduction et de retour arrière ;
- l’archive du plan et le journal validé.

Distingue VERIFIED, PARTIAL, INCONCLUSIVE et NO_OP. Ne revendique ni minimum universel ni qualité optimale sans limite de périmètre.

Les changements locaux et essais dans les plafonds sont autorisés. Prépare les éventuelles publications pour revue, mais ne pousse, ne déploie et ne modifie aucun service de production sans autorisation explicite.
