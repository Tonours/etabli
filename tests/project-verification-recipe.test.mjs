import assert from "node:assert/strict";
import { appendFileSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
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
