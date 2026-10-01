import { expect, test } from "bun:test";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { isNarrowPlanCleanupCommand } from "../../../scripts/lib/plan-cleanup-command.mjs";
import { planMutationGuardDecision } from "../../../workflow/runtime/workflow-router-core.mjs";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

test("quoted cleanup and same-session cd survive the plan mutation guard", () => {
  const cwd = mkdtempSync(join(tmpdir(), "cleanup test-"));
  const other = mkdtempSync(join(tmpdir(), "cleanup-other-"));
  try {
    mkdirSync(join(cwd, "scripts"));
    for (const command of [
      '"scripts/plan-cleanup" --discard "unrelated-plan"',
      `cd '${cwd}' && scripts/plan-cleanup --discard unrelated-plan`,
      `cd -- '${cwd}' && scripts/plan-cleanup --archive 'docs/plan/old.md'`,
    ]) {
      expect(isNarrowPlanCleanupCommand(command, cwd)).toBe(true);
      for (const status of ["DRAFT", "CHALLENGED", "READY", "STALE"]) {
        writeFileSync(join(cwd, "PLAN.md"), `# PLAN.md\n- Status: ${status}\n`);
        expect(planMutationGuardDecision({ cwd, tool_name: "Bash", tool_input: { command } })).toBeNull();
      }
    }
    for (const command of [
      `cd '${other}' && scripts/plan-cleanup --discard unrelated-plan`,
      "scripts/plan-cleanup --discard old; touch stolen",
      "scripts/plan-cleanup --discard old | sh",
      "scripts/plan-cleanup --discard old > other",
      "scripts/plan-cleanup --discard $(whoami)",
      "bash -c 'scripts/plan-cleanup --discard old'",
      "/tmp/plan-cleanup --discard old",
      "eval scripts/plan-cleanup --discard old",
      "scripts/plan-cleanup --discard old && touch stolen",
    ]) expect(isNarrowPlanCleanupCommand(command, cwd)).toBe(false);
    const alias = join(other, "alias");
    symlinkSync(cwd, alias);
    expect(isNarrowPlanCleanupCommand(`cd '${alias}' && scripts/plan-cleanup --discard old`, cwd)).toBe(true);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
    rmSync(other, { recursive: true, force: true });
  }
});

test("PATH-only cleanup executable never receives the guard exception", () => {
  const central = fileURLToPath(new URL("../../../scripts/plan-cleanup", import.meta.url));
  const cwd = dirname(central);
  const path = mkdtempSync(join(tmpdir(), "cleanup-path-"));
  try {
    writeFileSync(join(path, "plan-cleanup"), '#!/bin/sh\nprintf "foreign-executable\\n"\n', { mode: 0o755 });
    expect(execFileSync("/bin/sh", ["-c", "plan-cleanup --discard old"], {
      cwd, env: { ...process.env, PATH: path }, encoding: "utf8",
    }).trim()).toBe("foreign-executable");
    for (const runner of ["", "node ", "bun ", "bash "]) {
      expect(isNarrowPlanCleanupCommand(`${runner}plan-cleanup --discard old`, cwd)).toBe(false);
      expect(isNarrowPlanCleanupCommand(`${runner}./plan-cleanup --discard old`, cwd)).toBe(true);
      expect(isNarrowPlanCleanupCommand(`${runner}'${central}' --discard old`, cwd)).toBe(true);
    }
  } finally { rmSync(path, { recursive: true, force: true }); }
});

test("shell traversal and special cd operands cannot redirect approved cleanup", () => {
  const root = mkdtempSync(join(tmpdir(), "cleanup-shell-"));
  const cwd = join(root, "project");
  const foreign = join(root, "foreign");
  try {
    mkdirSync(join(cwd, "scripts"), { recursive: true });
    mkdirSync(join(foreign, "sub"), { recursive: true });
    mkdirSync(join(foreign, "scripts"));
    const stub = '#!/bin/sh\nprintf "foreign-executable\\n"\n';
    writeFileSync(join(foreign, "plan-cleanup"), stub, { mode: 0o755 });
    writeFileSync(join(foreign, "scripts/plan-cleanup"), stub, { mode: 0o755 });
    symlinkSync(join(foreign, "sub"), join(cwd, "scripts/link"));
    for (const name of ["-", "-L", "~", "alias"]) symlinkSync(cwd, join(cwd, name));
    symlinkSync(foreign, join(foreign, "alias"));
    const init = join(root, "bash-init");
    writeFileSync(init, `OLDPWD=${JSON.stringify(foreign)}\n`);
    for (const command of [
      "scripts/link/../plan-cleanup --discard old",
      "cd - && scripts/plan-cleanup --discard old",
      "cd -- - && scripts/plan-cleanup --discard old",
      "cd -L && scripts/plan-cleanup --discard old",
      "cd ~ && scripts/plan-cleanup --discard old",
      "cd alias && scripts/plan-cleanup --discard old",
    ]) {
      expect(execFileSync("/bin/bash", ["--noprofile", "--norc", "-c", command], {
        cwd, env: { ...process.env, BASH_ENV: init, HOME: foreign, CDPATH: foreign }, encoding: "utf8",
      }).trim().split("\n").at(-1)).toBe("foreign-executable");
      expect(isNarrowPlanCleanupCommand(command, cwd)).toBe(false);
    }
    expect(isNarrowPlanCleanupCommand("cd ./alias && scripts/plan-cleanup --discard old", cwd)).toBe(true);
    expect(isNarrowPlanCleanupCommand("cd . && ./scripts/plan-cleanup --discard old", cwd)).toBe(true);
    for (const command of [
      "cd ?(-) && scripts/plan-cleanup --discard old",
      "cd /tmp/* && scripts/plan-cleanup --discard old",
      "scripts/*/../plan-cleanup --discard old",
    ]) expect(isNarrowPlanCleanupCommand(command, cwd)).toBe(false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("unquoted shell operators in cd paths are refused while quoted paths stay usable", () => {
  const root = mkdtempSync(join(tmpdir(), "cleanup-operator-"));
  const cwd = join(root, "project&rogue");
  const bin = join(root, "bin");
  try {
    mkdirSync(join(root, "project"));
    mkdirSync(join(cwd, "scripts"), { recursive: true });
    mkdirSync(bin);
    writeFileSync(join(bin, "rogue"), '#!/bin/sh\nprintf "foreign-executable\\n"\n', { mode: 0o755 });
    writeFileSync(join(cwd, "scripts/plan-cleanup"), '#!/bin/sh\nprintf "local-executable\\n"\n', { mode: 0o755 });
    const command = `cd ${cwd} && scripts/plan-cleanup --discard old`;
    expect(execFileSync("/bin/bash", ["--noprofile", "--norc", "-c", command], {
      cwd, env: { ...process.env, BASH_ENV: "", CDPATH: "", PATH: `${bin}:/usr/bin:/bin` }, encoding: "utf8",
    })).toContain("foreign-executable");
    expect(isNarrowPlanCleanupCommand(command, cwd)).toBe(false);
    expect(isNarrowPlanCleanupCommand(`cd '${cwd}' && scripts/plan-cleanup --discard old`, cwd)).toBe(true);
    expect(isNarrowPlanCleanupCommand(`cd '${cwd}' '&&' scripts/plan-cleanup --discard old`, cwd)).toBe(false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("shell literal whitespace cannot receive a cleanup-only exception", () => {
  const cwd = mkdtempSync(join(tmpdir(), "cleanup-whitespace-"));
  try {
    mkdirSync(join(cwd, "scripts"));
    const stub = '#!/bin/sh\nprintf "foreign-executable\\n"\n';
    for (const gap of ["\u00a0", "\v", "\f", "\u2003", "\ufeff"]) {
      writeFileSync(join(cwd, `scripts/plan-cleanup${gap}--discard`), stub, { mode: 0o755 });
      mkdirSync(join(cwd, `${gap}scripts`));
      writeFileSync(join(cwd, `${gap}scripts/plan-cleanup`), stub, { mode: 0o755 });
      for (const command of [`scripts/plan-cleanup${gap}--discard old`, `${gap}scripts/plan-cleanup --discard old`]) {
        expect(execFileSync("/bin/bash", ["--noprofile", "--norc", "-c", command], {
          cwd, env: { ...process.env, BASH_ENV: "" }, encoding: "utf8",
        }).trim()).toBe("foreign-executable");
        expect(isNarrowPlanCleanupCommand(command, cwd)).toBe(false);
        writeFileSync(join(cwd, "PLAN.md"), "# PLAN.md\n- Status: DRAFT\n");
        expect(planMutationGuardDecision({ cwd, tool_name: "Bash", tool_input: { command } })).toMatchObject({
          hookSpecificOutput: { permissionDecision: "deny" },
        });
      }
    }
    expect(isNarrowPlanCleanupCommand(" \tscripts/plan-cleanup\t--discard old\t ", cwd)).toBe(true);
  } finally { rmSync(cwd, { recursive: true, force: true }); }
});

test("archiving and discarding preserve existing archives and active-run selection", () => {
  const cwd = mkdtempSync(join(tmpdir(), "cleanup-preserve-"));
  const cli = fileURLToPath(new URL("../../../scripts/plan-cleanup", import.meta.url));
  try {
    mkdirSync(join(cwd, "docs/plan"), { recursive: true });
    mkdirSync(join(cwd, ".workflow"));
    const activePath = join(cwd, ".workflow/active-run.json");
    const active = '{"schema_version":1,"run":"do-not-change"}\n';
    writeFileSync(activePath, active);
    const oldArchive = join(cwd, "docs/plan/previous.md");
    writeFileSync(oldArchive, "previous archive\n");
    for (const mode of ["archive", "discard"]) {
      const plan = "# PLAN.md\n- Status: READY\n- Last revised: 2020-01-01\n";
      writeFileSync(join(cwd, "PLAN.md"), plan);
      const hash = createHash("sha256").update(plan).digest("hex");
      writeFileSync(join(cwd, "docs/plan/implemented.md"), `# Implemented: test\n- Source plan: \`PLAN.md\`\n- Source plan SHA-256: \`${hash}\`\n- Status: IMPLEMENTED\n`);
      execFileSync(cli, mode === "archive" ? ["--archive", "docs/plan/implemented.md"] : ["--discard", "unrelated-plan"], { cwd });
      expect(existsSync(join(cwd, "PLAN.md"))).toBe(false);
      expect(readFileSync(activePath, "utf8")).toBe(active);
      expect(readFileSync(oldArchive, "utf8")).toBe("previous archive\n");
    }
  } finally { rmSync(cwd, { recursive: true, force: true }); }
});
