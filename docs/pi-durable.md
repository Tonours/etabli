# Pi Durable dans Etabli

`pi-durable` est un hôte natif distinct de `pi`. Il utilise Pi Durable 1.0.0,
SQLite et les tâches, conversations et compactions officielles. Les commandes
ci-dessous créent des exécutions dont on peut retrouver l'état après un arrêt
du processus. Les extensions classiques et leurs historiques restent dans
leur profil actuel ; les plugins de fournisseurs classiques ne sont pas
chargés par cet hôte. Il ne convertit pas automatiquement une ancienne session
JSONL en session Durable.

## Démarrer et reprendre

Prérequis : Node ≥22.19, Python 3 avec `fcntl`, npm et les outils des commandes
autorisées. Pi Mobile doit être voisin d'Etabli dans `../pi-mobile`, comme le
lien de l'extension classique. Installer ses dépendances pour ses propres
tests et compilations. Les versions Pi de son SDK et du profil classique
restent distinctes de celles du nouveau paquet.

```bash
npm ci --ignore-scripts --prefix pi/durable
scripts/pi-durable models
scripts/pi-durable start --session ~/.pi/durable/projet --cwd /chemin/projet \
  --provider PROVIDER --model MODEL --providers PROVIDER,AUTRE_PROVIDER
```

Choisir un modèle renvoyé par `models`. Cette commande liste les métadonnées
des modèles configurés sans imprimer les identifiants d'authentification ni
appeler un LLM. Les requêtes de génération et de compaction passent par la
même liste de fournisseurs autorisés et le même filtre de texte sensible.
Les outils refusent les fichiers d'identifiants et les cibles hors du projet.

Le terminal hôte reste ouvert. Depuis un autre terminal :

```bash
scripts/pi-durable state --session ~/.pi/durable/projet
scripts/pi-durable handoff --session ~/.pi/durable/projet
```

Après arrêt, relancer `resume` avec la même session et le même projet. Le
modèle, les réservations, les résultats et les deadlines viennent du stockage.
Une seconde instance est refusée tant que le verrou du premier propriétaire
est tenu. Un arrêt brutal libère ce verrou par EOF du gardien ; perdre le
gardien arrête aussi l'ancien propriétaire. Le répertoire privé doit appartenir
à l'utilisateur, avec mode 0700. Choisir un chemin court pour les sockets Unix
(par exemple `~/.pi/durable/projet`) sur macOS.

## Messages et état partagé

`state` renvoie `sessionId`, `conversationId`, une séquence persistée, les
messages publics et `state.workflow` : phases, enfants, dépendances,
annulations, résultats, budget, effets à rapprocher et travaux à ne pas refaire.
Le téléphone reçoit cette même projection. Les sorties d'outils et le
raisonnement privé n'en font pas partie.

Pi Mobile connaît la session par les métadonnées WebSocket ou par le snapshot
HTTP, chargé aussi lorsque le WebSocket n'est pas disponible. Tant que la
session est inconnue, incomplète ou que ces deux sources se contredisent,
l'envoi est refusé avant toute admission. Pour une session Durable connue,
le téléphone conserve l'identité du message avant le POST et la réutilise
après une réponse perdue. Ce message enregistré ne peut pas être renvoyé
vers une session classique. Un snapshot classique connu conserve son chemin
d'envoi habituel.

```json
{"id":"message-uuid-stable","session":"SESSION_UUID","conversation":1,"text":"Mon message exact","deliverAs":null}
```

Enregistrer ce JSON dans un fichier, puis envoyer `input --file fichier.json`.
Réutiliser son identité lors d'un renvoi. Un autre texte, mode de livraison ou
contexte est refusé pour cette identité. `steer` et `followUp` sont les deux
modes possibles pendant une génération.

## Tâches, missions et campagnes

Toutes les commandes acceptent `--session DIR --file manifeste.json`.
`agent`, `command`, `wait` et `review` créent une tâche. `tasks`, `campaign`,
`goal`, `plan-implement` et `ship` créent un parent avec un graphe de dépendances.
Chaque clé possède des entrées immuables : un renvoi identique retrouve la
tâche ; modifier le manifeste exige une nouvelle identité.

Exemple de graphe de deux agents en lecture seule :

```json
{
  "key":"analyse-v1","objective":"Inspecter puis synthétiser","run":null,
  "maxAttempts":2,"deadline":1790990000000,
  "steps":[
    {"name":"inspect","dependsOn":[],"kind":"agent","input":{"key":"inspect-v1","prompt":"Inspecte les modules de ce projet.","role":"reviewer","model":null,"files":{},"review":false}},
    {"name":"synthese","dependsOn":["inspect"],"kind":"agent","input":{"key":"synthese-v1","prompt":"Synthétise les résultats observés.","role":"reviewer","model":null,"files":{},"review":false}}
  ]
}
```

Remplacer la deadline par une échéance Unix en millisecondes future. Les
résultats du parent conservent les résultats de ses étapes. Chaque agent a une
conversation neuve détenue par sa tâche. Une dépendance empêche de démarrer
l'enfant suivant avant le résultat du précédent, puis transmet ce résultat à son prompt comme preuve enregistrée. `cancel {"id":TASK_ID}`
annule le parent et draine ses enfants. Les appels déjà consommés restent
comptés. `task {"id":TASK_ID}` donne le reçu privé complet.
La deadline du parent est elle-même une tâche persistée : à son échéance,
elle annule les enfants encore actifs, y compris après un redémarrage.

Les missions exigent un `run` canonique, un objectif et au moins une étape
`command` avec `validation:true` et ce même `run`. Avant une étape d’écriture, une commande hors validation ou une étape nommée
`implement` d'un `plan-implement`, le vrai `PLAN.md` et la revue indépendante
du plan doivent être `READY`. La clôture passe par le profil canonique complet
(validations, simplification, qualité, revues, archive et retrait du plan).
`ship` exige une attente CI et le profil `ship-completed` avant de déclarer le
succès. Une étape `publish` exige une revue plus récente que le dernier
`file_changed`. Ces reçus se produisent avec les outils du workflow existant,
puis `export` les rapproche du stockage ; démarrer un outil ne prouve jamais
que son résultat est valide.
Les écritures natives et les commandes hors validation enregistrent un
`file_changed` avant leur effet. Une ancienne validation ou revue ne permet
donc plus de terminer ou publier. Après cet enregistrement, les outils natifs
`write` et `edit` revérifient l'autorité courante, les entrées figées et la cible.
Une cible modifiée est préservée et son ancien effet reste `uncertain`, jusqu'au
rapprochement humain. Il reste une courte fenêtre entre la dernière vérification
et l'exécution d'une écriture ou commande : le verrou du registre ne verrouille
pas les modifications humaines du plan.
Les commandes relisent aussi leurs entrées figées et l'expiration du grant
après ces attentes. Un refus avant le lancement garde le grant consommé,
avec un résultat échoué et un effet connu `command:TASK_ID:not-started`.
Le lanceur effectue ce contrôle après l'écriture de son entrée préparée,
immédiatement avant de créer le worker. Cette entrée peut donc être conservée
avec un refus connu sans que la commande ait démarré.
Quand les étapes sont finies mais que les
preuves canoniques manquent, le parent reste en `awaiting_evidence`, avec son
échéance initiale. On peut apporter les reçus manquants et reprendre cette
attente sans relancer les étapes déjà terminées.
Des validations parallèles reprennent seulement leur enregistrement canonique
en cas de précondition devenue obsolète. Leurs commandes et budgets ne sont
pas rejoués. Un `file_changed` intervenu depuis le lancement produit un reçu
de validation échoué. La deadline initiale borne cette attente.
Risque connu : une revue concurrente d'une validation peut encore être bloquée
par une précondition d'export. Ses résultats et coûts restent enregistrés pour
le rapprochement humain ; cette finalisation ne réécrit pas cet ancien intent.

`campaign` utilise le même graphe pour ses cellules. Une cellule est une étape
`command` ou `agent`, avec sa clé, ses fichiers figés et un reçu conservé, même
en cas d'échec. Un changement de population pour une clé existante est refusé.
Un crash ne remet pas le nombre d'essais ni les requêtes à zéro. Les résultats
terminés sont réutilisés ; les commandes interrompues passent par rapprochement.

## Commandes et permissions

Les agents n'ont pas de shell général. Ils peuvent lire, écrire ou éditer dans
leur rôle et lancer une commande expressément autorisée via
`run_granted_command`. Un reviewer ne peut que lire. Les gardes Etabli de plan,
de gel des checks, de commit et de commentaires s'appliquent pendant l'exécution,
y compris aux outils pouvant être rejoués.

Une autorisation locale vient du terminal humain avec `grant` :

```json
{"key":"test-v1","argv":["npm","test"],"consumer":"test-cell-v1","expiresAt":1790990000000,"evidence":"Tests locaux autorisés par la demande de travail"}
```

Elle est liée aux arguments exacts, au projet, à l'action et à la cible, expire
et n'est consommable que par une tâche. Elle ne remplace pas l'autorisation
humaine requise pour publier, pousser, déployer ou acheter. Aucun de ces actes
externes n'est effectué par les tests de cette intégration.
`consumer` désigne la clé du travail autorisé. Pour un outil d'agent, il doit
nommer la clé de l'agent écrivain, ou `root:CONVERSATION_ID` pour la conversation
du terminal. Les publications Git/GitHub reconnues exigent une étape de
manifeste détenue par un parent enregistré et une revue courante ; l'outil de
commande d'un agent et une commande standalone ne les acceptent pas.
La route, la deadline et les attentes viennent du manifeste immuable du parent.
Une publication relit les attentes CI dont elle dépend, y compris transitivement.
On peut donc publier puis attendre les checks ; la clôture `ship` relit toutes
ses attentes. Les payloads standalone ne peuvent pas fournir leur propre `mission`.
Les commandes héritent des contrôles de la mission au moment de leur exécution.

Exemple de cellule/validation :

```json
{"key":"test-cell-v1","argv":["npm","test"],"grantId":"test-v1","timeoutMs":300000,"files":{},"validation":true,"run":"mission-v1"}
```

Un reçu privé garde stdout, stderr, sortie, identité et interruption. Le worker
arrête les processus attribués à la commande si l'hôte disparaît. Une commande sans
reçu complet ou interrompue laisse un effet incertain. Un nouvel identifiant
d'appel ne permet pas de répéter une action équivalente.
Le reçu est écrit après fermeture des pipes. Le worker supervise les processus
qu'il peut rattacher à la commande par leur identité de naissance sur macOS,
et par un subreaper sur Linux. Il arrête les descendants identifiés encore actifs,
même s'ils ont quitté le groupe de processus initial. Le reçu décrit cette portée
dans `containment` ; une lacune de suivi produit un reçu interrompu et un effet
incertain. Ce mécanisme ne constitue pas une sandbox OS et n'atteste pas à lui
seul la fin d'un effet distant. Les processus sans lien établi ne sont pas arrêtés.
La supervision macOS est vérifiée localement ; le driver Linux reste non vérifié
sur cette machine. Les anciens reçus sans cette preuve exigent un rapprochement.
Une lacune observée reste enregistrée même après la disparition du processus.
Des forks trop rapides peuvent laisser cette lacune, y compris lors d'un Git
local réussi : vérifier le HEAD réel puis enregistrer le rapprochement humain.
Ce rapprochement conserve le résultat interrompu de la tâche et de sa mission ;
il ne les transforme pas rétroactivement en succès et ne rejoue aucune commande.
Une sortie non nulle
complète reste un échec connu et permet une nouvelle tentative expressément
autorisée. Une édition refusée qui n'a changé aucun octet permet une correction.

Avant une nouvelle tentative, contrôler l'effet réel (fichier, commit, cible
distante, résultat de mesure). `reconcile` prend `key`, le chemin d'un reçu
privé mode 0600 et `hash` (empreinte produite par `fingerprint` dans
`pi/durable/state.ts`). Ce contrôle est réservé au terminal local authentifié,
jamais aux outils proposés au modèle. Il atteste le rapprochement humain ; le
runtime ne déduit pas le succès d'une action distante d'une absence de réponse.

`budget` prend `maxRequests`, `deadline` et `evidence`. Ce contrôle humain local
augmente les limites sans effacer les requêtes, échecs ni coûts déjà consommés.
Les options de `resume` ne changent pas les limites enregistrées. Les deadlines
propres aux missions et aux attentes CI restent celles de leurs manifestes.

Un export terminal en attente garde l'empreinte du ledger qu'il a évalué.
Le rapprochement vérifie cette empreinte sous le verrou d'écriture canonique ;
des preuves ajoutées ensuite ne peuvent pas autoriser rétroactivement un ancien
succès. Une clôture de mission utilise l'identité de la tâche et l'empreinte
des preuves évaluées. Si le journal évolue pendant cette évaluation, la mission
reste en attente et réévalue les nouvelles preuves, sans relancer ses enfants.
`abandon-export {"id":"EXPORT_ID","evidence":"motif humain"}` conserve l'ancien
intent abandonné. Avec les mêmes preuves, la mission reste en attente ; un
nouveau reçu canonique permet une nouvelle évaluation avec une autre identité.
Un export déjà écrit avant un crash est reconnu avant l'évaluation et acquitté,
sans second append, même s'il avait été abandonné avant observation du reçu.
Le handoff conserve alors le motif humain : l'abandon ne retire pas un résultat
déjà enregistré dans le journal canonique.

## Revues et review hunters

`review` et les étapes `kind:"review"` lancent Logic, Spec et adversary dans
trois conversations neuves, avec leurs modèles explicites. Le manifeste contient
`key`, `run`, `round` (`T1`, puis le prochain tour admis), `baseSha`, `patchSha`,
`intent` (objectif et critères), `files` (chemin → SHA-256), `authorProvider` et les trois `reviewers`
(`role`, `model:{provider,modelId}`). Les fichiers figés incluent le patch dont
le SHA vaut `patchSha` et les sources nécessaires au deciding-code.

L'adversary utilise une autre famille de modèle, vérifiée dans le reçu effectif.
Les hunters reçoivent les briefs canoniques et le patch figé. Spec reçoit les critères et ne dispose d’aucun outil. Les rapports JSON portent `verdict` et des `findings` avec les sept champs canoniques ; Logic ajoute les huit `lenses`, et Logic/adversary un `decidingCode` non vide (`behavior`, `path`, `line`, `resolver`, `decision`). Les emplacements et résolveurs sont vérifiés contre les entrées figées. Un rapport incomplet reprend seulement ce reviewer, au plus une fois.
Un résultat déjà complet est gardé. Les échecs et appels inconnus restent dans
le budget. Les tours sont dépensés uniquement par `review_completed` du ledger
canonique ; le stockage natif conserve des tentatives et références, sans
second compteur T/D/F. Une trouvaille bloque l'avancement pour correction ;
elle n'autorise pas le reviewer à modifier le code.

## CI, compaction et handoff

Une tâche `wait` utilise `{key,repo,pr,head,deadline,intervalMs,fixture:null}`.
Elle relit le HEAD et les checks via `gh pr view --json` à chaque reprise. Un
HEAD modifié invalide les checks précédents. Après l'échéance initiale, elle
relit une fois puis enregistre un timeout ou une indisponibilité ; elle ne
prolonge pas le délai. `fixture` est réservé à une source locale de test.
La décision de publier ou de terminer un `ship` relit aussi le HEAD et les
checks ; un résultat terminé ancien ne remplace pas ce contrôle courant.

`compact {"key":"compact-v1"}` crée une compaction native persistée, avec un
seul contrôleur actif. L'hôte la déclenche explicitement ; les contrôleurs de
compaction classiques ne sont pas chargés. La génération et cette compaction
partagent filtrage, liste de fournisseurs et réservations de budget. `handoff`
donne les phases, deadlines, résultats, attentes et clés à ne pas refaire,
indépendamment de ce que la conversation résumée raconte. Sa partie privée
`recovery` ajoute les résultats complets, empreintes et reçus d’effets/exports
pour la transmission depuis le terminal authentifié. Ces deux parties sont
construites dans la même transaction, après intégration des tâches terminées,
y compris leurs erreurs et annulations. Les données privées ne modifient pas
le numéro de version public. Le téléphone reçoit
seulement la projection publique, sans ces sorties d’outils privées.

## Pi Mobile

Démarrer le connecteur Pi Mobile habituel, puis ajouter
`--mobile-socket ~/.pi/mobile/bridge.sock` à `start` ou `resume` (utiliser le
`bridgeSocket` exact de sa configuration). Le connecteur affiche la session
native comme session du terminal et relaie le même snapshot enregistré.

Le nouveau client enregistre une boîte d'envoi SecureStore avant le réseau,
avec UUID, texte exact, mode, machine, session et conversation. Les gros textes
sont découpés sans séparer les caractères Unicode ; le pointeur est écrit après
les morceaux. Après redémarrage de l'application, le bouton de reprise renvoie
la même ligne jusqu'à acquittement d'admission. Une ancienne application sans
UUID ou une extension classique reste compatible, avec capacité de déduplication
Durable annoncée comme absente. L'acquittement signifie « message enregistré » ;
le résultat de son traitement reste suivi dans l'état de la session.
Le retrait du pointeur de boîte d'envoi constitue l'acquittement local ; un
échec de nettoyage des morceaux ne bloque pas l'envoi du message suivant.

## Validation et limites de preuve

État des preuves : `verified` pour les parcours locaux exercés ci-dessous ;
`not verified` pour le téléphone physique et la qualité des réponses d'un
fournisseur réel. Les réponses de test déterministes servent à vérifier la
coordination, la persistance et les frontières de permissions.

```bash
npm test --prefix pi/durable
npm run typecheck --prefix pi/durable
npm run typecheck --prefix ../pi-mobile
npm run smoke --prefix ../pi-mobile --workspace @pi-mobile/connector
scripts/verify-agentic-infra core
```

Les tests exécutent de vrais processus Node, SQLite, SIGKILL, workers, le
connecteur HTTP et les snapshots. Les réponses LLM sont déterministes et locales.
Cela vérifie la coordination et la reprise, pas la qualité d'un fournisseur ni
le comportement d'un téléphone physique. Le stockage reste mono-utilisateur et
mono-propriétaire ; les mutations externes demandent leur permission et leur
propre preuve. Garder le répertoire de session et `.workflow/<run>` ensemble.
