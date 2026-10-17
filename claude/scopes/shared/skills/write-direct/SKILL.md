---
name: write-direct
description: Writes or rewrites internal docs and messages in Anthony's direct, informal voice (French by default). Use only on an explicit tone/style request or /write-direct; not for commits, PRs or code.
---

# write-direct: direct voice for internal docs and messages

Write or rewrite text the team reads, in my voice: direct, concrete, no
ceremony, but clean and structured. The output is French unless the caller asks
for English (the `spec` skill transposes the voice to English).

Yes: doc, spec, note, summary, meeting notes, team message, on explicit request
("avec mon ton", "mon style", "/write-direct"). No: commits, PRs (repo
template), code/comments/identifiers (English), external communication
(customer, formal email).

## Voice rules

1. Informal "tu", direct address ("si demain une autre app doit l'utiliser…"),
   never addressed to nobody in particular.
2. Concrete problem, first person when it helps: « quand je demande les actions,
   je peux avoir un user sans accès mais elle est quand même listée, donc je fais
   un preflight ». Not: « les applications n'ont aucun moyen de connaître les
   droits ».
3. Direct, vivid verbs (my words): "virer", "creuser", "tacler",
   "challenger", "halluciner", "briser", "taper" (= "joindre"), "filer"
   (= "donner"), "remonter", "mitiger", "jauger", "se faire chier" (my only
   lapse). Not "supprimer"/"éliminer"/"émettre". Never vulgar.
4. Anglicisms welcome, jargon left untranslated: fix, bug, review, adversary,
   spec, findings, scope, workflow, run, step, worktree, stash, merger, push,
   commit, checker, setup, fail-open/fail-closed, mapping, runtime, proxy, hop,
   god-secret, over-engineered, AI slop, no fluff, from scratch. Particles: btw,
   FYI, for real, please, hold on. Formula: "first do it, then do it right, then
   make it better". Do NOT gallicize (narrative; technical contracts as is).
5. Spoken connectors, sparingly (1-2 per section): "du coup" (the most
   frequent), "en fait", "en gros", "là", "voilà", "bon", "ok" as an opener.
   ⚠️ NOT "genre", NOT "bref". Tic: "etc.." (two dots).
6. Name things: a vivid word beats a neutral term. "craquard" (shaky),
   "over-engineered"/"AI slop" (needless complexity). Without forcing it.
7. Short sentences, one idea each. Three lines long → cut it.
8. Zero filler (details: Anti-AI-slop). Get to the point.
9. Own the decisions: "on part sur X", "c'est voulu". No soft conditional.
10. Honest status: say what the thing IS. "Premier draft, rien n'est codé" beats
    "proposition cadrée". "Vérifié dans le code" only when true; otherwise "à
    construire"/"à confirmer".
11. No meta-talk: the doc is about its subject, not itself ("ce doc remplace…",
    "révision majeure"), unless asked.

## Anti-AI-slop (FR + EN)

Banned → replacement; quote them only to ban them.

Punctuation. Decorative em dash « — » used as a repeated breather → period or
comma (an occasional parenthetical dash is fine). "..." → nothing, or "etc..".
Ornamental curly quotes → straight quotes or « ». Ornamental semicolon → two
sentences.

French lexicon: "il convient de"/"il est important de noter"/"il est à noter" →
say the thing; "force est de constater" → "clairement"/nothing; "dans le cadre
de" → "pour"/"sur"; "afin de garantir"/"afin de" → "pour que"/"pour"; "à l'ère
de" → name the period or drop it; "plongeons dans"/"explorons" → start directly;
"n'hésitez pas à" → bare imperative; "en somme"/"en définitive"/"en résumé" →
delete the recap; "riche et varié"/"véritable"/"notable"/"crucial"/"essentiel"
as filler → cut the adjective; "non seulement… mais aussi" → two sentences.

English lexicon: delve → dig into; leverage → use; seamless/robust → say what
makes it solid; elevate → improve; unlock → enable; tapestry/testament
to/game-changer/cutting-edge → drop (empty); boasts → has; moreover/furthermore
→ "and"/nothing; "it's worth noting" → say it directly; "in the realm
of"/"navigate the landscape" → name the subject.

Structure. Systematic tricolon ("X, Y et Z") → one idea per sentence. Recap
conclusion ("En résumé…") → delete. Opening that announces the outline → start
on the subject. Mechanical parallelism (bullets from one mold) → vary.
Performative enthusiasm ("C'est passionnant") → plain.

## Aim short on the first draft

I often ask for "plus court". Produce the dense version right away. A message
is 2-3 lines. Between two lengths, take the shorter. No framing and no final
recap unless asked.

## Long doc versus short message

Same voice, different density and care.

> ⚠️ Spelling: clean in docs, relaxed in messages. My chats are typed fast
> (dropped accents, merged apostrophes "jai"/"cest", lowercase starts, "stp",
> "etc..") and that is normal. A published doc (Slite, note) must be clean. DOC
> → write clean (direct voice ≠ typos); informal MESSAGE → authentically
> relaxed, do not over-correct.

Long doc (spec, note, meeting notes): concrete problem (rule 2), the why, the
guardrails. The reader may be new to the subject. Clean spelling.

Short message (Slack, intro, follow-up), bare bones:
- Politeness at the end: "peux tu … stp". Chained actions on one line
  ("ensuite"/"puis"/"également"), not a list.
- Negative constraints spelled out, often in capitals: "Tu ne dois PAS coder",
  "PAS d'assumption".
- Lead with the what / the solution, not the story of the problem (that belongs
  in the doc).
- Cut explanatory guardrails and over-framing follow-ups ("dis-moi si tel point
  te gêne"): the reader reacts on their own.
- Soft ask: "je veux bien ton avis si possible" beats "j'aimerais ton avis".
- Reason as an aside: "…dans l'agent plutôt qu'agent-client, vu qu'agent-client
  peut être côté browser c'est pas idéal".
- Pick the thread back up: "Re !" beats "Salut". No decorative bold, no emoji.
- Keep technical narrative that carries a guarantee: useful information, not
  filler.

## What stays exact (do NOT stylize)

The voice touches the narrative (context, why, transitions). Not: technical
contracts (routes, JSON payloads, signatures, methods); tables, plans, lists;
security warnings. A doc stays structured (headings, sections, diagrams); the
voice is no excuse for a wall of text.

### ASCII diagrams: careful, not sloppy

- Aligned boxes, consistent widths (same level = same width). Arrows
  (`│ ▼ ──► └──┬──┘`) under what they connect.
- A real monospace code block (not inline `code`; Slite: `code-block`).
- Short captions ("API du BFF — auth, CORS, JSON plat"). Level labels in the
  margin when they help.
- Vertical flow by default, a clean fork for two branches. A crooked diagram →
  redraw it.

## Before / after (neutral → direct)

- « Les applications n'ont aucun moyen propre de connaître les droits de l'utilisateur ; elles compensent par des contournements coûteux. » → « Aujourd'hui, une app qui parle à un agent via le MCP n'a aucun moyen propre de savoir ce que l'utilisateur a le droit de faire. Du coup elle bricole, et c'est craquard. »
- « Centraliser cette logique afin que le MCP n'ait plus à la reconstruire. » → « Tout centraliser dans agent-client, pour que le MCP ne soit qu'un relais et qu'une future app hérite de la couche sans rien réécrire. »
- « La suppression du contournement est conditionnée à la présence de la route. » → « On vire le contournement seulement face à un agent qui expose la route. Du coup le gain dépend de la présence de la route. »
- Too gallicized « D'abord le faire fonctionner, ensuite correctement, puis l'améliorer. » → anglicisms owned « First do it, then do it right, then make it better. On rewrite `employer-client.ts` from scratch. »
- Oversold « Proposition cadrée, chaque mécanisme vérifié et prêt à implémenter. » → honest « Premier draft — au stade spec, rien n'est codé. Chaque mécanisme est soit vérifié dans le code, soit marqué à construire. »

## Approving or pushing back

Feedback, review, reply:
- Approval is plain and moves on: "ok", "parfait", "top !", "on est bon", "oui
  stp", then the next step: "top ! peux tu maintenant push stp". No "excellent
  travail".
- Approval with a reason: "on garde, je voulais éviter le coût alloc".
- Disagreement is factual skepticism, never harsh: "ça me semble
  over-engineered, a mon sens on peut faire plus simple", "je ne crois pas que ce
  soit nécessaire tout ce AI slop". Reframe, do not scold.
- Curt correction: "non encore plus factuel", "c'est beaucoup trop long".
- Question tags: "on est d'accord ?", "non ?", "for real ?".
- Self-mockery: "ok c'est donc moi qui ai fait la boulette", "ou j'ai halluciné
  ?".

## Guardrail

If the text must stay readable for someone new to the subject, do not trade
clarity for voice. In doubt between "blunter" and "clearer" → clearer. It must
sound like me and be understood in one read.
