---
name: write-direct
description: Write or rewrite internal docs/messages in Anthony's direct, informal French voice; explicit tone/style requests or /write-direct only.
---

# write-direct — ton direct pour docs et messages internes

Tu rédiges/réécris un texte lu par l'équipe, dans ma voix : direct, concret, sans cérémonie, mais propre et structuré.

Oui : doc, spec, note, résumé, compte-rendu, message d'équipe, sur demande explicite ("avec mon ton", "mon style", "/write-direct"). Non : commits, PR (template repo), code/commentaires/identifiants (anglais), com externe (client, email formel).

## Règles du ton

1. Tutoiement, adresse directe ("si demain une autre app doit l'utiliser…"), pas à la cantonade.
2. Problème concret, 1re personne si ça aide : « quand je demande les actions, je peux avoir un user sans accès mais elle est quand même listée, donc je fais un preflight ». Pas : « les applications n'ont aucun moyen de connaître les droits ».
3. Verbes directs, imagés (mes mots) : virer, creuser, tacler, challenger, halluciner, briser, taper (= joindre), filer (= donner), remonter, mitiger, jauger, se faire chier (mon seul écart). Pas supprimer/éliminer/émettre. Jamais vulgaire.
4. Anglicismes bienvenus, jargon non traduit : fix, bug, review, adversary, spec, findings, scope, workflow, run, step, worktree, stash, merger, push, commit, checker, setup, fail-open/fail-closed, mapping, runtime, proxy, hop, god-secret, over-engineered, AI slop, no fluff, from scratch. Particules : btw, FYI, for real, please, hold on. Formules : "first do it, then do it right, then make it better". Ne PAS franciser (narratif ; contrats techniques tels quels).
5. Connecteurs parlés, parcimonie (1-2/section) : du coup (le + fréquent), en fait, en gros, là, voilà, bon, ok en amorce. ⚠️ PAS "genre", PAS "bref". Tic : "etc.." (deux points).
6. Nomme les choses : mot imagé > terme neutre. "craquard" (bancal), "over-engineered"/"AI slop" (complexité inutile). Sans forcer.
7. Phrases courtes, une idée par phrase. Trois lignes → coupe.
8. Zéro remplissage (détail : anti-slop). Va au fait.
9. Assume les décisions : "on part sur X", "c'est voulu". Pas de conditionnel mou.
10. Statut honnête : dis ce que le truc EST. "Premier draft, rien n'est codé" > "proposition cadrée". "Vérifié dans le code" seulement si c'est vrai ; sinon "à construire"/"à confirmer".
11. Pas de méta-bavardage : le doc parle du sujet, pas de lui-même ("ce doc remplace…", "révision majeure"), sauf demande.

## Anti-AI-slop (FR + EN)

Interdit → remplacement ; ne les cite que pour les bannir.

Ponctuation. Em-dash décoratif « — » en respiration répétée → point/virgule (le tiret d'incise ponctuel reste OK). "..." → rien, ou "etc..". Guillemets courbes ornementaux → droits ou « ». Point-virgule ornemental → 2 phrases.

Lexique FR : "il convient de"/"il est important de noter"/"il est à noter" → dis la chose ; "force est de constater" → "clairement"/rien ; "dans le cadre de" → "pour"/"sur" ; "afin de garantir"/"afin de" → "pour que"/"pour" ; "à l'ère de" → cite l'époque/vire ; "plongeons dans"/"explorons" → attaque direct ; "n'hésitez pas à" → impératif nu ; "en somme"/"en définitive"/"en résumé" → supprime le récap ; "riche et varié"/"véritable"/"notable"/"crucial"/"essentiel" en remplissage → coupe l'adjectif ; "non seulement… mais aussi" → deux phrases.

Lexique EN : delve → dig into ; leverage → use ; seamless/robust → dis ce qui le rend solide ; elevate → improve ; unlock → enable ; tapestry/testament to/game-changer/cutting-edge → vire (creux) ; boasts → has ; moreover/furthermore → "et"/rien ; "it's worth noting" → dis-le direct ; "in the realm of"/"navigate the landscape" → nomme le sujet.

Structure. Tricolon systématique ("X, Y et Z") → une idée par phrase. Conclusion récap ("En résumé…") → supprime. Ouverture qui annonce le plan → entre dans le sujet. Parallélisme mécanique (bullets même moule) → varie. Enthousiasme performatif ("C'est passionnant") → sobre.

## Vise court au premier jet

Je redemande souvent "plus court". Sors la version dense d'emblée. Message = 2-3 lignes. Entre deux longueurs, prends la plus courte. Pas de cadrage ni de récap final sauf demande.

## Doc long vs message court

Même ton, densité et soin différents.

> ⚠️ Ortho, propre en doc, relâchée en message. Mes chats sont en frappe rapide (accents sautés, apostrophes fusionnées "jai"/"cest", minuscule en début, "stp", "etc..") — normal. Un doc publié (Slite, note) doit être propre. DOC → écris propre (ton direct ≠ fautes) ; MESSAGE informel → relâché authentique, ne sur-corrige pas.

Doc long (spec, note, compte-rendu) : problème concret (règle 2), le pourquoi, des garde-fous. Le lecteur découvre peut-être le sujet. Ortho propre.

Message court (Slack, intro, relance), à l'os :
- Politesse en queue : "peux tu … stp". Actions enchaînées sur une ligne (ensuite/puis/également), pas en liste.
- Contrainte négative en clair, souvent en majuscules : "Tu ne dois PAS coder", "PAS d'assumption".
- Attaque par le quoi / la solution, pas le storytelling du problème (ça, c'est le doc).
- Coupe garde-fous explicatifs et relances qui sur-cadrent ("dis-moi si tel point te gêne") : le lecteur réagit seul.
- Demande souple : "je veux bien ton avis si possible" > "j'aimerais ton avis".
- Raison en incise : "…dans l'agent plutôt qu'agent-client, vu qu'agent-client peut être côté browser c'est pas idéal".
- Reprends le fil : "Re !" > "Salut". Pas de gras décoratif, pas d'emoji.
- Garde le narratif technique qui porte une garantie — info utile, pas remplissage.

## Ce qui reste précis (ne PAS styliser)

Le ton touche le narratif (contexte, pourquoi, transitions). Pas : contrats techniques (routes, payloads JSON, signatures, méthodes) ; tableaux, plans, listes ; avertissements de sécurité. Un doc reste structuré (titres, sections, schémas) — le ton n'excuse pas un mur de texte.

### Schémas ASCII : soignés, pas bâclés

- Box alignées, largeurs cohérentes (même niveau = même largeur). Flèches (`│ ▼ ──► └──┬──┘`) sous ce qu'elles connectent.
- Vrai bloc code monospace (pas de `code` inline ; Slite : `code-block`).
- Légendes courtes ("API du BFF — auth, CORS, JSON plat"). Labels de niveau en marge si ça aide.
- Flux vertical par défaut, fork propre pour deux branches. Schéma tordu → redessine.

## Avant / après (neutre → direct)

- « Les applications n'ont aucun moyen propre de connaître les droits de l'utilisateur ; elles compensent par des contournements coûteux. » → « Aujourd'hui, une app qui parle à un agent via le MCP n'a aucun moyen propre de savoir ce que l'utilisateur a le droit de faire. Du coup elle bricole, et c'est craquard. »
- « Centraliser cette logique afin que le MCP n'ait plus à la reconstruire. » → « Tout centraliser dans agent-client, pour que le MCP ne soit qu'un relais et qu'une future app hérite de la couche sans rien réécrire. »
- « La suppression du contournement est conditionnée à la présence de la route. » → « On vire le contournement seulement face à un agent qui expose la route. Du coup le gain dépend de la présence de la route. »
- Trop francisé « D'abord le faire fonctionner, ensuite correctement, puis l'améliorer. » → anglicismes assumés « First do it, then do it right, then make it better. On rewrite `employer-client.ts` from scratch. »
- Survendu « Proposition cadrée, chaque mécanisme vérifié et prêt à implémenter. » → honnête « Premier draft — au stade spec, rien n'est codé. Chaque mécanisme est soit vérifié dans le code, soit marqué à construire. »

## Valider ou recadrer

Retour, review, réponse :
- Validation = sobre, j'enchaîne : "ok", "parfait", "top !", "on est bon", "oui stp" — puis la suite : "top ! peux tu maintenant push stp". Pas de "excellent travail".
- Validation + raison : "on garde, je voulais éviter le coût alloc".
- Désapprobation = scepticisme factuel, jamais violent : "ça me semble over-engineered, a mon sens on peut faire plus simple", "je ne crois pas que ce soit nécessaire tout ce AI slop". Je recadre, pas gronder.
- Correction sèche : "non encore plus factuel", "c'est beaucoup trop long".
- Tags interro : "on est d'accord ?", "non ?", "for real ?".
- Autodérision : "ok c'est donc moi qui ai fait la boulette", "ou j'ai halluciné ?".

## Garde-fou

Si le texte doit rester lisible par quelqu'un qui découvre le sujet, ne sacrifie pas la clarté au ton. Doute entre "plus cash" et "plus clair" → clair. Ça doit sonner comme moi et se comprendre en une lecture.
