import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  accessSync,
  constants,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  writeFileSync,
} from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { validateRecipeAssertions } from "./project-verification-assertions.mjs";
import {
  confinedFile,
  sourceInventory,
} from "./project-verification-source.mjs";

const schemaPath = new URL(
  "../../workflow/project-verification-recipe.schema.json",
  import.meta.url,
);
const deployedTemplates = new URL(
  "../../workflow/verification/",
  import.meta.url,
);
const templateRoot = existsSync(deployedTemplates)
  ? deployedTemplates
  : new URL("../../workflow-scaffold/templates/verification/", import.meta.url);
const reserved = new Set([
  "PATH",
  "HOME",
  "USER",
  "LOGNAME",
  "TMPDIR",
  "TEMP",
  "TMP",
  "SHELL",
  "NODE_OPTIONS",
  "NODE_PATH",
  "BASH_ENV",
  "ENV",
  "LD_PRELOAD",
  "DYLD_INSERT_LIBRARIES",
]);
let validator;

export async function readVerificationRecipe(
  root,
  path = "verification/recipe.json",
) {
  const full = confinedFile(root, path);
  assert.ok(
    sourceInventory(root).includes(path),
    "Recipe must be an inventoried project source file",
  );
  const bytes = readFileSync(full);
  const recipe = JSON.parse(bytes);
  if (!validator) {
    let compiler;
    try {
      compiler = createRequire(
        new URL("../../pi/package.json", import.meta.url),
      ).resolve("typebox/compile");
    } catch {
      compiler = createRequire(
        join(homedir(), ".pi/agent/npm/package.json"),
      ).resolve("typebox/compile");
    }
    const { Compile } = await import(pathToFileURL(compiler));
    validator = Compile(JSON.parse(readFileSync(schemaPath, "utf8")));
  }
  assert.ok(
    validator.Check(recipe),
    "Incomplete or invalid verification recipe: supply commands, timeouts, AC mappings, typed result oracles and explicit UI scope/observations for mode ui",
  );
  validateRecipeAssertions(recipe);
  assert.ok(
    !JSON.stringify(recipe).includes("__REQUIRED__"),
    "Resolve __REQUIRED__ verification placeholders before running",
  );
  for (const name of recipe.engine?.required_env ?? [])
    assert.ok(
      !reserved.has(name) && !name.startsWith("ETABLI_"),
      `Credential name cannot override runner environment: ${name}`,
    );
  assert.equal(
    new Set(recipe.engine?.required_env ?? []).size,
    (recipe.engine?.required_env ?? []).length,
    "Duplicate credential environment name",
  );
  for (const dependency of recipe.runtime?.dependencies ?? []) {
    assert.ok(
      /^(?:[A-Za-z0-9_.-]+\/)*node_modules$/.test(dependency.path) &&
        !dependency.path.split("/").includes(".."),
      "Dependency reuse is restricted to a node_modules directory",
    );
    assert.ok(
      isAbsolute(dependency.target) &&
        realpathSync(dependency.target) === dependency.target,
      "Dependency target must be an explicit canonical installed directory",
    );
    assert.ok(
      lstatSync(dependency.target).isDirectory(),
      "Installed dependency target must be a directory",
    );
    assert.ok(
      !sourceInventory(root).some(
        (path) =>
          path === dependency.path || path.startsWith(dependency.path + "/"),
      ),
      "Installed dependencies cannot replace inventoried source",
    );
  }
  for (const module of recipe.runtime?.modules ?? []) {
    assert.ok(
      isAbsolute(module.package_json) &&
        module.package_json.endsWith("/package.json"),
      "Installed module needs an explicit absolute package.json path",
    );
    const metadata = JSON.parse(readFileSync(module.package_json, "utf8"));
    assert.ok(
      typeof metadata.name === "string" && typeof metadata.version === "string",
      "Installed module identity is unavailable",
    );
  }
  return { recipe, bytes, path };
}

export function enginePreflight(recipe, useEngine, environment = process.env) {
  if (!useEngine) return { requested: false };
  assert.ok(
    recipe.engine,
    "No engine is configured; add explicit argv/provider/model/required_env or run the deterministic baseline",
  );
  const missing = recipe.engine.required_env.filter(
    (name) => !environment[name],
  );
  assert.ok(
    !missing.length,
    `Missing engine environment names: ${missing.join(", ")}`,
  );
  return {
    requested: true,
    provider: recipe.engine.provider,
    model: recipe.engine.model,
    credentials: recipe.engine.required_env.map((name) => ({
      name,
      present: true,
    })),
  };
}

function metadata(root, path) {
  try {
    return JSON.parse(readFileSync(confinedFile(root, path), "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export function discoverVerification(root = process.cwd()) {
  root = realpathSync(root);
  const manifest = metadata(root, "package.json");
  const scopes = [""];
  for (const parent of ["apps", "packages"])
    if (
      existsSync(join(root, parent)) &&
      lstatSync(join(root, parent)).isDirectory() &&
      !lstatSync(join(root, parent)).isSymbolicLink()
    ) {
      for (const entry of readdirSync(join(root, parent), {
        withFileTypes: true,
      }))
        if (entry.isDirectory() && !entry.isSymbolicLink())
          scopes.push(`${parent}/${entry.name}/`);
    }
  const configuration = scopes.flatMap((scope) =>
    [
      "playwright.config.ts",
      "playwright.config.js",
      "vitest.config.ts",
      "pytest.ini",
      "Cargo.toml",
      "go.mod",
      "pnpm-workspace.yaml",
    ]
      .filter((path) => existsSync(join(root, scope, path)))
      .map((path) => scope + path),
  );
  const workspaces = scopes.filter(Boolean).flatMap((scope) => {
    const pkg = metadata(root, scope + "package.json");
    return pkg
      ? [
          {
            path: scope.slice(0, -1),
            name: pkg.name,
            commands: pkg.scripts ?? {},
          },
        ]
      : [];
  });
  const recipeExists = existsSync(join(root, "verification/recipe.json"));
  const prerequisites = ["git", "node", "ps"].map((name) => ({
    name,
    available: executableAvailable(name, { PATH: process.env.PATH }, root),
  }));
  let hasHead = false;
  try {
    execFileSync("git", ["rev-parse", "--verify", "HEAD"], {
      cwd: root,
      stdio: "pipe",
    });
    hasHead = true;
  } catch {}
  prerequisites.push({ name: "project Git HEAD", available: hasHead });
  return {
    root,
    commands: manifest?.scripts ?? {},
    workspaces,
    configuration,
    prerequisites,
    missing_prerequisites: prerequisites
      .filter((item) => !item.available)
      .map((item) => item.name),
    recipe: { path: "verification/recipe.json", exists: recipeExists },
    next: recipeExists
      ? "Review recipe mappings/oracles, then run --plan PLAN.md"
      : "Run init; adapt the commands, product AC mappings and typed assertions before run",
    provider_key_required: false,
  };
}

export function initVerification(root = process.cwd()) {
  root = realpathSync(root);
  const directory = join(root, "verification");
  assert.ok(
    !existsSync(join(directory, "recipe.json")),
    "Recipe already exists; init never overwrites project files",
  );
  mkdirSync(directory, { recursive: true });
  assert.equal(
    realpathSync(directory),
    directory,
    "Verification directory must not be a symlink",
  );
  const recipe = JSON.parse(
    readFileSync(new URL("recipe.example.json", templateRoot), "utf8"),
  );
  writeFileSync(
    join(directory, "recipe.json"),
    JSON.stringify(recipe, null, 2) + "\n",
    { flag: "wx", mode: 0o600 },
  );
  const helper = join(directory, "observe-json.mjs");
  if (!existsSync(helper))
    writeFileSync(
      helper,
      readFileSync(new URL("observe-json.mjs", templateRoot)),
      { flag: "wx", mode: 0o700 },
    );
  return {
    created: "verification/recipe.json",
    helper: "verification/observe-json.mjs",
    unresolved: [
      "launch/doctor/cleanup argv",
      "scenario action/result argv",
      "product criterion IDs",
      "expected JSON values",
      "persistence command and assertions when required",
    ],
    runnable: false,
  };
}

export function executableAvailable(command, environment, cwd = process.cwd()) {
  const candidates = isAbsolute(command)
    ? [command]
    : /[\\/]/.test(command)
      ? [resolve(cwd, command)]
      : (environment.PATH ?? "")
          .split(":")
          .filter(Boolean)
          .map((path) => join(path, command));
  return candidates.some((path) => {
    try {
      accessSync(path, constants.X_OK);
      return true;
    } catch {
      return false;
    }
  });
}
