# Analyse du setup E2E et QA produit

Audit du 3 octobre 2026. Verdict : **pilote auth/profil verified ; confiance dans la CI blocked** tant que ses codes d'échec sont masqués. Les assertions navigateur et les preuves conservées apportent une base utile. La couverture reste limitée et le checker commun accepte quelques états incohérents.

Périmètre : ajout Etabli `ed8b6aa4`, intégré dans le worktree dédié au commit `8b523a54`, et satellite AdonisJS Starter `55e72e8`. Inspection du code, preuves locales conservées, tests déterministes et injections contrôlées. Aucun nouveau parcours navigateur, modèle ou service lancé ; les parcours réels cités datent du 2 octobre. Aucune correction applicative réalisée.

## Findings, par priorité

**P1 — Les wrappers CI masquent les échecs des suites.** Dans [integration.sh:12](/Volumes/Crucial/work/adonisjs-starter/scripts/ci/integration.sh:12) et [checks.sh:12](/Volumes/Crucial/work/adonisjs-starter/scripts/ci/checks.sh:12), chaque commande parallèle est suivie d'un `echo ... ok`. Les scripts utilisent `set -uo pipefail`, sans propager explicitement le statut de cette commande ; le sous-processus retourne donc celui de l'echo. `collect()` attend ce zéro et conserve `FAILED=0`.

Reproduction : cinq commandes d'intégration retournent toutes **7**, le wrapper retourne **0** ; la même injection sur les neuf commandes du wrapper de contrôles retourne aussi **0**. PostgreSQL, mail, tooling, E2E, Docker, build et scans peuvent donc échouer sans rendre leur job rouge. Défaut préexistant depuis `0ee7f568` du 14 septembre, antérieur au nouveau pilote. Le `pnpm quality` local utilise une chaîne `&&` distincte et conserve ses échecs. Prochaine correction : retenir puis retourner le statut réel de chaque branche, et vérifier qu'une branche rouge rend le wrapper rouge tout en collectant ses voisines.

**P2 — Le checker accepte des contrôles UI explicitement échoués.** [project-verification.mjs:48](/Users/tonours/.codex/worktrees/e2e-setup-audit/etabli/scripts/lib/project-verification.mjs:48) accepte `mode: ui`, mais la validation ne contrôle ensuite ni `pack.ui.checks`, ni les viewports. Sur une fixture valide, huit checks UI `failed`, des preuves vides et zéro viewport avec responsive/motion/référence en scope donnent **`status: passed`**. Le schéma valide leur forme, pas leur réussite. Le producer Starter actuel exporte `mode: product` : cette faille concerne un futur producer UI, sans régression auth/profil démontrée. Exiger des contrôles et preuves correspondant au périmètre UI, ou refuser ce mode tant que ces garanties manquent.

**P2 — Un reçu de clôture peut être écrit après une modification de source.** Après son `await`, [project-verification.mjs:125](/Users/tonours/.codex/worktrees/e2e-setup-audit/etabli/scripts/lib/project-verification.mjs:125) recontrôle plan, archive et pack, sans relire la source. Mutation immédiate de `app.txt` après l'appel au helper : il écrit un reçu avec **`passed`**, puis la revalidation de ce même reçu rejette **`Source content changed: app.txt`**. [plan-cleanup:112](/Users/tonours/.codex/worktrees/e2e-setup-audit/etabli/scripts/plan-cleanup:112) utilise ce helper et supprime ensuite le plan sans nouveau contrôle source. La suppression effective sous cette race reste **not verified** ; le reçu périmé est reproduit. Le gate terminal revalide et bloque ce reçu. Recontrôler la source à la frontière de finalisation réduirait cette fenêtre.

**P2 — Les traces navigateur ne sont pas publiées au bon endroit.** [playwright.config.ts:25](/Volumes/Crucial/work/adonisjs-starter/apps/web/playwright.config.ts:25) active `list` et `github`, avec traces/vidéos conservées à l'échec, mais aucun reporter HTML. [ci.yml:82](/Volumes/Crucial/work/adonisjs-starter/.github/workflows/ci.yml:82) tente uniquement d'exporter `apps/web/playwright-report`. La configuration n'exporte pas le répertoire `apps/web/test-results` contenant les traces/vidéos. Observation statique ; aucun échec de navigateur CI provoqué. Exporter les résultats réellement produits et vérifier leur présence sur un échec contrôlé. Le défaut P1 peut aussi empêcher cette étape `failure()` de s'activer.

**P3 — Une promesse de persistance peut rester sans preuve.** [project-verification.mjs:103](/Users/tonours/.codex/worktrees/e2e-setup-audit/etabli/scripts/lib/project-verification.mjs:103) contrôle la persistance seulement lorsque l'AC impose `side_effect`. Un scénario déclarant `side_effect_expected: true` avec `side_effect_evidence: []` passe si l'AC exige uniquement `action,result`. Incohérence du pack reproduite ; les producers auth/profil actuels conservent leur preuve SQLite. Rejeter cette contradiction sans étendre artificiellement les obligations du plan.

## Ce qui fonctionne

Le parcours partagé est : recette Claude/Pi → supervisor propriétaire → snapshot des sources → API/Vite, SQLite jetable et Mailpit local → doctor → drivers Playwright auth/profil → nettoyage → `qa.json` et `evidence-pack.json` → checker Etabli → archive et contrôle terminal.

Les modèles lancent la même recette ; les drivers portent les assertions déterministes. Le nouveau setup ne nécessite pas une réimplémentation du runner pour chaque harness. L'auth teste refus des mauvais identifiants, login après reload, cookie local et révocation du token après logout. Le profil teste édition après hydratation, reload, lecture SQLite et absence de mutation sur entrée invalide. Les erreurs navigateur et captures échouées font échouer la preuve.

Le checker relie AC gelés, chemins/hash/modes de source, ref Git, empreinte d'environnement, artefacts et reçus des phases. Les ressources appartiennent au run ; les données de développement sont préservées. La preuve protège un workflow local coopératif ; elle ne constitue pas une attestation contre un processus malveillant du même utilisateur.

## Couverture et limites

| Couche | Couverture observée | Limite |
| --- | --- | --- |
| Nouveau pilote | Auth et profil ; actions, résultat et persistance | Signup/reset/mail, organisations/invitations, API keys et billing demandent d'autres preuves exécutables |
| Suite Playwright existante | 18 tests déclarés, Chromium desktop | Vite dev et SQLite ; aucune nouvelle exécution pendant cet audit |
| Qualité globale | Japa, PostgreSQL, mail, Docker et scans restent distincts | Un job CI vert ne suffit pas à cause de P1 |
| Environnement du pilote | Snapshot local, database jetable, cookies HTTP locaux | Production/HTTPS, responsive, autres navigateurs, concurrence et isolation d'autorisation restent not verified par ce pilote |

L'activation produit est déclarative : [PLAN_TEMPLATE.md:75](/Users/tonours/.codex/worktrees/e2e-setup-audit/etabli/PLAN_TEMPLATE.md:75) conserve `Required: no` par défaut. Le mapping `--auth AC-ID --profile AC-ID` est explicite ; le checker assure la couverture des IDs, tandis que la pertinence du parcours pour le texte métier reste à revoir. Les recettes des autres fonctionnalités sont des instructions disponibles, pas des preuves d'exécution. Les gains de temps de QA humaine ne sont pas mesurés.

## Validation et artefacts

- Validation fraîche : `node --test tests/project-verification-check.test.mjs` depuis le nouveau worktree : **68/68 passed**, zéro skipped, **20,729 s**. TypeBox vient du runtime Pi géré déjà installé ; aucun bootstrap vierge testé.
- Validation fraîche satellite : `node --test scripts/tests/verify-starter-evidence.test.mjs` : **8/8 passed**. Ces 76 tests valident les mécanismes de preuve, pas 76 parcours produit.
- Revalidation fraîche du reçu `evidence-pack.json.completion.json` contre l'archive `20261002-source-bound-product-qa.md` : **exit 0, passed**, `AC-03` et `AC-04`. Run `trust-claude-publish-final-20261002`, source SHA-256 `7c8b52635d36fe32960f927746239b07b898dfc31d5c91715e4b15216583ace3`.
- Preuves réelles du 2 octobre relues : `final-native-parent-inspection.json`, `qa.json`, résultats auth/profil et cleanup Claude/Pi : chaque phase **exit 0**, état arrêté, Mailpit supprimé. `final-negative-assertion.json` : **QA 1 / profile 1 / checker 1 / cleanup 0**. Ce contrôle négatif conserve son échec.
- Reproductions de cet audit : [ci-false-success.json](../../.workflow/e2e-setup-audit-20261003/ci-false-success.json), [reproduce-ci-false-success.py](../../.workflow/e2e-setup-audit-20261003/reproduce-ci-false-success.py), [gates-repro.jsonl](../../.workflow/e2e-setup-audit-20261003/gates-repro.jsonl), [gates-repro.mjs](../../.workflow/e2e-setup-audit-20261003/gates-repro.mjs). Les fixtures sont jetables ; leurs succès inattendus prouvent les angles morts du checker, pas un succès applicatif.
- Sources historiques vérifiées localement : [archive](../plan/20261002-source-bound-product-qa.md), `.workflow/trust-qa-publish-close-20261002/final-native-parent-inspection.json`, `.workflow/trust-qa-publish-close-20261002/final-negative-assertion.json` dans le checkout principal Etabli. Le nouveau worktree ne reprend pas automatiquement ses artefacts ignorés.
- Obvault consulté : abstention lexicale, sémantique indisponible ; aucune conclusion fondée sur ce miss. Le contexte historique a été recoupé avec les fichiers et reçus actuels.

État final : rapport et preuves d'analyse seulement, checkout principal et satellite préservés. Priorité : corriger la propagation des échecs CI, puis durcir les gates et les artefacts ; étendre ensuite les parcours selon les fonctionnalités réellement changées.
