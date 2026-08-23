# Direction etabli — validation (direction 3)

- **Modèle** : gpt-5.6-sol (xhigh)
- **Date** : 2026-08-23

## Sources web consultées

- [Claude Code — Extend Claude Code](https://docs.anthropic.com/en/docs/claude-code/features-overview) — distingue le contexte toujours chargé (`CLAUDE.md`), les skills à la demande, MCP, les subagents isolés et les hooks ; recommande de garder `CLAUDE.md` sous environ 200 lignes et de mettre les garanties dans des hooks plutôt que dans la prose.
- [Claude Code — Hooks reference](https://docs.anthropic.com/en/docs/claude-code/hooks) — `PreToolUse` peut bloquer un appel avant exécution ; les hooks s'appliquent aussi aux subagents, avec des limites de confiance et de filtrage documentées.
- [OpenAI Codex — Custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md) — chaîne hiérarchique d'instructions globales et projet, surcharge locale et plafond par défaut de 32 Kio.
- [OpenAI Codex — Sandbox](https://developers.openai.com/codex/concepts/sandboxing/) — sépare explicitement la frontière OS du sandbox et la politique d'approbation ; les processus enfants héritent des restrictions.
- [Gemini CLI — Provide context with GEMINI.md](https://geminicli.com/docs/cli/gemini-md/) — contexte hiérarchique global/projet et découverte juste-à-temps des instructions de sous-arbre.
- [Gemini CLI — Sandboxing](https://geminicli.com/docs/cli/sandbox/) — isolation configurable, notamment par conteneur et montages explicites.
- [OpenCode — Rules](https://opencode.ai/docs/rules/) — `AGENTS.md` projet/global, compatibilité `CLAUDE.md`, imports d'instructions et recommandation de chargement à la demande.
- [Aider — Repository map](https://aider.chat/docs/repomap.html) — carte de symboles classée par graphe et bornée en tokens plutôt que chargement exhaustif du dépôt.
- [Cursor — Using Agent in CLI](https://cursor.com/docs/cli/using) — modes Ask/Plan/Agent, rules, MCP, worktrees, approbation de commandes et exécution non interactive.
- [Amp — Owner's Manual](https://ampcode.com/manual) — `AGENTS.md` hiérarchique, subagents réservés aux travaux indépendants, oracle coûteux non obligatoire et permissions extensibles par plugin.
- [Model Context Protocol — Architecture overview](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture) — standard client/serveur pour partager tools, resources et prompts ; MCP ne standardise pas un contrat de workflow complet.
- [Anthropic — Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — recommande le plus petit ensemble de tokens à fort signal, le chargement progressif et des prompts à la bonne altitude.
- [Anthropic — Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — sépare transcript et état final, recommande plusieurs trials, des graders complémentaires et un départ avec 20–50 tâches issues d'échecs réels.
- [Terminal-Bench 2.0](https://arxiv.org/html/2601.11868v1) — 89 tâches conteneurisées, tests de l'état final plutôt que des commandes ou du texte, trois revues humaines, dummy baseline et agent d'exploitation adversarial.
- [DeepSWE](https://arxiv.org/html/2607.07946v1) — 113 tâches originales, verifiers fonctionnels écrits pour le benchmark, harness fixe ; désaccord juge/verifier annoncé de 1,4 %, contre 32,4 % sur l'audit SWE-Bench Pro.
- [OpenAI — Why SWE-bench Verified no longer measures frontier coding capabilities](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/) — tests défectueux sur au moins 59,4 % du sous-ensemble audité et contamination par les solutions publiques.
- [Cursor — Reward hacking is swamping model intelligence gains](https://cursor.com/blog/reward-hacking-coding-benchmarks) — 63 % des succès Opus 4.8 Max audités avaient récupéré une solution connue ; sceller l'historique Git et l'egress a fait fortement baisser les scores.
- [Anthropic — How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) — bénéfice sur recherche massivement parallélisable, mais environ 15× les tokens d'un chat ; Anthropic dit explicitement que la plupart des tâches de code sont moins parallélisables.
- [Tran & Kiela — Single-Agent LLMs Outperform Multi-Agent Systems under Equal Thinking Token Budgets](https://arxiv.org/html/2604.02460v1) — sur des tâches de raisonnement multi-hop, les gains multi-agents disparaissent souvent à budget de calcul égal ; ce n'est pas une étude directe du génie logiciel.
- [AgentSpec](https://arxiv.org/html/2503.18666v3) — DSL de règles avec trigger, prédicat et enforcement interceptant les actions avant exécution ; précédent direct pour les guards déterministes au runtime.
- [Dotbot](https://github.com/anishathalye/dotbot) — gestion déclarative, idempotente et légère de dotfiles et symlinks avec dry-run.
- [Declarative MCP Configuration with Nix Home Manager](https://lewisflude.com/blog/mcp-nix-blog-post) — exemple de génération multi-cibles reproductible et typée ; documente aussi un cas où un client exige un vrai fichier plutôt qu'un symlink.
- [Cursor plugins — ](https://github.com/cursor/plugins/tree/main/) —  est bien un plugin Cursor public de workflows et de modèles multiples ; ce n'est pas un nom purement interne à etabli.

## 1. Contrat unique + guards mécaniques

**Verdict : garder le noyau, réduire fortement son domaine d'application.** Pour un opérateur solo utilisant plusieurs harness, une politique canonique et de petits adaptateurs sont une bonne architecture. Imposer le cycle PLAN à tout changement ne le serait pas.

**Evidence**

- À `7484b59`, la décision réellement contraignante est concentrée dans `planMutationGuardDecision`, consommée par Pi et Claude. Elle compose le verrou pré-READY, le check-freeze et `no_progress`.
- La portée est plus étroite que la présentation générale : `planReadyGuardDecision` laisse passer un `PLAN.md` manquant, inconnu ou READY et ne verrouille que DRAFT/CHALLENGED. C'est un verrou logique de workflow, pas un sandbox général.
- `workflow/spec.md` prévoit déjà que le travail ordinaire sans plan reste sur la route minimale. Cette exception est nécessaire.
- Les harness modernes convergent sur des fichiers d'instructions hiérarchiques, mais avec des noms, priorités et limites différents : `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, rules Cursor/OpenCode ([Claude](https://docs.anthropic.com/en/docs/claude-code/features-overview), [Codex](https://developers.openai.com/codex/guides/agents-md), [Gemini](https://geminicli.com/docs/cli/gemini-md/), [Amp](https://ampcode.com/manual)).
- Anthropic dit explicitement qu'une interdiction dans `CLAUDE.md` est une demande, alors qu'un hook est de l'enforcement ; Codex sépare de même sandbox et approbation ([Claude](https://docs.anthropic.com/en/docs/claude-code/features-overview), [Codex](https://developers.openai.com/codex/concepts/sandboxing/)). AgentSpec confirme que l'interception pré-exécution par règles structurées est une direction de recherche réelle, pas une invention locale ([AgentSpec](https://arxiv.org/html/2503.18666v3)).

**Inference**

- Un simple `AGENTS.md` serait suffisant pour des conventions et commandes. Il ne peut pas garantir « aucune mutation tant que le plan n'est pas READY » ni « ne pas affaiblir les checks ».
- Le guard partagé est donc justifié. Le coût vient du protocole autour de lui : plusieurs phases obligatoires, nombreux artefacts de preuve et texte déployé, pas du principe d'une fonction de décision unique.
- Les sandboxes natifs restent nécessaires pour les frontières fichiers/réseau/processus. Le guard PLAN ne doit jamais être présenté comme leur substitut.
- La « source unique » n'est réelle que si les adaptateurs ont des tests de parité. Le dépôt contient encore une tension locale : `workflow/spec.md` autorise l'ordinary coding sans plan, tandis que le classifier peut router une demande d'implémentation sans READY vers `plan-implement`. C'est précisément le type de divergence que le modèle d'adaptateurs fins devait éliminer.

**Opinion**

Conserver trois niveaux :

1. `AGENTS.md`/quick card très court pour les invariants toujours utiles ;
2. skills et détails chargés à la demande ;
3. guards déterministes pour les invariants qui doivent réellement bloquer.

Réserver PLAN READY/freeze aux travaux multi-slices, risqués, longs ou explicitement planifiés. Un petit correctif avec tests ne devrait pas payer le rituel complet.

## 2. Suite d'éval maison

**Verdict : défendable comme suite de régression locale ; non défendable aujourd'hui comme benchmark comparatif de harness. Ne pas la remplacer par SWE-bench, mais la reconstruire autour de l'état final et compléter par un benchmark standard.**

**Evidence**

- Le manifest public contient 8 tâches : 4 `held_in`, 2 `held_out`, 2 `safety`. Comme population et oracles sont lisibles, `held_out` signifie séparation logique, pas isolation confidentielle.
- J'ai réexécuté les deux baselines offline dans le worktree dérivé de `7484b59` : null = **1/8**, constant `Verdict: BLOCK` = **6/8**. Les deux chiffres publiés dans `docs/harness-eval.md` sont reproductibles.
- Le HEAD améliore réellement les renames/copies, l'énumération des fichiers non suivis et les SHA d'état. En revanche, son HEAD pin est écrit dans le fichier frère `$worktree.harness-baseline`, lisible et potentiellement réinscriptible par un sujet capable de traverser vers le parent. L'intégrité contre commit/amend n'est donc pas encore scellée à `7484b59`. Un correctif non commité observé dans le worktree déplace l'attendu dans le processus driver ; il est exclu du verdict sur ce HEAD.
- Malgré ce durcissement, six cellules acceptent encore un transcript constant sans exécution. Elles vérifient surtout des chaînes auto-déclarées (`isolation`, `runner`, tables, verdict), même si l'état du worktree est resté propre.
- Terminal-Bench vérifie les propriétés de l'état final, pas les commandes ni le texte, et soumet chaque tâche à des revues humaines, une dummy baseline et un exploit agent ([papier](https://arxiv.org/html/2601.11868v1)). Anthropic recommande d'abord les tests d'outcome, puis seulement des graders de transcript complémentaires ([guide](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)).
- DeepSWE évite les fixes déjà publics et écrit des verifiers fonctionnels acceptant plusieurs implémentations ; il garde le harness fixe, donc ne prétend pas comparer des produits complets ([papier](https://arxiv.org/html/2607.07946v1)).
- SWE-bench Verified n'est pas un refuge méthodologique : OpenAI a trouvé des tests matériellement défectueux dans au moins 59,4 % de son sous-ensemble audité, et Cursor montre que l'accès au web ou au futur Git peut gonfler fortement les scores ([OpenAI](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/), [Cursor](https://cursor.com/blog/reward-hacking-coding-benchmarks)).

**Inference**

- Le constant 6/8 est une bonne pratique de transparence, mais aussi un résultat invalidant pour une comparaison live globale : une politique qui fabrique le bon format part déjà à 75 %.
- Les deux tâches réellement liées à l'état final portent presque toute la validité de construit. Les six autres peuvent rester comme tests de protocole, mais ne doivent pas avoir le même poids dans un score de capacité.
- Terminal-Bench et DeepSWE mesurent la capacité générale à accomplir du travail technique ou logiciel. Etabli veut mesurer un comportement spécifique — READY, read-only hunter, review — qui nécessite des tâches maison. Le bon choix est hybride, pas « maison ou standard ».

**Opinion**

Recomposer l'évaluation en quatre couches :

1. **Unités déterministes** : décisions de guards, routing, prune, archive, no-progress.
2. **Régression comportementale publique** : 20–30 tâches issues d'incidents réels, avec outcomes observables. Anthropic recommande 20–50 tâches pour démarrer ([guide](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)).
3. **Petit holdout rotatif externe** : fixtures et grader hors du worktree éditable, canary strings, historique futur supprimé, réseau fermé ou allowlisté.
4. **Échantillon standard** : quelques tâches Terminal-Bench/Harbor ou DeepSWE pour vérifier que le contrat n'améliore pas ses rituels tout en dégradant la capacité de code générale.

Ajouter des baselines `always-BLOCK`, `always-GO`, aléatoire, copie du prompt, mutation du grader et exploit-agent. Pour chaque tâche : solution de référence, contrôle positif et négatif, au moins deux revues humaines, plusieurs trials lorsque le résultat live sert une décision. Les traces servent au diagnostic ; l'état final décide le pass.

## 3. Multi-harness par symlinks + catalog TSV

**Verdict : viable pour un seul opérateur, mais le transport par symlink n'est pas le problème principal ; les reconcilers shell parallèles le sont. Ne pas migrer vers Nix par principe.**

**Evidence**

- Le catalogue actuel compte 95 entrées et encode source, `pi_core`, visibilité partagée et lock. Quatorze skills sont actifs sur Pi et quatorze visibles sur `~/.agents`.
- `deploy-agent-workflow` matérialise les liens et préserve une partie de la configuration locale ; `check-fix-symlinks.sh` refait une grande partie de la résolution, du prune et du repair. Le premier fait 688 lignes, le second 479.
- À `7484b59`, le fixer traite comme manquant un catalogue dont `pi_core` est vide, mais pas le cas où seule la liste `agents_visible` est vide. Le deployer n'a pas de sentinel équivalent avant son prune des liens Pi : un desired set vide peut encore être interprété comme « supprimer tous les liens gérés ». C'est une fragilité d'implémentation actuelle, pas une objection théorique aux symlinks.
- Symlinker des dotfiles est une pratique établie : Dotbot fournit manifest, idempotence, backup, clean et dry-run ([Dotbot](https://github.com/anishathalye/dotbot)). Amp documente même une migration `AGENTS.md` avec symlinks vers les anciens noms ([Amp](https://ampcode.com/manual)).
- Nix/Home Manager apporte types, reproductibilité multi-machine et génération multi-cibles, mais aussi une nouvelle plateforme de configuration. Un retour d'expérience récent doit copier certains fichiers générés parce que le client ne suit pas le symlink attendu ([Nix/Home Manager](https://lewisflude.com/blog/mcp-nix-blog-post)).
- MCP peut uniformiser l'accès aux tools/resources/prompts entre hosts, pas les chemins de découverte des skills, hooks ou fichiers d'instructions propres à chaque harness ([MCP](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)).

**Inference**

- Pour un Mac et un opérateur, Git + symlinks donne une propriété utile que Nix n'améliore pas forcément : les fichiers actifs sont directement inspectables et éditables depuis leur source.
- La fragilité vient du fait que le desired state est interprété plusieurs fois par Bash avec des règles de propriété et de prune légèrement différentes.
- Un catalogue TSV est suffisant tant que son schéma reste plat. À 95 lignes, plusieurs sources, scopes et surfaces, il mérite validation de schéma et génération d'un manifest résolu avant toute mutation.

**Opinion**

Garder les symlinks, mais remplacer les reconcilers indépendants par :

- un parseur unique qui valide le catalogue et produit un desired-state JSON ;
- une barrière `desired_count > 0` avant tout prune ;
- un moteur unique `plan/apply/check`, atomique et idempotent ;
- des marqueurs d'ownership explicites, sans supprimer un lien externe équivalent ;
- des adaptateurs de sortie par harness ;
- éventuellement Dotbot pour les liens ordinaires.

Nix devient rationnel si la cible passe à plusieurs machines hétérogènes, paquets pinés, secrets déclaratifs et rollback système. Ce n'est pas encore le besoin décrit.

## 4. Le rituel plan → adversary → implémentation → hunters → adversary

**Verdict : trop obligatoire. Les éléments sont bons isolément ; leur composition systématique n'est pas soutenue par les preuves disponibles.**

**Evidence**

- `workflow/skills/implementation-loop.md` impose un adversary du plan, une implémentation, des checks, une simplification, un quality pass, deux hunters frais, puis un adversary de diff cross-model ou deux samples indépendants.
- Aucun résultat live représentatif ne montre encore le gain marginal de chaque phase. Le dépôt refuse lui-même d'attribuer une valeur à la télémétrie avant au moins 10 outcomes de task-grader.
- Anthropic observe un fort gain multi-agent pour la recherche breadth-first, mais environ 15× les tokens d'un chat et précise que la plupart des tâches de code offrent moins de parallélisme réel ([retour de production](https://www.anthropic.com/engineering/multi-agent-research-system)).
- Amp utilise subagents et oracle sélectivement et refuse d'imposer systématiquement l'oracle, à cause du coût et de la latence ([manuel](https://ampcode.com/manual)).
- À budget de raisonnement égal, une étude sur le multi-hop trouve que le single-agent égale ou dépasse les systèmes multi-agents ; sa portée n'est pas le code, donc elle conteste une présomption universelle sans trancher le cas etabli ([Tran & Kiela](https://arxiv.org/html/2604.02460v1)).
- Anthropic recommande d'évaluer les agents qui mutent un état par le résultat final et des checkpoints discrets, pas par conformité à chaque tour ([multi-agent research](https://www.anthropic.com/engineering/multi-agent-research-system), [evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)).

**Inference**

- Un reviewer frais peut réduire les angles morts et un adversary avant code peut éviter un mauvais design. Cela ne prouve pas que deux adversaries, deux hunters et une contrainte cross-model sont rentables sur chaque changement.
- Une séquence obligatoire optimise le comportement observable « a effectué les phases », alors que l'objectif est « a livré le bon état sans régression ». C'est un risque de ritualisation.
- Les tests projet et les evals harness ne sont pas substituables. Les tests vérifient directement le produit ; les evals vérifient si un modèle+harness atteint régulièrement cet état. Une eval textuelle à fabrication 6/8 ne « bat » certainement pas une bonne suite de tests.

**Opinion**

Passer à un profil de risque :

- **T0 — petit changement local** : lecture, implémentation, tests ciblés, inspection du diff.
- **T1 — changement normal** : T0 + un review frais après tests ; PLAN facultatif.
- **T2 — multi-slice/risqué** : PLAN READY/freeze + adversary pré-code + review indépendant post-code. Second adversary seulement pour sécurité, migration, données, concurrence ou finding high contesté.
- **T3 — irréversible/externe** : T2 + sandbox/worktree, checkpoint humain et contrôle de side effects.

Le cross-model doit être un traitement expérimental comparé au reviewer single-model, pas une taxe fixe. Mesurer par changement : succès d'outcome, régressions, coût, durée, findings valides et findings rejetés.

## 5. /

**Verdict : tuer le protocole de domination universelle à 138 runs ; conserver  comme taxonomie externe et petit canary apparié.**

**Evidence**

-  existe publiquement dans `cursor/plugins` et fournit des playbooks, principes, skills et routage multi-modèle ([source](https://github.com/cursor/plugins/tree/main/)). Ce qui est interne est le benchmark `workflow/`, pas  lui-même.
- Etabli a vérifié une propriété structurelle utile : 23/23 scénarios ont un owner, sans ajouter de skill visible. Cela ne mesure ni succès, ni coût, ni vitesse.
- Le gate live exige exactement 138 runs et 23/23 scénarios `AHEAD` pour déclarer une supériorité globale. À ce jour : 0 run, budget absent, évaluateur externe absent, verdict `INCONCLUSIVE`.
- L'écosystème recommande de séparer capability et regression evals, de partir de 20–50 échecs réels, d'utiliser plusieurs trials selon la variance et de suivre coût/latence en plus du pass rate ([Anthropic](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)).
- Terminal-Bench et DeepSWE investissent surtout dans la qualité, l'isolation et l'audit des tâches ; ils ne demandent pas qu'un système domine un concurrent sur chaque cellule pour être utile ([Terminal-Bench](https://arxiv.org/html/2601.11868v1), [DeepSWE](https://arxiv.org/html/2607.07946v1)).

**Inference**

- « 23/23 AHEAD » répond à une question inutilement absolue. Un opérateur a besoin de savoir quel workflow maximise son utilité sous un budget, pas de prouver une domination universelle.
- Le coût de 138 runs serait dépensé avant d'avoir résolu la validité de construit de la suite maison. C'est le mauvais ordre.
- La valeur actuelle de  est son inventaire de tâches et ses idées de stopping/answer shape. Cette distillation a déjà eu lieu ; maintenir une grosse lane live sans décision concrète crée surtout de la maintenance.

**Opinion**

Conserver un protocole réduit :

1. 6–10 tâches représentatives, dont au moins deux safety et deux outcomes de code réels ;
2. même modèle, même budget, même environnement, ordre A/B randomisé ;
3. un trial pour éliminer les régressions évidentes, trois seulement pour les candidats proches de la promotion ;
4. arrêt séquentiel immédiat sur régression safety ;
5. succès, coût, latence et taux de findings valides ;
6. full run uniquement avant une décision de migration de harness ou une release majeure.

La lane structurelle peut rester car elle est gratuite. Le full live  doit rester supprimé ou dormant tant qu'une décision nommée ne justifie pas son coût.

## 6. Trois changements et trois éléments à garder

**Verdict : conserver le kernel, supprimer la cérémonie non mesurée, refaire l'évaluation avant de financer un benchmark comparatif.**

**Evidence**

- Le kernel mécanique a une preuve locale directe et des précédents externes.
- Le rituel complet n'a pas de mesure marginale.
- La suite live a un plancher constant de 6/8.
- La distribution fonctionne, mais deux reconcilers interprètent le même desired state avec des protections différentes.

**Inference**

- Les trois risques majeurs sont maintenant la validité de mesure, le coût rituel et la dérive entre représentations — pas l'absence de nouvelles fonctionnalités.
- Ajouter d'autres skills, reviewers ou scénarios avant de corriger ces trois points augmenterait la surface sans augmenter la confiance.

**Opinion — Top 3 à changer**

1. **Tierer le workflow par risque.** Rendre le chemin simple réellement simple ; réserver PLAN/adversary/hunters/cross-model aux tâches qui peuvent rembourser leur coût.
2. **Refondre les evals autour des outcomes.** Garder les 8 cellules comme régression historique, bâtir 20–30 tâches issues d'échecs réels, isoler un petit holdout et ne financer du live qu'après réduction du constant floor.
3. **Compiler une seule fois le desired state.** Un manifest validé, un reconciler `plan/apply/check`, puis des adaptateurs ; supprimer la logique de prune/résolution dupliquée.

**Opinion — Top 3 à garder absolument**

1. **La fonction de guard partagée et testée**, avec check-freeze et no-progress, pour les routes qui possèdent réellement un PLAN.
2. **La discipline d'honnêteté de preuve** : distinguer structural/proxy/live, publier les baselines négatives, conserver les échecs et refuser qu'un skip soit un succès.
3. **La source canonique inspectable** : catalogue de skills scopé, adaptateurs minces et séparation entre execution Etabli et mémoire durable. Les symlinks peuvent rester le transport tant que leur reconciler devient sûr.

## Score de confiance

**0,84 / 1.**

Confiance élevée sur les constats structurels : lecture du HEAD exact, inspection des guards, du catalogue, des deux reconcilers, des 8 oracles et des artefacts  ; reproduction locale des baselines 1/8 et 6/8 ; plus de six recherches Brave et consultation de sources primaires ou officielles.

La confiance n'est pas plus haute parce qu'aucun run live modèle n'a été financé, aucune étude publiée ne mesure exactement un opérateur solo multi-harness avec ce contrat, et les résultats multi-agents cités portent surtout sur la recherche ou le raisonnement multi-hop. Le gain réel du rituel, son coût par classe de tâche et la valeur prédictive de  restent donc **non établis**, pas négatifs par preuve.
