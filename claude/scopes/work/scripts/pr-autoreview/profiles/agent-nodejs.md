# Profil de review — agent-nodejs (employer/agent-nodejs)

## Stack et commandes

- Gestionnaire : **yarn 1.22.19** (`package.json:4`). Monorepo **Lerna + yarn workspaces** (`package.json:52-55`, `workspaces: ["packages/*", "packages/workflow-executor/example"]`).
- Node : `.nvmrc` = `24.10`. `workflow-executor` impose `"engines": {"node": ">=22.12.0"}` (`packages/workflow-executor/package.json:9-11`) ; `yarn workspace …` refuse sous ce seuil, contournement local `YARN_IGNORE_ENGINES=1`.
- Test : **Jest** (`package.json:49`), config `jest.config.ts:11` : `testMatch: ['<rootDir>/packages/*/test/**/*.test.ts']` — tests **non colocalisés**, sous `test/` en miroir de `src/`. Setup global `jest-extended/all` (`jest.config.ts:12`).
  - Package `agent` en ESM forcé : `"test": "NODE_OPTIONS=--experimental-vm-modules jest"` (`packages/agent/package.json:46`).
  - Par package : `yarn workspace @employer/<pkg> test -- <path ou -t "nom">`.
- Lint : `"lint": "lerna exec --parallel eslint src test"` (`package.json:46`), extends `airbnb-base`, `airbnb-typescript/base`, `plugin:@typescript-eslint/recommended`, `plugin:prettier/recommended`, `plugin:jest/recommended` (`.eslintrc.js:6-12`).
- Build : `"build": "lerna run build"` (`package.json:43`), `tsc` par package.
- Pas de script `typecheck` au root — le build fait office de vérification de types.

## Architecture

24 packages sous `packages/*`.

- `agent` — point d'entrée SDK, `createAgent()`, orchestre HTTP + customizer + services. Dépend de `datasource-customizer`, `datasource-toolkit`, `employer-client`, `mcp-server` (`packages/agent/package.json:16-20`).
- `mcp-server` — serveur MCP OAuth, transport HTTP streamable, tools RPC vers l'agent live. Dépend de `agent-client`, jamais des données en direct.
- `agent-client` — client RPC vers un agent en marche (consommé par `mcp-server`, `workflow-executor`).
- `employer-client` — SDK vers l'API SaaS employer : permissions, scopes, OIDC, schema push, activity logs. Toute la couche HTTP passe par `ServerUtils`.
- `workflow-executor` — exécute les steps de workflow côté infra client. Node ≥22.12.
- `datasource-toolkit`, `datasource-customizer` — couche datasource de base + customisation.
- `datasource-sql|sequelize|mongo|mongoose|replica|zendesk|dummy|demo-fintech` — implémentations.
- `ai-proxy` — proxy LLM (jamais `@langchain/core` en direct depuis les consommateurs).
- `plugin-aws-s3`, `plugin-export-advanced`, `plugin-flattener`, `employer-cloud`, `agent-toolkit`, `agent-testing`, `_example`.

Frontière qui compte : `agent` ne manipule jamais les collections directement, il délègue à `datasource-customizer`. Un changement de logique data dans `agent/src/routes` qui contourne le customizer est suspect.

## Conventions vérifiées

- **Tests non colocalisés** sous `test/` miroir de `src/` (`jest.config.ts:11`).
- **Assertions précises** : `toHaveBeenCalledWith` avec arguments exacts, pas `toHaveBeenCalled()` seul (`CLAUDE.md:63-73` ; exemple `packages/mcp-server/test/tools/get-action-form.test.ts:50-54`).
- **Mocks de module entier** : `jest.mock('../../src/utils/agent-caller')` (`packages/mcp-server/test/tools/get-action-form.test.ts:11`).
- **Export** : `export default class XxxRoute extends CollectionRoute` (`packages/agent/src/routes/access/list.ts:8`), un fichier = une route/un tool.
- **Import order imposé** : groupes `type`, puis `[builtin, external]`, puis `[internal, sibling, parent, index, object]`, alphabétisé, ligne vide entre groupes (`.eslintrc.js:39-50`).
- **Type-only imports forcés** : `@typescript-eslint/consistent-type-imports` en `error`, `fixStyle: separate-type-imports` (`.eslintrc.js:60-63`).
- **`mcp-server` impose les extensions `.js`** sur les imports SDK MCP (`.eslintrc.js:124-146`). Un import sans `.js` est une régression, pas un choix de style.

## Cas tricky

1. **Trou d'autorisation `list` + projection de relation** — `packages/agent/src/routes/access/list.ts:14,16` ne vérifie `assertCanBrowse`/`getScope` que sur `this.collection`, jamais sur une collection liée projetée ; `list-related.ts:20,23` le fait correctement sur `foreignCollection`. **Reconfirmé sur HEAD.** Tout diff sur `list.ts` ajoutant une projection de relation doit être scruté. (kb `agent-list-relation-authz-gap`)
2. **Casing operators snake_case vs PascalCase** — `packages/agent/src/routes/capabilities.ts:60-67,87-92` convertit en snake_case, `packages/mcp-server/src/schemas/filter.ts:3-48` attend un enum PascalCase (44 operators). Un changement d'un côté sans l'autre casse le filtrage MCP silencieusement. (kb `employer-capabilities-operators`)
3. **Pas de validation operator-vs-champ dans `list.ts` du MCP** — `filterSchema` global, pas par champ. Gap assumé (YAGNI documenté), pas une omission à corriger.
4. **Collision de slug d'action gatée par un flag** — `packages/agent/src/utils/employer-schema/generator-collection.ts:47-72` : `assertNoActionSlugCollision` ne tourne que si `useUnsafeActionEndpoint` est actif. (kb `action-slug-collision`)
5. **Cache 24h du schéma MCP standalone** — `packages/mcp-server/src/utils/schema-fetcher.ts:31-48`, `ONE_DAY_MS` sans invalidation. Insérer une action au milieu du schéma peut faire exécuter la mauvaise action jusqu'à 24h.
6. **workflow-executor, idempotence** : write-ahead log `idempotencyPhase: executing → done`. Une erreur héritant de `WorkflowExecutorError` au lieu d'une erreur de boundary est silencieusement avalée par `base-step-executor.ts`. Vérifier l'héritage de tout nouveau type d'erreur.
7. **workflow-executor, config** : jamais de `process.env` hors `cli-core`/`tracing.ts`. Régression déjà survenue (`employer_EXECUTOR_ENCRYPTION_KEY` lu dans `crypto/`).
8. **Deux stacks de customizer parallèles** (user-facing + no-code) : un changement dans `buildRouterAndSendSchema()` doit être vérifié sur les deux.
9. **Ajouter un tool MCP = 3 éditions coordonnées** dans `server.ts` (`ToolName` union, `allTools`, `allToolNames`). Une PR qui n'en touche qu'une ou deux est incomplète.

## Ce qu'on NE commente PAS

- **Cycles d'import** : `'import/no-cycle': 'off'` (`.eslintrc.js:100`), assumé pour les types.
- **`console.debug/info/warn/error`** : autorisés (`.eslintrc.js:91`). Seul `console.log` est interdit.
- **`class-methods-use-this` désactivé** (`.eslintrc.js:78`) — une méthode qui n'utilise pas `this` est un choix assumé.
- **`consistent-return` désactivé** (`.eslintrc.js:97`) au profit du typage TS.
- **`mountOn*` prend `any`** volontairement : les frameworks HTTP sont des peer/dev deps, l'agent reste agnostique.
- **Absence de validation operator-vs-champ** (`mcp-server/list.ts`) : YAGNI documenté.
- **`UnsupportedActionFormError` jamais levée** dans `workflow-executor/src` : code mort assumé et documenté.

## Signaux de review prioritaires

1. **Régression d'autorisation sur `access/`** — tout diff sur `packages/agent/src/routes/access/*.ts` ou `relation-route.ts` : vérifier `assertCanBrowse`/`getScope` sur **chaque** collection réellement lue, pas seulement celle de la route.
2. **Ordre des routes et middlewares** — routes triées par `RouteType` pour que logger/error/auth chargent avant les routes privées. L'ordre porte du sens ; un tri alphabétique casse en prod sans échec de test.
3. **Idempotence des steps mutants** (workflow-executor) — un nouveau chemin mutant qui ne passe pas par `checkIdempotency()` double les effets de bord en prod (paiement, action déclenchée deux fois).
4. **Cache 24h mcp-server** — un changement d'ordre des actions dans le générateur de schéma agent casse le MCP jusqu'à 24h après déploiement, sans qu'aucun test agent ne le voie.
5. **Casing operators capabilities ↔ filterSchema MCP** — changement d'un côté sans l'autre : pas d'erreur de compilation, pas d'échec de test, cassé en prod.
6. **Cache de build stale `agent-client` → `workflow-executor`** — dist stale servi par le cache lerna/nx, produit des « no exported member » trompeurs. CI verte ≠ build frais.
