# Amélioration des agents à partir de leurs traces : Warp, Skill Doctor, GEPA et Reflexion

Date de recherche : **2026-11-07**. Statut : analyse externe et propositions, sans mise en œuvre.

Périmètre : confrontation de la présentation de Ben Holmes jointe à la demande avec les sources primaires publiques. Le code de `warpdotdev/common-skills` est figé au commit **`8792394ff1b655e0af451b8fabb68ef0cfcbd208`**, tête de `main` observée pendant cette recherche, datée du 20 octobre 2026. Les pages Warp ont été consultées le 7 novembre ; leurs comportements décrits ne constituent pas une observation du service en fonctionnement. [Commit examiné][WCOM]

La pièce jointe a servi à repérer les thèses à vérifier. Aucun extrait de cette transcription ni aucune trace privée n'est reproduit ici. Aucun collecteur n'a été exécuté sur les historiques locaux. Le rapprochement avec Etabli porte sur les sources de `origin/main` au commit `9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7`, et distingue contrats écrits, livraisons documentées et usages non mesurés. Fleet est géré dans un autre thread : cette recherche n'y apporte aucun changement.

## Constats

1. **Le mécanisme utile est une boucle d'ingénierie observable** : examiner les exécutions, qualifier les défauts, regrouper leurs causes, proposer une correction, puis vérifier son effet. Skill Doctor matérialise la partie diagnostic et proposition ; Factories documente l'exploitation continue et les PR de correction. Cela ne constitue pas un apprentissage des poids du modèle. [Workflow Skill Doctor][SD], [Self-improvement Factories][FSI]

2. **Skill Doctor est surtout une procédure donnée à l'agent, accompagnée d'un collecteur et d'un générateur de rapport.** Le jugement, l'agrégation et la rédaction des changements sont prescrits dans Markdown, pas exécutés par un moteur de scoring reproductible livré dans ce répertoire. Les scripts présents assurent collecte, décodage Warp et rendu. [Arborescence figée][WTREE], [Étapes 2–5][SDSCORE]

3. **Le code a dépassé la page commerciale.** La page Skill Doctor cite Claude Code, Codex et Warp, avec une présentation centrée sur efficacité, qualité et couverture. La référence actuelle prend en charge sept harnesses, dont Pi, et le workflow demande quatre jugements : efficacité, qualité du code, conformité procédurale et verbosité. La couverture est une détection séparée. [Présentation Warp][LAND], [Harnesses][HAR], [Rubriques appelées][SDSCORE]

4. **La note affichée n'est ni un taux de réussite, ni une mesure causale du bénéfice des skills.** Elle transforme les moyennes qualitatives, y ajoute une couverture fondée sur des heuristiques et les combine arbitrairement. L'échantillon est privilégié par récence et usage détecté de skills, et non tiré uniformément au hasard. [Agrégation][SDSCORE], [Échantillonnage][SAMPLE]

5. **La confidentialité est une intention explicite, mais pas une propriété garantie par le mot « local ».** Le collecteur est local ; les transcriptions sont ensuite lues par l'agent juge. Le workflow ne configure ni un modèle local, ni le réseau de son harness. Avec un modèle distant, le contenu fourni au juge entre dans son contexte d'inférence. Il faut donc examiner cette frontière séparément. [Consigne de confidentialité][SD], [Lecture par le juge][SDSCORE]

6. **La proposition la mieux justifiée pour Etabli est un pilote limité de diagnostic, avec possibilité de conclure « aucun changement ».** La règle upstream la plus intéressante exige une instruction absente ou erronée, une surface propriétaire et un lien explicite avec le défaut ; elle exclut le simple ajout de prose lorsqu'une instruction correcte a déjà été ignorée. [Critères de proposition][IMP]

## Lecture critique du talk fourni

Les horodatages ci-dessous repèrent les passages de la transcription jointe ; celle-ci comporte des segments qui se chevauchent. Ce sont des repères de lecture, pas une vérification de la vidéo originale.

- **03:26–06:45 : réunir conversation, actions et résultat.** C'est l'apport structurel le plus utile. Un résumé final ne permet pas de vérifier la trajectoire ; la trajectoire seule ne permet pas de conclure que le résultat fonctionne. Pour une correction, la preuve recherchée serait le diff exact, les vérifications à ce SHA et, si nécessaire, le résultat réellement observé.
- **08:09–09:50 : retrouver les détours invisibles.** Le cas des consignes d'environnement périmées explique comment une tâche peut réussir après des recherches inutiles. Le mot « hiding » du titre ne démontre pas une dissimulation intentionnelle : le phénomène décrit est surtout une perte d'information dans le compte rendu final.
- **09:23–13:57 : rubriques, classement et regroupement.** Les labels explicites et les justifications reliées à une trace sont utiles. En revanche, juger toutes les sessions avec un modèle ne remplace pas une calibration de ce juge, et examiner seulement les échecs ne mesure pas un taux de défaut sur l'ensemble du travail. [Calibration][ANTH], [Sélection réellement implémentée][SAMPLE]
- **13:31–16:32 : corriger la surface qui porte la cause.** Les exemples de ports et de langue du changelog illustrent des instructions incomplètes. Ils ne permettent pas de traiter chaque échec d'outil comme une mauvaise instruction : la référence publique impose une attribution plus exigeante. [Conditions upstream][IMP]
- **16:37–19:40 : rendre les améliorations visibles.** Un journal des changements et de leurs résultats est préférable à une mémoire opaque. L'inflexion d'une courbe après un merge reste un signal ; elle devient une preuve d'effet seulement avec des observations comparables et le contrôle des autres changements. La documentation Warp elle-même demande de tester un changement à la fois. [Méthode documentée][FMEASURE]

Un point à ne pas reprendre sans adaptation : « trop de tests » est une hypothèse à examiner, pas une catégorie de défaut universelle. Un test peut être redondant ; il peut aussi protéger une erreur déjà échappée. La décision dépend du défaut détectable, du risque et du coût de maintenance. De même, un test volontairement rouge en développement, une recherche sans résultat ou un refus de permission attendu ne sont pas des incidents d'efficacité par défaut. Cette distinction est une recommandation d'analyse pour Etabli, pas une capacité démontrée par le compteur lexical du collecteur. [Heuristiques existantes][CLAUDE], [Contraintes Etabli][ECONSTRAINT]

## Ce que les sources publiques fournissent réellement

### 1. La chaîne réelle de Skill Doctor

Le workflow demande d'abord d'identifier le harness d'exécution à partir du contexte du runtime. Un harness inconnu doit arrêter le travail avant toute lecture d'historique. Il demande ensuite le périmètre de conversations et celui des skills, puis crée un répertoire temporaire distinct du dépôt. Ces règles sont des instructions à l'agent ; le script peut aussi être appelé directement avec ses paramètres. [Démarrage][SD], [Référence des harnesses][HAR], [Arguments du collecteur][ARGS]

Les étapes sont les suivantes :

- Découvrir les historiques locaux et les skills ; produire `inventory.json` et des transcriptions condensées pour les seules sessions retenues.
- Faire lire chaque transcription au juge avec les quatre rubriques ; demander une classification, le score associé et une justification de une à trois phrases.
- Calculer les agrégats et retenir les conversations dont au moins un résultat applicable est inférieur à `0.5`.
- Vérifier les causes dans la configuration actuelle et rédiger les changements admissibles.
- Écrire les versions proposées sous `proposed/<skill-name>/SKILL.md`, leurs diffs et un `report.json` ; rendre `report.html`. [Collecte et analyse][SD], [Attribution][IMP]

**Ce que cette invocation modifie :** ses propres fichiers de travail et de rapport. Elle doit préserver les vrais fichiers de skills pendant la préparation. Sa réponse finale propose séparément d'appliquer les suggestions. Il n'y a pas de mise à jour automatique des skills installés, de commit, de PR ou de déploiement dans cette procédure. Les propositions portent principalement sur `SKILL.md` ; les critères d'attribution évoquent aussi la configuration de l'acteur et les instructions du dépôt. Cela ne prouve pas qu'un correcteur générique de ces autres surfaces soit fourni. [Étapes 4–6][SDDRAFT], [Surfaces admissibles][IMP]

Le rendu crée une page HTML avec notes, constats, preuves textuelles et diffs. Son bouton PNG dessine une carte dans un canvas et déclenche un téléchargement local ; ce bouton ne publie pas le rapport. Le HTML contient davantage de détails que la carte de partage. [Construction du rapport][REPORT], [Export local][PNG]

### 2. Sources de traces et portée effective

La référence figée énumère les sources suivantes. C'est une liste de lecteurs présents dans le code, pas une certification de compatibilité avec toutes les versions actuelles de ces produits. [Référence][HAR], [Collecteur complet][COL]

| Harness | Source lue |
| --- | --- |
| Claude Code | JSONL sous les projets du répertoire de configuration |
| Codex | JSONL de rollout, sessions actives et archivées |
| Warp | Bases SQLite locales de conversations et tâches |
| Pi | JSONL sous `~/.pi/agent/sessions` |
| Grok Build | JSONL de `chat_history` |
| ZCode | Rollouts `model-io` |
| Hermes | SQLite `state.db`, tables sessions et messages |

Les chemins standards peuvent être remplacés par des arguments dédiés. `--harness auto`, valeur par défaut, cherche toutes les sources disponibles, pas uniquement celle du harness qui exécute le skill. Les sessions enfants sont normalement exclues lorsqu'un lecteur sait les identifier ; `--include-subagents` élargit cette collecte. Le lecteur Pi accepte ce drapeau mais l'ignore explicitement. Il parcourt les enregistrements sans reconstruire une branche active à partir de liens parent/enfant : une conversation Pi à embranchements ne doit donc pas être considérée comme une trajectoire unique fidèlement rejouée. [Options][ARGS], [Lecteur Pi][PI]

Les skills projet sont recherchés sous `.agents/skills`, `.claude/skills` et `.codex/skills`. Les skills globaux sont optionnels ; des chemins supplémentaires sont acceptés. La découverte ne parcourt que `*/SKILL.md` à chaque racine et indexe les skills par nom de dossier : deux skills de même nom sont confondus au profit du premier trouvé, et une organisation plus profonde nécessite des racines explicites. [Découverte][DISCOVERY]

**Le périmètre `--repo` n'est pas une frontière de confidentialité.** Le programme découvre les fichiers récents, les parse, puis filtre selon le `cwd` reconstruit. D'autres projets peuvent donc être lus avant d'être exclus de l'inventaire et de l'échantillon. De plus, l'appartenance accepte aussi le nom du dépôt parmi les composants du chemin, au-delà de sa racine réelle : des dépôts homonymes peuvent se mélanger. C'est un compromis assumé pour retrouver worktrees et chemins importés, inadapté comme séparation entre organisations. [Ordre lecture puis filtrage][COLLECTFLOW], [Appartenance au dépôt][MATCH]

Warp bénéficie d'une ouverture SQLite avec `mode=ro` et `PRAGMA query_only`. Son lecteur décode un sous-ensemble du format protobuf persistant, sans bibliothèque protobuf externe ; les champs inconnus sont ignorés. Les conversations non décodables sont signalées puis exclues. La limite de 32 Mio sur les blobs de tâches est vérifiée après leur chargement : c'est une limite de décodage, pas une garantie de mémoire maximale du scan. [SQLite][SQLITE], [Chargement][WARPLOAD], [Décodeur][DEC]

### 3. Ce que voit réellement le juge

Le discours demande transcriptions, appels d'outils et artefacts. Skill Doctor fournit bien des messages et des appels/résultats d'outils, mais **sous une forme textuelle réduite** :

- Messages limités à `1 500` caractères ; arguments et résultats d'outils limités à `500` caractères.
- Au-delà de `160` entrées, conservation du début (`100`) et de la fin (`40`), avec un marqueur d'omission du milieu.
- Statistiques de tours, appels répétés, sorties contenant des indices d'erreur et présence probable d'éditions.
- Métadonnées de session et skills détectés. Le rendu normalisé n'est pas un graphe causal des appels avec identifiants, durées et timestamps par événement. [Bornes et buffer][BOUNDS], [Rendu de transcription][TRANSCRIPT]

Un gros `apply_patch`, une sortie de tests ou une erreur corrective peut disparaître après quelques centaines de caractères. Le programme ne récupère pas automatiquement le diff final d'une PR à un SHA donné et n'exécute pas les tests du projet pour le juge. Il déduit seulement un indice d'édition à partir des noms d'outils et de leurs arguments. La rubrique qualité prévoit justement `insufficient_evidence` lorsque le code visible ne suffit pas. [Lecteur Codex][CODEX], [Rubrique qualité][QUALITY]

Les appels « répétés » sont comptés par identité du nom et des arguments, sans comprendre si une répétition est utile. Les sorties « error-ish » sont reconnues notamment par des mots tels que `error`, `failed` ou `traceback`. Un résultat indiquant zéro erreur peut contenir ces mots ; une répétition peut être une vérification nécessaire après modification. Ces compteurs orientent une inspection, ils ne démontrent pas un gaspillage. [Heuristiques Claude][CLAUDE], [Heuristiques Codex][CODEX]

La conformité présente une difficulté supplémentaire : le lecteur élimine certaines injections de contexte et ne conserve pas systématiquement les instructions système historiques. La rubrique demande pourtant de ne juger que les règles visibles et applicables, et donne la meilleure classification si aucune n'est visible. Une bonne note peut donc refléter l'absence de preuve de règle, plutôt que sa bonne application. [Filtre de contexte][INJECT], [Rubrique conformité][COMPLY]

### 4. Rubriques et conception du juge

| Dimension | Labels et scores bruts | Objet du jugement |
| --- | --- | --- |
| Efficacité | `1`, `0.8`, `0.4`, `0.2` | Trajet vers le résultat, reprises, attention humaine, recherches, regroupement des appels, vérification |
| Qualité du code | `approve=1`, `block=0.2`, `insufficient_evidence=0.5` | Code réellement visible, conventions du dépôt, défauts, tests, commentaires, hygiène du diff |
| Conformité | `1`, `0.8`, `0.2` | Règles et skills réellement applicables ; une violation protectrice suffit à disqualifier |
| Verbosité | `proportionate=1`, `verbose=0.2`, `terse=0.1` | Proportion de la communication, répétition, silences et informations nécessaires |

Sources des quatre lignes : [efficacité][EFF], [qualité][QUALITY], [conformité][COMPLY], [verbosité][VERBOSE].

Le juge doit expliquer son choix avec des éléments de la session. Il n'a ni modèle imposé, ni température imposée, ni campagne de calibration livrée avec le workflow. Le répertoire contient des tests du collecteur et du rendu, qui ne constituent pas une validation de la précision des jugements. Cette recherche a inspecté leurs sources ; elle ne les a pas exécutés. [Instruction de scoring][SDSCORE], [Tests de collecte][TESTCOL], [Tests de rendu][TESTREPORT]

Deux biais sont visibles dans les rubriques elles-mêmes. L'efficacité évalue aussi des obstacles évitables avec de meilleurs outils, même si l'agent ne pouvait pas les éviter avec sa configuration immédiate. La qualité pénalise une erreur signalée puis corrigée par l'utilisateur, tout en se présentant comme un jugement de l'artefact. Ces choix peuvent être utiles, mais mélangent qualité finale, coût du processus et qualité de l'environnement. Il faut les expliciter avant de comparer des agents. [Efficacité][EFF], [Qualité, paragraphe « Corrections »][QUALITY]

La référence sur les améliorations réduit heureusement le risque d'ajouter une règle à chaque mauvaise note : vérifier chaque constat, regrouper par cause, prioriser fréquence × gravité, préférer remplacer plutôt qu'ajouter. Une proposition exige une lacune d'instruction concrète, répétée dans plusieurs runs ou suffisamment grave. Un modèle qui ignore une règle déjà correcte, une variance de modèle ou une panne d'infrastructure ne justifient pas une réécriture de skill. [Méthode et exclusions][IMP]

Il demeure une tension : le workflow principal suggère assez vite un problème de description lorsqu'un skill ne s'est pas déclenché, alors que cette référence impose une attribution plus stricte. Une absence de détection ne suffit pas à établir un déclenchement manqué. [Suggestions][SDSCORE], [Seuil de justification][IMP]

### 5. Échantillonnage, coût et note finale

Les valeurs par défaut sont **45 jours, 12 sessions, un quota de sélection de 3 par skill et 4 sessions sans skill**. La fenêtre JSONL repose sur la date de modification du fichier ; Warp utilise la date de modification en base. Une copie récente d'un vieux fichier peut donc entrer dans la fenêtre sans que ses interactions soient récentes. [Arguments][ARGS], [Découverte des fichiers][FILES], [Recherche Warp][SQLITE]

La sélection parcourt les sessions de la plus récente à la plus ancienne. Elle choisit d'abord celles dont un skill détecté conserve du quota, puis celles sans skill. Le code incrémente un seul compteur de skill par session sélectionnée : ce sont des quotas de sélection, pas une garantie stricte de trois occurrences observées par skill dans le résultat. Il n'y a pas de graine aléatoire ni de pondération pour restituer la distribution réelle. Le total obtenu peut être inférieur à douze. [Algorithme de sélection][SAMPLE]

Les sessions sans au moins un tour assistant et un appel d'outil sont écartées. Le collecteur conserve des comptes distincts pour fichiers vus, sessions dans le périmètre, sessions considérées et sessions échantillonnées. Ces dénominateurs sont indispensables pour annoncer la couverture. Le plafond de sessions borne surtout le travail du juge ; il ne borne pas le nombre de fichiers parsés en amont. [Flux de collecte][COLLECTFLOW], [Inventaire final][INVENTORY]

Jusqu'à 50 transcriptions, le skill prescrit un lot unique ; au-delà, des lots parallèles d'environ 20. Les quatre rubriques peuvent être appliquées au même lot : **quatre rubriques ne signifient pas nécessairement quatre appels de modèle par session**. Aucun plafond monétaire ni compteur de tokens n'est implémenté par les scripts de collecte et de rendu. Le coût dépend du harness, de l'inférence, de la longueur du contexte et du travail de proposition. [Scoring par lots][SDSCORE], [Scripts disponibles][WTREE]

Les quatre moyennes qualitatives sont transformées selon :

`score_affiché = 0.5 + 0.5 × moyenne_brute`

La couverture représente la proportion des sessions échantillonnées dans lesquelles au moins un skill installé est détecté. La note globale combine efficacité `25 %`, qualité `25 %`, conformité `20 %`, verbosité `15 %` et couverture `15 %`. En revanche, le filtre des échecs utilise bien les scores **bruts**, seuil strictement inférieur à `0.5`. [Formules][SDSCORE]

Conséquences calculées de ces formules, sans résultat expérimental :

- Un `block=0.2` devient `0.6`, soit 60/100 dans la dimension affichée.
- Sans aucune session jugeable pour la qualité, le fallback brut `0.5` devient 75/100.
- La couverture peut augmenter la note globale sans prouver que les skills ont amélioré le résultat.
- Les transformations et poids sont des conventions de présentation ; un 85/100 n'est pas « 85 % des tâches réussies ». Le générateur associe simplement des lettres à des seuils prédéfinis. [Agrégation][SDSCORE], [Lettres][GRADE]

### 6. Factories : produit documenté, distinct du skill local

Un scorer Factories classe les runs terminés des agents choisis, à partir d'une rubrique, de labels associés à des scores, d'un modèle juge et d'un seuil. L'échantillonnage automatique intervient après la fin du run ; l'interface permet aussi un scoring à la demande. **Re-scoring remplace le résultat précédent du même scorer**, ce qui compte pour une étude de dérive. Le déclencheur n'est donc pas nécessairement la fusion d'une PR. [Configuration des scorers][FSCORE]

Dans la définition versionnée, `samplingRate` vaut 10 % par défaut, accepte 0–100 et zéro coupe le scoring automatique. `selfImprovement` est désactivé par défaut. Les enfants ne sont inclus comme preuves que si la sélection de l'agent le demande avec `includeDescendants`. Le scorer peut disposer de runner, secrets et MCP propres : le juge peut donc avoir des accès à gouverner. [Syntaxe des scorers][FSYNTAX]

Pour les scorers activés dans la boucle, le contrôle planifié déclenche par défaut une investigation après **25 échecs distincts non traités par agent**, ou si le plus ancien attend depuis **7 jours**. Le seuil est configurable de 1 à 50 pour une factory liée à GitHub. Le lancement manuel peut partir d'un seul échec et ne permet pas de choisir les agents ou échecs traités. La suite propose des PR sur l'application ou la définition de la factory, avec liens vers les régressions. [Self-improvement][FSI]

Cela peut modifier prompts, skills et configuration versionnés, au-delà des seuls skills. La documentation présente l'adoption comme soumise à revue ; les protections de branche et permissions du dépôt restent la frontière effective pour imposer une revue humaine. Un texte d'agent n'est pas une protection de merge. La fréquence « chaque 24 heures » du discours ne doit pas remplacer les seuils documentés actuels. [Fonctionnement et contrôle des merges][FHOW], [Déclenchement actuel][FSI]

Factories documente aussi des benchmarks : tâches fixes, critères de correction, configurations et répétitions ; les essais terminaux sont évalués et les entrées du benchmark sont conservées. C'est une capacité distincte du diagnostic de production. Les coûts incluent essais et scorers, avec des estimations potentiellement incomplètes pour l'inférence externe. [Benchmarks][FBENCH]

**Niveau de preuve :** ces détails sont des contrats de documentation officiels, pas une inspection du backend ni un essai sur une factory. Le dépôt Skill Doctor ne permet pas de prouver la fidélité du service à ces contrats, sa fréquence réelle, son coût ou ses gains. Le témoignage de réduction du coût par PR et les chiffres illustratifs de la page commerciale n'établissent ni un protocole contrôlé ni un gain transférable à Etabli. [Présentation et témoignage][LAND], [Documentation de la boucle][FMEASURE]

## Limites

### Confidentialité et confiance dans les entrées

Le collecteur n'offre pas de redaction automatique des secrets : il tronque du texte mais ne le nettoie pas. Son inventaire conserve chemins et identifiants ; les transcriptions et les diffs peuvent contenir du code ou du contexte confidentiel. Le rapport reprend les preuves et changements proposés sans filtre de confidentialité. « Partageable » décrit son format, pas une validation de son contenu. [Collecteur][COL], [Contenu rendu][REPORT]

Le workflow interdit explicitement les uploads et réserve la délégation à des enfants locaux. Cette consigne ne transforme pas un harness connecté à un modèle distant en système d'inférence locale. Elle ne fournit pas non plus de rétention automatique ou de nettoyage des artefacts en fin de traitement. La garantie démontrée ici est limitée à la conception du workflow et des scripts examinés ; aucun contrôle réseau dynamique n'a été effectué. [Confidentialité et délégation][SD], [Écritures du collecteur][INVENTORY], [Sortie][SDDRAFT]

Les anciennes conversations et sorties d'outils doivent être considérées comme des données non fiables. Le filtre `looks_injected` retire certains préambules connus ; ce n'est pas une défense générale contre une instruction malveillante contenue dans un historique. **Proposition de précaution** : séparer le lecteur/juge sans permissions d'écriture de l'acteur autorisé à préparer un correctif, et interdire au contenu de trace de modifier les consignes du juge. C'est une recommandation issue de la frontière observée, pas une garantie revendiquée par le code. [Filtre réel][INJECT], [Travail confié à l'agent][SDSCORE]

L'auto-hébergement Factories ne résout pas toutes ces frontières. Warp distingue calcul, inférence et stockage ; le plan de contrôle reste chez Warp. Le stockage client, réservé à Enterprise, peut recevoir séparément traces, artefacts et pièces jointes ; les catégories non configurées restent chez Warp. Warp conserve l'accès nécessaire, notamment pour les scorers. Un bucket client n'implique donc ni traitement hors de Warp, ni absence de lecture par Warp. [Infrastructure][FINFRA], [Stockage][FSTORAGE]

### Validité des scores et causalité

Les principaux facteurs de confusion sont déjà visibles : échantillonnage privilégiant l'usage détecté, lecture d'instructions actuelles pour expliquer des sessions passées, perte du milieu des traces, manque de diff complet et conformité jugée à partir d'un contexte partiel. Une recommandation doit distinguer **défaut observé**, **cause plausible** et **cause vérifiée**. [Sélection][SAMPLE], [Condensation][BOUNDS], [Attribution actuelle][IMP], [Conformité][COMPLY]

Une inflexion d'un dashboard après fusion d'une règle reste compatible avec un changement de modèle, de tâches ou de juge. Warp recommande lui-même baseline, inspection des échecs, benchmark d'un candidat et adoption d'un changement mesurable à la fois ; sa documentation déconseille de tirer une causalité du seul dashboard. [Méthode Warp][FMEASURE]

L'évaluation de la qualité du résultat et celle du processus doivent rester séparées. Anthropic distingue notamment la trace de l'état final effectivement obtenu, recommande plusieurs essais pour la variabilité, et décrit la calibration humaine des juges. Cette source soutient l'emploi conjoint de tests et de jugements, pas la substitution d'une note LLM à une preuve de fonctionnement. [Guide d'évaluation des agents][ANTH]

### Dépendances et disponibilité

Skill Doctor annonce Python 3.9+ et utilise la bibliothèque standard, un décodeur local et un bundle JavaScript de diffs embarqué. Git sert à résoudre les racines de dépôt ; le navigateur est optionnel pour ouvrir le HTML. Le rendu échoue si le bundle `@pierre/diffs` n'est pas présent ; il n'est pas téléchargé à ce moment. Il faut aussi un agent capable de suivre la procédure et d'effectuer l'inférence. Le code du dépôt est sous licence MIT ; une reprise substantielle doit conserver sa notice. [Imports][COL], [Dépendance du rendu][RENDERDEPS], [Licence][LICENSE]

Ni le SDK Factories, ni un bucket central, ni GEPA ne sont requis par ce skill. À l'inverse, utiliser Factories implique les dépendances opérationnelles du service et ses frontières de données ; ce n'est pas une simple option du collecteur. La présence de lecteurs testés ne prouve pas que tous les historiques du poste seraient collectés correctement. [Code du skill][WTREE], [Architecture Factories][FINFRA]

## Pratiques apparentées : GEPA et Reflexion

### GEPA : optimiser des candidats avec une évaluation répétable

Papier examiné : **arXiv:2507.19457v2**, 14 février 2026. Dépôt officiel actuel examiné au commit **`cb7674c8b231270134b8e5ea8b9db1a62ed8d081`**. Le code actuel a évolué depuis le papier ; les deux ne sont pas traités comme des versions identiques. [Papier][GPAPER], [Commit][GCOM]

GEPA propose des changements textuels à partir de trajectoires et de feedback, teste les candidats, puis utilise une sélection diversifiée fondée sur leurs performances par tâche. Le papier sépare données de feedback, données de sélection Pareto et mesure sur un jeu tenu à l'écart. L'apport par rapport à une simple rétrospective est de **tester une proposition avant de la retenir**, avec un budget d'évaluations. [Méthode originale][GPAPER]

Le code expose `GEPAAdapter.evaluate` et `make_reflective_dataset` : l'intégrateur fournit scores et traces, puis les données pertinentes à la réflexion. Le contrat distingue évaluation sur minibatch et validation. Des sélecteurs Pareto sont implémentés ; les mutations évaluent parents et enfants avec capture des traces. Ce n'est donc pas seulement un prompt de conseil. [Adapter][GADAPTER], [Sélection][GSELECT], [Mutation][GMUTATE]

Les prérequis sont un évaluateur pertinent, des tâches rejouables, des artefacts candidats et un environnement permettant de les tester sans effets indésirables. Le package de base déclare Python 3.10–3.14 et aucune dépendance obligatoire ; des extras apportent notamment clients LLM et frameworks. Les critères d'arrêt comprennent nombre d'évaluations, temps, absence de progrès et coût de réflexion. Ce dernier ne représente pas, à lui seul, tout le coût d'exécution de l'évaluateur. [Dépendances][GDEPS], [Arrêts][GSTOP]

**Limite de transfert :** les résultats du papier concernent ses tâches, modèles, métriques et budgets. Ils ne démontrent pas que GEPA réduirait le coût d'Etabli, ni qu'un score de style fournirait un bon signal d'optimisation. La sélection consulte la validation à répétition : garder une évaluation finale indépendante demeure nécessaire. Aucun chiffre de gain n'est retenu comme prévision locale. [Protocole du papier][GPAPER], [Contrat de validation][GADAPTER]

### Reflexion : mémoire de feedback entre tentatives

Papier examiné : **arXiv:2303.11366v4**, 10 octobre 2023. Dépôt officiel examiné au commit **`218cf0ef1df84b05ce379dd4a8e47f17766733a0`**. Reflexion fait produire une réflexion textuelle après évaluation et la transmet aux tentatives suivantes, sans apprentissage des poids. C'est une adaptation du contexte et de la mémoire, pas nécessairement une modification des instructions partagées d'une équipe. [Papier][RPAPER], [Dépôt][RREADME]

Le code de programmation enchaîne génération, tests internes, feedback, réflexion et révision dans une boucle bornée par les paramètres d'itération. Il journalise implémentations et réflexions. L'exemple ALFWorld ajoute des leçons aux environnements non résolus et expose les trois dernières réflexions au générateur de la suivante. Cette mécanique est concrète mais spécifique à ses expériences. [Boucle de programmation][RCODE], [Mémoire ALFWorld][RMEM]

Le papier décrit des faux positifs dus aux tests générés par le modèle, des minima locaux et des limites liées aux tâches non déterministes ou concurrentes. Son ablation montre aussi qu'une réflexion sans signal de test fiable peut dégrader le résultat. Le README avertit du coût des reproductions originales. Ces limites excluent l'idée qu'une auto-critique libre garantirait une amélioration. [Analyse et limites][RPAPER], [Coût de reproduction][RREADME]

**Ce qui se transfère comme méthode** : conserver une leçon explicite reliée à un échec et à une vérification. Ce qui ne se transfère pas sans expérience : les performances rapportées sur les benchmarks, le nombre optimal de tentatives ou la fiabilité de souvenirs accumulés au fil de toutes les tâches. [Méthode et périmètre expérimental][RPAPER]

## Deux compléments utiles : ACE et les évaluations de trajectoires

### ACE : modifier les leçons par petits écarts

Le papier original **Agentic Context Engineering**, version `2510.04618v1` du 6 octobre 2025, sépare production de trajectoire, réflexion et curation. Il traite le contexte comme un ensemble d'entrées identifiées ; les changements locaux sont ensuite fusionnés par du code, au lieu de réécrire tout le contexte à chaque passage. Il prévoit aussi une déduplication. C'est une méthode d'adaptation du contexte, pas une preuve sur les workflows d'Etabli. [Papier ACE][ACE]

La pratique à retenir serait une proposition ciblée et réversible sur la leçon concernée, en préservant les décisions encore valides. Il ne faut pas en déduire que davantage de mémoire est toujours meilleur : le papier reconnaît qu'un mauvais Reflector peut produire un contexte bruité ou nuisible. Pour Etabli, le principe de modifications locales est compatible avec le contrat existant qui demande de supprimer les paragraphes sans effet. Les performances des expériences ACE ne sont pas transposées ici. [Limites ACE][ACE], [Conception des skills Etabli][ESKILL]

### LangSmith : séparer observation réelle et non-régression

Les concepts documentés distinguent évaluations sur des cas de référence et évaluations sur les traces de production. Les annotations humaines peuvent alimenter ensuite un jeu de régression versionné. Le tutoriel distingue résultat final, trajectoire d'appels et étape isolée. L'intérêt pour Etabli est cette séparation des preuves ; elle n'exige pas d'adopter la plateforme. [Concepts][LSCONCEPT], [Évaluer un agent][LSTRAJ]

Les évaluateurs multi-tours documentent l'assemblage d'une conversation et la déduplication des historiques répétés. Ils montrent aussi qu'une tâche traversant plusieurs tours ne se réduit pas à son dernier message. Une correspondance stricte de séquence d'outils serait toutefois trop rigide pour un workflow où plusieurs chemins peuvent être valides. Anthropic recommande de privilégier le résultat lorsque la séquence n'est pas une exigence métier. [Multi-tours][LSMULTI], [Pièges d'évaluation][ANTH]

Ces pratiques donnent une boucle concrète : trace réelle → annotation vérifiée → cas de régression → comparaison d'un candidat. Il faut conserver séparément les cas ayant servi à concevoir la correction et ceux destinés à vérifier qu'elle généralise. Un contrôle déjà vu devient un test de non-régression, pas une preuve de généralisation. [Évaluation GEPA][GPAPER], [Contrat Etabli][EREVIEW]

## Propositions d'adoption

Cette section est une **proposition pour discussion**, pas un plan d'exécution ni l'affirmation qu'Etabli manque de ces capacités. Aucun nouveau composant, collecteur, job ou calendrier n'est créé.

### Retenir d'abord l'attribution, pas la note globale

L'unité de travail proposée est : **un défaut vérifié → une cause → une surface propriétaire → une modification minimale → une évaluation indépendante**. La règle « ne rien proposer quand aucune lacune d'instruction n'est démontrée » mérite d'être conservée. Une règle déjà claire mais ignorée appelle d'abord une analyse du suivi des instructions ou du contrôle, pas un nouvel alinéa. [Justification upstream][IMP]

Pour une première expérimentation, privilégier un problème observable et fréquent, par exemple des appels échoués dus à une commande obsolète. Mesurer séparément occurrences, temps perdu et résultat de la tâche. Les défauts de confidentialité ou de permission seraient des critères éliminatoires, sans compensation par une bonne moyenne de style. Les rubriques de conformité et d'efficacité fournissent des points de départ, à adapter au contrat local. [Efficacité][EFF], [Conformité][COMPLY]

### Conserver une preuve exploitable et une possibilité d'abstention

Proposition de contenu minimal pour une observation, indépendamment de son format futur :

| Élément | Raison |
| --- | --- |
| Référence de run et plage d'événements | Retrouver le fait sans copier l'historique dans le dépôt |
| Harness, modèle et version des instructions chargées | Éviter une attribution à la mauvaise configuration |
| Rubrique, version et modèle du juge | Comparer des jugements portant sur le même critère |
| Statut complet, partiel, indisponible ou non applicable | Ne pas convertir l'absence de preuve en succès |
| Label, justification, gravité et surface propriétaire | Relier le diagnostic à une correction admissible |
| Diff final et vérification accessibles par référence privée | Évaluer le résultat, au-delà d'un récit de réussite |
| Coût et durée réellement mesurés, couverture par source | Séparer gain de qualité, économie et données manquantes |

Cette proposition répond aux pertes observées dans le format condensé et à la distinction entre trace et résultat. Elle n'exige pas de publier les données brutes. Pour juger une portion de code omise, il faudrait pouvoir consulter la preuve privée utile, plutôt qu'inventer une conclusion à partir de 500 caractères. [Format actuel][TRANSCRIPT], [Preuve insuffisante][QUALITY], [Trace et résultat][ANTH]

### Séparer diagnostic ciblé et mesure représentative

Un lot ciblé d'échecs aide à comprendre une cause ; il ne permet pas d'estimer un taux global de défauts. Pour mesurer une évolution, proposer un échantillon reproductible stratifié par harness, famille de tâche et période, avec échecs, réussites et abstentions. Dédupliquer racines, enfants et reprises pour éviter de compter plusieurs fois le même incident. Garder les cas de contrôle hors de la génération de propositions. C'est une réponse méthodologique aux biais du collecteur, pas une fonctionnalité qu'il fournit. [Sélection actuelle][SAMPLE], [Exclusion des sessions][COLLECTFLOW], [Évaluation indépendante GEPA][GPAPER]

Avant l'automatisation, comparer quelques jugements à une annotation humaine et examiner faux positifs, faux négatifs et désaccords. Une taille de pilote se choisit selon le volume et le risque locaux ; les 12 sessions de Skill Doctor ne constituent pas une justification statistique. Ne modifier qu'un levier à la fois et conserver un juge stable pendant la comparaison. [Calibration et baseline recommandées par Warp][FMEASURE], [Guide Anthropic][ANTH]

### Borner le coût et vérifier le bénéfice

Proposition de comptabilité : **collecte + scoring + analyse des causes + génération du candidat + replays de validation + revue**. Un taux d'échantillonnage réduit surtout le scoring ; les simulations et replays peuvent dominer le coût. Aucun budget en euros ne peut être déduit du nombre de rubriques seul. Prévoir une borne d'exécutions et de durée, ainsi qu'un budget de dépense explicite avant toute expérimentation payante. [Lots Skill Doctor][SDSCORE], [Coût des benchmarks][FBENCH], [Arrêts GEPA][GSTOP]

La décision d'adopter devrait s'appuyer sur le défaut ciblé réduit, aucune régression sur les contrôles, et un coût net acceptable. Une hausse du score affiché serait un signal secondaire. Le bénéfice net inclut le temps humain économisé et soustrait le coût de diagnostic, de validation et de maintenance des instructions. Ces éléments sont à mesurer localement, pas à reprendre d'un témoignage. [Pratique d'amélioration Warp][FMEASURE], [Limites du témoignage][LAND]

### Dépendances à accepter seulement après preuve du besoin

- **Skill Doctor :** utile comme référence de procédure et de rubriques. Une exécution inchangée demanderait d'abord de résoudre périmètre de lecture, inférence, redaction, représentativité et fidélité des traces. [Workflow][SD], [Collecteur][COL]
- **Factories :** pertinent si l'équipe veut sa plateforme d'exécution, ses intégrations et sa gouvernance de données. La boucle d'analyse ne justifie pas à elle seule cette adoption. [Architecture][FINFRA], [Stockage][FSTORAGE]
- **GEPA :** pertinent après disponibilité d'un évaluateur fiable et de tâches rejouables ; prématuré si la seule métrique est une impression LLM non calibrée. [Contrat de l'adapter][GADAPTER]
- **Reflexion :** inspiration pour des leçons bornées et testables entre essais ; aucune raison d'assimiler une mémoire rédigée automatiquement à une instruction durable déjà validée. [Boucle réelle][RCODE], [Limites][RPAPER]

## Application à Etabli : réutiliser les contrats présents

Inspection de sources au commit `9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7`. Le checkout de départ était propre sur sa branche `chore/pi-plugins` ; les observations sur la livraison récente ont été lues explicitement sur `origin/main`. Cette recherche ne teste ni l'adoption réelle de ces règles ni un gain de qualité ou de tokens.

| Besoin issu du talk | Surface Etabli existante | Ce qui reste à vérifier ou à améliorer |
| --- | --- | --- |
| Relier un défaut à une action admissible | `workflow/templates/escaped-defect.md` classe les défauts trouvés après revue et prévoit notamment `retrieval_change`, `contract_change`, `project_constraint`, `no_op` | Les erreurs récupérées pendant le travail ne sont pas nécessairement des défauts échappés : conserver cette distinction au lieu de les faire artificiellement entrer dans ce registre. [Source][EESCAPED] |
| Éviter l'accumulation de règles | `workflow/project-constraints.md` privilégie types, lint, tests et CI avant la prose, avec un cas échouant avant correction | Vérifier que le contrôle tourne dans la vraie commande du projet. Une consigne supplémentaire n'est pas le bon remède si un outil peut imposer la règle. [Source][ECONSTRAINT] |
| Tester une modification du dispositif de revue | `workflow/skills/review.md`, section Effectiveness comparison, définit cas figés, indépendance, contrôles, cas réservés et comptabilité des coûts | Mettre ce contrat en pratique pour le défaut ciblé. Il ne prouve pas qu'un corpus indépendant est actuellement disponible. [Source][EREVIEW] |
| Préserver la preuve en limitant le contexte | `workflow/skills/investigation.md` distingue observation, hypothèse et causalité ; la livraison workflow-efficiency conserve sorties privées et références décisives | Vérifier que le juge peut demander le segment décisif omis et marquer la preuve insuffisante. La troncature de transport ne doit pas devenir une conclusion sur la qualité. [Source][EINVEST], [Livraison documentée][EEFF] |
| Éviter de répéter une revue déjà valide | Livraison workflow-efficiency : réutilisation sous empreinte et journaux liés au SHA de PR | Ce sont des supports d'analyse, pas une mesure de gain déjà acquise ni un motif pour supprimer un axe de revue. [Source][EEFF] |
| Garder les skills courts et déclenchables | `workflow/skill-design.md` sépare procédure et références et impose un test de suppression de paragraphe | Auditer d'abord la surface réellement chargée et sa version. Le contenu actuel d'un fichier ne démontre pas qu'il était visible dans une ancienne session. [Source][ESKILL] |

Le complément utile concerne donc la **liaison vérifiable entre incident, cause, surface et résultat d'une correction**. Cette inspection n'autorise pas à déclarer qu'il manque un nouveau scheduler, une nouvelle plateforme de mémoire ou un second analyseur. Fleet conserve la responsabilité de son dispositif dans l'autre thread.

### Priorités proposées, sans mise en œuvre

1. **Faire apparaître les incidents récupérés.** Sur un petit lot privé de tâches terminées, reconstruire le moment de l'erreur, sa récupération, le résultat final et les preuves disponibles. Séparer outil indisponible, environnement, instruction absente, instruction ignorée, contrôle défaillant et test volontairement rouge. Un signal lexical déclenche une inspection, jamais une correction automatique. Conserver les cas sans conclusion.
2. **Calibrer quelques jugements sur des annotations vérifiées.** Mélanger réussites, incidents récupérés et échecs réels de tâches comparables. Vérifier les désaccords entre humain et juge avant de lui confier des propositions de modifications. Garder séparées correction finale, efficacité de trajectoire, respect des contraintes et qualité des preuves ; ne pas créer une moyenne globale qui compense un défaut critique par du style. [Calibration][ANTH], [Annotations et jeux de référence][LSCONCEPT]
3. **Router vers le correctif minimal.** Instruction réellement manquante : modifier son propriétaire. Règle claire mais ignorée : examiner chargement et application. Erreur mécaniquement évitable : ajouter un contrôle dans l'outil ou le projet concerné. Incident d'environnement : corriger cet environnement. Aucune cause vérifiée : ne rien changer. Ce sont des dispositions proposées ; elles réutilisent les surfaces ci-dessus. [Attribution upstream][IMP], [Contraintes][ECONSTRAINT]
4. **Vérifier chaque candidat sur des preuves figées.** Même tâche, même environnement pertinent, mêmes modèles et critères ; un facteur changé. Garder des contrôles et des cas qui n'ont pas servi à produire la correction. Le candidat ne modifie pas simultanément son juge, sa rubrique et les cas de test ; toute évolution de cette évaluation doit être identifiée séparément. Le replay de revue existant sert de contrôle de non-régression ; il ne suffit pas à lui seul à mesurer tous les effets d'un skill. [Contrat de comparaison][EREVIEW]
5. **Évaluer le gain net et la persistance.** Relier la correction à sa version livrée et aux usages suivants, après validation. Mesurer reprises et temps humain quand ils sont observables, coût des juges et revues, ainsi que longueur et lectures supplémentaires des instructions. Une instruction inutile ou contradictoire doit pouvoir être retirée. La comptabilité des tokens garde les catégories de cache séparées et ne prétend pas donner une facture sans tarifs et couverture vérifiés. [Comparaison Etabli][EREVIEW], [Conception des skills][ESKILL]

Ce pilote peut se limiter à trois familles de tâches existantes, par exemple correction bornée, plan-implémentation et revue. Une première sélection d'une vingtaine de tâches serait un exercice de calibration et de recherche de causes, **pas un échantillon établissant un taux global ou une économie attendue**. La taille doit ensuite être adaptée au volume, aux désaccords et au risque. Aucun seuil d'adoption numérique ne découle du talk.

### Ce qu'un rapport utile devrait rendre visible

Proposition de contrat d'information à discuter avec le dispositif qui produit déjà les rapports ; aucun format ou job n'est ajouté ici :

- **Couverture** : période, sources, tâches éligibles et inspectées, segments absents ou tronqués, enfant/reprise dédupliqués.
- **Résultat** : tâche achevée ou non, diff au SHA exact, vérifications et défauts confirmés ; état inconnu explicite.
- **Friction** : incidents récupérés et non récupérés, fréquence par tâche, temps mesuré lorsqu'il existe, cause observée ou seulement supposée.
- **Jugement** : dimension, label, version de rubrique et modèle du juge, preuves privées référencées, niveau de suffisance et éventuel désaccord humain.
- **Ressources** : catégories de tokens natives et coût du dispositif d'amélioration lui-même ; dépenses monétaires seulement si elles sont vérifiables.
- **Suivi** : décision de ne rien faire ou changement proposé, surface propriétaire, version des instructions réellement connue, validation et résultat postérieur.

La meilleure inspiration du talk est ce chemin de preuve. Le résultat recherché n'est pas d'obtenir une nouvelle règle chaque matin, mais de rendre les défauts moins fréquents sans augmenter les reprises, les risques ou le coût total. L'exécution des systèmes Warp/GEPA/Reflexion/ACE sur le corpus local reste **non évaluée**.

## Sources

Toutes les références techniques ci-dessous renvoient à des sources primaires. Les liens de code sont figés aux SHA indiqués ; les pages de documentation sont datées par leur consultation et peuvent évoluer.

### Warp : code Skill Doctor figé

- [Commit examiné][WCOM] et [répertoire complet][WTREE].
- [SKILL.md : procédure][SD], [harnesses et chemins][HAR], [conditions d'amélioration][IMP].
- [Collecteur][COL], [décodeur Warp][DEC], [rendu HTML][RENDERDEPS].
- [Rubrique efficacité][EFF], [qualité du code][QUALITY], [conformité][COMPLY], [verbosité][VERBOSE].
- [Tests du collecteur][TESTCOL], [tests du rendu][TESTREPORT], [licence MIT][LICENSE].

### Warp : documentation et présentation

- [Skill Doctor : présentation commerciale][LAND].
- [Scorers][FSCORE], [Self-improvement][FSI], [syntaxe de définition][FSYNTAX].
- [Fonctionnement des factories][FHOW], [mesurer et améliorer][FMEASURE], [benchmarks][FBENCH].
- [Infrastructure, inférence et permissions][FINFRA], [stockage des données d'exécution][FSTORAGE].

### Méthodes apparentées et évaluation

- [GEPA : papier v2][GPAPER], [dépôt au commit examiné][GCOM], [adapter][GADAPTER], [sélecteur][GSELECT], [mutations][GMUTATE], [arrêts][GSTOP], [dépendances][GDEPS].
- [Reflexion : papier v4][RPAPER], [README figé][RREADME], [boucle de programmation][RCODE], [mémoire ALFWorld][RMEM].
- [Anthropic : Demystifying evals for AI agents][ANTH].

[WCOM]: https://github.com/warpdotdev/common-skills/commit/8792394ff1b655e0af451b8fabb68ef0cfcbd208
[WTREE]: https://github.com/warpdotdev/common-skills/tree/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor
[SD]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/SKILL.md
[SDSCORE]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/SKILL.md#L90-L120
[SDDRAFT]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/SKILL.md#L122-L184
[HAR]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/references/supported-harnesses.md
[IMP]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/references/skill-improvements.md
[COL]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py
[ARGS]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L41-L106
[DISCOVERY]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L137-L183
[FILES]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L186-L222
[BOUNDS]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L29-L38
[CLAUDE]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L300-L431
[INJECT]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L434-L443
[CODEX]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L446-L537
[SQLITE]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L599-L662
[WARPLOAD]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L898-L985
[PI]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L1091-L1228
[TRANSCRIPT]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L1440-L1460
[MATCH]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L1463-L1487
[COLLECTFLOW]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L1575-L1645
[SAMPLE]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L1843-L1889
[INVENTORY]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/collect_sessions.py#L1876-L1932
[DEC]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/warp_decoder.py
[RENDERDEPS]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/render_report.py#L1-L106
[REPORT]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/render_report.py#L228-L317
[PNG]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/render_report.py#L523-L544
[GRADE]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/render_report.py#L23-L42
[EFF]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scorers/efficiency.md
[QUALITY]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scorers/code-quality.md
[COMPLY]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scorers/procedure-compliance.md
[VERBOSE]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scorers/verbosity.md
[TESTCOL]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/test_collect_sessions.py
[TESTREPORT]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/.agents/skills/skill-doctor/scripts/test_render_report.py
[LICENSE]: https://github.com/warpdotdev/common-skills/blob/8792394ff1b655e0af451b8fabb68ef0cfcbd208/LICENSE
[LAND]: https://www.warp.dev/skill-doctor
[FSCORE]: https://docs.warp.dev/factories/measure-and-improve/scorers/
[FSI]: https://docs.warp.dev/factories/measure-and-improve/self-improvement/
[FSYNTAX]: https://docs.warp.dev/factories/factory-as-code/#scorersnamescorermd
[FHOW]: https://docs.warp.dev/factories/how-factories-work/
[FMEASURE]: https://docs.warp.dev/factories/measure-and-improve/
[FBENCH]: https://docs.warp.dev/factories/benchmarks/
[FINFRA]: https://docs.warp.dev/factories/infrastructure-and-security/
[FSTORAGE]: https://docs.warp.dev/factories/self-hosting/data-storage/
[GPAPER]: https://arxiv.org/html/2507.19457v2
[GCOM]: https://github.com/gepa-ai/gepa/commit/cb7674c8b231270134b8e5ea8b9db1a62ed8d081
[GADAPTER]: https://github.com/gepa-ai/gepa/blob/cb7674c8b231270134b8e5ea8b9db1a62ed8d081/src/gepa/core/adapter.py
[GSELECT]: https://github.com/gepa-ai/gepa/blob/cb7674c8b231270134b8e5ea8b9db1a62ed8d081/src/gepa/strategies/candidate_selector.py
[GMUTATE]: https://github.com/gepa-ai/gepa/blob/cb7674c8b231270134b8e5ea8b9db1a62ed8d081/src/gepa/proposer/reflective_mutation/reflective_mutation.py
[GSTOP]: https://github.com/gepa-ai/gepa/blob/cb7674c8b231270134b8e5ea8b9db1a62ed8d081/src/gepa/utils/stop_condition.py
[GDEPS]: https://github.com/gepa-ai/gepa/blob/cb7674c8b231270134b8e5ea8b9db1a62ed8d081/pyproject.toml
[RPAPER]: https://arxiv.org/html/2303.11366v4
[RREADME]: https://github.com/noahshinn/reflexion/blob/218cf0ef1df84b05ce379dd4a8e47f17766733a0/README.md
[RCODE]: https://github.com/noahshinn/reflexion/blob/218cf0ef1df84b05ce379dd4a8e47f17766733a0/programming_runs/reflexion.py
[RMEM]: https://github.com/noahshinn/reflexion/blob/218cf0ef1df84b05ce379dd4a8e47f17766733a0/alfworld_runs/generate_reflections.py
[ANTH]: https://www.anthropic.com/research/demystifying-evals-for-ai-agents
[ACE]: https://arxiv.org/html/2510.04618v1
[LSCONCEPT]: https://docs.langchain.com/langsmith/evaluation-concepts
[LSTRAJ]: https://docs.langchain.com/langsmith/evaluate-complex-agent
[LSMULTI]: https://docs.langchain.com/langsmith/online-evaluations-multi-turn
[EESCAPED]: https://github.com/Tonours/etabli/blob/9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7/workflow/templates/escaped-defect.md
[ECONSTRAINT]: https://github.com/Tonours/etabli/blob/9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7/workflow/project-constraints.md
[EREVIEW]: https://github.com/Tonours/etabli/blob/9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7/workflow/skills/review.md#effectiveness-comparison-cold
[EINVEST]: https://github.com/Tonours/etabli/blob/9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7/workflow/skills/investigation.md
[EEFF]: https://github.com/Tonours/etabli/blob/9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7/docs/plan/20261107-workflow-efficiency.md
[ESKILL]: https://github.com/Tonours/etabli/blob/9ad2d5840a3148f2d70c11e9d6bbdd55d97a77b7/workflow/skill-design.md
