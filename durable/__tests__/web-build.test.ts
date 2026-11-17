import { expect, test } from "bun:test";
import { mkdir, mkdtemp, readdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { place } from "../scripts/build-web.ts";

async function scene(outputs: Record<string, string>) {
  const root = await mkdtemp(join(tmpdir(), "web-build-"));
  const source = join(root, "build"), destination = join(root, "web");
  await mkdir(source); await mkdir(destination);
  for (const [name, text] of Object.entries(outputs)) await writeFile(join(source, name), text);
  for (const name of ["app.js", "style.css", "index.html", "sw.js"]) await writeFile(join(destination, name), `old ${name}`);
  const files = async () => Object.fromEntries(await Promise.all((await readdir(destination)).sort().map(async (name) => [name, await readFile(join(destination, name), "utf8")])));
  return { source, destination, files, cleanup: () => rm(root, { recursive: true, force: true }) };
}
const before = { "app.js": "old app.js", "index.html": "old index.html", "style.css": "old style.css", "sw.js": "old sw.js" };

test("places exactly the two outputs and leaves the shell files untouched", async () => {
  const s = await scene({ "app.js": "new app", "style.css": "new style" });
  try {
    await place(s.source, s.destination);
    expect(await s.files()).toEqual({ ...before, "app.js": "new app", "style.css": "new style" });
  } finally { await s.cleanup(); }
});

for (const [name, outputs] of [["missing", { "app.js": "new app" }], ["extra", { "app.js": "new app", "style.css": "new style", "index.html": "emitted shell" }]] as const) {
  test(`refuses a ${name} output and leaves web unchanged`, async () => {
    const s = await scene(outputs);
    try {
      await expect(place(s.source, s.destination)).rejects.toThrow("build output must be exactly app.js, style.css");
      expect(await s.files()).toEqual(before);
    } finally { await s.cleanup(); }
  });
}

test("restores both previous files when the second rename fails", async () => {
  const s = await scene({ "app.js": "new app", "style.css": "new style" });
  let calls = 0;
  const failing = async (from: string, to: string) => { if (++calls === 2) throw new Error("rename failed"); await rename(from, to); };
  try {
    await expect(place(s.source, s.destination, failing)).rejects.toThrow("rename failed");
    expect(await s.files()).toEqual(before);
  } finally { await s.cleanup(); }
});
