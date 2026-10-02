# Claude Code mods : capacités réelles et implications pour Etabli

Date : 2026-10-01. Question : que peut-on réellement construire avec les mods, et comment les intégrer à Etabli sans perdre ses contrats partagés ni confondre une interface avec une preuve d'exécution ?

## Verdict

Les mods permettent de construire une véritable extension de l'agent Claude : interface interactive, commandes déterministes, outils locaux, instrumentation des requêtes, contrôle des agents, politique d'admission des autres plugins. Pour Etabli, le meilleur premier résultat est un cockpit du workflow et une commande `/etabli` en lecture seule, alimentés par le plan et le ledger existants. Un port des garde-fous est possible, mais son intégration exige davantage qu'un changement de syntaxe.

**verified** : le dépôt public contient les quatre mods `diff`, `agents-md`, `sec-default` et `telemetry`, leurs tests et un contrat TypeScript généré. Il expose des consommateurs de l'API et des déclarations ; nous n'y avons pas trouvé l'implémentation complète du moteur hôte. On peut étudier comment les fonctionnalités se construisent, sans auditer ni prouver intégralement les garanties de l'hôte propriétaire. [Sources publiques à la révision étudiée](https://github.com/anthropics/claude-code/tree/52c76441cae91f6891e4712306bffb057ff6fec5/mods).

**documented** : les mods sont activés par défaut à partir de Claude Code 2.1.287. **verified** : le Claude local est en 2.1.287. **blocked** : le test local du mod sec-default a été refusé avant toute exécution par le rollout distant. La version et les commandes présentes ne suffisent donc pas à démontrer que les mods peuvent fonctionner ici. **not verified** : aucun mod Etabli n'a été installé, aucune session interactive équipée n'a été exercée, et aucune équivalence de sécurité avec les hooks actuels n'est démontrée. [Référence actuelle](https://code.claude.com/docs/en/plugins/mods/reference), [changelog public](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/CHANGELOG.md#21287).

## Périmètre et provenance

- Article d'Addy Osmani publié le **2026-10-01** : [Getting started with Claude Code mods](https://claude.dev/blog/getting-started-with-claude-code-mods/). Version Markdown récupérée directement auprès du site officiel.
- Dépôt amont figé sur **`52c76441cae91f6891e4712306bffb057ff6fec5`** ; commit du 2026-10-01 à 18:43:08 UTC. Clone inspecté : `/tmp/etabli-claude-mods.0qGX9y/upstream`.
- Contrat public : `mods/types/claude-code.d.ts`, **13 186 lignes**, en-tête **Written by Claude Code 2.1.277**. Les déclarations générées par la version installée prévalent lorsque les sources divergent.
- Documentation officielle `overview`, `create`, `events`, `api`, `interface`, `admin`, `test` et `reference` et `troubleshoot`, récupérée le 2026-10-01 ; cache local `/tmp/etabli-claude-mods.0qGX9y/docs/`. Ce sont des pages vivantes, contrairement aux liens GitHub figés.
- Etabli : worktree `/Users/tonours/.codex/worktrees/683c/etabli`, révision **`fd4bf728f297eae867e5115ab10e3269fb037992`**. Les conclusions d'intégration ci-dessous concernent ce checkout.
- Méthode : lecture statique des sources, documentation primaire et comparaison avec Etabli ; validation statique des quatre mods publics par le CLI local. Aucun appel modèle, installation ou écriture externe. Une exécution du test kit a été tentée et refusée avant le chargement des tests ; aucun test runtime n'a tourné.

Labels : **verified** = observé dans les fichiers ou une commande locale ; **documented** = promis par la documentation officielle actuelle ; **inference** = conséquence proposée pour Etabli ; **not verified** = comportement non exercé en session.

## Le modèle d'exécution

Un mod est un plugin normal, avec `.claude-plugin/plugin.json`, `hooks/hooks.json` et exactement un module déclaré sous `modules`. Ce module exporte `register(on, options)`. Chaque `on` ajoute un maillon à une chaîne : le hook reçoit `$`, un événement `e` figé et `next` ; il peut transmettre l'événement, en transmettre une copie modifiée, ou répondre lui-même. Observer le résultat après `await next(e)` est différent d'observer seulement la tentative avant l'appel. [Article](https://claude.dev/blog/getting-started-with-claude-code-mods/#how-a-mod-works), [contrat public, lignes 5230–5330](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L5230).

Le module vit dans un évaluateur fermé : pas de DOM, de `require`, d'API Node, de timers globaux ou d'accès direct aux fichiers/réseau. Il dispose de JavaScript et de certaines API web, puis appelle `$` pour sortir. **Cela ne constitue pas un confinement des permissions du système** : `$` permet de lancer des processus, lire/écrire les fichiers accessibles à l'utilisateur et accéder au réseau. Une permission refusant au modèle `Read(.env)` ne refuse pas automatiquement `$.fs.read('.env')` à un mod. [API](https://code.claude.com/docs/en/plugins/mods/api#reach-files-processes-and-the-network), [administration](https://code.claude.com/docs/en/plugins/mods/admin#know-what-happens-by-default).

Les appels `$` sont eux-mêmes des événements : un mod placé avant un autre peut intercepter `fs.read`, `process.run`, `http.fetch`, etc. `plugin.register` reçoit les capacités détectées avant l'admission ; `engine.create` permet de construire l'API offerte aux plugins. Dans le contrat public, un mod peut ajouter ou retirer des namespaces, mais pas remplacer un namespace déjà fourni. Le namespace `telemetry` montre concrètement cette composition. [Contrat, lignes 3653–3661](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L3653), [implémentation telemetry](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/telemetry/hooks/register.ts#L55).

La validation repose sur une analyse statique stricte. Les appels doivent être écrits littéralement comme `$.fs.read` ; pas d'alias de `$`, de destructuration ou de nom de méthode calculé. `$` peut être passé à une fonction au niveau supérieur du même fichier, mais pas à une fonction importée d'un autre fichier. Seuls les imports relatifs à l'intérieur du plugin et le module nu `claude-code` sont admis ; pas d'import dynamique. C'est une contrainte architecturale réelle, pas une simple convention. [Règles de création](https://code.claude.com/docs/en/plugins/mods/create#check-what-claude-code-reads-from-your-mod), [capacités détectées dans le contrat, lignes 6253–6290](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L6253).

## Ce qu'on peut construire

| Famille | Événements / API | Application Etabli et limite |
| --- | --- | --- |
| Interface du workflow | `ui.render`, `ui.open`, `ui.status`, `ui.toast` | Bandeau du plan, panneau des checks et actions. Un statut doit citer le ledger et les preuves ; une animation ne prouve rien. |
| Commandes déterministes | `command.register`, `command.run`, `immediate: true` | `/etabli` peut répondre immédiatement, même pendant le travail, sans tour modèle. Le texte retourné est lu par Claude ; `ui.log` affiche sans alimenter le modèle. |
| Outils locaux | `tool.register`, `tool.call` | Un outil de lecture du statut ou de vérification peut être visible comme `mcp__<plugin>__<tool>`, sans serveur MCP externe. Son résultat reste une donnée d'outil, pas une autorisation humaine. |
| Instrumentation | `turn.step`, `session.measure`, `session.usage` | Tokens par requête, cache, contexte, coût disponible et limites du plan. Séparer usage réel des requêtes et estimations de contexte. |
| Garde-fous | `tool.call`, `tool.check` | Refus explicite, réécriture ou prévisualisation avant appel. La chaîne des permissions et les échecs doivent être testés avant un remplacement des hooks. |
| Sélection d'agents | `agent.offer`, `agent.spawn`, `agent.list` | Montrer/refuser des types, suivre l'activité, orienter le modèle d'un agent. Conserver provenance, budget et autorisation de délégation. |
| Routage de requêtes | `turn.step` avec `model` / `effort` | Changer une requête de la conversation, y compris celles d'un sous-agent. Ce n'est pas une preuve d'accès à n'importe quel fournisseur. |
| Appels modèle auxiliaires | `model.complete`, `model.fork`, `model.classify` | Résumé ou classification facultatifs. Coût imputé au plan/API ; un fork partage contexte et famille de modèle, ce qui ne démontre pas une revue indépendante. |
| Compaction et reprise | `session.compact`, `classic.SessionStart`, `session.end` | Préserver les pointeurs de reprise et le lien au ledger ; ne pas faire dépendre un état durable d'un flush final. |
| Politique de plugins | `plugin.register`, `engine.create`, hooks sur API | Refuser des capacités ou exposer un petit namespace Etabli. Une politique forte demande une position autoritaire dans la chaîne. |
| Messagerie | `session.send`, `session.receive`, `prompt.submit` | Communication entre sessions/agents et relance automatique possibles. Une réponse de mise en file ne prouve pas l'achèvement du destinataire ni une livraison exactement une fois ; un nom affiché n'authentifie pas la provenance. |

Sources : [référence des événements et méthodes](https://code.claude.com/docs/en/plugins/mods/reference), [guide événements](https://code.claude.com/docs/en/plugins/mods/events), [guide API](https://code.claude.com/docs/en/plugins/mods/api). Les possibilités Etabli de la dernière colonne sont des **inference**, pas des fonctionnalités implémentées.

### Interface : davantage qu'une statusline

Les sites actuels permettent de dessiner `Pane` et `AbovePrompt`, puis de modifier les lignes `UserMessage`, `AssistantMessage`, `ToolUse`, `ToolResult`, `ToolGroup`, `CommandOutput`, `Spinner`, `SessionMode`, `PromptHint` et `AskUserQuestion`. Certaines lignes, dont `ToolProgress`, `TurnDuration` et `InfoNotice`, sont spécifiques au terminal. Les dialogues de permission ne sont pas modifiables. Une transformation d'affichage ne réécrit pas nécessairement le transcript ; `session.append` est l'événement distinct qui peut modifier son contenu avant stockage. [Référence interface](https://code.claude.com/docs/en/plugins/mods/reference#render-sites), [règles de protection](https://code.claude.com/docs/en/plugins/mods/admin#know-which-controls-still-apply).

Les éléments communs sont `Box`, `Text`, `Button`, `Input`, `Select`, `Link`, `Code`, `Markdown` et `Client`. `Svg` est Desktop uniquement ; `Raster` et `Image` sont terminal uniquement. `Client` ajoute une petite couche d'interaction locale avec clavier/pointeur et rendu, sans DOM ni bibliothèque React externe librement importable. Le modèle pertinent est un arbre portable validé par l'hôte, pas un site web arbitraire intégré. [Éléments](https://code.claude.com/docs/en/plugins/mods/reference#elements), [Client dans les types, lignes 1196–1300](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L1196).

Les métriques doivent rester distinctes : taille du contexte, entrées/sorties de requête, cache, consommation du plan et coût monétaire ne sont pas interchangeables. Aucune économie de tokens ou de latence n'a été mesurée ici. Pour Etabli, un bouton « voir le check » peut lire une preuve ; un bouton « lancer le check » est une action différente ; un bouton « publier » doit conserver son checkpoint explicite. Une couleur verte devrait venir d'un résultat terminal réussi associé à la bonne révision, pas de la réception d'un événement ou du démarrage d'un processus. **inference** issue des contrats locaux et de la distinction `result` / `deny` / `isError` de l'API.

### Surfaces d'exécution

| Surface | Hooks | Dessin visible |
| --- | --- | --- |
| Terminal interactif, terminal intégré, JetBrains | Oui | Oui |
| Code de Claude Desktop hors WSL | Oui | Oui selon éléments supportés |
| Desktop WSL | Non, plugins indisponibles | Non |
| Panneau de chat VS Code | Oui | Non |
| `claude -p` / Agent SDK | Oui | Non |
| Remote Control | Oui, sur machine de la session | Dans le terminal local |
| Session cloud ayant reçu le plugin | Oui | Non |

**documented** : [table officielle](https://code.claude.com/docs/en/plugins/mods/overview#where-mods-run). **not verified** : aucune de ces surfaces n'a été testée pendant cette analyse. Le garde-fou doit avoir une issue explicite sans UI ; un appel tenu en attente d'un bouton invisible ne convient pas à `-p`.

## État, cycle de vie et concurrence

Trois durées différentes sont proposées : variable de module jusqu'au rechargement ; `$.state` jusqu'à la fin/réinitialisation de conversation, avec abonnements automatiques des dessins ; `$.store` persistant entre sessions, dans un JSON partagé par toutes les sessions du plugin sur la machine. Les valeurs de `$.state` sont déclarées dans un contrat `PluginState` nommé par le manifeste. Un render peut lire cet état, mais ne peut pas y écrire. [État](https://code.claude.com/docs/en/plugins/mods/interface#keep-state).

Points décisifs pour Etabli :

1. Le hot reload rappelle `register` puis `session.start` ; les variables et timers du vieux module ne constituent pas un journal durable. Les timers sont arrêtés lors du reload ; ils ne redémarrent pas un CLI mort et ne remplacent pas un superviseur externe.
2. `session.start` ne se déclenche pas après `/clear`, `/resume` ou `/branch`. Ces commandes réinitialisent `$.state`. `classic.SessionStart` avec `clear`, `resume` ou `fork` sert à recharger ce qui doit être reconstruit. La compaction n'est pas le même reset.
3. `$.store.get` puis `set` n'est pas une transaction. Relire juste avant écrire réduit une fenêtre de perte, sans l'éliminer. L'API décrite ne fournit pas de CAS natif. Les clés doivent distinguer dépôt, worktree et session ; une autorité nécessitant un verrou doit rester dans le runtime Etabli.
4. `$.fs.write` remplace en place et n'est pas atomique. Écrire directement `PLAN.md`, un ledger ou un reçu avec cette API peut exposer un contenu partiel à un autre processus.
5. Tous les hooks `session.end` partagent **1,5 seconde**, et un `kill -9` ne déclenche aucun hook de fin. Les preuves doivent être persistées au fil des résultats, puis reconstruites depuis leur autorité existante.

Sources : [reprise après clear](https://code.claude.com/docs/en/plugins/mods/interface#load-a-saved-value-again-after-clear), [concurrence du store](https://code.claude.com/docs/en/plugins/mods/interface#save-from-more-than-one-session), [référence fichiers et limites](https://code.claude.com/docs/en/plugins/mods/reference), [session.end, types lignes 3600–3614](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L3600).

## Permissions : la composition change les garanties

L'ordre documenté est : garde `sec-default` lorsqu'il est chargé et tier `prepend` administré, mods utilisateur, tier `append` administré, autres mods intégrés, puis comportement core. Les dépendances du manifeste influencent l'ordre entre mods utilisateur ; le hook appelant conserve l'autorité du premier maillon. `next.origin` est fixé par l'hôte et `next.to` n'est autorisé qu'aux tiers administrés. [Ordre](https://code.claude.com/docs/en/plugins/mods/events#the-order-mods-run-in), [Next et provenance](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L5230).

La distinction majeure : un `PreToolUse` managed précède les mods et son blocage est final ; les hooks utilisateur/projet/plugin arrivent dans core après les mods. Un mod qui répond lui-même peut empêcher ces hooks de s'exécuter. Un mod sur `tool.check` peut ensuite approuver un appel refusé par un hook non managed. `tool.check` garde ses arguments d'identité figés ; les réécritures sont sur `tool.call`. [Ordre avec settings hooks](https://code.claude.com/docs/en/plugins/mods/events#where-settings-hooks-run-in-the-order), [ToolCheck, types lignes 9910–9968](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L9910).

`sec-default` se charge sur une machine avec managed settings ou pour un compte Team/Enterprise. Il conserve les deny rules en recontrôlant sans le tier utilisateur lorsqu'un mod a desserré la décision. **Une décision deny sans règle nommée, notamment celle d'un hook, n'est pas conservée par cette procédure**. La source et un test de `held-verdict` le montrent explicitement. Sans connaître le tier et l'authentification de la session, on ne doit pas supposer que cette protection est présente. [Source register, lignes 93–132](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/sec-default/hooks/register.ts#L93), [test du verdict](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/sec-default/tests/held-verdict.test.ts#L9), [administration](https://code.claude.com/docs/en/plugins/mods/admin#know-what-happens-by-default).

Même sous cette garde, les `$.fs`/`$.process` d'un mod ne deviennent pas des appels d'outil du modèle soumis aux mêmes règles. Une politique sur `http.fetch` ne couvre pas le réseau d'un programme lancé par `process.run`. La prévention forte passe par admission/politique des mods et la position du plugin de garde ; le dessin d'un avertissement n'est pas un contrôle de permission. [Limites des contrôles existants](https://code.claude.com/docs/en/plugins/mods/admin#know-which-controls-still-apply).

Un hook qui échoue avant d'appeler `next` est **ignoré par défaut**, puis la suite s'exécute. Après un `next` déjà résolu, le résultat existant est conservé et n'est pas exécuté une deuxième fois. Un garde Etabli doit ajouter une `.catch` minimale qui refuse si sa propre décision n'est pas disponible. La grace est **1 seconde** ; une erreur du handler ne devient pas automatiquement une protection. [Défaillances](https://code.claude.com/docs/en/plugins/mods/events#handle-a-hook-that-fails), [budget source lignes 4219–4257](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L4219).

**inference** : installer un mod tiers n'est pas seulement ajouter une UI. Cela peut modifier l'autorité effective de nos hooks Claude locaux. Le pilote doit geler sa composition de plugins et tester le refus attendu avec un mod approbateur placé avant/après, sur les tiers réellement disponibles.

## Ce qu'enseignent les quatre mods publics

### `diff` : meilleur exemple d'adaptateur observable

Le mod ouvre une revue des changements du worktree avec base session, HEAD ou merge-base ; sélection de fichiers, changement de base, historique de tours, contexte ajouté pour un fichier armé. Il lit Git avec `process.run`, retarde son premier probe jusqu'au besoin, suit les edits et commandes, et détecte aussi les changements externes de HEAD pendant l'affichage. Il distingue l'espace disponible, le choix de l'utilisateur et les edits du main loop avant ouverture automatique. [README diff](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/diff/README.md).

La partie à retenir pour Etabli : `afterTool` teste le résultat après `next`, exclut `deny` et `isError` pour compter un edit réussi ; elle traite les shells séparément car un shell en échec peut avoir écrit avant d'échouer. Le mod invalide, rafraîchit et garde des générations pour écarter les résultats périmés. Sa source est une référence de comportement, pas un fichier à transplanter : `register.ts` fait plus de 1 000 lignes, alors qu'Etabli demande des extensions petites et explicites. [Filtrage réel, lignes 941–991](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/diff/hooks/register.ts#L941).

### `agents-md` : utile, sans équivalence complète à `CLAUDE.md`

Le mode par défaut `claude-md-or-agents-md` laisse un projet possédant déjà son `CLAUDE.md`, `.claude/CLAUDE.md` ou `CLAUDE.local.md` à l'hôte. Le mode `claude-md-and-agents-md` ajoute AGENTS et déduplique les fichiers déjà importés ou liés, par chemin puis contenu. Etabli a déjà `CLAUDE.md` qui importe `AGENTS.md` : ce n'est donc pas une migration urgente et le double chargement n'est pas automatique. [README et modes](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/agents-md/README.md), [source register](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/agents-md/hooks/register.ts).

Le README énumère huit différences persistantes : instructions imbriquées sur Read texte seulement ; pas de restauration des fichiers ajoutés dans l'état « récemment lus » après compaction ; annonce différente lors d'un `/cd` ; comparaison par orthographe de chemin et non résolution complète des liens ; pas de AGENTS dans `--add-dir` ; `/memory` et `#` ignorent AGENTS ; approbation des imports externes encore liée aux CLAUDE ; duplication possible des fichiers imbriqués dans un sous-agent non fork. `managed-only` laisse également arriver les pièces jointes CLAUDE imbriquées, faute d'événement permettant de les supprimer. La formulation « exactement comme CLAUDE.md » doit donc être bornée à la partie de pipeline atteignable par ces hooks. [Limites explicites](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/agents-md/README.md#where-it-still-differs-from-claudemd).

### `sec-default` : modèle de politique, avec une position spéciale

Il ne crée pas une politique nouvelle ; il protège les contrôles administrés et les deny rules existants. Il se fonde sur les tiers/provenances fixés par l'hôte, lit uniquement la policy et refuse en cas d'échec de lecture dans ses chemins de sécurité. `allowManagedModsOnly` peut refuser l'admission des modules utilisateur, sans transformer les hooks de settings en modules. Une copie chargée via `--plugin-dir` n'acquiert pas son autorité managed, même avec le même nom. [README sec-default](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/sec-default/README.md), [tests register](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/sec-default/tests/register.test.ts).

### `telemetry` : exemple de namespace, pas notre journal de preuves

Le mod fournit/intercepte un namespace, valide des champs fermés, groupe des envois et abandonne lorsque les analytics sont désactivées ou le provider non géré. Son gate admet le core et les builtins, refuse les plugins utilisateur et administrés. Un mod Etabli ne doit donc pas supposer qu'il peut publier ses mesures dans la télémétrie première partie Anthropic. Garder nos propres événements et preuves via le runtime local ; réserver les affichages à une projection. [README telemetry](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/telemetry/README.md), [gate source](https://github.com/anthropics/claude-code/tree/52c76441cae91f6891e4712306bffb057ff6fec5/mods/telemetry/hooks/gate), [contrat du namespace](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/telemetry/types/index.d.ts).

## Article : bons exemples, raccourcis à corriger

| Observation | Statut et implication |
| --- | --- |
| L'article 2.1.287 utilise `$.state`, `PluginState` et des redraws réactifs. Le contrat public figé 2.1.277 ne contient aucune déclaration de cette API. | **verified** : écart de versions, pas preuve que le tuto est faux. Régénérer les types de 2.1.287 avant de coder ou valider sa compilation. |
| README public et en-tête types évoquent « early access » et `/plugin-types` vers `.claude/types`. Article/docs actuels annoncent activation par défaut et génération automatique dans `.claude-plugin/types`. | **verified** / **documented** : metadata publique en partie ancienne ; suivre les types de la version exécutée. |
| Le tuto Replay remplit `pending` avant `next` et ne teste pas le résultat de l'edit avant de conserver le replay. | **inference** statique : il peut enregistrer un edit tenté mais refusé/échoué. Étiqueter les tentatives ou confirmer le résultat pour parler d'edit réalisé ; la source diff fournit le filtrage manquant. |
| Replay garde son état dans des variables alors que le même article recommande `$.state` pour survivre au reload. | **verified** sur le snippet : les données de ce snippet ne survivent pas au reload ; cela ne prouve pas le comportement d'un mod complet non fourni. |
| Blast Radius attend en lançant `sleep 0.25` et annonce un Cancel après sortie de boucle. | **inference** : la boucle contourne le décompte de temps d'attente propre au hook, sans borne de temps réelle ; sur abort elle peut aussi utiliser un message de Cancel que personne n'a pressé. Prévoir annulation, absence d'UI et limite de temps explicites. |
| La détection Blast Radius repose sur la chaîne de commande. | **documented** dans l'article : scripts, aliases et substitutions la contournent ; ce n'est pas un parseur de shell ni une barrière de permission générale. |
| Le test Token Weather emploie le vrai host mais stubbe la réponse usage et les événements. | **documented** : cela prouve le hook et l'arbre, pas les comptes réels du modèle, le rendu terminal/Desktop ni un reload en session. |
| L'article suggère d'ajouter les conventions à chaque `prompt.submit`. | **inference** : possibilité technique incompatible avec ADR-0014 si réintroduite comme injection de routage permanente dans Etabli. Utiliser les instructions établies et le contexte demandé. |

Sources : [article complet](https://claude.dev/blog/getting-started-with-claude-code-mods/), [en-tête des types publics](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L1), [types de la version installée](https://code.claude.com/docs/en/plugins/mods/create#get-the-types-for-your-build). Ces constats portent sur les extraits publiés ; Blast Radius et Replay Theater ne figurent pas comme modules complets inspectables dans ce snapshot de `mods/`.

## Limites opérationnelles et maturité

Les limites documentées utiles au dimensionnement : **10 s** de code propre par hook ; attente de `next`/API exclue sauf `clock.sleep` ; **30 s** de timeout process par défaut, maximum **10 min** ; **4 MiB** par lecture/écriture fichier et par store total ; transcript limité aux **4 096** entrées les plus récentes ; **10 redraws/s**, **30/s** pour panneau/bandeau visible ; texte/code/Markdown bornés ; autoplacement du panneau à **144 colonnes**, **110** après ouverture préalable. Pour un long ledger, lire une projection bornée du runtime au lieu de promettre un historique complet via `session.messages` ou de multiplier arbitrairement les quotas. [Référence des limites](https://code.claude.com/docs/en/plugins/mods/reference#limits).

Le process API prend un argv et ne passe pas par un shell. Un programme terminé avec exit non nul **résout** avec `{ exitCode, stdout, stderr }` ; démarrage impossible et timeout rejettent. Il faut donc lire `exitCode`, pas considérer un `await` réussi comme un check réussi. `model.complete` distingue pareillement `isAnswered: false` d'une rejection de requête refusée. [API fichiers/process et modèles](https://code.claude.com/docs/en/plugins/mods/api).

**not verified** : disponibilité et parité des événements sur chaque surface, activation réelle de sec-default local, composition des plugins utilisateur, exactitude de l'usage, comportement des interruptions/reloads et impact de latence. Les sources publiques ne donnent pas une garantie de stabilité : l'API peut évoluer entre releases. Le dépôt porte une licence indiquant les droits réservés Anthropic et les Commercial Terms ; ne pas confondre source publiquement consultable avec licence permissive de réutilisation intégrale. [Licence du dépôt](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/LICENSE.md).

## Intégration à Etabli : architecture proposée

### Conserver les autorités partagées

Les décisions de garde restent dans `workflow/runtime/workflow-router-core.mjs`, déjà utilisé par `claude/hooks/plan-ready-guard.mjs` et `pi/extensions/workflow-router.ts`. La reprise reste fondée sur `claude/hooks/session-state.mjs`, `scripts/lib/session-handoff.mjs` et la sélection unique du ledger actif. Les émissions continuent via `workflow-event`, `active-run`, `scripts/lib/ledger-auto-emit.mjs` et les leases de `scripts/workflow-lease`. Le mod lit/projette ces résultats ; il ne les recrée pas dans `$.store`.

Ce choix suit `docs/adr/0006-keep-agent-surfaces-as-adapters-over-shared-workflow-contracts.md`. `docs/adr/0014-stop-injecting-route-context-into-every-prompt.md` interdit de vendre l'intégration comme une nouvelle couche répétitive de contexte de routage. Le retrieval durable reste dans obvault, selon `workflow/skills/obvault-memory.md` ; un appel `model.fork` ne remplace pas cette autorité.

### Le coût de port est concret

**verified** dans Etabli : le core actuel importe `node:fs`, `node:child_process`, `node:path` et des helpers hors d'un dossier plugin. Un mod ne peut pas l'importer directement dans son évaluateur. Copier le core dans le module créerait une politique concurrente.

**inference** : la première passerelle viable est un petit adaptateur qui appelle le CLI/helper canonique par `$.process.run` avec un argv, puis traduit sa réponse explicite. Le helper reste en Node et peut conserver accès aux leases, écriture atomique et règles existantes. Le mod porte l'affichage et l'interception. Le prix est un coût process qu'il faut mesurer, et une réponse dont les erreurs/timeouts doivent rester explicites. Extraire plus tard un noyau purement déterministe à dépendances injectées peut se justifier, après avoir démontré la valeur du chemin réel. Cette extraction n'est pas un préalable au cockpit en lecture seule.

### Ordre des expériences

| Étape | Résultat concret | Preuve attendue pour avancer |
| --- | --- | --- |
| 1. Cockpit en lecture seule | Bandeau du plan + panneau provenance/checks + `/etabli` immediate | Terminal réel : plan absent/READY, ledger absent/ambigu, worktree distinct, changement externe, fenêtre étroite et commande `-p` sans dessin. |
| 2. Instrumentation native | Vue contexte/cache/usage main et agents | Comparaison des chiffres API/événements avec la session ; pas de promesse d'économie avant mesure. |
| 3. Prévisualisation d'actions | État du diff/check et conséquence d'une action autorisée | Cancel/abort/headless ne lancent rien ; les faits exposés viennent du runtime et restent liés à la révision. |
| 4. Pont de garde en shadow | Décision mod et décision hook canonique comparées | Cas refusés et autorisés, exit non nul, timeout, corruption, interruption et mods concurrents. Hooks actuels toujours actifs. |
| 5. Remplacement éventuel | Garde via mod mince, avec contrat Claude/Pi conservé | Parité démontrée sur tiers et surfaces cibles ; reprise et publication restent vérifiables sans UI. |

Ce sont des **inference** de priorisation, pas un `PLAN.md` READY et pas une autorisation d'implémenter/installer. Le prochain résultat utile est le pilote local de la première ligne, lorsque le rollout permet son exécution et qu'une implémentation est demandée.

## Validation effectuée et validation restant à faire

**verified** avec le Claude installé **2.1.287** :

```sh
claude plugin validate /tmp/etabli-claude-mods.0qGX9y/upstream/mods/agents-md
claude plugin validate /tmp/etabli-claude-mods.0qGX9y/upstream/mods/diff
claude plugin validate /tmp/etabli-claude-mods.0qGX9y/upstream/mods/sec-default
claude plugin validate /tmp/etabli-claude-mods.0qGX9y/upstream/mods/telemetry
```

Résultat : **3/4 acceptés statiquement** : agents-md, diff et sec-default **exit 0, Validation passed** ; telemetry **exit 1**, car son flux Anthropic est réservé au tier builtin et ne peut être utilisé par un plugin utilisateur. Ce refus est cohérent avec le gate public ; il ne démontre pas un défaut du builtin intégré. Portée : manifests, imports et usages API, sans session ni dessin.

Test tenté ensuite :

```sh
claude plugin test /tmp/etabli-claude-mods.0qGX9y/upstream/mods/sec-default
```

**blocked**, exit **1**, **0 test runtime exécuté**. Preuve : `/tmp/etabli-claude-mods.0qGX9y/sec-default-test.log` :

```text
claude plugin test: hooks modules are turned off in this process: the rollout switch served off, and a plugin's tests run only while it is on
```

La [documentation de diagnostic](https://code.claude.com/docs/en/plugins/mods/troubleshoot#check-whether-mods-can-load) associe précisément `turned off in this process` à une désactivation distante Anthropic et dit qu'aucun réglage local ne la réactive. **documented** pour cette correspondance ; **verified** pour la sortie de ce processus uniquement. Nous ne déduisons pas l'état de tous les comptes, machines ou sessions. Pas de contournement d'environnement ni retry identique ; le pilote réel reste à reprendre lorsque la disponibilité change.

La suite `claude plugin test` fournit le vrai moteur de hooks avec des réponses stubbées : chaque appel non fourni peut échouer, et un hook ignoré ne fait pas toujours échouer le test immédiatement. Une assertion sur les effets finaux et le chemin de refus reste indispensable. `ui.mount` vérifie l'arbre, les boutons et leur validité, **pas la peinture Ink/Desktop**. [Guide tests](https://code.claude.com/docs/en/plugins/mods/test), [contrat du test kit, lignes 25–42](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts#L25).

Pour un futur pilote : types de la version exécutée, validate strict, tests des décisions et du cycle de vie, puis session réelle et revue des reçus. Pour un garde, ajouter la composition de permissions ; pour une commande/check, ajouter les résultats non zéro/timeout/cancel et l'absence d'UI ; pour le store, ajouter deux sessions/worktrees. Ne pas qualifier une validation statique de workflow fonctionnel de bout en bout.

## Repères de lecture amont

- `mods/types/claude-code.d.ts:1` : version, évaluateur et test kit ; `:2011` API core ; `:3205` fold ; `:5230` continuation ; `:6253` scan de capacités ; `:9832` résultats d'outils ; `:9924` décision de permission ; `:10427` requête modèle.
- `mods/diff/hooks/register.ts:941` : observation du succès réel après l'outil ; `mods/diff/README.md` : tout le comportement UX et Git.
- `mods/agents-md/README.md` : modes, provenance, déduplication et huit différences de loader ; `hooks/register.ts` : routage.
- `mods/sec-default/hooks/register.ts:93` : recheck des deny rules sans utilisateur ; `tests/held-verdict.test.ts:9` : règle nommée vs deny sans règle.
- `mods/telemetry/hooks/register.ts:55` : namespace ajouté sur le fold ; `types/index.d.ts` : contrat partagé ; `README.md` : admission builtin et politique d'envoi.
