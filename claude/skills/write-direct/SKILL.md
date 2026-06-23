---
name: write-direct
description: Rédige ou réécrit un document / message interne (doc de conception, note, résumé, message d'équipe, Slack) dans le ton direct d'Anthony — tutoiement, concret, zéro chichi, structuré et lisible par un collègue. La densité s'adapte au format : doc long = on pose le problème et on explique ; message court = on va à l'os (quoi/solution direct, pas de garde-fous, pas d'emoji). Se déclenche sur demande explicite ("écris ça avec mon ton", "réécris dans mon style", "/write-direct"). Ne PAS l'appliquer aux commits (format imposé), aux PR (template imposé), ni au code/commentaires.
---

# write-direct — le ton direct pour les docs et messages internes

Tu rédiges (ou réécris) un texte destiné à être lu par l'équipe, dans **ma** voix. Pas la voix
neutre d'un doc corporate, pas non plus du langage parlé brut. Le juste milieu : **direct, concret,
sans ceremonie — mais propre et structuré**, parce que d'autres vont le lire et se caler dessus.

## Quand l'utiliser

- Doc de conception, spec, note technique, résumé, compte-rendu, message d'équipe.
- Sur demande explicite uniquement ("avec mon ton", "mon style", "/write-direct").

## Quand NE PAS l'utiliser

- **Commits** → format imposé `type(scope): description`, anglais, pas de ton.
- **PR** → template du repo, écrit pour un reviewer.
- **Code, commentaires, identifiants** → anglais, conventions du repo.
- Communication externe (client, email formel) → registre différent, ne pas appliquer.

## Les règles du ton

1. **Tutoiement et adresse directe.** On parle au lecteur ("si demain une autre app doit
   l'utiliser…"), on n'écrit pas à la cantonade.
2. **Pose le problème concrètement, à la première personne quand ça aide.** Décris la situation
   réelle plutôt que de l'abstraire. Ex : « quand je demande les actions, je peux très bien avoir un
   user qui n'a pas accès, mais elle est quand même listée — donc je suis obligé de faire un
   preflight ». Pas : « les applications n'ont aucun moyen de connaître les droits ».
3. **Verbes directs et imagés** (vérifiés sur mes messages) : "virer", "creuser" ("on creuse d'abord
   techniquement"), "tacler" ("tacler les erreurs"), "challenger" ("on peut challenger pour aligner"),
   "halluciner" (pour me corriger : "ou j'ai halluciné ?"), "briser" ("ton fix va briser X"), "taper"
   (= joindre : "ça vient pas taper sur api.employer.com"), "filer" (= donner), "remonter", "mitiger",
   "jauger", "se faire chier" (mon seul écart de registre, pour pointer un truc inutilement compliqué).
   Pas "supprimer/éliminer/émettre". Reste compréhensible, jamais vulgaire.
4. **Les anglicismes sont les bienvenus — c'est comme ça que je parle.** Le jargon tech anglais que
   j'emploie sans le traduire (vérifié, très dense) : "fix", "bug", "review", "adversary", "spec",
   "findings", "scope", "workflow", "run", "step", "worktree", "stash", "merger", "push", "commit",
   "checker", "setup", "fail-open/fail-closed", "mapping", "runtime", "proxy", "hop", "god-secret",
   "over-engineered", "AI slop", "no fluff", "from scratch". Particules : "btw", "FYI", "for real",
   "please", "hold on". Et les formules anglophones comme principe : "first do it, then do it right,
   then make it better". Ne PAS franciser à tout prix. Ça vaut pour le **narratif** ; les contrats
   techniques restent tels quels de toute façon.
5. **Connecteurs parlés, avec parcimonie.** Ceux qui sont vraiment dans ma voix (vérifié sur mes
   messages) : **"du coup"** (le plus fréquent), **"en fait"**, **"en gros"**, **"là"**, **"voilà"**,
   **"bon"**, **"ok"** en amorce. Un ou deux par section, pas à chaque phrase. ⚠️ **PAS "genre", PAS
   "bref"** — je ne les utilise pas, ça sonne faux. Tic graphique récurrent : **"etc.."** (deux points,
   pas trois).
6. **Appelle les choses par leur nom.** Un mot imagé qui porte une intention vaut mieux qu'un terme
   neutre : "c'est craquard" pour un truc bancal, "over-engineered" / "AI slop" pour de la complexité
   inutile. Garde-les quand ils sont justes — sans les forcer si le contexte ne s'y prête pas.
7. **Phrases courtes, une idée par phrase.** Pas de subordonnées empilées. Si une phrase fait trois
   lignes, coupe-la.
8. **Pas de remplissage.** Pas de "il est important de noter que", "dans le cadre de", "afin de
   garantir". Va au fait.
9. **On assume les décisions.** "On part sur X", "c'est voulu", "on se cale dessus". Pas de
   conditionnel mou ("il serait envisageable de").
10. **Statut honnête, jamais survendu.** Dis ce que le truc EST, pas ce qu'on aimerait qu'il soit.
    "Premier draft, rien n'est encore codé" plutôt que "proposition cadrée" si c'est un draft. "Vérifié
    dans le code" seulement si ça l'est vraiment ; sinon "à construire", "à confirmer", "déduction non
    chiffrée". Un doc qui se survend, ça se retourne contre toi à la première relecture sérieuse.
11. **Pas de méta-bavardage.** Le doc parle du sujet, pas de lui-même. On vire les "ce doc remplace
    l'ancienne version", "on a changé de direction", "révision majeure" — sauf si c'est explicitement
    demandé. Le lecteur veut le contenu, pas l'historique éditorial du fichier.

## Vise court au premier jet

Par défaut je trouve les textes trop longs et je redemande "plus court", "encore
plus court", "plus factuel" plusieurs fois. Coupe l'aller-retour : sors la version
**dense dès le premier jet**. Un message court = 2-3 lignes, pas un paragraphe. Si
tu hésites entre deux longueurs, prends la plus courte — je rallonge moi-même si
besoin, c'est plus rare que l'inverse. Pas de phrase de cadrage ni de récap final
sauf si je le demande.

## Doc long vs message court — calibrer la densité

Le ton est le même, mais la **densité ET le niveau de soin changent** selon le format. Ne pas
appliquer un doc de conception à un message Slack.

> ⚠️ **Orthographe : propre en doc, relâchée OK en message.** Mes messages chat sont en frappe rapide
> — accents sautés ("a" pour à, "etre", "coté", "completement"), apostrophes fusionnées ("jai",
> "cest"), minuscule en début, "stp" sans ponctuation, "etc..". C'est normal **dans un message**. Mais
> un **doc/spec que je publie** (Slite, note d'équipe) doit être **orthographiquement propre** —
> accents, ponctuation, tout. Donc : si tu rédiges un DOC, écris propre (le ton direct ≠ fautes). Si
> tu rédiges un MESSAGE court informel dans ma voix, le relâché est authentique, ne le sur-corrige pas.

**Doc long (spec, note, compte-rendu)** : on pose le problème concrètement (règle 2), on explique le
pourquoi, on met des garde-fous. Le lecteur découvre peut-être le sujet. **Orthographe propre.**

**Message court (Slack, intro à un collègue, relance)** : je vais à l'os. Demande typique : **"peux tu
… stp"** (politesse en queue de phrase, jamais cérémonieuse ; parfois doublée "peux tu s'il te plait …
stp"). Enchaînement d'actions sur une ligne avec **"ensuite" / "puis" / "également"** plutôt qu'en
liste. Quand je cadre une tâche, **contrainte négative en clair**, souvent en majuscules pour insister :
"Tu ne dois PAS coder", "PAS d'assumption", "ne modifie AUCUN fichier".

- **Attaque par le quoi / la solution**, pas par le storytelling du problème. En message, on zappe
  le « voici comment ça marche aujourd'hui et pourquoi c'est pénible » — ça, c'est dans le doc. On
  dit ce qu'on veut faire, point.
- **Coupe les garde-fous explicatifs** ("ça dégrade proprement" suffit, pas besoin de détailler
  fail-closed) et **les relances qui sur-cadrent** ("dis-moi si tel point te gêne", "prends 15 min,
  balance-moi tes remarques"). Le lecteur sait réagir tout seul.
- **Demande souple, pas directive** : "je veux bien ton avis si possible" plutôt que "j'aimerais ton
  avis". On demande, on n'assigne pas.
- **Raison en incise**, pas en bullet séparé : "…dans l'agent plutôt que dans agent-client, vu
  qu'agent-client peut être côté browser c'est pas idéal."
- **Reprends le fil** si la conversation existe déjà : "Re !" plutôt que "Salut".
- **Pas de gras décoratif, pas d'emoji** dans un message — texte plat, les puces suffisent à
  structurer.

Garde quand même le narratif technique condensé qui porte une garantie ("le verdict colle
exactement à ce qui est appliqué à l'exécution") — ça, c'est de l'info utile, pas du remplissage.

## Ce qui reste précis (ne PAS styliser)

Le ton touche le **narratif** : contexte, le pourquoi, les transitions, les explications. Il ne
touche **pas** :

- les **contrats techniques** (routes, payloads JSON, signatures, noms de méthodes) — exacts, tels
  quels ;
- les **tableaux** récap, plans de livraison, listes de règles ;
- les **avertissements de sécurité** ou contraintes dures — clairs et nets, pas désinvoltes.

Un doc reste **structuré** : titres numérotés, sections, schémas. Le ton direct n'est pas une excuse
pour un mur de texte.

### Les schémas ASCII : soignés, pas bâclés

Un schéma d'archi ou de flux dans un doc, ça doit être **clean** — c'est de l'info, pas du gribouillage.

- **Box alignées, largeurs cohérentes.** Les boîtes d'un même niveau ont la même largeur. Les flèches
  (`│ ▼ ──► └──┬──┘`) tombent juste sous ce qu'elles connectent.
- **Un vrai bloc de code monospace** (pas du texte inline). Sur Slite : balise `code-block`, jamais
  des lignes `code` inline qui éclatent le dessin.
- **Légendes sur les flèches**, courtes ("API du BFF — auth, CORS, JSON plat"). Labels de niveau en
  marge si ça aide ("TRANSPORTS", "CŒUR", "PROTOCOLE").
- **Flux vertical par défaut**, un fork propre quand il y a deux branches parallèles.
- Si un schéma est tordu ou désaligné, on le **redessine** — on ne le laisse pas "à peu près".

## Avant / après (exemples réels)

**Neutre (à éviter) :**
> Les applications qui consomment un agent via le serveur MCP n'ont aujourd'hui aucun moyen propre
> de connaître les droits de l'utilisateur. Elles compensent par des contournements coûteux.

**Ton direct (cible) :**
> Aujourd'hui, une app qui parle à un agent via le MCP n'a aucun moyen propre de savoir ce que
> l'utilisateur a le droit de faire. Du coup elle bricole, et c'est craquard.

---

**Neutre :** « Centraliser cette logique dans agent-client afin que le serveur MCP n'ait plus à la
reconstruire. »
**Direct :** « Tout centraliser dans agent-client, pour que le MCP ne soit qu'un relais et qu'une
future app hérite de la couche sans rien réécrire. »

---

**Neutre :** « La suppression du contournement est conditionnée à la présence de la route. »
**Direct :** « On vire le contournement seulement face à un agent qui expose la route. Du coup le gain
dépend de la présence de la route. »

---

**Trop francisé (à éviter) :** « D'abord le faire fonctionner, ensuite le faire correctement, puis
l'améliorer. On réécrit le client depuis zéro et on déduplique la logique en phase finale. »
**Direct (anglicismes assumés) :** « First do it, then do it right, then make it better. On rewrite
`employer-client.ts` from scratch, et on dédoublonne la logique en phase finale. »

---

**Survendu (à éviter) :** « Proposition cadrée, chaque mécanisme est vérifié et prêt à implémenter. »
**Honnête (cible) :** « Premier draft — au stade spec, rien n'est encore codé. Chaque mécanisme est
soit vérifié dans le code existant, soit marqué comme à construire. »

## Valider ou recadrer dans ma voix

Quand le skill sert à rédiger un retour, un commentaire de review ou une réponse (pas juste un doc),
voici comment je réagis (vérifié sur mes messages) :

- **Validation = sobre, zéro effusion, et souvent j'enchaîne.** "ok", "parfait", "top !", "on est
  bon", "ok avec ta suggestion", "oui stp" — puis directement la suite : "top ! peux tu maintenant
  push stp". Pas de "excellent travail", pas de paragraphe de félicitations.
- **Validation + raison en une phrase** : "on garde, je voulais éviter le coût alloc", "option C est
  bien".
- **Désapprobation = scepticisme factuel, jamais violent.** "ça me semble over-engineered, a mon sens
  on peut faire plus simple", "je ne crois pas que ce soit nécessaire tout ce AI slop", "j'aime
  vraiment pas ce pattern, ça rend le code moins lisible". Je recadre, je ne gronde pas.
- **Correction sèche en une ligne** quand c'est un doc/texte : "non encore plus factuel", "c'est
  beaucoup trop long", "pas de bullet list numérotée".
- **Tags interrogatifs** pour vérifier un alignement : "on est d'accord ?", "non ?", "for real ?".
- **Autodérision franche** quand c'est moi : "ok c'est donc moi qui ai fait la boulette", "ou j'ai
  halluciné ?". Décomplexé, pas dramatique.

## Garde-fou

Si le texte doit rester lisible par quelqu'un qui découvre le sujet, **ne sacrifie pas la clarté au
ton**. En cas de doute entre "plus cash" et "plus clair", choisis clair. Le but est que ça sonne
comme moi *et* que ça se comprenne en une lecture.
