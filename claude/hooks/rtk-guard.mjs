import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { rtkDataFlowReason } from "../../workflow/runtime/rtk-data-flow.mjs";

const input = readFileSync(0, "utf8");
let command = "";
try {
  command = JSON.parse(input)?.tool_input?.command ?? "";
} catch {
  process.exit(0);
}
if (typeof command !== "string" || command === "" || rtkDataFlowReason(command) !== null) process.exit(0);

const result = spawnSync("rtk", ["hook", "claude"], { input, encoding: "utf8", timeout: 2000 });
if ((result.error && result.error.code !== "EPIPE") || result.signal) process.exit(0);
process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");
process.exitCode = result.status ?? 0;
