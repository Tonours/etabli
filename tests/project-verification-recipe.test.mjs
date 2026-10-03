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
