import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import {
  appendFileSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { createRequire } from "node:module";
import { join, resolve } from "node:path";
import { sha256 } from "../../scripts/lib/project-verification-source.mjs";

export const repository = resolve(import.meta.dirname, "../..");
const templates = join(repository, "workflow-scaffold/templates/verification");

export function productFixture(
  directory,
  { web = false, negative = false } = {},
) {
  mkdirSync(directory, { recursive: true });
  const root = realpathSync(directory);
  const git = (args) => execFileSync("git", args, { cwd: root, stdio: "pipe" });
  git(["init", "-q"]);
  execFileSync(join(repository, "scripts/deploy-workflow"), [root], {
    stdio: "pipe",
  });
  const compilerRuntime = realpathSync(join(repository, "pi/node_modules"));
  mkdirSync(join(root, "pi"));
  symlinkSync(compilerRuntime, join(root, "pi/node_modules"), "dir");
  appendFileSync(join(root, ".git/info/exclude"), "/pi/\n");
  mkdirSync(join(root, "verification"), { recursive: true });
  copyFileSync(
    join(templates, web ? "web-app.mjs" : "cli-app.mjs"),
    join(root, "app.mjs"),
  );
  for (const helper of [
    "fixture-lifecycle.mjs",
    "observe-json.mjs",
    ...(web ? ["web-drive.mjs", "web-probe.mjs"] : []),
  ])
    copyFileSync(join(templates, helper), join(root, "verification", helper));
  const recipe = JSON.parse(
    readFileSync(
      join(templates, web ? "web.recipe.json" : "cli.recipe.json"),
      "utf8",
    ),
  );
  recipe.runtime ??= {};
  recipe.runtime.dependencies = [
    { path: "pi/node_modules", target: compilerRuntime },
  ];
  if (web) {
    assert.ok(
      process.env.ETABLI_TEST_PLAYWRIGHT_PACKAGE,
      "Set ETABLI_TEST_PLAYWRIGHT_PACKAGE to an explicitly selected installed Playwright project/package.json; no install or skip is performed",
    );
    const packagePath = createRequire(
      process.env.ETABLI_TEST_PLAYWRIGHT_PACKAGE,
    ).resolve("@playwright/test/package.json");
    recipe.runtime.modules[0].package_json = packagePath;
    if (negative) {
      const wrong = join(root, "verification/wrong-result.mjs");
      writeFileSync(
        wrong,
        'console.log(JSON.stringify({value:"wrong-result",reloaded:true,page_errors:[]}));\n',
      );
      recipe.scenarios[0].result.argv = [
        "node",
        "verification/wrong-result.mjs",
      ];
    }
  } else if (negative)
    recipe.scenarios[0].result.argv = ["node", "app.mjs", "wrong-result"];
  writeFileSync(
    join(root, "verification/recipe.json"),
    JSON.stringify(recipe, null, 2) + "\n",
  );
  writeFileSync(
    join(root, "package.json"),
    JSON.stringify({
      name: web ? "web-proof-fixture" : "cli-proof-fixture",
      private: true,
      scripts: {
        verify: "node scripts/project-verification run --plan PLAN.md",
      },
    }) + "\n",
  );
  git(["add", "."]);
  git([
    "-c",
    "user.name=Verification fixture",
    "-c",
    "user.email=fixture@localhost",
    "-c",
    "core.hooksPath=/dev/null",
    "-c",
    "commit.gpgsign=false",
    "commit",
    "-qm",
    "test: real verification fixture",
  ]);
  const plan = `# PLAN.md\n\n## Meta\n- Status: READY\n\n## Acceptance Criteria\n- [ ] AC-01 [product]: The entered value survives ${web ? "DOM reload and server persistence" : "CLI read and persisted state"}. Proof: action,result,side_effect.\n\n## Product Verification\n- Required: auto\n- Evidence pack: .workflow/proof/pack.json\n- Subject root: .\n`;
  const planPath = join(root, "PLAN.md");
  writeFileSync(planPath, plan);
  const env = { ...process.env, WORKFLOW_EVENT_PROJECT_ROOT: root };
  const execute = (script, args, timeout = 120000) =>
    spawnSync(process.execPath, [join(root, "scripts", script), ...args], {
      cwd: root,
      env,
      encoding: "utf8",
      timeout,
    });
  const event = (type, detail) =>
    spawnSync(
      join(root, "scripts/workflow-event"),
      [
        "--dir",
        join(root, ".workflow/ledger"),
        "append",
        "demo",
        type,
        JSON.stringify(detail),
      ],
      { cwd: root, env, encoding: "utf8" },
    );
  const created = event("plan_created", { path: "PLAN.md", status: "READY" });
  assert.equal(created.status, 0, created.stderr);
  return {
    root,
    recipe,
    planPath,
    plan,
    execute,
    event,
    saveRecipe() {
      writeFileSync(
        join(root, "verification/recipe.json"),
        JSON.stringify(recipe, null, 2) + "\n",
      );
    },
    run(useEngine = false) {
      return execute("project-verification", [
        "run",
        "--plan",
        "PLAN.md",
        ...(useEngine ? ["--engine"] : []),
      ]);
    },
    check() {
      return execute("project-verification-check", ["PLAN.md"]);
    },
    archive() {
      mkdirSync(join(root, "docs/plan"), { recursive: true });
      const archivePath = join(root, "docs/plan/demo.md");
      writeFileSync(
        archivePath,
        `# Implemented: real product fixture\n- Source plan: \`PLAN.md\`\n- Status: IMPLEMENTED\n- Source plan SHA-256: \`${sha256(readFileSync(planPath))}\`\n`,
      );
      const pack = join(root, ".workflow/proof/pack.json");
      const archived = event("archive_written", {
        path: "docs/plan/demo.md",
        product_verification_required: true,
        product_verification_receipt: pack + ".completion.json",
        product_archive_path: archivePath,
      });
      const result = execute("plan-cleanup", [
        "--archive",
        "docs/plan/demo.md",
      ]);
      if (result.status === 0) {
        assert.equal(archived.status, 0, archived.stderr);
        assert.equal(existsSync(planPath), false);
        const removed = event("plan_removed", {
          path: "PLAN.md",
          archive: "docs/plan/demo.md",
        });
        assert.equal(removed.status, 0, removed.stderr);
      }
      return { ...result, archiveEvent: archived };
    },
  };
}
