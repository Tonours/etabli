# Claude Code : réduire le contexte et la consommation sans déplacer le coût

Recherche documentaire du **9 novembre 2026**, pour Etabli. Sources techniques exclusivement Anthropic/Claude et dépôt officiel `anthropics/claude-code`. Aucun réglage changé, aucune inférence de comparaison lancée. **Gain réel mesuré : aucun.**

## Conclusion de recherche

La priorité proposée est de mesurer l'arbre d'exécution complet, puis de réduire les lectures et instructions inutiles. Un sous-agent peut protéger le contexte du parent tout en augmentant les tokens totaux. Remote Control sert surtout à continuer le travail depuis une autre interface ; son emplacement distant ne constitue pas une preuve d'économie. Ces distinctions découlent des architectures documentées ; leur effet dans Etabli reste à tester. [Sous-agents SDK][S06], [Remote Control][S09], [comptabilité SDK][S15].

La recherche documentaire est complétée par une inspection locale bornée en section 11 : sources Etabli, version CLI et champs de configuration non secrets. Les modèles, efforts et exigences de review sont conservés. L'activation globale de Sonnet reste différée jusqu'à validation CLI/IDE/SDK. Fleet est hors périmètre.

## 1. État des sources et plafond de preuve

Les pages ont été consultées pendant cette recherche le 9 novembre 2026. Leur contenu est évolutif ; une date de consultation n'est ni une date de publication ni une garantie de disponibilité pour un compte. Les pages sans date de publication exploitable sont traitées comme telles.

La dernière release GitHub renvoyée par l'API officielle est **v2.1.319**, publiée le **6 novembre 2026 à 17:04:01 UTC**. Le dernier commit modifiant `CHANGELOG.md` renvoyé par l'API est `0ed94698aa0aeee471465fc9c867c2e8434c4d68`, daté du **6 novembre 2026 à 17:03:45 UTC**. C'est un repère public, pas la version installée chez l'utilisateur. [Release][S01], [métadonnées release][S02], [métadonnées commit][S03].

Repères explicitement documentés utiles à une future vérification de compatibilité :

| Fonction | Version minimale ou changement documenté | Source |
| --- | --- | --- |
| Statistiques de cache du parent dans `/usage` | 2.1.251 ; indication de cause probable d'un miss : 2.1.260 | [Coûts][S04] |
| Totaux restaurés par reprise SDK/`-p` | Changement en 2.1.277 | [Comptabilité SDK][S15] |
| Fork via `Agent(subagent_type: "fork")` dans le SDK | 2.1.302 | [Sous-agents SDK][S06] |
| `omitClaudeMd` dans `AgentDefinition` TypeScript | SDK 0.3.271 ; champ absent de la définition Python documentée | [Sous-agents SDK][S06] |
| TTL distinct parent/autres requêtes | Réglages et variables : 2.1.242 | [Cache Claude Code][S12] |
| Ventilation OTel des écritures de cache 5 min/1 h | 2.1.300 | [Monitoring][S16] |

Le changelog 2.1.319 corrige aussi l'injection répétée de la grille visuelle de `/context` dans les tours ultérieurs. Les versions 2.1.314 corrigent des affichages de permission mode à distance ; 2.1.142 corrige des requêtes `set_model` redondantes injectant des marqueurs `/model`. Ce sont des corrections annoncées, sans mesure de gain dans Etabli. Le changelog n'est pas une inspection du code propriétaire du moteur. [Changelog figé][S27].

## 2. Mesurer quatre choses différentes

### Commandes de diagnostic

La référence actuelle regroupe `/cost` et `/stats` sous **`/usage`** ; `/stats` ouvre l'onglet Stats. `/context` examine l'occupation du contexte. `/status` expose notamment version, modèle et compte. Les anciennes descriptions « `/cost` pour API, `/stats` pour abonnés » ne décrivent donc plus exactement cette interface. La liste réellement exposée reste à vérifier dans chaque runtime. [Commandes][S07].

Dans `/usage`, les dollars de session sont une estimation locale aux prix catalogue, ou aux tarifs configurés par l'organisation ; ils ne sont pas une facture. Pour l'usage inclus d'un abonnement, les barres de plan sont la mesure pertinente. La ventilation par skills/sous-agents/plugins/MCP est une attribution : ses pourcentages peuvent se chevaucher et ne représentent pas des économies attendues. Les statistiques de cache « main » excluent les sous-agents. `/clear` remet les totaux de session à zéro depuis 2.1.211. [Coûts][S04].

### Grandeurs à conserver séparément

| Grandeur | Interprétation pour la comparaison |
| --- | --- |
| Contexte courant | Taille du prochain contexte ; ne résume pas tout le travail déjà effectué |
| Entrées cumulées | Toutes les entrées des requêtes, y compris les préfixes relus |
| Entrées non cachées / écritures / lectures de cache | Trois classes à garder distinctes, avec TTL des écritures |
| Sorties | Réponse et raisonnement facturables selon le modèle ; longueur visible insuffisante |
| USD estimés / USD facturés | Estimation du client / comptabilité du fournisseur |
| Consommation du plan | Progression et réinitialisation du quota de l'abonnement |
| Latence / travail utile validé | Temps et qualité ; deux axes supplémentaires |

L'API définit : `entrées totales = input_tokens + cache_creation_input_tokens + cache_read_input_tokens`. Le premier champ seul ne représente donc pas toutes les entrées. Les écritures et lectures n'ont pas le même prix ; une longue durée de cache augmente le prix d'écriture. Les tarifs doivent être ceux du modèle, du fournisseur et du régime effectifs. [Prompt caching API][S13].

Les tokens de thinking entrent dans les sorties facturées ; leur éventuel résumé visible ne révèle pas toute la quantité générée. Ne pas additionner une deuxième fois une estimation de thinking déjà incluse dans `output_tokens`. [Thinking][S26].

Les limites d'abonnement dépendent notamment du modèle, de l'effort et de la longueur/complexité ; elles sont partagées entre surfaces Claude, dont Claude Code. Une fenêtre de contexte et une limite d'usage sont deux contraintes différentes. La documentation consultée ne fournit pas de conversion universelle et reproductible « tokens/$API → pourcentage du plan ». [Limites][S17]. Une clé API configurée peut faire utiliser la facturation API plutôt que l'usage inclus : vérifier le mode d'authentification sans lire ni publier sa valeur. [Abonnements Claude Code][S18].

## 3. Contexte : réduire ce qui entre avant de résumer ce qui est entré

### Instructions, imports et chargement progressif

`CLAUDE.md` et ses imports `@chemin` sont chargés ensemble : découper un gros fichier en imports organise le texte sans le rendre différé. Les règles `.claude/rules/` sans `paths` sont chargées au démarrage ; les règles conditionnelles se chargent lors d'un accès correspondant. Une lecture de fichier peut déclencher le chargement de règles locales. Un YAML invalide peut faire charger une règle comme si elle n'avait pas de filtre. La documentation actuelle décrit aussi la prise en charge directe d'`AGENTS.md`, dépendante du choix des instructions et de la disponibilité de la fonction. [Mémoire et règles][S08].

Un skill ordinaire expose sa description au départ et son corps à l'invocation ; ses fichiers annexes permettent de garder les références hors du corps initial. **Une fois invoqué, son corps reste dans l'historique des tours suivants.** `disable-model-invocation: true` retire sa description du contexte automatique et réserve son déclenchement à l'utilisateur ; `user-invocable: false` masque seulement la commande utilisateur et conserve la découverte par le modèle. Le premier empêche aussi le préchargement du skill dans un sous-agent. `context: fork` dans un skill signifie exécution en sous-agent, pas nécessairement copie de l'intégralité de la conversation. [Skills][S10].

**Pistes Etabli, non appliquées :** vérifier les chemins réellement chargés, les descriptions encore automatiques et les procédures fréquemment invoquées trop tôt. Ne pas recommander de nouveau l'allègement déjà réalisé. Ne pas cacher les instructions indispensables à une review ou à une frontière de sécurité uniquement pour réduire un compteur.

La simulation officielle de contexte illustre le chargement des instructions, descriptions, lectures et résumés ; elle utilise des quantités représentatives. Ses valeurs ne constituent pas un benchmark de l'installation Etabli. [Simulation][S28].

### `/clear`, `/compact` et `/rewind`

| Action | Mécanisme documenté | Usage proposé, à comparer |
| --- | --- | --- |
| `/clear` | Nouvelle session, contexte conversationnel remis à zéro | Changement de sujet indépendant ; préserver auparavant décisions et pointeurs utiles |
| `/compact instruction` | Résumé orienté par la consigne ; instructions de compact possibles dans `CLAUDE.md` | Continuité d'une tâche longue, avec résultats de tests et contraintes préservés |
| `/rewind` : conversation | Retour à un point antérieur, sans obligation de restaurer le code | Abandon d'une piste inutile ; contrôler l'écart entre historique et fichiers |
| `/rewind` : résumé ciblé | Résumé depuis ou jusqu'à un point choisi | Éliminer une exploration verbeuse tout en conservant les échanges utiles |

Les deux premières actions sont décrites dans la [gestion des coûts][S04] ; les restaurations et résumés ciblés dans le [checkpointing][S11]. Ce dernier n'est pas un remplacement de Git : toutes les modifications Bash ou de sous-agents ne sont pas restaurées.

**Consigne de compact proposée**, sans modification de fichier : « Conserver objectif, décisions, contraintes, SHA cible, vérifications réellement exécutées et résultat, problèmes ouverts et prochaine action. Remplacer les gros outputs par leur chemin et le fait décisif. Ne pas transformer une hypothèse en preuve. » Le handoff visant 400 mots reste une cible de restitution, pas une limite sur la qualité de l'analyse.

**Hypothèse à falsifier :** compacter à une frontière naturelle pourrait réduire le coût des tours restants ; le coût du résumé, de la reconstruction du cache et des relectures pourrait annuler ce bénéfice sur une tâche courte. Ne pas programmer une compaction toutes les N minutes sans observation.

### Cache : une instruction statique n'est pas gratuite

Claude Code gère automatiquement un cache de préfixe côté fournisseur. Un changement de modèle peut invalider le cache ; une compaction réécrit l'historique. Un changement de permission mode le conserve, sauf s'il entraîne un changement de modèle avec `opusplan`. Sur certains modèles récents, l'effort peut changer sans casser le cache ; ce comportement dépend aussi du fournisseur et de la configuration.

Par défaut, le parent sous abonnement inclus bénéficie d'une heure ; les autres requêtes, notamment sous-agents et compaction, ont généralement cinq minutes, avec exceptions pilotées côté serveur. API, fournisseur cloud et usage credits ont généralement cinq minutes. Les contrôles de TTL parent et sous-agents sont distincts. [Cache Claude Code][S12].

**Pistes :** garder stables les préfixes et mettre les données variables dans la partie conversationnelle ; limiter les bascules opportunistes de modèle et de serveur en pleine tâche. Comparer un contexte réduit à un contexte plus grand bien caché : ni le taux de cache seul ni la taille seule ne tranche le coût total. Ne pas envoyer des messages artificiels pour garder un cache chaud.

Le SDK distingue son prompt minimal, le preset `claude_code` et un prompt personnalisé ; `claude -p` utilise par défaut le prompt Claude Code. Un prompt minimal et un preset complet n'ont donc pas la même base de comparaison. Le chargement `CLAUDE.md` dépend des `settingSources`, pas uniquement du preset. [Prompts SDK][S19].

## 4. Sous-agents : isoler les lectures sans oublier le coût de délégation

### Ce qui est transmis

Un sous-agent ordinaire reçoit un contexte frais, son propre prompt, le brief et les outils hérités/filtrés ; il n'a pas l'historique du parent. Les agents personnalisés chargent normalement la hiérarchie `CLAUDE.md`, contrairement aux built-ins Explore/Plan ; les règles locales peuvent encore charger à l'accès. Les serveurs MCP inline peuvent rester limités à sa durée de vie ; les références au parent partagent sa connexion. Explore n'est plus à supposer systématiquement sur Haiku. Les appels consomment les mêmes limites que le parent. [Sous-agents][S05].

Le préchargement `skills:` injecte les corps complets. [Skills][S10]. La définition TypeScript expose séparément outils, MCP, skills, modèle et effort ; le modèle accepte alias, identifiant complet ou `inherit`. `omitClaudeMd` est ignoré lorsque l'agent devient le thread principal. [Référence TypeScript][S33].

Un **fork de conversation** copie au contraire l'historique, les outils et le prompt du parent. Son travail ultérieur reste isolé. Le SDK sait en lancer via `Agent` depuis 2.1.302 ; il ne faut pas attribuer à ce fork le bénéfice d'une entrée vierge. Les options et champs diffèrent entre SDK TypeScript et Python. [Sous-agents SDK][S06]. Ce préfixe identique peut réutiliser le cache du parent : lorsque la mission exige réellement le même contexte, un fork peut coûter moins cher qu'une reconstruction complète dans un agent frais. Il reste une dépendance au raisonnement et à l'historique du parent, incompatible avec une revue censée en être indépendante. [Architecture du cache][S36].

### Modes à distinguer

| Forme | Ce qu'il faut comparer |
| --- | --- |
| Sous-agent frais | Brief + instructions chargées + exploration propre + rapport + synthèse parent |
| Fork | Préfixe hérité potentiellement caché + travail de branche + retour ; pas d'isolation de l'historique d'entrée |
| Reprise d'un agent | Ancien contexte conservé ; économies possibles de redécouverte, contexte plus long |
| `claude --agent nom` | Le thread principal adopte l'agent ; ce n'est pas une délégation supplémentaire |
| `--agents` | Définitions pour la session ; ne signifie pas qu'elles sont toutes exécutées |
| `--fork-session` | Nouvelle identité de session lors d'une reprise ; distinct d'un worker frais |

Les trois formes CLI sont décrites dans la [référence CLI][S14]. La reprise conserve l'historique ; Explore et Plan sont documentés comme one-shot, sans identifiant permettant leur reprise. [Sous-agents][S05].

Les sous-agents démarrent actuellement en arrière-plan par défaut. Le premier plan attend leur résultat ; l'arrière-plan permet le travail concurrent. Les permissions peuvent remonter au parent. La possibilité de faire attendre le parent dépend du fork mode et du runtime ; `-p`/SDK peuvent attendre selon les dépendances. Ces différences interdisent de supposer qu'une recette CLI s'applique telle quelle à l'IDE. [Sous-agents SDK][S06], [sous-agents][S05].

**Critère de délégation proposé :** privilégier une enquête autonome avec gros outputs dont seul un résultat bref sera réutilisé. Garder dans le parent les petites recherches dont il connaît déjà l'essentiel. Pour une reprise, demander la continuation ciblée plutôt que relancer l'enquête complète, puis comparer le coût cumulé. Garder les modèles et efforts existants pendant cette première comparaison.

### Équipes, parallélisme et quota

Les agent teams sont expérimentales et désactivées par défaut. Chaque teammate est une session dotée de son propre contexte et peut échanger directement avec les autres ; il charge son environnement d'instructions/outils sans hériter de toute la conversation du lead. Ce fonctionnement diffère du simple rapport d'un sous-agent. Une invocation nommée peut devenir teammate dans certaines sessions interactives où les équipes sont activées. [Équipes][S20].

**Inférence :** exécuter trois branches simultanément peut raccourcir le délai tout en consommant leur somme dans la même période de quota. Le parallélisme n'augmente pas l'allocation du compte. Mesurer la durée seule récompenserait potentiellement une solution plus chère. Compter coordination, messages, doublons, échecs et branches abandonnées, sans rogner la review indépendante déjà exigée.

## 5. Outils, sorties et MCP

La documentation MCP actuelle dit **outils différés par défaut**, et non « toujours chargés jusqu'à 10 % du contexte ». Le seuil de 10 % concerne `ENABLE_TOOL_SEARCH=auto` ; `auto:N` le personnalise, `false` charge en amont. Certaines configurations, versions, générations de modèles ou passerelles empêchent le chargement différé. Refuser/retirer `ToolSearch` peut charger tous les outils en amont. `alwaysLoad` force le chargement d'un serveur. Les noms et instructions restent un coût même si les schémas sont différés. [MCP][S21].

**Pistes à tester :** sorties structurées et ciblées ; recherches limitées aux fichiers/symboles utiles ; journal complet conservé localement, avec résultat décisif et pointeur dans le contexte ; sélection des serveurs réellement nécessaires avant de commencer. Ne pas remplacer systématiquement MCP par CLI : comparer les définitions évitées, les recherches d'outils supplémentaires et la verbosité réelle des réponses. Ne pas confondre sortie masquée dans l'interface et sortie absente du prompt.

L'API propose le **context editing** en bêta, avec `context-management-2025-06-27`, pour effacer d'anciens résultats d'outils ou blocs de thinking côté serveur. Effacer peut invalider une partie du cache ; il faut amortir la nouvelle écriture. C'est une capacité de la Messages API, pas la preuve qu'un réglage identique est exposé dans chaque runtime Claude Code. [Context editing][S22].

Le SDK charge les skills selon ses sources de configuration et permet de contrôler les skills invocables. Vérifier les options effectives du SDK et la version de son moteur avant de comparer son catalogue à celui du CLI/IDE. [Skills SDK][S23].

## 6. Remote Control : localiser l'exécution et reconnaître les sessions

| Entrée | Exécution et continuité documentées |
| --- | --- |
| `/remote-control` ou `/rc` | Expose la conversation locale courante et son historique |
| `claude --remote-control` | Session interactive locale également accessible à distance |
| `claude remote-control` | Serveur local pouvant créer/servir des sessions ; modes `same-dir`, `worktree`, `session` |
| Serveur `--continue` / `--session-id` | Reprise explicite, disponible depuis 2.1.200 ; démarrer le serveur n'est pas toujours reprendre l'ancien contexte |
| `claude.ai/code` | Interface pouvant montrer Remote Control ou une session cloud |
| `claude --cloud` | Nouvelle session cloud ; `--remote` reste un ancien alias déprécié |
| `/remote-env` | Choix de l'environnement cloud par défaut ; aucune compression implicite du contexte |

Les quatre premières lignes sont documentées dans [Remote Control][S09], les sessions cloud dans [Claude Code cloud][S24], la commande d'environnement dans les [commandes][S07].

Remote Control garde outils, fichiers et configuration sur la machine d'exécution. Il nécessite un abonnement éligible — Pro, Max, Ultra, Team ou Enterprise dans la page actuelle — et ne prend pas les clés API ; les politiques d'organisation s'appliquent. Bedrock, Google Cloud, Foundry et les endpoints proxy ne sont pas pris en charge par cette connexion. [Remote Control][S09]. Une session cloud utilise son propre environnement ; la téléportation vers le terminal crée une copie locale dont le travail nouveau ne remonte pas automatiquement dans l'ancienne session cloud. [Claude Code cloud][S24].

**Comparaison conceptuelle avec SSH/tmux :** s'attacher à un processus déjà vivant et lancer une seconde commande `claude` sont deux opérations différentes. SSH/tmux n'implique aucun mécanisme Claude de compression ; pour établir la continuité, comparer l'identité du processus et de la session, le répertoire et l'arbre des agents. Cette analyse de transport n'est pas un test SSH effectué ici.

**Hypothèse étroite :** continuer le même travail pourrait éviter de le réexpliquer dans une nouvelle session. Le bénéfice proviendrait de la continuité et de la suppression de doublons, pas de la distance. Réponse à la question « Remote Control économise-t-il intrinsèquement ? » : **non établi par les sources consultées**. Aucun tarif réduit lié au contrôle distant n'y est démontré.

### Permissions, plan mode et déduplication

Le plan mode est une restriction d'action ; il n'est pas une garantie d'absence d'appels modèle. Les règles de permission, hooks et sandbox continuent de s'appliquer. Une autorisation dans un message de worker ne remplace pas une approbation de permission. [Permissions][S25], [équipes][S20]. Le maintien de cache lors d'un changement de mode, et l'exception `opusplan`, sont documentés séparément. [Cache Claude Code][S12].

Pour l'audit parent : distinguer demande affichée sur plusieurs interfaces, message réellement soumis deux fois et requête modèle répétée. Une déduplication d'événements UI, de titre ou de marqueurs de modèle ne prouve pas une déduplication de facturation. Les corrections de changelog citées plus haut justifient de noter la version ; elles ne prouvent pas un double coût actuel.

Dans VS Code, ouvrir une entrée Remote Control locale peut retrouver la conversation existante ; si le runtime ne peut exclure qu'un autre processus la détienne, une copie peut être téléchargée. La ventilation Day/Week locale n'inclut pas les autres appareils ni claude.ai. L'extension peut également injecter sélection et fichier ouvert : préserver ce facteur dans une comparaison CLI/IDE. [VS Code][S29].

## 7. Plan mode, effort, fast mode et budgets

L'effort pilote le raisonnement adaptatif selon le modèle ; ses niveaux et valeurs par défaut varient. Le thinking ne peut plus être désactivé sur certains modèles récents ; `MAX_THINKING_TOKENS=0` n'y est donc pas une recette universelle. `opusplan` associe des modèles différents aux phases. [Configuration des modèles][S30].

Fast mode réduit la latence à un prix supérieur par token. La page actuelle le réserve à certains modèles Opus et indique qu'il utilise des usage credits, hors limites incluses de l'abonnement. Son activation n'est donc pas une optimisation du coût ou de l'allocation incluse. [Fast mode][S31].

`--max-budget-usd` et `--max-turns` sont des contrôles du mode print. Le premier s'appuie sur l'estimation client et inclut les sous-agents, mais peut être dépassé ; les totaux restaurés d'une ancienne exécution ne sont pas comptés contre ce nouveau plafond. [CLI][S14].

**Décision proposée :** garder les niveaux actuels pendant les essais de contexte. Une tâche tronquée à trois tours n'est pas une tâche achevée plus efficacement ; compter sa reprise et ses corrections. Le plan mode peut éviter des modifications inutiles, mais son analyse initiale et ses transitions coûtent aussi : ne pas annoncer une baisse de tours sans comparaison à qualité constante. Le routage global Sonnet demeure différé selon la décision fournie par le parent.

## 8. Observer sans ajouter une nouvelle boucle coûteuse

Les **suggestions du prochain prompt** utilisent une requête au modèle de la session et comptent dans l'usage. Si elles ne servent pas, tester leur désactivation dans `/config` ou via `promptSuggestionEnabled: false`. Le **Session recap** automatique est également une fonction distincte, désactivable dans `/config` ; ne pas confondre sa courte restitution avec la compaction nécessaire à une tâche longue. Leur activité effective reste à vérifier dans les sessions de l'utilisateur. [Mode interactif][S34].

L'**idle compaction** peut au contraire réduire les entrées du retour après une longue pause. Elle nécessite notamment une session interactive, un cache d'une heure, un grand contexte et une durée d'inactivité suffisante. Le réglage `idleCompaction: false` évite le résumé en arrière-plan mais peut déplacer le coût sur la requête suivante ; ne pas le recommander globalement sans comparaison. [Réglages][S35].

`InstructionsLoaded` observe les chargements `CLAUDE.md`/rules et indique notamment raison, fichier et origine d'import ; il est asynchrone et ne bloque pas. Il ne couvre pas la lecture native directe d'`AGENTS.md`, mais couvre son import par `CLAUDE.md`. Les événements de compaction et de cycle de sous-agent apportent d'autres repères. Les hooks `prompt` appellent un modèle ; les hooks `agent` lancent un vérificateur outillé. Un hook d'observation en commande locale n'implique pas ces appels supplémentaires, sauf s'il les lance lui-même. [Hooks][S32].

OpenTelemetry documente les événements `claude_code.api_request`/`api_error`, les compteurs d'entrées/sorties/cache, le modèle, l'effort, la source de requête et les identifiants de corrélation. Ces métriques permettent de distinguer parent, compaction et agents ; elles ne sont pas une facture. [Monitoring][S16].

**Piste :** réutiliser d'abord les journaux déjà présents. Si une instrumentation manque, proposer ultérieurement un petit observateur déterministe conservant seulement identifiants pseudonymisés, version, modèle, compteurs et statut ; pas les prompts, outputs bruts ou secrets. Observer les instructions statiques réellement chargées avant de changer leur organisation. Aucun hook créé ici.

## 9. Priorités proposées pour Etabli

Ces étapes sont des recommandations de recherche ; elles n'autorisent ni activation ni appel payant.

1. **P0 — Fiabiliser le dénominateur.** Établir version CLI/moteur IDE/SDK, fournisseur, modèle exact, effort, facturation et arbre de sessions. Vérifier que le suivi par SHA comprend enfants, compactions et reprises. Critère : aucune économie annoncée à partir du seul parent.
2. **P1 — Réduire les entrées inutiles restantes.** Contrôler chargements réels, imports non différés, règles trop larges, skills invoqués sans nécessité, lectures et outputs redondants. Critère : mêmes règles pertinentes et mêmes preuves de validation accessibles.
3. **P1 — Choisir la bonne continuité.** `/clear` pour sujets indépendants ; compact orienté ou résumé ciblé à une frontière de tâche ; reprise d'un worker lorsque son contexte utile existe déjà. Critère : gain total après résumé, cache et relectures.
4. **P1 — Comparer une délégation ciblée.** Une enquête verbeuse avec brief minimal et retour sourcé face à la même enquête dans le parent. Critère : qualité de résultat et coût de tout l'arbre ; ne pas supprimer une review obligatoire.
   Examiner séparément les forks quand la mission exige le contexte courant et autorise cette dépendance. Tester aussi les suggestions/recaps si ces fonctions sont actives et inutilisées ; ne pas les confondre avec la compaction.
5. **P2 — Vérifier MCP et cache effectifs.** Confirmer les outils différés et leurs exceptions ; comparer la stabilité du préfixe et le TTL observé. Critère : comptage des recherches d'outils et écritures supplémentaires, pas seulement du cache hit rate.
6. **P2 — Remote Control comme continuité opérationnelle.** Contrôler qu'un appareil rejoint la session souhaitée ; limiter les travaux accidentellement dupliqués. Critère : identités de sessions/branches et absence de double soumission ; pas de promesse intrinsèque de tokens.
7. **P3 — Modèles/effort séparément.** Garder les réglages pendant P0–P2. Une autre campagne pourra étudier le routage après validation des runtimes. Fast mode reste un choix de latence facturé, pas une économie.

## 10. Petit protocole robuste, à autoriser et exécuter ultérieurement

### Préenregistrement

Sélectionner des fixtures sans historique privé : petite correction déterministe, recherche transverse verbeuse, diagnostic avec logs, tâche longue avec interruption/reprise, review avec défaut connu et contrôle propre. Fixer SHA et empreintes des fixtures, commandes, réponses attendues, critères de qualité, modèle exact/effort, runtime, outils, plafond financier et temps maximal. Une même tâche doit être comparable dans les deux bras ; ne pas attribuer la différence CLI/IDE au seul contexte.

Premier essai limité : **une seule intervention** — parent seul versus sous-agent frais pour l'enquête verbeuse — avec même modèle et mêmes exigences de sortie. Puis, si utile, essais distincts sur instructions différées, compact et Remote Control. Ne pas multiplier toutes les combinaisons d'un coup.

### Exécution proposée

- Alterner/randomiser l'ordre des bras et figer le plan avant lancement. Séparer scénarios à cache froid et continuité chaude ; conserver délais et TTL. Ne pas utiliser le même préfixe réchauffé par A pour avantager arbitrairement B.
- Pour une conclusion de médiane, respecter le contrat local : au moins sept observations mesurées par bras ; un petit pilote descriptif peut d'abord vérifier l'instrumentation, sans conclusion statistique. Ne pas annoncer de p95 à partir d'un tel pilote.
- Repartir du même état de fichiers ; laisser finir ou arrêter explicitement tous les enfants. Inclure appels de lancement, coordination, synthèse, compactions, retries, reprises, branches abandonnées et vérification finale.
- Faire évaluer en aveugle la correction, les preuves, la couverture des cas et les régressions. La review doit garder son indépendance et sa qualité. Une réponse courte mais incomplète est un échec.
- Enregistrer durée, contexte maximal, requêtes, ventilation d'entrées/cache/sorties, estimation USD et preuve de facturation disponible. Mesurer séparément les barres de plan, sans autre activité du compte pendant la fenêtre et sans réinitialisation entre relevés ; documenter leur précision et délai.

### Règles de comptabilité indispensables

Le SDK indique que `usage` du résultat exclut les sous-agents ; `modelUsage`/`model_usage` et `total_cost_usd` les incluent. Les fragments assistant peuvent partager le même identifiant : les dédupliquer. Les sorties par fragment sont des valeurs provisoires ; utiliser les totaux de résultat. Les reprises restaurent les coûts précédents : ne pas sommer aveuglément ces cumuls. Une erreur peut avoir déjà consommé des tokens, et un crash peut produire des compteurs finaux nuls. [Comptabilité SDK][S15].

**Convention expérimentale proposée :** une ligne par requête fournisseur identifiable, rattachée à une tâche et une branche ; un journal séparé pour événements et erreurs. Ne jamais additionner à la fois le total global et ses enfants. Un retry avec une nouvelle requête reste du travail distinct ; plusieurs événements du même résultat n'en sont pas. Pour les tentatives sans usage disponible, conserver « inconnu » et réconcilier avec la comptabilité fournisseur, sans inventer zéro. Les cumuls restaurés lors d'un fork/reprise sont un solde d'ouverture, pas une nouvelle consommation.

### Décision

Adopter seulement si la qualité ne régresse pas et si le coût total pertinent baisse de façon répétée sur les cas représentatifs. Publier valeurs absolues, dispersion, échecs, couverture et limites. Pour l'abonnement, parler d'amélioration du quota uniquement si cette mesure existe ; sinon conclure sur les tokens et/ou l'estimation API. Un temps plus court ou un parent plus léger peut rester utile, mais reçoit son propre libellé.

## 11. Observations locales et priorités spécifiques

Instantané du 9 novembre 2026, checkout propre `main@07927127105522cd34111a35c9576aae4746a106`. L'inspection porte sur les sources du dépôt, la version du binaire sur PATH et une liste fermée de champs non secrets dans `~/.claude/settings.json`. Elle ne reconstitue pas la configuration fusionnée d'une session Claude en cours, ne certifie pas les runtimes IDE/SDK, ne prouve aucune éligibilité Remote Control et ne mesure pas la consommation des deux Macs. Aucun historique privé, fichier d'authentification ou contenu de conversation n'a été consulté pour cette recherche.

- `claude --version` : **2.1.319**. `claude remote-control --help` expose `--spawn`, `--capacity`, `--continue` et `--session-id`. La vérification s'est arrêtée à l'aide du CLI : aucune session Remote Control ouverte.
- `scripts/claude-skill-load-check` : **OK**, `index_chars=4283`, `discovered=32`, `on_set=19`, `pinned=18`. Ce sont des caractères et des comptes de catalogue, pas des tokens natifs ni un taux d'économie.
- Les liens des quatre agents personnalisés Claude résolvent vers les sources Etabli. `scout`, `worker` et `reviewer` déclarent déjà `claude-sonnet-5-5` / `medium` ; `adversary` déclare `claude-opus-5-5` / `low` et `omitClaudeMd: true`. Sources : `claude/scopes/shared/agents/*.md`. Ces frontmatters ne prouvent pas le modèle effectif d'un appel.
- Le council déclare `PR_COUNCIL_MODEL:-opus`, `PR_COUNCIL_EFFORT:-high` et `PR_COUNCIL_PHASE_A_MODEL:-sonnet` ; la vérification des corrections déclare `PR_REVIEW_WATCH_VERIFY_MODEL:-opus`. Les variables d'environnement et certains chemins du lanceur peuvent modifier ces valeurs. Sources : `claude/scopes/work/scripts/pr-council-review/run.sh`, `claude/scopes/work/scripts/pr-review-watch/review-run.sh`.
- Le fragment partagé `claude/settings.skill-overrides.json` gouverne déjà les skills et ne fixe pas `CLAUDE_CODE_SUBAGENT_MODEL`. L'archive `docs/plan/20261107-token-defaults.md` maintient le report de son activation globale jusqu'à vérification de tous les consommateurs CLI/IDE/SDK. « Préserver les choix actuels » ne signifie donc pas « tous les agents sont Opus ».
- Dans les champs autorisés inspectés de `~/.claude/settings.json` et de l'environnement de ce processus : aucun override explicite de modèle de subagent, fork, effort, tool search, cache ou TTL. Aucun override de `promptSuggestionEnabled` ou `idleCompaction` dans ce fichier. **Une clé absente n'établit ni le défaut effectif, ni l'activité de la fonction** : d'autres couches, des flags et les choix d'une session peuvent intervenir.
- `autoMemoryEnabled: false` est présent dans ce fichier et dans le fragment partagé ; la liste `enabledPlugins` y est vide. Le `.mcp.json` du dépôt est vide. Cela ne recense pas les MCP utilisateur, ceux des autres couches, les connecteurs de compte ou les plugins intégrés activés ailleurs.
- Les trois hooks recensés dans ce fichier sont de type `command` : cette inspection n'a pas trouvé de hook `prompt` ou `agent` à supprimer dans cette couche. Le coût d'un sous-processus éventuel dépend toujours de la commande, pas de l'étiquette seule.
- La statusline est **déjà installée** via le wrapper Etabli : `claude/statusline.mjs` affiche le contexte, le dernier appel parent, lectures/écritures cache, hit ratio, chaleur, misses, fenêtres de compte, et **`subagents:inconnu`**. Ne pas reconstruire ce tableau ; le manque utile à mesurer est l'agrégation des branches enfant. « parent(last) » n'est pas un total de tâche.
- Les consignes de compaction existent dans `claude/claude-global.md` ; RTK est déjà intégré avec une voie `proxy` pour les sorties exactes/structurées. Les archives `20261107-workflow-context.md` et `20261107-workflow-efficiency.md` documentent skills froids, handoff ciblé à 400 mots, journaux privés et réduction des sorties volumineuses. Elles ne revendiquent pas de gain monétaire ou de quota mesuré.

### Priorités locales issues de l'inspection

1. **Mesurer avant de rajouter un collecteur** : réutiliser la statusline et les événements/artefacts existants, en rendant explicite la couverture parent/enfants. Ne pas confondre la ligne de cache du parent avec le bilan de la tâche.
2. **Rendre le choix d'agent explicite dans les prompts de délégation** : traitement direct pour une petite opération ; agent spécialisé à contexte séparé pour une mission bornée ; fork quand la mission exige réellement le contexte courant et autorise cette dépendance. Une revue indépendante reste dans son contexte neuf exigé par le contrat : le partage d'historique d'un fork ne convient pas à cet objectif.
3. **Réduire les répétitions et les branches inutiles**, plutôt que basculer globalement tous les modèles : transmettre un périmètre, les références déjà trouvées, le résultat attendu et la condition d'arrêt ; éviter que parent et enfant explorent la même tranche en parallèle. Ne pas réutiliser un évaluateur lorsque le contrat exige un nouveau regard.
4. **Remote Control comme continuité** : pour une tâche en cours, attacher l'interface à la même session sur la machine d'exécution au lieu d'en recréer une sur l'autre Mac. Pour un usage mono-tâche du serveur, évaluer `--spawn=session` ; pour plusieurs tâches, borner les sessions et garder l'isolation requise. La limite de capacité n'est ni une limite de tokens ni une économie mesurée. Aucun serveur à lancer automatiquement pour cette étude.
5. **Essais optionnels séparés** : suggestions et recap si effectivement actifs et non utilisés ; niveau d'effort sur tâches simples ; TTL des agents seulement si les reprises dépassent le TTL actuel. Ne pas désactiver par principe la compaction, forcer un TTL d'une heure, élargir les permissions ou changer le modèle des reviewers pour obtenir un chiffre plus bas.

Ces observations sont une base de propositions : aucun réglage Claude, hook, skill, modèle, serveur, service, planificateur ou déploiement n'a été modifié par cette recherche. Fleet reste hors périmètre.

## 12. Limites et statut final

**Documentation/source :** mécanismes, commandes, différences de runtime et repères de versions vérifiés dans les sources ci-dessous ; inspection locale limitée à la section 11. **Hypothèses/pistes :** priorités et protocole proposés pour Etabli. **Gain mesuré : aucun.** Aucune conclusion sur le coût réellement économisé, le nombre de tâches supplémentaires dans l'abonnement ou la configuration effective fusionnée d'une session en cours.

La recherche de contexte préalable dans le vault personnel a retourné des pistes lexicales ; elles ne servent pas de preuve technique ici. Les mécanismes ont été vérifiés aux sources officielles. Certaines surfaces changent rapidement et dépendent de droits, flags, fournisseurs et versions ; une page actuelle ne prouve pas que l'installation locale les possède. Les comptabilités partielles ou les périodes de quota contaminées doivent aboutir à « comparaison inconclusive ».

## Sources primaires

[S01]: https://github.com/anthropics/claude-code/releases/tag/v2.1.319 "Release Claude Code v2.1.319"
[S02]: https://api.github.com/repos/anthropics/claude-code/releases/latest "API GitHub officielle : dernière release, réponse consultée le 9 novembre 2026"
[S03]: https://api.github.com/repos/anthropics/claude-code/commits?path=CHANGELOG.md&per_page=1 "API GitHub officielle : dernier commit CHANGELOG, réponse consultée le 9 novembre 2026"
[S04]: https://code.claude.com/docs/en/costs "Claude Code : Manage costs effectively"
[S05]: https://code.claude.com/docs/en/sub-agents "Claude Code : Create custom subagents"
[S06]: https://code.claude.com/docs/en/agent-sdk/subagents "Claude Agent SDK : Subagents in the SDK"
[S07]: https://code.claude.com/docs/en/commands "Claude Code : Commands"
[S08]: https://code.claude.com/docs/en/memory "Claude Code : How Claude remembers your project"
[S09]: https://code.claude.com/docs/en/remote-control "Claude Code : Continue local sessions from any device with Remote Control"
[S10]: https://code.claude.com/docs/en/skills "Claude Code : Extend Claude with skills"
[S11]: https://code.claude.com/docs/en/checkpointing "Claude Code : Checkpointing"
[S12]: https://code.claude.com/docs/en/prompt-caching "Claude Code : How Claude Code uses prompt caching"
[S13]: https://platform.claude.com/docs/en/build-with-claude/prompt-caching "Claude API : Prompt caching"
[S14]: https://code.claude.com/docs/en/cli-reference "Claude Code : CLI reference"
[S15]: https://code.claude.com/docs/en/agent-sdk/cost-tracking "Claude Agent SDK : Track cost and usage"
[S16]: https://code.claude.com/docs/en/monitoring-usage "Claude Code : Monitoring"
[S17]: https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work "Claude Help Center : How do usage and length limits work?"
[S18]: https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-max-or-ultra-plan "Claude Help Center : Use Claude Code with your Pro, Max, or Ultra plan"
[S19]: https://code.claude.com/docs/en/agent-sdk/modifying-system-prompts "Claude Agent SDK : Modifying system prompts"
[S20]: https://code.claude.com/docs/en/agent-teams "Claude Code : Orchestrate teams of Claude Code sessions"
[S21]: https://code.claude.com/docs/en/mcp "Claude Code : Connect Claude Code to tools via MCP"
[S22]: https://platform.claude.com/docs/en/build-with-claude/context-editing "Claude API : Context editing"
[S23]: https://code.claude.com/docs/en/agent-sdk/skills "Claude Agent SDK : Extend agents with skills"
[S24]: https://code.claude.com/docs/en/claude-code-on-the-web "Claude Code : Use Claude Code in the cloud"
[S25]: https://code.claude.com/docs/en/permissions "Claude Code : Configure permissions"
[S26]: https://platform.claude.com/docs/en/build-with-claude/extended-thinking "Claude API : Extended thinking"
[S27]: https://raw.githubusercontent.com/anthropics/claude-code/0ed94698aa0aeee471465fc9c867c2e8434c4d68/CHANGELOG.md "Changelog officiel figé au commit observé"
[S28]: https://code.claude.com/docs/en/context-window "Claude Code : Explore the context window"
[S29]: https://code.claude.com/docs/en/vs-code "Claude Code : Use Claude Code in VS Code"
[S30]: https://code.claude.com/docs/en/model-config "Claude Code : Model configuration"
[S31]: https://code.claude.com/docs/en/fast-mode "Claude Code : Speed up responses with fast mode"
[S32]: https://code.claude.com/docs/en/hooks "Claude Code : Hooks reference"
[S33]: https://code.claude.com/docs/en/agent-sdk/typescript "Claude Agent SDK : TypeScript reference"
[S34]: https://code.claude.com/docs/en/interactive-mode "Claude Code : Prompt suggestions et Session recap"
[S35]: https://code.claude.com/docs/en/settings-reference "Claude Code : All settings, notamment idleCompaction"
[S36]: https://claude.dev/blog/lessons-from-building-claude-code-prompt-caching-is-everything/ "Équipe Claude Code : Lessons from building Claude Code, 30 avril 2026"
