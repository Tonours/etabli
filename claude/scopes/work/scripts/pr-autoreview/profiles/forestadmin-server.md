# Profil de review — forestadmin-server (ForestAdmin/forestadmin-server)

## Stack et commandes

- **yarn 1.22.19**, monorepo Lerna + workspaces (`package.json:79-82,116,166`). Node **22.12.0** (`package.json:165-167`, `packages/private-api/package.json:86-88`).
- **Tests : Jest**, suites séparées par domaine — `test:misc`, `test:ai`, `test:routes`, `test:services`, `test:stores`, `test:unit`, `test:externals` (`packages/private-api/package.json:54-72`). Racine : `lerna run test` (`package.json:64`).
- **Lint** : ESLint 8 + `airbnb-base`/`airbnb-typescript`, `sonarjs`, `import`, `filenames`, `unused-imports` (`.eslintrc.ci.js:9-19,46`). Par package : `eslint --config=.eslintrc.ci.js --quiet --cache --cache-strategy content .` (`packages/private-api/package.json:76`). Prettier : `prettier --config ../../.prettierrc.json --check .` (`:78`).
- **Build** : `tsc` par package (`packages/private-api/package.json:24-27`), orchestré par `lerna run build` (`package.json:56-59`).
- **Serveur** : Express 4 (`packages/private-api/package.json:129`), Sequelize 6 + PostgreSQL (`:156,162`), migrations via `sequelize-cli` (`:163`, scripts `db:migrate*` `package.json:72-75`).

## Architecture

- Packages : `private-api` (cœur métier), `public-api`, `server`, `cloud-gateway`, `cloud-agent-manager`, `common`, `ai`, `ai-mcp`, `private-agent-api`.
- Dans `private-api/src` : `routes`, `middlewares`, **pas de `controllers`** — les routes appellent directement `services`/`domain`, avec `fetchers` en couche intermédiaire (`.claude/examples/code-patterns.md:38-92`).
- **Injection de dépendances par convention de nommage** : les factories reçoivent `{ assertPresent, ...deps }` et s'enregistrent dans un `context` (`context/build-business-services.js`, `context/build-fetchers.js`). Chaque service/middleware/fetcher fait `assertPresent({...})` en entrée (`code-patterns.md:12,42,106`).
- **Erreurs métier** : hiérarchie `BusinessError` dans `src/utils/errors/*-errors.ts`, un fichier par domaine (41 fichiers).
- **Chaîne HTTP** : `errorTranslator` (`src/utils/error-translator-http.ts:47-88`) mappe classe d'erreur → constructeur HTTP, branché dans `src/make-configure-rest-errors.js:18-32` — validation OAuth (`:21`), `catchErrorsValidation` (`:23`), `errorsBusiness.catch` (`:26`), `scimErrorsHandler` (`:27`), `catchExpectedError` (`:28`), `catchUnexpectedErrors` en dernier filet (`:31`).
- **Migrations** : `packages/private-api/migrations/*.js`, nommage `YYYYMMDDHHMMSS-slug.js`, `up`/`down` exposés (`migrations/20250716081955-add-inbox-type-to-layout-changes.js:6-70`).

## Conventions vérifiées

- **Nommage de fichiers imposé par ESLint** `filenames/match-regex` selon le dossier : routes `^[-a-z]+-route$`, stores `^[-a-z]+-store$`, serializers `^[-a-z]+-serializer$`, deserializers `^[-a-z]+-deserializer$`, migrations `^20[0-9]{12}-[-a-zA-Z0-9]+$`, erreurs `^[-a-z]+-errors$` (`packages/private-api/.eslintrc.ci.js:130-182`).
- **`bluebird` interdit** explicitement — « Use native promises » (`.eslintrc.ci.js` racine `:163-173`, package `:47-84`). Tout `bluebird` dans un diff est un signal.
- **Imports internes par la racine du package**, jamais `dist`/`src` (`no-restricted-imports` sur `@forestadmin/*`).
- **Migrations isolées** : `import/no-restricted-paths` interdit d'importer `models`, `services`, `utils` (sauf `migrations-tools.js`) depuis `migrations/` — elles ne doivent pas dépendre de code qui change (`packages/private-api/.eslintrc.ci.js:96-118`).
- **`no-explicit-any`** : `warn` dans private-api (`.eslintrc.ci.js` package `:27`) mais `error` à la racine (`:71-76`). Divergence vérifiée.
- **Erreur métier** = classe étendant `BusinessError` (`src/utils/errors/common-errors.ts:4-15`), une sous-classe par cas.
- **Tests** : `makeContext()` fabrique tous les mocks Jest (`liana-permission-v4-cache-service.unit.test.ts:10-34`), instanciation manuelle avec cast (`:40-41`), assertion que `assertPresent` reçoit les deps (`:44`), AAA par `it` (`:50-72`). Nommage `*.unit.test.ts` pour l'unitaire isolé, `*.test.ts` pour route/service.
- **Migrations transactionnelles** : `transactionWithLock(queryInterface, async () => {...})` (`migrations/20250716081955-add-inbox-type-to-layout-changes.js:8,40`). Contre-exemple documenté (transaction Sequelize sans passer `{transaction}` à la query) dans `.claude/examples/code-patterns.md:187-205`.

## Cas tricky

1. **Runtime Joi ≠ types** (kb `private-api-joi-15`) — `private-api` tourne sur Joi 15.1.1 embarqué par `celebrate@10.1.0`, mais les types installés sont `@types/hapi__joi@17`. `.greater()` doit partir de `Joi.date()`, pas `Joi.string()`, sinon crash au chargement du module. Signature diagnostique : tout ce qui boote le contexte crashe, les suites isolées passent. `src/domain/bff/bff-api-keys-validator.ts:65`.
2. **`loadFixtures` fait un DROP** (kb `test-loadfixtures-drop`) — `sync({force:true})` sur deux connexions : un second `FixtureBuilder`/`loadFixtures` dans le même test DROP ce que le premier a seedé, y compris la session JWT du caller → 401 trompeur au lieu du 403/422 attendu. `test/helpers/load-fixtures.js:105-112,148-153`.
3. **Replay de migration d'enum non idempotent** (kb `migration-enum-replay`) — `ALTER TYPE ... ADD VALUE` sans `IF NOT EXISTS` : rejouer `up` sans repasser par `down` casse. Après un squash, `SequelizeMeta` peut garder un enregistrement fantôme bloquant `db:migrate:undo`. `migrations/helpers/premium-feature.js:106,111,119,176,202,222`.
4. **Permissions v4 : jamais de flag booléen individuel** (kb `forest-permissions-v4`) — le serveur n'émet jamais `true` pour un droit CRUD isolé, seulement `{roles:[...]}` (sauf réponse `/environment` entière si `areRolesDisabled`). Un `true` littéral sur un droit individuel casse le contrat client. `src/services/liana-permission-v4-service.ts:23-34`.
5. **Fidélité au bug amont côté fork** (kb `bff-fork-fidelity-over-robustness`) — le fork d'évaluateur de permissions dans `agent-bff` reproduit délibérément un crash amont ; « corriger » localement casse le drift-gate. Concerne `agent-nodejs`, mais toute PR alignant les deux comportements doit vérifier ce précédent avant de durcir un cas similaire ici.

## Ce qu'on NE commente PAS

- **`no-explicit-any` en `warn`** dans private-api (`.eslintrc.ci.js` package `:27`) — divergence assumée vs la racine, pas un oubli à signaler PR par PR.
- **`sonarjs/no-duplicate-string`, `no-identical-functions`, `no-nested-template-literals` désactivées** dans private-api (`.eslintrc.ci.js:86-88`) — ne pas relever la duplication de chaînes/fonctions.
- **Fichiers `.js` legacy** : le override racine désactive `no-unsafe-*`, `no-var-requires`, `restrict-*`, `return-await` (`.eslintrc.ci.js:304-327`). Code pré-TypeScript, ne pas demander sa migration dans une PR non liée.
- **`no-console` autorise `debug/info/warn/error`** (`.eslintrc.ci.js:147-152`) — usage volontaire, pas un `console.log` oublié.
- **`migrations/*.js` désactive `no-console`** (`packages/private-api/.eslintrc.ci.js:171`) — logs de migration attendus.

## Signaux de review prioritaires

1. **Migration d'enum ou de colonne sans `down` idempotent, ou sans wrapper transactionnel/lock** — casse un déploiement en prod sans se voir en CI locale à un seul run. Vérifier `transactionWithLock` (ou transaction explicite) et un `down` symétrique.
2. **Import de `bluebird` ou import direct depuis `dist`/`src` d'un `@forestadmin/*`** — interdit par ESLint, mais un cache lint non invalidé peut le laisser passer.
3. **Nouvelle classe d'erreur métier non mappée dans `error-translator-http.ts`** — une `BusinessError` sans branche dans le switch (`src/utils/error-translator-http.ts:50-85`) tombe dans `catchUnexpectedErrors` et remonte en 500 générique. Passe les tests unitaires, casse le contrat HTTP en intégration.
4. **Deux `FixtureBuilder`/`loadFixtures` dans le même test** — instable en CI, symptôme typique : 401 inattendu sur un test cross-projet.
5. **Modification de `/liana/v4/permissions/*` introduisant un `true` littéral sur un droit CRUD individuel** — rupture de contrat frontend, aucun test serveur ne la détecte.
