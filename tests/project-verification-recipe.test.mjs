import assert from "node:assert/strict";
import { appendFileSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import {
  discoverVerification,
  enginePreflight,
  initVerification,
  readVerificationRecipe,
} from "../scripts/lib/project-verification-recipe.mjs";
import { productFixture } from "./lib/project-verification-fixture.mjs";

function fixture(t) {
  const directory = mkdtempSync(join(tmpdir(), "etabli-recipe-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  return productFixture(directory);
}

function declareUi(recipe) {
  const example = JSON.parse(readFileSync(new URL("../workflow-scaffold/templates/verification/web.recipe.json", import.meta.url), "utf8"));
  recipe.mode = example.mode;
  recipe.ui = example.ui;
}

test("recipe schema accepts explicit UI and explicit legacy product modes", async (t) => {
  const f = fixture(t);
  f.recipe.mode = "product";
  f.saveRecipe();
  await readVerificationRecipe(f.root);
  declareUi(f.recipe);
  f.saveRecipe();
  assert.equal((await readVerificationRecipe(f.root)).recipe.mode, "ui");
});

for (const [name, mutate] of [
  ["missing UI", recipe => delete recipe.ui],
  ["implicit UI", recipe => delete recipe.mode],
  ["product with UI", recipe => recipe.mode = "product"],
  ["missing scope", recipe => delete recipe.ui.responsive_in_scope],
  ["missing reason", recipe => delete recipe.ui.not_applicable_reasons.reference],
  ["missing UI command", recipe => delete recipe.ui.observation],
  ["UI timer overflow", recipe => recipe.ui.observation.timeout_ms = 2147483648],
  ["empty UI assertions", recipe => recipe.ui.observation.assertions = []],
  ["extra UI property", recipe => recipe.ui.claimed_pass = true],
])
  test(`recipe rejects ${name}`, async (t) => {
    const f = fixture(t);
    declareUi(f.recipe);
    mutate(f.recipe);
    f.saveRecipe();
    await assert.rejects(readVerificationRecipe(f.root));
  });

test("discovery uses public metadata, bootstrap is create-only and incomplete recipes cannot run", async (t) => {
  const f = fixture(t);
  assert.ok(discoverVerification(f.root).commands.verify);
  assert.deepEqual(discoverVerification(f.root).missing_prerequisites, []);
  const path = join(f.root, "verification/recipe.json");
  const before = readFileSync(path);
  assert.throws(() => initVerification(f.root), /never overwrites/);
  assert.deepEqual(readFileSync(path), before);
  rmSync(path);
  const initialized = initVerification(f.root);
  assert.equal(initialized.runnable, false);
  await assert.rejects(readVerificationRecipe(f.root), /placeholders/);
  assert.notEqual(f.run().status, 0);
});

function bareProject(t, files = {}) {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "etabli-constraints-")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  return root;
}

test("discovery reports constraint tooling per scope without reading it", (t) => {
  const root = bareProject(t, {
    "eslint.config.js": "",
    ".eslintrc.json": "{",
    ".template-lintrc.js": "",
    "pyproject.toml": "not toml [",
    "ruff.toml": "",
    "apps/web/tsconfig.json": "",
    "apps/web/biome.json": "",
    "packages/core/.golangci.yml": "",
    "packages/core/sgconfig.yml": "",
    "packages/core/clippy.toml": "",
  });
  const constraints = discoverVerification(root).constraints;
  assert.deepEqual(constraints, [
    { tool: "eslint", path: "eslint.config.js" },
    { tool: "eslint", path: ".eslintrc.json" },
    { tool: "ember-template-lint", path: ".template-lintrc.js" },
    { tool: "ruff", path: "ruff.toml" },
    { tool: "pyproject", path: "pyproject.toml" },
    { tool: "typescript", path: "apps/web/tsconfig.json" },
    { tool: "biome", path: "apps/web/biome.json" },
    { tool: "clippy", path: "packages/core/clippy.toml" },
    { tool: "golangci-lint", path: "packages/core/.golangci.yml" },
    { tool: "ast-grep", path: "packages/core/sgconfig.yml" },
  ]);
});

test("discovery reports no constraints for a bare project and keeps existing fields", (t) => {
  const result = discoverVerification(bareProject(t));
  assert.deepEqual(result.constraints, []);
  assert.deepEqual(
    Object.keys(result),
    ["root", "commands", "workspaces", "configuration", "constraints", "prerequisites", "missing_prerequisites", "recipe", "next", "provider_key_required"],
  );
});

test("discovery ignores symlinked, directory and symlinked-scope constraint candidates", (t) => {
  const outside = bareProject(t, { "eslint.config.js": "", "biome.json": "" });
  const root = bareProject(t, { "real.config.js": "" });
  mkdirSync(join(root, "internal-dir"));
  symlinkSync(join(root, "real.config.js"), join(root, "eslint.config.js"));
  symlinkSync(join(outside, "biome.json"), join(root, "biome.json"));
  symlinkSync(join(root, "missing.json"), join(root, ".oxlintrc.json"));
  symlinkSync(join(root, "internal-dir"), join(root, "tsconfig.json"), "dir");
  mkdirSync(join(root, "apps/dir/mypy.ini"), { recursive: true });
  symlinkSync(outside, join(root, "apps/link"), "dir");
  assert.deepEqual(discoverVerification(root).constraints, []);
});

for (const [name, mutate] of [
  ["missing timeout", (recipe) => delete recipe.launch.timeout_ms],
  ["Node timer overflow", (recipe) => (recipe.launch.timeout_ms = 2147483648)],
  [
    "empty assertions",
    (recipe) => (recipe.scenarios[0].result.assertions = []),
  ],
  ["empty mappings", (recipe) => (recipe.scenarios[0].criterion_ids = [])],
  [
    "duplicate scenario",
    (recipe) => recipe.scenarios.push(structuredClone(recipe.scenarios[0])),
  ],
  [
    "reserved engine environment",
    (recipe) =>
      (recipe.engine = {
        argv: ["node"],
        timeout_ms: 1000,
        provider: "fixture",
        model: "fixture",
        required_env: ["PATH"],
      }),
  ],
  ["undeclared recipe property", (recipe) => (recipe.invented = true)],
])
  test(`recipe rejects ${name}`, async (t) => {
    const f = fixture(t);
    mutate(f.recipe);
    f.saveRecipe();
    await assert.rejects(readVerificationRecipe(f.root));
  });

test("recipe accepts the largest supported Node timer", async (t) => {
  const f = fixture(t);
  f.recipe.launch.timeout_ms = 2147483647;
  f.saveRecipe();
  assert.equal((await readVerificationRecipe(f.root)).recipe.launch.timeout_ms,2147483647);
});

test("engine preflight is keyless unless explicitly requested and reports names only", (t) => {
  const recipe = {
    engine: {
      provider: "fixture-provider",
      model: "fixture-model",
      required_env: ["TEST_KEY"],
    },
  };
  assert.deepEqual(enginePreflight(recipe, false, {}), { requested: false });
  assert.throws(() => enginePreflight(recipe, true, {}), /TEST_KEY/);
  assert.equal(
    JSON.stringify(
      enginePreflight(recipe, true, { TEST_KEY: "private-value" }),
    ).includes("private-value"),
    false,
  );
  assert.throws(() => enginePreflight({}, true), /No engine/);
});

test("recipe must remain in the origin Git inventory", async (t) => {
  const f = fixture(t);
  appendFileSync(
    join(f.root, ".git/info/exclude"),
    "verification/recipe.json\n",
  );
  // A tracked recipe remains inventoried even when an ignore rule exists.
  assert.equal(
    (await readVerificationRecipe(f.root)).recipe.name,
    f.recipe.name,
  );
});
