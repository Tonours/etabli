import { describe, expect, test, beforeEach } from "bun:test";
import { mkdtempSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runVerify } from "../verify.ts";

let workDir: string;

beforeEach(() => {
  workDir = mkdtempSync(join(tmpdir(), "nightshift-verify-test-"));
});

describe("runVerify", () => {
  test("returns ok when all commands succeed", async () => {
    const result = await runVerify(workDir, ["true", "echo hello"]);
    expect(result.status).toBe("ok");
    expect(result.failedCommand).toBeUndefined();
  });

  test("returns failed on first failing command", async () => {
    const result = await runVerify(workDir, ["true", "false", "echo should-not-run"]);
    expect(result.status).toBe("failed");
    expect(result.failedCommand).toBe("false");
  });

  test("returns ok for empty command list", async () => {
    const result = await runVerify(workDir, []);
    expect(result.status).toBe("ok");
  });

  test("runs commands in the specified directory", async () => {
    Bun.write(join(workDir, "marker.txt"), "exists");
    const result = await runVerify(workDir, ["test -f marker.txt"]);
    expect(result.status).toBe("ok");
  });

  test("fails when command references missing file", async () => {
    const result = await runVerify(workDir, ["test -f nonexistent.txt"]);
    expect(result.status).toBe("failed");
  });
});
