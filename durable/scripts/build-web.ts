import { copyFile, mkdtemp, readdir, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export const OUTPUTS = ["app.js", "style.css"] as const;
type Rename = (from: string, to: string) => Promise<void>;

/** Moves the two build outputs of `source` into `destination`, one rename each; refuses any other output set and restores both previous files when a rename fails. */
export async function place(source: string, destination: string, move: Rename = rename): Promise<void> {
  const found = (await readdir(source)).sort();
  if (found.join("\n") !== [...OUTPUTS].sort().join("\n")) throw new Error(`build output must be exactly ${OUTPUTS.join(", ")}; found ${found.join(", ") || "nothing"}`);
  const previous = new Map<string, string>();
  for (const name of OUTPUTS) {
    const copy = join(source, `${name}.previous`);
    try { await copyFile(join(destination, name), copy); previous.set(name, copy); }
    catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
  }
  const placed: string[] = [];
  try {
    for (const name of OUTPUTS) { await move(join(source, name), join(destination, name)); placed.push(name); }
  } catch (error) {
    for (const name of OUTPUTS) {
      const copy = previous.get(name);
      if (copy) await copyFile(copy, join(destination, name));
      else if (placed.includes(name)) await rm(join(destination, name), { force: true });
    }
    throw error;
  }
}

async function main(): Promise<void> {
  const root = fileURLToPath(new URL("..", import.meta.url));
  const { build } = await import("vite");
  const temporary = await mkdtemp(join(root, ".web-build-"));
  try {
    await build({ configFile: join(root, "vite.config.ts"), logLevel: "warn", build: { outDir: temporary } });
    await place(temporary, join(root, "web"));
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

if (import.meta.main) {
  main().catch((error: unknown) => { console.error(error instanceof Error ? error.message : error); process.exit(1); });
}
