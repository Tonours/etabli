import { spawnSync } from "node:child_process";
import { afterEach, expect, test } from "bun:test";
import { mkdtemp, readFile, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execute, localPath, parseRemote, readLocal, remoteScript, run, writeLocal } from "../operations.ts";

const dirs: string[] = [];
const fixture = async () => { const dir = await realpath(await mkdtemp(join(tmpdir(), "gemma-profile-"))); dirs.push(dir); return dir; };
afterEach(async () => { for (const dir of dirs.splice(0)) await rm(dir, { recursive: true, force: true }); });

test("actual local command receipt has host, cwd, result and exit status", async () => {
  const root = await fixture(); const fact = await execute("local", "printf 'evidence'; exit 7", root);
  expect(fact.stdout).toBe("evidence"); expect(fact.code).toBe(7); expect(fact.cwd).toBe(root); expect(fact.hostname.length).toBeGreaterThan(0);
});
test("framing ignores banners and preserves a command exit255", async () => {
  const cwd = await fixture(); const nonce = "fixture";
  const raw = await run("/bin/sh", ["-s"], cwd, "printf 'login banner'\n" + remoteScript("printf 'body'; exit 255", nonce));
  const fact = parseRemote(raw, nonce); expect(fact.stdout).toBe("body"); expect(fact.code).toBe(255);
  expect(() => parseRemote({ ...raw, code: 255 }, nonce)).toThrow("transport_failed");
  expect(() => parseRemote(raw, "different")).toThrow("transport_failed");
});
test("quoting survives quotes, dollar expansion and shell syntax", async () => {
  const cwd = await fixture(); const nonce = "quotes";
  const raw = await run("/bin/sh", ["-s"], cwd, remoteScript("printf '%s' \"a'b $((2+3))\"", nonce));
  expect(parseRemote(raw, nonce).stdout).toBe("a'b 5");
});
test("missing, forged and duplicate frame markers are not proof", () => {
  const base = { stdout: "\nGEMMA_n_BEGIN\nhost\n/cwd\nLinux\nGEMMA_n_BODY\nbody\nGEMMA_n_END:0\n", stderr: "", code: 0, killed: false, truncated: false };
  expect(parseRemote(base, "n").hostname).toBe("host");
  for (const stdout of ["no frame", base.stdout.replace("END:0", "END:bad"), base.stdout + base.stdout, base.stdout.replace("BODY\n", "BODY\nGEMMA_n_BODY\n")]) {
    expect(() => parseRemote({ ...base, stdout }, "n")).toThrow("transport_failed");
  }
});
test("reads and writes reject outside paths and symlink escapes", async () => {
  const root = await fixture(), outside = await fixture(); await writeFile(join(outside, "file"), "private");
  await symlink(outside, join(root, "escape")); await symlink(join(outside, "file"), join(root, "link"));
  expect(await writeLocal(root, "valid", "ok")).toBe(join(root, "valid")); expect(await readFile(join(root, "valid"), "utf8")).toBe("ok");
  for (const path of [join(outside, "file"), "escape/file"]) {
    await expect(localPath(root, path)).rejects.toThrow("outside_workdir");
    await expect(writeLocal(root, path, "bad")).rejects.toThrow("outside_workdir");
  }
  await expect(writeLocal(root, "link", "bad")).rejects.toThrow("symlink_refused");
  expect(await readFile(join(outside, "file"), "utf8")).toBe("private");
});
test("abort kills only the owned command and cannot prove success", async () => {
  const root = await fixture(); const abort = new AbortController();
  const pending = run("/bin/sh", ["-c", "sleep 30"], root, "", abort.signal); setTimeout(() => abort.abort(), 30);
  const result = await pending; expect(result.killed).toBe(true); expect(result.code).not.toBe(0);
  const valid = await run("/bin/sh", ["-c", "printf alive"], root, ""); expect(valid.stdout).toBe("alive");
});
test("output limit marks an incomplete result", async () => {
  const result = await execute("local", "yes output", await fixture());
  expect(result.killed).toBe(true); expect(result.truncated).toBe(true); expect(result.code).not.toBe(0);
});
test("obvious nested SSH and injected aliases never execute", async () => {
  const root = await fixture();
  await expect(execute("local", "ssh gromarchy", root)).rejects.toThrow("nested_ssh_refused");
  await expect(execute("-oProxyCommand=bad", "true", root)).rejects.toThrow("invalid_target");
  expect((await execute("local", "printf ssh", root)).stdout).toBe("ssh");
});
test("file byte bounds include Unicode and never return a hidden prefix", async () => {
  const root = await fixture(); await writeFile(join(root, "large"), Buffer.alloc(65537));
  await expect(readLocal(root, "large")).rejects.toThrow("file_too_large");
  await expect(writeLocal(root, "unicode", "é".repeat(32769))).rejects.toThrow("file_too_large");
  await writeLocal(root, "valid", "é".repeat(32768));
  expect((await readLocal(root, "valid")).content).toBe("é".repeat(32768));
});

test("project FIFOs are refused without waiting for a peer", async () => {
  const root = await fixture();
  expect(spawnSync("/usr/bin/mkfifo", [join(root, "pipe")]).status).toBe(0);
  for (const method of ["readLocal", "writeLocal"]) {
    const source = `import { ${method} } from ${JSON.stringify(join(import.meta.dir, "../operations.ts"))}; try { await ${method}(${JSON.stringify(root)}, "pipe"${method === "writeLocal" ? ', "data"' : ""}); process.exit(2); } catch { process.exit(0); }`;
    const result = spawnSync(process.execPath, ["-e", source], { timeout: 1000 });
    expect(result.error).toBeUndefined(); expect(result.status).toBe(0);
  }
});

test("abort settles even when an escaped descendant keeps the pipes", async () => {
  const root = await fixture(); const abort = new AbortController();
  const code = `import os,time\npid=os.fork()\nif pid==0:\n os.setsid()\n open('escaped.pid','w').write(str(os.getpid()))\n time.sleep(5)\n os._exit(0)\nos._exit(0)`;
  const pending = run("/usr/bin/python3", ["-c", code], root, "", abort.signal);
  setTimeout(() => abort.abort(), 100);
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const result = await Promise.race([pending, new Promise<never>((_resolve, reject) => { timer = setTimeout(() => reject(new Error("owned_pipe_deadline_exceeded")), 1000); })]);
    expect(result.killed).toBe(true);
  } finally {
    if (timer) clearTimeout(timer);
    const pid = Number(await readFile(join(root, "escaped.pid"), "utf8"));
    if (Number.isInteger(pid) && pid > 1) { try { process.kill(pid, "SIGTERM"); } catch { } }
    await pending;
  }
});
