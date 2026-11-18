import { expect, test } from "bun:test";
import { mkdtemp, readFile, writeFile, symlink, rm, stat } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { spawn } from "node:child_process";
import lockfile from "proper-lockfile";
import { SharedCredentialStore } from "../src/credentials.ts";
import { until } from "./helpers.ts";

function child(path: string, root: string, delay: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const process = spawn("node", [join(import.meta.dirname, "fixtures/credential-process.ts"), path, root, String(delay)], { stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    process.stdout.on("data", (value: Buffer) => { output += value.toString(); });
    process.stderr.on("data", (value: Buffer) => { output += value.toString(); });
    process.on("error", reject);
    process.on("exit", (code) => code === 0 ? resolve(output) : reject(new Error(`Synthetic credential subprocess failed (${code})`)));
  });
}

test("canonical aliases serialize expired OAuth across real processes and preserve other providers", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-auth-"));
  try {
    const path = join(root, "auth.json");
    const alias = join(root, "alias.json");
    await writeFile(path, JSON.stringify({ fixtureoauth: { type: "oauth", access: "synthetic-expired", refresh: "synthetic-refresh", expires: 1 }, other: { type: "api_key", key: "synthetic-other" } }), { mode: 0o600 });
    await symlink(path, alias);
    const first = child(path, root, 250);
    await until(() => stat(join(root, "refresh-held")).then(() => true, () => false));
    const second = child(alias, root, 0);
    expect(await Promise.all([first, second])).toEqual(["ok\n", "ok\n"]);
    expect(await readFile(join(root, "refreshes"), "utf8")).toBe("refresh\n");
    const store = new SharedCredentialStore(alias);
    expect(await store.read("other")).toEqual({ type: "api_key", key: "synthetic-other" });
    const current = await store.read("fixtureoauth");
    expect(await store.modify("fixtureoauth", async () => undefined)).toEqual(current);
    expect((await stat(path)).mode & 0o777).toBe(0o600);
    expect((await stat(alias)).isFile()).toBe(true);
  } finally { await rm(root, { recursive: true, force: true }); }
}, 15_000);

test("credential reads honor Pi's non-atomic-write lock and cancellation bounds acquisition", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-auth-read-"));
  try {
    const path = join(root, "auth.json");
    await writeFile(path, "{}", { mode: 0o600 });
    const release = await lockfile.lock(path, { stale: 30_000, update: 5_000 });
    const store = new SharedCredentialStore(path, 1000);
    await writeFile(path, "");
    let resolved = false;
    const reading = store.read("other").then((value) => { resolved = true; return value; });
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(resolved).toBe(false);
    const controller = new AbortController();
    const cancelled = store.read("other", { signal: controller.signal });
    controller.abort();
    await expect(cancelled).rejects.toThrow("cancelled");
    await writeFile(path, JSON.stringify({ other: { type: "api_key", key: "synthetic" } }));
    await release();
    expect(await reading).toEqual({ type: "api_key", key: "synthetic" });
  } finally { await rm(root, { recursive: true, force: true }); }
});

test("a completed refresh persists a rotated token even when caller cancellation arrives", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-auth-cancel-"));
  try {
    const store = new SharedCredentialStore(join(root, "auth.json"));
    const controller = new AbortController();
    const credential = { type: "oauth" as const, access: "synthetic-new", refresh: "synthetic-rotated", expires: Date.now() + 10_000 };
    expect(await store.modify("provider", async () => { controller.abort(); return credential; }, { signal: controller.signal })).toEqual(credential);
    expect(await store.read("provider")).toEqual(credential);
  } finally { await rm(root, { recursive: true, force: true }); }
});
