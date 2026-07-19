# Handoff.md - Optimisation Complète du Workflow Etabli (Machine de Guerre Dev 2026)

**Date** : 19 juillet 2026
**Auteur** : Grok (analyse + recherche exhaustive)
**Objectif** : Transformer Etabli en une **machine de guerre** agentique auto-améliorante, harness-aware, avec gains mesurables en productivité, qualité et autonomie.

## Executive Summary

Ton projet Etabli est déjà exceptionnellement mature : PLAN.md strict avec READY gate, adversary reviews, answer-quality audits/traces, self-improvement loops, Pi extensions custom, obvault memory, tests meta-système, ADRs, workflow/spec.md comme contrat canonique.

Les recherches 2026 (Claude Code dominance, Self-Harness paper arXiv:2606.09498, TRACE Stanford, HASE, Meta-Harness, rapports Zylos/Kingy/LogRocket) confirment que l'avenir est dans **l'optimisation du harness** (scaffolding = loops, memory, routing, tools, checks) plutôt que le modèle seul.

**Proposition** : Implémenter un **Self-Harness Loop** natif + multi-model routing + parallelism + metrics avancées. Gains attendus : +15-25% sur qualité/throughput, réduction maintenance manuelle, compounding automatique.

Ce handoff est le blueprint complet. Commité dans `docs/handoff.md`.

## 1. Synthèse des Recherches (Web, X, Reddit, Papers, Blogs 2026)

### Landscape Outils Agentic
- **Claude Code** : Leader pour tâches profondes (SWE-bench ~88-95%, Terminal-Bench haut, hooks/subagents/Dynamic Workflows/computer use). Recommandé pour refactors complexes.
- **Cursor** : IDE rapide + agent mode. Hybride idéal : Cursor daily + Claude/Pi heavy lifting.
- **Standards** : AGENTS.md/CLAUDE.md comme contexte portable (lu par la plupart des tools).
- Consensus communauté (X/Reddit) : Plan-then-Execute, rôles séparés (planner/adversary/verifier), fresh-context reviews, mechanical checks.

### Self-Improving & Harness Optimization (clé pour toi)
- **Self-Harness** (arXiv 2606.09498) : Agent mine traces d'échecs → propose edits minimaux model-specific au harness → valide par regression tests. Gains jusqu'à +21pp sur benchmarks. Pas de prompts génériques.
- **TRACE** (Stanford) : Recurrent failures → synthetic RL environments ciblés sur capabilities manquantes.
- **HASE / Meta-Harness / HarnessX** : Co-évolution modèle + harness via feedback exécution.
- **Autres** : Adaptive Auto-Harness pour task streams open-ended, SEED distillation on-policy.
- X posts (Brian Lovin, Viv @LangChain, etc.) : Teach agents to build verification tools, self-improve skills, point back at itself (meta-skills).

### Best Practices Workflow 2026
- Parallel agents avec git worktrees isolation.
- Budget-aware execution + early stopping + cascading.
- Metrics : tokens per successful outcome, harness improvement rate.
- Skills factory : extraire reusable skills des sessions réussies.
- Human checkpoints aux actions irréversibles.

Ton Etabli aligne parfaitement sur ces tendances (mieux que beaucoup de setups commerciaux).

## 2. Forces Actuelles d'Etabli (à préserver)
- PLAN.md + READY gate + adversary/challenger.
- Answer-quality (audits, traces, coverage, fixtures) — rare et puissant.
- Self-improvement-loop + workflow-retrospect + tests meta-système.
- Pi custom (extensions, router, obvault) — harness minimaliste extensible.
- Neovim + Hunk review surface.
- Scaffolding reproductible + ADRs/plans archive.
- Evidence-based partout (ops-stop, mechanical checks).

## 3. Plan d'Optimisation Détaillé : Etabli 

### 3.1 Self-Harness Loop (Priorité #1 - Impact Max)
Intégrer le pattern du papier Self-Harness dans ton workflow.

**Nouveau skill** : `self-harness-evolve` (ajouter dans `workflow/skills/` et `pi/skills/`).

**Spécification détaillée** (copier-coller dans le skill) :

```markdown
# Skill: self-harness-evolve

## Objective
Améliorer le harness Etabli (spec.md, skills, prompts, router, hooks, checks) à partir des runs passés.

## Steps (exécuter séquentiellement)
1. **Weakness Mining**
   - Analyser : .workflow/ledgers, docs/answer-quality-traces, failed plans, router-eval results, review findings, workflow-metrics.
   - Identifier patterns model-specific (ex: "Opus rate sur multi-file", "router miss sur cas Y").

2. **Harness Proposal**
   - Proposer edits **minimaux** et ciblés :
     - Modifs à workflow/spec.md (routing rules, statuses).
     - Nouveaux/updated skills ou templates.
     - Améliorations prompts/hooks/router.
     - Nouveaux mechanical checks.
   - Format : liste de patches Git-style + rationale.

3. **Proposal Validation**
   - Tester sur held-out fixtures (tes tests existants + nouveaux).
   - Regression sur smoke tests complets.
   - Mesurer : pass rate, tokens/outcome, quality score.

4. **Apply & Archive**
   - Si gain >5% et no regression : apply via edit_file + commit.
   - Archiver proposal + results dans docs/plan/ ou ADR.
   - Mettre à jour workflow-metrics.
```

**Implémentation** :
- Ajouter le fichier `workflow/skills/self-harness-evolve.md`.
- Mettre à jour `workflow/spec.md` pour router `/self-harness-evolve` vers ce skill.
- Ajouter dans `claude/commands/` et `pi/skills/`.
- Lancer manuellement d'abord sur un run récent, puis automatiser dans retrospect.

**Gains attendus** : Harness qui s'améliore seul, comme dans le papier (+10-20% perf sur tes benchmarks internes).

### 3.2 Multi-Model Routing + Parallelisme
- Mettre à jour `workflow/runtime-capabilities.json` et router pour :
  | Tâche | Modèle prioritaire |
  |-------|--------------------|
  | Hard/long-horizon/refactor | Opus 4.8 / Fable equiv |
  | Routine/quick | Haiku / DeepSeek fast |
  | Verification | Multi-model council |

- Ajouter support parallel sessions dans Pi (worktrees isolation, comme recommandé partout).
- Script : `scripts/parallel-agent-launch.sh` pour lancer 3-5 sessions isolées.

### 3.3 Mémoire & Contexte Avancés
- Étendre obvault : semantic recall cross-session (inspiré Mem0 + extensions Pi).
- Standardiser `AGENTS.md` comme source de vérité (ajouter sections pour skills, forbidden patterns, verification rules).
- Nouveau template : `docs/project-context.md` auto-généré par skill.

### 3.4 Metrics Dashboard & Observability
- Étendre `workflow-metrics` et `workflow-retrospect` :
  - Harness improvement rate (avant/après self-harness).
  - Tokens per verified outcome.
  - Answer-quality coverage trends.
  - Capability gap tracking (recurrent failures → TRACE-style).
- Ajouter script `scripts/harness-dashboard.sh` qui génère un rapport Markdown/HTML.

### 3.5 Skills Factory & Mechanical Checks
- Skill `extract-reusable-skill` : après session réussie, analyser et proposer nouveau skill dans `workflow/skills/`.
- Règle : 3e occurrence finding → mechanical check auto (hook ou test).

### 3.6 Hybrid & Scaffolding
- Option Cursor integration pour daily (handoff vers Etabli pour heavy).
- Améliorer `workflow-scaffold` pour inclure Self-Harness Loop par défaut dans nouveaux projets.

## 4. Roadmap Implémentation (Étapes Détaillées)

**Phase 1 (1-2 jours)** :
1. Créer `workflow/skills/self-harness-evolve.md` (copier le template ci-dessus).
2. Mettre à jour `workflow/spec.md` (ajouter route + rules).
3. Commit + lancer test sur un run récent.

**Phase 2 (2-3 jours)** :
1. Implémenter multi-model routing dans Pi router + capabilities.json.
2. Ajouter parallel session support (worktrees).
3. Mettre à jour metrics scripts.

**Phase 3 (1 semaine)** :
1. Enrichir obvault + AGENTS.md.
2. Skills factory + mechanical checks.
3. Tester end-to-end sur 2-3 tâches réelles.
4. Mesurer avant/après (metrics).

**Phase 4 (ongoing)** :
- Automatiser Self-Harness dans retrospect loop.
- Monitor + itérer via tes plans datés.

## 5. Mesures de Succès (KPI)
- +15% throughput (tasks/day).
- +10-20% answer-quality score.
- Harness improvement rate >5% par semaine.
- Réduction manual review time 30%.
- Zéro regression sur smoke tests après edits harness.

## 6. Réflexions Personnelles & Explorations Supplémentaires

J'ai réfléchi en profondeur :
- **Machine de guerre** = harness qui non seulement exécute, mais **evolue comme un organisme** : failure → mining → proposal → validation → apply → measure → repeat. Ton Etabli est déjà le seed parfait.
- Risques : over-optimization (harness bloat) → garder minimalisme Pi + edits minimaux (comme Self-Harness).
- Opportunités : Intégrer SWE-bench style internal evals dans answer-quality pour benchmarker vs état de l'art.
- Playwright dogfood auto plus poussé (tes skills playwright déjà top).
- Linear integration deeper (ticket → plan → implement → auto-update status avec evidence).
- Cost control : ajouter tracking API spend par run.
- Future-proof : Préparer pour modèles 2027 (1M+ context, native tool calling plus fort) en gardant router flexible.
- Équipe : Si team grandit, ce handoff + scaffold rend Etabli scalable (onboarding via AGENTS.md).

Explorations supplémentaires que j'ai faites mentalement :
- Comparaison Pi vs Claude Code pur : Pi gagne en custom control/extensibilité ; combiner via adapters.
- Potentiel pour "Etabli Council" : multi-agent adaptive (scout + judge) pour tasks critiques (déjà dans tes plans multi-model).
- Inspiré X : "teach agent to build its own tools" → skill qui génère nouveaux tools Pi extensions automatiquement.

Ce handoff est vivant : mets à jour avec tes runs futurs.

**Commité** via tool GitHub. Lis `docs/handoff.md` pour détails complets.

Prêt à implémenter ? Dis-moi la phase 1 ou une édition spécifique.
