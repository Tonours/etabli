# Workflows Pi et Claude d'Etabli : analyse du dépôt et recherche croisée

Date : 2026-10-07. Statut : analyse en lecture seule, aucun correctif appliqué ;
les recommandations (§8) sont des propositions, non implémentées.

Méthode : trois lectures parallèles du dépôt (adaptateur Pi, adaptateur Claude,
contrat `workflow/` + outillage + recherches antérieures), deux recherches web
(Pi et Claude Code à date ; projets comparables). Les défauts les plus graves
ont été relus ligne par ligne. Complète, sans les répéter,
`docs/research/20260917-harness-engineering-loops.md`,
`docs/research/20260924-skill-reliability-token-economy.md` et
`docs/research/20260927-harness-practices-audit.md`.

Statut des preuves :

| Section | Statut | Base |
| --- | --- | --- |
| §1 chiffres du dépôt | verified | `wc`, `git ls-files`, `scripts/verify-agentic-infra core`, `bun test` |
| §2-§3 enforcement code vs prose | verified | lecture des hooks, extensions et du cœur `workflow-router-core.mjs` |
| §4 défauts D1-D4, D7 | verified | relus ligne par ligne dans cette session |
| §4 autres défauts | not verified | relevés par lecture déléguée avec `fichier:ligne`, non relus intégralement |
| §5 Pi / Claude Code | confirmed / approximate | docs officielles lues le 2026-10-07 ; points presse marqués `[secondaire]` |
| §6-§7 projets comparables | approximate | READMEs, docs, articles ; étoiles GitHub au 2026-10-07 ; `[secondaire]` signalé |
| §8 recommandations | assumption | effort et impact estimés, pas mesurés |

## 1. Le dépôt en chiffres

| Mesure | Valeur |
| --- | --- |
| Fichiers suivis | 1 117 (533 `.md`, 110 `.mjs`, 108 `.sh`, 74 `.ts`) |
| Contrat `workflow/**/*.md` | 4 502 lignes, ~210k caractères |
| `workflow/runtime/workflow-router-core.mjs` | 1 599 lignes (cœur partagé des gardes) |
| `scripts/` | 135 fichiers, 25 162 lignes (dont `scripts/lib/plan-check-freeze.mjs` 1 861) |
| `tests/` | 256 fichiers, 26 102 lignes |
| Extensions Pi | 2 784 LOC code, 4 348 LOC tests ; `pi/durable` ~1 900 LOC + 1 900 LOC tests |
| Hooks Claude | 13 fichiers `.mjs`, 8 événements câblés |
| ADR | 29 ; archives de plan : 88 (80 IMPLEMENTED, 7 DISCARDED), 2026-08-24 → 2026-10-06 |
| `verify-agentic-infra core` (Linux, clone propre) | 25/33 PASS ; les 8 échecs dépendent de l'environnement (Pi non installé, `tsc` absent, `root` rend un fichier chmod lisible) |
| `bun test pi/extensions/__tests__/` | 437 pass, 1 fail (`typebox` non résolu sans `bun install`) |

Budget de contexte mesuré (`scripts/workflow-context-budget`, chars/4) :
always-on ~3,0k tokens, `plan-loop` 1,6k, `implement` 12,5k,
`plan-implement` 13,9k, `ship` 20,8k. `plan-loop` et `spec-map` sont à 0 de
marge sous leur plafond.

Constat transversal : les 88 archives de `docs/plan/` portent toutes sur le
harnais lui-même (vendoring, routage sémantique Jev construit puis retiré en
~10 jours, économie de tokens, élagage minimal-core, preuves produit). Il n'y a
aucune donnée de résultat sur des projets tiers ; `workflow/self-improvement/review-metrics.md`
ne contient qu'une ligne synthétique « unmeasured ».

## 2. Workflow Pi : ce qui est réellement appliqué

Chaîne : `pi/AGENTS.md` → `workflow/agent-quick-card.md` → `workflow/spec.md`,
puis skills adaptateurs de 18 à 51 lignes (`pi/skills/*/SKILL.md`) qui pointent
vers `workflow/skills/*.md`.

| Règle | Pi classique | Mécanisme |
| --- | --- | --- |
| Routage | prose | `classifyWorkflowRoute` tourne à chaque prompt (`pi/extensions/workflow-router.ts:83-97`) mais le résultat va seulement en `appendEntry` + ledger ; le modèle ne le voit pas (ADR-0014) |
| Gate READY + hash de revue adverse | **code** | `planReadyGuardDecision` (`workflow-router-core.mjs:1288`) via `tool_call` ; statut inconnu = refus |
| Check-freeze | **code** | `planCheckFreezeGuardDecision` (`:1415`), variante Bash (`:1482`) |
| Pas de `PLAN*.md` commité | **code** | garde commit (`:1256`) |
| No-comments | **code** | `workflow/runtime/no-comments-guard.mjs` (diff avant/après) |
| Relecteur lecture seule | **code** (partiel) | seul le Logic hunter tourne isolé : `scripts/pi-review-hunter --no-extensions --tools read,grep` |
| Consentement push/PR | prose | seul `pi/durable/guards.ts:49-81` lie un grant à argv/cwd/cible |
| `ops-stop` | prose | aucune garde ne consomme la route ; `lib/workflow-router-runtime.ts:85` ne sert qu'au type `writeAllowed`, inutilisé |
| No-progress | ledger | enregistré par `scripts/lib/ledger-auto-emit.mjs`, jamais bloquant |
| Un seul écrivain | prose / lease | `scripts/workflow-lease` (ADR-0028) n'est appelé par aucun code Pi |
| Archive + suppression `PLAN.md` | prose | contrainte indirecte : un `PLAN.md` non READY bloque les mutations suivantes |

Orchestration : le contrat déclare « parent-only execution », mais
`pi/agent/settings.json` installe `pi-subagents` et `@zenspc/pi-pstack`
(fan-out), alors que `pi/agent/subagents.json` affiche `maxConcurrent: 0`
(« no subagents package », obsolète) et que `pi/agents/Explore.md:16` cible un
modèle listé dans `retired_pi_models` (`workflow/runtime/model-routing.json:84`).
Les outils mutants issus de MCP ou de paquets (TaskExecute, subagent) sont hors
de `MUTATION_RELEVANT_TOOLS` (`workflow-router-core.mjs:332`) et échappent aux
gardes de plan.

Modèles : défaut `zai/glm-5.3` ; registre `model-routing.json` marqué
« advisory / configured_unverified » ; provenance de la famille adverse
auto-déclarée sur Pi classique, vérifiée seulement dans `pi/durable/reviews.ts`.

## 3. Workflow Claude : ce qui est réellement appliqué

Chaîne : `~/.claude/CLAUDE.md` (= `claude/CLAUDE.md`, 1 960 o) importe
`@~/.pi/agent/AGENTS.md` et `@RTK.md` ; l'adaptateur Claude dépend donc du
déploiement Pi.

| Événement | Hook | Effet |
| --- | --- | --- |
| PreToolUse `Write\|Edit\|MultiEdit\|Bash` | `plan-ready-guard.mjs` | READY + check-freeze + commit (cœur partagé) |
| PreToolUse `Write\|Edit\|MultiEdit` | `no-comments-guard.mjs` | implémentation **propre à Claude** (voir D3) |
| PreToolUse `Bash` | `rtk-guard.mjs` | compaction RTK |
| PostToolUse `Bash` | `ledger-auto-emit.mjs` | `validation_failed` dans le ledger |
| UserPromptSubmit / Notification | `correction-emit`, `notification-classify` | télémétrie ledger |
| SessionStart `compact\|resume` | `session-state.mjs` | réinjecte statut du plan + dernier handoff |
| Stop | `detect-adr-signal.mjs` | relance vers `/adr` |
| PreToolUse (frontmatter agent) | `read-only-agent-guard.mjs` | allowlist Bash pour scout/reviewer/adversary |

Le hook-fragment n'est pas déployé par lien : il faut `scripts/claude-hooks-merge`
(fusion idempotente avec sauvegarde, car `settings.json` peut contenir des
secrets). Profils de lancement `lean / daily / deep / full`
(`scripts/lib/claude-launch.mjs`) ; `lean` mesure 25 692 tokens au premier
appel contre 52 538 en pilote. Sur 30 jours (audit du 2026-10-02) : 11 219
requêtes, entrée médiane 126 731 tokens, 90,8 % des tokens sur Opus, cache
read 98,4 %. Le levier dominant reste la taille de conversation, pas le
contrat (cohérent avec P6 : capsule de contexte plafonnée à 1,45 % de gain).

## 4. Défauts relevés

| # | Défaut | Preuve | Gravité | Statut |
| --- | --- | --- | --- | --- |
| D1 | La rédaction des secrets est sautée quand l'outil échoue : `cat .env; exit 1` arrive en clair au modèle. Aucun test avec `isError: true`. Le hunter (`--no-extensions`) n'a aucune rédaction | `pi/extensions/filter-output.ts:930` | haute | verified |
| D2 | Toutes les gardes de plan se désactivent si `PLAN.md` déclare `- Branch: X` ≠ branche courante ; avant READY l'agent a le droit d'éditer `PLAN.md`, donc peut s'auto-débloquer. Contournement seulement journalisé | `workflow/runtime/workflow-router-core.mjs:1504-1515`, `:1336` | haute | verified |
| D3 | Deux gardes no-comments divergent : Claude scanne tout `new_string`, Pi diffe avant/après. Une Edit qui conserve un commentaire existant est refusée sur Claude, acceptée sur Pi (viole ADR-0006) | `claude/hooks/no-comments-guard.mjs:13-20,79-93` vs `workflow/runtime/no-comments-guard.mjs` | moyenne | not verified (reproduit par la lecture déléguée) |
| D4 | Le hook Stop ADR renvoie `decision: "block"` (force un tour de plus) alors que `claude/README.md:198-202` dit qu'il ne relance pas le tour ; l'idempotence repose sur un schéma de transcript non documenté | `claude/hooks/detect-adr-signal.mjs:126`, `:59-71` | moyenne | verified |
| D5 | Gardes en fail-open : un module manquant, un crash ou un timeout sort en code 1, que Claude traite comme non bloquant. Les hooks d'agents codent `$HOME/.claude/hooks/...` alors que le fragment utilise `${CLAUDE_CONFIG_DIR}` | `claude/scopes/shared/agents/scout.md:15` | moyenne | not verified |
| D6 | `ledger-auto-emit` n'écoute que PostToolUse et infère l'échec par regex sur la sortie (`/exit(?:\s+code)?[=:\s]+(-?\d+)/`) : faux positifs (`grep` qui affiche « exit 1 »), et `PostToolUseFailure` n'est pas câblé | `scripts/lib/ledger-auto-emit.mjs:196` ; aucun `PostToolUseFailure` dans `claude/` | moyenne | verified (absence du câblage) |
| D7 | `ops-stop` n'a aucune garde côté Pi ni Claude, contrairement à la prémisse d'ADR-0007 ; sur Claude il repose sur les permissions natives et le modèle | `grep` sur `claude/hooks`, `pi/extensions`, `pi/durable`, `scripts/lib` | moyenne | verified |
| D8 | `pi/durable` (tests + typecheck) n'est dans ni `agentic-infra-checks.tsv` ni la CI | `workflow/runtime/agentic-infra-checks.tsv`, `.github/workflows/agentic-infra.yml` | moyenne | verified |
| D9 | `pi/extensions/pi-mobile-bridge.ts` est un lien vers `../../../pi-mobile/...` absent : extension cassée sur machine neuve ; `pi/tsconfig.json` dépend du même dépôt voisin | `ls -la pi/extensions/` | basse | verified |
| D10 | Télémétrie inopérante hors etabli : les hooks appellent `scripts/workflow-event`, que le scaffold ne livre pas | `claude/hooks/correction-emit.mjs:12`, `notification-classify.mjs:21` | basse | not verified |
| D11 | Dérives de doc : README RTK (le fragment retire `rtk hook claude`), `RTK.md` jamais déployé, mode bypass décrit comme suivi mais absent du fragment, adversary absent de la liste des agents, « Three upstream suites » pour cinq, Claude sans skill TDD (pstack est Pi-only), carte `skillOverrides` dupliquée octet par octet dans deux fichiers | `claude/README.md:108-112,208-231`, `docs/vendor-skills.md:3`, `claude/profiles/lean.settings.json` | basse | not verified |
| D12 | Pourriture : section « Product Dogfood » dans `PLAN_TEMPLATE_FULL.md:78` après retrait du dogfood ; mentions dogfood dans le cœur (`:912,927`) ; versions `pi/durable` (pi 1.0.0, TS 5.9.3) vs `pi/` (1.0.3, TS 7.0.2) | fichiers cités | basse | not verified |

Points de sur-ingénierie relevés (not verified, à confirmer par mesure) :
`pi/extensions/lib/rtk-runtime.ts` (552 LOC, LRU + cache L1 pour mémoïser un
spawn de quelques ms), `pi-runtime.ts` (276 LOC, `fs.watch` pour une config lue
une fois), un classifieur de ~415 lignes de regex évalué à chaque tour sur Pi
pour une télémétrie non lue par le modèle, et `pi/durable` (~3 800 LOC denses
livrées en deux commits alors que la recherche du 2026-10-01 recommandait de
commencer par une chaîne de revue lecture seule).

## 5. État de l'art : Pi et Claude Code à date

### Pi

- Philosophie d'origine (Zechner, https://mariozechner.at/posts/2025-11-30-pi-coding-agent/) :
  prompt + outils < 1 000 tokens, quatre outils, pas de sous-agents, pas de
  plan mode (« conversation + PLAN.md »), pas de MCP, YOLO par défaut. Le
  billet « Prompts are code, .json/.md files are state »
  (http://mariozechner.at/posts/2025-06-02-prompts-are-code/) est la référence
  la plus proche du design PLAN.md + ledger d'Etabli. confirmed
- Position 2026 plus sceptique : « Thoughts on slowing the fuck down »
  (http://mariozechner.at/posts/2026-03-25-thoughts-on-slowing-the-fuck-down/)
  contre les essaims d'agents et les boucles « ralph », pour limiter le code
  généré accepté par jour. confirmed
- Pi passe chez Earendil (Ronacher) en avril 2026
  (https://mariozechner.at/posts/2026-04-08-ive-sold-out/). 1.0.0 le
  2026-10-01 : TUI plein écran, **MCP natif via Codemode** (revirement,
  https://www.theregister.com/ai-and-ml/2026/10/02/pi-coding-agent-pulls-a-180-and-adds-mcp-support/5300678
  `[secondaire]`), outils MCP différés via `tool_search`, Pi Durable
  expérimental. v1.0.4 au 5 octobre, **v1.1.0 publiée le 2026-10-07**
  (https://github.com/earendil-works/pi/releases) ; Etabli épingle 1.0.3. confirmed
- API d'extension : `tool_call` (bloquer/muter), `tool_result`,
  `before_agent_start`, `context`, `agent_before_settle` (≈ Stop hook),
  `appendEntry` hors contexte
  (https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md).
  Les exemples officiels incluent `plan-mode/`, `subagent/`, `permission-gate.ts`,
  `protected-paths.ts`, `confirm-destructive.ts`, `dirty-repo-guard.ts`,
  `git-checkpoint.ts`, `handoff.ts`. confirmed
- Écosystème : ~5 700 paquets sur https://pi.dev/packages ; les plus installés
  réintroduisent ce que le cœur refuse (pi-mcp-adapter ~1,5M/mois,
  pi-subagents ~583k, todo, plan mode). Plusieurs ports pstack concurrents.
  approximate

### Claude Code

- Best practices officielles (https://code.claude.com/docs/en/best-practices) :
  explorer → planifier → implémenter → commiter ; « si le diff tient en une
  phrase, saute le plan » ; donner un moyen de vérification (prompt, `/goal`,
  Stop hook déterministe, sous-agent vérificateur) ; revue adverse contre
  PLAN.md **mais** avertissement explicite que les relecteurs inventent des
  manques et poussent à la sur-ingénierie. confirmed
- Mémoire (https://code.claude.com/docs/en/memory.md) : CLAUDE.md < 200
  lignes, les `@imports` chargent au lancement (n'économisent rien), règles
  `.claude/rules/` à `paths:` chargées à la demande, `/doctor prompt-audit`
  pour repérer instructions obsolètes ou contradictoires ; le motif
  `CLAUDE.md → @AGENTS.md` est la voie documentée. confirmed
- Hooks (https://code.claude.com/docs/en/hooks) : 33 événements dont
  `PostToolUseFailure`, `SubagentStart/Stop`, `PreCompact/PostCompact`,
  `InstructionsLoaded`, `WorktreeCreate` ; handlers `command`, `http`,
  `mcp_tool`, `prompt`, `agent` ; **exit 2 bloque, exit 1 non**. confirmed
- Plugins et marketplaces (skills + hooks + agents + MCP), workflows
  scriptés (`.claude/workflows/`, « le script décide » vs « Claude décide »),
  `/goal`, `/loop`, routines cloud, sandbox OS, auto mode par défaut. Agent
  teams toujours expérimentales. confirmed
- Ingénierie Anthropic : « Effective harnesses for long-running agents »
  (https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) :
  liste de features **en JSON** où l'agent ne peut changer que `passes`,
  car il altère moins le JSON que le Markdown. « Harness design for
  long-running application development »
  (https://www.anthropic.com/engineering/harness-design-long-running-apps) :
  « chaque composant encode une hypothèse sur ce que le modèle ne sait pas
  faire seul » ; retirer ce qui n'est plus porteur à chaque génération de
  modèle. « Steering Claude Code »
  (https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more) :
  « a real guardrail needs to be deterministic ». confirmed

## 6. Recherche croisée : projets comparables

Étoiles GitHub au 2026-10-07.

| Projet | Mécanisme clé | Étoiles / état |
| --- | --- | --- |
| obra/superpowers (https://github.com/obra/superpowers) | brainstorm → worktree → plan en tâches de 2-5 min → un sous-agent frais par tâche + revue → finish ; TDD strict ; ~15 harnais dont Pi. v6 fusionne deux relecteurs (coût) `[secondaire]` | 296k, actif |
| mattpocock/skills (https://github.com/mattpocock/skills) | skills composables (`grill-me`, `to-spec`, `tdd`, `handoff`) ; « ne possède pas votre process » | 280k |
| github/spec-kit (https://github.com/github/spec-kit) | constitution → specify → plan → tasks → implement → converge | 140k, actif |
| garrytan/gstack (https://github.com/garrytan/gstack) | 23 outils de rôle | 136k |
| Fission-AI/OpenSpec (https://github.com/Fission-AI/OpenSpec) | dossier de change (proposal, deltas ADDED/MODIFIED, tasks) → apply → **archive datée fusionnée dans les specs** | 71k |
| oh-my-openagent (https://github.com/code-yeongyu/oh-my-openagent) | mot-clé « ulw » : read → plan → verify → stop ; tourne sur un fork de Pi | 70k |
| get-shit-done → open-gsd/gsd-core (https://github.com/open-gsd/gsd-core) | discuss → plan (tient dans un contexte frais) → vagues d'exécuteurs → verify → ship ; STATE.md | 64k, **archivé 2026-06**, repris |
| BMAD-METHOD (https://github.com/bmad-code-org/BMAD-METHOD) | allégé en Clarify → Plan → Build-and-verify → Learn ; petits changements directs en build | 54k |
| wshobson/agents (https://github.com/wshobson/agents) | une source Markdown + adaptateurs multi-harnais + **matrice de capacités** | 40k |
| oh-my-claudecode (https://github.com/Yeachan-Heo/oh-my-claudecode) | modes autopilot/ralph/team, état `.omc/`, hooks, `/ask codex` cross-modèle ; « ne pas croire `/goal` sans preuve dans le transcript » | 40k |
| gastownhall/beads (https://github.com/gastownhall/beads) | tracker d'issues en graphe pour agents, `bd ready`, decay mémoire | 28k |
| humanlayer/12-factor-agents (https://github.com/humanlayer/12-factor-agents) + ACE-FCA | research → plan → implement, contexte à 40-60 %, revue humaine sur recherche et plan | 27k |
| compound-engineering-plugin (https://github.com/EveryInc/compound-engineering-plugin) | brainstorm → plan → work → simplify → review → **compound** (`docs/solutions/` relu aux runs suivants) | 25k |
| SuperClaude, ruflo | personas, essaims, « self-learning » sans méthode publiée | 24k, 74k |
| buildermethods/agent-os (https://github.com/buildermethods/agent-os) | v3 **retire** orchestration et sous-agents, délègue au plan mode hôte | 5,5k |
| Kiro specs (https://kiro.dev/docs/specs/) | requirements (EARS) → design → tasks en vagues ; Quick Spec saute les gates | produit |
| Ralph loop (https://ghuntley.com/ralph/) | `while :; do cat PROMPT.md \| claude; done`, une tâche par itération, backpressure tests | essai |

Positionnement d'Etabli, axe par axe :

| Axe | Pratique dominante | Etabli |
| --- | --- | --- |
| Gate de plan | approbation humaine (superpowers, Kiro, OpenSpec) ou plan optionnel (mattpocock, pstack) | **seul** à avoir un statut de plan vérifié par code |
| Critères de succès | Anthropic : JSON, seul `passes` modifiable | check-freeze = même idée généralisée, mais sur Markdown (parseur 1 861 LOC) |
| Revue | relecteur frais par tâche ; cross-modèle chez pstack et oh-my-claudecode | aligné sur le motif le plus fort (frais + adverse cross-famille en high-risk) |
| État / mémoire | fichiers lus au démarrage (Memory Bank, STATE.md, Beads) | ledger JSONL structuré + archive + ADR : plus riche que la moyenne |
| Enforcement | surtout prompt (« mandatory skills ») | hooks/extensions : **en avance** sur la plupart |
| Portabilité | une source + adaptateurs (superpowers, wshobson, OpenSpec) | identique ; la matrice de capacités de wshobson manque |
| Auto-amélioration | auto-écriture (compound, ruflo) | propositions jamais auto-appliquées : plus prudent, cohérent avec les études |
| Budget de contexte | conseils (CLAUDE.md court) | **ratchet** mécanique : rien d'équivalent trouvé |
| Checkpoints humains | aux frontières d'irréversibilité | aligné ; mais `ops-stop` non gardé (D7) |

## 7. Consensus et critiques

Consensus (≥ 4 sources indépendantes) :

1. Séparer réflexion et exécution ; la revue humaine porte sur le plan, pas
   chaque ligne.
2. Contextes frais pour sous-tâches et revues ; compacter dans des fichiers.
3. Les capteurs déterministes battent les instructions
   (https://martinfowler.com/articles/harness-engineering.html, 2026-04-02 ;
   HumanLayer « don't use Claude as a linter »,
   https://www.humanlayer.dev/blog/writing-a-good-claude-md).
4. Empêcher l'agent de modifier ses propres critères de succès.
5. État durable sur disque, relu au démarrage.
6. Fichier racine court + divulgation progressive.
7. Distribution en skills portables multi-harnais.

Critiques documentées :

- Cérémonie disproportionnée : Böckeler
  (https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) voit
  Kiro transformer un petit bug en 4 user stories / 16 critères ; superpowers
  jugé plus coûteux que le fix sur une ligne
  (https://vibecoding.app/blog/superpowers-review). approximate
- Obsolescence de l'échafaudage : agent-os v3 retire son orchestration ;
  Anthropic retire contexte-reset puis sprints au fil des modèles ; la règle
  pratique est « retirer le pilotage, garder les capteurs ». Un routeur
  déterministe fait main est exposé (https://www.traversal.com/blog/ai-agent-architecture-mistakes,
  `[secondaire]`). approximate
- Fichiers de contexte : AGENTbench (https://arxiv.org/abs/2602.11988) les
  trouve toujours plus coûteux en étapes et tokens, effet sur le succès non
  significatif ; Lulla et al. (https://arxiv.org/abs/2601.20404) mesurent
  -28,6 % de temps médian avec AGENTS.md. Les deux soutiennent un contrat
  minimal et mesuré. confirmed
- Aucune preuve rigoureuse qu'un framework de process lourd améliore les
  résultats ; les ablations de scaffolds (https://arxiv.org/pdf/2601.11100,
  https://arxiv.org/pdf/2512.10398) montrent des effets réels mais bruités et
  non isolés pour plan/revue/gate. METR 2025 : -19 % de vitesse perçue +20 %
  (https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/). approximate
- Biais d'auto-évaluation des juges LLM (https://arxiv.org/abs/2404.13076) :
  justifie la revue en contexte frais et cross-modèle. confirmed

## 8. Synthèse et recommandations

Lecture d'ensemble : Etabli est en avance sur l'écosystème pour les capteurs
(gate READY, check-freeze, ledger, ratchet de contexte, revue isolée) et
aligné sur les recommandations Anthropic et Pi pour l'état sur disque. Ses
risques sont ceux que la littérature nomme : cérémonie, routeur fait main qui
vieillit, et surtout une base de code d'outillage (~51k lignes scripts + tests
pour ~9k de contrat) maintenue par une personne, dont la valeur n'est pas
mesurée hors du harnais lui-même.

Priorité 1, sécurité et intégrité des gardes (petits diffs) :

1. D1 : appliquer la rédaction aussi quand `event.isError` ; ajouter un test
   `isError: true` ; donner au hunter une rédaction minimale.
2. D2 : lier la ligne `Branch:` au hash de revue adverse, ou refuser
   l'ajout/modification de `Branch:` par l'agent avant READY.
3. D5 : faire échouer fermé `plan-ready-guard` (try/catch → exit 2 sur erreur
   interne) et utiliser `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` dans les agents.
4. D7 : soit une garde `ops-stop` minimale (push, force-push, `rm -rf` hors
   worktree) via `permissions.ask` natifs côté Claude et `tool_call` côté Pi,
   soit corriger ADR-0007/0014.

Priorité 2, parité et dérive :

5. D3 : faire importer `workflow/runtime/no-comments-guard.mjs` par le hook
   Claude (une seule implémentation).
6. D6 : câbler `PostToolUseFailure` et lire le code de sortie structuré au
   lieu d'une regex sur la sortie.
7. D8 : ajouter `pi/durable` à `agentic-infra-checks.tsv`, ou geler Durable
   tant qu'il n'est pas testé en CI.
8. D4, D11, D12 : aligner README/hooks ; supprimer la carte `skillOverrides`
   dupliquée ; évaluer la mise à jour 1.0.3 → 1.1.x (MCP natif via Codemode
   depuis 1.0).

Priorité 3, mesurer avant d'ajouter :

9. Publier la distribution réelle des routes (part de travail trivial passée
   par `plan-implement`) et le coût par tâche réussie déjà demandé par
   `20260924-skill-reliability-token-economy.md`, sur au moins un projet tiers
   et pas seulement sur Etabli.
10. À chaque changement de génération de modèle, une ablation « pilotage vs
    capteurs » : désactiver une étape de prose (12b, 12c, hunters
    systématiques) sur un échantillon et comparer les défauts échappés.
11. Sur Pi, soit exposer la route au modèle, soit cesser d'évaluer le
    classifieur et le scan obvault à chaque tour (pure télémétrie aujourd'hui).

Idées empruntées aux projets comparables (assumption, à évaluer) :

- Critères de check-freeze dans un bloc JSON/YAML (modèle Anthropic) plutôt
  que dans le Markdown : moins altérable, et un parseur bien plus petit.
- Paquetage Claude en plugin local (hooks, agents, commandes ; skills hors
  plugin à cause de `skillOverrides`) : supprime la fusion manuelle et les
  chemins `$HOME/.claude` codés en dur.
- Matrice de capacités par harnais (wshobson/agents) pour remplacer
  `supports_subagents: unknown` et documenter les écarts Pi/Claude.
- Archive par deltas fusionnés (OpenSpec) si les specs de projet doivent
  survivre au plan.
- `/doctor prompt-audit` dans `verify-agentic-infra` pour détecter les
  instructions obsolètes côté Claude.
