import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
const root = join(import.meta.dir, "../../..");
const lib = await import(join(root, "pi/extensions/lib/rtk-runtime.ts"));
const run = (c: string, env: Record<string, string | undefined> | undefined) => {
  const exec = () => execFileSync("rtk", ["rewrite", c], { encoding: "utf-8", env });
  return typeof lib.readRtkRewrite === "function" ? lib.readRtkRewrite(exec) : exec();
};
const rw = lib.createRtkCommandRewriter(run, { enabled: true, mode: "always", timeoutMs: 2500, maxCacheEntries: 256, maxCommandLength: 4000, dangerousCommandBypass: true });
const corpus = readFileSync(join(import.meta.dir, "rtk-corpus.txt"), "utf8").trim().split("\n").map((l) => l.split("\t"));
let dataRw = 0, dispRw = 0, data = 0, disp = 0;
for (let pass = 0; pass < 2; pass++) {
  for (const [kind, cmd] of corpus) {
    let out = cmd; try { out = rw(cmd); } catch {}
    if (pass === 0) continue;
    const changed = out !== cmd;
    if (kind === "data") { data++; if (changed) dataRw++; } else { disp++; if (changed) dispRw++; }
  }
}
let calls = 0;
const counting = lib.createRtkCommandRewriter((c: string, env: Record<string, string | undefined> | undefined) => { calls++; return run(c, env); }, { enabled: true, mode: "always", timeoutMs: 2500, maxCacheEntries: 256, maxCommandLength: 4000, dangerousCommandBypass: true });
const unsupported = readFileSync(join(import.meta.dir, "rtk-unsupported.txt"), "utf8").trim().split("\n");
let unsupportedChanged = 0, unsupportedErrors = 0;
for (let pass = 0; pass < 2; pass++) for (const cmd of unsupported) { let out = cmd; try { out = counting(cmd); } catch { unsupportedErrors++; } if (out !== cmd) unsupportedChanged++; }
const unsupportedCalls = calls;
counting("git status"); counting("git status");
console.log(`pi_rtk_unsupported_rewritten=${unsupportedChanged}/${unsupported.length * 2}`);
console.log(`pi_rtk_unsupported_errors=${unsupportedErrors}`);
console.log(`pi_rtk_unsupported_runner_calls=${unsupportedCalls}`);
console.log(`pi_rtk_negative_control=${calls > unsupportedCalls ? "detected" : "missed"}`);
console.log(`pi_rtk_data_commands_rewritten=${dataRw}/${data}`);
console.log(`pi_rtk_display_commands_rewritten=${dispRw}/${disp}`);
