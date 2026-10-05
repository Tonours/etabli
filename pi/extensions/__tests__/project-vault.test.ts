import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { resolveObvaultRoot } from "../../../workflow/runtime/obvault-topic-resolver.mjs";
import { classifyWorkflowRoute } from "../lib/workflow-router-runtime.ts";

const dirs: string[] = [];
let previousRoot: string | undefined;
beforeEach(() => {
  previousRoot = process.env.OBVAULT_ROOT;
  delete process.env.OBVAULT_ROOT;
});
function fixture() {
  const home = realpathSync(mkdtempSync(join(tmpdir(), "project-vault-")));
  dirs.push(home);
  for (const vault of ["brain", "obvault"]) {
    mkdirSync(join(home, "work", vault, "_meta"), { recursive: true });
    writeFileSync(join(home, "work", vault, "_meta", "obvault"), "#!/bin/sh\nexit 0\n", { mode: 0o755 });
  }
  writeFileSync(join(home, ".etabli-scope"), "work\n");
  const cwd = join(home, "project");
  mkdirSync(cwd);
  execFileSync("git", ["init", "-q", cwd]);
  return { home, cwd };
}
afterEach(() => {
  if (previousRoot === undefined) delete process.env.OBVAULT_ROOT;
  else process.env.OBVAULT_ROOT = previousRoot;
  for (const dir of dirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

test("personal projects ignore machine work scope and accept vaults without AGENTS.md", () => {
  const { home, cwd } = fixture();
  expect(resolveObvaultRoot(undefined, { home, cwd })).toBe(resolve(home, "work/obvault"));
});

for (const remote of ["git@github.com:ForestAdmin/forestadmin.git", "github.com:ForestAdmin/repo.git", "deploy@github.com:ForestAdmin/repo.git", "github.com:/ForestAdmin/repo.git", "git@github.com:/ForestAdmin/repo.git", "https://github.com/forestadmin/agent", "ssh://git@github.com/ForestAdmin/forestadmin.git", "https://user@github.com/ForestAdmin/repo.git", "ssh://git@github.com:22/ForestAdmin/repo.git", "git+ssh://git@github.com/ForestAdmin/repo.git", "ssh+git://git@github.com/ForestAdmin/repo.git", "git+ssh://deploy@github.com:22/ForestAdmin/repo.git", "ssh+git://github.com:22/forestadmin/repo.git"]) {
  test(`ForestAdmin remote selects brain: ${remote}`, () => {
    const { home, cwd } = fixture();
    execFileSync("git", ["-C", cwd, "remote", "add", "origin", remote]);
    mkdirSync(join(cwd, "sub"));
    expect(resolveObvaultRoot(undefined, { home, cwd: join(cwd, "sub") })).toBe(resolve(home, "work/brain"));
    rmSync(join(home, "work/brain/_meta/obvault"));
    expect(resolveObvaultRoot(undefined, { home, cwd })).toBeNull();
  });
}

for (const remote of ["git@github.com:Tonours/forestadmin.git", "github.com:ForestAdmin-tools/repo.git", "github.com.evil.test:ForestAdmin/repo.git", "https://github.com/ForestAdmin-tools/repo", "https://github.com.evil.test/ForestAdmin/repo", "https://other.test/ForestAdmin/repo", "https://github.com@evil.test/ForestAdmin/repo", "git+ssh://github.com/ForestAdminX/repo.git", "ssh+git://github.com.evil.test/ForestAdmin/repo.git", "git+ssh://github.com@evil.test/ForestAdmin/repo.git", "ssh+git://github.com/evil/../ForestAdmin/repo.git", "https://github.com/evil/../ForestAdmin/repo.git"]) {
  test(`lookalikes remain personal: ${remote}`, () => {
    const { home, cwd } = fixture();
    execFileSync("git", ["-C", cwd, "remote", "add", "origin", remote]);
    expect(resolveObvaultRoot(undefined, { home, cwd })).toBe(resolve(home, "work/obvault"));
  });
}

test("secondary ForestAdmin remotes and worktrees follow repository identity", () => {
  const { home, cwd } = fixture();
  execFileSync("git", ["-C", cwd, "remote", "add", "origin", "git@github.com:Tonours/fork.git"]);
  execFileSync("git", ["-C", cwd, "remote", "add", "upstream", "git@github.com:ForestAdmin/repo.git"]);
  execFileSync("git", ["-C", cwd, "-c", "user.name=test", "-c", "user.email=test@example.test", "commit", "--allow-empty", "-qm", "init"]);
  const worktree = join(home, "worktree");
  execFileSync("git", ["-C", cwd, "worktree", "add", "--detach", worktree]);
  expect(resolveObvaultRoot(undefined, { home, cwd: worktree })).toBe(resolve(home, "work/brain"));
  expect(resolveObvaultRoot(undefined, { home, cwd: home })).toBe(resolve(home, "work/obvault"));
});

test("static knowledge commands use the provided repository cwd", () => {
  const { cwd } = fixture();
  execFileSync("git", ["-C", cwd, "remote", "add", "origin", "git@github.com:ForestAdmin/repo.git"]);
  expect(classifyWorkflowRoute("help me with React frontend architecture", { cwd }).knowledgeContext?.command).toContain("work/brain/_meta/obvault");
});

test("static knowledge commands default to session cwd and honor exclusive override", () => {
  const { home, cwd } = fixture();
  execFileSync("git", ["-C", cwd, "remote", "add", "origin", "git@github.com:ForestAdmin/repo.git"]);
  const module = new URL("../../../workflow/runtime/workflow-router-core.mjs", import.meta.url).href;
  const program = `import { classifyWorkflowRoute } from ${JSON.stringify(module)}; console.log(classifyWorkflowRoute("help me with React frontend architecture").knowledgeContext.command);`;
  const command = execFileSync("node", ["--input-type=module", "-e", program], {
    cwd, env: { ...process.env, OBVAULT_ROOT: "" }, encoding: "utf8",
  });
  expect(command).toContain("work/brain/_meta/obvault");
  const override = join(home, "work/obvault");
  process.env.OBVAULT_ROOT = override;
  expect(resolveObvaultRoot(undefined, { home, cwd })).toBe(override);
  expect(classifyWorkflowRoute("help me with React frontend architecture").knowledgeContext?.command).toContain(`${override}/_meta/obvault`);
  process.env.OBVAULT_ROOT = join(home, "missing");
  expect(resolveObvaultRoot(undefined, { home, cwd })).toBeNull();
});

for (const mode of ["repository selection", "common directory", "config injection"]) {
  test(`session cwd isolates inherited Git ${mode}`, () => {
    const personal = fixture();
    const forest = fixture();
    execFileSync("git", ["-C", forest.cwd, "remote", "add", "origin", "git@github.com:ForestAdmin/repo.git"]);
    const module = new URL("../../../workflow/runtime/obvault-topic-resolver.mjs", import.meta.url).href;
    const environment = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith("GIT_")));
    for (const [project, foreign, vault] of [[personal, forest, "obvault"], [forest, personal, "brain"]] as const) {
      const conflict = mode === "repository selection"
        ? { GIT_DIR: join(foreign.cwd, ".git"), GIT_WORK_TREE: foreign.cwd }
        : mode === "common directory"
          ? { GIT_COMMON_DIR: join(foreign.cwd, ".git") }
          : { GIT_CONFIG_COUNT: "1", GIT_CONFIG_KEY_0: "remote.origin.url", GIT_CONFIG_VALUE_0: vault === "brain" ? "git@github.com:Tonours/repo.git" : "git@github.com:ForestAdmin/repo.git" };
      const program = `import { resolveObvaultRoot } from ${JSON.stringify(module)}; console.log(resolveObvaultRoot(undefined, ${JSON.stringify(project)}));`;
      const root = execFileSync("node", ["--input-type=module", "-e", program], {
        cwd: project.cwd, env: { ...environment, OBVAULT_ROOT: "", ...conflict }, encoding: "utf8",
      }).trim();
      expect(root).toBe(join(project.home, "work", vault));
    }
  });
}

test("legacy cached retrieval commands are re-quoted for the selected root", () => {
  const { home } = fixture();
  const root = join(home, "vault with spaces and 'quote");
  const cache = join(home, "cache");
  mkdirSync(join(root, "_meta"), { recursive: true });
  mkdirSync(cache);
  writeFileSync(join(root, "_meta/obvault"), '#!/bin/sh\n[ "$1" = context ] || exit 97\nprintf "retrieval-ok\\n"\n', { mode: 0o755 });
  const prompt = "FinOps";
  const hash = (value: string) => createHash("sha256").update(value).digest("hex");
  const legacy = {
    topics: ["finops"], query: "finops", reason: "legacy cache fixture",
    command: `${root}/_meta/obvault context --json --max-tokens 2500 "finops"`,
    source: "obvault-metadata", matchedNotes: [],
  };
  writeFileSync(join(cache, `etabli-obvault-route-${process.getuid?.() ?? 0}.json`), JSON.stringify({
    v: 1, e: [{ k: hash(`${root}\n${prompt}`), f: hash(""), x: Date.now() + 10_000, v: legacy }],
  }));
  const module = new URL("../../../workflow/runtime/obvault-topic-resolver.mjs", import.meta.url).href;
  const program = `import { resolveDynamicKnowledgeContext } from ${JSON.stringify(module)}; console.log(JSON.stringify(resolveDynamicKnowledgeContext(${JSON.stringify(prompt)}, { roots: [${JSON.stringify(root)}] })));`;
  const context = JSON.parse(execFileSync("node", ["--input-type=module", "-e", program], {
    env: { ...process.env, TMPDIR: cache, ETABLI_OBVAULT_ROUTE_CACHE: "1" }, encoding: "utf8",
  }));
  expect(context?.query).toBe("finops");
  expect(execFileSync("/bin/sh", ["-c", context.command], { encoding: "utf8" }).trim()).toBe("retrieval-ok");
  for (const cachedValue of [null, { ...legacy, query: { toString: "invalid" } }, { ...legacy, query: ["finops"] }]) {
    writeFileSync(join(cache, `etabli-obvault-route-${process.getuid?.() ?? 0}.json`), JSON.stringify({
      v: 1, e: [{ k: hash(`${root}\n${prompt}`), f: hash(""), x: Date.now() + 10_000, v: cachedValue }],
    }));
    expect(JSON.parse(execFileSync("node", ["--input-type=module", "-e", program], {
      env: { ...process.env, TMPDIR: cache, ETABLI_OBVAULT_ROUTE_CACHE: "1" }, encoding: "utf8",
    }))).toBeNull();
  }
});

for (const scheme of ["https", "ssh", "git+ssh", "ssh+git"]) {
  for (const host of ["%67ithub.com", "github%2ecom", "GITHUB.COM"]) {
    test(`canonical GitHub authority selects brain: ${scheme}://${host}`, () => {
      const { home, cwd } = fixture();
      execFileSync("git", ["-C", cwd, "remote", "add", "origin", `${scheme}://git@${host}/ForestAdmin/repo.git`]);
      expect(resolveObvaultRoot(undefined, { home, cwd })).toBe(resolve(home, "work/brain"));
    });
  }
  for (const host of ["ｇｉｔｈｕｂ.com", "github。com", "%EF%BD%87ithub.com", "%2567ithub.com", "github.com.evil.test", "%zzithub.com"]) {
    test(`noncanonical authority remains personal: ${scheme}://${host}`, () => {
      const { home, cwd } = fixture();
      execFileSync("git", ["-C", cwd, "remote", "add", "origin", `${scheme}://git@${host}/ForestAdmin/repo.git`]);
      expect(resolveObvaultRoot(undefined, { home, cwd })).toBe(resolve(home, "work/obvault"));
    });
  }
}

for (const scheme of ["https", "ssh", "git+ssh", "ssh+git"]) {
  for (const suffix of ["?other/repo", "#/../other/repo"]) {
    test(`URI suffix cannot change repository identity: ${scheme}${suffix}`, () => {
      const { home, cwd } = fixture();
      execFileSync("git", ["-C", cwd, "remote", "add", "origin", `${scheme}://git@github.com/ForestAdmin/repo.git${suffix}`]);
      expect(resolveObvaultRoot(undefined, { home, cwd })).toBe(resolve(home, "work/obvault"));
    });
  }
}

for (const scheme of ["ssh", "git+ssh", "ssh+git"]) {
  for (const target of ["git@evil.test%2F@github.com/ForestAdmin/repo.git", "git@github.com/ForestAdmin/x%2F..%2F..%2Fother%2Frepo"]) {
    test(`SSH decoding cannot invent repository identity: ${scheme}://${target}`, () => {
      const { home, cwd } = fixture();
      const remote = `${scheme}://${target}`;
      execFileSync("git", ["-C", cwd, "remote", "add", "origin", remote]);
      expect(resolveObvaultRoot(undefined, { home, cwd })).toBe(resolve(home, "work/obvault"));
      const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith("GIT_")));
      try {
        execFileSync("git", ["-C", cwd, "-c", "core.sshCommand=/usr/bin/false", "ls-remote", remote], {
          env: { ...env, GIT_TRACE: "1", GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" }, stdio: "pipe",
        });
        throw new Error("disabled SSH helper unexpectedly succeeded");
      } catch (error) {
        expect(String((error as { stderr?: Buffer }).stderr)).toContain(target.includes("evil.test") ? "/usr/bin/false git@evil.test " : "/ForestAdmin/x/../../other/repo");
      }
    });
  }
}
