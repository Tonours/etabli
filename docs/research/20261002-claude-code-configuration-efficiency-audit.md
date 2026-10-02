# Audit Claude Code : configuration et efficacité de l’abonnement

Date : **2 octobre 2026**. Statut : **verified** pour les observations locales, les agrégats SSH de `macbook-work` et les sources publiques ; **not verified** pour les économies futures et le quota du compte.

## Verdict

Le meilleur levier observé est la taille des conversations qui continuent à être envoyées au modèle, suivie du choix du modèle et de la consommation des agents. Le catalogue de skills local est déjà maîtrisé. Le corpus distant ajoute une priorité : attribuer les instructions héritées et les surfaces des plugins avant de réduire davantage les descriptions des skills partagés.

Dans le répertoire de configuration du shell interactif, les traces des 30 derniers jours contiennent **11 219 requêtes** avec usage non nul. Leur entrée médiane, cache compris, est de **126 731 tokens**, le p95 empirique de **769 944 tokens**. **90,77 %** des tokens traités enregistrés portent le modèle Opus 5.5. Les lectures de cache représentent **98,43 %** de l’entrée enregistrée : le cache fonctionne largement, mais ne rend pas les longues conversations gratuites pour l’abonnement.

La recommandation est de mesurer le quota natif, séparer les travaux indépendants, conserver un contexte ciblé, puis comparer le modèle et l’effort sur des tâches vérifiables. Le profil `claude-lean` mérite une révision : il coupe le LSP TypeScript et remplace les vaults actuels par un ancien serveur `brain` sélectionné selon le scope de la machine.

L’extension SSH apporte **37 831 requêtes** enregistrées sur `macbook-work` pendant la même fenêtre recherchée de 30 jours. Entrée médiane : **155 792 tokens** ; Opus 5/5.5 : **82,81 %** des tokens traités. Les settings actuels y préfèrent Sonnet et `low` pour les modèles 5.5, mais ne prouvent pas les choix historiques. Onze plugins sont activés dans les settings utilisateur et un `~/work/CLAUDE.md` de **10 604 caractères** ajoute une couche d’instructions aux projets descendants. La section 8 détaille ce corpus et les nouvelles pistes.

**Aucun pourcentage d’économie d’abonnement n’est démontré par cet audit.** Les tokens retraités, les prix API et les pourcentages de quota sont des mesures différentes.

## Périmètre, méthode et livrables

- Worktree créé : `/Users/tonours/.codex/worktrees/claude-efficiency-audit/etabli` ; chemin physique `/Volumes/Crucial/.homes/codex/worktrees/claude-efficiency-audit/etabli`.
- Révision Etabli étudiée : `1e79c3caa36ed634fcc2099285e00c253df065eb`.
- Claude installé : **2.1.287**, confirmé par `claude --version` ; binaire natif dans `~/.local/share/claude/versions/2.1.287`.
- Surfaces étudiées : `claude/`, lanceurs et helpers, budgets du workflow, imports, skills, agents, hooks, plugins, MCP, shell de lancement et metadata locale d’usage. Deux répertoires Claude ont été inspectés, car le shell interactif diffère du processus de cet audit.
- Historique initial : compteurs et metadata d’assistant. Extension : traitement des conversations sur leur machine source pour compter les outils, tailles et répétitions, avec indicateurs de mots-clés fixes. Aucun contenu de prompt, résultat d’outil, raisonnement privé ou identité de session n’est conservé dans les preuves. Les configurations MCP ont été inspectées par noms ou nombres de serveurs seulement.
- Recherche : documentation officielle actuelle et sources publiques Anthropic figées ; une recherche déléguée, sans délégation imbriquée. Lecture préalable de la mémoire de projet via alambic-obvault, notamment `kb/skill-catalog-context-budget-gating.md`.
- Route : analyse/recherche, sans modification fonctionnelle de la configuration. Aucun appel d’inférence Claude, installation, commit, push ou changement des paramètres du compte.

Preuves : [configuration du processus](claude-efficiency-20261002/local-evidence.json), [configuration du shell interactif](claude-efficiency-20261002/interactive-evidence.json), [corpus macbook-work](claude-efficiency-20261002/macbook-work-evidence.json), [usages des outils locaux](claude-efficiency-20261002/local-conversation-patterns.json), [vérifications complémentaires](claude-efficiency-20261002/validation.json). Ces fichiers contiennent des agrégats et des valeurs de configuration autorisées, pas des copies des sessions ou des fichiers d’authentification.

La couverture initiale porte sur les paramètres partagés et le projet Etabli. L’extension inspecte aussi les configurations existantes dans les ancêtres des répertoires de travail enregistrés sur `macbook-work`, sans exporter leurs noms. Elle ne reconstitue pas les réglages historiques supprimés. Les politiques administrées, les machines restantes, Claude web et les contextes natifs des sessions actives ne sont pas intégralement observés. Le plan Pro/Max/Team exact et le rattachement des deux machines au même abonnement n’ont pas été confirmés. Les préconisations sur le quota sont donc communes aux abonnements, avec validation dans `/usage`.

## 1. La configuration réellement utilisée

### Deux répertoires différents

| Surface | Shell interactif | Processus de cet audit sans export |
| --- | --- | --- |
| Répertoire | `/Volumes/Crucial/.homes/claude` | `/Users/tonours/.claude` |
| Sélection | export `CLAUDE_CONFIG_DIR` dans `.zshrc` | variable absente |
| Opus 5.5, effort utilisateur | `modelSettings` : `medium` | `modelSettings` : `high` |
| Skills découverts par le check | 88 | 42 |
| Skills visibles au modèle selon le check | 20 | 20 |
| Taille projetée du catalogue | 3 651 caractères | 3 651 caractères |
| MCP user configurés | `alambic-brain`, `alambic-obvault` | sept noms dans `~/.claude.json` |
| Plugins activés par settings | `typescript-lsp@claude-plugins-official` | clé `enabledPlugins` absente |
| Mémoire automatique | désactivée | désactivée |

Les sept noms du second store sont `chrome-devtools`, `mobbin`, `uidotsh`, `web-reader`, `web-search-prime`, `zai-mcp-server` et `zread`. Ils ne représentent pas les MCP du lancement interactif configuré. La présence d’une entrée ne prouve ni connexion ni chargement de ses schémas.

Claude Code permet de déplacer ses settings, plugins et sessions avec `CLAUDE_CONFIG_DIR`. C’est pourquoi un audit limité à `~/.claude` aurait produit une conclusion incorrecte sur ton utilisation habituelle. [Settings officiels](https://code.claude.com/docs/en/settings#settings-files).

**Action prioritaire :** rendre explicites le répertoire et le profil dans chaque point d’entrée, y compris lancement depuis Herdr, automatisation et CLI non interactif. Ne pas fusionner les stores ni modifier les liens globaux depuis un worktree d’analyse. Les liens des imports et hooks gérés pointent actuellement vers `/Volumes/Crucial/work/etabli`, ce qui est le déploiement observé, pas une isolation du runtime dans ce worktree.

### Ce qui est déjà bien réglé

Dans le store interactif : `promptSuggestionEnabled:false`, `awaySummaryEnabled:false`, `autoMemoryEnabled:false`, `enableWorkflows:false` et `workflowKeywordTriggerEnabled:false`. Les suggestions et workflows dynamiques ne sont donc pas de nouveaux leviers à désactiver par défaut. `CLAUDE_CODE_SUBAGENT_MODEL` vaut `sonnet` ; la mémoire automatique est aussi désactivée par une variable d’environnement.

Les overrides locaux répartissent les skills en **20 `on` et 68 `user-invocable-only`**. Les checks des profils lean et complet passent. Le répertoire contient 90 entrées, dont 88 skills découverts ; une entrée de répertoire n’équivaut pas à un skill chargé.

La source des settings ne fixe pas un modèle principal unique : le modèle effectif peut venir du compte, d’un flag ou d’une session reprise. L’effort `medium` sauvegardé aujourd’hui ne prouve pas l’effort historique de toutes les requêtes.

### Lanceurs et profil lean

`scripts/claude-lean` et `scripts/claude-full` existent et fonctionnent dans le dépôt ; aucun des deux n’est sur le PATH du processus audité. L’alias interactif `claude` ne sélectionne pas lean : il ajoute `LEAN_CTX_AGENT` et `BASH_ENV`. `.bashenv` contient encore un passage conditionnel par `lean-ctx`, tandis que ce binaire est absent du PATH audité. C’est une dérive à nettoyer, sans preuve que deux filtres tournent effectivement.

Le lancement lean applique `--settings`, `--strict-mcp-config` et un fichier MCP temporaire `0600`, supprimé à la sortie. Il ne fixe pas le modèle principal. Son `effortLevel:low` passé via **`--settings`** prime sur le réglage utilisateur `medium`, sous réserve de managed settings et des choix explicites. Dans une même source, le réglage par modèle prime. Les flags/env et le frontmatter actif peuvent encore déterminer l’effort. [Priorité officielle](https://code.claude.com/docs/en/settings-reference#modelsettings).

Deux écarts concrets :

1. Lean désactive **12 noms de plugins**, dont le LSP TypeScript actuellement activé. Le nombre 12 ne signifie pas que 12 plugins actifs sont économisés. Le registre installé contient aussi des noms historiques provenant d’autres marketplaces.
2. `--no-strict-mcp` est décrit dans l’aide comme ajoutant le MCP lean, mais `buildLeanLaunch` omet alors **les deux flags MCP**. Le fichier est rendu puis nettoyé, sans être passé au CLI. Ce mode conserve les configurations natives ; il n’ajoute pas le serveur lean. Evidence : `scripts/claude-lean:29`, `scripts/lib/claude-profile.mjs:98` et la sonde argv dans `validation.json`.

Le serveur `brain` est choisi par `~/.etabli-scope=work` et la présence du vault. Notre contrat mémoire choisit pourtant le vault selon l’organisation du dépôt : **Etabli → obvault**, ForestAdmin → brain. Le profil peut donc charger le mauvais vault par rapport au projet. Le CLI mémoire reste disponible ; un MCP assaini n’est pas une garantie de bonne sélection. Sources locales : `scripts/lib/claude-profile.mjs:41`, `claude/profiles/lean.mcp.template.json:4`, `workflow/skills/obvault-memory.md:22`.

## 2. Les mesures locales de consommation

Fenêtre recherchée : du 2 septembre au 2 octobre 2026, UTC. Store interactif : **357 fichiers récents inspectés**, zéro erreur de parsing ; données d’usage non nul observées du **23 septembre à 12:00 UTC au 2 octobre à 10:27 UTC**. La fenêtre recherchée de 30 jours ne signifie donc pas 30 jours d’activité effectivement couverts.

Les fragments sont dédupliqués par `(modèle déclaré, requestId ou message.id)` en conservant le maximum de chaque compteur. Les records sans usage non nul sont exclus. Aucun corps de message n’est analysé. Les chiffres suivants sont une observation des metadata de transcript, **pas une facture fournisseur ni une mesure d’économie causale**.

| Mesure | Store interactif |
| --- | ---: |
| Requêtes avec usage non nul | 11 219 |
| Entrée non cachée | 30 542 tokens |
| Écriture de cache | 41 120 428 tokens |
| Lecture de cache | 2 587 474 503 tokens |
| Sortie | 11 045 075 tokens |
| Total traité, somme des quatre composantes | 2 639 670 548 tokens |
| Entrée par requête, médiane | 126 731 tokens |
| Entrée par requête, p95 empirique | 769 944 tokens |
| Entrée par requête, maximum | 966 872 tokens |
| Première requête observée par fichier récent, médiane, n=327 | 22 563 tokens |

Le total additionne les relectures du même contexte : **il ne représente pas 2,64 milliards de tokens uniques**. La première requête d’un fichier récent peut être une reprise ou un sous-agent ; les 22 563 tokens ne sont pas une mesure de cold start contrôlée.

| Modèle déclaré | Requêtes | Tokens traités enregistrés |
| --- | ---: | ---: |
| Opus 5.5 | 7 641 | 2 395 983 721 |
| Sonnet 5 | 3 238 | 223 909 211 |
| Fable 5.1 | 262 | 16 190 932 |
| Haiku 4.5 | 73 | 3 555 988 |
| Sonnet 5.5 | 5 | 30 696 |

Les sous-agents représentent **3 862 requêtes**, **11,32 %** des tokens traités et **39,72 %** des tokens de sortie. Ces parts ont des dénominateurs différents. Leur contexte plus court peut expliquer une part de tokens traités inférieure à leur part de sortie ; leur efficacité et leur qualité par tâche restent inconnues.

Le store de repli contient **605 requêtes** et **138 990 995 tokens traités** sur sa fenêtre. Ses agrégats ne sont pas additionnés à ceux du store interactif : des copies de sessions peuvent se recouvrir. L’activité des autres machines et de Claude chat n’est pas incluse.

**Interprétation :** les longs historiques, l’usage d’Opus et les sorties des agents sont des candidats prioritaires. Ces traces ne permettent pas d’identifier la part de travail utile, les raisonnements nécessaires, les retries ou les sessions qui mélangeaient plusieurs tâches. Aucune conclusion de qualité n’est tirée du nombre brut de tokens.

## 3. Comment Claude Code consomme ce contexte

La boucle alterne décision du modèle, appels d’outils et requête suivante alimentée par leurs résultats. Le contexte contient instructions, conversation, fichiers lus et résultats d’outils. Réduire un gros log **avant** son ingestion peut éviter sa relecture sur les tours suivants. Masquer son affichage après ingestion n’a pas cet effet. [Fonctionnement officiel](https://code.claude.com/docs/en/how-claude-code-works).

Les imports `@...` de CLAUDE.md sont chargés au démarrage, jusqu’à quatre niveaux. Découper un gros fichier en imports organise le contenu sans le rendre facultatif. Pour du contenu spécialisé, utiliser des règles conditionnelles par chemin et des skills invoqués à la demande. Une importation d’AGENTS.md ne prouve pas à elle seule un double chargement. [Mémoire](https://code.claude.com/docs/en/memory#import-additional-files), [déduplication publiée du mod agents-md](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/agents-md/hooks/files/unseen-files.ts).

Le cache est automatique. La documentation distingue un TTL principal d’une heure dans l’abonnement inclus, cinq minutes par défaut sur API ou crédits payants. Le modèle possède son propre cache ; une bascule entraîne une relecture. Les modèles récents peuvent conserver le cache après changement d’effort, selon le provider. Il faut donc éviter les changements répétés de modèle dans une grosse conversation et observer les rebuilds. [Cache officiel](https://code.claude.com/docs/en/prompt-caching).

Le quota de l’abonnement est partagé avec les autres surfaces Claude. Son allocation exacte ne se déduit pas des prix API. Max propose des allocations 5× ou 20× Pro, avec fenêtres de session et hebdomadaires ; aucun volume garanti de travaux terminés ne peut être calculé depuis les fichiers locaux. [Usage Pro/Max](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan), [plan Max](https://support.claude.com/en/articles/11049741-what-is-the-max-plan).

`/clear` n’effectue pas d’inférence ; `/compact` résume via le modèle. La compaction sert la continuité, tandis qu’un nouveau travail indépendant peut commencer après clear. `/usage` expose l’usage du compte et une attribution locale approximative aux agents, skills, plugins et MCP. Cette attribution exclut les autres machines et Claude chat. [Coûts et usage officiels](https://code.claude.com/docs/en/costs).

## 4. Audit des leviers de configuration

### Instructions et workflow

Le budget statique Etabli passe sur **8/8 surfaces** :

| Surface contractuelle | Caractères | Estimation chars/4 |
| --- | ---: | ---: |
| always-on, union contractuelle | 12 066 | 3 017 |
| plan-loop | 6 450 | 1 613 |
| plan-implement | 55 406 | 13 852 |
| implement | 50 061 | 12 516 |
| review | 21 811 | 5 453 |
| verify | 3 776 | 944 |
| spec-map | 30 120 | 7 530 |
| ship | 83 241 | 20 811 |

**Ces nombres sont des proxys statiques**, issus de `scripts/workflow-context-budget --json`. La surface always-on est une union de fichiers de plusieurs harnesses et de lectures prescrites, pas un relevé du prompt Claude effectivement envoyé. La quick card citée en prose n’est pas un import natif `@`. Les routes utilisent aussi des adaptateurs Pi : leur poids n’est pas automatiquement le poids du chemin Claude.

Les entrées natives observées restent petites : adaptateur global 1 946 caractères ; règles Pi importées 2 668 ; CLAUDE.md du projet 184, important AGENTS.md de 2 394. L’intérêt probable se trouve davantage dans les lectures successives des gros contrats et dans les données explorées.

Le RTK.md installé dans le store interactif fait **958 caractères**, contre **335** pour le fichier suivi. Celui installé décrit une réécriture générale ; le garde actuel la limite aux commandes dont le flux est sûr. L’import relatif et les éventuelles déduplications restent à confirmer via `/memory` ou `/context` en session. Le RTK.md du store de repli est absent, sans preuve de panne de l’import via le lien résolu.

**Recommandation :** maintenir les cartes comme points d’entrée, ouvrir les annexes au besoin de la phase, conserver READY, preuves, permissions et reprise. Ne pas réduire un check obligatoire ou un critère d’acceptation pour gagner des tokens.

### Skills et plugins

`skillOverrides` est supporté avec `on`, `name-only`, `user-invocable-only` et `off`. Les skills des plugins échappent à ce réglage. `skillListingBudgetFraction:0.008` fixe un budget de catalogue en **caractères** ; il ne garantit pas une réduction équivalente de tokens ni la disparition des noms. [Skills officiels](https://code.claude.com/docs/en/skills#override-skill-visibility-from-settings).

Le catalogue projeté est identique, lean ou complet, à **3 651 caractères**. Les 46 skills supplémentaires du store interactif sont gouvernés hors du set automatique. Modifier encore tout le catalogue offre donc un potentiel statique faible comparé aux contextes mesurés.

Conserver le LSP TypeScript sur les projets TypeScript est une hypothèse raisonnable : la navigation de symboles peut éviter plusieurs recherches/lectures et faire remonter des erreurs tôt. Le tester sur un même parcours de code ; désactiver un plugin utile peut faire augmenter le nombre de tours. [Intelligence de code officielle](https://code.claude.com/docs/en/discover-plugins#code-intelligence).

### MCP et mémoire

Les définitions complètes MCP sont différées par défaut dans la version documentée actuelle ; seuls noms et instructions serveur entrent initialement. `ENABLE_TOOL_SEARCH=auto` rétablit un seuil de 10 %, et `false` charge tout. Ces anciennes recettes ne doivent pas être appliquées automatiquement. [MCP officiel](https://code.claude.com/docs/en/mcp#scale-with-mcp-tool-search).

Le store interactif n’a que deux MCP de vault configurés ; le projet Etabli en déclare zéro. Le premier travail est de vérifier leur poids dans `/context`, le vault réellement utilisé et les résultats retournés. Garder la récupération bornée et les citations. Préférer le CLI pour une opération simple quand il évite un résultat MCP volumineux, en mesurant ce parcours concret.

### Modèles, effort et agents

| Rôle suivi | Modèle | Effort | maxTurns |
| --- | --- | --- | ---: |
| scout | sonnet | medium | 24 |
| worker | opus | medium | 40 |
| reviewer | sonnet | medium | 24 |
| adversary | fable | low | 24 |

En 2.1.287, le modèle d’invocation et le frontmatter priment sur `CLAUDE_CODE_SUBAGENT_MODEL`. La variable `sonnet` ne force donc pas les quatre rôles. Le built-in Explore hérite du modèle principal ; une simple variable par défaut ne suffit pas à le faire passer sur Sonnet. Un fork hérite aussi du contexte principal. Les versions antérieures avaient un ordre différent. [Sous-agents officiels](https://code.claude.com/docs/en/sub-agents#choose-a-model).

Le shell active **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`**. Ce réglage est distinct de `enableWorkflows:false`. En interactif, un appel Agent avec `name` peut devenir teammate sans demande explicite de team, hors exceptions fork/isolation ; en `-p`/SDK, il reste un sous-agent. Une préférence verbale pour parent+scout ne garantit donc pas une exécution ordinaire. Proposer `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0` pour les sessions quotidiennes, puis réactiver sur besoin identifié. Leur disponibilité ne prouve pas qu’elles ont tourné dans les traces. [Teams officielles](https://code.claude.com/docs/en/agent-teams#enable-agent-teams), [déclenchement](https://code.claude.com/docs/en/agent-teams#how-claude-starts-agent-teams), [workflows](https://code.claude.com/docs/en/settings-reference#enableworkflows).

Comparer Sonnet/medium pour une tâche ordinaire et Opus/medium pour une tâche difficile, tout en conservant les choix explicites du demandeur. Réserver `low` aux tâches faciles et vérifiables. Le thinking adaptatif des modèles récents ne se pilote pas efficacement par une ancienne recette `MAX_THINKING_TOKENS=0`. [Effort officiel](https://code.claude.com/docs/en/model-config#adjust-effort-level), [effort API](https://platform.claude.com/docs/en/build-with-claude/effort).

Ne pas imposer Haiku à toutes les reviews ou diminuer arbitrairement maxTurns. Un agent arrêté trop tôt peut entraîner reprise et nouveau contexte. L’indépendance de contexte et la diversité de modèle sont deux exigences distinctes ; conserver celle requise par le contrat de chaque review.

### Hooks et traitements déterministes

Tous les hooks configurés inspectés sont de type **`command`**, pas des hooks `prompt`/`agent`. La différence est matérielle : un command hook exécute du code ; les autres peuvent appeler un modèle. [Hooks officiels](https://code.claude.com/docs/en/hooks#prompt-based-hooks).

Les guards, le journal, la correction, les notifications et la reprise ont leurs scripts présents. `session-state` ne réinjecte l’état que sur compact/resume et seulement si un plan ou ledger actif existe. Le Stop ADR peut provoquer un tour supplémentaire après signal structurel ; il dispose d’une protection contre une nouvelle relance dans la même session. Herdr utilise un socket local. Le hook de harvest lance un processus de vault : son statut command ne démontre pas l’absence de provider dans tout le traitement aval, qui n’a pas été exercé.

RTK a été sondé sans lancer les commandes cibles : `git status` devient `rtk git status`, et `git diff | head -80` est réécrit ; une séquence `git status && git log -1` et une redirection vers un fichier restent intactes. C’est la protection voulue du flux de données, pas une panne de RTK. Formuler des commandes simples ou ajouter RTK explicitement lorsque c’est sûr ; conserver les logs complets accessibles et le code de sortie.

Le compteur global RTK rapporte environ **53,3 % de réduction estimée des sorties** sur tous ses usages locaux. Il ne mesure pas Claude seul, le quota, ni la qualité. Son avertissement « no hook installed » ne détecte pas nécessairement notre hook personnalisé ; les sondes du garde attestent sa réécriture.

Les routines suivies et `pr-autoreview` lancent Claude sans choix explicite de modèle/effort. Leur coût actuel n’a pas été attribué. Aucun cron Claude/routine n’a été trouvé ; le seul LaunchAgent correspondant est un watcher Herdr toutes les 60 secondes. Cela ne prouve pas un appel modèle chaque minute. Il faudrait mesurer les lancements réels avant de désactiver une routine.

## 5. Ce que le code public permet d’étudier

L’amont `anthropics/claude-code` a été figé à **`52c76441cae91f6891e4712306bffb057ff6fec5`**, commit du 1er octobre 2026. L’arbre complet compte 1 525 fichiers, dont 1 290 sous `mods/`, 149 sous `plugins/` et 38 sous `examples/`. Il ne publie pas le moteur complet sous `src/`, `packages/` ou `cli/`. Le changelog confirme l’introduction des mods en 2.1.287. [Arbre figé](https://api.github.com/repos/anthropics/claude-code/git/trees/52c76441cae91f6891e4712306bffb057ff6fec5?recursive=1), [changelog](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/CHANGELOG.md).

L’analyse couvre les consommateurs et types publics, pas les garanties internes du moteur propriétaire :

| Source publique étudiée | Mécanisme pertinent | Application Etabli |
| --- | --- | --- |
| `mods/agents-md/hooks/register.ts` et `files/unseen-files.ts` | Chargement du contexte, imports et déduplication | Éviter un nouveau injecteur d’instructions redondant |
| `mods/diff/` | Observation d’outils et UI locale | Afficher un diff sans demander au modèle de le raconter |
| `mods/telemetry/` | Instrumentation, namespace et gates | S’inspirer du contrat ; conserver nos preuves localement |
| `mods/sec-default/` | Admission et politique des plugins | Garder les contrôles de sécurité pendant l’optimisation |
| `mods/types/claude-code.d.ts` | API de contexte et appels modèles | Distinguer observation déterministe et requête d’inférence |

Sources : [mods figés](https://github.com/anthropics/claude-code/tree/52c76441cae91f6891e4712306bffb057ff6fec5/mods), [types publics](https://github.com/anthropics/claude-code/blob/52c76441cae91f6891e4712306bffb057ff6fec5/mods/types/claude-code.d.ts). Leur version peut différer du runtime installé ; les types générés pour ce runtime prévalent.

Le SDK Python public, figé à `bfb895c6ef46e095191938b4eda798a025957c09`, pilote un sous-processus Claude Code par JSON. Il n’offre pas une seconde implémentation publique du moteur permettant de changer gratuitement sa politique de contexte. [Transport SDK](https://github.com/anthropics/claude-agent-sdk-python/blob/bfb895c6ef46e095191938b4eda798a025957c09/src/claude_agent_sdk/_internal/transport/subprocess_cli.py#L237).

Le cockpit Etabli existant s’inscrit dans le levier utile : `/etabli` expose l’état du workflow et les mesures natives via `session.measure` et `$.session.usage`, sans soumettre un prompt pour afficher ces vues. La présence des handlers est vérifiée statiquement ; son activation dans ton lancement habituel et son quota live ne sont pas prouvés ici. Sources : `claude/mods/etabli/hooks/register.js:199`, `claude/mods/etabli/hooks/views.js:16`, `docs/claude-etabli-mod.md:1`.

**Recommandation :** utiliser l’observation native et les commandes déterministes avant d’ajouter un proxy, un résumeur autonome ou un mod qui appelle `$.model.complete/fork/classify`. Modifier constamment les instructions peut déclencher des rebuilds ; aucune réécriture opaque du prompt système n’est proposée.

## 6. Priorités concrètes

| Priorité | Intervention proposée | Preuve motivant la proposition | Validation nécessaire |
| --- | --- | --- | --- |
| P1 | Rendre le lancement et le store explicites | Deux stores, efforts et catalogues différents | Même profil observé en terminal, Herdr et CLI |
| P1 | Afficher quota 5h/7j, contexte et cache dans le cockpit/statusline | Pas de quota du compte dans les preuves actuelles | Valeurs natives présentes ou marquées inconnues |
| P1 | Un travail indépendant par session ; reprise ciblée pour la continuité | Entrée médiane 126 731, p95 769 944 tokens | Moins d’entrée par travail réussi, sans perte de reprise |
| P1 | Comparer le modèle par tâche, garder medium par défaut quotidien | Opus : 90,77 % des tokens traités ; medium déjà sauvegardé | Qualité, reprises, latence et quota par tâche |
| P1 | Réviser lean : garder LSP utile et sélectionner le vault du dépôt | TypeScript désactivé, ancien `brain` lié au scope machine | Navigation correcte et mémoire du bon projet |
| P2 | Opt-in teams à 0 pour les sessions ordinaires ; scouts avec modèle ciblé | Teams activées ; Explore peut hériter d’Opus | Sous-agent ordinaire observé, qualité conservée |
| P2 | Limiter logs/diffs lus avant ingestion ; garder annexes à la demande | RTK fonctionne, mais commandes complexes peuvent rester brutes | Codes de sortie, preuves et erreurs toujours disponibles |
| P2 | Aligner RTK.md, aide du lanceur et vieux wrapper shell | Drift live/suivi et mode no-strict différent de son aide | Contrats exacts, absence de régression des commandes |
| P2 | Attribuer les instructions héritées et plugins par projet sur macbook-work | Ancêtre de 10 604 caractères, onze plugins utilisateur activés, hooks SessionStart/UserPromptSubmit | `/context`, fonctionnalités utilisées et qualité conservée |
| P2 | Réutiliser les résultats de recherche stables dans une même tâche | Appels identiques à Linear/Slack dans les traces distantes | Vérifier fraîcheur et droits ; aucune réutilisation aveugle des données modifiées |
| P3 | Affiner skills/MCP après attribution réelle | Catalogue déjà à 3 651 caractères, deux MCP natifs | `/context`, usage par outil et absence de capability perdue |

La statusline native expose modèle, effort, quatre compteurs, cache et fenêtres de quota Pro/Max après réponse. Les statistiques de cache principal excluent les sous-agents ; les champs absents doivent rester inconnus. [Statusline officielle](https://code.claude.com/docs/en/statusline#available-data).

Fast mode utilise des crédits payants même lorsque l’usage inclus est disponible : il ne répond pas à l’objectif d’allonger l’abonnement. [Fast mode](https://code.claude.com/docs/en/fast-mode#requirements). `--bare` saute imports/hooks et attend une authentification API ; le CLI local le confirme dans son aide. Il ne constitue pas un profil quotidien équivalent sous abonnement.

### Usage immédiat avec la configuration actuelle

Pour une nouvelle tâche ordinaire, un choix de session explicite évite de modifier la préférence sauvegardée :

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 CLAUDE_CONFIG_DIR=/Volumes/Crucial/.homes/claude command claude --model sonnet --effort medium
```

Pour un travail difficile nécessitant Opus :

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 CLAUDE_CONFIG_DIR=/Volumes/Crucial/.homes/claude command claude --model opus --effort medium
```

Ces commandes sont des propositions ; aucune session d’inférence n’a été lancée. Vérifier `/model`, `/context`, `/usage` et les mesures du cockpit. Garder `high` lorsque le travail ou une demande explicite le nécessite. Éviter des bascules répétées dans une conversation déjà volumineuse.

Le lanceur lean peut être appelé par son chemin `./scripts/claude-lean`; son intérêt reste à mesurer après correction des écarts décrits. Il ne remplace pas silencieusement l’entrée quotidienne dans cet audit.

## 7. Comment démontrer une économie réelle

Objectif à mesurer : **travaux correctement terminés par unité de quota**, avec latence et reprises comme mesures complémentaires. Une réduction de caractères, un compteur `input_tokens` seul ou un dollar API estimé ne suffisent pas.

1. Figer une baseline : store, version, modèle, effort, imports, plugins, MCP et tâche. Conserver les empreintes des instructions. Lire le quota avant et après via les surfaces natives, sans requête directe utilisant des credentials.
2. Comparer un seul levier à la fois : historique ciblé, modèle, LSP ou profil. Utiliser les mêmes tâches, tests et règles de sécurité. Réserver des cas jamais utilisés pour ajuster la configuration.
3. Pour un pilote borné : 6 tâches représentatives × 2 configurations × 3 répétitions = 36 exécutions, maximum 120 minutes de travail expérimental. Ce pilote reste **proposé et non lancé** ; aucun budget d’inférence n’est consommé ici.
4. Comptabiliser entrée non cachée, cache créé, cache lu et sortie ; inclure sous-agents, opérations auxiliaires, retries et échecs dans le coût. Vérifier la réconciliation `result.usage`/transcripts et la fin de transport.
5. Compter une livraison uniquement si ses critères passent. Rejeter une régression critique, un résultat tronqué ou une perte de capacité nécessaire. Comparer médianes/p95 sur des populations répétées, pas un p95 de run unique.
6. Pour le quota, isoler les activités concurrentes du compte. Les pourcentages d’abonnement sont globaux et leur granularité peut rendre un petit écart inconclusive. Garder alors les tokens et la qualité comme diagnostics, sans annoncer un gain de quota.

Le dépôt possède déjà `scripts/claude-agent-benchmark`, `scripts/claude-token-budget` et `scripts/harness-token-eval`. Réutiliser leur comptabilité et leurs règles de provenance au lieu de fabriquer un nouveau compteur. La campagne antérieure documentée dans `docs/claude-token-budget.md` n’avait pas joué le holdout complet ; ses ratios de surface ne prouvent pas 50 % de gain quotidien. Ce protocole devra être gelé dans un READY PLAN.md si sa mise en œuvre est demandée.

## 8. Extension du corpus : macbook-work

### Collecte et couverture

Connexion SSH explicitement demandée, traitement **en lecture seule sur la machine distante**. Aucun transcript brut, source métier ou fichier de credentials n’a été copié. Les lectures portent sur les settings Claude, surfaces de plugins, instructions, metadata shell et conversations sous `~/.claude/projects`.

La fenêtre est figée sur celle du premier audit : **2 septembre 2026 à 13:24:38 UTC → 2 octobre à 13:24:38 UTC**. Parmi **1 167 fichiers JSONL présents**, **1 159** dont la date de modification est récente ont été parcourus, soit environ **1,05 Go lus sur place** ; huit fichiers anciens ont été écartés. Les usages non nuls couvrent effectivement le 2 septembre à 13:24:59 UTC jusqu’au 2 octobre à 13:24:37 UTC. Zéro erreur de parsing JSON ; les records sans timestamp sont exclus, sans record d’assistant portant usage parmi ceux exclus pour ce motif.

Même déduplication que l’audit local : maximum des quatre compteurs par `(modèle déclaré, requestId ou message.id)`, globalement entre main et sous-agents. Les **37 831 requêtes** proviennent de **71 874 fragments** avec usage non nul. Les appels d’outils sont dédupliqués par `tool_use.id`. Les répétitions comparent un hash interne de l’entrée et de la session ; ni ces hashes ni les identités ne sont exportés.

Les deux machines sont présentées séparément : aucune somme n’est annoncée comme nombre de requêtes uniques du compte, car les éventuelles copies de sessions entre machines n’ont pas été réconciliées. Les fichiers actifs ont continué à évoluer pendant la lecture ; le filtre temporel conserve la borne commune et les agrégats d’usage ont été identiques sur deux lectures.

### Configuration distante observée

| Surface | macbook-work | Machine locale, store interactif |
| --- | --- | --- |
| Store inspecté | `~/.claude` ; export alternatif non trouvé dans les fichiers shell directs | `/Volumes/Crucial/.homes/claude`, export confirmé |
| Préférence principale sauvegardée | `model:sonnet` | pas de préférence principale unique dans le fichier |
| Effort par modèle 5.5 | Opus `low`, Sonnet `low` | Opus `medium` |
| Worker partagé installé | Sonnet, medium, 40 tours | Opus, medium, 40 tours |
| Plugins `true` dans settings utilisateur | 11 | 1 : TypeScript LSP |
| Skills locaux découverts par présence de SKILL.md | 81, pour 83 entrées de répertoire | 88 |
| Overrides sauvegardés | 20 `on`, 59 `user-invocable-only` | 20 `on`, 68 `user-invocable-only` |
| Ancêtre `~/work/CLAUDE.md` | présent : 10 604 caractères | absent à ce chemin |
| MCP dans configuration utilisateur | alambic-brain, chrome-devtools | alambic-brain, alambic-obvault |

Selon la priorité des settings documentée, les entrées par modèle `low` priment sur la clé globale utilisateur `effortLevel:high` dans cette même source. Cette dernière ne suffit pas à qualifier la machine de « high ». Les flags, reprises, autres sources et le frontmatter peuvent modifier le résultat. Les versions déclarées dans les traces distantes vont de **2.1.258 à 2.1.284** ; le CLI actuel n’a pas été localisé dans le PATH SSH ni dans les emplacements candidats inspectés. Les préférences sauvegardées sont vérifiées ; leur application dans un lancement interactif actuel reste **not verified**. [Priorité officielle](https://code.claude.com/docs/en/settings-reference#modelsettings).

Les instructions utilisateur et le fichier `~/.claude/RTK.md` ont les mêmes empreintes sur les deux machines. Le graphe d’imports résolu depuis la cible du symlink distant contient le fichier utilisateur de 1 946 caractères, un AGENTS.md de 2 689 et un RTK.md de **335** : le fichier user RTK.md de 958 caractères n’est donc pas cette cible d’import. Ce graphe statique suit les chemins des sources ; il ne mesure pas le prompt natif d’une session. Les instructions des ancêtres s’ajoutent pour les projets descendants. [Mémoire et imports](https://code.claude.com/docs/en/memory).

L’inventaire des répertoires de travail déclarés dans les traces trouve **8 settings de projet, 8 settings locaux, 29 CLAUDE.md et un .mcp.json vide** encore présents dans leurs ancêtres. Trois fichiers sauvegardent Sonnet 5.5/low. Les CLAUDE.md mesurent entre 184 et 37 066 caractères, p95 34 622 ; ce sont des fichiers distincts, pas 29 imports dans une même session. Certaines configurations projet activent aussi code-review, commit-commands, feature-dev et document-skills. Le checkout Etabli distant est sur `main` à `f7ec82f58903839434bbb6c87e2e6c4cc02342cf`, différent de la révision du worktree étudié.

Les onze plugins utilisateur activés sont caveman, code-simplifier, datadog, forest, macroscope, ponytail, pr-review-toolkit, superpowers, telegram, typescript-lsp et typesafe. Leurs metadata installées exposent notamment **48 fichiers de skills** au total, hors skills locaux ; leur présence ne prouve pas leur chargement. Les overrides des skills utilisateur ne réduisent pas ceux des plugins. Le registre de pr-review-toolkit comporte 61 installations de scope, sans preuve de 61 chargements simultanés. Les hooks déclarés de ponytail, caveman et superpowers touchent SessionStart ; ponytail/caveman touchent aussi UserPromptSubmit. Tous les types de hooks trouvés dans ces metadata sont `command`. Cela justifie une attribution par contexte et comportement avant de changer le profil, pas une estimation de tokens par nombre de plugins. [Portée des overrides](https://code.claude.com/docs/en/skills).

### Consommation distante et comparaison temporelle

| Mesure | macbook-work, fenêtre de 30 jours |
| --- | ---: |
| Requêtes avec usage non nul | 37 831 |
| Entrée non cachée | 221 636 |
| Cache créé | 181 434 239 |
| Cache lu | 8 129 790 674 |
| Sortie | 23 454 784 |
| Somme des quatre compteurs | 8 334 901 333 |
| Entrée par requête : médiane / p95 | 155 792 / 603 648 |
| Part Opus 5 + Opus 5.5 des tokens traités | 82,81 % |
| Cache lu / total d’entrée | 97,81 % |
| Sous-agents / tokens traités ; sous-agents / sortie | 8,52 % ; 21,04 % |

Les milliards représentent le retraitement cumulé de contextes, pas des milliards de tokens de texte unique ni une facture API. **3 186 requêtes** ont une entrée d’au moins 512 000 tokens : **8,42 %** des requêtes et **24,78 %** de la somme des compteurs. Cette concentration donne une cible de diagnostic ; couper le contexte correspondant sans vérifier la tâche peut dégrader le résultat.

Pour éviter de comparer trente jours distants à neuf jours locaux observés, voici la **fenêtre commune du 23 septembre à 12:00:55 UTC au 2 octobre à 13:24:38 UTC** :

| Mesure | Local interactif | macbook-work |
| --- | ---: | ---: |
| Requêtes | 11 219 | 20 600 |
| Entrée médiane | 126 731 | 151 066,5 |
| Entrée p95 | 769 944 | 569 790 |
| Part Opus 5.5 des tokens traités | 90,77 % | 70,04 % |

Ces populations diffèrent par tâches, applications, modèles et ancienneté du contexte. Aucun ratio de productivité ou d’efficacité entre machines n’en est déduit. La préférence Sonnet actuelle et le worker distant Sonnet ne prouvent ni un gain acquis ni le modèle de toutes les conversations reprises.

### Ce que les conversations ajoutent aux recommandations

Les traces distantes contiennent **39 643 appels d’outils uniques**, dont **27 076 Bash, 3 237 Read et 634 Agent**. Elles attestent des usages historiques de lean-ctx, Linear, Slack, navigateur, documentation et Datadog : les deux MCP des settings utilisateur ne décrivent donc pas tous les outils effectivement utilisés. Les noms d’outils ne permettent pas d’attribuer seuls leur source à un scope précis.

| Observation distante | Mesure | Piste à valider |
| --- | --- | --- |
| Read sans offset, limit ni pages explicitement passé | 1 934 / 3 237 | Cibler symboles et plages lorsque la lecture complète ne sert pas la tâche |
| Taille d’un résultat Read | médiane 2 639 caractères ; p95 27 474 ; max 410 840 | Garder les fichiers complets disponibles, mais récupérer les passages nécessaires |
| Même entrée Read dans la même session | 419 appels supplémentaires sur 3 237 | Réutiliser une lecture stable ; relire après modification pertinente |
| Même entrée Linear get_issue dans la même session | 268 appels supplémentaires sur 611 | Conserver le contexte du ticket, rafraîchir sur changement plutôt que systématiquement |
| Même recherche Slack public/private dans la même session | 135 appels supplémentaires sur 181 | Conserver les références pertinentes ; resserrer ou rafraîchir la recherche selon besoin |
| lean-ctx ctx_shell / ctx_read | 1 756 / 242 appels observés | Comparer à lecture Bash/Read équivalente, avec même résultat utile |
| Appels Agent avec argument modèle explicite reconnu | 69 / 634 | Vérifier le rôle et son frontmatter avant de modifier le défaut |

L’absence d’argument modèle n’implique pas l’absence de routage : frontmatter et environnement peuvent le fournir. De même, une relecture peut être justifiée par un fichier modifié ou une vérification. **Ces répétitions ne sont pas classées automatiquement comme gaspillages.**

Les tailles sont des caractères de contenu ou de sérialisation JSON, pas des tokens. Les résultats visuels peuvent contenir des images/base64 ; leur taille ne donne pas un coût textuel fiable. Les erreurs `is_error` ne prouvent pas des retries évitables. Les indicateurs fixes de mots-clés dans les messages utilisateur servent à sélectionner de futures tâches représentatives ; ils ne constituent ni une analyse sémantique exhaustive ni un jugement de réussite.

La comparaison locale obtenue avec le même extracteur retrouve exactement les **11 219 requêtes et 2 639 670 548 tokens traités** de la première collecte. Elle constate aussi des résultats Read volumineux — p95 **41 975 caractères**, maximum **418 380** — ce qui soutient une amélioration de récupération ciblée sur les deux machines, sans économie de quota démontrée.

**Priorités ajoutées :** observer les instructions héritées et surfaces de plugins via `/context` ; tester une récupération plus ciblée et la réutilisation de résultats stables ; comparer les profils sur des tâches de travail et des tâches personnelles séparées. Conserver le LSP et les capacités nécessaires. La désactivation générale de plugins, la fusion des configurations des deux machines et le changement d’effort global ne sont pas justifiés par ces seuls agrégats.

## Validation et limites finales

**Validation locale :** hooks gérés câblés dans les deux stores ; gates skills lean/complet verts dans les deux stores ; budget de contexte **8/8** ; tests de profil sur fixtures verts ; quatre sondes RTK conformes ; arguments strict/no-strict vérifiés sans démarrer Claude. Les fixtures ont utilisé un TMPDIR isolé pour éviter la suppression de fichiers temporaires d’autres sessions.

Les contrôles des hooks démontrent le câblage attendu, pas une validation complète de tous les hooks locaux supplémentaires ni de leur comportement en session réelle. Aucun benchmark fournisseur ou test de perte de qualité n’a été lancé. La présence d’un plugin activé dans settings ne prouve pas son chargement effectif.

**Validation de l’extension :** JSON et sommes des compteurs réconciliés ; deux lectures distantes concordantes sur la fenêtre figée ; comparaison locale identique aux compteurs initiaux ; empreintes des settings, instructions utilisateur et RTK préservées pendant chaque collecte. Les hooks et plugins distants ont été inspectés statiquement, sans exécution. Aucun test de profil ni inférence Claude n’a été lancé sur macbook-work.

**Remaining risks / not verified :** quota exact, plan et identité de compte des deux machines ; CLI et lancement interactif distants actuels ; contexte natif réellement envoyé ; politique administrée ; efficacité par tâche ; usage des teams ; doublons entre stores ou machines ; attribution des tâches automatiques ; fonctionnement complet du moteur propriétaire.

Le blog officiel d’optimisation et la documentation actuelle divergent sur quelques anciennes recettes de thinking/cache ; les règles détaillées correspondant aux modèles récents ont été retenues. [Blog officiel](https://claude.com/blog/maximizing-the-value-of-your-claude-code-sessions), [cache actuel](https://code.claude.com/docs/en/prompt-caching).

État livré : worktree dédié, inventaire des deux stores locaux et extension macbook-work, agrégats de conversations sur les deux machines, analyse du code public et priorités testables. Les paramètres Claude live sont préservés ; les changements du worktree sont des artefacts de recherche.
