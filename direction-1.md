# Direction etabli — validation (direction 1)

- **Modèle** : claude-fable-5 (medium)
- **Date** : 2026-08-23
- **HEAD lu** : `7484b59` (fix(workflow): enforce oracle state integrity and publish both floors)
- **Méthode** : lecture repo (README, docs/how-it-works.md, workflow/spec.md,
  docs/harness-eval.md, branch-review-aggregate.md, échantillon
  workflow/skills/ + scripts/) ; 14 requêtes/extractions web via brave-search ;
  aucun run live facturé ; aucune écriture hors ce fichier.

## Sources web consultées

État de l'art harness/CLI :

- <https://www.tembo.io/blog/coding-cli-tools-comparison> — 15 CLI agents comparés 2025-2026 ; l'explosion des CLI reflète un basculement du mode de production logicielle.
- <https://www.morphllm.com/ai-coding-agent> — classement par Terminal-Bench ; OpenCode ~200k stars devant Claude Code, Codex, Gemini CLI (août 2026).
- <https://devtoollab.com/blog/top-cli-ai-coding-agents> — différenciation par harness : Claude Code (raisonnement), Codex CLI (sandbox), OpenCode (flexibilité modèles).
- <https://dev.to/deployhq/claudemd-agentsmd-and-every-ai-config-file-explained-4pde> — AGENTS.md est devenu un standard ouvert sous gouvernance Linux Foundation, 60 000+ projets.
- <https://codex.danielvaughan.com/2026/05/27/agent-instruction-files-agents-md-claude-md-cross-tool-portability-codex-cli/> — stratégie dominante : « write AGENTS.md well, symlink or configure other tools to read it ».

Évaluation d'agents :

- <https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/> — OpenAI abandonne SWE-bench Verified : contamination et tests faibles ; recommande SWE-bench Pro.
- <https://arxiv.org/pdf/2512.10218> — SWE-Bench-Verified mesure en partie la mémoire du modèle : 60-76 % sur les repos du bench, <53 % hors bench.
- <https://arxiv.org/abs/2601.11868> — Terminal-Bench 2.0 : 89 tâches terminal, environnement unique, solution humaine, tests de vérification complets par tâche.
- <https://deepswe.datacurve.ai/> — DeepSWE : 113 tâches originales écrites from scratch (5 langages, 91 repos), contamination structurellement impossible, vérification exécutable.
- <https://arxiv.org/abs/2510.20270> — ImpossibleBench : mesure la propension au « cheating » via des variantes impossibles où passer implique nécessairement l'exploitation du test.
- <https://arxiv.org/html/2605.02964v1> — Reward Hacking Benchmark : cartographie fabrication (ImpossibleBench), propension à l'exploit (RHB), détection (EvilGenie).
- <https://arxiv.org/abs/2604.15149> — « LLMs Gaming Verifiers » : des vérificateurs qui ne contrôlent que la correction extensionnelle admettent des faux positifs ; le hack est structurel, pas accidentel.
- <https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents> — (contenu extrait intégralement) 20-50 tâches issues d'échecs réels suffisent au départ ; graders déterministes d'abord ; « grade what the agent produced, not the path it took » ; l'outcome est l'état final de l'environnement, pas le transcript ; les graders doivent résister aux bypasses ; pass@k vs pass^k ; solution de référence obligatoire par tâche ; lire les transcripts.

Multi-harness / config-as-code :

- <https://github.com/kissgyorgy/coding-agents> — module home-manager Nix : un répertoire de skills partagé symlinké vers chaque agent (Claude Code, Codex, Gemini CLI, Pi, Crush).
- <https://github.com/Kyure-A/agent-skills-nix> — gestion déclarative de skills d'agents sous Nix.
- <https://jade.fyi/blog/use-nix-less/> — même les utilisateurs Nix recommandent un gestionnaire de liens trivial en complément : le symlink vers un repo git est hors du happy path home-manager.
- <https://drmowinckels.io/blog/2026/dotfiles-coding-agents/> et <https://seanogrady.me/posts/managing-ai-config-with-dotfiles/> — le pattern « dotfiles + stow/symlinks pour configs d'agents IA » est devenu une pratique courante d'opérateur solo.

Comportement des modèles en agent :

- <https://arxiv.org/pdf/2507.11538> — IFScale : la fidélité au suivi d'instructions se dégrade avec la densité (décroissance à seuil, linéaire ou exponentielle selon le modèle).
- <https://arxiv.org/html/2601.03269v1> — « The Instruction Gap » : violations d'instructions en contexte long, trois modes d'échec identifiés.
- <https://ceaksan.com/en/llm-behavioral-failure-modes> — « ceremonialization » : une règle répétée finit appliquée en forme mais vidée de substance (« ran tests, passed » sans exécution).
- <https://www.anthropic.com/engineering/multi-agent-research-system> — multi-agent : +90,2 % sur la recherche breadth-first, mais ~15x le coût en tokens.
- <https://medium.com/@mjgmario/single-agent-vs-multi-agent-systems-when-coordination-helps-hurts-and-pays-off-57735ee7916d> — sur SWE-bench Verified, les architectures multi-agents dégradent de -2 % à -15 % vs single-agent.
- <https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai> — multi-agent gagne en exploration breadth-first ; pour la review de PR standard, un agent unique avec contexte complet suffit.
- <https://www.flowhunt.io/blog/multi-agent-ai-system/> — papiers 2026 : à budget de tokens égal, le single-agent égale ou bat le multi-agent.

 et alternatives :

- <https://github.com/cursor/plugins/tree/main/> — ** existe publiquement** : suite de plugins Cursor (playbooks, -mode, show-me-your-work, choix de modèles par rôle). Ce n'est pas un nom purement interne à etabli ; en revanche, **aucun précédent externe trouvé** pour l'usage qu'en fait etabli (geler les playbooks d'une suite de plugins comme population de benchmark comparatif). « Population-stack » comme concept : néant sur le web.
- <https://github.com/github/spec-kit> et <https://github.github.com/spec-kit/> — GitHub Spec Kit : workflow specify → plan → tasks → implement, extensions communautaires « CI Guard » / « Architecture Guard » ; le contract-first gagne du terrain comme pratique mainstream.
- <https://code.claude.com/docs/en/hooks-guide> et <https://blakecrosley.com/blog/claude-code-hooks-explained> — les hooks PreToolUse de Claude Code sont une couche d'enforcement déterministe : un `permissionDecision: deny` bloque même sous `--dangerously-skip-permissions`. L'écosystème converge vers « guards mécaniques > prose ».

**Absences constatées** (l'absence est une donnée) : personne ne publie de
« fabrication floor » (constant baseline) à côté de ses scores d'éval maison —
c'est un geste de niveau recherche (ImpossibleBench) qu'aucun outil d'opérateur
solo trouvé ne fait ; aucun benchmark public ne mesure « l'adhérence d'un
harness à un contrat de workflow » (l'objet des 8 tâches d'etabli) ; aucun
précédent de « benchmark comparatif de sa propre config d'agent contre une
suite de plugins tierce ».

---

## Réponses aux six questions

### Q1 — Contrat unique + guards mécaniques : la bonne architecture ?

**Verdict : VALIDÉ sur l'architecture, CONTESTÉ sur la masse de prose.**

La partie différenciante d'etabli n'est pas le contrat écrit, c'est le guard
partagé qui refuse l'écriture pré-READY dans les deux runtimes
(`planMutationGuardDecision`, hooks Claude + `tool_call` Pi). C'est exactement
là où l'écosystème converge : les hooks PreToolUse de Claude Code sont vendus
comme « la couche déterministe autour de l'agent » et bloquent même en mode
bypass ([blakecrosley.com](https://blakecrosley.com/blog/claude-code-hooks-explained)) ;
Spec Kit pousse des gates de conformité communautaires
([spec-kit](https://github.github.com/spec-kit/)). Un simple AGENTS.md repose
sur l'obéissance du modèle, et la recherche dit que cette obéissance se
dégrade avec la densité d'instructions (IFScale,
[arXiv 2507.11538](https://arxiv.org/pdf/2507.11538)) et se « céremonialise »
avec la répétition ([ceaksan.com](https://ceaksan.com/en/llm-behavioral-failure-modes)).
Donc non, ce n'est pas de la sur-ingénierie vs AGENTS.md : c'est la réponse
correcte à une faiblesse documentée des AGENTS.md purs.

Le revers : le contrat prose fait ~5 600 mots pour le noyau (spec +
contract-details + quick-card + answer-quality, mesuré `wc -w`), ~29 000 mots
avec les skills. La même littérature qui justifie les guards condamne cette
densité — chaque règle prose supplémentaire coûte de l'adhérence sur toutes
les autres. La bonne asymptote : prose minimale (carte), enforcement maximal
(hooks + checks). Le repo l'énonce déjà comme principe (« instruction files
stay maps, not manuals » ; « la troisième occurrence d'un finding devient un
check mécanique ») mais ne l'applique pas à lui-même : spec.md liste ~25
règles non-négociables.

- **Evidence** : hooks deny-under-bypass documentés ; IFScale ; standardisation AGENTS.md (Linux Foundation, 60k+ projets) ; comptage de mots local.
- **Inference** : un opérateur multi-harness a besoin d'un point d'enforcement partagé, sinon N configurations divergent — le symlink + guard commun est la réponse minimale, pas maximale.
- **Opinion** : la moitié des règles prose de contract-details.md serait plus utile en check exécutable ou supprimée.

### Q2 — Suite d'éval maison : méthodologiquement défendable ?

**Verdict : DÉFENDABLE dans sa posture, PAS ENCORE dans son objet. Ne pas
migrer vers SWE-bench/terminal-bench — corriger le grading à la place.**

Ce qui est défendable, et même en avance sur la pratique courante : publier
les deux planchers (null 1/8, constant 6/8) est un geste que seule la
littérature de recherche fait (ImpossibleBench,
[arXiv 2510.20270](https://arxiv.org/abs/2510.20270) ; RHB,
[arXiv 2605.02964](https://arxiv.org/html/2605.02964v1)). 8 tâches, c'est
dans la fourchette basse mais légitime du « start early » d'Anthropic (20-50
tâches issues d'échecs réels comme bon départ,
[demystifying-evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)).
La filiation DeepSWE revendiquée (tâches originales + vérificateurs
exécutables + runner fixe) est correcte dans l'intention.

Ce qui ne l'est pas : constant = 6/8 signifie que 6 cellules sur 8 ne
distinguent pas un exécutant d'un fabricateur. La règle industrielle est sans
ambiguïté : l'outcome est **l'état final de l'environnement**, pas le
transcript (« the outcome is whether a reservation exists in the environment's
SQL database » — Anthropic ; vérification d'état backend dans WebArena,
inspection d'artefacts dans OSWorld). DeepSWE grade par tests exécutés ; 6
oracles d'etabli grappent du texte. « LLMs Gaming Verifiers »
([arXiv 2604.15149](https://arxiv.org/abs/2604.15149)) formalise pourquoi
c'est structurel : un vérificateur extensionnel admet des faux positifs par
construction. Les 6 reviews internes ont convergé sur le même point (C1),
et HEAD `7484b59` a livré l'intégrité d'état + les deux planchers — la
direction du fix est la bonne ; il reste à sortir les preuves du transcript
(artefact hors-bande imposé par la cellule, hashé par l'oracle — la piste C10
des reviews 2 et 4 est la bonne).

Faut-il passer au public ? Non. SWE-bench Verified est officiellement
abandonné par OpenAI pour contamination
([openai.com](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/)) ;
Terminal-Bench mesure la maîtrise du terminal, pas l'adhérence à un contrat
de workflow — l'objet d'etabli n'a pas de benchmark public. Les benchmarks
publics répondent à « quel modèle/harness choisir », pas à « mon contrat
change-t-il le comportement ». Le maison est la seule option pour la seconde
question ; l'infrastructure de Terminal-Bench (harbor) pourrait servir de
runner, pas de substitut.

- **Evidence** : planchers publiés localement ; abandon SWE-bench par OpenAI ; doctrine outcome-grading d'Anthropic ; convergence 6/6 des reviews internes sur C1.
- **Inference** : tant que 6/8 cellules sont fabricables, tout pass@1 live compare des politiques de formatage — l'interdiction consensuelle de publier est correcte.
- **Opinion** : 8 tâches textuelles durcies valent moins que 4 tâches state-bound ; réduire le nombre pour augmenter la classe de preuve serait un échange gagnant.

### Q3 — Multi-harness par symlinks + catalog TSV : viable ou fragile ?

**Verdict : VIABLE, conforme à la pratique dominante ; Nix n'apporterait
qu'un gain marginal pour un coût de migration réel. La fragilité observée est
dans les installeurs, pas dans le pattern.**

Le pattern « un repo source, des symlinks vers chaque surface d'agent » est
exactement ce que fait l'écosystème : le module home-manager
[kissgyorgy/coding-agents](https://github.com/kissgyorgy/coding-agents)
symlinke un répertoire de skills partagé vers chaque agent — c'est
l'architecture d'etabli en Nix ; les setups stow d'opérateurs solo font pareil
([seanogrady.me](https://seanogrady.me/posts/managing-ai-config-with-dotfiles/)).
Et même le camp Nix admet que le lien vers un repo git vivant est hors du
happy path home-manager ([jade.fyi](https://jade.fyi/blog/use-nix-less/)) —
pour un repo édité en continu comme etabli, le store immuable de Nix est une
friction, pas un gain. La convergence AGENTS.md (Linux Foundation) va par
ailleurs réduire le besoin d'adaptateurs par outil avec le temps.

La vraie fragilité est ailleurs, et les reviews l'ont trouvée : prune
fail-open qui supprime tous les liens managés sur keep-list vide (C4),
`prefer-cursor-agent.sh` qui avale ses échecs (C7). C'est la classe de risque
des installeurs bash maison — Nix l'éliminerait, mais un `set -euo pipefail`
discipliné + refus de pruner sur liste vide l'élimine aussi, pour deux heures
de travail au lieu d'une migration.

- **Evidence** : précédents publics du même pattern ; défauts C4/C7 reproduits par 4-6 reviewers ; friction Nix documentée par ses propres utilisateurs.
- **Inference** : le TSV catalog (skill-surface, source-ownership) est un registre de faits, pas un moteur — sa fragilité est celle de ses consommateurs shell.
- **Opinion** : ne pas migrer vers Nix ; durcir les installeurs fail-closed et considérer le sujet clos.

### Q4 — Le rituel (plan → adversary → implémentation → hunters → adversary cross-model) : aligné avec la recherche ?

**Verdict : ALIGNÉ pour le gate de plan et la review fresh-context ;
NON ALIGNÉ pour l'adversary cross-model inconditionnel par changement.**

Ce qui est soutenu : le gate READY (« code changes allowed only here »)
correspond au mouvement spec-driven mainstream (Spec Kit : specify → plan →
tasks → implement, [github/spec-kit](https://github.com/github/spec-kit)) ;
la review par contexte frais correspond à la pratique ( fait relire par
des rôles séparés ; Anthropic recommande de relire les transcripts) ; le
no_progress stop est une réponse directe au mode d'échec « grinding » documenté.
« Un bug fix part d'un test qui échoue » est le meilleur guardrail du lot —
c'est un test système, pas un rituel.

Ce qui ne l'est pas : la recherche 2026 est convergente sur le coût des
architectures multi-passes — ~15x les tokens pour le multi-agent
d'Anthropic sur la recherche (où il gagne), **dégradation** de -2 % à -15 %
sur SWE-bench Verified (où il perd,
[Medium/mjgmario](https://medium.com/@mjgmario/single-agent-vs-multi-agent-systems-when-coordination-helps-hurts-and-pays-off-57735ee7916d)),
et à budget égal le single-agent égale ou bat le multi-agent
([flowhunt.io](https://www.flowhunt.io/blog/multi-agent-ai-system/)). Pour la
review de PR standard, « un agent unique avec contexte complet performe bien »
([augmentcode.com](https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai)).
Deux passes adversary + hunters + reviewer sur **chaque** changement est
au-delà de ce que l'évidence justifie ; l'argument des angles morts corrélés
est réel mais vaut pour le risque élevé, pas pour le patch de 20 lignes. Le
repo a d'ailleurs déjà la soupape (route « plain prompt » sans rituel) — le
problème est le défaut du `/plan-implement`, pas l'existence du rituel.

Sur « evals as guardrails vs bon système de tests » : Anthropic tranche —
pour les agents de code, les graders naturels sont les tests. Les 8 cellules
harness ne remplacent pas une suite de tests ; elles mesurent autre chose
(l'adhérence au contrat). Les deux coexistent légitimement, mais si un seul
budget existe, il va aux tests exécutables du code produit, pas aux oracles
de comportement.

- **Evidence** : chiffres multi-agents 2026 ; doctrine test-first d'Anthropic ; C5 des reviews (le rituel a un coût matériel mesuré : scaffold ×2,2).
- **Inference** : un rituel dont le coût est indépendant du risque du changement sur-paie les petits changements et sous-paie peut-être les gros.
- **Opinion** : rendre la phase 7 (adversary cross-model sur diff) conditionnelle au risque (surface touchée, destructivité, familiarité) serait le meilleur ratio gain/coût de tout le backlog direction.

### Q5 — / : tuer ou continuer ?

**Verdict : CONTINUER la partie gratuite (structurel + distillation), TUER
l'ambition de dominance live sous sa forme actuelle.**

 existe publiquement
([cursor/plugins/](https://github.com/cursor/plugins/tree/main/)) ;
l'usage qu'en fait etabli — geler 23 playbooks comme population de benchmark —
n'a **aucun précédent trouvé** sur le web. C'est original, et la partie déjà
payée est réelle : la distillation des reply shapes dans answer-quality.md a
coûté zéro run live. Le run structurel (23/23, routing + ownership) est une
preuve de couverture honnête tant qu'elle n'est pas vendue comme preuve
comportementale — et le repo ne la vend pas comme telle (statut
`not_established`, lane `BLOCKED`).

Mais le protocole live (138 runs, pass@1/pass^3, jugement indépendant, assets
scellés) est un protocole de niveau laboratoire pour répondre à une question
dont la lane-2 manuelle a déjà esquissé la réponse : 2 AHEAD / 12 TIE /
1 BEHIND / 8 INCONCLUSIVE — majoritairement des égalités. Dépenser un budget
significatif pour confirmer « pas de différence détectable » est le pire
achat possible. Ce que l'écosystème recommande pour mesurer ses propres
agents sans budget infini (Anthropic, même source) : une petite suite de
régression sur tâches réelles, pass^k sur les quelques tâches critiques,
lecture de transcripts, dogfooding — et « teams get surprisingly far » ainsi
avant l'échelle production, qu'un opérateur solo n'atteint pas. La
comparaison la plus informative pour etabli n'est pas « etabli vs  »
mais « etabli(t) vs etabli(t-1) » sur ses propres tâches gelées : une
régression interne coûte ~10 runs, pas 138.

- **Evidence** : lane-2 majoritairement TIE ; interdiction consensuelle des 6 reviews de tout pass@1 live avant C1/C2 ; conseil budget d'Anthropic.
- **Inference** : le gate d'ingest peut rester comme spécification dormante — il coûte zéro et documente la barre ; c'est l'autorisation de dépense qui doit rester fermée.
- **Opinion** : requalifier officiellement -live de « bloqué » à « abandonné sauf événement nouveau » serait plus honnête que de maintenir l'ambition en vitrine.

### Q6 — voir les deux sections suivantes.

---

## Top 3 à changer

1. **Sortir les preuves du transcript.** Migrer les 6 oracles textuels vers
   du grading d'état/artefact hors-bande (fichier imposé par la cellule,
   hashé par l'oracle — les briques existent, C10) ; d'ici là, aucune
   publication de pass@1 live, et les cellules textuelles étiquetées
   « formatting checks » dans le rapport. C'est la seule position compatible
   avec la doctrine outcome-grading et avec les six reviews internes.
2. **Amaigrir la prose, engraisser les checks.** Le noyau prose (~5 600 mots)
   dépasse le point de rendement décroissant documenté par IFScale ; le repo
   a déjà la règle (« troisième occurrence → check mécanique ») — l'appliquer
   agressivement à contract-details.md, et plafonner la charge scaffold
   déployée par projet (les 341 Ko de C5 contredisent « maps, not manuals »).
3. **Rendre le rituel proportionnel au risque.** L'adversary cross-model sur
   diff devient conditionnel (surface, destructivité, familiarité) au lieu
   d'inconditionnel ; le budget économisé finance un canary live mensuel de la
   suite harness (ce que l'écosystème recommande réellement de payer).

## Top 3 à garder

1. **Le guard mécanique partagé et la philosophie fail-closed.** C'est la
   pièce différenciante vis-à-vis d'un simple AGENTS.md, elle est alignée
   avec la convergence de l'écosystème (hooks déterministes), et c'est la
   réponse correcte à la dégradation documentée du suivi d'instructions.
2. **Les planchers publiés (null + constant).** Personne d'autre ne fait ça
   à ce niveau d'artisanat ; c'est un import réel de la littérature
   (ImpossibleBench) dans un outil d'opérateur solo. À étendre (delta
   par tâche), jamais à retirer.
3. **La culture de la claim proportionnelle à la preuve.** `not_established`
   plutôt qu'un chiffre flatteur, ADR append-only, rejets loggés, lane
   BLOCKED assumée. C'est ce qui a empêché -live de devenir du
   benchmark-washing, et c'est la propriété la plus difficile à reconstruire
   une fois perdue.

## Score de confiance : 0,7

**Pourquoi pas plus.** Je n'ai exécuté aucun run live ; mes verdicts sur la
suite d'éval reposent sur `docs/harness-eval.md`, les commits HEAD et six
reviews internes convergentes — convergence forte, mais pas une repro
personnelle des mutations aveugles. Le contrat total (~29 000 mots, lane-3
~3 600 lignes, classifier ~1 300 lignes) n'a été qu'échantillonné. Une partie
des sources web (comparatifs CLI, blogs multi-agents) est de qualité
blog/vendeur ; je les ai utilisées pour la direction du vent, pas pour les
chiffres, mais le risque de biais de sélection des moteurs de recherche
existe. Les estimations de coût token du contrat sont des conversions
mots→tokens approximatives.

**Pourquoi pas moins.** Les claims structurants s'appuient sur des sources
primaires fortes (OpenAI sur SWE-bench, Anthropic sur les evals, arXiv sur le
gaming de vérificateurs et la densité d'instructions), recoupées avec des
mesures locales reproductibles (`wc -w`, planchers publiés, HEAD vérifié) et
avec six reviews indépendantes dont les repros numériques concordent. Les
trois verdicts les plus critiques (oracles textuels fabricables, rituel
sur-payé sur petits changements, live comparatif à ne pas financer) sont
chacun soutenus par au moins deux classes de preuve indépendantes.
