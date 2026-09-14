import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const resolvers = [
  new URL("../../../../workflow/runtime/obvault-topic-resolver.mjs", import.meta.url),
  new URL("../../../runtime/obvault-topic-resolver.mjs", import.meta.url),
];
const source = resolvers.find((url) => existsSync(fileURLToPath(url)));
if (!source) throw new Error("Etabli vault resolver missing; rerun Herdr setup/sync");
const { resolveObvaultRoot } = await import(source.href);
const root = resolveObvaultRoot();
if (!root) throw new Error("No vault available for the current Etabli scope / OBVAULT_ROOT");
const cli = join(root, "_meta/obvault");
const mode = process.argv[2];
const run = (args, { optional = false } = {}) => {
  const result = spawnSync(cli, args, {
    stdio: "inherit",
    env: { ...process.env, OBVAULT_ROOT: root },
  });
  if (optional) return;
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
};
if (mode === "session") {
  const cwd = process.env.HERDR_ACTIVE_PANE_CWD || process.cwd();
  run(["session", "--json", "--max-tokens", "2500", `context for work in ${cwd}`]);
} else if (mode === "status") {
  run(["status", "--json"]);
  run(["loop", "--json"], { optional: true });
} else {
  throw new Error("Expected session or status");
}
