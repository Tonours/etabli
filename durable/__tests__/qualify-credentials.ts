import { mkdtemp, mkdir, readFile, writeFile, rm, stat } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const cli = process.env.PI_CLI ?? "pi";
const fixture = join(import.meta.dirname, "fixtures/credential-process.ts");
const faux = fileURLToPath(new URL("../node_modules/@earendil-works/pi-ai/dist/providers/faux.js", import.meta.url));

async function waitFile(path: string): Promise<void> {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    if (await stat(path).then(() => true, () => false)) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("Synthetic refresh never acquired the lock");
}

function run(command: string, args: string[], root: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: root, env: { PATH: process.env.PATH, HOME: root, XDG_CONFIG_HOME: join(root, "config"), XDG_DATA_HOME: join(root, "data"), PI_CODING_AGENT_DIR: join(root, "agent"), PI_OFFLINE: "1" }, stdio: ["ignore", "pipe", "pipe"], timeout: 45_000 });
    let output = "";
    child.stdout.on("data", (value: Buffer) => { output += value.toString(); });
    child.stderr.on("data", (value: Buffer) => { output += value.toString(); });
    child.on("error", () => reject(new Error("Synthetic qualification subprocess could not start")));
    child.on("exit", (code) => code === 0 && /\bok\b/.test(output) ? resolve(output) : reject(new Error(`Synthetic qualification subprocess failed (${code}); ${output.replace(/synthetic-[A-Za-z0-9_-]+/g, "[fixture]")}`)));
  });
}

for (const first of ["daemon", "cli"] as const) {
  const root = await mkdtemp(join(tmpdir(), "durable-pi-interop-"));
  try {
    await mkdir(join(root, "agent"), { mode: 0o700 });
    const auth = join(root, "agent/auth.json");
    await writeFile(auth, JSON.stringify({ fixtureoauth: { type: "oauth", access: "synthetic-expired", refresh: "synthetic-refresh", expires: 1 }, other: { type: "api_key", key: "synthetic-other" } }), { mode: 0o600 });
    const extension = join(root, "faux.js");
    await writeFile(extension, `import { createFauxCore, fauxAssistantMessage } from ${JSON.stringify(faux)};
import { appendFile, writeFile } from 'node:fs/promises';
const core = createFauxCore({ provider: 'fixtureoauth', models: [{ id: 'fixture' }] });
core.setResponses([fauxAssistantMessage('ok')]);
export default function(api) {
  api.registerProvider('fixtureoauth', {
    baseUrl: 'https://synthetic.invalid', api: core.api, models: core.models, streamSimple: core.streamSimple,
    oauth: {
      name: 'Synthetic OAuth', login: async () => { throw new Error('fixture has no login'); },
      refreshToken: async (current) => {
        await appendFile(${JSON.stringify(join(root, "refreshes"))}, 'refresh\\n');
        await writeFile(${JSON.stringify(join(root, "refresh-held"))}, 'ready');
        await new Promise(resolve => setTimeout(resolve, ${first === "cli" ? 11_500 : 0}));
        return { ...current, access: 'synthetic-rotated-access', refresh: 'synthetic-rotated-refresh', expires: Date.now() + 3600000 };
      },
      getApiKey: current => current.access
    }
  });
}
`);
    const cliArgs = ["--offline", "--no-session", "--no-extensions", "--no-skills", "--no-prompt-templates", "--no-context-files", "--no-themes", "--no-mcp", "--no-tools", "-e", extension, "--model", "fixtureoauth/fixture", "-p", "fixture"];
    let one: Promise<string>;
    let two: Promise<string>;
    if (first === "daemon") {
      one = run("node", [fixture, auth, root, "11500"], root);
      await waitFile(join(root, "refresh-held"));
      await new Promise((resolve) => setTimeout(resolve, 10_100));
      two = run(cli, cliArgs, root);
    } else {
      one = run(cli, cliArgs, root);
      await waitFile(join(root, "refresh-held"));
      two = run("node", [fixture, auth, root, "0"], root);
    }
    await Promise.all([one, two]);
    if (await readFile(join(root, "refreshes"), "utf8") !== "refresh\n") throw new Error("Duplicate synthetic OAuth refresh");
    const values = JSON.parse(await readFile(auth, "utf8")) as { other: { key: string }; fixtureoauth: { refresh: string } };
    if (values.other.key !== "synthetic-other" || values.fixtureoauth.refresh !== "synthetic-rotated-refresh") throw new Error("Synthetic provider entries lost");
    console.log(`${first}-first: two requests succeeded, one refresh, other provider preserved, lock held 11.5s`);
  } finally { await rm(root, { recursive: true, force: true }); }
}
