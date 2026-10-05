# Expériences lean harness : pointeur de contrat Pi, capsule de route, pilote Jev

Date : 2026-09-28. Run `.workflow/lean-harness/` (branche `refactor/lean-harness`,
départ `5c6d3fb`). Protocoles P5 à P7 fixés dans le `PLAN.md` du run avant
l'ouverture des données scellées ; archive du plan : `docs/plan/20260928-lean-harness.md`.

Statuts : `verified` = mesuré sur le snapshot scellé ; `inferred` = lecture de
l'auteur. Les drivers et les snapshots restent locaux, sous
`.workflow/lean-harness/experiments/` (ignoré par git) ; seuls les agrégats et les
empreintes sont reproduits ici.

## P5 — pointeur de contrat Pi (test de profondeur, observationnel)

- Données : 1 052 sessions Pi locales, 224 tours routés vers un skill ; snapshot
  `p5-snapshot.json`, sha256
  `557b96740cf4ea4adcb853b7dfffbad5e7a50e8709d8f03488c3f9366c82c028`
  (`verified`).
- Contraste primaire, profondeur ≥ 2 : avec pointeur 2 lectures sur 4 tours
  (2 sessions), sans pointeur 19 sur 172 (63 sessions) ; différence +0,39 ;
  intervalle 95 % par bootstrap de sessions [−0,14 ; 0,58] (`verified`).
- Règle pré-enregistrée : garder seulement si la différence est ≥ 10 points,
  l'intervalle exclut 0 et chaque ère compte ≥ 10 sessions. Décision : retrait
  (`pi/extensions/workflow-router.ts`, commit `7fcc19f`).
- Descriptif sans pointeur : 5/47 à la profondeur 1, 5/34 de 2 à 3, 14/138 à 4 et
  plus ; pas de baisse avec la profondeur (`verified`).
- Lecture (`inferred`) : l'estimation va dans le sens du pointeur, mais la preuve
  est insuffisante, pas négative. Un test apparié et puissant peut le rétablir.

## P6 — capsule statique par route (screening de coût, hors ligne)

- Données : transcripts Claude du fil principal (`$CLAUDE_CONFIG_DIR/projects`,
  `~/.claude/projects`) et sessions Pi ayant lu au moins un fichier d'une chaîne
  de route de `workflow/runtime/context-budget.json`, ou déplié une commande de
  route ; 180 épisodes (13 Claude, 167 Pi) ; 68 sessions Claude et 885 Pi
  exclues faute de lecture de contrat ; snapshot `p6-snapshot.json`, sha256
  `bbd06d585ab9049457ec08809cde463a70131992f51f34302991d0bb3c613aea`
  (`verified`).
- Coût : usage enregistré de chaque appel (Pi `usage.cost` ; Claude, tokens aux
  tarifs de la référence claude-api : écriture de cache ×1,25 à 5 min et ×2 à
  1 h, lecture ×0,1, ×0,05 sur Opus 5.5, ×0,025 sur Fable 5.1). Une lecture de
  contrat de t tokens coûte t × le prix d'entrée moyen de chaque appel suivant,
  jusqu'à la compaction ou la fin de session.
- Borne supérieure, capsule de taille zéro : 21,87 $ sur 1 511,33 $, soit
  1,45 % ; intervalle 95 % par bootstrap de sessions [0,99 % ; 1,91 %] ; moitié
  « hash impair » 1,27 % (`verified`).
- Verdict pré-enregistré : screening négatif. La capsule n'a pas été testée,
  aucun fichier de capsule n'a été écrit et A est conservé. La jambe qualité
  (≥ 10 points) n'a pas été testée : le live n'était permis qu'après un
  screening positif.
- Lecture (`inferred`) : le coût des contrats de route est un petit poste. Le
  contexte accumulé domine, comme le mesurait
  `docs/research/20260924-skill-reliability-token-economy.md` §11.

## P7 — pilote Jev sur l'escalade de revue sous le plancher de tier (screening, hors ligne)

- Seam : une re-passe adversaire de plan après une passe non bloquante (le gate
  de plan est déjà satisfait) ; les passes `code_diff` sont exclues, car le
  plancher de tier et la machine de rounds peuvent les rendre obligatoires.
- Données : ledgers de `/Volumes/Crucial/work/*/.workflow/`, compteurs et classes
  de verdict seulement ; 41 runs avec au moins deux passes de plan ;
  développement = racines déjà explorées par la recherche (`etabli`, `etabli-*`),
  25 runs ; held-out = autres racines, 16 runs ; snapshot sha256
  `7993f1515c356e3147b138e590a3f82530627fdf6991d9607d87f5d50f1fb19a`
  (`verified`).
- Bras : A = passes observées ; B = meilleure règle « arrêt après la passe k si
  k ≥ f et acceptés(k) ≤ t » ; C = B + Jev (`jev-1.13.0`, deux questions Noul
  groupées dans un appel, état fait de compteurs et de libellés).
- Développement : aucune règle B admissible, chacune saute une passe critique
  (2 régressions critiques) ; B = A. τ = 0,32. Gel (règle, τ, questions, modèle)
  sha256 `c6de0124660c6c7b24a3b3f98f88676cd95d1f6940d9207862071090397caf5f`,
  enregistré avant le held-out (`verified`).
- Held-out : 4 runs sur 16 ont un point de décision éligible, sous le plancher
  pré-enregistré de 15 ; aucune passe tarifable (45 sans provenance, 4 Codex
  sans prix de liste cité). Verdict : `inconclusive`, A conservé (`verified`).
- Exploratoire held-out : A = 49 passes et 190 findings acceptés ; B = A ; C
  sauterait 3 passes (6,1 %) en perdant 3 findings, dont 1 régression critique ;
  intervalle 95 % apparié de C contre A [0 ; 0,17] (`verified`).
- Calibration exploratoire : sur le développement, P(oui) moyen de « encore un
  finding » 0,38 quand la passe suivante en a trouvé (n = 16) contre 0,28 sinon
  (n = 2) ; sur le held-out, 0,34 (n = 6) contre 0,375 (n = 4) : pas de pouvoir
  de discrimination (`verified`).
- Coût Jev : 28 appels, 0,00045 $ au total (0,042 $/Mtok d'entrée), jamais
  additionnés aux tokens LLM (`verified`).
- Code : l'adaptateur (`scripts/lib/jev-adapter.mjs`, 63 lignes, modèle épinglé,
  sans retry, fail-open, filtre d'état interne, santé « présente ou absente »)
  et son test, 5/5 verts, ont été supprimés de l'arbre ; copies hachées dans le
  dossier du run : adaptateur `4c4aa527…27de`, test `648b3f0c…f1d6`.
- Lecture (`inferred`) : sur ce seam, les re-passes optionnelles sont rares et
  presque toujours productives ; ni une règle simple ni Jev n'en retirent sans
  perdre de findings.

## Limites

- Traces locales d'une seule machine ; l'estimateur de tokens est chars/4.
- P5 est observationnel : l'exposition au pointeur est datée par ère, le message
  injecté n'étant pas persisté par Pi.
- P6 attribue au contrat le prix moyen de chaque appel, écriture de cache
  comprise : c'est une borne haute, pas une mesure de capsule réelle.
- P7 ne connaît ni le tier ni la sévérité des findings historiques : toute passe
  sautée qui portait un finding accepté compte comme régression critique.

## Sources

Sources: fichiers locaux du run et du dépôt ci-dessous, relus pendant l'analyse.

- `.workflow/lean-harness/events.jsonl` : sceaux et verdicts (événements `validation_run`).
- `.workflow/lean-harness/experiments/p5-depth.mjs`, `p6-capsule.mjs`, `p7-jev.mjs` et leurs reçus `p5-receipt.json`, `p6-receipt.json`, `p7-dev.json`, `p7-receipt.json` (sha256 `9ef1b5c7…2dca`).
- `workflow/runtime/context-budget.json` : chaînes de route.
