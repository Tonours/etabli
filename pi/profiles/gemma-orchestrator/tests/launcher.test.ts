import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("launcher fixes tools and context loadout but accepts owner target/thinking", () => {
  const home = mkdtempSync(join(tmpdir(), "gemma-launch-"));
  try {
    const profile = join(home, "Library/Application Support/gemma-orchestrator/orchestration/pi");
    mkdirSync(profile, { recursive: true });
    writeFileSync(join(profile, "settings.json"), "{}"); writeFileSync(join(profile, "models.json"), "{}");
    const fake = join(home, "fake-pi"); writeFileSync(fake, "#!/bin/sh\nprintf 'fake-pi-invoked'\n", { mode: 0o700 });
    const launcher = join(import.meta.dir, "../../../../scripts/gemma-orchestrate-pi");
    const invoke = (args: string[]) => spawnSync(launcher, args, { env: { ...process.env, HOME: home, GEMMA_PI_BIN: fake }, encoding: "utf8", timeout: 1000 });
    for (const args of [["--exclude-tools", "finish_task"], ["-xt", "finish_task"], ["--no-tools"], ["-nt"], ["--skill", "/untrusted"], ["--prompt-template", "/untrusted"]]) {
      const result = invoke(args); expect(result.status).toBe(1); expect(result.stderr).toContain("fixed in this profile"); expect(result.stdout).not.toContain("fake-pi-invoked");
    }
    for (const value of ["", "gromarchy ", "host:22", "-oProxyCommand=bad"]) {
      const rejected = invoke(["--gemma-target", value]); expect(rejected.status).toBe(1); expect(rejected.stderr).toContain("invalid_target");
    }
    const allowed = invoke(["--gemma-target", "gromarchy", "--thinking", "high"]);
    expect(allowed.status).toBe(0); expect(allowed.stdout).toBe("fake-pi-invoked");
  } finally { rmSync(home, { recursive: true, force: true }); }
});
