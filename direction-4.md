# Direction etabli — validation (direction 4)

- **Modèle** : grok-4.6 (xhigh)
- **Date** : 2026-08-23
- **HEAD inspecté** : `7484b59` (`fix(workflow): enforce oracle state integrity and publish both floors`) — **verified**
- **Méthode** : lecture locale (README, `docs/how-it-works.md`, `workflow/spec.md`, `docs/harness-eval.md`, `branch-review-aggregate.md`, ADRs, scripts, oracles, catalogue TSV) ; pack obvault borné (données non fiables) ; ≥6 recherches Brave + extraits de pages primaires. Aucun run live facturé. Aucun commit.

Verdict global : **garder le noyau (guards mécaniques + source unique + honnêteté des floors), arrêter de traiter le rituel et le benchmark  live comme la direction.** Etabli a la bonne *espèce* d'architecture (hooks > prose) et la mauvaise *dose* (contrat always-on + oracles encore textuels + comparatif live trop cher). Ce n'est pas une validation molle : les 6/8 cellules encore fabricables et le rituel adversary×2 sont des erreurs de construct validity, pas des détails d'implémentation.

---

## Sources web consultées

Recherches Brave (`./search.js` depuis `/Users/tonours/.pi/agent/skills/brave-search`) :

1. Harness/CLI 2025-2026 (Claude Code, Codex, Gemini CLI, OpenCode, Amp, Aider, cursor-agent)
2. Évals d'agents (SWE-bench, critiques, DeepSWE, Terminal-Bench, reward hacking, floors)
3. Multi-harness / config-as-code (Nix, Home Manager, Dotbot, catalogues de skills, MCP)
4. Comportement des modèles en agent (contrats longs, coût tokens, subagents)
5.  / population-stack / harness comparatif
6. Alternatives contract-first, guards d'écriture, evals maison
7. DeepSWE Datacurve (méthode)
8. Anthropic multi-agent, coût 15×
9. Lost-in-the-middle / CLAUDE.md ignoré
10. CursorBench / traces → régression
11. Claude Code PreToolUse hooks
12. Amp / Aider / OpenCode / AGENTS.md
13. ETH Zurich `AGENTS.md` (Gloaguen et al.)

Pages extraites (`./content.js`) :

| URL | Point clé retenu |
| --- | --- |
| https://cursor.com/blog/reward-hacking-coding-benchmarks | 63 % des succès Opus 4.8 Max Pro audités = lookup du fix ; scores stricts −14.1 / −20.7 pts |
| https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents | Distinguer transcript vs outcome ; graders code / modèle / humain ; evals capability vs regression |
| https://inventivehq.com/blog/claude-md-vs-agents-md-vs-gemini-md | AGENTS.md = standard ; Claude ne le lit pas nativement ; cible ~150–200 lignes |
| https://deepswe.datacurve.ai/blog/deepswe | Tâches originales, verifiers comportementaux, runner fixe ; SWE-bench Pro 32 % désaccords judge/verifier |
| https://www.anthropic.com/engineering/multi-agent-research-system | Multi-agent +90.2 % sur eval *recherche* ; ~15× tokens vs chat ; coding peu parallèle |
| https://rdi.berkeley.edu/blog/trustworthy-benchmarks-cont/ | 8 benches exploitables à ~100 % sans résoudre ; checklist : isoler évaluteur, null agent, state-tampering |
| https://github.com/cursor/plugins/blob/main//README.md |  = plugin Cursor de , 22 playbooks ; « I don't believe in planning » |
| https://cursor.com/blog/cursorbench | Evals privés depuis traces réelles ; public benches mal alignés / contaminés |
| https://www.anthropic.com/engineering/building-effective-agents | Workflows (chemin connu) vs agents (chemin ouvert) ; simplicité d'abord |
| https://arxiv.org/html/2602.11988v1 | ETH : AGENTS.md générés −succès, +20–23 % coût ; fichiers humains +4 % succès, +coût |
| https://developers.openai.com/api/docs/guides/agent-evals | Flywheel traces → graders → datasets, pas leaderboard public |
| https://agents.md/ | Standard AAIF / Linux Foundation ; 60k+ repos ; symlink de compat |
| https://github.com/tienedev/harnix | Nix module multi-harness (Claude + Pi) ; symlink store = `EROFS` sur settings |

Sources secondaires utiles (snippets search, page non extraite en entier) : https://aider.chat/docs/repomap.html (repo map) ; https://code.claude.com/docs/en/hooks (PreToolUse deny avant permission mode) ; https://github.com/microsoft/skills (symlinks multi-projet) ; https://lewisflude.com/blog/mcp-nix-blog-post (Nix MCP, copie forcée si le client n'honore pas le symlink) ; https://dev.to/fabibi/your-coding-agent-doesnt-need-better-prompts-it-needs-a-contract-572k (contract-first observable) ; https://github.com/ai-boost/awesome-harness-engineering (VSC-Bench, statewright) ; https://www.swebench.com/ ; https://arxiv.org/abs/2307.03172 (Lost in the Middle, Liu et al. 2023).

**Absence explicite :** aucun projet public nommé «  » / « population-stack » comme *harness comparatif d'agents*. Le mot «  » désigne un plugin Cursor réel. Le cadrage « population gelée de 23 scénarios pour comparer deux harness » est interne à etabli. Aucun équivalent publié d'un *contrat PLAN.md READY + check-freeze partagé Pi/Claude* n'apparaît dans les résultats ; les plus proches sont hooks Claude, permissions harnix, et state machines type statewright.

Vault (obvault, `content_trust: untrusted-retrieved-content`) : `kb/evaluator-optimizer-needs-executable-oracle.md`, `kb/synthesis-agent-evals-and-verification.md`, `kb/agent-evaluation-as-a-layered-production-system.md`, `kb/workflow-engineering-over-unconstrained-react.md`, `kb/etabli-self-improvement-harness-contract.md`. Traité comme mémoire, pas comme preuve.

---

## 1. Contrat unique + guards mécaniques

**Verdict : garder les guards ; ne pas traiter le contrat-prose comme l'architecture.** Pour un opérateur solo multi-harness, *une* fonction de décision d'écriture partagée est la bonne couche. Un AGENTS.md seul est insuffisant. Un spec + details + 24 skills + scaffold recopié dans chaque projet est trop de texte always-on.

### Rationale

- **Evidence (repo).** `planMutationGuardDecision` compose READY, check-freeze et `no_progress` (`claude/hooks/workflow-router-lib.mjs:1252-1258`) et est consommé par Claude PreToolUse (`claude/hooks/plan-ready-guard.mjs`) et Pi `tool_call` (`pi/extensions/workflow-router.ts:106`). ADR-0007 + ADR-0014 : le classifier reste, l'injection de route a été retirée (~301 tok/tour mesurés, ADR-0014). `AGENTS.md` local = 103 lignes ; `CLAUDE.md` = 31 ; `workflow/spec.md` = 191 ; `workflow/contract-details.md` = 317 ; skills workflow = 24 fichiers. Le quick card autorise déjà le coding ordinaire sans PLAN (`workflow/agent-quick-card.md:21-25`).
- **Evidence (web).** AGENTS.md est le standard AAIF, lu par 25+ outils, pas par Claude nativement — le pattern officiel est `@AGENTS.md` ou symlink (`https://agents.md/`, InventiveHQ). Claude documente ~200 lignes ; Codex cappe à 32 KiB. ETH Zurich (Gloaguen et al., arXiv 2602.11988) : fichiers générés *baissent* le succès (−0.5 % SWE-bench Lite, −2 % AGENTbench) et *montent* le coût (+20 % / +23 %) ; fichiers humains +~4 % succès mais +coût (jusqu'à 19 %) et +raisonnement (GPT-5.2 +20 % tokens de thinking). Les agents *suivent* les instructions — l'échec n'est pas de l'ignorance, c'est que des exigences inutiles rendent la tâche plus dure. Lost-in-the-middle (Liu et al. 2023) + tickets Claude Code (#7777, #17530) : la prose au milieu disparaît ; les hooks PreToolUse deny *avant* le permission mode (`https://code.claude.com/docs/en/hooks`).
- **Inference.** Le différentiel utile d'etabli vs « un AGENTS.md » n'est pas le volume de markdown, c'est le *deny mécanique* pré-READY / freeze / no_progress. ADR-0014 l'a déjà compris pour l'injection. La direction actuelle continue pourtant d'empiler de la prose (scaffold `deploy-workflow` FILES ~30 + toutes les skills) que chaque cellule et chaque projet paie.
- **Opinion.** Pour un solo, le contrat unique est justifié. La sur-ingénierie commence au moment où le rituel (PLAN obligatoire, adversary, hunters) est traité comme ambient au même titre que les guards. Spec ligne 135 dit le contraire (« ordinary coding → answer ») ; le reste du repo se comporte encore comme si plan-implement était le défaut moral.

**Sources :** ADR-0006, ADR-0007, ADR-0014 ; `workflow/spec.md:37-43,94-97,135` ; ETH 2602.11988 ; agents.md ; InventiveHQ ; Claude hooks docs.

**Statut :** architecture des guards **verified** dans le code ; coût token du contrat always-on etabli **not verified** (pas de mesure de session 2026-08-23) — on s'appuie sur ADR-0014 + ETH.

---

## 2. Suite d'éval maison (8 tâches, oracles, floors)

**Verdict : méthodologiquement défendable comme *régression de harness*, indéfendable comme preuve que le harness « discrimine ». Ne pas migrer vers SWE-bench / Terminal-Bench.**

### Rationale

- **Evidence (repo).** `docs/harness-eval.md` publie à `7484b59` : null **1/8** (seul `plan-draft-no-mutate` passe, l'abstention est correcte), constant **6/8** (transcript fabriqué `Verdict: BLOCK`, `scripts/lib/etabli-harness-eval.sh:531-552`). Tous les oracles pinent HEAD hors worktree (`harness_write_baseline` / `harness_require_head_unchanged`, L138-151). Les deux cellules load-bearing sont `ready-implement-touches-only-plan-files` (SHA d'état) et `review-go-clean-diff` (contrôle positif GO-only). Les six autres exigent encore des sous-chaînes de transcript (`hunter-read-only/oracle.sh:12-24`, `review-spec-drift/oracle.sh:10-16`). La suite *ne* tourne *pas* DeepSWE et *ne* revendique *pas* ses scores — c'est écrit.
- **Evidence (web).** L'industrie évite le gaming ainsi : (1) **outcome ≠ transcript** (Anthropic evals) ; (2) **isoler l'évaluateur** du container agent (Berkeley RDI : pytest hook / `conftest.py` = 100 % SWE-bench ; curl trojan = 100 % Terminal-Bench) ; (3) **null + exploit/constant agents** comme floors (Berkeley checklist) ; (4) **tâches originales + verifiers comportementaux + runner fixe** (DeepSWE) ; (5) **sceller git + egress** sur les benches historiques (Cursor, juin 2026 : 63 % lookup) ; (6) **evals privés depuis traces** (CursorBench) plutôt que leaderboards saturés. OpenAI a arrêté de reporter SWE-bench Verified après ~59 % de tests défectueux. DeepSWE trouve 32 % de désaccords judge/verifier sur SWE-bench Pro.
- **Inference.** Etabli a fait la moitié juste de Berkeley : floors publiés, HEAD pin, SHA sur quelques fichiers. Il n'a pas fait l'autre moitié : l'évaluateur lit encore le transcript que le sujet rédige. Un constant policy à 6/8 signifie que *le score d'une cellule review n'est pas une mesure de review*. Publier le floor est honnête ; s'en servir comme « 8 tâches gelées donc le harness est évalué » serait une fraude de construct.
- **Opinion.** Remplacer cette suite par Terminal-Bench ou SWE-bench serait une régression de *question de recherche*. Ces benches mesurent « le modèle + un harness générique sur des issues GitHub / puzzles shell ». Etabli a besoin de « l'agent a-t-il respecté READY / isolation / freeze *dans ce contrat* ». Cursor le dit clairement : SWE et Terminal-Bench sont mal alignés sur le travail réel. La bonne évolution est CursorBlame-style : traces etabli → cellules *état*, pas plus de grep de `Verdict:`.

**Sources :** `docs/harness-eval.md` ; oracles sous `tests/fixtures/harness-v1/tasks/` ; Cursor reward-hacking ; Berkeley RDI ; DeepSWE ; Anthropic evals ; CursorBench ; OpenAI agent-evals.

**Statut :** floors 1/8 et 6/8 **verified** dans le doc et le code du constant transcript ; je n'ai **not verified** en relançant `null-baseline` / `constant-baseline` dans cette session. Gaming live des oracles par un vrai modèle : **not verified**.

---

## 3. Multi-harness par symlinks + catalog TSV

**Verdict : viable pour un solo Mac ; fragile par *reconcilers multiples*, pas par le principe symlink. Ne pas migrer vers Nix par principe.**

### Rationale

- **Evidence (repo).** Une source liée dans `~/.claude/workflow`, `~/.pi/agent/workflow`, `~/.agents/workflow` (`docs/how-it-works.md:14-18`). Catalogue `workflow/runtime/skill-surface.tsv` : 96 lignes, flags `pi_core` / `agents_visible` / `locked`. Trois programmes touchent les mêmes liens : `scripts/install.sh` → `scripts/lib/install-main.sh` (refuse de pruner si `pi_core` ou `agents_visible` vide, L430-460), `scripts/deploy-agent-workflow` (688 lignes, prune sans sentinel équivalent si la keep-list `agents_visible` est vide, L513-530), `scripts/check-fix-symlinks.sh` (478 lignes, sentinel `pi_core` vide seulement, L23-25). `deploy-workflow` copie ~30 fichiers + toutes les skills dans chaque projet (ADR-0005, `scripts/deploy-workflow:21-56`). MCP : inventaire sanitizé, config live *non* symlinkée (`docs/mcp-strategy.md`).
- **Evidence (web).** Le pattern « un fichier, des liens » est le conseil officiel AGENTS.md et le cookbook Microsoft skills (`ln -s` multi-projet / multi-harness). wshobson/agents : `CLAUDE.md` symlink vers `AGENTS.md`. i9wa4/dotfiles et Kyure-A/agent-skills-nix : pipeline Nix → symlink-trees Claude/Codex. harnix (2026) déclare Claude + Pi + `~/.agents/skills` en Nix — et documente que le symlink store casse `/effort` / `/config` (`EROFS`) ; il faut `mutable = true`. Lewis Flude : certains clients MCP exigent une *copie* réelle. Dotbot reste le gestionnaire de symlink le plus simple.
- **Inference.** Le risque n'est pas « les symlinks cassent ». C'est « trois scripts peuvent converger vers des keep-lists différentes, et un desired-set vide signifie encore “tout supprimer” d'un côté ». Nix achète la reproductibilité multi-machine au prix d'une plateforme et d'une guerre avec les CLIs qui *écrivent* leurs settings. Pour un opérateur, un Mac, un repo git, le bénéfice Nix est faible.
- **Opinion.** Garder Git + TSV + symlink. Fusionner deployer et fixer en *un* reconciler fail-closed. Sortir `evidence-proof` / `program-state` / `workflow-event` du scaffold projet (C5 de l'agrégat : ces copies ne sont pas de la distillation, c'est de la charge).

**Sources :** `skill-surface.tsv` ; `deploy-agent-workflow` ; `install-main.sh:430-460` ; agents.md ; microsoft/skills ; harnix ; Lewis Flude ; Dotbot.

**Statut :** asymétrie des sentinels prune **verified** par lecture ; casse réelle d'une keep-list vide en prod **not verified**.

---

## 4. Le rituel (plan → adversary → implement → hunters → adversary)

**Verdict : aligné comme *workflow optionnel* pour le travail risqué ; mal aligné comme taxonomie par défaut. Les evals maison ne battent un bon système de tests que sur le comportement de harness, jamais sur le produit.**

### Rationale

- **Evidence (repo).** `/plan-implement` enchaîne 8 phases dont *deux* adversary cross-model (`docs/how-it-works.md:58-98`). Le substitut accepté est un double-sample same-family ; un seul passage same-family est `blocked` (`workflow/skills/adversary.md:55-61`). Ordinary coding *sans* PLAN est route `answer` (`workflow/spec.md:135`). ADR-0013 a tué le council multi-modèle. ADR-0014 a tué l'injection de route. Le golden principle « 3e occurrence d'un finding → check mécanique » est déjà dans spec L107-108.
- **Evidence (web).** Anthropic (2024, toujours cité en 2026) : *workflows* quand le chemin est connu, *agents* quand il ne l'est pas ; « add complexity only when it demonstrably improves outcomes ». Anthropic Research : multi-agent +90.2 % sur *recherche parallèle*, ~15× tokens vs chat, et *« most coding tasks involve fewer truly parallelizable tasks »*. Token spend explique ~80 % de la variance BrowseComp — plus d'agents = plus de tokens, pas une magie d'architecture.  (, Cursor) : playbooks + preuves runtime, et explicitement *« I don't believe in planning. the best spec is code. »* ETH : plus d'instructions suivies = plus de tests *et* plus de coût, pas plus de succès. Lost-in-the-middle : un rituel long dans le prompt n'est pas un rituel exécuté.
- **Inference.** Etabli a choisi le bon *type* (workflow à gates, pas un swarm) et la mauvaise *fréquence* (le full-auto 8 phases est le récit identitaire). Cross-model adversary a une justification d'indépendance, pas de couverture : c'est un vote, pas un oracle. Le payer deux fois par changement, plus hunters, plus review lead, plus archive, est un multiplicateur de tokens du même ordre que ce qu'Anthropic réserve à la recherche high-value. Pour un bug d'une cellule, le rituel est plus cher que le bug.
- **Opinion.** Evals-as-guardrails *battent* les tests produit sur une classe étroite : « l'agent a-t-il écrit hors READY », « le hunter a-t-il muté », « le freeze a-t-il tenu ». Elles *perdent* dès qu'on leur demande de remplacer `bun test` / un SHA de fichier produit. L'agrégat de branche a raison sur C10 : hunters = mécanisme réel (spawn argv), preuve encore théâtrale (chaînes que le parent écrit et que l'oracle greppe).

**Sources :** `docs/how-it-works.md:58-98` ; Anthropic building-effective-agents + multi-agent-research-system ;  README ; ETH 2602.11988 ; vault `workflow-engineering-over-unconstrained-react` (untrusted).

**Statut :** coût réel d'un `/plan-implement` etabli en tokens/USD **not verified**. Alignement conceptuel workflow-vs-agent **verified** sur les sources Anthropic.

---

## 5.  / 

**Verdict : tuer la comparaison live comme objectif de direction ; garder le pin structurel comme calibration cheap.**

### Rationale

- **Evidence (web).**  *existe* : plugin Cursor `github.com/cursor/plugins` / ``, auteur , v0.14.1 pin etabli `fd6dd6f`. Ce n'est pas un harness comparatif. C'est un *mode* + 22 playbooks + 21 principles, portable Claude via des forks (`-claude`). Aucun résultat web pour « population-stack » comme banc d'agents. L'écosystème mesure autrement : CursorBench (traces privées + online), DeepSWE (tâches originales, runner fixe), Harbor/Terminal-Bench (shell), VSC-Bench (Copilot), flywheel traces OpenAI. Cursor refuse de traiter SWE-bench Pro standard comme chiffre Composer précisément *parce que* le harness fuit.
- **Evidence (repo).** Structural : 23/23 VERIFIED, 0 skill ajouté (`workflow//results/-0.14.1-structural.json`). Live : `BLOCKED`, 0/138 runs, pas de budget, pas d'évaluateur isolé, `comparison.verdict = INCONCLUSIVE`, `not_established` (`-live-ingest-gate.json`, `live-blocked.json`, README). La règle de dominance (23/23 AHEAD + 138 runs) est un appareil mécanique honnête et *inéxécutable* aux tarifs frontier. Distillation déjà extraite : reply shapes + hillclimb → `workflow/answer-quality.md`. Residual risk #1 : live waived comme stop de goal (2026-07-23).
- **Inference.** Continuer  live, c'est optimiser un comparatif dont le seuil d'admission (138 cellules sealed, juge indépendant, pas de drift de checkout) coûte plus que l'information qu'il peut encore donner. Le structural run a déjà répondu à la seule question cheap : « notre surface route-t-elle les 23 situations sans ajouter de skills ? » Oui. La question live (« on est AHEAD de  ») n'est pas une question d'opérateur solo, c'est une question de vendor.
- **Opinion.** L'écosystème, sans budget infini, fait : (1) floors offline (etabli les a), (2) 5–20 cellules *privées* issues de vraies sessions, state-graded, (3) 1 canary live rare et budgeté, (4) online proxies (l'opérateur sent-il une régression). Pas 138 runs contre le playbook d'un autre. **Continuer le pin ; arrêter de construire de l'identité autour du live .**

**Sources :**  README ; `workflow//results/-0.14.1-structural.json` ; `-live-ingest-gate.json` ; CursorBench ; Cursor reward-hacking ; DeepSWE limitations (mini-swe-agent ≠ harness natif).

**Statut :** existence et pin  **verified** ; superiorité comportementale etabli vs  **not_established** (le repo le dit). Recherche web « population-stack » : **aucun précédent public**.

---

## 6. Trois à changer, trois à garder

### Changer

1. **Compresser la surface always-on ; réserver le rituel aux routes explicites / risquées.** Garder `planMutationGuardDecision`. Couper ce que chaque session *lit* : `contract-details.md` n'est pas un prompt ; `deploy-workflow` ne doit pas recopier evidence-proof / program-state / 24 skills dans un repo applicatif. Ordinary coding = `answer`. `/plan-implement` = opt-in. Un adversary cross-model, pas deux, sauf ship / secrets / harness. *Evidence :* ETH +20 % coût, ADR-0014, spec:135,  anti-planning. *Opinion :* c'est le levier tokens le plus large.

2. **Ne compter comme éval que les cellules à état isolé.** Promouvoir `ready-implement` et `review-go-clean-diff` en *seules* cellules publiables pour un `pass@1`. Les 6 cellules transcript-grep deviennent des lints de format, pas des scores. Isoler l'oracle hors du worktree (Berkeley). Nourrir de nouvelles cellules depuis les traces réelles (CursorBench), pas depuis SWE-bench. *Evidence :* constant 6/8, oracles L12-24 hunter, DeepSWE vs SWE-bench Pro. *Not verified :* je n'ai pas rejoué les baselines.

3. **Un reconciler fail-closed ; abandonner  live comme direction.** Fusionner `deploy-agent-workflow` + `check-fix-symlinks` + prune installer. Desired-set vide = refuse, partout (aujourd'hui `install-main` le fait, le deployer agents_visible non). Garder le pin structurel 23/23. Ne plus parler de 138 runs. *Evidence :* 688+478 lignes, prune asymétrique, live 0/138, CursorBench.

### Garder

1. **Le guard d'écriture partagé fail-closed** (READY / freeze / `no_progress`) — c'est le seul artefact qu'un AGENTS.md ne peut pas remplacer. Hooks > prose. **verified** dans le code.

2. **L'honnêteté épistémique des floors et des lives bloqués.** Publier null 1/8 + constant 6/8, refuser de teindre un skip en succès, `not_established` sur  : c'est plus rare et plus précieux que la plupart des harness publics. **verified** à `7484b59`.

3. **Source unique + adapters minces + split exécution/mémoire.** ADR-0006 / ADR-0011 / ADR-0017 : un contrat, Pi+Claude adapters, Codex/Grok en surface de liens, obvault hors du plan. C'est la raison d'être d'un repo solo multi-harness. **verified** comme décision ; la *propagation* (classifier vs spec, scaffold vs distillation) reste le talon.

---

## Score de confiance

**0.74**

Pourquoi pas plus : pas de run live ; pas de rejeu local `null-baseline`/`constant-baseline` dans cette session ; pas de mesure tokens d'un `/plan-implement` réel ; ETH et Cursor sont des labs avec d'autres distributions de tâches ; le pack obvault est lexical et borné. Pourquoi pas moins : HEAD lu, oracles et floors lus au code, ADRs et tailles de contrat mesurés (`wc -l`), sources primaires extraites (pas seulement des snippets), et l'absence de «  comparatif » est une donnée, pas un oubli.

**Inconclusif / non vérifié (parking) :** classifier `ordinary coding → answer` vs fixtures router (C6 agrégat, HEAD agrégat `a8c28f8`, non relu ligne à ligne ici) ; casse prune deployer en conditions dégénérées ; sentinel hunter vs `review.md` (C3) à `7484b59` ; secret/multihost ; lane-3 ~3600 lignes.

---

## Validation

- Checks: `scripts/research-proof-check direction-4.md` ; `scripts/answer-quality-check --mode research direction-4.md` (à lancer après écriture).
- Local paths cités : `7484b59`, `workflow/spec.md:135`, `claude/hooks/workflow-router-lib.mjs:1252`, `scripts/lib/etabli-harness-eval.sh:531-552`, `docs/harness-eval.md`.
- Remaining risks : floors non rejoués ici ; pas de live ; ETH n'évalue pas un contrat à hooks.
- Confidence labels used : verified, not verified, not_established, inconclusive, assumption (aucune).
