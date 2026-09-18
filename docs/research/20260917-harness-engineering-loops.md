# Harness engineering et boucles d'amélioration pour Etabli

Date de recherche : 2026-09-17. Statut : `verified` pour les sources et le code expressément inspectés ; `not verified` pour leur efficacité dans Etabli. Recherche documentaire, sans exécution de benchmark ni modification des contrats ou scripts du workflow.

## Périmètre et conclusion

Audit de `plan-loop`, `plan-implement` et de leur infrastructure ; exploration de la spec projet et de ses lacunes ; recherche Web sur les harness, les boucles de développement et leur auto-amélioration. Le terme ambigu « world… » est interprété principalement comme « workflows » ; les world models sont traités séparément en fin de note.

**Conclusion : Etabli dispose déjà des composants essentiels. La priorité est de rendre leurs garanties vérifiables de bout en bout, puis de mesurer lesquelles apportent effectivement de la valeur.** Ajouter des agents ou du texte ne constitue pas, en soi, une amélioration. La boucle utile relie intention produit, état observé, action, résultat indépendant et décision d'apprentissage.

Les propositions ci-dessous sont des inférences à expérimenter, pas des gains acquis. Les sources techniques sont primaires. L'audit porte sur l'arbre de travail observé le 17 septembre 2026, qui comportait déjà des modifications. Elles ont été préservées et ne sont pas attribuées à cette recherche. Cette note est un livrable de recherche, pas un contrat actif ni un second plan d'exécution.

## Ce qu'un harness apporte dans un workflow de développement

Le modèle propose des actions. Le harness lui donne des outils, un contexte, un environnement, une mémoire de travail, des règles de transition et des moyens de constater le résultat. Le harness d'évaluation doit, lui, décider si ce résultat satisfait les exigences. Séparer ces deux responsabilités évite que la boucle optimisée puisse redéfinir son propre succès.

Pour Etabli, trois boucles doivent être distinguées :

```text
PROJET       demande + spec + décisions + code observé
                    ↓ identifier les écarts et les inconnues
             PLAN → READY → première tranche utilisable
                    ↑                         ↓
                    └──── faits nouveaux ─────┘

DÉVELOPPEMENT  action → observation réelle → validation → correction
                         ↓ preuve sur le dernier état
                      revue → clôture

AMÉLIORATION   traces et incidents → hypothèse → candidat isolé
                    → comparaison → test final → adopter / rejeter
                                              ↓
                                   vérifier sur les tâches futures
```

Un résultat rouge peut demander une correction du code, de la spec, de l'environnement ou du harness. Relancer la même action ne permet pas de distinguer ces causes.

## Enseignements des sources récentes

Les billets d'équipes décrivent des expériences situées ; les articles scientifiques donnent des protocoles plus explicites, sans garantir un transfert à Etabli. Aucun chiffre externe ci-dessous n'est une prévision de gain local.

### Environnement observable et incréments vérifiables

**OpenAI, 11 février 2026 — retour d'ingénierie.** Le [récit sur le harness engineering](https://openai.com/index/harness-engineering/) décrit un dépôt accessible aux agents, une documentation navigable, des contraintes mécaniques et une application observable par ses interfaces, logs et métriques. Les blocages orientent le travail vers les capacités manquantes de l'environnement. C'est une expérience d'équipe, pas une comparaison causale contrôlée de productivité. **Application proposée :** préparer la commande de lancement et le moyen d'observer le comportement dès le plan ; garder les instructions d'entrée courtes et reliées aux sources utiles.

**Anthropic, 26 novembre 2025 — fondation historique.** [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) distingue préparation de l'environnement et sessions incrémentales, avec état de progression et tests réels. **Application proposée :** une reprise Etabli doit retrouver le dernier état validé, la prochaine preuve à produire et les hypothèses éliminées. Un compte rendu textuel de réussite ne remplace pas l'observation du produit. Cette source explique un mécanisme ; elle ne prouve pas sa supériorité pour tous les projets.

**Anthropic, 24 mars 2026 — expérience de développement d'applications.** [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) articule planificateur, générateur et évaluateur, avec critères convenus avant le code et inspection réelle de l'application. Les auteurs retirent aussi des mécanismes devenus inutiles avec de nouveaux modèles. La comparaison illustrée change durée, coût et périmètre : elle n'isole pas l'effet du harness. **Application proposée :** attribuer les responsabilités d'évaluation explicitement, calibrer la sévérité des juges et mesurer l'utilité de chaque étape ; trois rôles ne nécessitent pas systématiquement trois agents.

### Spec, plan et code : vérifier les deux directions

**GitHub Spec Kit, documentation consultée le 17 septembre 2026.** Le [workflow officiel](https://github.github.io/spec-kit/reference/agentic-sdd.html) distingue clarification des exigences, plan technique, analyse des incohérences et vérification de l'implémentation face aux artefacts. Il traite la qualité de la spec comme une question distincte de l'achèvement du code. C'est un workflow documenté, sans preuve comparative fournie ici. **Application proposée :** reprendre l'analyse des trous avant `READY` et le contrôle de couverture à la fin ; conserver l'unique `PLAN.md` d'Etabli et référencer les sources produit existantes. La promesse de convergence d'une boucle documentaire ne garantit pas sa terminaison.

### Vérifier le résultat et maîtriser les variables expérimentales

**Anthropic, 9 janvier 2026 — méthode d'évaluation.** [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) distingue trajectoire et résultat dans l'environnement, évaluateurs programmatiques, juges modèles et évaluation humaine. La réussite d'au moins un essai (`pass@k`) diffère de la réussite de tous les essais (`pass^k`). **Application proposée :** mesurer la tâche effectivement réussie, conserver les échecs et calibrer les juges sur des cas négatifs connus. Le nombre de tests ou de revues exécutés mesure une activité, pas directement la qualité livrée.

**Anthropic, 5 février 2026 — expérience sur l'infrastructure.** [Infrastructure noise](https://www.anthropic.com/engineering/infrastructure-noise) rapporte jusqu'à **6 points de pourcentage** d'écart sur Terminal-Bench entre configurations de ressources, à modèle et harness constants. Ce maximum entre configurations n'est pas une correction universelle à appliquer aux scores. **Application proposée :** identifier environnement, concurrence, ressources et délais dans chaque comparaison, puis distinguer échec d'infrastructure et échec fonctionnel. Une amélioration de ces paramètres doit être évaluée comme un changement explicite.

### Des étapes utiles peuvent devenir du surcoût

**LangChain, 17 février 2026 — benchmark interne.** [Improving Deep Agents with harness engineering](https://www.langchain.com/blog/improving-deep-agents-with-harness-engineering) rapporte **52,8 → 66,5 %** sur 89 tâches Terminal-Bench 2.0, avec le même modèle. Les changements portent sur prompts, outils et mécanismes d'intervention ; les traces guident les corrections. **Application proposée :** les boucles de réparation doivent revenir à l'exigence initiale et changer d'hypothèse en cas de stagnation. Ce résultat justifie d'expérimenter le harness ; il ne permet pas d'attribuer le gain à une seule règle ni de le transférer à Etabli.

**LangChain, 29 juillet 2026 — simplification du harness.** [Deep Agents v0.7](https://www.langchain.com/blog/deep-agents-v0-7) réduit d'environ **6 000 à 2 000** les tokens d'entrée de base en retirant des instructions et en rendant les todos optionnels. Il ne s'agit pas des tokens totaux d'une tâche. Les résultats restent comparables globalement ; les coûts ne baissent pas uniformément selon le modèle. **Application proposée :** tester le retrait d'une obligation coûteuse à la fois, en préservant les critères de réussite. Ces résultats ne justifient pas de supprimer le contrat `READY` d'Etabli.

**Gloaguen et al., version du 23 juin 2026 — étude empirique.** [Evaluating AGENTS.md, v2](https://arxiv.org/html/2602.11988v2) compare des configurations avec et sans contexte sur SWE-bench Lite et CTXbench. Les fichiers générés n'améliorent pas significativement la réussite et augmentent les coûts moyens d'environ **20–23 %**. Le contexte écrit par des développeurs surpasse le contexte généré, sans gain significatif face à l'absence de contexte. Limites : tâches Python, modèles étudiés, une exécution par tâche/configuration ; toutes les fonctions de gouvernance ne sont pas mesurées. **Application proposée :** conserver les règles nécessaires et tester les ajouts de contexte au lieu de supposer leur bénéfice.

**Geoffrey Huntley, 14 juillet 2025 — pratique de boucle persistante.** [Ralph Wiggum as a software engineer](https://ghuntley.com/ralph/) popularise une boucle simple qui réengage l'agent autour d'un état de travail persistant. C'est un retour d'expérience, pas une évaluation contrôlée. **Application proposée :** reprendre la continuité et la possibilité de recommencer depuis un état inspectable ; conditionner les nouvelles tentatives à une observation ou une hypothèse nouvelle. Une boucle qui continue à tourner ne démontre pas que le travail progresse.

## Self-Harness : protocole intéressant, généralisation à établir

**Source :** prépublication du 8 juin 2026, [v3 du 20 août](https://arxiv.org/abs/2606.09498v3). Traces d'échec → propositions limitées → régression ; modèle et évaluateur fixes. Baseline minimale ; 64 tâches Terminal-Bench, 100 SWE-bench, 180 AppWorld ; deux tentatives par candidat sauf exception. [Méthode, §3–4](https://arxiv.org/html/2606.09498v3).

Taux globaux SWE-bench publiés : MiniMax M2.5, 46,0 → 52,5 % ; Qwen3.5-35B-A3B, 19,5 → 41,5 % ; GLM-5, 52,0 → 55,5 %. [Tableau 1](https://arxiv.org/html/2606.09498v3).

**Limites / inférences :** le « held-out » participe aux promotions : validation adaptative, pas test final intact. Baseline minimale et deux répétitions ne prouvent ni robustesse statistique ni transfert vers Etabli. Reproduction indépendante non effectuée ici.

## Artefact officiel Self-Harness : lecture ciblée

Version inspectée : [`2720dbb3f52283684f4b85a1065d642df1779dd8`](https://github.com/qzzqzzb/Self-Harness/tree/2720dbb3f52283684f4b85a1065d642df1779dd8), commit daté du 2 juillet 2026, 24 fichiers. L'arbre contient un harness final Qwen/Terminal-Bench ; cet inventaire ne démontre pas la reproduction des neuf combinaisons du papier.

Le [contrôle d'acceptation](https://github.com/qzzqzzb/Self-Harness/blob/2720dbb3f52283684f4b85a1065d642df1779dd8/acceptance/scripts/run_acceptance_gate.py#L79-L189) exige deux répétitions par défaut, des dénominateurs comparables et aucune baisse entre splits, avec au moins une hausse. Il compare des agrégats ; cette fonction ne prouve pas l'identité des tâches ni celle de l'évaluateur.

L'[orchestrateur](https://github.com/qzzqzzb/Self-Harness/blob/2720dbb3f52283684f4b85a1065d642df1779dd8/workflow/scripts/run_self_harness_loop.py#L525-L587) réévalue la combinaison de candidats acceptés avant promotion. **Inférence :** c'est un mécanisme utile à reprendre, mais le code public n'est pas une preuve suffisante d'intégrité de campagne. Aucun audit exhaustif ni lancement effectué.

## GEPA : apprendre des retours explicatifs et conserver plusieurs candidats

[GEPA v2](https://arxiv.org/abs/2507.19457v2), du 14 février 2026, est acceptée à ICLR 2026 en présentation orale. Les mutations exploitent traces et retours textuels ; une frontière de Pareto conserve des candidats complémentaires. Le papier distingue validation et test final et étudie leurs écarts. [Méthode et expériences](https://arxiv.org/pdf/2507.19457v2).

**Limites :** expériences de raisonnement, instructions, confidentialité, recherche d'information et kernels ; pas de preuve d'amélioration de la conduite complète d'un projet. L'acceptation scientifique n'est pas une réplication. **Inférence pour Etabli :** conserver raisons des échecs et alternatives sous budget fixé peut enrichir l'apprentissage.

L'[implémentation officielle](https://github.com/gepa-ai/gepa/tree/15ee314f9c7d34ec153b809d401f42f55c4dcd76), référencée par le papier, a été identifiée au commit `15ee314f9c7d34ec153b809d401f42f55c4dcd76` du 11 septembre 2026 ; son algorithme n'a pas été audité dans cette recherche.

## Autoresearch : un exemple simple d'expérimentation bornée

Dans le [dépôt officiel de Karpathy](https://github.com/karpathy/autoresearch/tree/228791fb499afffb54b46200aca536f79142f117), commit du 26 mars 2026, l'agent modifie `train.py`, exécute cinq minutes d'entraînement, mesure `val_bpb` et conserve ou rejette l'expérience. `prepare.py`, dont l'évaluation, doit rester fixe ; `program.md` est présenté comme une surface pilotée par l'humain. [README](https://github.com/karpathy/autoresearch/blob/228791fb499afffb54b46200aca536f79142f117/README.md).

Les [instructions d'expérience](https://github.com/karpathy/autoresearch/blob/228791fb499afffb54b46200aca536f79142f117/program.md) enregistrent les essais, imposent une baseline et valorisent aussi la simplification. **Limites :** cette optimisation locale, mono-GPU et centrée sur une métrique n'est pas une démonstration d'auto-amélioration récursive du développeur. Une interdiction textuelle de modifier l'évaluation n'est pas une séparation technique. La consigne de boucle indéfinie ne convient pas telle quelle aux campagnes Etabli.

## Diagnostic local : ce qui existe et ce qui manque

Etabli dispose déjà d'une exploration préalable, d'un plan unique, de niveaux de risque, d'un arrêt sur stagnation, de reprises documentées, d'un contrôle d'usage réel du produit et d'une boucle d'amélioration avec rejets. Voir [implementation-loop](../../workflow/skills/implementation-loop.md), [product-dogfood](../../workflow/skills/product-dogfood.md) et [self-improvement-loop](../../workflow/skills/self-improvement-loop.md). Les travaux présents dans l'arbre renforcent également les empreintes d'artefacts, l'identité de l'évaluateur et la non-régression par tâche. Il faut prolonger ces mécanismes, pas les présenter comme absents.

| Priorité | Constat vérifié dans l'arbre observé | Conséquence et correction proposée |
| --- | --- | --- |
| P1 | [plan-loop](../../workflow/skills/plan-loop.md), lignes 24–40, demande les fichiers pertinents mais n'impose pas explicitement le rapprochement spec/code ni l'examen des lacunes de la spec. Le [contrat des projets ambitieux](../../workflow/skills/ambitious-project-loop.md) le couvre partiellement. | Un plan peut être techniquement cohérent tout en oubliant une exigence produit. Ajouter une reconnaissance proportionnée des sources produit et des écarts avant `READY`. |
| P1 | [workflow-event-detail.jq](../../scripts/lib/workflow-event-detail.jq), fonction `autonomous_profile_error`, recherche surtout des types d'événements. La branche stricte ne reprend pas le contrôle d'ordre entre dernier changement et validation. | La présence des étapes ne prouve pas leur succès ni leur validité actuelle. Exiger les verdicts compatibles avec la clôture, résoudre les blocages et rattacher validation/revue au dernier état pertinent. |
| P1 | [plan-check-freeze.mjs](../../scripts/lib/plan-check-freeze.mjs), `parseChecksUncached`, ignore `expected:` et ne capture pas `## Validation Plan` du [modèle complet](../../PLAN_TEMPLATE_FULL.md). | Le résultat attendu peut être affaibli et des vérifications retirées sans dégel explicite. Protéger critères, résultats attendus et validations dans les deux modèles. |
| P1 | [workflow-router-lib.mjs](../../claude/hooks/workflow-router-lib.mjs), `readPlanStatus` et `planReadyGuardDecision`, traite un statut non reconnu comme absence de verrou. Le simple libellé `READY` ne valide pas le contenu du plan. | Distinguer absence légitime de plan et plan présent mal formé ; valider le contrat minimal avant d'ouvrir les mutations d'une tâche soumise au plan. La [matrice des runtimes](../../workflow/runtime-capabilities.json) signale déjà l'absence de ces hooks sur la surface Codex : ne pas promettre une protection uniforme. |
| P1 | [implementation-loop](../../workflow/skills/implementation-loop.md), étapes 13–13b, définit la revue par `merge-base...HEAD` puis autorise des corrections avec relance des checks. | Ce périmètre Git exclut le travail non commité ; aucune nouvelle revue du dernier état après correction n'est explicitement exigée. Lier chaque revue au patch réellement livré, incluant les changements locaux concernés, et renouveler les preuves rendues obsolètes. |
| P2 | [workflow-retrospect](../../scripts/workflow-retrospect), `scan_plan_archives` et `build_summary`, utilise `fichier:ligne` pour les occurrences d'archives. | Deux mentions d'un incident dans une même archive peuvent compter comme deux récurrences. Dédupliquer par incident/initiative, puis rattacher les formulations à une cause avec preuves. |
| P2 | [skill-eval.mjs](../../scripts/lib/skill-eval.mjs), lignes 170–171, exige un gain strict du nombre de tâches réussies dans `held_in`. | Une amélioration moins coûteuse à qualité identique est rejetée. Déclarer des objectifs distincts : qualité, efficacité ou fiabilité, chacun avec son critère et ses invariants de non-régression. |

Ces constats distinguent le contrat demandé à l'agent de son application mécanique. Un hook incomplet ne signifie pas que toutes les sessions ont enfreint le contrat ; il signifie que ce hook ne suffit pas à garantir son respect.

### Contre-exemples locaux réexécutés pendant la recherche

Un script Node a importé les deux modules concernés ; le contrôle des statuts a utilisé un dossier temporaire supprimé après l'essai. Aucun fichier applicatif ni plan du dépôt n'a été modifié. Résultats :

```text
READY / Checks / command: npm test
expected: all tests pass → expected: one test passes
evaluateCheckFreeze.ok = true

READY / Acceptance Criteria / feature works
suppression de Validation Plan / Automated checks: npm test
evaluateCheckFreeze.ok = true

PLAN contenant uniquement le statut :
DRAFT                  → parsed: draft   → mutation_allowed: false
DRAFT — needs review   → parsed: unknown → mutation_allowed: true
READY                  → parsed: ready   → mutation_allowed: true
```

Ces résultats prouvent les comportements des fonctions sur ces entrées. Ils ne constituent pas un test de bout en bout des intégrations Pi, Claude et Codex.

## Exploration du plan : spec, code et inconnues

La **spec projet** définit le produit attendu ; `workflow/spec.md` définit la manière de travailler. Lire le second ne couvre pas la première. Pour une petite correction, une exigence et quelques fichiers peuvent suffire. Pour une évolution produit, l'exploration doit aussi couvrir les parcours, données, intégrations et états d'échec concernés.

Séquence proposée pour `plan-loop`, également utilisée par `plan-implement` :

1. **Identifier les sources applicables.** Demande actuelle, spec/PRD, ticket, décisions acceptées, contraintes du projet, puis code et tests. Nommer les chemins, leur actualité connue et les contradictions éventuelles. Ne pas choisir silencieusement entre deux intentions produit incompatibles.
2. **Observer l'existant.** Pour chaque comportement concerné, localiser implémentation, test, commande de lancement et preuve disponible. Le code révèle l'état actuel ; son existence ne le rend pas automatiquement conforme.
3. **Challenger la spec elle-même.** Vérifier acteurs et permissions, préconditions, parcours nominal, erreurs/reprises, états limites, données persistées et critère observable de réussite, selon le risque. Rechercher omissions et contradictions, pas seulement les écarts d'implémentation.
4. **Décider du traitement de chaque trou.** Correction incluse ; hypothèse réversible avec moyen de la vérifier ; courte expérimentation ; question réellement bloquante ; ou hors périmètre motivé. Élargir le projet reste une décision explicite.
5. **Préparer la première preuve utile.** Identifier une tranche minimale exécutable de bout en bout et confirmer que l'environnement et le moyen de validation sont accessibles. Un test irréalisable doit être découvert avant que toute l'implémentation en dépende.
6. **Passer `READY` sur les décisions nécessaires.** Aucun manque critique non traité sur la tranche autorisée ; les inconnues restantes ont un impact, un traitement et un point de décision. Une hypothèse structurante non vérifiée peut conduire à un plan d'exploration limité plutôt qu'à la construction prématurée de toute la fonctionnalité.

La trace peut tenir dans une petite table de `PLAN.md`, avec références aux documents existants :

| Exigence / source | État observé | Trou ou divergence | Décision | Étape / preuve attendue |
| --- | --- | --- | --- | --- |
| Exemple fictif : après création, la donnée reste disponible | UI locale seulement ; persistance non démontrée | La spec ne précise pas le comportement après rechargement | Clarifier la persistance nécessaire ; limiter le périmètre au parcours choisi | Créer → recharger → relire via la surface réelle |

**Spec absente :** noter « aucune spec trouvée dans les sources examinées », dériver les critères de la demande et des décisions confirmées, puis poser seulement les questions qui empêchent une mise en œuvre correcte. L'absence de document n'est pas automatiquement un blocage. Une spec ancienne ou contradictoire doit rester une source à vérifier.

En fin de développement, parcourir la correspondance dans les deux sens : chaque exigence retenue a sa preuve ; chaque changement livré sert une exigence ou une correction justifiée. Les fonctionnalités non demandées ne deviennent pas légitimes simplement parce qu'elles passent des tests.

## Boucle de développement : transitions fondées sur l'état réel

**Avant de coder :** rendre accessibles l'environnement, les checks et la preuve de la première tranche. La disponibilité du reviewer et du runtime requis se vérifie aussi à ce moment, pour éviter un blocage découvert à la clôture.

**Pendant le travail :** à chaque échec, distinguer erreur de code, ambiguïté produit, manque d'outil, état obsolète ou panne d'infrastructure. Une relance se justifie par un changement ou une hypothèse. En cas de dérive matérielle, reprendre le plan avec les faits nouveaux, conformément au contrat existant. La reprise doit conserver dernier état validé, échecs connus et tentatives à ne pas répéter.

**Avant la clôture :** une validation doit couvrir l'état courant, une revue le patch concerné, et un critère produit un résultat observable. Toute correction invalide les preuves qu'elle peut affecter. Le système doit traiter explicitement preuves absentes, périmètres incomplets, verdicts bloquants et changements postérieurs à la revue. Cette exigence ne signifie pas relancer tous les contrôles après une modification documentaire sans incidence.

Le contrat prévoit déjà les niveaux de risque et le dogfood. L'amélioration consiste à relier leur activation aux exigences et aux preuves, puis à comparer leur contribution. Réduire une étape coûteuse demande une expérience ; préserver les contrôles critiques reste un invariant.

Enfin, la règle générale de [Long-Loop Budget Discipline](../../workflow/skills/implementation-loop.md) qui demande d'abandonner une commande métrique après environ 60 secondes mérite une correction ciblée : un benchmark ou build utile peut légitimement durer davantage. Distinguer délai entre observations de progression, durée maximale de la commande et budget de campagne ; dimensionner chacun à partir de l'exécution réelle. Ce point ne justifie pas une boucle sans fin.

## Auto-amélioration : passer de la récurrence à une décision mesurée

### Une mémoire causale, avec des résultats négatifs

Réutiliser les événements et archives existants pour relier : incident distinct → résultat attendu/observé → cause étayée ou encore inconnue → mécanisme du harness → candidat → essais → décision. Garder les rejets, leur motif et les conditions de réexamen. Une répétition textuelle n'est ni une récurrence indépendante ni une preuve causale.

La mémoire utile réduit une future erreur, une recherche répétée ou une mauvaise décision. Mesurer aussi les mauvaises suggestions, les rappels obsolètes et les faux blocages. Conserver `no_op` comme un résultat valable : une observation isolée ne doit pas automatiquement ajouter une règle permanente.

### Trois ensembles de tâches et un évaluateur protégé

Les incidents connus servent à construire les candidats. Une suite de validation sert à les comparer. Un **test final encore intact**, puis des tâches futures, mesurent le transfert. Un ensemble consulté à chaque promotion devient de la validation adaptative, même si son fichier s'appelle `held_out`.

Le contrat local exclut déjà l'évaluateur de la boucle de mutation. L'application technique doit être attestée : exécution de l'évaluateur depuis une surface distincte, non modifiable par le candidat, avec identités des tâches, critères et environnement figés pour la comparaison. Une empreinte détecte une différence ; elle n'empêche pas à elle seule une modification. Une évolution légitime de l'évaluateur ouvre une nouvelle campagne et impose de rejouer la baseline.

Deux changements acceptés séparément doivent être réévalués une fois combinés. Si le test final devient une source de diagnostic, il ne peut plus servir de test intact au prochain candidat ; renouveler les cas réservés et confirmer sur le travail futur.

### Définir quel progrès est recherché

| Objectif choisi avant l'essai | Signal principal | Contre-mesures indispensables |
| --- | --- | --- |
| Qualité | Plus de tâches réellement réussies | Régressions par tâche, défauts échappés, contraintes critiques |
| Efficacité | Moins de coût ou de délai par tâche réussie | Qualité maintenue, reprises humaines, temps de réparation |
| Fiabilité | Résultats plus stables sur essais répétés | Même population, panne d'infrastructure séparée, coût des tentatives |
| Exploration | Lacunes importantes détectées et bien traitées avant le code | Faux blocages, questions inutiles, portée ajoutée sans justification |

Les tokens réellement mesurés et le coût total de campagne incluent les essais ratés, reviewers et reprises. Le volume de caractères de `workflow-context-budget` reste un proxy de taille statique ; sa réduction ne démontre pas une économie en exécution. Un statut `completed` ne suffit pas à mesurer la réussite fonctionnelle. Le [contrat actuel](../../workflow/spec.md) exige déjà au moins dix résultats de `task-grader` avant une revendication de valeur de la télémétrie ; ce plancher documentaire n'est pas une garantie statistique.

## Trois expérimentations proposées, dans cet ordre

Ces expérimentations ne sont pas lancées par cette recherche. Chacune nécessite sa baseline figée, ses surfaces modifiables, son critère de succès, ses répétitions, son budget opérationnel et son critère d'arrêt dans un futur `PLAN.md`.

### 1. Prouver les transitions et la clôture

Constituer un corpus déterministe des contre-exemples locaux : statut mal formé, plan incomplet, résultat attendu affaibli, validation complète retirée, test rouge, revue bloquante, changement après validation/revue, modification non commitée. Ajouter les cas positifs correspondants, dont une petite tâche autorisée sans plan.

**Succès :** tous les états invalides sont refusés avec une correction explicite ; les cas légitimes restent possibles ; un parcours réel préparation → implémentation → validation → revue → clôture fonctionne sur chaque runtime revendiqué. Vérifier que le mode strict ne retire jamais une garantie du mode normal.

### 2. Évaluer l'exploration spec/code

Préparer un corpus public synthétique ou assaini : spec claire, absente, ancienne, contradictoire, détail critique manquant, manque non critique, implémentation divergente et test inadéquat. Comparer le workflow actuel et le candidat sur les mêmes tâches avec évaluateur indépendant. Garder des variantes inédites pour la vérification finale.

**Succès :** les lacunes critiques connues sont traitées avant `READY`, sans augmenter les blocages injustifiés ; les hypothèses restantes sont vérifiables ; la première tranche satisfait ses critères. Évaluer la gravité et la justesse des décisions, pas le nombre de questions ou de lignes du plan.

### 3. Mesurer puis simplifier une étape

Choisir une modification : chargement du contexte à la demande, suppression d'une instruction redondante, moment d'une revue ou forme du handoff. Conserver les obligations critiques. Comparer les variantes à modèle, réglages et environnement constants, en alternant l'ordre des essais. Répéter les tâches et comparer les résultats appariés ; un petit pilote renseigne d'abord la variabilité, sans prouver une généralisation.

**Succès :** bénéfice prédéfini sur coût, délai ou fiabilité, sans régression fonctionnelle ou de protection. Rapporter coûts totaux, essais échoués, interventions humaines et dispersion des résultats. `inconclusive` reste possible. Toute adoption ultérieure conserve un retour arrière et un contrôle sur de nouvelles tâches.

## Si « world… » désignait les world models

[Agent World Model, v3 du 22 mai 2026](https://arxiv.org/abs/2602.10090v3), décrit des environnements synthétiques exécutables, adossés à des bases de données, pour entraîner des agents à utiliser des outils. [SWE-World, 3 février 2026](https://arxiv.org/abs/2602.03419), propose un modèle de substitution qui prédit les retours d'exécution et de tests pour entraîner et évaluer des agents logiciels. Ces travaux portent sur la simulation et l'apprentissage ; leurs gains annoncés ne sont pas validés ici.

**Inférence pour Etabli :** un modèle explicite de l'état du projet — exigences, fichiers, dépendances, état exécuté et preuves valides — est utile. Il ne s'agit pas d'un world model appris. La simulation peut aider à concevoir des fixtures ; elle ne doit pas certifier qu'une application réelle fonctionne. Construire ou intégrer un modèle appris ne paraît pas prioritaire face aux écarts observés dans les contrôles actuels.

## Validation et limites de cette recherche

- Sources primaires ouvertes : publications OpenAI et Anthropic, documentation GitHub Spec Kit, billets et résultats LangChain, étude AGENTS.md v2, texte Ralph, article et code Self-Harness, article et dépôt GEPA, README et protocole autoresearch ; résumés primaires AWM et SWE-World. Métadonnées des commits cités pour Self-Harness, GEPA et autoresearch contrôlées via l'API publique GitHub.
- Validation locale : lecture des contrats, modèles et fonctions cités ; contre-exemples `plan-check-freeze` et garde `READY` réexécutés dans un dossier temporaire. Les constats sur les autres contrôles reposent ici sur l'inspection du code, pas sur une nouvelle campagne de bout en bout.
- Contexte local consulté : `workflow/answer-quality.md`, `workflow/skills/obvault-memory.md` ; entrée `~/work/obvault/AGENTS.md`, puis contexte borné de `kb/etabli-self-improvement-harness-contract.md`. Cette mémoire sert de contexte ; aucune performance actuelle n'en est déduite.
- `not verified` : gains sur Etabli, réplication indépendante, robustesse statistique et coût total de recherche. Aucune expérience payante ou exécution des dépôts externes.
- Checks documentaires : `scripts/research-proof-check docs/research/20260917-harness-engineering-loops.md` et `scripts/answer-quality-check --mode research docs/research/20260917-harness-engineering-loops.md`. Ils contrôlent la structure de preuve ; ils ne valident pas les résultats scientifiques. Résultats finaux consignés dans la réponse de livraison après consolidation.
- Prochaine action utile : transformer les corrections de garanties et l'exploration spec/code en un `PLAN.md` ciblé, puis implémenter depuis `READY`. La recherche seule ne modifie pas les skills, les hooks ni les critères actifs.
