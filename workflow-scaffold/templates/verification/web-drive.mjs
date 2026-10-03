import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";
const root = process.env.ETABLI_RUN_DIR;
const recipe = JSON.parse(readFileSync("verification/recipe.json"));
const module = recipe.runtime.modules[0].package_json;
const { chromium, expect } = createRequire(module)("@playwright/test");
const { url } = JSON.parse(readFileSync(join(root, "url.json")));
const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto(url);
  await page.locator("body[data-ready=true]").waitFor();
  await page.getByLabel("Value").fill("verified");
  await page.getByRole("button", { name: "Save" }).click();
  await expect(page.getByRole("status")).toHaveText("Saved");
  await page.reload();
  await page.locator("body[data-ready=true]").waitFor();
  await expect(page.getByLabel("Value")).toHaveValue("verified");
  assert.deepEqual(errors, []);
  writeFileSync(
    join(root, "browser.json"),
    JSON.stringify({
      value: await page.getByLabel("Value").inputValue(),
      reloaded: true,
      page_errors: errors,
    }) + "\n",
  );
} finally {
  await browser.close();
}
