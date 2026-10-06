# Implemented: Identité de contrat produit stable entre alias de chemin

## Metadata
- Archived: 2026-10-06
- Source plan: `PLAN.md` — Identité produit stable entre alias de chemin — canonicalisation plan-dir + WORKFLOW_EVENT_PROJECT_ROOT
- Source plan SHA-256: `870ec01f9d23012116b075d9c1a2fd41a65f1416df6c4919be3ba611aa4fea5c`
- Status: IMPLEMENTED
- Commit / branch: `96959324` sur `fix/product-contract-alias-identity` (merge main + push à la suite)
- Workflow initiative: `.workflow/contract-alias-identity/` (ledger complet)

## Outcome
- L'identité de contrat produit (`productContractIdentity`) est désormais identique que le dépôt soit accédé par son chemin canonique (`/Volumes/Crucial/work/etabli`) ou par un alias symlink (`/Users/tonours/work/etabli`).
- Les comparaisons de chemin d'archive dans `workflow-event` ne dépendent plus du `$PWD` d'appel.
- Cause racine (trouvée pendant l'essai TesterArmy, trois clôtures mortes) : `frozenProductContract` résolvait `pack` via `resolve(dirname(planPath), …)` sans suivre les symlinks, et `workflow-event` exportait `WORKFLOW_EVENT_PROJECT_ROOT` brut.

## Context
- Symptôme mesuré : `29d5b0bd…` (canonique) vs `7755f537…` (alias) — seul le champ `pack` différait (`subjectRoot` était déjà realpath).
- Le garde runner (`project-verification-run.mjs:66-69`) échouait aussi sous alias (pack alias vs root canonique) — réparé par le fix.

## Decisions
### Canonicaliser le planDir seul, jamais le pack
- Context: le pack peut ne pas exister à la construction du contrat ; canonicaliser le pack suivrait les symlinks internes sous `.workflow/` et casserait le confinement lexical du garde runner + son test core (`project-verification-run.test.mjs:93-116`).
- Choice: `planDir = realpathSync(dirname(planPath))` ; `pack = resolve(planDir, declaration.pack)` (lexical) ; comparaison bilatérale `realpathSync` dans `checkProductContract`.
- Rejected options: helper `canonicalPath` best-effort (3 rounds de review pour l'écarter — suit les ancêtres symlinkés) ; realpath du pack direct (pack absent au build).
- Rationale: l'identité reste lexicale sous le planDir canonique ; les symlinks internes ne fuient jamais dans l'identité ; le garde garde son message exact.
- Consequences: le packPath alias (relatif ou absolu) est accepté à la comparaison sans jamais affaiblir `assertProductIdentity` (relit les octets à l'emplacement déclaré).

### Canonicaliser WORKFLOW_EVENT_PROJECT_ROOT une fois au démarrage
- Choice: `cd "$valeur" >/dev/null 2>&1 && pwd -P` avec fallback valeur brute (idiome maison :509,511,803).
- Rationale: les deux résolutions de `.path` (l.26 et l.748) partent de la même racine canonique → la comparaison de chemins d'archive devient indépendante du cwd.

## Accepted Drift
- Original plan (v1-v3): helper `canonicalPath` best-effort — abandonné en v4 sur P2 opus (symlinks internes suivis, test core cassé, hors bornes).
- Lettres du plan vs livraison : `test/` vs `tests/` (suivi la convention du repo), `orchestrate.mjs` vs `orchestrator.mjs` (idem) — écarts de lettre équivalents documentés dans l'essai précédent.

## Validation Evidence
- `node --test tests/project-verification-check.test.mjs` → 124/124 (dont le nouveau test alias : identités égales, pack canonique, subjectRoot canonique, `checkProductPlan` via plan alias + pack alias → passed)
- `node --test tests/project-verification-run.test.mjs` → 42/42 (garde runner intacte)
- Smoke : `workflow-event-smoke.sh` ok, `project-verification-check-smoke.sh` exit 0
- Review machine : T1 BLOCK (2 findings test) → T2 GO zéro finding (codex f11a7596) → F1 GO zéro blocker (opus f10a5786, suites re-exécutées vertes)

## Follow-up State
- Remaining risks: pas de test automatisé de l'alias dans workflow-event (vérifié par sonde isolée) ; trou préexistant du pack-mismatch non testé ; ledgers/receipts pré-fix enregistrés via alias échouent fermés à la revalidation (fail-closed, sûr) ; CDPATH relatif = risque idiomatique préexistant.
- Parking lot: test e2e workflow-event alias (archive_written via alias → completed via canonique) ; test du pack-mismatch.
- Superseded docs/specs: `docs/plan/20261005-testerarmy-trial.md` (essai dont ce fix est issu).
- Next links: aucun — fix autonome.
