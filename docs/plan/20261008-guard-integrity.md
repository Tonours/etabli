# Implemented: Intégrité des gardes et parité Pi/Claude après l'audit du 2026-10-07

## Metadata
- Archived: 2026-10-08
- Source plan: `PLAN.md` — Corriger les défauts confirmés par l'audit `docs/research/20261007-workflows-pi-claude-benchmark.md` et séquencer le reste en feuille de route
- Source plan SHA-256: `3861565913742eac818aa5b3fa3fc8f298504cb4d77fd74299479820f1c1b289`
- Status: IMPLEMENTED
- Commit / branch: `ba6d7f4`..`ced8fa9` (22 commits) sur `ccr-a9d3198c-x7umes`
- Workflow initiative: none (session cloud éphémère, pas de ledger `.workflow/`)

## Outcome
- **Rédaction des secrets** : `pi/extensions/filter-output.ts` masque aussi les résultats `isError` et retire `structuredContent` brut. Le hunter isolé charge `filter-output.ts` via `-e`, avec un chemin résolu physiquement à travers les liens symboliques. `review-hunter-capture` garde le reçu `isolated_read_grep` avec cette seule extension en plus.
- **Ancrage de branche** : un plan local ne peut plus être ré-ancré vers une autre branche par Write, Edit, MultiEdit, `replace_all` ou un alias de chemin (même inode). Un plan étranger ne lève plus que le gate READY : le check-freeze et la règle d'ancrage restent actifs, et le refus nomme `plan-cleanup --discard`.
- **Gardes Claude en échec fermé ciblé** : si ses modules ne se chargent pas, `plan-ready-guard.mjs` refuse seulement là où une garde est attendue (`PLAN.md` racine, ou jeton push/rm) et nomme le remède ; `read-only-agent-guard.mjs` refuse tout Bash. Les agents résolvent leurs hooks sous `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`.
- **Nouvelle garde `ops-stop` étroite** (`workflow/runtime/ops-stop-guard.mjs`, choix utilisateur) :
  - Elle porte sur trois cas : force-push sans lease, push vers une branche par défaut (y compris `HEAD:main`, `:main`, `--delete`, `--all`, `--mirror`), et `rm -r` qui vise `/`, `~`, `.git`, la racine du projet, une variable non résolue ou un chemin hors projet.
  - Côté Claude, `plan-ready-guard` renvoie `ask`, et `deny` en `bypassPermissions`/`dontAsk`.
  - Côté Pi, `tool_call` passe par `ctx.ui.confirm`, et bloque quand il n'y a pas d'UI.
- **no-comments côté Claude** : il ne refuse plus un commentaire déjà présent dans `old_string` ou sur disque. Une matrice fige les 8 divergences qui restent avec le détecteur partagé.
- **Ledger** : `ledger-auto-emit` ne déduit un échec que d'un signal d'erreur (`isError` côté Pi, `PostToolUseFailure` côté Claude, désormais câblé).
- **CI** : les 63 tests de `pi/durable` qui ne dépendent pas de pi-mobile tournent dans le groupe `pi`, avec `setup-node` v6.5.0 épinglé par SHA, `npm ci` et une entrée dependabot.
- **Doc réalignée sur le code** : `README.md`, `claude/README.md` (hook ADR, RTK, mode autonome, agents, hooks), `docs/vendor-skills.md` et `workflow/contract-details.md` (checkpoints humains, ledger).
- **Hors plan, trouvé en validation** : `claude/hooks/rtk-guard.mjs` jetait une sortie `rtk` valide sur EPIPE, ce qui rendait `claude-hooks-smoke` instable sous charge.

## Context
- `docs/research/20261007-workflows-pi-claude-benchmark.md` §4 (D1-D12) et §8 sont la source du plan.
- La doc hooks Claude (code.claude.com/docs/en/hooks) précise plusieurs points :
  - seul l'exit 2 bloque ;
  - `ask` force une demande en mode auto ;
  - la priorité entre hooks est deny > defer > ask > allow ;
  - `PostToolUseFailure` porte `error` (« Exit code N … ») et `is_interrupt` ;
  - le comportement de `ask` sous `bypassPermissions` n'est pas documenté.
- Pi 1.0.3 : `--no-extensions` garde les `-e` explicites ; `tool_result` conserve les champs omis mais retire `structuredContent` quand `content` est remplacé ; le bash Pi signale un échec par `isError` + `Command exited with code N`.
- `tests/workflow-docs-smoke.sh:404` exige la section `## Product Dogfood` du template complet ; le contrat dogfood est rangé sur l'étagère (`extras/`).

## Decisions
### ops-stop étroit, consentement par la demande native
- Context: aucune garde ne lisait `ops-stop`, alors que le README affirmait bloquer les pushes non consentis.
- Choice: une décision pure partagée, avec son propre tokenizer (redirections, heredocs, commentaires, `cd`/`pushd`, enveloppes, mots-clés, `bash -c`, `eval`, `env -S`, `find -exec`), branchée dans le hook Bash existant et dans `tool_call` Pi.
- Rejected options: garde large (écartée par l'utilisateur) ; export de `splitShellWords` du cœur (renvoie `null` sur les redirections) ; un nouveau processus hook (~70 ms par appel Bash).
- Rationale: le modèle de menace vise les accidents, pas un agent hostile ; demander est la direction sûre dans le doute.
- Consequences: sous le `bypassPermissions` de l'utilisateur, ces actions sont refusées avec « run it yourself in a terminal » jusqu'à vérification de `ask` dans ce mode.

### Le bypass « plan étranger » ne lève que le gate READY
- Context: `git switch -c`, un glob ou une ligne `Branch:` modifiée coupaient aussi le check-freeze.
- Choice: le bypass saute seulement `planReadyGuardDecision` ; la règle d'ancrage refuse le passage d'un plan local vers une autre branche.
- Rejected options: refuser toute édition de `Branch:` (bloque la création et la reprise légitimes).
- Rationale: garde le cas d'usage de `e57dfac` (plan suivi par le working tree entre branches).
- Consequences: écrire un nouveau plan par-dessus un plan étranger READY demande d'abord `plan-cleanup --discard`.

### no-comments : retirer le faux refus, figer les divergences
- Context: déléguer au module partagé changeait des verdicts dans les deux sens.
- Choice: comparaison en multiensemble contre `old_string`/disque ; une matrice de parité fige 8 divergences.
- Rejected options: unification immédiate (R13).
- Rationale: plus petit correctif qui supprime le faux refus sans ouvrir de trou.
- Consequences: deux détecteurs subsistent, documentés et testés.

## Accepted Drift
- Original plan/spec: une tranche = un commit ; ADR d'amendement pour ops-stop ; export de `splitShellWords` ; A5 (dogfood) supposée vraie.
- Implemented reality:
  - 22 commits, un comportement par commit (`workflow/git-contract.md`).
  - Pas d'ADR : le test en trois conditions échoue, car la garde se retire en un commit.
  - Tokenizer propre à ops-stop.
  - A5 infirmée : template et cœur intacts.
  - Fichiers hors Scope In : `scripts/review-hunter-capture`, `tests/review-run-receipt.test.mjs`, `workflow/runtime/source-ownership.tsv`, `pi/extensions/__tests__/workflow-router-extension.test.ts`, `claude/hooks/rtk-guard.mjs`.
  - `read-only-agent-guard` refuse tout Bash en cas d'échec de chargement, ce qui est plus strict que AC-3.
- Why accepted: chaque écart est journalisé au Decision Log du plan source ; aucun n'affaiblit un critère d'acceptation.
- Revue : la passe adverse de plan et la revue code-diff ont été faites par trois relecteurs frais de même famille (Claude Opus 5.5) : Logic, Spec/adversaire, puis un second échantillon. Pas de passe cross-modèle ; l'utilisateur a renoncé explicitement à la passe cross-famille.

## Validation Evidence
- command: `cd pi && bun test ./extensions/__tests__/`
  - result: 448 pass, 0 fail
- command: `bash tests/ops-stop-guard-smoke.sh`
  - result: ok (97 cas, dont les régressions trouvées en revue)
- command: `bash tests/dual-runtime-guard-matrix-smoke.sh`, `bash tests/claude-hooks-smoke.sh`, `bash tests/claude-agents-smoke.sh`, `bash tests/ledger-auto-emit-smoke.sh`, `bash tests/pi-review-hunter-smoke.sh`, `node --test tests/review-run-receipt.test.mjs`
  - result: tous verts ; chaque nouveau test échoue sur le code d'avant
- command: `claude-hooks-smoke` lancé 8 fois en parallèle
  - result: avant le correctif EPIPE, 3 à 5 échecs sur 8 (y compris sur la baseline `b19f08a`) ; après, 8 sur 8
- command: `scripts/verify-agentic-infra pi`
  - result: 7/7, dont durable-tests 63/63 en 88 s
- command: `scripts/verify-agentic-infra core` (cloud, après `bun install` et `npm ci`)
  - result: 34/35 ; seul `ship-order` échoue, préexistant (uid 0 lit un fichier en chmod 000)
- command: `scripts/workflow-context-budget`, `scripts/workflow-ref-linter`, `node scripts/validate-adrs .`
  - result: 8 surfaces dans le plafond (aucune hausse), clean, pass
- command: les deux détecteurs no-comments sur tout le diff `b19f08a..HEAD`
  - result: aucun commentaire ajouté

## Follow-up State
- Remaining risks:
  - AC-4b `blocked` : faire un essai manuel de `ask` sous `bypassPermissions` sur la machine de l'utilisateur. Si la demande s'affiche, on pourra passer de `deny` à `ask`.
  - Pi sans échec fermé quand une extension ne se charge pas.
  - `plan-cleanup --discard` disponible avant READY.
  - `full_output_path` du bash Pi non masqué.
  - Contournements ops-stop obscurs (`coproc`, `watch`, `busybox`, `r\m`).
  - Code de sortie perdu au ledger quand la sortie est entièrement masquée.
  - `scripts/workflow-adapter-sync --check` : 5 échecs préexistants, inchangés.
  - Hooks à refusionner sur la machine : `scripts/claude-hooks-merge` (nouvel événement `PostToolUseFailure`).
- Parking lot: feuille de route R1-R14 du plan source, une `plan-loop` chacune :
  - R1 Pi 1.1.x + versions durable
  - R2 mesures
  - R3 ablations
  - R4 classifieur Pi
  - R5 check-freeze en JSON
  - R6 plugin Claude
  - R7 matrice de capacités
  - R8 `/doctor prompt-audit`
  - R9 deltas de spec
  - R10 découplage pi-mobile (réactive typecheck durable et deux tests)
  - R11 allègement rtk/pi-runtime
  - R12 source unique `skillOverrides`
  - R13 unification no-comments
  - R14 déploiement `RTK.md`
- Superseded docs/specs: none
- Next links: `docs/research/20261007-workflows-pi-claude-benchmark.md`
