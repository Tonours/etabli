import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { execSync } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";

export interface ValidationResult {
  name: string;
  status: "pass" | "warn" | "fail" | "skip";
  message: string;
  durationMs: number;
}

export interface ValidationSuite {
  timestamp: string;
  cwd: string;
  results: ValidationResult[];
  summary: {
    pass: number;
    warn: number;
    fail: number;
    skip: number;
    total: number;
  };
}

function timed(name: string, fn: () => Omit<ValidationResult, "name" | "durationMs">): ValidationResult {
  const start = Date.now();
  const result = fn();
  return { name, durationMs: Date.now() - start, ...result };
}

export const checks = {
  planExists(cwd: string): ValidationResult {
    return timed("PLAN.md status", () => {
      const planPath = join(cwd, "PLAN.md");
      if (!existsSync(planPath)) {
        return { status: "skip", message: "No PLAN.md found (not required for all work)" };
      }

      const content = readFileSync(planPath, "utf-8");
      if (!content.includes("## Goal")) {
        return { status: "warn", message: "PLAN.md missing ## Goal section" };
      }

      const status = content.match(/^- Status:\s*(.+)$/m)?.[1]?.trim();
      if (!status) {
        return { status: "warn", message: "PLAN.md missing Status field" };
      }
      if (status === "DRAFT") {
        return { status: "warn", message: "PLAN.md is DRAFT - needs review before implementation" };
      }
      if (status === "CHALLENGED") {
        return { status: "fail", message: "PLAN.md is CHALLENGED - blockers must be resolved" };
      }

      return { status: "pass", message: `PLAN.md is ${status}` };
    });
  },

  gitState(cwd: string): ValidationResult {
    return timed("Git working tree", () => {
      try {
        const status = execSync("git status --porcelain", { cwd, encoding: "utf-8" }).trim();
        if (status === "") {
          return { status: "pass", message: "Working tree clean" };
        }

        const lines = status.split("\n").filter((line) => line.trim());
        const staged = lines.filter((line) => /^[MADRCU]/.test(line)).length;
        const unstaged = lines.filter((line) => /^\s[MDRC]|^\?\?/.test(line)).length;
        return { status: "warn", message: `${staged} staged, ${unstaged} unstaged changes` };
      } catch {
        return { status: "skip", message: "Not a git repository" };
      }
    });
  },

  mergeConflicts(cwd: string): ValidationResult {
    return timed("Merge conflicts", () => {
      try {
        const grep = execSync("git grep -l '^<<<<<<< ' 2>/dev/null || true", {
          cwd,
          encoding: "utf-8",
        }).trim();
        if (grep === "") {
          return { status: "pass", message: "No merge conflicts detected" };
        }

        const files = grep.split("\n").filter((file) => file.trim());
        return { status: "fail", message: `Merge conflicts in: ${files.join(", ")}` };
      } catch {
        return { status: "skip", message: "Could not check for conflicts" };
      }
    });
  },

  tsCompilation(cwd: string): ValidationResult {
    return timed("TypeScript compilation", () => {
      const piDir = join(cwd, "pi");
      if (!existsSync(piDir)) {
        return { status: "skip", message: "No pi/ directory found" };
      }

      const outDir = mkdtempSync(join(tmpdir(), "pi-validate-build-"));
      try {
        execSync(`bun build --target=bun extensions/*.ts --outdir=${outDir}`, {
          cwd: piDir,
          encoding: "utf-8",
          timeout: 30000,
        });
        return { status: "pass", message: "All extensions compile successfully" };
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        return { status: "fail", message: `Build failed: ${message.slice(0, 200)}` };
      } finally {
        rmSync(outDir, { recursive: true, force: true });
      }
    });
  },

  largeFiles(cwd: string): ValidationResult {
    return timed("Large files", () => {
      try {
        const result = execSync(
          "find . -type f -size +500k ! -path './node_modules/*' ! -path './.git/*' ! -path './.pi/*' 2>/dev/null | head -10 || true",
          { cwd, encoding: "utf-8", timeout: 5000 },
        ).trim();
        if (result === "") {
          return { status: "pass", message: "No large files (>500KB) in repo" };
        }

        const files = result.split("\n").filter((file) => file.trim());
        const preview = files.slice(0, 3).join(", ");
        return {
          status: "warn",
          message: `${files.length} large file(s): ${preview}${files.length > 3 ? "..." : ""}`,
        };
      } catch {
        return { status: "skip", message: "Could not check file sizes" };
      }
    });
  },
};

export function runAllValidations(cwd: string): ValidationSuite {
  const results = [
    checks.planExists(cwd),
    checks.gitState(cwd),
    checks.mergeConflicts(cwd),
    checks.tsCompilation(cwd),
    checks.largeFiles(cwd),
  ];

  return {
    timestamp: new Date().toISOString(),
    cwd,
    results,
    summary: {
      pass: results.filter((result) => result.status === "pass").length,
      warn: results.filter((result) => result.status === "warn").length,
      fail: results.filter((result) => result.status === "fail").length,
      skip: results.filter((result) => result.status === "skip").length,
      total: results.length,
    },
  };
}

export function formatValidationReport(suite: ValidationSuite): string {
  const icons = { pass: "✓", warn: "⚠", fail: "✗", skip: "○" } as const;
  const lines = ["Validation Report", "=================", ""];

  for (const result of suite.results) {
    lines.push(`${icons[result.status]} ${result.name}: ${result.message} (${result.durationMs}ms)`);
  }

  lines.push("");
  lines.push(
    `Summary: ${suite.summary.pass} pass, ${suite.summary.warn} warn, ${suite.summary.fail} fail, ${suite.summary.skip} skip`,
  );

  if (suite.summary.fail > 0) {
    lines.push("", "Critical issues detected. Address failures before continuing.");
  } else if (suite.summary.warn > 0) {
    lines.push("", "Warnings present. Review recommended.");
  }

  return lines.join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("validate", {
    description: "Run validation suite on current cwd",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Running validation suite...", "info");
      const suite = runAllValidations(ctx.cwd);

      pi.sendMessage({
        customType: "validation-report",
        content: formatValidationReport(suite),
        display: true,
      });

      if (suite.summary.fail > 0) {
        ctx.ui.notify(`${suite.summary.fail} validation failure(s)`, "error");
      } else if (suite.summary.warn > 0) {
        ctx.ui.notify(`${suite.summary.warn} validation warning(s)`, "warning");
      } else {
        ctx.ui.notify("All validations passed", "info");
      }
    },
  });

  pi.registerTool({
    name: "validate",
    label: "Validate",
    description: "Run the validation suite on the current working directory.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _args, _signal, _onUpdate, ctx) {
      const suite = runAllValidations(ctx.cwd);
      const lines = suite.results.map((result) => `${result.name}: ${result.status} - ${result.message}`);
      lines.push("");
      lines.push(`Summary: ${suite.summary.pass} pass, ${suite.summary.warn} warn, ${suite.summary.fail} fail`);

      return {
        content: [{ type: "text" as const, text: lines.join("\n") }],
        details: { suite, canContinue: suite.summary.fail === 0 },
      };
    },
  });

  pi.on("agent_end", async (_event, ctx) => {
    const autoValidate = process.env.PI_AUTO_VALIDATE;
    if (autoValidate !== "1" && autoValidate !== "true") return;

    const suite = runAllValidations(ctx.cwd);
    if (suite.summary.fail > 0) {
      ctx.ui.notify(`${suite.summary.fail} validation failure(s) detected`, "error");
    }
  });

  pi.on("session_start", async (_event, ctx) => {
    const planPath = join(ctx.cwd, "PLAN.md");
    if (!existsSync(planPath)) return;

    const status = readFileSync(planPath, "utf-8").match(/^- Status:\s*(.+)$/m)?.[1]?.trim();
    if (status === "CHALLENGED") {
      pi.sendMessage({
        customType: "validation-warning",
        content:
          "PLAN.md is CHALLENGED. Review and resolve blockers before implementation.\n\nUse `/validate` for the full validation report.",
        display: true,
      });
    }
  });
}
