# Tokens et qualité des harness — bilan de campagne

Statut : **PARTIAL**, 5 septembre 2026. Objectif : [goal-token-quality-optimum.md](goal-token-quality-optimum.md).

Exécution : **BLOCKED** après trois contrôles consécutifs du même obstacle. Au dernier contrôle natif, `claude auth status --json` renvoie `loggedIn=false` et `authMethod=none` ; les deux auditeurs Codex restent en erreur de quota. La provenance fournisseur Codex et la revue indépendante finale restent non prouvées. Les reprises automatiques sont arrêtées ; le bilan demeure PARTIAL et l’objectif non atteint. Aucun plafond n’est augmenté. Preuve : `.workflow/token-quality-optimum/remaining-blocker-audit.json`.

**Aucune réduction globale fiable des tokens par livraison réussie n’est démontrée sur Claude, Codex ou Pi.** Le candidat Pi H01 est rejeté et retiré. Les modifications préexistantes sont conservées. La campagne livre des instruments de mesure et des preuves, pas une optimisation opérationnelle validée.

## Résultats finaux Pi

Les **72 tentatives prévues pour Pi sont terminées et consolidées** : 12 scénarios, deux bras, trois répétitions appariées, ordre A/B alterné. Les six scénarios réservés ont été ouverts après clôture des 36 tentatives publiques, à 11:31:27 UTC. Le candidat et les oracles sont restés figés. Modèle réellement capturé : **ZAI / GLM-5.3**, raisonnement `max` côté API, correspondant à `xhigh` côté Pi.

| Population, 18 tentatives par bras | Baseline publique | H01 public | Baseline réservée | H01 réservé |
| --- | ---: | ---: | ---: | ---: |
| Tentatives entièrement mesurées | 17 | 17 | 14 | 18 |
| Livraisons réussies | 14 | 13 | 12 | 13 |
| Échecs critiques | 0 | 1 | 3 | 2 |
| Tokens connus, sous-total si incomplet | 3 620 244 | 3 075 356 | 5 000 362 | 2 554 090 |
| Total des tokens | Inconnu | Inconnu | Inconnu | 2 554 090 |
| Tokens par livraison réussie | INCONCLUSIVE | INCONCLUSIVE | INCONCLUSIVE | 196 468,46 |

Sur les 36 tentatives de chaque bras : **26 livraisons réussies et 3 échecs critiques de chaque côté**. Les sous-totaux connus valent 8 620 606 tokens baseline et 5 629 446 H01. Ils ne permettent pas de calculer une économie globale : **six tentatives restent incomplètement mesurées**. La valeur isolée H01 réservée n’est pas un gain comparatif.

H01 différait sept schémas d’outils de code. Il est inadmissible selon les exigences du goal : sur le jeu public, il introduit une erreur fonctionnelle (`-0` au lieu de `0`) et une modification interdite de `tests/check.mjs`, avec moins de livraisons réussies. Les résultats réservés ne compensent pas ces régressions. Aucun réglage n’a été ajusté à partir du jeu réservé.

Preuves dans `.workflow/token-quality-optimum/` :

- `final-v3-development-population.jsonl` et `final-v3-held_out-population.jsonl` : les 72 lignes, sans exclusion, avec usages normalisés et grades bruts.
- `final-v3-evidence-summary.json` : agrégats et limites par population.
- `final-v3-paired-results.csv` : les 36 paires, leurs tokens, réussites, erreurs critiques et durées ; les totaux inconnus sont distincts des sous-totaux connus.
- `final-v3-all-cells-closure.json` : hashes des preuves, groupes de processus absents lors du contrôle `ps`, sources effectives stables pour les 72 tentatives.
- `H01-adoption-decision.json` : décision de rejet prise sur le jeu public, avant son ouverture réservée.

## Mesure, qualité et dispersion

La métrique est `E = tokens de toutes les tentatives / livraisons réussies`. Échecs, corrections et revues restent dans le numérateur. Les entrées cachées sont incluses ; le raisonnement déjà inclus dans la sortie n’est pas ajouté une seconde fois. Les reçus parents et enfants sont rapprochés par identité de réponse et filiation de processus, sans additionner deux copies du même reçu.

Cinq tentatives ont une requête interrompue sans usage final. La sixième, `pi-h01-v3-s-8cf3a1793f2b4eea-r3-baseline`, a terminé sa livraison, mais un enfant présente une action masquée dans son historique : ses **757 305 tokens capturés** sont un sous-total, et sa couverture complète demeure INCONCLUSIVE. Les arguments masqués n’ont pas été reconstruits par lecture de secrets. Les historiques de couverture inconnue restent intacts.

Les derniers audits de couverture sont réalisés par l’agent principal, indépendant des sujets du benchmark, après arrêt des deux auditeurs Codex sur quota. Ils ne sont pas présentés comme des revues en contexte neuf. Les oracles de qualité restent les évaluateurs indépendants figés. Pour un enfant H01, les hashes lus avant formatage ont été reproduits exactement depuis les écritures/éditions natives ; les deux versions sont conservées dans `child-read-source-reconstruction/` de sa cellule.

| Pi, 36 tentatives par bras | Baseline | H01 |
| --- | ---: | ---: |
| Durée médiane de tâche, secondes | 80,82 | 79,16 |
| Étendue des durées, secondes | 34,44–600,22 | 31,67–600,21 |
| Appels d’outils du processus principal | 529 | 498 |
| Interventions humaines pendant les tâches | 0 | 0 |

Les appels d’outils des enfants ne sont pas inclus dans cette dernière métrique d’outils. Leurs tokens audités sont inclus dans les comptes fournisseur. Les durées englobent les sous-revues observées ; elles ne mesurent pas seulement la latence API. Avec trois répétitions par scénario, la dispersion ne permet pas une garantie générale de qualité ou un minimum universel.

Le cache est celui observé chez le fournisseur, sans prétendre à une expérimentation cache froid : 7 817 344 tokens d’entrée cachés connus côté baseline, 4 968 896 côté H01. Les conditions de version/modèle/effort sont figées et l’ordre alterné ; un effet du cache ne peut être isolé de cette seule population.

Deux limites des évaluateurs sont documentées :

1. `evaluator-limit-delivery.json` : le rapport historique comptait les PASS bruts, même pour une livraison interrompue. **Défaut corrigé après clôture des 72 essais** dans `scripts/lib/harness-token-usage.mjs` : le rapport exige désormais un transport terminé et respecte toute adjudication explicite de livraison. Une preuve absente ou mal formée laisse E inconclusif. Le replay public passe de 15 PASS bruts à 14 livraisons baseline, comme le bilan ; les trois autres groupes sont inchangés. Les anciens scripts sont conservés dans `frozen-evaluator/scripts/`, et les grades/reçus restent intacts. Preuve : `post-freeze-metric-fix.json`, 33/33 tests. La normalisation des événements reste identique octet pour octet ; le finaliseur historique conserve son verrou sur les sources d’origine et ne doit pas servir à prolonger cette cohorte.
2. `evaluator-limit-dev02.json` : la regex du scénario `verify` peut manquer une commande suivie d’un point-virgule. Les grades d’origine restent conservés ; ils ne prouvent pas à eux seuls une erreur de calcul. La première répétition publique comporte aussi une valeur JSON non conforme au critère figé.

## Sources effectives et isolation

Les **36 paires** ont des inventaires de fichiers effectifs identiques avant lancement : **33 128 entrées par paire**, après normalisation exclusive du chemin temporaire de la tâche. Les liens du jeu réservé ont aussi été comparés. Les sources Pi avant/après restent identiques dans chaque cellule. Ces empreintes ne prouvent pas une isolation de sécurité : processus, fichiers temporaires et évaluateurs utilisent le même compte local.

Le lot public 6 s’est arrêté après un changement de hash de configuration Codex, hors des sources Pi inchangées. La revue indépendante a autorisé seulement la suite des lots restants ; l’indicateur global faux d’origine est conservé. Aucun contenu de cette configuration n’a été lu. Preuves : `batch6-source-drift-review.json`, `batch6-resume-preflight.json`.

La recherche statique de chemins absolus `/tmp` dans les arguments racines n’a pas trouvé de chemin partagé entre deux cellules du même lot. Elle ne couvre pas les chemins dynamiques ni tous les enfants : `final-v3-scratch-isolation-review.json`.

## Claude, Codex et phases précédentes

| Harness | Éléments établis | Limite pour le goal |
| --- | --- | --- |
| Claude Code 2.1.251 | Pilote arrêté sur une session OAuth expirée | Pas de population A/B mesurée ; garde financier par requête non prouvé |
| Codex 0.153.3 | Probes locales et tests de normalisation ; quota des auditeurs épuisé | Provenance effective fournisseur/modèle et couverture complète non prouvées ; pas de population A/B réelle |
| Pi 0.84.4 | Les 72 tentatives finales ci-dessus, GLM-5.3 confirmé par reçus | H01 rejeté ; six couvertures incomplètes ; aucune économie globale revendicable |

Les faits de version et d’authentification correspondent aux observations de cette campagne, pas à une nouvelle connexion. Aucun renouvellement d’authentification ni changement de fournisseur n’a été effectué.

Le protocole complet exige **216 exécutions sur les trois harness** : les 72 Pi ne remplissent pas cette exigence. Les pilotes et anciennes phases Pi restent séparés dans `runs.jsonl`, `development-runs.jsonl` et `development-v2-runs.jsonl`. Leurs échecs et anciennes revues sans reçus restent inconnus ; aucune réussite n’a été transférée sélectivement dans la cohorte finale. L’historique détaillé du rapport est conservé dans `report-before-final-consolidation.md`.

Les réductions de caractères de la passe précédente, décrites dans [harness-token-efficiency.md](harness-token-efficiency.md), appartiennent à la baseline. Elles ne sont pas recomptées comme économies de cette campagne.

## Coût et plafonds

L’inventaire après clôture contient **959 reçus fournisseur complets**, **19 664 608 tokens connus** et **9,66803144 USD au tarif API équivalent figé**, avec huit enregistrements sans usage final complet. Source : `campaign-receipt-inventory.json`. Les appels opérationnels du benchmark figurent dans les tableaux précédents ; cet inventaire additionne aussi pilotes, phases abandonnées et contre-revues de campagne.

Ce montant n’est **ni une facture d’abonnement ni le coût complet de campagne**. Il manque notamment des anciennes consommations d’enfants et la consommation fournisseur de l’orchestration/auditeurs Codex. Le compteur du goal est une télémétrie distincte ; il n’est pas additionné à ces reçus. Les enregistrements historiques encore marqués `reserved` ne sont pas assimilés à des processus actifs ou à zéro token.

Ta consigne lève le blocage monétaire GLM-5.3, pas les exigences de mesure. Les autres plafonds restent 8 heures de travail effectif, 24 hypothèses et 50 USD pour les modèles non exemptés. L’échéance conservatrice figée est **12:48:55 UTC le 5 septembre 2026** ; elle n’a pas été prolongée. Une seule hypothèse d’optimisation, H01, a été implémentée. Aucun plateau de trois candidats successifs ni exploration exhaustive des pistes prioritaires n’est démontré.

## État livré et validation

Le retour arrière H01 est appliqué et vérifié :

- `pi/extensions/workflow-tools.ts` et `pi/extensions/__tests__/workflow-tools.test.ts` sont restaurés **octet pour octet** depuis la baseline, tout en conservant les fichiers préexistants.
- Sur les 900 fichiers initiaux, **899 sont identiques**. Le seul écart conservé est l’addendum autorisé de `docs/goal-token-quality-optimum.md` sur GLM-5.3 et le décompte du temps à la reprise.
- `scripts/harness-token-eval`, `scripts/lib/harness-token-usage.mjs` et `tests/harness-token-usage.test.mjs` restent des instruments locaux de mesure. Le rapport de livraison a été corrigé après clôture ; les autres limites exposées plus haut demeurent. Ces outils ne constituent pas une économie de tokens.
- Les octets rejetés sont archivés dans `H01-rejected-candidate/`, le patch dans `H01-rollback.patch`, les hashes/préconditions dans `H01-rollback-manifest.json` et le résultat dans `H01-rollback-result.json`.

Contrôles après retour arrière : **8/8 tests workflow-tools**, **33/33 tests de mesure après correction du rapport**, **18/18 contrôles core**, dont **262/262 tests Pi** ; typecheck Pi et `git diff --check` passent. Préservation vérifiée dans `baseline-preservation-final.json`. Simplification : retrait du seul delta de comportement H01 et de ses deux tests spécifiques ; aucun mécanisme supplémentaire ajouté au harness.

Les gardes de capture avaient aussi passé leurs validations ciblées avant le gel : 29 contrôles du garde, 34 de phase finale, 13 de capture d’enfants, 19 d’injection, 8 d’admission et 6 d’arrêt. Sources inchangées, résultats dans `final-capture-validation.json` et les artefacts associés. Ces contrôles structurels ne prouvent pas les gains du goal.

La contre-revue native initiale GLM-5.3 a terminé et son finding accepté a été corrigé. Les **deux contre-revues natives du delta ont expiré**, sans verdict final ; cette piste est arrêtée. La validation indépendante finale du delta de mesure reste manquante. Une revue parent ne remplace pas ce contrôle requis.

Aucun commit, push ou déploiement. `PLAN.md` reste présent et READY, avec le bilan partiel : le travail complet n’est pas validé, donc aucune archive IMPLEMENTED ni clôture de goal n’est revendiquée. Le journal original terminal reste intact ; la reprise est tracée dans `.workflow/token-quality-optimum-resume-1/events.jsonl`.

## Reproduction et suite

Recalculer le bilan depuis les preuves sauvegardées, sans inférence :

```sh
python3 .workflow/token-quality-optimum/summarize-final-evidence.py
scripts/harness-token-eval report .workflow/token-quality-optimum/final-v3-development-population.jsonl
scripts/harness-token-eval report .workflow/token-quality-optimum/final-v3-held_out-population.jsonl
scripts/workflow-event validate token-quality-optimum-resume-1
scripts/answer-quality-check --mode handoff docs/harness-token-quality.md
```

L’agrégateur vérifie que chaque ligne correspond à ses `normalized.json`, `grade.json` et reçu terminal. Les oracles, reçus privés et copies de travail sont liés par hashes ; plusieurs chemins sont temporaires locaux, donc la reproduction sur une autre machine exige de conserver ces artefacts. Le lanceur reste borné par son échéance d’origine : ces commandes ne relancent pas la campagne.

Le retour arrière est déjà effectué. Pour l’inspecter sans mutation :

```sh
git apply --reverse --check .workflow/token-quality-optimum/H01-rollback.patch
bun test pi/extensions/__tests__/workflow-tools.test.ts
```

Ne pas réactiver H01 pour une nouvelle campagne : il est rejeté. La suite nécessite une mesure Claude/Codex exploitable, une couverture intégrale des enfants, la revue indépendante manquante et une nouvelle validation réservée indépendante pour tout nouveau candidat. Les pistes observées de lectures répétées et de coût des revues restent des hypothèses à tester, pas des améliorations validées. L’objectif d’au moins 30 % par harness demeure **non atteint**.
