# Harness Best Practices Audit

Date: 2026-06-12

Repo: `/Volumes/Crucial/work/etabli`

Objectif: comparer le harness agentique Etabli aux pratiques recentes observees chez Anthropic, OpenAI, GitHub, Kiro, LangChain et Spec Kit, puis lister ce qu'il faut garder, modifier, ajouter ou eviter/supprimer.

Non-objectifs: ce document ne modifie pas le harness. Il ne remplace pas un plan d'implementation et ne cree pas de ticket.

## Labels de preuve

- `confirmed`: confirme par une source primaire/locale inspectee.
- `approximate`: source plausible mais date, portee ou detail partiellement approximatif.
- `proxy-supported`: recommande par analogie avec des sources proches, sans preuve directe sur Etabli.
- `blocked`: impossible a confirmer avec les sources disponibles.
- `unknown`: manque d'evidence ou decision dependante d'un usage futur.

## Synthese

Le harness Etabli est deja aligne avec les pratiques les plus solides: boucle simple, `PLAN.md` comme artefact d'execution unique, archive post-implementation, memoire durable separee, review sceptique, commandes de scaffold/conversion avec dry-run et backups. Le risque principal n'est pas l'absence d'un gros framework de spec-driven development. Le risque principal est la derive entre les cartes de contexte, les fichiers reellement deployes, et les conventions que les agents doivent appliquer apres plusieurs sessions.

Le prochain meilleur investissement est donc une consolidation du harness, pas une expansion massive:

- corriger la carte installee du harness;
- formaliser la taxonomie des artefacts d'etat;
- ajouter une petite boucle d'evaluation/regression du harness;
- clarifier quand utiliser un evaluateur frais;
- documenter une discipline de contexte et de tools;
- eviter de cloner Spec Kit/Kiro tant que le besoin n'est pas prouve par des echecs repetes.

## Sources inspectees

### Sources locales

- `workflow/spec.md`
- `workflow/memory.md`
- `workflow/plan-archive.md`
- `workflow/review-rubric.md`
- `workflow/ticket-template.md`
- `PLAN_TEMPLATE.md`
- `PLAN_TEMPLATE_FULL.md`
- `harness/templates/AGENTS.md`
- `harness/templates/CLAUDE.md`
- `harness/templates/docs/agent-harness.md`
- `harness/templates/docs/agent-memory.md`
- `harness/templates/docs/plan.md`
- `harness/templates/docs/claude-code-harness.md`
- `harness/templates/docs/project-context.md`
- `scripts/deploy-harness`
- `scripts/scaffold-project`
- `README.md`
- `pi/skills/plan-loop/SKILL.md`
- `pi/skills/plan-implement/SKILL.md`
- `pi/skills/implement/SKILL.md`
- `claude/commands/plan-create.md`
- `claude/commands/plan-loop.md`
- `claude/commands/plan-implement.md`
- `claude/commands/implement.md`
- `codex/workflow/dynamic-workflow-triggers.md`

### Sources web

- Anthropic, [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps), 2026-03-24.
- Anthropic, [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents), 2025-09-29.
- Anthropic, [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents), 2025-11-26.
- Anthropic Claude Cookbook, [Context engineering: memory, compaction, and tool clearing](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools), 2026-03-20.
- Anthropic, [Building effective AI agents](https://www.anthropic.com/engineering/building-effective-agents), 2024-12-19.
- Anthropic, [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents), consulte le 2026-06-12.
- Anthropic, [Writing effective tools for AI agents](https://www.anthropic.com/engineering/writing-tools-for-agents), consulte le 2026-06-12.
- OpenAI, [Custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md), consulte le 2026-06-12.
- OpenAI Cookbook, [Build an Agent Improvement Loop with Traces, Evals, and Codex](https://developers.openai.com/cookbook/examples/agents_sdk/agent_improvement_loop), 2026-05-12.
- OpenAI, [A practical guide to building agents](https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/), consulte le 2026-06-12.
- GitHub Docs, [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions), consulte le 2026-06-12.
- AGENTS.md, [Open format for coding agents](https://agents.md/), consulte le 2026-06-12.
- LangChain, [Context Engineering](https://www.langchain.com/blog/context-engineering-for-agents), 2025-07-02.
- GitHub, [spec-kit](https://github.com/github/spec-kit), consulte le 2026-06-12.
- GitHub Blog, [Spec-driven development with AI](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/), 2025-09-02.
- Kiro, [Bring engineering rigor to agentic development](https://kiro.dev/), consulte le 2026-06-12.
- Martin Fowler / Thoughtworks, [Understanding Spec-Driven-Development: Kiro, spec-kit, and Tessl](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html), 2025-10-15.

### Mapping des preuves externes

- Simplicite avant orchestration lourde: Anthropic "Building effective AI agents", OpenAI "A practical guide to building agents", Anthropic "Harness design for long-running application development".
- Planner/builder/evaluator avec cout explicite: Anthropic "Harness design for long-running application development".
- Context engineering, memoire, compaction, isolation: Anthropic "Effective context engineering", Anthropic Claude Cookbook, LangChain "Context Engineering".
- Evals et boucle d'amelioration: OpenAI Cookbook "Agent Improvement Loop", Anthropic "Demystifying evals".
- Instructions repo et AGENTS.md: OpenAI Codex AGENTS.md, GitHub custom instructions, AGENTS.md open format.
- Tools/scripts peu bruyants: Anthropic "Writing effective tools for AI agents".
- Spec-driven development comme comparateur, pas comme obligation: GitHub Spec Kit, GitHub Blog Spec-driven development, Kiro, Martin Fowler / Thoughtworks.

## Etat actuel du harness Etabli

### Faits observes

- `workflow/spec.md` definit la boucle `learn -> plan -> implement -> review -> validate`.
- `PLAN.md` est l'artefact d'execution unique en cours de travail.
- Les statuts valides sont `DRAFT`, `CHALLENGED`, `READY`; seule la valeur `READY` autorise l'implementation.
- Les plans sont archives dans `docs/plan/` seulement apres implementation et validation.
- `workflow/plan-archive.md` demande une archive distillee orientee memoire, pas une copie brute de `PLAN.md`.
- `workflow/memory.md` separe les lecons durables dans `docs/agent-memory/`.
- `scripts/scaffold-project` expose `--new`, `--convert`, `--dry-run`, `--force` et appelle `scripts/deploy-harness`.
- `scripts/deploy-harness` detecte les conflits, sauvegarde avant overwrite avec `--force`, et ajoute `PLAN.md` a `.gitignore`.
- `harness/templates/docs/agent-harness.md` ne liste pas toute la surface aujourd'hui deployee par `scripts/deploy-harness`: `workflow/memory.md`, `workflow/plan-archive.md`, `docs/agent-memory/README.md`, `docs/plan/README.md`.
- `harness/templates/docs/claude-code-harness.md` contient deja une doctrine proche de l'article Anthropic: workflow simple par defaut, planner/builder/evaluator seulement quand utile, contrats de sprint, handoff, evaluation UI.
- `workflow/review-rubric.md` couvre self-check, compliance au plan, review adversariale et checkpoint humain.
- `workflow/ticket-template.md` est agnostique et suit "un ticket = un comportement = une PR".

### Hypotheses

- Le harness est destine a etre portable entre projets, pas seulement a ce repo.
- Les agents cibles restent principalement Codex, Pi et Claude Code.
- Copilot/Kiro/Spec Kit servent de comparateurs, pas de plateformes ciblees a supporter immediatement.

## Matrice de recommandations

| Action | Label | Recommandation | Pourquoi | Risque si ignore | Cout | Fichiers probables |
| --- | --- | --- | --- | --- | --- | --- |
| A garder | `confirmed` | Garder la boucle simple `learn -> plan -> implement -> review -> validate` et `PLAN.md` comme artefact actif unique. | Anthropic et OpenAI recommandent de commencer par la solution la plus simple et de n'ajouter de l'orchestration que si elle apporte un gain mesure. Etabli a deja cette contrainte. | Bureaucratie, double source de verite, plans qui deviennent eux-memes du bruit de contexte. | Aucun. | `workflow/spec.md`, `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md` |
| A garder | `confirmed` | Garder `AGENTS.md` et `CLAUDE.md` comme adaptateurs courts vers des docs suivies. | OpenAI, GitHub et AGENTS.md convergent sur des instructions repo lisibles, proches du code, avec hierarchie de contexte. | Instructions longues, stale, ou chargees par trop d'outils differents sans priorite claire. | Aucun. | `harness/templates/AGENTS.md`, `harness/templates/CLAUDE.md` |
| A modifier | `confirmed` | Mettre a jour `docs/agent-harness.md` pour lister exactement la surface deployee. | Le script deploye plus de fichiers que la doc installee ne mentionne. C'est une derive de source de verite deja observable. | Un agent ou un humain croit que la memoire/les archives ne font pas partie du harness installe. | Faible. | `harness/templates/docs/agent-harness.md`, `tests/harness-smoke.sh` |
| A modifier | `confirmed` | Ajouter une taxonomie courte des artefacts d'etat: `PLAN.md`, `docs/plan/`, `docs/agent-memory/`, `docs/agent-runs/`, tickets. | Les sources context-engineering distinguent contexte actif, memoire, handoff et evaluation. Etabli a les pieces, mais leur relation est dispersee. | Mauvais artefact au mauvais moment: archives creees trop tot, memoire transformee en logs, plans anciens reutilises comme specs vivantes. | Faible a moyen. | `workflow/spec.md`, `workflow/memory.md`, `workflow/plan-archive.md`, `harness/templates/docs/agent-harness.md` |
| A ajouter | `confirmed` | Ajouter une petite boucle d'evaluation/regression du harness. | OpenAI et Anthropic traitent le harness comme un systeme a evaluer: traces, evals, regression tasks, resultats reproductibles. Etabli a des smoke tests, mais pas de banque de comportements harness critiques. | Les regles regressent silencieusement: plan archive trop tot, ticket template devie, conversion ecrase des fichiers, review oublie le plan. | Moyen. | `tests/`, `workflow/harness-evals.md` ou doc equivalente |
| A modifier | `confirmed` | Rendre explicites les criteres d'escalade vers evaluateur frais/subagent. | Anthropic montre que planner/generator/evaluator aide surtout pour les taches longues, subjectives ou aux limites du modele; sinon c'est du cout. Etabli dit deja "seulement quand utile", mais les triggers peuvent etre plus operationnels. | Sous-evaluation des gros changements ou, inversement, usage reflexe de multi-agent lourd. | Faible. | `workflow/spec.md`, `workflow/review-rubric.md`, `harness/templates/docs/claude-code-harness.md` |
| A modifier | `confirmed` | Formaliser une discipline de contexte: quoi lire, quoi resumer, quoi compacter, quoi sortir du contexte. | Anthropic Cookbook et LangChain decrivent la memoire, la compression, l'isolation et le nettoyage des retours d'outils comme leviers distincts. Etabli a memoire/archive, mais pas encore une politique courte et commune. | Context rot, repetition de gros dumps, agents qui se basent sur une conversation plutot que sur les artefacts suivis. | Moyen-faible. | `workflow/memory.md`, `harness/templates/docs/claude-code-harness.md`, `harness/templates/AGENTS.md` |
| A ajouter | `proxy-supported` | Ajouter une mini doctrine de design des tools/scripts du harness. | Anthropic insiste sur des tools a but distinct, faible bruit, noms clairs, sorties actionnables. Etabli ajoute des scripts (`deploy-harness`, `scaffold-project`, audits); leur design merite une checklist avant expansion. | Scripts redondants, sorties trop verbeuses, options ambiguës, faible testabilite. | Faible a moyen. | `workflow/tool-design.md` ou section dans `docs/agent-harness.md`, `scripts/` |
| A modifier | `confirmed` | Clarifier `scaffold-project` comme commande user-facing et `deploy-harness` comme primitive deploiement. | Le README le dit deja, mais montre encore les deux dans le quick path. L'utilisateur doit avoir une porte d'entree nette. | Choix inutile entre deux commandes, adoption plus fragile dans projets existants. | Faible. | `README.md`, `harness/templates/docs/agent-harness.md` |
| A ajouter | `proxy-supported` | Ajouter un mode `--check` ou un rapport machine-readable optionnel pour conversion de projets existants. | Spec Kit supporte l'initialisation dans un projet existant; Etabli a dry-run et conflits, mais pas de sortie structuree exploitable par CI/agent. | Conversion manuelle peu auditable, difficile de detecter la derive du harness dans un repo deja equipe. | Moyen. | `scripts/deploy-harness`, `scripts/scaffold-project`, `tests/harness-smoke.sh` |
| A garder | `confirmed` | Garder l'archive de plan comme memoire distillee, pas comme copie brute. | Les sources de context engineering poussent a conserver du signal reutilisable, pas des logs exhaustifs. Etabli encode deja decisions, drift accepte, validation, follow-up. | Archives longues, peu lues, et donc inutiles comme memoire projet. | Aucun. | `workflow/plan-archive.md`, `harness/templates/docs/plan.md` |
| A modifier | `confirmed` | Ajouter dans le format d'archive une ligne "Superseded source-of-truth docs/specs" obligatoire quand un plan a fait diverger une spec. | La demande initiale vise les specs qui driftent. Le template l'a deja sous "Follow-up State", mais ce point devrait etre assez visible pour forcer l'agent a dire ce qui est devenu faux. | La memoire dit ce qui a ete fait, mais pas quelle ancienne spec ne doit plus etre crue. | Faible. | `workflow/plan-archive.md`, `harness/templates/docs/plan.md` |
| A garder | `confirmed` | Garder le ticket template agnostique et comportemental. | GitHub Spec Kit/Kiro mettent en avant requirements, acceptance criteria et tasks mappees aux intentions. Le template Etabli capture deja outcome, user story, scope, non-goals, contract, edge cases, acceptance criteria, validation. | Tickets trop specifiques a un produit ou trop larges pour une PR. | Aucun. | `workflow/ticket-template.md`, `codex/workflow/ticket-template.md` |
| A supprimer / eviter | `confirmed` | Eviter de cloner Spec Kit/Kiro comme framework complet. | Les sources spec-driven sont utiles, mais Anthropic/OpenAI rappellent que la complexite doit etre load-bearing. Etabli possede deja plan, tickets, archive, memoire et review. | Duplication: `specify/plan/tasks/implement` en plus de `PLAN.md`, tickets et archives; plus de docs a maintenir. | Economie de cout. | N/A, sauf si futures docs proposent un clone |
| A supprimer / deplacer | `approximate` | Retirer les references trop centrales a `docs/agent-runs/` du chemin par defaut, ou scaffold un README correspondant. | `docs/claude-code-harness.md` recommande `docs/agent-runs/<slug>/contract.md` et `handoff.md`, mais `deploy-harness` ne cree pas de doc racine pour cette surface. Ce n'est pas bloquant, mais c'est un espace d'etat implicite. | Des handoffs apparaissent hors taxonomie, puis concurrencent `PLAN.md`, `docs/plan/` ou `docs/agent-memory/`. | Faible. | `harness/templates/docs/claude-code-harness.md`, eventuel `harness/templates/docs/agent-runs.md` |
| A ajouter avec prudence | `proxy-supported` | Ajouter seulement des hooks/lints cibles apres erreurs repetees, pas une couche d'automation generale. | Kiro met en avant les hooks; GitHub Copilot expose aussi des hooks. Mais les hooks sont utiles quand ils capturent une erreur recurrente, pas quand ils automatisent un jugement flou. | Bruit, faux positifs, agents qui contournent les checks. | Moyen. | `tests/`, eventuels hooks Codex/Pi/Claude |
| A ajouter | `confirmed` | Ajouter une regle de recherche web: sources recentes, primaires si possible, et labels d'incertitude pour claims. | Les instructions projet le demandent deja; le harness portable ne l'explicite pas fortement. Pour un harness qui produit decisions et memoire, la fraicheur et la provenance font partie du contrat. | Rapports perimes, recommandations "best practice" non sourcees. | Faible. | `harness/templates/AGENTS.md`, `harness/templates/docs/agent-harness.md` |

## Comparaison detaillee

### 1. Instruction files et decouverte projet

Etabli est bien positionne. OpenAI documente `AGENTS.md` comme mecanisme d'instructions projet pour Codex, avec hierarchie et precedence par proximite. GitHub supporte aussi des instructions repo et path-specific, et AGENTS.md s'est impose comme format lisible par plusieurs agents.

Decision: garder des adaptateurs courts et ne pas charger toute la doctrine dans `AGENTS.md`.

Modification utile: la carte `harness/templates/docs/agent-harness.md` doit correspondre au deploiement reel. Sinon le harness enseigne sa propre version stale.

### 2. Memoire, archives et context engineering

Les sources recentes convergent: le contexte est une ressource finie; les artefacts doivent separer contexte actif, memoire durable, handoff et evaluation. Etabli a deja cette separation:

- `PLAN.md`: contrat actif temporaire;
- `docs/plan/`: memoire post-implementation;
- `docs/agent-memory/`: lecons durables;
- `docs/project-context.md`: faits projet stables;
- tickets: slices futures;
- `docs/agent-runs/`: handoffs longs, mentionnes mais pas vraiment cartographies.

Le manque n'est pas un nouveau repertoire. Le manque est une taxonomie courte qui dit quand lire/ecrire quoi.

Decision: modifier les docs existantes avant d'ajouter un nouvel artefact.

### 3. Planner / builder / evaluator

Anthropic montre un pattern planner/generator/evaluator efficace pour les longues taches, UI subjective, gros produits ou limites du modele. La meme source insiste sur le cout et sur la simplification: chaque composant encode une hypothese sur ce que le modele ne sait pas faire.

Etabli encode deja cette prudence dans `docs/claude-code-harness.md`. Le point faible est operationnel: quand exactement escalader?

Criteres proposes:

- tache large ou multi-surface;
- UI/product quality subjective;
- validation impossible par tests unitaires seuls;
- risque securite/auth/donnees;
- implementation qui a deja invalide le plan;
- validation echouee puis corrigee plusieurs fois;
- besoin d'un regard frais apres beaucoup de contexte.

### 4. Evals et regression du harness

OpenAI et Anthropic traitent l'agent/harness comme un systeme mesurable: traces, evals, regression tasks, graders, retour humain ou modele. Etabli a des tests smoke, mais il manque une definition des comportements critiques du harness.

Exemples d'evals utiles pour Etabli:

- une commande de plan ne cree jamais `docs/plan/`;
- une commande d'implementation archive seulement apres validation;
- une archive contient outcome, decisions, drift accepte, validation evidence et follow-up;
- `scaffold-project --convert --dry-run` n'ecrase rien;
- `deploy-harness --force` cree des backups;
- un ticket conserve l'ordre de sections requis;
- une review compare le diff a `PLAN.md` quand il existe;
- les docs installees listent toutes les surfaces deployee.

Decision: ajouter une petite banque d'evals harness, pas un framework eval lourd.

### 5. Spec-driven development

Spec Kit et Kiro poussent des specs vivantes, requirements, plans, tasks et implementation mappee aux requirements. C'est pertinent pour les produits ou specs long terme. Mais Etabli a une autre philosophie: `PLAN.md` est un contrat temporaire et l'archive devient memoire apres implementation.

Le point a prendre: tracer quelle spec/doc a ete rendue obsolete par l'implementation.

Le point a eviter: empiler `spec -> plan -> tasks -> ticket -> PLAN.md -> archive` pour chaque petite tache. Ce serait du contexte a maintenir plutot qu'une memoire utile.

### 6. Tools, scripts et conversion

Anthropic recommande des tools clairs, distincts, peu bruyants, faciles a evaluer. `scripts/scaffold-project` et `scripts/deploy-harness` vont dans la bonne direction:

- commande user-facing;
- dry-run;
- force explicite;
- backups;
- conflits non silencieux.

Amelioration utile: un mode `--check` ou `--json` permettrait aux agents/CI de detecter une derive du harness sans parser du texte. Ce n'est pas urgent, mais c'est cohérent avec un harness qui se veut deployable et verifiable.

## Priorite proposee

1. Corriger `harness/templates/docs/agent-harness.md` pour refleter la surface deployee.
2. Ajouter une taxonomie courte des artefacts d'etat dans `workflow/spec.md` ou `docs/agent-harness.md`.
3. Renforcer `workflow/plan-archive.md` avec le champ visible "Superseded source-of-truth docs/specs".
4. Ajouter une mini eval bank du harness, probablement dans `tests/` plus une doc courte.
5. Clarifier les triggers d'evaluateur frais dans `workflow/review-rubric.md` et `docs/claude-code-harness.md`.
6. Ajouter une checklist tool/script design avant d'etendre les commandes.
7. Envisager `scaffold-project --check` ou `deploy-harness --json` apres stabilisation des tests.

## Ce qu'il ne faut pas faire maintenant

- Ne pas ajouter un clone complet de Spec Kit.
- Ne pas creer un second artefact actif obligatoire a cote de `PLAN.md`.
- Ne pas archiver les plans non implementes.
- Ne pas transformer `docs/agent-memory/` en journal de session.
- Ne pas ajouter de hooks generiques avant d'avoir une erreur recurrente precise a prevenir.
- Ne pas supporter Copilot/Kiro comme plateformes de premier rang sans besoin explicite.

## Inconnues et limites

- `unknown`: je n'ai pas de donnees d'usage reelles sur la frequence des erreurs de harness dans plusieurs projets deployes. Les priorites sont donc basees sur inspection locale et sources externes, pas sur telemetrie.
- `approximate`: Kiro est utilise comme comparateur produit public; ses details internes de harness ne sont pas verifiables depuis les sources publiques consultees.
- `proxy-supported`: la recommandation `--check`/`--json` vient de la logique d'evals et d'automation, pas d'une source disant explicitement que les harness de projet doivent exposer cette option.
- `blocked`: je n'ai pas acces aux donnees internes de performance des harness Anthropic/OpenAI/Kiro/GitHub; les conclusions utilisent leurs publications publiques, pas leurs traces internes.
- `confirmed`: la derive de `docs/agent-harness.md` est locale et observable.

## Conclusion

Etabli n'a pas besoin de plus de ceremonie. Il a besoin d'un meilleur alignement entre ses artefacts, ses scripts et sa memoire. Les sources recentes soutiennent une direction simple: garder le flux actuel, mesurer les comportements critiques, archiver seulement ce qui a ete implemente, et ajouter de l'orchestration uniquement quand le risque ou la duree rendent le single-agent insuffisant.
