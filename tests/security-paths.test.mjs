import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const adr = join(root, "skills/shared/adr/scripts/apply-adr.mjs");
const cleanup = join(root, "scripts/plan-cleanup");
const deploy = join(root, "scripts/deploy-workflow");
const plan = "# PLAN.md\n\n- Status: READY\n";
const hash = createHash("sha256").update(plan).digest("hex");
const archive = `# Implemented: fixture\n\n- Source plan: \`PLAN.md\`\n- Source plan SHA-256: \`${hash}\`\n- Status: IMPLEMENTED\n`;
const record = "---\nstatus: accepted\ndate: 2026-10-27\n---\n\n# Original\n";

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), "etabli-security-paths-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const target = join(dir, "target");
  const outside = join(dir, "outside");
  mkdirSync(target);
  mkdirSync(outside);
  return { dir, target, outside };
}

function run(binary, args, cwd) {
  const result = spawnSync(binary, args, { cwd, encoding: "utf8", timeout: 30000 });
  assert.ifError(result.error);
  return result;
}

for (const flags of [[], ["--force"], ["--force", "--refresh-tracked"]]) {
  for (const tail of ["existing", "missing", "dangling"]) {
    test(`deploy refuses outside parent: ${flags.join(" ")} ${tail}`, (t) => {
      const { target, outside } = fixture(t);
      writeFileSync(join(outside, "spec.md"), "outside sentinel\n");
      const destination = tail === "existing" ? outside : join(outside, "missing");
      symlinkSync(destination, join(target, "workflow"));
      if (tail === "missing") mkdirSync(join(outside, "missing"));
      const result = run(deploy, [target, ...flags], root);
      assert.notEqual(result.status, 0, result.stdout);
      assert.match(result.stdout + result.stderr, /CONFLICT/);
      assert.equal(readFileSync(join(outside, "spec.md"), "utf8"), "outside sentinel\n");
      assert.deepEqual(readdirSync(outside).sort(), tail === "missing" ? ["missing", "spec.md"] : ["spec.md"]);
      assert.deepEqual(readdirSync(target), ["workflow"]);
    });
  }
}

test("deploy safely replaces an untracked dangling leaf under force", (t) => {
  const { target, outside } = fixture(t);
  symlinkSync(join(outside, "missing.md"), join(target, "AGENTS.md"));
  const result = run(deploy, [target, "--force"], root);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(lstatSync(join(target, "AGENTS.md")).isSymbolicLink(), false);
  assert.deepEqual(readdirSync(outside), []);
});

for (const managed of ["docs", "docs/adr", "docs/adr/README.md", "CLAUDE.md", "docs/adr/0001-original.md"]) {
  for (const mode of ["create", "reindex"]) {
    test(`ADR ${mode} refuses managed symlink ${managed} before any write`, (t) => {
      const { dir, target, outside } = fixture(t);
      const leaf = managed.endsWith(".md");
      const external = join(outside, leaf ? "existing.md" : "managed");
      if (leaf) writeFileSync(external, managed.includes("0001-") ? record : "external sentinel\n");
      else mkdirSync(external);
      mkdirSync(dirname(join(target, managed)), { recursive: true });
      symlinkSync(external, join(target, managed));
      const draft = join(dir, "draft.json");
      writeFileSync(draft, JSON.stringify({ title: "Next", body: "A decision.", supersedes: managed.includes("0001-") ? "ADR-0001" : undefined }));
      const result = run(process.execPath, [adr, "--root", target, ...(mode === "reindex" ? ["--reindex"] : ["--input", draft])], root);
      assert.notEqual(result.status, 0, result.stdout);
      assert.match(result.stderr, /symlink/i);
      if (leaf) assert.equal(readFileSync(external, "utf8"), managed.includes("0001-") ? record : "external sentinel\n");
      else assert.deepEqual(readdirSync(external), []);
      if (managed !== "CLAUDE.md") assert.equal(existsSync(join(target, "CLAUDE.md")), false);
      if (existsSync(join(target, "docs/adr"))) {
        assert.equal(readdirSync(join(target, "docs/adr")).some((name) => name.includes("next")), false);
      }
    });
  }
}

test("ADR refuses a dangling managed leaf before creating an ADR", (t) => {
  const { dir, target, outside } = fixture(t);
  symlinkSync(join(outside, "missing.md"), join(target, "CLAUDE.md"));
  const draft = join(dir, "draft.json");
  writeFileSync(draft, JSON.stringify({ title: "Next", body: "Decision" }));
  const result = run(process.execPath, [adr, "--root", target, "--input", draft], root);
  assert.notEqual(result.status, 0);
  assert.equal(existsSync(join(target, "docs")), false);
  assert.deepEqual(readdirSync(outside), []);
});

for (const managed of ["docs", "docs/plan"]) {
  for (const mode of ["archive", "discard"]) {
    test(`cleanup ${mode} refuses symlinked ${managed}, preserving PLAN.md`, (t) => {
      const { target, outside } = fixture(t);
      mkdirSync(dirname(join(target, managed)), { recursive: true });
      symlinkSync(outside, join(target, managed));
      mkdirSync(join(target, "docs/plan"), { recursive: true });
      writeFileSync(join(target, "docs/plan/implemented.md"), archive);
      writeFileSync(join(target, "PLAN.md"), plan);
      const before = readdirSync(outside);
      const result = run(process.execPath, [cleanup, ...(mode === "archive" ? ["--archive", "docs/plan/implemented.md"] : ["--discard", "unrelated"])], target);
      assert.notEqual(result.status, 0, result.stdout);
      assert.match(result.stderr, /symlink/i);
      assert.equal(readFileSync(join(target, "PLAN.md"), "utf8"), plan);
      assert.deepEqual(readdirSync(outside), before);
    });
  }
}

test("cleanup refuses a dangling discard destination and preserves the root plan", (t) => {
  const { target, outside } = fixture(t);
  mkdirSync(join(target, "docs/plan"), { recursive: true });
  const day = new Date().toISOString().slice(0, 10).replaceAll("-", "");
  symlinkSync(join(outside, "created.md"), join(target, `docs/plan/${day}-discarded-unrelated.md`));
  writeFileSync(join(target, "PLAN.md"), plan);
  const result = run(process.execPath, [cleanup, "--discard", "unrelated"], target);
  assert.notEqual(result.status, 0);
  assert.equal(readFileSync(join(target, "PLAN.md"), "utf8"), plan);
  assert.deepEqual(readdirSync(outside), []);
});
