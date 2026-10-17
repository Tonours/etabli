import { expect, test } from "bun:test";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

test("archiving and discarding preserve existing archives", () => {
  const cwd = mkdtempSync(join(tmpdir(), "cleanup-preserve-"));
  const cli = fileURLToPath(new URL("../../../scripts/plan-cleanup", import.meta.url));
  try {
    mkdirSync(join(cwd, "docs/plan"), { recursive: true });
    const oldArchive = join(cwd, "docs/plan/previous.md");
    writeFileSync(oldArchive, "previous archive\n");
    for (const mode of ["archive", "discard"]) {
      const plan = "# PLAN.md\n- Status: READY\n- Last revised: 2020-01-01\n";
      writeFileSync(join(cwd, "PLAN.md"), plan);
      const hash = createHash("sha256").update(plan).digest("hex");
      writeFileSync(join(cwd, "docs/plan/implemented.md"), `# Implemented: test\n- Source plan: \`PLAN.md\`\n- Source plan SHA-256: \`${hash}\`\n- Status: IMPLEMENTED\n`);
      execFileSync(cli, mode === "archive" ? ["--archive", "docs/plan/implemented.md"] : ["--discard", "unrelated-plan"], { cwd });
      expect(existsSync(join(cwd, "PLAN.md"))).toBe(false);
      expect(readFileSync(oldArchive, "utf8")).toBe("previous archive\n");
    }
  } finally { rmSync(cwd, { recursive: true, force: true }); }
});
