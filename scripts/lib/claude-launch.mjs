import { accessSync, constants, realpathSync, statSync } from "node:fs";
import { spawn } from "node:child_process";
import { homedir, constants as osConstants } from "node:os";
import { delimiter, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { buildLeanLaunch } from "./claude-profile.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const modes = new Set(["lean", "daily", "deep"]);
const help = `Usage: claude-{daily,deep,lean} [--inspect|--print-args] [--store DIR] [--claude-bin FILE] [--teams] [Claude args...]
Daily inherits native capabilities/model/effort; teams are opt-in.
Deep defaults to Opus, inherits effort; explicit --model/--effort flags win.
Lean uses a project-selected private MCP file and reduces optional plugins/skills.
Lean --no-strict-mcp still passes that file and also retains all native MCPs;
it does not isolate native vaults or remove their tools. TypeScript LSP is inherited.
--inspect / --print-args never launch Claude. Native store/auth files are never changed.
Use -- before prompt words matching launcher options. ETABLI_CLAUDE_BIN pins the CLI.
`;

export function resolveLaunch(mode, argv, env = process.env) {
  if (!modes.has(mode)) throw new Error("unknown launch mode");
  let store = env.CLAUDE_CONFIG_DIR,
    binary = env.ETABLI_CLAUDE_BIN,
    teams = false,
    inspect = null,
    strict = true;
  const args = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--") {
      args.push(...argv.slice(i));
      break;
    }
    if (arg === "--help" || arg === "-h") return { help: true };
    if (arg === "--inspect" || arg === "--print-args") {
      inspect = arg;
      continue;
    }
    if (arg === "--teams") {
      teams = true;
      continue;
    }
    if (arg === "--no-strict-mcp" && mode === "lean") {
      strict = false;
      continue;
    }
    if (arg === "--store" || arg === "--claude-bin") {
      const value = argv[++i];
      if (!value || value.startsWith("--"))
        throw new Error(`${arg} needs a value`);
      if (arg === "--store") store = value;
      else binary = value;
      continue;
    }
    if (arg.startsWith("--store=")) {
      store = arg.slice(8);
      if (!store) throw new Error("--store needs a value");
      continue;
    }
    if (arg.startsWith("--claude-bin=")) {
      binary = arg.slice(13);
      if (!binary) throw new Error("--claude-bin needs a value");
      continue;
    }
    args.push(arg);
  }
  const home = env.HOME || homedir();
  let configDir = resolve(home, ".claude");
  if (store) {
    try {
      if (!statSync(store).isDirectory()) throw new Error();
      configDir = realpathSync(store);
    } catch {
      throw new Error(
        `invalid Claude store: ${store} — choose an existing directory; no fallback performed`,
      );
    }
  }
  const candidates = binary
    ? [binary]
    : (env.PATH || "").split(delimiter).map((path) => join(path, "claude"));
  let cli;
  for (const candidate of candidates) {
    try {
      accessSync(candidate, constants.X_OK);
      if (statSync(candidate).isFile()) {
        cli = realpathSync(candidate);
        break;
      }
    } catch {}
  }
  if (!cli)
    throw new Error(
      "Claude binary unavailable — pin an executable with --claude-bin or ETABLI_CLAUDE_BIN",
    );
  for (const name of ["lean", "full", "daily", "deep"]) {
    if (cli === realpathSync(join(repoRoot, "scripts", `claude-${name}`)))
      throw new Error(
        "Claude binary resolves to a launcher — remove recursive alias or pin the real CLI",
      );
  }
  const childEnv = {
    ...env,
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: teams ? "1" : "0",
  };
  if (store) childEnv.CLAUDE_CONFIG_DIR = configDir;
  // An unset config dir must stay unset: native keychain/store selection remains native.
  const native = args.slice(
    0,
    args.indexOf("--") < 0 ? args.length : args.indexOf("--"),
  );
  if (
    mode === "deep" &&
    !native.some((arg) => arg === "--model" || arg.startsWith("--model="))
  )
    args.unshift("--model", "opus");
  const lean =
    mode === "lean"
      ? buildLeanLaunch({ repoRoot, home, strictMcp: strict, extraArgs: args })
      : null;
  return {
    cli,
    args: lean?.args || args,
    env: childEnv,
    inspect,
    configDir,
    storeSource: store ? "explicit" : "native-default",
    teams,
    mode,
    strict,
    scope: lean?.scope,
    vault: lean?.vault,
    skipped: lean?.skippedServers,
    cleanup: lean?.cleanup || (() => {}),
  };
}

async function main() {
  let launch;
  try {
    launch = resolveLaunch(process.argv[2], process.argv.slice(3));
    if (launch.help) {
      process.stdout.write(help);
      return;
    }
    if (launch.inspect) {
      if (launch.inspect === "--print-args")
        process.stdout.write(
          `scope=${launch.scope || "native"} vault=${launch.vault || "native"} strict_mcp=${launch.strict ? 1 : 0}\n${launch.args.join("\n")}\n`,
        );
      else
        process.stdout.write(
          JSON.stringify(
            {
              mode: launch.mode,
              binary: launch.cli,
              store: launch.configDir,
              store_source: launch.storeSource,
              teams: launch.teams,
              vault: launch.vault || null,
              skipped_servers: launch.skipped || [],
              args: launch.args,
              effective_model: null,
              effective_effort: null,
            },
            null,
            2,
          ) + "\n",
        );
      return;
    }
    if (launch.mode === "lean" && !launch.strict)
      process.stderr.write(
        "claude-lean: non-strict keeps native MCP servers alongside the project MCP; native vaults are not isolated\n",
      );
    if (launch.skipped?.length)
      process.stderr.write(
        `claude-lean: project vault MCP unavailable (${launch.skipped.join(", ")}); no vault fallback\n`,
      );
    await new Promise((done) => {
      const child = spawn(launch.cli, launch.args, {
        env: launch.env,
        stdio: "inherit",
      });
      let spawnError = false;
      const handlers = ["SIGINT", "SIGTERM", "SIGHUP"].map((signal) => {
        // A terminal already sends Ctrl-C to the whole foreground process group.
        const handler = () => {
          if (signal !== "SIGINT" || !process.stdin.isTTY) child.kill(signal);
        };
        process.on(signal, handler);
        return [signal, handler];
      });
      child.on("error", (error) => {
        spawnError = true;
        process.stderr.write(`claude-launch: ${error.message}\n`);
        process.exitCode = 2;
      });
      child.on("close", (code, signal) => {
        for (const [name, handler] of handlers) process.off(name, handler);
        process.exitCode = spawnError
          ? 2
          : (code ?? 128 + (osConstants.signals[signal] || 1));
        done();
      });
    });
  } catch (error) {
    process.stderr.write(`claude-launch: ${error.message}\n`);
    process.exitCode = 2;
  } finally {
    launch?.cleanup?.();
  }
}
let isMain = false;
try {
  isMain = Boolean(
    process.argv[1] &&
      realpathSync(process.argv[1]) === fileURLToPath(import.meta.url),
  );
} catch {}
if (isMain) await main();
