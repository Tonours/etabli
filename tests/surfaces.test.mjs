import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, readlinkSync, realpathSync, rmSync, symlinkSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, test } from "node:test";
import {
  activeScopes,
  backupFile,
  backupStamp,
  claudeConfigOverride,
  declaredName,
  isShadowed,
  physicalHome,
  physicalPath,
  reconcile,
  seedPiSettings,
  skillRecords,
  surfaceExpected,
  writeJsonAtomic,
} from "../scripts/lib/surfaces.mjs";

const ROOT_SKIP = process.getuid?.() === 0 && "root ignores permission bits";

let tmp;
beforeEach(() => {
  tmp = realpathSync(mkdtempSync(join(tmpdir(), "surfaces-")));
});
afterEach(() => {
  rmSync(tmp, { recursive: true, force: true });
});

function isLink(path) {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch {
    return false;
  }
}

function writeSkill(dir, nameLine) {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "SKILL.md"), `---\n${nameLine ? `${nameLine}\n` : ""}description: fixture\n---\nbody\n`);
}

function link(target, path) {
  mkdirSync(join(path, ".."), { recursive: true });
  symlinkSync(target, path);
}

function fixtureRepo(root, catalogRows, sources) {
  mkdirSync(join(root, "workflow/runtime"), { recursive: true });
  mkdirSync(join(root, "vendor"), { recursive: true });
  writeFileSync(join(root, "workflow/runtime/skill-surface.tsv"), `# fixture\n${catalogRows.map((row) => row.join("\t")).join("\n")}\n`);
  writeFileSync(join(root, "vendor/sources.tsv"), sources.map((row) => row.join("\t")).join("\n"));
  return root;
}

function run(repoDir, homeDir, overrides = {}) {
  const lines = [];
  const counts = reconcile(
    {
      repoDir,
      homeDir,
      claudeRoot: join(homeDir, ".claude"),
      claudeOnly: false,
      scopes: ["shared"],
      records: skillRecords(repoDir),
      mode: "deploy",
      apply: true,
      install: false,
      verbose: false,
      timestamp: "smoke",
      live: false,
      ...overrides,
    },
    (status, message) => lines.push(`${status} ${message}`),
  );
  return { counts, lines };
}

describe("skill catalog", () => {
  test("declared names keep slugs and fall back to the directory name", () => {
    const cases = [
      ["how", "name: how", "how"],
      ["poteto-mode", "name: Poteto Mode", "poteto-mode"],
      ["technical-writing", "name: technical writing", "technical-writing"],
      ["no-name", "", "no-name"],
      ["quoted-name", 'name: "quoted-name"', "quoted-name"],
    ];
    for (const [dir, nameLine, expected] of cases) {
      writeSkill(join(tmp, dir), nameLine);
      assert.equal(declaredName(join(tmp, dir)), expected, nameLine);
    }
  });

  test("records take first-party scope from the path, vendor scope from sources.tsv, and skip the shelf", () => {
    const repo = join(tmp, "repo");
    writeSkill(join(repo, "skills/shared/core"), "name: core");
    writeSkill(join(repo, "skills/work/ticket"), "name: ticket");
    writeSkill(join(repo, "vendor/suite/skills/group/tool"), "name: tool-renamed");
    fixtureRepo(
      repo,
      [
        ["shared/core", "etabli", "1", "1"],
        ["work/ticket", "etabli", "0", "1"],
        ["group/tool", "suite", "1", "1"],
        ["shelved", "extras", "0", "1"],
      ],
      [["suite", "https://example.invalid/s.git", "main", "personal", "group/tool"]],
    );
    assert.deepEqual(skillRecords(repo), [
      { scope: "shared", name: "core", dir: join(repo, "skills/shared/core"), piCore: "1", source: "etabli" },
      { scope: "work", name: "ticket", dir: join(repo, "skills/work/ticket"), piCore: "0", source: "etabli" },
      { scope: "personal", name: "tool-renamed", dir: join(repo, "vendor/suite/skills/group/tool"), piCore: "1", source: "suite" },
    ]);
    assert.equal(skillRecords(join(tmp, "missing")), null);
  });

  test("surface policy: Claude gets every active-scope record, Pi only pi_core, empty scope fails closed", () => {
    const record = (scope, piCore) => ({ scope, piCore });
    assert.equal(surfaceExpected(".claude/skills", record("", "1"), ["shared"]), false);
    assert.equal(surfaceExpected(".pi/agent/skills", record("shared", "0"), ["shared"]), false);
    assert.equal(surfaceExpected(".pi/agent/skills", record("shared", "1"), ["shared"]), true);
    assert.equal(surfaceExpected(".claude/skills", record("shared", "0"), ["shared"]), true);
    assert.equal(surfaceExpected(".claude/skills", record("work", "1"), ["shared", "personal"]), false);
    assert.equal(surfaceExpected(".pi/agent/skills", record("work", "1"), ["shared"]), false);
  });

  test("adr is shadowed only while the work scope is active", () => {
    assert.equal(isShadowed("adr", ["shared", "work"]), true);
    assert.equal(isShadowed("adr", ["shared", "personal"]), false);
    assert.equal(isShadowed("adr", ["shared"]), false);
    assert.equal(isShadowed("conventions", ["shared", "work"]), false);
  });

  test("scopes come from ETABLI_SCOPE, then ~/.etabli-scope, and reject unknown values", () => {
    assert.deepEqual(activeScopes(tmp, {}), ["shared"]);
    writeFileSync(join(tmp, ".etabli-scope"), " work\n");
    assert.deepEqual(activeScopes(tmp, {}), ["shared", "work"]);
    assert.deepEqual(activeScopes(tmp, { ETABLI_SCOPE: "personal" }), ["shared", "personal"]);
    assert.throws(() => activeScopes(tmp, { ETABLI_SCOPE: "bogus" }), /unknown scope "bogus"/);
  });
});

describe("physical paths", () => {
  test("`..` applies after a symlink, as the kernel resolves it", () => {
    const repo = join(tmp, "repo");
    const outside = join(tmp, "outside/npm/node_modules");
    mkdirSync(join(repo, "pi/extensions"), { recursive: true });
    mkdirSync(outside, { recursive: true });
    symlinkSync(outside, join(repo, "pi/extensions/node_modules"));
    assert.equal(physicalPath(`${repo}/pi/extensions/node_modules/..`), join(tmp, "outside/npm"));
    assert.equal(physicalPath(`${repo}/../x`), join(tmp, "x"));
    assert.equal(physicalPath(`${repo}/skills/../../x`), join(tmp, "x"));
  });

  test("a dangling alias is followed and a symlink loop is indeterminate", () => {
    const repo = join(tmp, "repo");
    mkdirSync(repo);
    symlinkSync(join(tmp, "outside/missing"), join(repo, "alias"));
    assert.equal(physicalPath(join(repo, "alias/skill")), join(tmp, "outside/missing/skill"));
    symlinkSync(join(repo, "loop-b"), join(repo, "loop-a"));
    symlinkSync(join(repo, "loop-a"), join(repo, "loop-b"));
    assert.equal(physicalPath(join(repo, "loop-a/skill")), null);
  });

  test("an unreadable component is indeterminate, never resolved lexically", { skip: ROOT_SKIP }, () => {
    const repo = join(tmp, "repo");
    mkdirSync(join(repo, "private"), { recursive: true });
    chmodSync(join(repo, "private"), 0o000);
    try {
      assert.equal(physicalPath(join(repo, "private/alias/skill")), null);
    } finally {
      chmodSync(join(repo, "private"), 0o755);
    }
  });
});

describe("homes", () => {
  test("a home given as `<alias>/..` reads the scope file the kernel would", () => {
    mkdirSync(join(tmp, "real/sub"), { recursive: true });
    symlinkSync(join(tmp, "real/sub"), join(tmp, "alias"));
    writeFileSync(join(tmp, "real/.etabli-scope"), "work\n");
    const aliased = `${join(tmp, "alias")}/..`;
    assert.equal(physicalHome(aliased), join(tmp, "real"));
    assert.deepEqual(activeScopes(aliased, {}), ["shared", "work"]);
  });

  test("the Claude config override compares against the physical home", () => {
    mkdirSync(join(tmp, "real/sub"), { recursive: true });
    mkdirSync(join(tmp, "real/claude-config"));
    symlinkSync(join(tmp, "real/sub"), join(tmp, "alias"));
    symlinkSync(join(tmp, "real/claude-config"), join(tmp, "real/.claude"));
    const env = { HOME: `${join(tmp, "alias")}/..`, CLAUDE_CONFIG_DIR: join(tmp, "real/claude-config") };
    assert.equal(claudeConfigOverride(env), null);
  });
});

describe("reconcile", () => {
  function vendorRepo() {
    const repo = join(tmp, "repo");
    writeSkill(join(repo, "vendor/suiteA/skills/alpha"), "name: alpha");
    writeSkill(join(repo, "vendor/suiteA/skills/beta"), "name: beta");
    writeSkill(join(repo, "vendor/suiteB/skills/gamma"), "name: gamma");
    writeSkill(join(repo, "skills/shared/core-one"), "name: core-one");
    return fixtureRepo(
      repo,
      [
        ["shared/core-one", "etabli", "1", "1"],
        ["alpha", "suiteA", "1", "1"],
        ["beta", "suiteA", "0", "1"],
        ["gamma", "suiteB", "1", "1"],
      ],
      [
        ["suiteA", "https://example.invalid/a.git", "main", "shared", "alpha,beta"],
        ["suiteB", "https://example.invalid/b.git", "main", "shared", "gamma"],
      ],
    );
  }

  test("vendor skills: pi_core gating, foreign checkout, broken mirror, orphan and removed tree", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    const pi = join(home, ".pi/agent/skills");
    const claude = join(home, ".claude/skills");
    run(repo, home);
    assert.ok(isLink(join(pi, "alpha")) && isLink(join(claude, "alpha")));
    assert.ok(!isLink(join(pi, "beta")) && isLink(join(claude, "beta")));
    assert.ok(isLink(join(home, ".codex/skills/alpha")) && isLink(join(home, ".codex/skills/beta")));
    for (const retired of [".config/devin", ".agents"]) assert.ok(!existsSync(join(home, retired)));

    writeSkill(join(tmp, "foreign/suiteB/skills/gamma"), "name: gamma");
    writeSkill(join(tmp, "foreign/suiteA/skills/beta"), "name: beta");
    rmSync(join(pi, "gamma"));
    symlinkSync(join(tmp, "foreign/suiteB/skills/gamma"), join(pi, "gamma"));
    symlinkSync(join(tmp, "foreign/suiteA/skills/beta"), join(pi, "beta"));
    run(repo, home);
    assert.equal(readlinkSync(join(pi, "gamma")), join(repo, "vendor/suiteB/skills/gamma"));
    assert.ok(!isLink(join(pi, "beta")));

    symlinkSync(join(home, ".claude/skills/nothing-there"), join(pi, "ghost-mirror"));
    run(repo, home);
    assert.ok(!isLink(join(pi, "ghost-mirror")));

    fixtureRepo(
      repo,
      [
        ["shared/core-one", "etabli", "1", "1"],
        ["alpha", "suiteA", "1", "1"],
        ["beta", "suiteA", "0", "1"],
      ],
      [
        ["suiteA", "https://example.invalid/a.git", "main", "shared", "alpha,beta"],
        ["suiteB", "https://example.invalid/b.git", "main", "shared", "gamma"],
      ],
    );
    run(repo, home);
    assert.ok(!isLink(join(pi, "gamma")) && !isLink(join(claude, "gamma")));
    assert.ok(existsSync(join(repo, "vendor/suiteB/skills/gamma")));

    symlinkSync(join(repo, "vendor/suiteB/skills/gamma"), join(pi, "gamma"));
    symlinkSync(join(repo, "vendor/suiteB/skills/gamma"), join(claude, "gamma"));
    rmSync(join(repo, "vendor/suiteB"), { recursive: true });
    run(repo, home);
    assert.ok(!isLink(join(pi, "gamma")) && !isLink(join(claude, "gamma")));
  });

  test("stale skill prune follows relative and aliased targets and keeps everything outside managed roots", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    const claude = join(home, ".claude/skills");
    for (const target of ["claude/scopes/shared/skills/removed", "vendor/suiteA/skills/removed", "pi/skills/removed", "skills/shared/removed"]) {
      link(join(repo, target), join(claude, `gone-${target.split("/")[0]}`));
    }
    mkdirSync(join(tmp, "unmanaged-skill"));
    link(join(tmp, "unmanaged-skill"), join(claude, "unmanaged-skill"));
    mkdirSync(join(home, ".shared/skills/relative-live"), { recursive: true });
    link("../../.shared/skills/relative-live", join(claude, "relative-live"));
    link("../../.shared/skills/relative-gone", join(claude, "relative-dangling"));
    mkdirSync(join(repo, "pi/skills"), { recursive: true });
    link("../../../repo/pi/skills/relative-managed-gone", join(claude, "relative-managed-dangling"));
    symlinkSync(repo, join(tmp, "repo-alias"));
    link(join(tmp, "repo-alias/pi/skills/aliased-gone"), join(claude, "aliased-dangling"));
    link(join(tmp, "outside-any-repo/skills/keep-me"), join(claude, "outside-dangling"));
    run(repo, home);
    for (const name of ["gone-claude", "gone-vendor", "gone-pi", "gone-skills", "relative-managed-dangling", "aliased-dangling"]) {
      assert.ok(!isLink(join(claude, name)), name);
    }
    for (const name of ["unmanaged-skill", "relative-live", "relative-dangling", "outside-dangling", "alpha", "core-one"]) {
      assert.ok(isLink(join(claude, name)), name);
    }
  });

  test("a foreign link on a managed name moves to <surface>.bak, never inside the discovery root", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    const claude = join(home, ".claude/skills");
    link(`${repo}/../personal-skill`, join(claude, "alpha"));
    link(`${repo}/skills/../../personal-skill`, join(claude, "personal"));
    run(repo, home, { mode: "check" });
    assert.equal(readlinkSync(join(home, ".claude/skills.bak/alpha.bak.smoke")), `${repo}/../personal-skill`);
    assert.equal(readlinkSync(join(claude, "alpha")), join(repo, "vendor/suiteA/skills/alpha"));
    assert.ok(isLink(join(claude, "personal")));
  });

  test("a relative link through a dangling in-repo alias is foreign and moved aside", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    symlinkSync(join(tmp, "outside/missing"), join(repo, "alias"));
    link("../../../repo/alias/alpha", join(home, ".claude/skills/alpha"));
    run(repo, home);
    assert.equal(readlinkSync(join(home, ".claude/skills.bak/alpha.bak.smoke")), "../../../repo/alias/alpha");
  });

  test("a link through an unreadable in-repo directory is foreign and moved aside", { skip: ROOT_SKIP }, () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    mkdirSync(join(repo, "private"));
    symlinkSync(join(tmp, "outside"), join(repo, "private/alias"));
    link("../../../repo/private/alias/alpha", join(home, ".claude/skills/alpha"));
    chmodSync(join(repo, "private"), 0o000);
    try {
      run(repo, home, { mode: "check" });
    } finally {
      chmodSync(join(repo, "private"), 0o755);
    }
    assert.equal(readlinkSync(join(home, ".claude/skills.bak/alpha.bak.smoke")), "../../../repo/private/alias/alpha");
  });

  test("a failed backup leaves the user entry in place and counts as unresolved", { skip: ROOT_SKIP }, () => {
    const repo = vendorRepo();
    for (const [name, block] of [
      ["mkdir", (home) => writeFileSync(join(home, ".claude/skills.bak"), "not a directory\n")],
      ["rename", (home) => {
        mkdirSync(join(home, ".claude/skills.bak"), { recursive: true });
        chmodSync(join(home, ".claude/skills.bak"), 0o555);
      }],
    ]) {
      const home = join(tmp, `blocked-${name}`);
      mkdirSync(join(home, ".claude/skills"), { recursive: true });
      writeFileSync(join(home, ".claude/skills/alpha"), "mine\n");
      block(home);
      const { counts } = run(repo, home, { mode: "check" });
      if (name === "rename") chmodSync(join(home, ".claude/skills.bak"), 0o755);
      assert.ok(counts.unresolved > 0, name);
      assert.ok(!isLink(join(home, ".claude/skills/alpha")), name);
      assert.ok(lstatSync(join(home, ".claude/skills/alpha")).isFile(), name);
    }
  });

  test("a missing catalog skips record linking and record pruning but still prunes stale managed links", () => {
    const repo = join(tmp, "repo");
    mkdirSync(join(repo, "skills/shared/kept"), { recursive: true });
    const home = join(tmp, "home");
    link(join(repo, "pi/skills/ghost"), join(home, ".claude/skills/ghost"));
    link(join(repo, "skills/shared/kept"), join(home, ".claude/skills/orphan-if-catalogued"));
    const { counts, lines } = run(repo, home, { records: null });
    assert.ok(!isLink(join(home, ".claude/skills/ghost")));
    assert.ok(isLink(join(home, ".claude/skills/orphan-if-catalogued")));
    assert.ok(counts.unresolved > 0);
    assert.ok(lines.some((line) => line.includes("skill catalog source missing")));
  });

  test("hooks keep the exact rule; agents keep the *.md direct-child rule", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    const claudeRoot = join(home, ".claude");
    link(join(repo, "claude/hooks/proof-shadow.mjs"), join(claudeRoot, "hooks/proof-shadow.mjs"));
    link(join(repo, "claude/hooks/archive/personal.sh"), join(claudeRoot, "hooks/personal.sh"));
    link(join(repo, "claude/hooks/renamed-hook.mjs"), join(claudeRoot, "hooks/personal-alias.mjs"));
    link(join(repo, "claude/agents/playwright-generator.md"), join(claudeRoot, "agents/playwright-generator.md"));
    link(join(repo, "claude/agents/personal.json"), join(claudeRoot, "agents/personal.json"));
    link(join(repo, "claude/agents/nested/deep.md"), join(claudeRoot, "agents/deep.md"));
    link(join(repo, "claude/scopes/work/scripts/retired-routine"), join(claudeRoot, "scripts/retired-routine"));
    run(repo, home);
    for (const gone of ["hooks/proof-shadow.mjs", "agents/playwright-generator.md", "scripts/retired-routine"]) {
      assert.ok(!isLink(join(claudeRoot, gone)), gone);
    }
    for (const kept of ["hooks/personal.sh", "hooks/personal-alias.mjs", "agents/personal.json", "agents/deep.md"]) {
      assert.ok(isLink(join(claudeRoot, kept)), kept);
    }
  });

  test("work shadows the shared adr link on Claude only", () => {
    const repo = join(tmp, "repo");
    writeSkill(join(repo, "skills/shared/adr"), "name: adr");
    fixtureRepo(repo, [["shared/adr", "etabli", "1", "1"]], []);
    const home = join(tmp, "home");
    run(repo, home);
    assert.ok(isLink(join(home, ".claude/skills/adr")));
    run(repo, home, { scopes: ["shared", "work"] });
    assert.ok(!isLink(join(home, ".claude/skills/adr")));
    assert.ok(isLink(join(home, ".pi/agent/skills/adr")));
  });

  test("a Claude config dir inside a Codex skill skips every Codex link", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    const override = join(home, ".codex/skills/alpha");
    writeSkill(override, "name: personal");
    const { lines } = run(repo, home, { claudeRoots: [join(home, ".claude"), override] });
    assert.ok(lines.some((line) => line.startsWith("WARN Codex links skipped:") && line.includes(override)));
    assert.ok(!isLink(override) && !existsSync(join(home, ".codex/AGENTS.md")));
  });

  test("install mode replaces a foreign link but still backs up a file", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    link(join(tmp, "elsewhere"), join(home, ".claude/skills/alpha"));
    mkdirSync(join(home, ".claude/skills"), { recursive: true });
    writeFileSync(join(home, ".claude/skills/beta"), "mine\n");
    run(repo, home, { install: true });
    assert.equal(readlinkSync(join(home, ".claude/skills/alpha")), join(repo, "vendor/suiteA/skills/alpha"));
    assert.ok(!existsSync(join(home, ".claude/skills.bak/alpha.bak.smoke")));
    assert.ok(lstatSync(join(home, ".claude/skills.bak/beta.bak.smoke")).isFile());
  });

  test("two concurrent replacements of a stale link end valid, with no crash and no EEXIST", async () => {
    const repo = fixtureRepo(join(tmp, "repo"), [["shared/core-one", "etabli", "1", "1"]], []);
    writeSkill(join(repo, "skills/shared/core-one"), "name: core-one");
    const home = join(tmp, "home");
    const dest = join(home, ".claude/skills/core-one");
    const stale = "../../../repo/skills/shared/core-one";
    link(stale, dest);
    const racer = join(tmp, "racer.mjs");
    writeFileSync(
      racer,
      [
        'import { renameSync, symlinkSync } from "node:fs";',
        `const { reconcile, skillRecords } = await import(${JSON.stringify(join(dirname(fileURLToPath(import.meta.url)), "../scripts/lib/surfaces.mjs"))});`,
        `const [repo, home, dest, stale] = ${JSON.stringify([repo, home, dest, stale])};`,
        "const fails = [];",
        "for (let round = 0; round < 200; round += 1) {",
        "  symlinkSync(stale, `${home}/.claude/skills/.reset.${process.pid}`);",
        "  renameSync(`${home}/.claude/skills/.reset.${process.pid}`, dest);",
        '  reconcile({ repoDir: repo, homeDir: home, claudeRoot: `${home}/.claude`, claudeOnly: true, scopes: ["shared"], records: skillRecords(repo), mode: "deploy", apply: true, install: false, verbose: false, timestamp: "race", live: false }, (status, message) => status === "FAIL" && fails.push(message));',
        "}",
        "const clashes = fails.filter((message) => message.includes(\"EEXIST\"));",
        "if (clashes.length) throw new Error(clashes.join(\"; \"));",
        "",
      ].join("\n"),
    );
    const race = () =>
      new Promise((resolve) => {
        const child = spawn(process.execPath, [racer], { stdio: ["ignore", "ignore", "pipe"] });
        let stderr = "";
        child.stderr.on("data", (chunk) => (stderr += chunk));
        child.on("close", (status) => resolve({ status, stderr }));
      });
    for (const { status, stderr } of await Promise.all([race(), race()])) assert.equal(status, 0, stderr);
    assert.equal(readlinkSync(dest), join(repo, "skills/shared/core-one"));
    assert.deepEqual(readdirSync(join(home, ".claude/skills")), ["core-one"]);
  });

  test("dry run reports drift without touching the home", () => {
    const repo = vendorRepo();
    const home = join(tmp, "home");
    const { lines } = run(repo, home, { apply: false });
    assert.ok(lines.some((line) => line.startsWith("WOULD_LINK Claude skill alpha")));
    assert.ok(!existsSync(home));
  });
});

describe("Pi settings seed", () => {
  test("a settings symlink becomes a private local copy with no staged leftover", () => {
    const repo = join(tmp, "repo");
    const home = join(tmp, "home");
    mkdirSync(join(repo, "pi/agent"), { recursive: true });
    writeFileSync(join(repo, "pi/agent/settings.json"), "{\"tracked\":true}\n");
    writeFileSync(join(tmp, "personal.json"), "{\"mine\":true}\n");
    link(join(tmp, "personal.json"), join(home, ".pi/agent/settings.json"));
    assert.equal(seedPiSettings({ homeDir: home, repoDir: repo, apply: true }, () => {}), true);
    const local = join(home, ".pi/agent/settings.json");
    assert.ok(lstatSync(local).isFile());
    assert.equal(readFileSync(local, "utf8"), "{\"mine\":true}\n");
    assert.equal(lstatSync(local).mode & 0o777, 0o600);
    assert.deepEqual(readdirSync(join(home, ".pi/agent")), ["settings.json"]);
  });
});

describe("deploy-agent-workflow", () => {
  const scripts = join(dirname(fileURLToPath(import.meta.url)), "../scripts");

  function deploy(catalogRows, args, home = join(tmp, "home")) {
    const repo = join(tmp, "repo");
    mkdirSync(join(repo, "scripts/lib"), { recursive: true });
    copyFileSync(join(scripts, "deploy-agent-workflow"), join(repo, "scripts/deploy-agent-workflow"));
    copyFileSync(join(scripts, "lib/surfaces.mjs"), join(repo, "scripts/lib/surfaces.mjs"));
    fixtureRepo(repo, catalogRows, [["suiteA", "https://example.invalid/a.git", "main", "shared", "alpha"]]);
    writeSkill(join(repo, "vendor/suiteA/skills/alpha"), "name: alpha");
    writeSkill(join(repo, "skills/shared/core-one"), "name: core-one");
    const result = spawnSync(process.execPath, [join(repo, "scripts/deploy-agent-workflow"), ...args, "--home", home], {
      encoding: "utf8",
      env: { ...process.env, ETABLI_SCOPE: "", ETABLI_SKIP_LIVE_CHECKS: "1" },
    });
    return { result, home };
  }

  test("a degenerate catalog aborts deploy and check before touching the home", () => {
    for (const args of [["--apply"], ["--check", "--fix"]]) {
      const { result, home } = deploy([["alpha", "suiteA", "1", "1"]], args);
      assert.equal(result.status, 1, args.join(" "));
      assert.match(result.stderr, /degenerate/);
      assert.ok(!existsSync(home), args.join(" "));
    }
  });

  test("--home resolves `..` after a symlink physically, as the kernel does", () => {
    mkdirSync(join(tmp, "real/sub"), { recursive: true });
    symlinkSync(join(tmp, "real/sub"), join(tmp, "alias"));
    deploy([["shared/core-one", "etabli", "1", "1"]], ["--check", "--fix"], `${join(tmp, "alias")}/..`);
    assert.ok(isLink(join(tmp, "real/.claude/skills/core-one")));
    assert.ok(!existsSync(join(tmp, ".claude")));
  });

  test("--dry-run refuses to combine with a mutating mode", () => {
    for (const args of [["--check", "--fix", "--dry-run"], ["--dry-run", "--apply"]]) {
      const { result, home } = deploy([["alpha", "suiteA", "1", "1"]], args);
      assert.equal(result.status, 2, args.join(" "));
      assert.ok(!existsSync(home), args.join(" "));
    }
  });
});

describe("settings writes", () => {
  const scripts = join(dirname(fileURLToPath(import.meta.url)), "../scripts");

  function failingWrites() {
    const preload = join(tmp, "enospc.mjs");
    writeFileSync(
      preload,
      [
        'import fs from "node:fs";',
        'import { syncBuiltinESMExports } from "node:module";',
        "const real = fs.writeFileSync;",
        "fs.writeFileSync = (target, data, options) => {",
        "  real(target, String(data).slice(0, 8), options);",
        '  throw Object.assign(new Error("ENOSPC: no space left on device, write"), { code: "ENOSPC" });',
        "};",
        "syncBuiltinESMExports();",
        "",
      ].join("\n"),
    );
    return { ...process.env, NODE_OPTIONS: `--import ${preload}` };
  }

  function stamped(dir, name, stamp, ageSeconds) {
    const path = join(dir, `${name}${stamp}`);
    writeFileSync(path, stamp);
    const when = Date.now() / 1000 - ageSeconds;
    utimesSync(path, when, when);
    return path;
  }

  test("a write that fails before rename leaves the original byte-identical and no staged file", () => {
    const path = join(tmp, "settings.json");
    writeFileSync(path, "{\"keep\":true}\n");
    chmodSync(path, 0o640);
    const child = spawnSync(
      process.execPath,
      ["--input-type=module", "-e", `import { writeJsonAtomic } from ${JSON.stringify(join(scripts, "lib/surfaces.mjs"))}; writeJsonAtomic(${JSON.stringify(path)}, { replaced: true });`],
      { encoding: "utf8", env: failingWrites() },
    );
    assert.notEqual(child.status, 0);
    assert.equal(readFileSync(path, "utf8"), "{\"keep\":true}\n");
    assert.deepEqual(readdirSync(tmp).sort(), ["enospc.mjs", "settings.json"]);
    writeJsonAtomic(path, { replaced: true });
    assert.equal(readFileSync(path, "utf8"), "{\n  \"replaced\": true\n}\n");
    assert.equal(lstatSync(path).mode & 0o777, 0o640);
  });

  test("the settings writers keep the original when the write fails", () => {
    const home = join(tmp, "home");
    const claudeSettings = join(home, ".claude/settings.json");
    const piSettings = join(home, ".pi/agent/settings.json");
    mkdirSync(dirname(claudeSettings), { recursive: true });
    mkdirSync(dirname(piSettings), { recursive: true });
    const original = "{\"keep\":true}\n";
    writeFileSync(claudeSettings, original);
    writeFileSync(piSettings, original);
    const runs = [
      [join(scripts, "claude-hooks-merge"), ["--home", home]],
      [process.execPath, [join(scripts, "lib/pi-agent-settings-sync.mjs"), piSettings, join(scripts, "../pi/agent/settings.json"), "0", "smoke"]],
      [process.execPath, [join(scripts, "lib/claude-settings-sync.mjs"), claudeSettings, join(scripts, "../claude/settings.skill-overrides.json"), "0", "smoke", "deploy"]],
    ];
    for (const [command, args] of runs) {
      const child = spawnSync(command, args, { encoding: "utf8", env: failingWrites() });
      assert.notEqual(child.status, 0, `${args[0]}: ${child.stdout}${child.stderr}`);
      assert.equal(readFileSync(claudeSettings, "utf8"), original, args[0]);
      assert.equal(readFileSync(piSettings, "utf8"), original, args[0]);
    }
    for (const dir of [dirname(claudeSettings), dirname(piSettings)]) {
      assert.deepEqual(readdirSync(dir).filter((name) => !/^settings\.json(\.bak\.[^.]+(\.\d+)?)?$/.test(name)), [], dir);
    }
  });

  test("a dangling settings symlink is replaced by a private file", () => {
    const path = join(tmp, "settings.json");
    symlinkSync(join(tmp, "gone.json"), path);
    writeJsonAtomic(path, { fresh: true });
    assert.ok(lstatSync(path).isFile());
    assert.equal(lstatSync(path).mode & 0o777, 0o600);
  });

  test("a backup that loses its name to a concurrent writer takes the next suffix", () => {
    const path = join(tmp, "settings.json");
    writeFileSync(path, "{\"live\":true}\n");
    const preload = join(tmp, "eexist.mjs");
    writeFileSync(
      preload,
      [
        'import fs from "node:fs";',
        'import { syncBuiltinESMExports } from "node:module";',
        "const real = fs.copyFileSync;",
        "let raced = false;",
        "fs.copyFileSync = (source, target, mode) => {",
        "  if (!raced) {",
        "    raced = true;",
        '    fs.writeFileSync(target, "concurrent");',
        "  }",
        "  return real(source, target, mode);",
        "};",
        "syncBuiltinESMExports();",
        "",
      ].join("\n"),
    );
    const child = spawnSync(
      process.execPath,
      ["--import", preload, "--input-type=module", "-e", `import { backupFile } from ${JSON.stringify(join(scripts, "lib/surfaces.mjs"))}; console.log(backupFile(${JSON.stringify(path)}, { stamp: "20261023T063547Z" }));`],
      { encoding: "utf8" },
    );
    assert.equal(child.status, 0, child.stderr);
    assert.equal(child.stdout.trim(), `${path}.bak.20261023T063547Z.1`);
    assert.equal(readFileSync(`${path}.bak.20261023T063547Z`, "utf8"), "concurrent");
    assert.equal(readFileSync(`${path}.bak.20261023T063547Z.1`, "utf8"), "{\"live\":true}\n");
  });

  test("backup stamps are UTC", () => {
    assert.equal(backupStamp(new Date("2026-10-23T06:35:47.123Z")), "20261023T063547Z");
  });

  test("backupFile keeps the newest 5 timestamp-named backups across formats and never rotates named ones", () => {
    const path = join(tmp, "settings.json");
    writeFileSync(path, "{\"live\":true}\n");
    const old = [
      stamped(tmp, "settings.json", ".bak.20250101-000000", 900),
      stamped(tmp, "settings.json", ".bak-20250102-000000", 800),
      stamped(tmp, "settings.json", ".bak.20250103T000000", 700),
      stamped(tmp, "settings.json", ".bak.20250104T000000Z", 600),
    ];
    const recent = [
      stamped(tmp, "settings.json", ".bak.20250105-000000.1", 500),
      stamped(tmp, "settings.json", ".bak-20250106-000000", 400),
      stamped(tmp, "settings.json", ".bak.20250107T000000", 300),
      stamped(tmp, "settings.json", ".bak.20250108T000000Z", 200),
    ];
    const named = [
      stamped(tmp, "settings.json", ".bak-20250101-model-fix", 1000),
      stamped(tmp, "settings.json", ".bak.token-economy-20250101T000000Z", 1000),
      stamped(tmp, "settings.json", ".bak.20250101-prune", 1000),
      stamped(tmp, "settings.json", ".bak.1700000000", 1000),
      stamped(tmp, "models.json", ".bak.20200101-000000", 1000),
    ];
    const backup = backupFile(path, { stamp: "20261023T063547Z" });
    assert.equal(backup, `${path}.bak.20261023T063547Z`);
    assert.equal(readFileSync(backup, "utf8"), "{\"live\":true}\n");
    for (const kept of [backup, ...recent, ...named]) assert.ok(existsSync(kept), kept);
    for (const removed of old) assert.ok(!existsSync(removed), removed);
    assert.equal(backupFile(path, { stamp: "20261023T063547Z" }), `${path}.bak.20261023T063547Z.1`);
  });
});


describe("Claude managed env", () => {
  const sync = fileURLToPath(new URL("../scripts/lib/claude-settings-sync.mjs", import.meta.url));
  const secret = "SYNTHETIC_PRIVATE_VALUE_NEVER_LOG";
  function fixture(env, local = { skillOverrides: {} }) {
    const bin = join(tmp, "bin");
    mkdirSync(bin, { recursive: true });
    const claude = join(bin, "claude");
    writeFileSync(claude, "#!/bin/sh\nprintf '%s\\n' '2.1.251 (Claude Code)'\n");
    chmodSync(claude, 0o755);
    const tracked = join(tmp, "tracked.json");
    const settings = join(tmp, "settings.json");
    writeFileSync(tracked, JSON.stringify({ skillOverrides: {}, env }));
    writeFileSync(settings, JSON.stringify(local));
    const run = (stamp = "first", dry = "0", mode = "deploy") =>
      spawnSync(process.execPath, [sync, settings, tracked, dry, stamp, mode, tmp], { encoding: "utf8", env: { ...process.env, PATH: `${bin}:/usr/bin:/bin` } });
    return { tracked, settings, run, claude };
  }
  test("managed optional suggestions and recaps preserve all unrelated settings", () => {
    const original = { skillOverrides: {}, promptSuggestionEnabled: true, awaySummaryEnabled: true, model: "opus", effortLevel: "high", idleCompaction: true, autoCompactEnabled: true, permissions: { defaultMode: "default" }, env: { TOKEN: secret, CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION: "true", CLAUDE_CODE_ENABLE_AWAY_SUMMARY: "1", CLAUDE_CODE_SUBAGENT_MODEL: "opus" } };
    const f = fixture(undefined, original);
    chmodSync(f.settings, 0o600);
    writeFileSync(f.tracked, JSON.stringify({ skillOverrides: {}, promptSuggestionEnabled: false, awaySummaryEnabled: false }));
    const dry = f.run("dry", "1");
    assert.equal(dry.status, 0, dry.stderr);
    assert.match(dry.stdout, /^WOULD_SYNC +Claude tracked settings/);
    assert.match(dry.stdout, /2 settings keys/);
    assert.deepEqual(JSON.parse(readFileSync(f.settings)), original);
    assert.equal(existsSync(`${f.settings}.bak.dry`), false);
    const applied = f.run();
    assert.equal(applied.status, 0, applied.stderr);
    assert.doesNotMatch(applied.stdout + applied.stderr, new RegExp(secret));
    assert.deepEqual(JSON.parse(readFileSync(f.settings)), { ...original, promptSuggestionEnabled: false, awaySummaryEnabled: false });
    assert.deepEqual(JSON.parse(readFileSync(`${f.settings}.bak.first`)), original);
    assert.equal(lstatSync(f.settings).mode & 0o777, 0o600);
    assert.equal(f.run("unchanged").status, 0);
    assert.equal(existsSync(`${f.settings}.bak.unchanged`), false);
    writeFileSync(f.tracked, JSON.stringify({ skillOverrides: {}, promptSuggestionEnabled: true, awaySummaryEnabled: true }));
    assert.equal(f.run("enable").status, 0);
    assert.deepEqual(JSON.parse(readFileSync(f.settings)), original);
  });
  test("optional background switches reject non-booleans before touching settings", () => {
    for (const key of ["promptSuggestionEnabled", "awaySummaryEnabled"]) {
      for (const value of [null, "false", 0, [], {}, { x: 1 }]) {
        const f = fixture(undefined, { skillOverrides: {}, env: { TOKEN: secret } });
        writeFileSync(f.tracked, JSON.stringify({ skillOverrides: {}, [key]: value }));
        const bytes = readFileSync(f.settings, "utf8");
        const child = f.run();
        assert.equal(child.status, 1);
        assert.match(child.stderr, /must be a boolean/);
        assert.doesNotMatch(child.stdout + child.stderr, new RegExp(secret));
        assert.equal(readFileSync(f.settings, "utf8"), bytes);
        assert.equal(existsSync(`${f.settings}.bak.first`), false);
      }
    }
  });
  test("shared background defaults install privately without changing compaction or models", () => {
    const f = fixture(undefined);
    copyFileSync(fileURLToPath(new URL("../claude/settings.skill-overrides.json", import.meta.url)), f.tracked);
    rmSync(f.settings);
    const child = f.run("install", "0", "install");
    assert.equal(child.status, 0, child.stderr);
    const settings = JSON.parse(readFileSync(f.settings));
    assert.equal(settings.promptSuggestionEnabled, false);
    assert.equal(settings.awaySummaryEnabled, false);
    for (const key of ["model", "effortLevel", "idleCompaction", "autoCompactEnabled"]) assert.equal(settings[key], undefined);
    assert.equal(lstatSync(f.settings).mode & 0o777, 0o600);
  });
  test("background fragments cannot admit adjacent privileged settings or env keys", () => {
    for (const extra of [{ model: "haiku", env: { CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION: "0" } }, { env: { CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION: "0" } }]) {
      const original = { skillOverrides: {}, env: { TOKEN: secret } };
      const f = fixture(undefined, original);
      writeFileSync(f.tracked, JSON.stringify({ skillOverrides: {}, promptSuggestionEnabled: false, ...extra }));
      const child = f.run();
      assert.equal(child.status, 1);
      assert.match(child.stderr, /not allowed/);
      assert.doesNotMatch(child.stdout + child.stderr, new RegExp(secret));
      assert.deepEqual(JSON.parse(readFileSync(f.settings)), original);
      assert.equal(existsSync(`${f.settings}.bak.first`), false);
      writeFileSync(f.tracked, JSON.stringify({ skillOverrides: {}, promptSuggestionEnabled: false }));
      assert.equal(f.run("control").status, 0);
      assert.equal(JSON.parse(readFileSync(f.settings)).promptSuggestionEnabled, false);
    }
  });
  test("merges managed default, preserves secrets, backs up and detects env-only drift", () => {
    const original = { skillOverrides: {}, env: { TOKEN: secret, CLAUDE_CODE_SUBAGENT_MODEL: "opus", CLAUDE_CODE_SUBAGENT_MODEL_FORCE: "0" } };
    const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" }, original);
    const first = f.run();
    assert.equal(first.status, 0, first.stderr);
    assert.doesNotMatch(first.stdout + first.stderr, new RegExp(secret));
    assert.match(first.stdout, /SET +env.CLAUDE_CODE_SUBAGENT_MODEL -> sonnet/);
    assert.deepEqual(JSON.parse(readFileSync(f.settings)), { ...original, env: { ...original.env, CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" } });
    assert.deepEqual(JSON.parse(readFileSync(`${f.settings}.bak.first`)), original);
    const bytes = readFileSync(f.settings, "utf8");
    const second = f.run("second");
    assert.equal(second.status, 0, second.stderr);
    assert.match(second.stdout, /^OK +Claude tracked settings/);
    assert.equal(readFileSync(f.settings, "utf8"), bytes);
    assert.equal(existsSync(`${f.settings}.bak.second`), false);
  });
  test("dry-run counts env-only changes without writing or exposing local values", () => {
    const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" }, { skillOverrides: {}, env: { TOKEN: secret } });
    const bytes = readFileSync(f.settings, "utf8");
    const child = f.run("dry", "1");
    assert.equal(child.status, 0, child.stderr);
    assert.match(child.stdout, /0 skills, 1 settings keys/);
    assert.doesNotMatch(child.stdout + child.stderr, new RegExp(secret));
    assert.equal(readFileSync(f.settings, "utf8"), bytes);
    assert.equal(existsSync(`${f.settings}.bak.dry`), false);
  });
  test("creates missing settings and initializes absent env in install mode", () => {
    const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" });
    rmSync(f.settings);
    const created = f.run("create", "0", "install");
    assert.equal(created.status, 0, created.stderr);
    assert.deepEqual(JSON.parse(readFileSync(f.settings)), { skillOverrides: {}, env: { CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" } });
    assert.equal(lstatSync(f.settings).mode & 0o777, 0o600);
    assert.equal(existsSync(`${f.settings}.bak.create`), false);
    writeFileSync(f.settings, JSON.stringify({ skillOverrides: {}, theme: "dark" }));
    assert.equal(f.run("absent").status, 0);
    assert.equal(JSON.parse(readFileSync(f.settings)).theme, "dark");
  });
  test("rejects invalid tracked env before backup or write", () => {
    for (const env of [null, [], "bad", { OTHER: secret }, { ["__proto__"]: secret }, { CLAUDE_CODE_SUBAGENT_MODEL: "" }, { CLAUDE_CODE_SUBAGENT_MODEL: null }, { CLAUDE_CODE_SUBAGENT_MODEL: 1 }]) {
      const f = fixture(env, { skillOverrides: {}, env: { TOKEN: secret } });
      const bytes = readFileSync(f.settings, "utf8");
      const child = f.run();
      assert.equal(child.status, 1);
      assert.match(child.stderr, /^claude-settings-sync: /);
      assert.match(child.stderr, /env/);
      assert.doesNotMatch(child.stdout + child.stderr, new RegExp(secret));
      assert.equal(readFileSync(f.settings, "utf8"), bytes);
      assert.equal(existsSync(`${f.settings}.bak.first`), false);
    }
  });
  test("rejects invalid local env without printing its values", () => {
    for (const env of [null, [], secret, 1]) {
      const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" }, { skillOverrides: {}, env });
      const bytes = readFileSync(f.settings, "utf8");
      const child = f.run();
      assert.equal(child.status, 1);
      assert.match(child.stderr, /^claude-settings-sync: /);
      assert.match(child.stderr, /local.*env/);
      assert.doesNotMatch(child.stdout + child.stderr, new RegExp(secret));
      assert.equal(readFileSync(f.settings, "utf8"), bytes);
      assert.equal(existsSync(`${f.settings}.bak.first`), false);
    }
  });
  test("does not expose malformed local or tracked JSON parser snippets", () => {
    for (const target of ["settings", "tracked"]) {
      const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" });
      const malformed = `{"env":{"TOKEN":${secret}}}`;
      writeFileSync(f[target], malformed);
      const original = readFileSync(f.settings, "utf8");
      const child = f.run();
      assert.equal(child.status, 1);
      assert.match(child.stderr, /^claude-settings-sync: /);
      assert.match(child.stderr, /invalid JSON/);
      assert.doesNotMatch(child.stdout + child.stderr, new RegExp(secret));
      assert.equal(readFileSync(f.settings, "utf8"), original);
      assert.equal(existsSync(`${f.settings}.bak.first`), false);
    }
  });
  test("skips only the managed env on an old, absent or unrecognized runtime", () => {
    for (const version of ["2.1.250 (Claude Code)", "2.0.999", "1.9.999", "2.1.251-beta", "unrecognized", null]) {
      const original = { skillOverrides: {}, env: { TOKEN: secret, CLAUDE_CODE_SUBAGENT_MODEL: "opus" } };
      const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" }, original);
      if (version === null) rmSync(f.claude);
      else writeFileSync(f.claude, `#!/bin/sh\nprintf '%s\\n' '${version}'\n`);
      const child = f.run();
      assert.equal(child.status, 0, child.stderr);
      assert.match(child.stderr, /WARN.*2.1.251/);
      assert.doesNotMatch(child.stdout + child.stderr, new RegExp(secret));
      assert.deepEqual(JSON.parse(readFileSync(f.settings)), original);
      assert.equal(existsSync(`${f.settings}.bak.first`), false);
      writeFileSync(f.tracked, JSON.stringify({ skillOverrides: {}, autoMemoryEnabled: false, env: { CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" } }));
      assert.equal(f.run("other").status, 0);
      assert.equal(JSON.parse(readFileSync(f.settings)).autoMemoryEnabled, false);
      assert.deepEqual(JSON.parse(readFileSync(f.settings)).env, original.env);
    }
  });
  test("accepts newer releases and rejects a failed version probe", () => {
    for (const version of ["2.1.251", "2.1.319", "2.2.0", "3.0.0"]) {
      const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" });
      writeFileSync(f.claude, `#!/bin/sh\nprintf '%s\\n' '${version}'\n`);
      const child = f.run();
      assert.equal(child.status, 0, child.stderr);
      assert.equal(JSON.parse(readFileSync(f.settings)).env.CLAUDE_CODE_SUBAGENT_MODEL, "sonnet");
    }
    const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" });
    writeFileSync(f.claude, "#!/bin/sh\nprintf '2.1.319\\n'\nexit 1\n");
    const child = f.run();
    assert.equal(child.status, 0, child.stderr);
    assert.match(child.stderr, /WARN.*2.1.251/);
    assert.equal(JSON.parse(readFileSync(f.settings)).env, undefined);
  });
  test("bounds version output and stalled probes without exposing output", () => {
    for (const script of ["printf '2.1.300 %5000s' x", "exec sleep 10"]) {
      const original = { skillOverrides: {}, env: { TOKEN: secret, CLAUDE_CODE_SUBAGENT_MODEL: "opus" } };
      const f = fixture({ CLAUDE_CODE_SUBAGENT_MODEL: "sonnet" }, original);
      writeFileSync(f.claude, `#!/bin/sh\n${script}\n`);
      const start = Date.now();
      const child = f.run();
      assert.equal(child.status, 0, child.stderr);
      assert.match(child.stderr, /WARN.*2.1.251/);
      assert.ok(Date.now() - start < 6500, "version probe exceeded its deadline");
      assert.equal((child.stdout + child.stderr).includes("2.1.300 "), false);
      assert.deepEqual(JSON.parse(readFileSync(f.settings)), original);
    }
  });
  test("shared fragment leaves existing model choices unchanged", () => {
    const original = { skillOverrides: {}, env: { TOKEN: secret, CLAUDE_CODE_SUBAGENT_MODEL: "opus" } };
    const f = fixture(undefined, original);
    copyFileSync(fileURLToPath(new URL("../claude/settings.skill-overrides.json", import.meta.url)), f.tracked);
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(readFileSync(f.settings)).env, original.env);
    assert.doesNotMatch(result.stdout + result.stderr, new RegExp(secret));
  });
  test("fragments without env preserve existing local env", () => {
    const original = { skillOverrides: {}, env: { TOKEN: secret } };
    const f = fixture(undefined, original);
    writeFileSync(f.claude, "#!/bin/sh\nexit 1\n");
    const child = f.run();
    assert.equal(child.status, 0);
    assert.equal(child.stderr, "");
    assert.deepEqual(JSON.parse(readFileSync(f.settings)), original);
    assert.equal(existsSync(`${f.settings}.bak.first`), false);
  });
});
