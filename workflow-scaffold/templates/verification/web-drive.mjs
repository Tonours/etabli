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
  const errors = [], consoleErrors = [], networkErrors = [], responses = [];
  const focus = [], viewports = [], keyboard = [], accessible = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("requestfailed", (request) => networkErrors.push({ url: request.url(), error: request.failure()?.errorText }));
  page.on("response", (response) => {
    responses.push({ path: new URL(response.url()).pathname, status: response.status() });
    if (response.status() >= 400) networkErrors.push({ url: response.url(), status: response.status() });
  });
  for (const viewport of [
    { label: "desktop", width: 1280, height: 800 },
    { label: "mobile", width: 390, height: 844 },
  ]) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await page.goto(url);
    await page.locator("body[data-ready=true]").waitFor();
    const input = page.getByRole("textbox", { name: "Value", exact: true });
    const save = page.getByRole("button", { name: "Save", exact: true });
    for (const [control, name] of [[input, "Value"], [save, "Save"]]) {
      await expect(control).toHaveCount(1);
      await expect(control).toBeVisible();
      await expect(control).toBeEnabled();
      await expect(control).toHaveAccessibleName(name);
    }
    accessible.push({ viewport: viewport.label, textbox: "Value", button: "Save" });
    await page.keyboard.press("Tab");
    await expect(input).toBeFocused();
    await page.keyboard.press("ControlOrMeta+A");
    await page.keyboard.type("verified");
    for (const control of [input, save]) {
      if (control === save) await page.keyboard.press("Tab");
      await expect(control).toBeFocused();
      focus.push(await control.evaluate((element) => {
        const style = getComputedStyle(element);
        return {
          control: element.id,
          focus_visible: element.matches(":focus-visible"),
          outline_style: style.outlineStyle,
          outline_width: style.outlineWidth,
          outline_color: style.outlineColor,
          background: getComputedStyle(document.body).backgroundColor,
        };
      }));
    }
    await page.keyboard.press("Enter");
    await expect(page.getByRole("status")).toHaveText("Saved");
    keyboard.push({ viewport: viewport.label, focused: ["value", "save"], activated: "Enter", status: "Saved" });
    const layout = await page.evaluate(() => ({
      width: innerWidth,
      height: innerHeight,
      client_width: document.documentElement.clientWidth,
      scroll_width: document.documentElement.scrollWidth,
      controls: [...document.querySelectorAll("input,button,[role=status]")].map((element) => {
        const { x, y, width, height } = element.getBoundingClientRect();
        return { x, y, width, height };
      }),
    }));
    viewports.push({ label: viewport.label, ...layout });
  }
  await page.reload();
  await page.locator("body[data-ready=true]").waitFor();
  await expect(page.getByLabel("Value")).toHaveValue("verified");
  assert.deepEqual(errors, []);
  writeFileSync(join(root, "browser.json"), JSON.stringify({
    value: await page.getByLabel("Value").inputValue(),
    reloaded: true,
    page_errors: errors,
  }) + "\n");
  writeFileSync(join(root, "ui.json"), JSON.stringify({
    checks: {
      keyboard: keyboard.length === 2,
      focus: focus.length === 4 && focus.every((item) => item.focus_visible && item.outline_style === "solid" && parseFloat(item.outline_width) >= 2 && item.outline_color === "rgb(0, 0, 0)" && item.background === "rgb(255, 255, 255)"),
      accessibility: accessible.length === 2,
      console: errors.length === 0 && consoleErrors.length === 0,
      network: networkErrors.length === 0 && responses.some((item) => item.path === "/" && item.status === 200) && responses.some((item) => item.path === "/state" && item.status === 200),
      responsive: viewports.every((item) => item.scroll_width <= item.client_width && item.controls.every((rect) => rect.width > 0 && rect.height > 0 && rect.x >= 0 && rect.y >= 0 && rect.x + rect.width <= item.width && rect.y + rect.height <= item.height)),
    },
    viewports,
    observations: { keyboard, focus, accessible, console_errors: consoleErrors, page_errors: errors, network_errors: networkErrors, responses },
  }) + "\n");
} finally {
  await browser.close();
}
