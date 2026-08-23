# Synthèse — Direction etabli (4 researchers, web)

- **Date** : 2026-08-23
- **Rapports** : `direction-1.md` (fable-5 medium), `direction-2.md` (opus-5 xhigh), `direction-3.md` (gpt-5.6-sol xhigh), `direction-4.md` (grok-4.6 xhigh) — recherche web exigée (12-14 requêtes chacun), 40+ sources primaires distinctes.
- **Correction factuelle** :  **existe publiquement** (`cursor/plugins/`) ; c'est l'usage qu'en fait etabli (benchmark comparatif de harness) qui n'a aucun précédent externe.

## Convergences (4/4 sauf mention)

### 1. Les guards mécaniques sont la meilleure décision du repo — les garder

L'écosystème converge exactement vers ça : hooks PreToolUse = enforcement déterministe qui tient même sous `--dangerously-skip-permissions` ; un AGENTS.md seul « est parsé, pesé, peut-être suivi ». `planMutationGuardDecision` partagé Pi/Claude est cité comme la forme correcte (politique unique testable, adaptateurs fins). L'étude ETH (arXiv 2602.11988, 138 instances) montre que les fichiers de contexte n'améliorent généralement pas le taux de réussite (+20 % de coût) — **mais** que les instructions qu'ils contiennent sont suivies : utiles pour les pratiques non standard, pas pour les overviews. La prose d'etabli (~5 600 mots noyau, 341 Ko scaffold) est **sur-dosée** (IFScale arXiv 2507.11538 ; Instruction Stacking arXiv 2608.02639 : 96 % → 20 % de suivi quand les instructions s'empilent et conflittent).

**Consensus** : garder le guard, amaigrir la prose (« maps, not manuals » appliqué à soi-même), plafonner la charge scaffold.

### 2. Eval maison : défendable comme régression locale — ne pas migrer vers SWE-bench/Terminal-Bench

- BenchJack (arXiv 2605.12673) : un agent d'exploit atteint ~100 % sur 8 benchmarks majeurs **sans résoudre une seule tâche** — les planchers null/constant publiés par etabli sont exactement le remède recommandé (« run a null agent; if its score isn't zero, something is broken ») ; personne d'autre à l'échelle opérateur ne publie de fabrication floor.
- SWE-bench Verified : abandonné par OpenAI (59,4 % de tests cassés audités ; SWE-bench+ : 32,67 % de cheating). Terminal-Bench mesure le terminal, pas l'adhérence à un contrat — la question d'etabli n'a **pas de benchmark public**.
- Doctrine (Anthropic) : l'outcome est **l'état final de l'environnement**, pas le transcript. Constant 6/8 = 6 cellules encore fabricables ; la prochaine étape est le grading d'état/artefact hors-bande (fichier imposé par la cellule, hashé par l'oracle), pas plus de greps.
- Harness-Bench (arXiv 2605.27922) valide le cadre « capacité = configuration modèle-harness » ; le protocole Nimbalyst (A/B apparié, oracle pré-enregistré, scoring aveugle) est le modèle si un comparatif est un jour relancé.

### 3. Symlinks + catalog TSV : viable, ne pas migrer vers Nix

Pratique courante documentée (home-manager coding-agents, stow/chezmoi patterns) ; même le camp Nix admet que le lien vers un repo vivant est hors du happy path home-manager. La fragilité est dans les **reconcilers shell parallèles**, pas dans le pattern — les durcir fail-closed suffit.

### 4. Le rituel est trop obligatoire — le rendre proportionnel au risque

Consensus 4/4 + données : multi-agent = ~15× les tokens (Anthropic), **-2 à -15 %** sur SWE-bench Verified, single-agent gagne à budget égal ; spec-driven : « pour un petit bug fix, l'overhead ne vaut pas le coup » (Thoughtworks). L'adversary cross-model inconditionnel par changement n'est documenté nulle part comme bonne pratique ; le cross-model reste justifié pour le **high-risk** (et le self-preference bias des juges LLM justifie le cross-family quand on juge). Le repo a déjà la soupape (route plain prompt) — c'est le défaut du rituel qu'il faut changer, pas son existence.

### 5.  live : tuer le protocole de domination — garder le pin structurel

Le gate 138 runs / 23 AHEAD est « un appareil mécanique honnête et inéxécutable aux tarifs frontier » (direction-4). La lane-2 manuelle dit déjà la réponse probable (2 AHEAD / 12 TIE / 1 BEHIND / 8 INCONCLUSIVE — majoritairement des égalités). La comparaison utile est **etabli(t) vs etabli(t-1)** sur ses propres tâches gelées (~10 runs), pas la dominance universelle. Requalifier -live de « bloqué » à « abandonné sauf événement nouveau » (direction-1) — le pin structurel (23/23) reste comme calibration gratuite.

### 6. Priorités consolidées (intersection des 4 rapports)

1. **Sortir les preuves du transcript** (grading d'état/artefact hors-bande) — condition de tout pass@1 live. [prochain chantier mécanique]
2. **Amaigrir la prose + plafonner le scaffold** (C5/C7 repo) — le coût est mesuré, le bénéfice contesté par la littérature.
3. **Rituel proportionnel** : adversary cross-model conditionnel au risque (surface, destructivité, familiarité).
4. **Clôturer -live** officiellement ; canary interne etabli(t) vs etabli(t-1).
5. Ne pas ouvrir : migration Nix, remplacement par benchmarks publics, peuplement de lanes mortes.

## Divergences mineures

- direction-1 accorde plus de valeur aux planchers publiés comme « geste de niveau recherche » ; direction-3/4 insistent sur le plafond restant (6/8) comme erreur de construct validity à corriger avant tout autre investissement. Compatible : publier les planchers **et** migrer vers l'état.
- Q1 : direction-3 voudrait « réduire fortement le domaine d'application » du cycle PLAN (ordinary coding → direct) ; direction-1/2 le formulent en amaigrissement de prose. Les deux convergent sur : le rituel complet n'est pas le défaut.

## Ce que ça change pour les décisions ouvertes du repo

| Décision ouverte | Recommandation consolidée |
|---|---|
| C4 spec↔classifier (ordinary coding) | **Trancher pour l'édition directe** (spec actuelle) — convergent avec « spec-driven pour greenfield/grosses features, pas pour les petits fixes » ; aligner le classifier dessus. |
| C3 reconciler unique | Oui — durcir d'abord (fail-closed fait), table déclarative ensuite. |
| C5 brain/obvault | Non traité par le web (aucun précédent) — décision locale : un resolver scope-aware. |
| C6 split installer | Oui, « la prochaine fois qu'on touche l'installer » (garde fail-closed déjà posée). |
| C9 tiering rituel | **Décidé par consensus direction** : 3 niveaux de risque, cross-model réservé au high-risk. |
| all_zero skills | Annoter l'étagère (l'annonce installer morte déjà retirée) ; ne pas supprimer. |
|  live | Tuer officiellement la dominance ; garder structural. |

## Limites

Aucun run live ; littérature 2025-2026 prépondérante (champ en mouvement rapide) ; qualité hétérogène des sources secondaires (blog/vendeur) utilisées pour la direction du vent, jamais pour les chiffres ; les 4 researchers ont lu des échantillons différents du repo.
