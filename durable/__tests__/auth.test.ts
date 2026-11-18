import { expect, test } from "bun:test";
import { mkdtemp, chmod, readFile, rm, stat, symlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { loadToken, readToken, apiConfig, remoteAuth } from "../src/auth.ts";

test("token survives restart, is private, and unsafe existing files fail closed", async () => {
  const root = await mkdtemp(join(tmpdir(), "durable-auth-"));
  try {
    const path = join(root, "token");
    const [first, concurrent] = await Promise.all([loadToken(path), loadToken(path)]);
    expect(concurrent).toBe(first);
    expect(first.length).toBe(43);
    expect(await loadToken(path)).toBe(first);
    expect((await stat(path)).mode & 0o777).toBe(0o600);
    await symlink(path, join(root, "link"));
    await expect(loadToken(join(root, "link"))).rejects.toThrow();
    await chmod(path, 0o644);
    await expect(readToken(path)).rejects.toThrow("0600");
    expect((await readFile(path, "utf8")).trim()).toBe(first);
    await chmod(path, 0o600);
    await writeFile(path, "invalid\n");
    await expect(loadToken(path)).rejects.toThrow("Invalid token");
    await expect(readToken(root)).rejects.toThrow();
  } finally { await rm(root, { recursive: true, force: true }); }
});

test("remote config is disabled by default and requires an exact identity allowlist", () => {
  expect(apiConfig(undefined)).toBeUndefined();
  expect(apiConfig({ port: 4318, identities: ["owner@example.invalid"] })).toEqual({ port: 4318, identities: ["owner@example.invalid"] });
  for (const raw of [null, false, [], {}, { port: 0, identities: ["a"] }, { port: 65536, identities: ["a"] }, { port: "4318", identities: ["a"] }, { port: 4318, identities: [] }, { port: 4318, identities: [""] }, { port: 4318, identities: ["a,b"] }, { port: 4318, identities: ["a\nb"] }]) expect(() => apiConfig(raw)).toThrow();
  expect(() => remoteAuth("", ["owner@example.invalid"])).toThrow();
});
