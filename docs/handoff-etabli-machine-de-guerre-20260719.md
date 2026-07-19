# Etabli Handoff - Machine de Guerre Dev Workflow

**Date:** 19 juillet 2026
**Auteur:** Jack (via recherche + analyse autonome)
**Objectif:** Transformer Etabli en un harness agentic self-improving, compounding, multi-modèle, hautement observable et reproductible – une vraie 'machine de guerre' pour le software engineering de haute qualité.

## Executive Summary

Etabli est déjà parmi les setups les plus matures que j'ai vus : PLAN.md strict + READY gate + adversary + answer-quality traces/audits/coverage + Pi custom runtime + Neovim hunk review + Obvault + self-improvement loops + tests meta-système exhaustifs.

La recherche 2026 (Self-Harness arXiv:2606.09498, HASE, RHO, AHE, Harness Optimizer, etc.) confirme que le levier principal est l'**optimisation du harness** plutôt que le modèle seul. Gains de 20-60% sur Terminal-Bench sans changer le modèle.

Proposition : implémenter un **Self-Harness Loop** natif + multi-model routing intelligent + observability avancée + hybrid Cursor/Claude Code/Pi pour un workflow compounding autonome avec gates humains minimaux.

## Synthèse Recherche (Web, arXiv, X, blogs - juillet 2026)

### Self-Harness (Hangfan Zhang et al., Shanghai AI Lab, juin 2026)
- Boucle 3 étapes :
  1. **Weakness Mining** : analyser traces d'exécution échouées pour patterns *model-specific*.
  2. **Harness Proposal** : générer edits minimaux, concrets, ciblés (pas de prompts génériques).
  3. **Proposal Validation** : regression tests sur held-in + held-out ; n'appliquer que si amélioration + pas de régression.
- Résultats : +21pp à +33-60% relative sur Terminal-Bench-2.0 pour différents modèles.
- Clé : edits model-specific et safe.

### Autres papiers pertinents
- **HASE** (Harness-Aware Self-Evolving) : co-évolution modèle + harness + solutions.
- **RHO** (Retrospective Harness Optimization) : optimisation via self-preference sur trajectoires passées.
- **AHE** : observability-driven (component, experience, decision).
- **StructAgent** : état structuré vérifié par evidence au lieu d'historique brut.
- **Harness Optimizer**, Hill-Climbing, etc. : traiter le harness comme paramètres optimisables.

### Benchmarks & Landscape 2026
- Claude Code domine pour agentic terminal/deep work (hooks, subagents, Dynamic Workflows).
- Cursor excellent pour IDE interactive + Cloud Agents.
- Consensus : hybrid Cursor (daily) + Claude Code/Pi (autonomous heavy) + Codex (parallel).
- Proxies (CLIProxyAPI, claude-code-router) permettent multi-modèle dans le même harness puissant de Claude Code.

### Community (X)
- Multi-model dans Claude Code via proxies (Fable planning + Sol execution).
- Orchestration parallèle, worktrees pour isolation.
- Focus sur harness > modèle.

## Forces Actuelles d'Etabli (analyse repo)
- Contrat canonique `workflow/spec.md` très mature.
- `PLAN.md` + statuts + guards (plan-ready-guard, ops-stop, adversary).
- Answer-quality (traces, audits, coverage, fixtures, evals).
- Pi/extensions (workflow-router, tasks-till-done, obvault-topic-resolver, rtk, tests exhaustifs).
- Claude commands/hooks/skills + Neovim hunk review.
- Scripts deploy/scaffold, tests meta, retrospects, self-improvement-loop existants.
- Obvault comme second brain.

Vous êtes déjà en avance sur 90% des setups.

## Plan d'Implémentation - Machine de Guerre

### Phase 1 (Priorité haute - 1-2 jours) : Self-Harness Loop natif
Créer skill/command `self-harness-evolve` (dans Pi et Claude) :
1. Mining : parser answer-quality-traces + workflow ledgers + failed plans + router misses.
2. Proposal : edits minimaux sur spec.md, skills, router, hooks, prompts (model-specific si routing multi-modèle).
3. Validation : run smoke-tests, router-eval, answer-quality-eval, fixtures regression. Human gate final.
4. Apply + commit + update metrics.

Ajouter tracking `harness-improvement-rate` dans workflow-metrics.

### Phase 2 : Multi-Model & Orchestration Avancée
- Intégrer proxy (CLIProxyAPI ou équivalent) via scripts.
- Pi router intelligent : task classification → model optimal (reasoning heavy → Opus/Fable, execution → Sol/GPT, fast/cheap → Haiku, fallback Kimi).
- Sub-agents avec effort controls et budget-aware.
- Parallel sessions via git worktrees.

### Phase 3 : Observability & Memory
- Dashboard metrics (tokens/outcome, answer-quality trends, harness delta, cost).
- Obvault enhancements : semantic cross-session recall, topic-aware routing renforcé.
- Structured state (inspiré StructAgent) pour long-horizon tasks.

### Phase 4 : Hybrid & Scaling
- Recommandations Cursor comme frontend IDE + handoff seamless vers Etabli/Pi/Claude Code.
- Skill factory auto-extraction des sessions réussies.
- Support team : scaffold + shared contracts.

### Fichiers à créer/modifier (détails précis)
- `pi/skills/self-harness-evolve/` + SKILL.md + scripts.
- Mise à jour `workflow/spec.md` avec section Self-Harness.
- `scripts/self-harness-loop.sh` ou intégration dans workflow-retrospect.
- `docs/harness-metrics-dashboard.md` ou script.
- Update AGENTS.md, CLAUDE.md, Pi models.json, router.

## Mesure de Succès
- Harness improvement rate > 5-10% par itération sur evals internes.
- Réduction temps review, tokens/task, erreurs.
- Autonomous loop pass rate sur fixtures/scénarios.
- Benchmark interne proche Terminal-Bench/SWE.

## Prochaines Étapes Immédiates
1. Créer le skill Self-Harness.
2. Tester sur traces existantes (202607 plans).
3. Ajouter routing multi-modèle.
4. Run full smoke + eval.

Ce handoff transforme Etabli en système qui **s'améliore lui-même de façon mesurable et sûre**. C'est la direction de la recherche 2026 appliquée à ton setup déjà exceptionnel.

Commit prêt. Dis-moi pour push ou itérer !

---
Références clés incluses dans le doc complet (liens arXiv, VentureBeat, etc.).