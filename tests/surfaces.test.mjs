import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, readlinkSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, test } from "node:test";
import {
  activeScopes,
  claudeConfigOverride,
  declaredName,
  isShadowed,
  physicalHome,
  physicalPath,
  reconcile,
  seedPiSettings,
  skillRecords,
  surfaceExpected,
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
    for (const retired of [".codex", ".config/devin", ".agents"]) assert.ok(!existsSync(join(home, retired)));

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
