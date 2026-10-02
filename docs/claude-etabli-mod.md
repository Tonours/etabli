# Cockpit Claude `/etabli`

Le mod ajoute une commande immédiate `/etabli` et huit vues du workflow. Il lit les sources d’Établi sans modifier le plan, le journal, les permissions ou les settings. Il ne lance aucun skill et ne soumet aucun prompt au modèle.

Depuis le checkout Établi :

```bash
claude --plugin-dir "$PWD/claude/mods/etabli"
```

Depuis un autre projet, passer le chemin absolu du même dossier. Garder le plugin dans son checkout : le pont Node utilise `scripts/lib/etabli-session.mjs` trois niveaux au-dessus du plugin. Une copie isolée du seul dossier du plugin ne contient pas ce helper.

Claude Code 2.1.287 ou ultérieur est nécessaire. Le runtime doit autoriser les hooks modules ; `--bare`, `--safe-mode`, `disableAllHooks` et les politiques administrées peuvent empêcher leur chargement. Aucun contournement du rollout n'est fourni. Le lancement ci-dessus charge le plugin pour cette session ; aucune installation globale n'est effectuée.

## Utilisation

Chaque vue s'ouvre sur une **synthèse** : état, action utile et informations qui
demandent attention. **Voir les détails** (`d`) révèle les sources, hashes et
enregistrements complets ; la même touche revient à la synthèse. Ouvrir ces
détails ne relit pas les sources. Changer de vue revient à la synthèse.

Les alertes de fraîcheur, de dossier invalidé ou de capture incomplète restent
visibles. Une demande humaine reste distincte d'un accord historique ; une
valeur inconnue ne devient pas zéro. Les lignes longues sont réparties sur des
pages adaptées à la largeur du panneau. Les contrôles de page apparaissent
quand une suite existe.

| Vue | Source et comportement |
| --- | --- |
| Reprise | Objectif de `PLAN.md`, prochaine action, blocage, effectué/en attente depuis le helper de handoff et un journal validé. |
| Routage | Dernier `route_decided`, raison, contrat et hash enregistré/actuel. Sans décision enregistrée, la route reste inconnue. |
| Journal | Chronologie paginée des étapes, checks et preuves ; une ligne tronquée ou un journal ambigu ne devient jamais une source valide. |
| Accords | Demandes et décisions historiques distinctes ; consentement demandé, accordé, refusé ou inconnu. Une décision sans demande liée reste signalée. Aucun bouton n’accorde une permission. |
| Diagnostic | Boutons **Vérifier les préconditions** et **Tester la clôture** : outils/dépendances manquants, preuves insuffisantes et remédiation. Le check prospectif ne vérifie pas l’archive réelle et ne clôture pas le run. |
| Revue | **Capturer le diff** crée un dossier en mémoire ; **Vérifier le dossier** compare les hashes, la révision, le run et les preuves. Diff suivi, noms/hashes des fichiers nouveaux, extraits explicites et preuves sont paginés dans **Détails**. |
| Usage | Contexte/coût/limites fournis par Claude et cache du dernier tour principal. Une valeur absente reste inconnue ; les tokens cumulés d’un tour ne deviennent pas la taille du contexte. |
| Skills | La synthèse présente les skills du périmètre courant, leurs conditions et les commandes observées. **Détails** conserve le catalogue complet, y compris les scopes inactifs, chemins et règles d'invocation. |

Les touches `1` à `8` choisissent une vue. **Précédent/Suivant** (`b`/`n`) parcourent son contenu ; le journal possède aussi ses boutons de changement de page d’événements (`j`/`k`). **Actualiser** (`r`) relit les sources. Les diagnostics utilisent `p`/`c`, la capture/revérification `g`/`v`. **Échap** ferme le panneau.

Dans le journal, **Lot précédent/suivant** (`j`/`k`) lit d'autres événements ;
**Précédent/Suivant** (`b`/`n`) parcourt les pages du lot affiché.
Les intitulés courts du panneau ne changent pas les arguments de commande :
`routing`, `checkpoints` et `usage` restent acceptés.

```text
/etabli
/etabli journal
/etabli usage
/etabli run my-run
```

La sélection explicite d’un run permet d’inspecter un journal historique, même terminal. `/etabli run` revient à la sélection active. Un pointeur terminal périmé ou plusieurs runs actifs sont signalés ; le mod ne choisit pas arbitrairement une autre autorité.

Si le reader de journal accepte un ancien format que le helper canonique de reprise refuse, les autres vues restent consultables et **Reprise** affiche cette incompatibilité.

L’objectif provient du `PLAN.md` courant. Pour un run historique, sa liaison à cet objectif reste explicitement non attestée ; le journal historique ne transforme pas le plan courant en archive de cet ancien run.

Dans **Revue**, indiquer éventuellement une base Git et un extrait relatif, par exemple `src/guard.ts:20-45`, puis **Capturer le diff**. **Vérifier le dossier** compare toujours à cette capture de référence et conserve sa base SHA initiale et la référence demandée. Cette référence est résolue à chaque recontrôle : son déplacement invalide le dossier, même si HEAD et les fichiers restent identiques ; plusieurs recontrôles ne réhabilitent pas une ancienne preuve. **Capturer le diff** recommence avec la base et l’extrait saisis et établit une nouvelle référence. Une base vide utilise `HEAD`. **Vérifier le dossier** conserve aussi l’extrait de référence, même si le champ a été modifié depuis. Les fichiers nouveaux sont identifiés par leur hash ; leur texte se consulte par un extrait explicite. Une preuve de journal sans révision attestée reste étiquetée non liée, même quand elle est incluse dans une capture à une révision donnée. Sans capture de référence, **Vérifier le dossier** affiche un diagnostic. Si un recontrôle échoue, le dossier précédent et sa référence restent visibles mais invalidés, avec la raison de l’échec. Le dossier contient des données brutes, aucun verdict de revue.

Les captures ne valent qu’à leur instant de lecture. Une activité d’outil ou la fin d’un tour signale une fraîcheur à recontrôler ; un changement externe nécessite **Actualiser** ou **Vérifier le dossier**. Une suppression suivie toujours absente reste inchangée au recontrôle ; une référence illisible reste incertaine. Le dossier est perdu au rechargement, au changement de session/projet/run, à `/clear` et à `/resume`. Une action plus récente peut annuler une capture en cours : le panneau le signale explicitement, même pendant la liaison à la session. Une nouvelle capture remplace le dossier et sa référence seulement après une lecture réussie ; en cas d’annulation ou d’échec, ils restent consultables avec un état de fraîcheur à recontrôler. Le changement explicite de run remet aussi les mesures et le cache du dernier tour à l’état inconnu jusqu’à une nouvelle observation native. Avant une première projection réussie de la session, la capture et les diagnostics demandent **Actualiser** ; un projet sans workflow reste consultable après cette projection. Aucun `$.store` ne crée un second journal.

Le diagnostic affiche son instant de capture et sa propre fraîcheur : une actualisation générale ne remplace pas un nouveau diagnostic après une activité Claude.

La fin d’un outil déjà commencé marque aussi les captures du run sélectionné entre-temps, tant que le panneau reste lié à la même session et au même répertoire. Ce suivi utilise la liaison du panneau et ne retarde pas le résultat de l’outil pour attendre un rafraîchissement visuel. Si l’outil démarre avant la première liaison, celle-ci peut fournir son périmètre ; après une remise à zéro survenue avant cette liaison, son origine reste inconnue et sa fin ne marque pas un nouveau panneau. Un panneau lié à un autre répertoire pendant l’outil est également exclu. Dans ces cas, **Actualiser** et **Vérifier le dossier** restent nécessaires pour observer les éventuels effets sur le nouveau projet.

La fraîcheur du dossier de revue possède son propre état : **Actualiser** la projection ne remplace pas **Vérifier le dossier** le dossier après une activité. Les lectures de consommation suivent leur ordre d’observation ; une réponse ancienne ou une lecture indisponible ne remplace pas une mesure connue. Le cache conserve séparément le dernier tour principal et exclut les sous-agents. Une panne de l’observation native conserve le résultat du tour ou de l’outil Claude.

## Diagnostic et validation

Node doit être disponible sur le `PATH` de Claude, ainsi que Git pour le dossier de revue et les outils requis par les diagnostics canoniques. Le helper accepte uniquement `snapshot`, `diagnostic` et `review` ; il ne lance aucun shell à partir des arguments de la session. Les échanges JSON sont limités à 1 MiB, les extraits à 6500 octets et les fichiers à 16 MiB selon le reader canonique. Le diff entier contribue à son hash et au snapshot avant création d’un aperçu UTF8 de 96 KiB au maximum ; l’aperçu est réduit davantage si son JSON échappé dépasse le budget. Ses octets montrés et sa troncature sont indiqués séparément de la lisibilité des fichiers. Les hashes portent sur le texte du diff décodé en UTF8 par le reader canonique, et ne garantissent pas les octets Git non UTF8. Les extraits et preuves précèdent le diff ; son affichage est limité explicitement à 40 lignes de 200 caractères. Les détails du journal, des preuves et les lignes d’extrait dépassant 200 caractères Unicode portent une étiquette de troncature ; les données et hashes complets restent dans le helper et les sources indiquées. Les métadonnées seules dépassant 1 MiB ou le buffer Git canonique de 32 MiB produisent un diagnostic explicite avec une action adaptée. Une capture incomplète reste signalée. Aucun contenu d’authentification ni transcript Claude n'est lu.

La projection générale transporte une page de journal, sans dupliquer toutes ses preuves ; le dossier de revue les conserve. En cas de dépassement, le diagnostic nomme le mode et le composant mesuré. Pour la revue, il distingue preuves, fichiers et extraits et oriente vers la source qui domine : journal du run directement, base Git plus proche ou Git direct, extraits réduits ou fichiers directs. L’aperçu du diff précède la liste complète des fichiers pour rester accessible même quand cette liste est longue.

Le helper se teste aussi directement, indépendamment de l’affichage Claude :

```bash
scripts/etabli-session snapshot --cwd /path/to/project
scripts/etabli-session diagnostic --cwd /path/to/project --kind preflight
scripts/etabli-session diagnostic --cwd /path/to/project --kind close
scripts/etabli-session review --cwd /path/to/project --base HEAD --excerpt src/guard.ts:20-45
node --test tests/etabli-session.test.mjs tests/etabli-session-mod.test.mjs
claude plugin validate claude/mods/etabli
claude plugin test claude/mods/etabli
node pi/node_modules/typescript/lib/tsc.js --project claude/mods/etabli/tsconfig.json
scripts/verify-agentic-infra core
```

Le preflight existant vérifie aussi les dépendances Pi du checkout Établi : leur absence n'est pas masquée. Les diagnostics ne les installent pas. Le catalogue lit uniquement `~/.etabli-scope` pour le scope local ; les settings natifs fournissent uniquement les états `skillOverrides` affichés, sans projection du reste des settings.

Le chargement natif génère les déclarations dans `.claude-plugin/types/`, ignoré par Git. Le `tsconfig.json` du plugin les référence pour vérifier les tests TypeScript du kit ; le validateur contrôle le module JavaScript et ses capabilities. Les tests Node et les tests du kit officiel vérifient des comportements simulés. Ils ne prouvent pas la peinture du panneau ni les valeurs réelles de consommation : ces validations nécessitent une session Claude interactive. La disponibilité d’une commande native ne prouve pas l’identité du fichier skill chargé ni son exécution.

Sources : [API des mods](https://code.claude.com/docs/en/plugins/mods/api), [interface](https://code.claude.com/docs/en/plugins/mods/interface), [tests](https://code.claude.com/docs/en/plugins/mods/test), [dépannage](https://code.claude.com/docs/en/plugins/mods/troubleshoot).
