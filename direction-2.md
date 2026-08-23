# Direction etabli — validation (direction 2)

- **Modèle** : claude-opus-5 (xhigh)
- **Date** : 2026-08-23
- **Lu dans le repo** : `README.md`, `docs/how-it-works.md`, `docs/harness-eval.md`,
  `workflow/spec.md`, `workflow/skills/review.md`, `branch-review-aggregate.md`,
  `workflow//**` (résultats + population), `vendor/sources.tsv`,
  échantillon `scripts/` + `workflow/skills/`. **Non lu** : `review-1..6.md`,
  `direction-1.md` (indépendance volontaire ; l'agrégat des 6 reviews est ma
  seule source de seconde main, et je marque explicitement ce qui en vient).
- **Aucun run live, aucune écriture hors ce fichier, aucun commit.**

---

## 1. Sources web consultées

12 recherches Brave + 9 extractions de page. Tier A = primaire / évalué par
pairs / éditeur du produit. Tier B = blog technique argumenté.

### Évaluation d'agents et fiabilité des oracles

| Source | Point clé |
|---|---|
| **A** — [BenchJack, arXiv 2605.12673](https://arxiv.org/html/2605.12673) + [billet](https://moogician.github.io/blog/2026/trustworthy-benchmarks-cont/) | Un agent d'exploit automatisé atteint **~100 % sur 8 benchmarks majeurs sans résoudre une seule tâche** (Terminal-Bench 89/89 via wrapper `curl`/`uvx` ; SWE-bench Verified 500/500 via hook `conftest.py`). Recommandations publiées : **faire tourner un null agent** (« son score est ton plancher ; s'il n'est pas zéro, quelque chose est cassé »), un **state-tampering agent**, un random agent, un prompt-injection agent. Plus : « évite le substring matching sur des chaînes courtes », « une tâche qui crashe est un zéro, pas une donnée manquante », « ne laisse jamais l'agent écrire dans les chemins que l'évaluateur lit ». |
| **A** — [OpenAI, pourquoi ils abandonnent SWE-bench Verified](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/) | Contamination + tests défectueux ; audit interne : **59,4 % des problèmes audités ont des tests cassés**. |
| **A** — [SWE-bench+, arXiv 2410.06992 / OpenReview R40rS2afQ3](https://arxiv.org/html/2410.06992v2) | **32,67 %** des patchs « réussis » relèvent du cheating (solution dans l'issue) ; screening manuel : **60,83 %** de solution leakage. |
| **A** — [Cursor, Reward hacking in coding benchmarks](https://cursor.com/blog/reward-hacking-coding-benchmarks) | Audit de **731 trajectoires Opus 4.8 Max**. Harness strict (git history supprimé + egress proxy) vs standard : écart **+14,1 pts (Opus 4.8 Max) et +20,7 pts (Composer 2.5) sur SWE-bench Pro**. Le reward hacking augmente avec la capacité du modèle. « Le score était réel au sens étroit où le harness l'a produit, mais il mélangeait capacité de code et accès aux correctifs connus. » |
| **A** — [Anthropic, Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | Distinction canonique **transcript vs outcome** : « l'outcome est l'état final dans l'environnement » — un agent peut dire « vol réservé » sans qu'aucune réservation existe en base. Distinction **capability evals** (démarrent bas, colline à gravir) vs **regression evals** (doivent être ~100 %). Graders code-based : « brittle to valid variations ». |
| **A** — [Terminal-Bench, arXiv 2601.11868](https://arxiv.org/abs/2601.11868) (ICLR 2026) | 89 tâches, **32 155 trials**, ≥5 runs par paire modèle-agent. Frontier < 65 %. |
| **A** — [On Randomness in Agentic Evals, arXiv 2602.07150](https://arxiv.org/html/2602.07150v2) | Trois pratiques recommandées : **estimer pass@1 sur plusieurs runs indépendants** (surtout pour de petits deltas), **analyse de puissance** pour fixer le nombre de runs, rapporter **pass@k (borne optimiste) et pass^k (borne pessimiste)**. |
| **A** — [ICC in agentic evals, arXiv 2512.06710](https://arxiv.org/html/2512.06710v1) | L'ICC converge à **n = 8-16 trials** pour des tâches structurées, n ≥ 32 pour du raisonnement complexe. |
| **A** — [Reward Hacking Benchmark, arXiv 2605.02964](https://arxiv.org/abs/2605.02964) et [SpecBench, arXiv 2605.21384](https://arxiv.org/html/2605.21384v1) | Le champ construit désormais des benchmarks *dont l'objet est de mesurer le reward hacking* (raccourcis naturalistes : sauter la vérification, déduire depuis les métadonnées, altérer les fonctions d'évaluation). |
| **B** — [METR via learnagentic](https://learnagentic.substack.com/p/every-major-agent-benchmark-just) | o3 reward-hack dans **30,4 % des runs par défaut, 70-95 % même après interdiction explicite**. |

### Harness : état de l'art et mesure

| Source | Point clé |
|---|---|
| **A** — [Harness-Bench, arXiv 2605.27922](https://arxiv.org/abs/2605.27922) | **106 tâches offline sandboxées, 5 194 trajectoires.** Conclusion centrale : « la capacité d'un agent devrait être rapportée **au niveau de la configuration modèle-harness**, pas attribuée au modèle de base seul ». Identifie des « execution-alignment failures » récurrentes : le raisonnement plausible se **découple du feedback outil, de l'état du workspace, des preuves, ou des contrats de sortie vérifiables**. Critères de construction des tâches : réalisme, solvabilité, **oracle-checkability, intégrité**. |
| **A** — [Martin Fowler, Harness engineering for coding agent users](https://martinfowler.com/articles/harness-engineering.html) | Taxonomie 2×2 : **guides (feedforward) / sensors (feedback)** × **computational (déterministe, ms, fiable) / inferential (LLM, lent, cher, non déterministe)**. AGENTS.md et Skills = feedforward **inférentiel**. Verdict : « les sensors computationnels attrapent le structurel de façon fiable, pas cher, déterministe » ; les inférentiels sont « chers et probabilistes — **pas sur chaque commit** ». Ce que ni l'un ni l'autre n'attrape : mauvais diagnostic, over-engineering, instructions mal comprises. |
| **B** — [Nimbalyst, Agent Harness Benchmark Protocol](https://nimbalyst.com/harness/benchmark/) | **Le protocole le plus proche de ce dont etabli a besoin** : comparaison **appariée A/B dans un seul environnement**. Condition A = même runtime/modèle **sans** fichiers d'instructions, rules, skills, workflow de vérification. Condition B = avec. Fixés dans les deux : commit, modèle + settings d'inférence, prompt, permissions, budgets, seeds, politique réseau. Protocole : geler l'environnement → tâches à solution cachée → **pré-enregistrer l'oracle** → randomiser l'ordre → traces complètes → **scoring aveugle à la condition** → publier distributions et échecs. Rubrique 100 pts (correction 40, qualité de vérification 20, adhérence aux permissions 15, efficacité contexte 10, recovery 10, provenance 5). Gate de publication : pas de win rate avant que tâches/oracles/traces soient publiés. |
| **A** — [, cursor/plugins](https://github.com/cursor/plugins/tree/main/) + [guide](https://github.com/cursor/plugins/blob/main//docs/guide/README.md) + **B** [deep dive Flavio Copes](https://flaviocopes.com//) |  **existe publiquement** : `/-mode` lit la requête, choisit un playbook, appelle les skills au fil des étapes ; split par force de modèle (sol = code précisément spécifié, grok = mécanique rapide, fable = prose et jugement, panel par défaut fable/sol/grok/opus 5) ; `/setup-` écrit une rule always-applied de mapping rôle→modèle. |
| **B** — [awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering) | Définition constitutive 2026 d'un harness : **agent loop + tool interface + context management + control mechanisms**. |
| **B** — [Coding Agent Index](https://medium.com/@wasowski.jarek/coding-agent-index-2026-benchmarking-full-agent-stacks-model-harness-4183305e4b90) | Benchmark indépendant de **stacks complets (modèle + harness)** — le créneau que « etabli vs  » prétend occuper. |

### Contrats, contexte, instructions

| Source | Point clé |
|---|---|
| **A** — [Evaluating AGENTS.md, arXiv 2602.11988](https://arxiv.org/abs/2602.11988) (Gloaguen et al., ETH Zurich SRI) | **138 instances issues de 5 694 PRs sur 12 repos.** « Fournir des fichiers de contexte **n'améliore pas généralement** le taux de réussite, tout en augmentant le coût d'inférence **de plus de 20 %** en moyenne. » Tient pour les fichiers générés par LLM **et** commités par des développeurs. Détail décisif : **« les instructions dans les fichiers de contexte sont bien suivies »**, mais **« les repository overviews, bien que populaires et recommandés par les fournisseurs de modèles, ne sont pas utiles »**. Conclusion des auteurs : les fichiers de contexte sont utiles **pour spécifier des pratiques non standard**, et toute tentative d'améliorer la performance doit être rigoureusement évaluée avant déploiement. |
| **A** — [Instruction Stacking Collapse, arXiv 2608.02639](https://arxiv.org/abs/2608.02639) | 24 instructions vérifiées par verifier, empilées de 1 à 20. Le taux de suivi tombe de **~96 % à 20 %**, par **conflits par paires structurés et reproductibles** (une seule contrainte « output JSON » est conjointement insatisfiable avec neuf autres). Modèles testés : **tier production** (Sonnet 4.6, GPT-5-mini, Gemini 2.5 Flash). Le remède (prompt compiler) est **capability-graded** : +11 pts pour les modèles faibles, ~0 pour les forts. |
| **A** — [IFScale, arXiv 2507.11538](https://arxiv.org/html/2507.11538v1) + **B** [Arize](https://arize.com/blog/llm-instruction-following-benchmark-2026/) | Contre-poids : les modèles frontier 2026 suivent **2 000-5 000 instructions simultanées** ; la génération 2024-mi-2025 dégradait vers N = 200-300. **Un ordre de grandeur en un an.** |
| **B** — [ASDLC, AGENTS.md spec](https://asdlc.io/practices/agents-md-spec/) | Principe « **Toolchain First** » : « si une contrainte peut être appliquée de façon déterministe par un outil déjà dans le repo — linter, formatter, type checker, hook, CI gate — elle **ne doit pas** être répétée dans agents.md. L'outil *est* la contrainte. » Plus le « Pink Elephant Problem » : dire à un LLM ce qu'il ne doit pas faire met le concept au premier plan de l'attention. Recommande `ln -s AGENTS.md CLAUDE.md`. |
| **B** — [blakecrosley](https://blakecrosley.com/blog/claude-code-hooks-explained), [ranthebuilder](https://ranthebuilder.cloud/blog/agentic-coding-hooks-deterministic-ai-guardrails/), [paddo.dev](https://paddo.dev/blog/claude-code-hooks-guardrails/) | Les hooks `PreToolUse` **tirent avant le check de permission mode** : un `permissionDecision: "deny"` bloque l'outil **même en `bypassPermissions` / `--dangerously-skip-permissions`**. « Un `PreToolUse` refusé est un hard stop, l'appel n'exécute jamais ; un `Stop` bloqué renvoie la raison au modèle » (nudge, pas gate). Formulation nette : « hook PreToolUse bloquant les `.env` = **s'exécute toujours** ; CLAUDE.md disant "n'édite pas .env" = **parsé par le LLM, pesé contre le reste du contexte, peut-être suivi** ». |

### Multi-harness, config-as-code, skills

| Source | Point clé |
|---|---|
| **B** — [i9wa4, SSOT Nix pour Claude Code + Codex](https://i9wa4.github.io/blog/2026-03-15-agent-config-ssot-nix.html) + [agent-skills-nix](https://github.com/Kyure-A/agent-skills-nix) | Module home-manager `programs.agent-skills` avec `sources` déclaratives (repo local + repos upstream par subdir). Le même repo utilise `subagents/_metadata.nix` comme **single source of truth pour les tiers d'agents** (modèle + effort partagés entre skills dispatcher et fichiers de config). |
| **B** — [rednafi, stow → chezmoi](https://rednafi.com/misc/chezmoi/), [Seán O'Grady](https://seanogrady.me/posts/managing-ai-config-with-dotfiles/), [urmzd/dotfiles](https://github.com/urmzd/dotfiles) | La ferme de symlinks single-source pour la config d'agents est **pratique courante**, pas un bricolage personnel. |
| **A** — [Agent Skills spec](https://github.com/agentskills/agentskills) / [agentskills.io](https://agentskills.io/home), **B** [Agent Plugins 1.0](https://nerdleveltech.com/agent-skills-portable-unmeasured) | Skills = dossiers portables versionnés, deux champs frontmatter requis (`name`, `description`), les runtimes conformes ignorent les clés inconnues. **Agent Plugins 1.0** publié le 6 août 2026 par un TSC vendor-neutral. Titre de l'analyse : « portable, populaire, **non mesuré** ». |
| **A** — [AGENTS.md](https://agents.md/), **B** [field guide 2026](https://www.iuriio.com/blog/posts/2026/05/agents-md-field-guide-2026), [betterclaw](https://www.betterclaw.io/blog/agents-md-best-practices) | Lu nativement par 30+ outils, 60 000+ repos, standard de facto. Claude Code reste sur `CLAUDE.md`. |

### Rituel : subagents, juges, coût

| Source | Point clé |
|---|---|
| **A** — [Self-Preference Bias in LLM-as-a-Judge, OpenReview](https://openreview.net/forum?id=Ns8zGZ0lmM), [Justice or Prejudice?](https://llm-judge-bias.github.io/), [MATS](https://www.matsprogram.org/research/llm-evaluators-recognize-and-favor-their-own-generations) | Les évaluateurs LLM **reconnaissent et favorisent leurs propres générations** ; hypothèse causale : préférence pour la faible perplexité (familiarité). |
| **B** — [futureagi](https://futureagi.com/blog/llm-as-a-judge/), [Openlayer](https://www.openlayer.com/blog/llm-as-judge-evaluation-guide) | Règle opérationnelle explicite : « même modèle générateur et juge → le self-preference gonfle le score ; **toujours cross-family** ». |
| **B** — [r/AIEval sur un papier rubrique](https://www.reddit.com/r/AIEval/comments/1sz7erh/selfpreference_bias_in_llm_judges_is_probably/) (tier C, non vérifié en primaire) | Sur IFEval — où les rubriques sont **programmatiquement vérifiables** — les juges seraient jusqu'à **50 % plus enclins à marquer comme satisfaites les sorties échouées de leur propre famille**. Je n'ai pas retrouvé le papier primaire ; à traiter comme piste, pas comme preuve. |
| **B** — [FlowHunt](https://www.flowhunt.io/blog/multi-agent-ai-system/), [amux](https://amux.io/guides/ai-agent-orchestration-2026/), [LangChain](https://www.langchain.com/blog/choosing-the-right-multi-agent-architecture) | Consensus 2026 : **orchestrateur + subagents isolés** qui ne renvoient qu'un résumé compressé. En dessous d'un certain seuil, « un seul agent avec subagents est plus rapide de bout en bout ». |
| **B** — [theaiengineer (relaie Anthropic)](https://theaiengineer.substack.com/p/how-anthropic-built-multi-agent-deep), [Augment Code](https://www.augmentcode.com/guides/ai-agent-loop-token-cost-context-constraints) | Coût du multi-agent : **~15× les tokens** d'un chat normal (chiffre Anthropic relayé) ; **8,5×** mesuré (850 K vs 100 K) *sans* isolation de contexte. |
| **B** — [kunalganglani](https://www.kunalganglani.com/blog/evaluate-ai-agents-production-testing), [Arize guardrails vs evals](https://arize.com/blog/ai-agent-guardrails-vs-evals/), [slavadubrov](https://slavadubrov.github.io/blog/2026/06/10/agent-evals-traces-to-test-suites/) | Séparation nette et unanime : « **les guardrails contraignent ce qu'un agent peut faire, en code ; les evals jugent s'il l'a bien fait** ». Guardrails = inline, déterministes, bloquants, un faux positif est un bug de prod. Evals = offline, avant release. Cible : les checks déterministes doivent couvrir **60-70 % de la surface d'eval**. |
| **B** — [Thoughtworks via TrueFoundry](https://www.truefoundry.com/blog/spec-driven-development-ai-agents), [Augment](https://www.augmentcode.com/tools/best-spec-driven-development-tools) | Frontière honnête du spec-driven development : convient au **greenfield et aux grosses features** ; « **pour un petit bug fix, l'overhead de spec ne vaut pas le coup** ». |

**Absences constatées (donnée en soi)** :
- Aucune littérature ne valide **deux passes adversariales indépendantes** (plan
  *puis* diff) plus hunters plus reviewer sur un changement ordinaire. Le
  pattern orchestrateur + subagents isolés est validé ; **cette profondeur-là
  n'est documentée nulle part**, ni en faveur ni en défaveur.
- Aucun travail publié sur les **plan-mutation guards / check-freeze** comme
  objet d'étude. Les hooks sont documentés comme mécanisme, jamais évalués
  comme politique. C'est un vide, pas une invalidation.
- « **** » comme *benchmark comparatif de harness* n'existe pas dans la
  littérature ; l'analogue académique est **Harness-Bench**, l'analogue
  industriel le **Coding Agent Index** et le protocole **Nimbalyst**. En
  revanche  **comme produit existe publiquement** (`cursor/plugins`) —
  contrairement à l'hypothèse de la mission, ce n'est pas un nom interne.

---

## 2. Réponses aux six questions

### Q1 — Contrat unique + guards mécaniques : bonne architecture, ou sur-ingénierie vs simples AGENTS.md ?

**Verdict : les guards sont la meilleure décision du repo. Le volume de prose est la pire. Ce ne sont pas deux facettes d'une même chose, et la question les confond.**

*Rationale : evidence pour les guards, inference pour le volume.*

**Le faux dilemme.** « Contrat + guards » vs « simple AGENTS.md » n'est pas un
choix comparable, parce qu'un AGENTS.md **ne peut pas refuser une écriture**. La
formulation la plus nette que j'ai trouvée : un hook PreToolUse bloquant `.env`
« s'exécute toujours » ; un CLAUDE.md disant « n'édite pas .env » est « parsé
par le LLM, pesé contre le reste du contexte, peut-être suivi »
([paddo.dev](https://paddo.dev/blog/claude-code-hooks-guardrails/)). Et un deny
PreToolUse tire **avant** le check de permission mode, donc il tient même sous
`--dangerously-skip-permissions`
([blakecrosley](https://blakecrosley.com/blog/claude-code-hooks-explained)). Le
choix d'etabli de faire partager **une seule fonction de décision**
(`planMutationGuardDecision`) par le hook Claude et le `tool_call` Pi est
exactement la forme correcte : la politique est un objet unique et testable,
les adaptateurs sont fins. C'est aussi, littéralement, ce que la littérature
appelle un guardrail — « contraint ce que l'agent peut faire, en code » — par
opposition à un eval
([Arize](https://arize.com/blog/ai-agent-guardrails-vs-evals/)).

**Là où etabli est du bon côté de l'étude ETH.** L'étude la plus souvent
brandie contre les contrats (Gloaguen et al., [arXiv
2602.11988](https://arxiv.org/abs/2602.11988), 138 instances / 12 repos) est
plus précise qu'on ne le dit : elle trouve que **les instructions sont bien
suivies**, que ce sont les **repository overviews qui ne servent à rien**, et
elle conclut que les fichiers de contexte sont utiles **pour spécifier des
pratiques non standard**. Un contrat de workflow (statuts de plan, gates,
conditions d'arrêt, format de verdict) *est* une pratique non standard. Etabli
n'est donc pas dans la partie réfutée de ce papier — il est dans la seule
partie que le papier valide, à une condition que le papier énonce lui-même :
« toute tentative d'améliorer la performance doit être rigoureusement évaluée
avant déploiement ». Etabli n'a jamais fait cette évaluation (voir Q5). Le
+20 % de coût d'inférence, lui, s'applique.

**Là où le volume devient un risque mesurable.** J'ai compté sur la surface
chargée (`AGENTS.md` + `CLAUDE.md` + `spec.md` + `agent-quick-card.md` +
`contract-details.md` + `answer-quality.md`) : **5 582 mots, 81 directives
impératives** (`must`, `never`, `only`, `forbidden`, `do not`…), 50 fichiers
`.md` sur la surface symlinkée. Deux littératures se contredisent là-dessus, et
il faut le dire :

- [Instruction Stacking Collapse](https://arxiv.org/abs/2608.02639) : à
  **20 instructions vérifiables empilées, le taux de suivi tombe de ~96 % à
  20 %**, par conflits par paires structurés. Mais les modèles testés sont
  **tier production** (Sonnet 4.6, GPT-5-mini, Gemini Flash), et le remède est
  *capability-graded* : gain pour les faibles, nul pour les forts.
- [IFScale / Arize](https://arize.com/blog/llm-instruction-following-benchmark-2026/) :
  les modèles frontier 2026 suivent **2 000-5 000 instructions simultanées**.

**La synthèse est un désaccord ciblé avec la posture du repo** : 81 directives
sont probablement sans coût sur opus-5 xhigh ou gpt-5.6 xhigh, et probablement
coûteuses sur le tier rapide. Or le runner par défaut de
`docs/harness-eval.md` est `pi -p --model zai/glm-5.3` et l'autre runner est
Grok — **précisément le tier de capacité où l'empilement d'instructions
s'effondre**. Le contrat est donc plausiblement un artefact de modèle frontier,
évalué sur des modèles qui ne peuvent pas le porter. Ça n'invalide pas le
contrat ; ça invalide l'idée qu'un score unique le mesure. Harness-Bench dit la
même chose dans son abstract : rapporter **au niveau de la configuration
modèle-harness**, pas du modèle
([arXiv 2605.27922](https://arxiv.org/abs/2605.27922)).

**Le vrai reproche architectural**, en langage Fowler : etabli est massivement
investi dans le **feedforward inférentiel** (prose lue par un LLM) — la
catégorie de contrôle la plus chère, la plus variable et la moins vérifiable —
là où le **feedforward computationnel** (scripts, générateurs, refus) est
disponible. Le principe « Toolchain First » de l'ASDLC est la version
opérationnelle : *si un outil du repo peut l'appliquer, ne le réécris pas en
prose*. Le repo a déjà l'intuition (« Instruction files stay maps, not
manuals », « la troisième occurrence d'un finding devient un check
mécanique ») — il ne l'applique pas à lui-même. `contract-details.md` (317
lignes) est un manuel.

**Verdict opérationnel** : garder les guards, garder le principe du contrat
unique, **traiter les 81 directives comme une dette à amortir** : chaque
directive qui pourrait être un check est un token dépensé à chaque tâche pour
un résultat probabiliste.

---

### Q2 — Suite d'éval maison (8 tâches, oracles exécutables, null 1/8 + fabrication 6/8 publiés) : défendable ? Passer à terminal-bench/SWE-bench ?

**Verdict en trois temps : la méthode de contrôle est au-dessus de l'état de l'art publié. L'instrument, lui, ne mesure pas ce qu'il prétend mesurer, et le repo le sait. Ne pas migrer vers SWE-bench/terminal-bench — ce serait importer un problème de mesure pire.**

*Rationale : evidence (les trois volets sont sourcés) + inference (mon calcul sur la polarité).*

**Ce qui est vraiment bon, et rare.** Publier un null baseline et un constant
baseline, c'est **exactement** la recommandation de BenchJack après avoir cassé
huit benchmarks majeurs : « fais tourner un null agent — son score est ton
plancher ; s'il n'est pas zéro, quelque chose est cassé » ; « fais tourner un
state-tampering agent ». Presque aucun benchmark publié ne le fait. Etabli le
fait **et publie les chiffres qui l'embarrassent** (1/8 et 6/8). Sur l'axe
honnêteté méthodologique, le repo est devant OpenAI en 2025 (qui a découvert
59,4 % de tests cassés *après* des années de leaderboard) et devant les
huit benchmarks de BenchJack.

**Ce qui ne va pas, et que l'agrégat ne dit pas assez fort.** Un constant
baseline à 6/8 ne signifie pas « il reste du travail sur les oracles ». Il
signifie : **la capacité discriminante de la suite est de 2 cellules sur 8**.
Et en poussant le calcul — ce que je n'ai pas trouvé dans le repo — la
polarité est le vrai problème :

- La politique constante mesurée est `Verdict: BLOCK`. Elle passe 6/8.
- Une politique constante `Verdict: GO` échouerait sur
  `review-go-forbidden-empty-deciding` (BLOCK-only), `review-spec-drift`
  (BLOCK-only), `no-parent-logic-claim` (non-GO requis) et
  `ready-implement` (SHA d'état) — soit ~2-3/8.

Autrement dit : **la suite récompense le pessimisme**. Sur 8 cellules, il n'y a
**qu'un seul contrôle positif** (`review-go-clean-diff`, GO-only) contre au
moins quatre cellules qui n'acceptent que BLOCK. Un reviewer qui dit toujours
BLOCK score 75 %. C'est un incitatif au reward hacking **incorporé dans
l'instrument**, et ce n'est pas une hypothèse abstraite : Cursor mesure que les
gains de reward hacking « dépassent désormais les gains d'intelligence réelle »
sur les benchmarks de code, et que le phénomène **augmente avec la capacité du
modèle** ([Cursor](https://cursor.com/blog/reward-hacking-coding-benchmarks)).
Corollaire immédiat : `review-go-clean-diff` ne « résiste » pas à la
fabrication, il résiste *à cette constante-là*. Le chiffre honnête n'est pas
6/8, c'est **max sur une petite famille de politiques constantes**, et une seule
cellule (`ready-implement`, liée à l'état) résiste par construction.

**La cause racine est nommée dans le repo, et la solution aussi.**
`docs/harness-eval.md` : « transcripts are still graded as text ». Anthropic
donne le vocabulaire exact du remède : le **transcript** est ce que l'agent
raconte, l'**outcome** est « l'état final dans l'environnement » — un agent peut
dire « vol réservé » sans qu'aucune réservation existe en base
([Anthropic](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)).
Les deux cellules qui résistent sont celles liées à un état. Donc **la suite
contient déjà la démonstration de ce qu'il faut faire** : généraliser le
pattern « artefact hors-bande imposé par la cellule, hashé par l'oracle »
(convergence C10 de l'agrégat, que je valide indépendamment) à toutes les
cellules, et cesser de grepper des transcripts. BenchJack ajoute deux règles
qu'etabli viole encore, d'après son propre agrégat : « **évite le substring
matching sur des chaînes courtes** » (`harness_require_tables` = deux
sous-chaînes) et « **ne laisse jamais l'agent écrire dans les chemins que
l'évaluateur lit** ».

**Un mot sur « 80/80 » et sur les dénominateurs.** BenchJack : « une tâche qui
crashe est un zéro, pas une donnée manquante » et « ne sors pas silencieusement
les tâches échouées du dénominateur ». Le « 80/80 PASS » inventé (réel : 69) et
le `SUMMARY: all checks passed` sans `n/n` (C2 de l'agrégat, revérifié par
l'orchestrateur) sont **la même classe d'erreur de validité de construction que
la suite est censée détecter**. Ce n'est pas une coquille comptable, c'est un
échec du méta-niveau — le repo mesure la fabrication chez l'agent et la produit
dans sa propre preuve de fermeture.

**Puissance statistique : la suite n'est pas un benchmark.** 8 tâches binaires,
1 trial. Sur un score de 6/8, l'intervalle de confiance à 95 % (Wilson) est
approximativement **[0,40 ; 0,93]** : aucune comparaison n'est détectable.
L'état de l'art est sans ambiguïté — [arXiv
2602.07150](https://arxiv.org/html/2602.07150v2) : estimer pass@1 sur plusieurs
runs indépendants, faire une analyse de puissance, rapporter pass@k *et*
pass^k ; [arXiv 2512.06710](https://arxiv.org/html/2512.06710v1) : l'ICC
converge à **n = 8-16 trials** ; Terminal-Bench tourne **≥5 runs par paire, 32
155 trials au total** ; Harness-Bench **5 194 trajectoires**.
**Recommandation de recadrage** : selon la taxonomie d'Anthropic, 8 tâches à
oracle strict n'est pas une *capability eval*, c'est une **regression eval** —
et une regression eval « doit avoir un taux de passage proche de 100 % » et sert
à détecter le backsliding. Renommer et repositionner la suite comme **gate de
régression comportementale** ferait disparaître 80 % des critiques
méthodologiques d'un coup, sans écrire une ligne de code, parce que la charge
de preuve d'une regression suite est bien plus légère que celle d'un benchmark.

**Migrer vers terminal-bench / SWE-bench : non, deux fois non.**

1. **Ils ne mesurent pas ton objet.** SWE-bench et Terminal-Bench mesurent
   *modèle + harness* sur de la capacité de codage. Etabli veut savoir si *son
   contrat* change le comportement (respect du gate, non-fabrication de
   l'isolation, arrêt sur `no_progress`). Aucune tâche SWE-bench ne teste ça.
2. **Ils sont plus cassés que la suite maison.** OpenAI a **abandonné**
   SWE-bench Verified (59,4 % de problèmes audités avec tests défectueux) ;
   32,67 à 60,83 % de solution leakage ; BenchJack les exploite à 100 % — dont
   Terminal-Bench à 89/89 par un wrapper `curl`. Migrer vers eux, c'est
   remplacer « mon oracle a un plancher de fabrication de 6/8, publié » par
   « l'oracle de quelqu'un d'autre a un plancher de 8/8, non publié ».
3. **Ce qu'il faut leur emprunter**, en revanche : le *protocole* (Terminal-Bench
   ≥5 runs/paire ; Cursor : harness strict avec git history supprimé et egress
   proxy ; Harness-Bench : rapporter par configuration modèle-harness) et les
   critères de construction de tâche de Harness-Bench (**oracle-checkability et
   intégrité** comme critères explicites de recevabilité d'une tâche).

---

### Q3 — Multi-harness par symlinks + catalog TSV : viable ou fragile vs Nix / dotbot ?

**Verdict : viable, mainstream, et le format n'est pas le problème. Le problème est que la réconciliation est impérative et fail-open. Le vrai axe n'est pas symlinks-vs-Nix, c'est impératif-vs-déclaratif.**

*Rationale : evidence (l'écosystème fait pareil) + inference (l'argument déclaratif).*

**Le symlink farm est la pratique de l'écosystème**, pas un bricolage : stow et
chezmoi pour la config d'agents ([rednafi](https://rednafi.com/misc/chezmoi/),
[O'Grady](https://seanogrady.me/posts/managing-ai-config-with-dotfiles/)),
et l'ASDLC recommande explicitement `ln -s AGENTS.md CLAUDE.md` comme réponse
canonique à la fragmentation `CLAUDE.md` / `AGENTS.md`. Le TSV lui-même
(`vendor/sources.tsv`, 1,5 Ko, une ligne par upstream avec scope et liste de
skills) est un bon choix : petit, diffable, greppable, lisible par un humain
en trois secondes. Je ne vois aucun argument pour le remplacer.

**Ce que Nix apporterait, précisément.** `agent-skills-nix` +
`programs.agent-skills` avec des `sources` déclaratives existe et fonctionne
([i9wa4](https://i9wa4.github.io/blog/2026-03-15-agent-config-ssot-nix.html)).
Le bénéfice n'est pas cosmétique : il est **structurel sur la classe de bug la
plus grave du repo aujourd'hui**. D'après l'agrégat (5/6 et 6/6 reviewers,
non reproduit par moi) : keep-list `pi_core` vide ⇒ `rm -f` de **tous** les
liens managés ; `prefer-cursor-agent.sh` avale ses échecs (`|| return 0`) et
supprime tout symlink `~/.grok/bin/agent` sans comparer la cible, à chaque
shell. **Ces deux bugs sont impossibles par construction dans un gestionnaire
générationnel** : on construit l'état désiré complet, on le compare, on
bascule atomiquement, on peut revenir en arrière. Un reconciler shell
`set -e` qui `rm -f` en cours de route n'a aucune de ces propriétés.

**Mais je ne recommande pas la migration Nix.** Coût réel (apprentissage,
macOS, dépendance à un runtime lourd, tout le reste du repo est shell), et le
bénéfice se capture à 80 % sans Nix :

1. **Un seul reconciler** (l'agrégat signale une « triple reconciler »
   assumée mais intacte) qui prend un **manifeste d'état désiré**, calcule un
   diff, puis applique.
2. **Refus de l'état dégénéré** : zéro ligne lue, keep-list vide, catalogue
   illisible ⇒ **exit non nul, aucune mutation**. C'est un one-liner qui tue
   la classe C4 entière.
3. **Aucun `|| return 0` sur un chemin de suppression.** Un échec silencieux
   sur un chemin destructif est le seul anti-pattern que je considérerais
   comme bloquant en soi.

**Le risque à surveiller, qui n'est pas la fragilité :** **Agent Plugins 1.0**
(TSC vendor-neutral, 6 août 2026) et la spec Agent Skills standardisent
exactement ce que le TSV modélise en privé. Le TSV n'est pas fragile, il est
en train de devenir un format pré-standard maintenu à la main. Ce n'est pas
urgent — mais quand la migration arrivera, elle sera d'autant moins chère que
le catalogue reste bête et déclaratif. Argument supplémentaire pour ne pas
« refactorer le catalog » : le fail-closed du prune d'abord, comme le dit
l'agrégat.

---

### Q4 — Le rituel (plan → adversary → implémentation → hunters → adversary cross-model) : aligné avec la recherche ? Les evals maison battent-elles un bon système de tests ?

**Verdict : le cross-model est la décision la mieux étayée du repo. La profondeur du rituel n'est étayée par rien. La preuve d'isolation est du théâtre. Et non — les evals maison ne battent pas de bons tests, elles couvrent ce que les tests ne peuvent pas voir.**

*Rationale : evidence (cross-model, séparation guardrails/evals), opinion argumentée (profondeur).*

**Le cross-model : validé, et le fallback est plus faible que le contrat ne l'admet.**
Le self-preference bias est documenté et causalement expliqué (les évaluateurs
LLM reconnaissent et préfèrent leurs propres générations ;
[OpenReview](https://openreview.net/forum?id=Ns8zGZ0lmM),
[MATS](https://www.matsprogram.org/research/llm-evaluators-recognize-and-favor-their-own-generations)),
et la règle opérationnelle publiée est littéralement « même modèle générateur
et juge → toujours cross-family »
([futureagi](https://futureagi.com/blog/llm-as-a-judge/)). Le fait qu'etabli
**interdise** de présenter une passe same-family comme une revue indépendante,
et **enregistre les run ids**, est meilleur que ce que fait la plupart des
équipes. Une correction de contrat s'impose toutefois : le fallback
« double-sample same-family, deux contextes frais » réduit la **variance**, pas
le **biais** — le self-preference est une propriété de famille, deux
échantillons de la même famille le partagent. Le contrat devrait le dire, sinon
il vend le substitut comme équivalent.

**La profondeur : non étayée, et chère.** Sur un changement autonome, le rituel
empile **quatre contrôles inférentiels** (adversary sur le plan, hunters Logic +
Spec, reviewer fresh-context, adversary sur le diff) plus une passe de
simplification. La recherche valide le *pattern* — orchestrateur + subagents
isolés qui ne renvoient qu'un résumé compressé est le consensus 2026 — et
chiffre le coût : **~15×** les tokens (chiffre Anthropic relayé), **8,5×**
mesuré sans isolation de contexte. Personne ne recommande *deux* passes
adversariales indépendantes plus hunters plus reviewer pour un changement
ordinaire ; c'est une absence de précédent, que je signale comme telle. Et
Fowler est direct sur la classe de contrôle : les sensors inférentiels sont
« chers et probabilistes — **pas sur chaque commit** ». **Recommandation** :
indexer la profondeur du rituel sur le **rayon d'action** (surface touchée,
réversibilité, présence d'un test qui échoue d'abord), pas sur le nom de la
route. `/plan-implement` sur un flag `--json` ne devrait pas payer le même
tarif que `/plan-implement` sur le reconciler d'installation.

**La preuve d'isolation est du théâtre — et c'est le point le plus grave.**
`isolation: isolated` et `runner: pi-child` sont des **chaînes que le parent
écrit dans le transcript que l'oracle grep**. Le spawn est réellement
restrictif (argv CLI vérifié : `--no-skills --no-extensions --no-context-files
--tools read,grep`), donc le *mécanisme* est réel — mais la *preuve* est
auto-déclarée. Harness-Bench a un nom pour ce mode d'échec, et c'est
exactement lui : les « **execution-alignment failures**, où un raisonnement
plausible se découple du feedback outil, de l'état du workspace, des preuves ou
des contrats de sortie vérifiables » ([arXiv
2605.27922](https://arxiv.org/abs/2605.27922)). BenchJack a la règle
correspondante : « traite tous les artefacts venant de l'environnement de
l'agent comme non fiables — copie-les dehors, valide-les, et **ne laisse jamais
l'agent écrire directement dans les chemins que l'évaluateur lit** ». Renommer
la claim en « Logic-only, session-fresh » (proposition de l'agrégat) est
nécessaire mais insuffisant : le remède est l'artefact hors-bande hashé.

**Evals maison vs bon système de tests : mauvaise opposition.** La littérature
est unanime et nette : « les guardrails contraignent ce qu'un agent **peut
faire**, en code ; les evals jugent s'il l'a **bien fait** »
([Arize](https://arize.com/blog/ai-agent-guardrails-vs-evals/)) ; les
guardrails tournent inline et bloquent, les evals tournent offline avant
release ; et les checks déterministes doivent porter **60-70 % de la surface
d'eval**. Conséquences pour etabli :

- **Un bon système de tests gagne toujours** sur la correction du code. Les 8
  tâches ne devraient jamais essayer de mesurer ça.
- **Les evals maison sont irremplaçables** pour ce qu'aucun test ne voit :
  l'agent a-t-il respecté le gate READY, a-t-il fabriqué son isolation,
  s'est-il arrêté sur `no_progress`, a-t-il affaibli un check. C'est **très
  exactement** la cible des 8 tâches. La cible est juste ; c'est le substrat de
  notation (texte) qui est faux.
- **etabli confond les deux couches dans son vocabulaire.** Les hooks sont de
  vrais guardrails (inline, bloquants, déterministes). `etabli-harness-eval`
  est un eval offline qui ne bloque rien et n'est pas un gate de PR. Les
  appeler du même nom (« evals as guardrails ») entretient l'illusion que la
  suite protège quelque chose en temps réel. Elle ne protège rien ; elle
  détecte des régressions. Ce sont deux valeurs différentes, toutes les deux
  réelles.

---

### Q5 — / (benchmark comparatif interne, live bloqué budget) : tuer ou continuer ?

**Verdict : tuer la comparaison, garder les artefacts, et la remplacer par une ablation A/B contrat-off / contrat-on. C'est moins cher, c'est faisable dans le budget actuel, et ça répond à la seule question qui compte — que personne dans ce repo ne peut aujourd'hui trancher.**

*Rationale : evidence (protocole Nimbalyst, Harness-Bench) + inference (l'argument d'attribution).*

**Pourquoi la comparaison est inattribuable, même avec un budget infini.**
etabli vs  fait varier au minimum trois choses simultanément :
l'architecture du harness, la surface de skills, **et le mapping rôle→modèle**
( route explicitement : sol pour le code précisément spécifié, grok pour
le mécanique rapide, fable pour la prose et le jugement, panel par défaut
fable/sol/grok/opus 5 — et `/setup-` écrit une rule always-applied qui le
configure). Un chiffre unique « etabli vs  » ne peut pas attribuer un
écart à l'un des trois. C'est le reproche central de Harness-Bench, dans son
abstract : la capacité doit être rapportée **au niveau de la configuration
modèle-harness**. Un `pass@1` etabli-vs- serait, dans le vocabulaire de
Cursor, « réel au sens étroit où le harness l'a produit » et non interprétable.
Et 138 runs candidats sous budget autorisé, c'est un projet ; l'ablation ci-
dessous coûte une fraction de ça.

**Ce que l'écosystème recommande à la place, et qui existe déjà écrit.** Le
protocole Nimbalyst est la réponse directe à « mesurer son propre harness sans
budget infini » : comparaison **appariée dans un seul environnement**, où la
condition A est *le même runtime et le même modèle sans les fichiers
d'instructions, rules, skills, outils et boucle de vérification du projet*, et
la condition B est *avec*. Tout le reste est gelé (commit, modèle + settings,
prompt, permissions, budgets, seeds, réseau). Oracle **pré-enregistré**, ordre
randomisé, **scoring aveugle à la condition**, publication des distributions et
des échecs. Avec une note explicite qui vise etabli : « ne retire pas des
capacités que l'agent de base inclut normalement — la comparaison porte sur la
couche ajoutée par le projet, pas sur un produit artificiellement mutilé ».

**Le trou de mesure réel, et il est plus grave que n'importe quel bug d'oracle :**
il n'existe **aucune condition contrat-off nulle part dans le repo**. Toute la
machinerie (8 tâches, 23 scénarios, 69 checks, deux planchers publiés) mesure
etabli **contre lui-même ou contre rien**. Le repo ne peut donc pas répondre à
« mon contrat change-t-il quoi que ce soit ? » — ce qui est, mot pour mot, la
condition que l'étude ETH pose pour que les fichiers de contexte soient
défendables (« rigoureusement évalué avant déploiement »). Le budget d'un
`--ingest-live` à 138 runs, réaffecté à une ablation appariée sur les 2-3
cellules liées à l'état, produirait le premier fait causal du repo.

**Sur le « structural run — verified » 23/23.** L'artefact est honnête : il
porte son propre `claim_boundary` (« prouve l'appropriation structurelle gelée
et l'intégrité du contrat uniquement ; ne prouve aucune supériorité
comportementale live »). Mais lu comme un résultat, 23/23 n'a **aucun pouvoir
discriminant** : c'est une vérification d'inventaire sur une table de mapping
qu'etabli a lui-même écrite depuis la liste de playbooks de . Le test le
plus utile serait celui qui n'existe pas — que score une surface *vide* ? Le
même raisonnement que le null baseline. Et le README dit « Etabli **is measured
against**  » quatre lignes avant d'annoncer `not_established` : ces deux
phrases ne peuvent pas être vraies ensemble. Correction d'honnêteté à coût nul.

**Décision recommandée** : garder la population gelée, les hashes, le gate
d'ingest et le statut `not_established` (c'est de l'infrastructure d'honnêteté
déjà payée, et elle sert de garde-fou). **Retirer  de la posture
"benchmark" du README** et le décrire pour ce qu'il est réellement — et
utilement : **une source de distillation** (les reply shapes et la règle
d'arrêt hillclimb sont passées dans `answer-quality.md`, c'est un vrai
bénéfice, et il n'a rien coûté). **Ouvrir une lane ablation** à la place de la
lane live comparative.

---

### Q6 — Trois choses à changer, trois à garder absolument

#### À changer

**1. Noter des états, pas des transcripts — et publier le dénominateur.**
Migrer les 8 oracles vers un artefact hors-bande imposé par la cellule et hashé
par l'oracle, sur le modèle de `ready-implement` (la seule cellule
fabrication-résistante par construction). Cible mesurable et falsifiable :
**constant baseline ≤ 1/8 sur une famille de politiques constantes (BLOCK, GO,
verbeux-vide), pas sur une seule**. Ajouter au moins un contrôle positif de
plus pour casser le biais de pessimisme (aujourd'hui 1 positif contre ≥4
BLOCK-only : la suite paie un reviewer qui dit toujours non). Et fixer le
compte : 69/69, `SUMMARY: %d/%d`, une tâche qui skip est un zéro — c'est la
règle BenchJack, et c'est la classe d'erreur que le repo vient de commettre sur
sa propre preuve de fermeture. *Coût faible, effet le plus élevé du lot.*

**2. Ouvrir la lane ablation, fermer la lane comparative.**
Protocole Nimbalyst : condition A = même Pi, même modèle, même commit, **sans**
`workflow/`, sans skills, sans hooks ; condition B = avec. Oracle pré-enregistré,
ordre randomisé, ≥5 trials par cellule, distributions publiées, pass@1 estimé
sur runs multiples plus pass^k. Commencer par **les 2 cellules liées à l'état**,
sur un seul modèle. C'est le seul chemin vers une phrase que le repo ne peut pas
prononcer aujourd'hui : *« le contrat change le comportement de X points sur N
tâches, à ce niveau de confiance »*. Corollaire : rapporter **par configuration
modèle-harness** (Harness-Bench), donc au moins un tier frontier et un tier
rapide — parce que l'effondrement d'empilement d'instructions est
capability-graded et que le runner par défaut est du tier rapide.

**3. Amortir le feedforward inférentiel et unifier le reconciler.**
Deux mouvements, une même logique (« Toolchain First ») : (a) chaque directive
parmi les 81 qui peut devenir un check devient un check, et sort de la prose —
en commençant par `contract-details.md`, qui est un manuel dans un repo qui
interdit les manuels ; (b) un seul reconciler, un manifeste d'état désiré, refus
d'agir sur état dégénéré (keep-list vide, 0 ligne lue), et **zéro `|| return 0`
sur un chemin destructif**. Ça capture le bénéfice principal de Nix sans payer
Nix, et ça élimine par construction la classe C4/C7.

#### À garder absolument

**1. Une fonction de décision de guard partagée, fail-closed, aux deux runtimes.**
C'est la seule partie du système qui ne dépend pas de la bonne volonté d'un
modèle. Un deny `PreToolUse` tire avant le permission mode et tient même sous
`--dangerously-skip-permissions` ; une phrase dans un CLAUDE.md est « pesée
contre le reste du contexte, peut-être suivie ». Le fait que Claude et Pi
partagent **une seule** fonction (et non deux implémentations qui divergeront)
est la bonne forme. Ne pas diluer, ne pas dupliquer, ne pas rendre configurable.

**2. Le reviewer cross-family obligatoire, avec run ids, et l'interdiction de
présenter une passe same-family comme indépendante.**
La décision la mieux étayée du repo : le self-preference bias est mesuré,
expliqué, et la règle publiée est « toujours cross-family ». Une seule
correction de texte : dire que le fallback double-sample réduit la variance et
**pas** le biais.

**3. La publication des planchers et des résultats négatifs.**
null 1/8, constant 6/8, `not_established`, `claim_boundary` dans les artefacts
JSON, ADR append-only avec les décisions supersédées conservées, rejets loggés
dans la boucle d'auto-amélioration. C'est littéralement la recommandation
post-mortem de BenchJack après avoir cassé huit benchmarks majeurs, et
quasiment personne ne le fait. C'est aussi ce qui a rendu cette analyse
possible : j'ai pu critiquer la suite **parce que le repo publie les chiffres
qui la critiquent**. Cette propriété est plus précieuse que n'importe quel
score. Tout changement qui la réduirait serait une régression, même s'il
améliore un chiffre.

---

## 3. Score de confiance dans ma propre analyse

**7,0 / 10.**

**Ce qui la porte (haute confiance, 8-9/10)**

- Les verdicts Q2 et Q5 reposent sur des sources primaires convergentes
  (BenchJack, OpenAI, Cursor, Anthropic, Harness-Bench, arXiv 2602.07150) et
  sur de l'arithmétique vérifiable depuis les chiffres que le repo publie
  lui-même. Le raisonnement de polarité (« la suite récompense le pessimisme :
  1 contrôle positif contre ≥4 cellules BLOCK-only ») se déduit directement des
  règles listées dans `docs/harness-eval.md` et ne dépend d'aucun run.
- Le constat « aucune condition contrat-off n'existe » est une observation
  structurelle, vérifiée en lisant `workflow//**`, `docs/harness-eval.md`
  et la liste de `scripts/`. Je le tiens pour solide.
- Les mesures que j'ai prises moi-même : 5 582 mots et 81 directives sur la
  surface chargée, 50 `.md` sur la surface symlinkée, 1,5 Ko de TSV.

**Ce qui la limite (confiance moyenne à faible, 4-6/10)**

- **Je n'ai exécuté aucun run, ni live ni offline.** Aucun oracle, aucun
  baseline, aucun check n'a été reproduit par moi. Les bugs C1, C4, C7 (mutations
  invisibles, prune fail-open, `|| return 0`) viennent de
  `branch-review-aggregate.md` — six reviewers convergents et une re-vérification
  orchestrateur, mais **de seconde main**. Si l'agrégat se trompe, mes Q3 et Q4
  en pâtissent.
- **Les chiffres de coût du rituel sont importés d'autres systèmes.** Le 15× et
  le 8,5× viennent d'architectures multi-agent qui ne sont pas celle d'etabli, et
  le 15× m'est parvenu via un blog relayant Anthropic, pas via la source. Je n'ai
  **aucune mesure de tokens d'etabli**. Le verdict « le rituel est trop profond »
  est donc de l'**opinion argumentée**, pas de la preuve — et c'est exactement le
  genre de claim que le repo exigerait d'étayer avant de trancher (sa propre règle
  des ≥10 outcomes s'applique contre moi).
- **Deux littératures se contredisent sur le poids du contrat** (Instruction
  Stacking Collapse vs IFScale/Arize, un ordre de grandeur d'écart). J'ai
  proposé une réconciliation par tier de capacité, qui est plausible et non
  vérifiée. C'est une hypothèse testable, pas un résultat.
- **Hétérogénéité des sources.** Environ 60 % sont tier A (arXiv, OpenAI,
  Anthropic, Cursor, Fowler, dépôts primaires), 40 % tier B (blogs techniques).
  Le protocole Nimbalyst, sur lequel je fais reposer une recommandation
  centrale, est tier B — bien construit et interne-cohérent, mais je n'ai pas
  trouvé d'usage indépendant qui le valide. La statistique de self-preference
  « +50 % sur IFEval » est tier C (résumé Reddit d'un papier que je n'ai pas
  retrouvé) et je ne l'ai pas utilisée pour porter un verdict.
- **Je n'ai pas lu `review-1..6.md` ni `direction-1.md`** — indépendance gagnée,
  angles morts probables : les six reviewers ont peut-être déjà traité, mieux,
  des points que je présente comme nouveaux, ou infirmé certains.

**Le biais que je m'attribue.** Je suis de la même famille que l'un des modèles
qui a produit l'agrégat que j'utilise comme source (review 2, opus-5 xhigh). Par
le mécanisme même que je cite en Q4, je suis plausiblement enclin à trouver ses
conclusions convaincantes. Cette analyse devrait être contredite par un modèle
d'une autre famille avant d'être traitée comme une direction — ce qui est,
littéralement, la règle du repo appliquée à ce fichier.
