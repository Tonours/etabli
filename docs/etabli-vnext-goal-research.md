> Historical snapshot (2026-07-23). Not operational. Canonical: workflow/spec.md + scripts/-suite

# Etabli  — du contrôle procédural à l’efficacité prouvée

Status: **verified** pour l’état local observé le 2026-07-23, **confirmed** pour les principes soutenus par plusieurs sources, **approximate** pour leur transfert à Etabli tant qu’un benchmark local ne l’a pas mesuré, **not verified** pour toute promesse de « perfection ».

## Décision

Etabli n’a pas besoin d’une nouvelle couche d’orchestration générale. Il est déjà un bon **control plane local, multi-harness, evidence-first**. Son prochain saut de qualité doit être un **eval plane outcome-first** : mesurer des tâches réelles, la fiabilité répétée, la sécurité et le coût par résultat vérifié, puis n’accepter que les changements qui améliorent ce profil sans régression held-out.

« Parfait » doit donc signifier ici : **les propriétés importantes sont explicites, testables, comparées à un baseline, et les inconnues restent visibles**. Cela ne signifie ni absence garantie de défaut, ni score global artificiel.

## Direction réelle du projet

### Ce qu’Etabli est

- Un environnement personnel de développement assisté par IA pour Pi, Claude, Codex, Neovim et les outils de terminal (`README.md:3`).
- Un contrat de workflow partagé où la plus petite route suffisante doit finir avec des preuves (`workflow/spec.md:27`).
- Un système local-first avec un seul artefact d’exécution actif, `PLAN.md` (`workflow/spec.md:81`).
- Un harness qui sépare l’exécution Etabli de la mémoire durable obvault.
- Un système volontairement prudent : un seul writer, gates `READY`, ledgers append-only, checks mécaniques et write-back externe explicitement autorisé.

### Ce qu’Etabli ne devrait pas devenir sans nouvelle preuve

- Un framework générique d’agents ou un SaaS.
- Un swarm permanent : le benchmark aveugle local a déjà rejeté les panels systématiques après quatre dépassements de latence sur six sans gain de qualité (`workflow/skills/multi-model-orchestration.md:5-7`).
- Un système auto-modifiant qui applique ses propres recommandations sans revue.
- Un dashboard, une mémoire vectorielle ou une « skill factory » ajoutés parce qu’ils semblent modernes.
- Une collection croissante de règles textuelles qui n’améliorent aucun outcome.

## Baseline local observé

| Surface | État | Preuve | Confiance |
| --- | --- | --- | --- |
| Contrat, routing, permission gates | Solide et largement mécanisé | 32 cas du routeur, 11 scénarios déterministes; `tests/router-evals/core.json`, `tests/agent-scenarios/` | **verified** |
| Régression documentaire et infrastructure | Large couverture déterministe | 42 suites shell recensées par `scripts/workflow-efficiency-report --json`; manifeste `workflow/runtime/agentic-infra-checks.tsv` | **verified** |
| Budget de contexte toujours chargé | Déjà bien optimisé | 1 887 tokens estimés sur 9 455, sous la cible stretch, via `scripts/workflow-efficiency-report --json` | **verified** |
| Mémoire et retrieval | Bounded, cité, local-first | obvault `context --max-tokens 2500`; résultats avec statut/fraîcheur/provenance | **verified**, mais la santé globale du vault est actuellement **degraded** par un dossier top-level `.pi` non autorisé |
| Evals d’output | Plancher utile, pas qualité réelle | 10 fixtures answer-quality; le dossier dit explicitement que la qualité live et la satisfaction ne sont pas vérifiées (`docs/answer-quality-eval-cases.md:71-72`) | **verified** |
| Evals multi-modèles | Méthodologie saine, corpus minuscule | 3 fixtures (`tests/multi-model-quality-score-smoke.sh:9-23`) | **verified** |
| Evals live cross-runtime | Présentes mais opt-in | `RUN_REAL_AGENT_SCENARIOS=1`; le script sort sinon immédiatement (`tests/workflow-real-agent-scenarios.sh:13-14`) | **verified** |
| CI canonique | Vérifie surtout le déterminisme du harness | Le manifeste inclut le smoke CLI, mais celui-ci skippe sans `RUN_AGENT_CLI_SMOKE=1` (`tests/workflow-cli-smoke.sh:54-55`); le scénario live complet n’est pas dans le manifeste | **verified** |
| Santé canonique au 2026-07-23 | Baseline actuellement rouge sur la fraîcheur des capacités | `scripts/verify-agentic-infra all` passe les groupes précédents puis bloque dans `runtime-capabilities-smoke`: `pi.supports_goal_state` et `codex.supports_hooks` sont expirés | **verified**, à re-prouver ou relabeller `unknown`; ne jamais rafraîchir une date seule |
| Télémétrie | Bonne couverture de consommation, sémantique d’outcome faible | 41 runs terminaux, 39 outcomes marqués succès, 38 mesurés, 8 318 058,58 tokens par succès mesuré; seulement 1 candidat harness validé sur 2, via `scripts/workflow-metrics --json` | **verified** pour le scope de l’agrégateur; **not verified** comme productivité ou valeur utilisateur |
| Sécurité agentique | Bonnes barrières ponctuelles, pas de matrice adversariale générale | Redaction, gates `READY`, ops-stop, trust label obvault; aucune suite canonique large trouvée pour injection indirecte, tool-result hostile, memory poisoning ou privilege escalation | **verified** pour l’inventaire, **approximate** pour le risque résiduel |
| Maintenabilité | Instructions minces, quelques hotspots de code | Analyse locale : callback principal de `pi/extensions/filter-output.ts:229` et guards de `pi/extensions/workflow-router.ts:71-192` à revalider avant refactor | **approximate**; la complexité seule n’autorise pas une réécriture |

### Lecture critique de la métrique actuelle

`tokens_per_successful_outcome` est utile pour compter la consommation selon le contrat actuel, mais la plupart des outcomes historiques signifient « le run s’est déclaré terminé avec ses checks » et non « un utilisateur a accompli une tâche plus vite ou mieux ». Les imports historiques couvrent la fenêtre de session principale et peuvent omettre les sidecars. Cette métrique ne doit donc pas être convertie en coût économique ou productivité sans un grader de tâche et un protocole comparatif.

## Résultats de recherche applicables

### 1. Évaluer l’état final, pas seulement la conformité du trajet

Anthropic distingue le transcript, l’outcome réel et le harness d’évaluation. Un agent peut dire qu’une action est terminée alors que l’état externe ne l’est pas. Les evals matures combinent graders déterministes, graders modèle calibrés et revue humaine; elles séparent capability evals et regression evals, utilisent des environnements isolés et commencent utilement avec 20 à 50 tâches réelles [Anthropic, *Demystifying evals for AI agents*](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents).

OpenAI propose pour les skills une boucle très proche du besoin Etabli : prompt → trace + artefacts → petits checks → score comparable, avec objectifs d’outcome, de process, de style et d’efficacité; 10 à 20 prompts ciblés suffisent pour un premier signal [OpenAI, *Testing Agent Skills Systematically with Evals*](https://developers.openai.com/blog/eval-skills).

**Implication Etabli — confirmed:** construire un corpus représentatif qui exécute réellement les routes et grade l’état final. Les tests de chaînes et de schéma restent des regressions, pas une preuve d’efficacité.

### 2. Mesurer la fiabilité répétée et garder des tâches fraîches

`τ-bench` vérifie l’état final d’une base après interaction et introduit `pass^k`, qui mesure la probabilité que toutes les répétitions réussissent. Les agents étudiés pouvaient avoir un pass@1 acceptable mais une forte inconsistance [Yao et al., 2024](https://arxiv.org/abs/2406.12045).

SWE-bench-Live montre pourquoi un corpus statique peut surévaluer le progrès : tâches fraîches, environnements reproductibles et couverture plus diverse donnent des performances inférieures au benchmark statique dans leur étude [Zhang et al., 2025](https://arxiv.org/abs/2505.23419).

**Implication Etabli — confirmed:** garder un split sealed/held-out, faire plusieurs répétitions sur le sous-ensemble non déterministe, versionner la population et renouveler une petite partie du corpus à partir de vrais échecs.

### 3. Traiter le contexte comme un budget d’attention

Les modèles n’utilisent pas uniformément les longs contextes; l’information au milieu peut être nettement moins bien exploitée [Liu et al., TACL, *Lost in the Middle*](https://arxiv.org/abs/2307.03172). Anthropic recommande le plus petit ensemble de tokens à fort signal, le retrieval just-in-time, la progressive disclosure, la compaction et les notes structurées [Anthropic, *Effective context engineering for AI agents*](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents).

**Implication Etabli — confirmed:** le budget d’instructions est déjà bon; le prochain test doit porter sur la **qualité du contexte effectivement chargé** par route : pertinence, fraîcheur, bruit, appels inutiles et effet sur le succès.

### 4. Considérer les tools comme une ACI à tester

SWE-agent montre que l’Agent-Computer Interface change fortement la performance sans changer les poids du modèle [Yang et al., 2024](https://arxiv.org/abs/2405.15793). Anthropic recommande des tools distincts, des paramètres non ambigus, des réponses à fort signal, des erreurs réparables et des held-out evals [Anthropic, *Writing effective tools for AI agents*](https://www.anthropic.com/engineering/writing-tools-for-agents). ToolSandbox révèle notamment les échecs sur dépendances d’état, informations insuffisantes, outils distracteurs et schémas dégradés [Lu et al., 2024](https://arxiv.org/abs/2408.04682).

**Implication Etabli — confirmed:** évaluer la sélection de tool, l’usage correct des paramètres, l’abstention/clarification, le nombre d’appels, les erreurs et les fichiers superflus. Refactorer une interface seulement après un échec reproduit.

### 5. Mettre la sécurité dans le host et dans les evals

AgentDojo évalue séparément benign utility, utility under attack et targeted attack success rate dans un environnement stateful avec données de tools non fiables [Debenedetti et al., 2024](https://arxiv.org/abs/2406.13352). CaMeL illustre une défense architecturale : séparer control flow et data flow, puis appliquer des capabilities au moment des appels de tools [Debenedetti et al., 2025](https://arxiv.org/abs/2503.18813).

Les recommandations MCP couvrent consentement, token audience, SSRF, sessions, serveurs locaux et scope minimization [MCP Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices). Le [NIST AI 600-1](https://doi.org/10.6028/NIST.AI.600-1) fournit le cadre de gestion des risques sur tout le cycle de vie. L’[OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) ajoute goal hijacking, tool misuse, identity/privilege abuse, supply chain, code execution, memory poisoning, communications inter-agents, cascading failures, trust exploitation et rogue agents.

**Implication Etabli — confirmed:** « treat as untrusted » dans un prompt est nécessaire mais insuffisant. Les cas critiques doivent échouer mécaniquement au niveau host/tool boundary et être rejoués comme adversarial evals.

### 6. Optimiser un front de Pareto, pas un modèle ou un score unique

RouteLLM formalise la sélection modèle comme compromis qualité/coût et rapporte plus de 2× d’économie sur ses benchmarks sans perte substantielle de qualité [Ong et al., 2024](https://arxiv.org/abs/2406.18665). Anthropic rapporte que son système de recherche multi-agent utilise environ 15× les tokens d’un chat et n’est économiquement pertinent que sur des tâches dont la valeur justifie le gain; les tâches très interdépendantes, dont beaucoup de tâches de code, sont de moins bons candidats [Anthropic, *How we built our multi-agent research system*](https://www.anthropic.com/engineering/multi-agent-research-system).

Le RCT METR sur 16 développeurs expérimentés et 246 issues a observé un ralentissement de 19 % avec les outils early-2025 alors que les participants croyaient avoir accéléré de 20 %; le transfert hors de ce cadre reste limité [METR, 2025](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/). METR propose aussi la durée humaine d’une tâche comme axe interprétable de capacité long-horizon [METR, *Measuring AI Ability to Complete Long Tasks*](https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/).

**Implication Etabli — confirmed:** mesurer tokens, temps, tool calls et coût **par tâche vérifiée**, puis comparer les stratégies sur un front qualité–fiabilité–latence–coût. Ne pas extrapoler le résultat METR à Etabli sans expérience locale.

### 7. Réévaluer et supprimer les hypothèses devenues obsolètes

Anthropic rapporte que certaines compensations de harness utiles à un modèle sont devenues du poids mort sur un modèle ultérieur; leur architecture sépare session durable, harness et sandbox pour pouvoir les remplacer indépendamment [Anthropic, *Scaling Managed Agents*](https://www.anthropic.com/engineering/managed-agents).

**Implication Etabli — approximate:** ajouter un budget de suppression : chaque règle, route ou abstraction ancienne doit survivre à un benchmark ou être simplifiée. Le bon mouvement n’est pas toujours d’ajouter.

## Matrice des écarts et priorités

| Priorité | Écart | Gate recherché | Pourquoi maintenant | Confiance |
| --- | --- | --- | --- | --- |
| P0 | Pas de benchmark end-to-end représentatif et canonique | Corpus initial ≥24 cas couvrant routes critiques, positifs, négatifs et adversariaux; ≥25 % sealed held-out; graders d’état final | Sans lui, aucun gain global n’est falsifiable | **confirmed** |
| P0 | Outcomes historiques trop proches de « run terminé » | Chaque essai lie task id, verifier result, pass/fail, tokens, tool calls, durée et provenance; aucune réussite sans grader | La télémétrie existe déjà, il faut améliorer sa sémantique | **confirmed** |
| P0 | Sécurité agentique non évaluée de bout en bout | Matrice host-level pour goal hijack, tool-result hostile, scope expansion, secret access, external write, skill/supply-chain et memory poisoning; benign utility et ASR séparés | Le blast radius croît avec les tools et l’autonomie | **confirmed** |
| P1 | Context/ACI non mesurés par outcome | Tests de mauvais tool, tool distracteur, information insuffisante, erreur réparable, retrieval stale/wrong, signal par token | Les interfaces peuvent apporter plus qu’un changement de modèle | **confirmed** |
| P1 | Long-horizon surtout validé par schémas | Scénarios de resume après context reset/crash, replay du ledger, no-progress et handoff; horizons de tâche nommés | Les ledgers sont un bon socle mais leur utilité live reste peu testée | **confirmed** |
| P1 | Complexité et documentation peuvent croître sans bénéfice | Chaque ajout transverse montre un gain eval; chaque cycle examine suppression/déduplication; aucune réécriture fondée sur la taille seule | Préserve la simplicité qui fait déjà la force du projet | **approximate** |
| P2 | UX publique/dashboard/distribution | Seulement après friction utilisateur reproduite et surface de validation | Etabli reste d’abord un outil personnel | **not verified** comme besoin actuel |

## Scorecard recommandé

Ne pas produire une moyenne globale. Publier un vecteur par suite et par stratégie :

1. **Task success:** pass@1 et compte exact par catégorie.
2. **Reliability:** pass^3 sur le sous-ensemble live non déterministe.
3. **Safety:** benign utility, utility under attack, targeted ASR, violations de permission.
4. **Efficiency:** tokens, tool calls, durée et coût par succès vérifié; thrashing et retries.
5. **Context/ACI:** bon tool, bon paramètre, clarification/abstention, retrieval pertinent, bruit chargé.
6. **Regression:** suite déterministe existante à 100 %.
7. **Portability:** Pi/Claude/Codex seulement sur les capacités réellement prouvées et non expirées.
8. **Maintainability:** lignes/règles ajoutées ou supprimées, duplication, complexité seulement comme signaux secondaires.
9. **Human value:** temps humain ou note de replay sur un petit échantillon, sans extrapolation statistique abusive.

Un candidat est accepté uniquement si :

- baseline et candidat utilisent la même population, le même environnement et la même configuration;
- il améliore strictement le signal held-in visé ou ferme un gap P0 déterministe;
- il ne régresse pas sur held-out, sécurité et regressions existantes;
- son coût se situe sur le front de Pareto ou son surcoût est explicitement justifié par un gain répété;
- les résultats négatifs restent enregistrés;
- les seuils et graders ont été gelés avant la modification et ne sont pas affaiblis ensuite.

## Goal prompt prêt à utiliser

Prompt:

```text
/goal Dans /Volumes/Crucial/work/etabli, amène Etabli à un état «  prouvé » : son efficacité réelle, sa fiabilité, sa sûreté et son coût doivent être évalués par un benchmark local représentatif et reproductible, puis toute modification du harness doit être acceptée uniquement si elle améliore un outcome vérifié sans régression held-out. Commence par lire AGENTS.md, workflow/spec.md, workflow/skills/self-improvement-loop.md et docs/etabli--goal-research.md, inspecter le HEAD/worktree courant, créer le ledger autonome requis et établir le baseline avant toute mutation. Pour tout claim de capacité expiré, exécute sa `proof_command` ou relabelle-le `unknown`; ne rafraîchis jamais seulement sa date. Utilise la route plan-implement avec le seul PLAN.md racine; n’implémente qu’après Status: READY et adversary. Gèle d’abord une suite initiale d’au moins 24 tâches couvrant les routes critiques, cas positifs/négatifs, permissions, recherche/mémoire, tool use et adversarial security, avec au moins 25 % de cas sealed held-out et des graders d’état final; sur un sous-ensemble live d’au moins 6 tâches, exécute trois répétitions baseline/candidat et rapporte pass@1 et pass^3 uniquement si LIVE_EVAL_BUDGET_USD a été explicitement fourni et reste respecté. Lie chaque trial à task id, verifier result, tokens, tool calls, durée, stratégie, modèle/provenance et artefacts; ne compte jamais « run terminé » comme succès sans grader. Priorise dans cet ordre : (1) outcome eval harness et métriques par succès vérifié, (2) matrice de sécurité host-level couvrant injection indirecte/tool-result hostile, scope/permission, secrets, external write, skill/supply-chain et memory poisoning avec benign utility et ASR séparés, (3) evals de context/ACI, (4) resume/compaction/chaos long-horizon, (5) simplification des règles ou hotspots seulement quand un échec reproduit la justifie. Évalue au moins un candidat, mais n’impose pas un changement : accepte-le seulement avec amélioration held-in stricte ou fermeture d’un gap P0, zéro régression held-out/safety/canonical suite, et coût sur le front qualité–fiabilité–latence–tokens; sinon consigne le rejet. Préserve les changements utilisateur, les API/comportements utiles, le modèle local-first, le one-writer rule et la séparation Etabli/obvault. N’ajoute ni framework général, swarm permanent, dashboard, base vectorielle, auto-apply, provider/model change, secret access, commit, push, PR, deploy, production/billing write ou autre write-back externe sans autorisation explicite; n’écris pas dans obvault. Utilise au maximum 8 itérations de candidats; après deux échecs de la même hypothèse ou trois checks rouges sans nouveau diff, stoppe comme blocked avec les hypothèses éliminées. La goal n’est complete que lorsque la suite  et scripts/verify-agentic-infra all passent, les résultats baseline/candidat et risques restants sont inspectables, aucun gap P0 n’est silencieusement inconnu, une fresh-context review autorisée conclut GO, le plan implémenté est archivé sous docs/plan/, le PLAN.md racine est supprimé et git diff --check passe. Si le budget live, un verifier ou une capacité runtime indispensable manque, termine blocked avec preuves, tentatives, incertitude et l’entrée exacte requise; ne transforme jamais une preuve proxy en succès.
```

Why this is stronger:

- **Loop:** `/goal` convient parce que le chemin d’amélioration est incertain mais l’état final est falsifiable; il délègue la condition d’arrêt, avec un cap de huit candidats.
- **Outcome:** Etabli doit prouver des résultats de tâche, pas seulement la cohérence de ses contrats.
- **Evidence:** corpus gelé, graders d’état final, held-out, répétitions, pass@1/pass^3, sécurité et coût par succès.
- **Constraints:** one-writer, `PLAN.md` `READY`, aucune mutation externe ou auto-application, aucune baisse de sécurité.
- **Scope:** dépôt Etabli uniquement; obvault est read-only; pas de nouvelle plateforme générique.
- **Iteration:** une hypothèse mesurable à la fois, baseline/candidat sur population identique, rejet enregistré si le gate échoue.
- **Stop condition:** benchmark et suite canonique verts, review fraîche, archive et cleanup; sinon blocker explicite, jamais « parfait » par déclaration.

Assumptions:

- Etabli reste d’abord un control plane personnel, local-first et multi-harness.
- Les 24 cas constituent un corpus initial, pas une preuve statistique universelle.
- Les résultats de sources vendor et de preprints sont des hypothèses de design jusqu’à validation locale.
- `LIVE_EVAL_BUDGET_USD` vaut 0 tant qu’un montant n’est pas explicitement fourni.

Missing inputs:

- Un montant explicite pour `LIVE_EVAL_BUDGET_USD` est nécessaire avant de lancer les répétitions live payantes. Sans lui, le goal peut livrer les gates déterministes mais doit rester **blocked: live effectiveness not verified** pour la claim  complète.

## Validation de cet artefact

- `scripts/research-proof-check docs/etabli--goal-research.md`: **passed**.
- `scripts/answer-quality-check --mode research docs/etabli--goal-research.md`: **passed**.
- `scripts/answer-quality-check --mode repo docs/etabli--goal-research.md`: **passed**.
- `git diff --check`: **passed**.
- `lens_diagnostics mode=all` sur cet artefact: zéro erreur bloquante.
  Des advisories stylistiques `MD013` de longueur de ligne subsistent sur des
  liens et blocs de preuve.
- Le serveur Markdown LSP n’est pas disponible sur cette surface; ce check est **not verified**, et non assimilé à zéro diagnostic.
- `scripts/verify-agentic-infra all`: **failed** sur le baseline préexistant après tous les groupes précédents passés; `runtime-capabilities-smoke` exige de re-prouver ou relabeller `pi.supports_goal_state` et `codex.supports_hooks`. Ce dossier n’altère pas ces claims sans leurs preuves.

## Sources

### Sources locales

- `README.md:3-47`
- `workflow/spec.md:27-178`
- `workflow/skills/self-improvement-loop.md:31-105`
- `workflow/skills/multi-model-orchestration.md:5-61`
- `workflow/events.md:87-94`
- `workflow/runtime/agentic-infra-checks.tsv`
- `tests/router-evals/core.json`
- `tests/agent-scenarios/`
- `tests/workflow-real-agent-scenarios.sh:13-14`
- `tests/workflow-cli-smoke.sh:54-55`
- `tests/multi-model-quality-score-smoke.sh:9-23`
- `docs/answer-quality-eval-cases.md:64-74`
- Command evidence: `scripts/workflow-efficiency-report --json`
- Command evidence: `scripts/workflow-metrics --json`
- Command evidence: `scripts/workflow-retrospect --json`

### Sources externes primaires ou reconnues

- Anthropic, [Building Effective AI Agents](https://www.anthropic.com/engineering/building-effective-agents)
- Anthropic, [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- Anthropic, [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- Anthropic, [Writing effective tools for AI agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- Anthropic, [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- Anthropic, [Scaling Managed Agents](https://www.anthropic.com/engineering/managed-agents)
- OpenAI, [Testing Agent Skills Systematically with Evals](https://developers.openai.com/blog/eval-skills)
- Liu et al., [Lost in the Middle](https://arxiv.org/abs/2307.03172), TACL
- Yang et al., [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering](https://arxiv.org/abs/2405.15793)
- Yao et al., [`τ`-bench](https://arxiv.org/abs/2406.12045)
- Lu et al., [ToolSandbox](https://arxiv.org/abs/2408.04682)
- Debenedetti et al., [AgentDojo](https://arxiv.org/abs/2406.13352)
- Debenedetti et al., [Defeating Prompt Injections by Design / CaMeL](https://arxiv.org/abs/2503.18813)
- Zhang et al., [SWE-bench Goes Live](https://arxiv.org/abs/2505.23419)
- Ong et al., [RouteLLM](https://arxiv.org/abs/2406.18665)
- METR, [Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/)
- METR, [Measuring AI Ability to Complete Long Tasks](https://metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/)
- Model Context Protocol, [Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices)
- NIST, [AI RMF Generative AI Profile — NIST AI 600-1](https://doi.org/10.6028/NIST.AI.600-1)
- OWASP, [Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)

## Limites et risques restants

- **not verified:** aucune comparaison live baseline/candidat n’a été exécutée dans cette recherche; elle serait une dépense externe et nécessite un budget explicite.
- **approximate:** le corpus minimum de 24 cas est un point de départ cohérent avec les recommandations 10–20 et 20–50, pas un seuil scientifique universel.
- **inconclusive:** les chiffres de sources vendor ou de preprints ne prédisent pas le gain qu’obtiendra Etabli.
- **blocked outside scope:** la validation obvault signale actuellement le dossier top-level `.pi`; ce défaut de santé ne doit pas être réparé depuis Etabli sans une action obvault séparée.
- **blocked baseline:** la suite canonique Etabli exige une nouvelle preuve ou un relabelling honnête pour deux capacités expirées; une simple modification de date serait une fausse preuve.
- **risk:** un benchmark figé peut être gameable; le split sealed, les tâches fraîches et la revue de traces doivent rester obligatoires.
