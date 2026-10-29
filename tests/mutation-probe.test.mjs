import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { chmodSync, closeSync, existsSync, linkSync, lstatSync, mkdirSync, mkdtempSync, openSync, readFileSync, readdirSync, readlinkSync, realpathSync, renameSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { addedLines, codeOnly, excluded, fileMutants, inside, lineMutants, maskedLines, parseArgs, parseProcesses, profile, sourceKind, summary, tableRow, trackTree } from "../workflow/runtime/mutation-probe.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const probe = join(root, "workflow/runtime/mutation-probe.mjs");
const darwin = process.platform === "darwin";
const temp = realpathSync.native(tmpdir());

test("unit: options", () => {
  assert.deepEqual(parseArgs(["--base", "main", "--test", "t"]), { paths: [], allowWrite: [], max: 30, timeout: 300, base: "main", test: "t" });
  assert.deepEqual(parseArgs(["--base", "b", "--test", "t", "--check", "c", "--paths", "x", "--paths", "y", "--allow-write", "/tmp", "--max", "2", "--timeout", "9"]), { paths: ["x", "y"], allowWrite: ["/tmp"], max: 2, timeout: 9, base: "b", test: "t", check: "c" });
  assert.deepEqual(parseArgs(["--help"]), { help: true });
  for (const [argv, message] of [
    [["--test", "t"], /missing --base/],
    [["--base", "b"], /missing --test/],
    [["--base", "b", "--test"], /missing value for --test/],
    [["--base", "b", "--test", "t", "--bogus"], /unknown option: --bogus/],
    [["--base", "b", "--test", "t", "toString"], /unknown option: toString/],
    [["--base", "b", "--test", "t", "--max", "0"], /--max needs an integer/],
    [["--base", "b", "--test", "t", "--timeout", "1.5"], /--timeout needs an integer/],
    [["--base", "b", "--test", "t", "--timeout", "86401"], /--timeout needs an integer >= 1 and <= 86400/],
    [["--base", "b", "--test", "t", "--max", "x"], /--max needs an integer/],
    [["--base", "b", "--test", "t", "--allow-write", "tmp"], /--allow-write needs/],
    [["--base", "b", "--test", "t", "--allow-write", "/no/such/dir"], /--allow-write needs/],
    [["--base", "b", "--test", "t", "--allow-write", "/etc/hosts"], /--allow-write needs/],
  ]) assert.throws(() => parseArgs(argv), message);
});

test("unit: targets", () => {
  for (const path of ["tests/a.sh", "x/test/a.js", "__tests__/a.ts", "spec/a.js", "a.test.js", "a.spec.ts", "dist/a.js", "x/build/a.js", "a.min.js", "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml", "bun.lockb", "bun.lock", "yarn.lock", "Gemfile.lock"]) assert.equal(excluded(path), true, path);
  for (const path of ["lib/a.sh", "rebuild/a.js", "testing/a.js", "latest.js", "é ü.sh", "a[b].js", "blocker.js", "clock.js", "lockable.sh", "verify-skills-lock.mjs", "file-lock.js", "lock.sh"]) assert.equal(excluded(path), false, path);
  assert.equal(sourceKind("a.sh", ""), "sh");
  assert.equal(sourceKind("a.bash", ""), "sh");
  assert.equal(sourceKind("a.cjs", ""), "js");
  assert.equal(sourceKind("a.mjs", ""), "js");
  assert.equal(sourceKind("a.tsx", ""), "ts");
  assert.equal(sourceKind("a.md", "#!/bin/bash"), null);
  assert.equal(sourceKind("tool", "#!/usr/bin/env node"), "node");
  assert.equal(sourceKind("tool", "#!/usr/bin/env -S node --no-warnings"), "node");
  assert.equal(sourceKind("tool", "#!/bin/sh"), "sh");
  assert.equal(sourceKind("tool", "#!/usr/bin/env bash"), "sh");
  assert.equal(sourceKind("tool", "#!/usr/bin/env zsh"), null);
  assert.equal(sourceKind("tool", "#!/usr/bin/env python3"), null);
  assert.equal(sourceKind("tool", "echo node"), null);
});

test("unit: added lines", () => {
  const diff = "diff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1,0 +2,2 @@\n+one\n++two\n@@ -9 +11 @@\n-old\n+new\n@@ -20,2 +21,0 @@\n-gone\n-gone\n\\ No newline at end of file\n";
  assert.deepEqual(addedLines(diff), [2, 3, 11]);
  assert.deepEqual(addedLines("+++ b/f\n+not a hunk\n"), []);
  assert.deepEqual(addedLines("@@ -1 +4,3 @@\n+a\n b\n+c\n"), [4, 6]);
});

test("unit: mask", () => {
  const shell = ["# a && b", "cat <<EOF", "a && b", "EOF", "cat <<-'END'", "x", "\tEND", "echo $((1 << 2))", "cat <<< \"$x\"", "y && z", 'cat <<"Q"', "q", "Q", "w"].join("\n");
  assert.deepEqual([...maskedLines(shell, "sh")].sort((a, b) => a - b), [3, 4, 6, 7, 12, 13]);
  assert.deepEqual([...maskedLines("cat <<A\nx <<B\nA\ny && z\nB\nw", "sh")], [2, 3]);
  assert.deepEqual([...maskedLines("# uses <<EOF\necho \"<<EOF\"\nx=$((1 << n))\na && b", "sh")], []);
  assert.deepEqual([...maskedLines("cat <<E\n  E\nE\nx", "sh")], [2, 3]);
  assert.deepEqual([...maskedLines("cat <<-E\n\tE\nx", "sh")], [2]);
  assert.deepEqual([...maskedLines("rm -rf /tmp/*\na && b\necho `\nc && d", "sh")], [4]);
  assert.deepEqual([...maskedLines("echo $(( (n + 1) << shift ))\na && b", "sh")], []);
  assert.deepEqual([...maskedLines("x=$((1)) && cat <<EOF\nbody\nEOF\ny", "sh")], [2, 3]);
  assert.deepEqual([...maskedLines("echo don\\'t \\\"x\na && b\ncat <<E\"OF\"\nc\nEOF\nd", "sh")], [4, 5]);
  assert.deepEqual([...maskedLines("echo \\<<EOF\na && b\ncat <<EO\\F\nc\nEOF\nd\ncat <<\"A B\"\nx\nA B\ny\ncat <<E\\ OF\nz\nE OF\nw", "sh")], [4, 5, 8, 9, 12, 13]);
  assert.deepEqual([...maskedLines("cat <<E'OF'\nc\\\nEOF\nd\ncat <<EOF\nh\\\nEOF\nt && f\nEOF\ncat <<X\na\\\\\nX\nw", "sh")], [2, 3, 6, 7, 8, 9, 11, 12]);
  assert.deepEqual([...maskedLines("cat <<\\EOF\na && b\nEOF\ncat <<'END-OF-TEXT'\nx\nEND-OF-TEXT\nc && d", "sh")], [2, 3, 5, 6]);
  assert.deepEqual([...maskedLines("help='\ntrue && false\ndon''t\n'\nx && y\ntr '\\' /\nz && w", "sh")], [2, 3, 4]);
  const js = ["const a = `", "x === y", "${z}`;", "b && c;", "/* start", " x === y", "end */ d && e;", "const q = '`';", "f && g;", "const r = \"`\"; // `", "h && i;"].join("\n");
  assert.deepEqual([...maskedLines(js, "js")].sort((a, b) => a - b), [2, 3, 6, 7]);
  assert.deepEqual([...maskedLines("/* a\n * b\n c\n*/\nd", "js")], [2, 3, 4]);
  assert.deepEqual([...maskedLines("const v = a / b + `\nt && u\n`;\nw && x;", "js")], [2, 3]);
  assert.deepEqual([...maskedLines("x = \"a\n`\nb && c\n`", "js")], [3, 4]);
  assert.deepEqual([...maskedLines("y = 1 // `\nz && w", "js")], []);
});

test("unit: operators", () => {
  const ops = (line, kind = "js") => lineMutants(line, kind).map((mutant) => `${mutant.op} ${mutant.text}`);
  assert.deepEqual(ops("if (a === b && c !== d) x = true;"), ["===->!== if (a !== b && c !== d) x = true;", "&&->|| if (a === b || c !== d) x = true;", "!==->=== if (a === b && c === d) x = true;", "true->false if (a === b && c !== d) x = false;"]);
  assert.deepEqual(ops("a == b || c != d"), ["==->!= a != b || c != d", "||->&& a == b && c != d", "!=->== a == b || c == d"]);
  assert.deepEqual(ops("x = a || b; // c && d"), ["||->&& x = a && b; // c && d"]);
  assert.deepEqual(ops("/* true means enabled */"), []);
  assert.deepEqual(ops("f(/* a && b */ x === y)"), ["===->!== f(/* a && b */ x !== y)"]);
  assert.deepEqual(ops("#flag = true;"), ["true->false #flag = false;"]);
  assert.deepEqual(ops("#!/usr/bin/env node true", "node"), []);
  assert.deepEqual(ops("x=1 # a && b", "sh"), []);
  assert.deepEqual(ops("printf ok;# true", "sh"), []);
  assert.deepEqual(ops("a&&!b || !c"), ["&&->|| a||!b || !c", "||->&& a&&!b && !c"]);
  assert.deepEqual(ops("x||!y"), ["||->&& x&&!y"]);
  assert.deepEqual(ops("x = 'a\\' && b' && c"), ["&&->|| x = 'a\\' && b' || c"]);
  assert.deepEqual(ops("a=b#c && d", "sh"), ["&&->|| a=b#c || d"]);
  assert.deepEqual(ops("  *) true ;;", "sh"), ["true->false   *) false ;;"]);
  assert.deepEqual(ops('echo "|| exit"', "sh"), []);
  assert.deepEqual(ops('[ "$a" -eq 1 ] && [ $b -ne 2 ] || [ $c -lt 3 ] && [ $d -ge 4 ] && [ $e -gt 5 ] && [ $f -le 6 ]').filter((op) => op.startsWith("-")).map((op) => op.split(" ")[0]), ["-eq->-ne", "-ne->-eq", "-lt->-ge", "-ge->-lt", "-gt->-le", "-le->-gt"]);
  assert.deepEqual(ops("x = false"), ["false->true x = true"]);
  assert.deepEqual(ops('echo "a && b" \'c || d\' `e == f` trueish untrue x.true_ a<=b a>=c a||=b a&&=c --eq'), []);
  assert.deepEqual(ops('echo "a \\" && b" && c'), ['&&->|| echo "a \\" && b" || c']);
  for (const comment of ["// a && b", " * a == b"]) assert.deepEqual(ops(comment), []);
  assert.deepEqual(ops("  # true", "sh"), []);
  for (const line of ["  return x;", "throw e", "continue", "break;", "exit 1", "[ -n \"$a\" ] || return 1", "ok && return", "cd x || exit"]) assert.ok(ops(line).includes("delete "), line);
  for (const line of ["returnCode = 0", "  exiting", "a || exit_code", "x.return()", "breakfast()"]) assert.equal(ops(line).includes("delete "), false, line);
  const mutants = fileMutants("f.sh", "a && b\n# c && d\ncat <<E\ne && f\nE\ng || h\n", "sh", [1, 2, 3, 4, 6, 9]);
  assert.deepEqual(mutants.map((mutant) => `${mutant.path}:${mutant.line} ${mutant.kind} ${mutant.op}`), ["f.sh:1 sh &&->||", "f.sh:6 sh ||->&&"]);
});

test("unit: summary and table", () => {
  const rows = (...outcomes) => outcomes.map((outcome) => ({ outcome }));
  assert.deepEqual(summary([], 0), ["generated 0, ran 0", "n/a: no mutable lines"]);
  assert.deepEqual(summary(rows("killed", "survived", "invalid", "timeout"), 9), ["generated 9, ran 4", "survived: 1 of 2 scored (1 invalid, 0 denied, 1 timeout)"]);
  assert.deepEqual(summary(rows("killed", "denied", "denied", "denied"), 4), ["generated 4, ran 4", "inconclusive: 1 scored (0 invalid, 3 denied, 0 timeout)"]);
  assert.deepEqual(summary(rows("invalid", "timeout"), 2), ["generated 2, ran 2", "inconclusive: 0 scored (1 invalid, 0 denied, 1 timeout)"]);
  assert.deepEqual(summary(rows("survived", "survived", "killed"), 3), ["generated 3, ran 3", "survived: 2 of 3 scored (0 invalid, 0 denied, 0 timeout)"]);
  assert.deepEqual(summary(rows("survived", "denied", "denied"), 3), ["generated 3, ran 3", "inconclusive: 1 scored (0 invalid, 2 denied, 0 timeout)"]);
  assert.equal(tableRow({ path: "a|b.sh", line: 3, op: "||->&&", outcome: "killed", note: "x\ny | z" }), "| a\\|b.sh:3 | \\|\\|->&& | killed | x y \\| z |");
});

test("unit: paths and process groups", () => {
  assert.equal(inside("/a/b", "/a/b"), true);
  assert.equal(inside("/a/b/c", "/a/b"), true);
  assert.equal(inside("/a/bc", "/a/b"), false);
  assert.equal(inside("/a", "/a/b"), false);
  assert.equal(inside("/x", "/"), true);
  const processes = parseProcesses("  10     1    10 Ss   bash -c x\n  11    10    10 T    echo y > /z\n  12    11    12 TN   perl setpgrp\n  13    12    12 S    sleep 9\n  14     1    99 T    other\nbad line\n");
  assert.deepEqual(processes[1], { pid: 11, ppid: 10, pgid: 10, stat: "T", command: "echo y > /z" });
  const tracked = new Set([10]);
  assert.deepEqual(trackTree(processes, tracked, 10).map((entry) => entry.pid), [10, 11, 12, 13]);
  assert.deepEqual(trackTree(processes.filter((entry) => entry.pid === 13), tracked, 10).map((entry) => entry.pid), [13]);
  assert.deepEqual(trackTree(processes, new Set(), 5), []);
  assert.deepEqual(trackTree(parseProcesses("  30    31    30 S    child\n  31    10    31 S    parent\n  10     1    10 S    leader\n"), new Set([10]), 10).map((entry) => entry.pid), [30, 31, 10]);
  const stale = new Set([10, 11]);
  trackTree(processes.filter((entry) => entry.pid !== 11), stale, 10);
  assert.deepEqual(trackTree(parseProcesses("  11     1    50 T    unrelated\n  15    11    50 S    child\n"), stale, 10), []);
  assert.equal(codeOnly('a "b && c" // d', "js"), `a${" ".repeat(10)}`);
  assert.equal(codeOnly("a 'b' # c", "sh"), "a     ");
});

test("unit: profile", () => {
  const text = profile({ roots: ["/r/top", "/r/top/.git", "/c/common"], work: "/w/work", allowed: ["/private/tmp", "/dev"], own: "/w/work/m1" });
  const lines = text.trim().split("\n");
  assert.deepEqual(lines.slice(0, 4), ["(version 1)", "(allow default)", "(deny lsopen)", "(deny file-write* (with send-signal SIGSTOP))"]);
  assert.equal(lines[4], '(allow file-write* (subpath "/private/tmp") (subpath "/dev"))');
  assert.equal(lines[5], '(deny file-write* (with send-signal SIGSTOP) (subpath "/r/top") (subpath "/r/top/.git") (subpath "/c/common") (subpath "/w/work") (literal "/r") (literal "/") (literal "/r/top") (literal "/c") (literal "/w"))');
  assert.equal(lines[6], '(allow file-write* (subpath "/w/work/m1"))');
  assert.equal(lines.length, 7);
  assert.equal(profile({ roots: ["/r"], work: "/w", allowed: ["/dev"], own: null }).trim().split("\n").length, 6);
  for (const bad of ['/r/"x', "/r/\\x"]) assert.throws(() => profile({ roots: [bad], work: "/w", allowed: ["/dev"], own: null }), /unsupported character in path/);
});

function sh(cwd, script, env = process.env) {
  const result = spawnSync("/bin/bash", ["-c", script], { cwd, env, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
}

function put(dir, files) {
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(dir, path)), { recursive: true });
    writeFileSync(join(dir, path), content);
  }
}

function fixture(t, base, changes, parent = temp) {
  const dir = realpathSync.native(mkdtempSync(join(parent, "mp-test-")));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const repo = join(dir, "repo");
  mkdirSync(repo);
  sh(repo, "git init -q && git config user.email t@example.com && git config user.name t && git config commit.gpgSign false");
  put(repo, base);
  sh(repo, "git add -A && git commit -qm base");
  put(repo, changes);
  return { dir, repo };
}

function runProbe(cwd, args, options = {}) {
  const result = spawnSync("node", [probe, ...args], { cwd, encoding: "utf8", timeout: 180000, ...options });
  return { status: result.status, out: `${result.stdout}${result.stderr}` };
}

const rowsOf = (out) => out.split("\n").filter((line) => line.startsWith("| ") && !line.startsWith("| file:line") && !line.startsWith("| ---")).map((line) => line.split(" | ").slice(0, 3).join(" ").slice(2).replace(/\\\|/g, "|"));
const workOf = (out) => /^work directory: (.*)$/m.exec(out)?.[1];

function snapshot(path) {
  const entries = {};
  const visit = (entry) => {
    const stat = lstatSync(entry);
    const key = relative(path, entry);
    if (stat.isDirectory()) {
      entries[key] = ["d", stat.mode];
      for (const name of readdirSync(entry)) visit(join(entry, name));
    } else if (stat.isSymbolicLink()) {
      entries[key] = ["l", readlinkSync(entry)];
    } else {
      entries[key] = ["f", stat.mode, stat.mtimeMs, createHash("sha256").update(readFileSync(entry)).digest("hex")];
    }
  };
  visit(path);
  return entries;
}

const LIB = 'one() { [ "$1" -eq 1 ]; }\nflag=true\nneed() {\n  if [ -z "$1" ]; then\n    exit 1\n  fi\n}\nspin() { trap "" TERM; while false; do :; done; }\n';
const basic = (t, parent) => fixture(t, { "t.sh": ". ./lib.sh\none 1 || exit 1\nspin\necho ok\n", "lib.sh": ":\n" }, { "lib.sh": LIB }, parent);
const BASIC_ROWS = ["lib.sh:1 -eq->-ne killed", "lib.sh:2 true->false survived", "lib.sh:5 delete invalid", "lib.sh:8 false->true timeout"];
const MODE = (attack) => ({ "t.sh": `. ./lib.sh\nif $mode; then\n${attack}\nfi\nexit 0\n`, "lib.sh": ":\n", "sub/keep.txt": "keep\n" });
const modeRepo = (t, attack) => fixture(t, MODE(attack), { "lib.sh": "mode=false\nunused=true\n" });

function assertDenied(t, repo, command, extra = []) {
  const before = snapshot(repo);
  const result = runProbe(repo, ["--base", "HEAD", "--test", command, "--max", "1", ...extra]);
  assert.equal(result.status, 2, result.out);
  assert.match(result.out, /baseline failed: denied write by /);
  assert.deepEqual(snapshot(repo), before);
  return result;
}

describe("integration", { skip: !darwin && "needs the macOS write sandbox" }, () => {
  test("outcomes, summary, timeout bound and cleanup", (t) => {
    const { dir, repo } = basic(t);
    const decoys = [join(temp, `mutation-probe-999999-${basename(dir)}`), join(dir, ".mutation-probe-999999-decoy")];
    for (const decoy of decoys) mkdirSync(decoy);
    t.after(() => rmSync(decoys[0], { recursive: true, force: true }));
    const before = snapshot(repo);
    const started = Date.now();
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh", "--timeout", "2"]);
    assert.equal(result.status, 0, result.out);
    assert.deepEqual(rowsOf(result.out), BASIC_ROWS);
    assert.match(result.out, /\ngenerated 4, ran 4\nsurvived: 1 of 2 scored \(1 invalid, 0 denied, 1 timeout\)\n/);
    assert.match(result.out, /\| lib.sh:5 \| delete \| invalid \| .*syntax error/);
    assert.ok(Date.now() - started < 60000);
    assert.match(result.out, /^copy: clone$/m);
    assert.equal(existsSync(workOf(result.out)), false);
    for (const decoy of decoys) assert.equal(existsSync(decoy), true);
    assert.deepEqual(snapshot(repo), before);
  });

  test("a hanging mutant that ignores SIGTERM ends within the timeout plus 5 s", (t) => {
    const { repo } = fixture(t, { "t.sh": ". ./lib.sh\nspin\n", "lib.sh": ":\n" }, { "lib.sh": 'spin() { trap "" TERM; while false; do :; done; }\n' });
    const started = Date.now();
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh", "--timeout", "1"]);
    const elapsed = Date.now() - started;
    assert.deepEqual(rowsOf(result.out), ["lib.sh:1 false->true timeout"]);
    assert.ok(elapsed >= 6000 && elapsed < 30000, String(elapsed));
  });

  test("baseline failures exit 2", (t) => {
    const { repo } = basic(t);
    for (const [args, message] of [
      [["--test", "echo boom; exit 1"], /baseline failed: test\n(.|\n)*boom/],
      [["--test", "true", "--check", "echo nope; false"], /baseline failed: check\n(.|\n)*nope/],
    ]) {
      const result = runProbe(repo, ["--base", "HEAD", ...args]);
      assert.equal(result.status, 2, result.out);
      assert.match(result.out, message);
    }
    writeFileSync(join(repo, "broken.sh"), "if then true\n");
    const broken = runProbe(repo, ["--base", "HEAD", "--test", "true"]);
    assert.equal(broken.status, 2, broken.out);
    assert.match(broken.out, /baseline failed: check/);
  });

  test("writes to the original are denied through every path", (t) => {
    const { dir, repo } = basic(t);
    const home = join(homedir(), `.mutation-probe-test-${basename(dir)}`);
    t.after(() => rmSync(home, { force: true }));
    for (const command of [
      `echo x >> '${repo}/lib.sh'`,
      `ln -s '${repo}' l && echo x > l/new.txt`,
      `ln '${repo}/lib.sh' alias && echo x >> alias`,
      `echo x > ../../${basename(dir)}/repo/new.txt`,
      `echo x >> '${repo}/.git/config'`,
      `mkdir sub && printf 'gitdir: ${repo}/.git\\n' > sub/.git && git -C sub config probe.x 1`,
      `mkdir fake && echo 'ref: refs/heads/main' > fake/HEAD && echo '${repo}/.git' > fake/commondir && git --git-dir=fake config probe.x 1`,
      `echo x > '${home}'`,
    ]) assertDenied(t, repo, command);
    assert.equal(existsSync(home), false);
  });

  test("a step cannot write the pristine copy, another step or the original", (t) => {
    for (const attack of ["echo x > ../pristine/f", "mv ../pristine/sub ../pristine/sub.old && mkdir ../pristine/sub", "mkdir -p ../m2 && echo x > ../m2/f", "ln ../pristine/lib.sh alias && echo x >> alias", "echo x >> \"$ORIGINAL/lib.sh\""]) {
      const { repo } = modeRepo(t, attack);
      const before = snapshot(repo);
      const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh"], { env: { ...process.env, ORIGINAL: repo } });
      assert.equal(result.status, 0, result.out);
      assert.deepEqual(rowsOf(result.out), ["lib.sh:1 false->true denied", "lib.sh:2 true->false survived"], attack);
      assert.match(result.out, /\| denied \| \S/);
      assert.deepEqual(snapshot(repo), before);
    }
  });

  test("a mutant cannot contaminate the next step", (t) => {
    const { repo } = fixture(t, {
      "t.sh": ". ./lib.sh\ngrep -q clean neighbor.txt || exit 3\ngrep -q clean cache.txt || exit 3\nif $mode; then echo dirty > neighbor.txt; echo dirty > cache.txt; exit 1; fi\n",
      "lib.sh": ":\n", "neighbor.txt": "clean\n", ".gitignore": "cache.txt\n",
    }, { "lib.sh": "mode=false\nunused=true\n", "cache.txt": "clean\n" });
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh"]);
    assert.deepEqual(rowsOf(result.out), ["lib.sh:1 false->true killed", "lib.sh:2 true->false survived"]);
  });

  test("ancestors of the original cannot be renamed", (t) => {
    const { dir, repo } = basic(t);
    t.after(() => rmSync(`${dir}.moved`, { recursive: true, force: true }));
    assertDenied(t, repo, `mv '${dir}' '${dir}.moved'`);
    assert.equal(existsSync(repo), true);
  });

  test("lsopen is denied", (t) => {
    const { repo } = basic(t);
    const result = runProbe(repo, ["--base", "HEAD", "--test", "open -g -j -a TextEdit"]);
    assert.equal(result.status, 2, result.out);
    assert.match(result.out, /baseline failed: test/);
  });

  test("a nested sandbox is refused", (t) => {
    const { repo } = basic(t);
    const result = spawnSync("/usr/bin/sandbox-exec", ["-p", "(version 1)(allow default)(deny file-write* (literal \"/private/var/empty/x\"))", "node", probe, "--base", "HEAD", "--test", "true"], { cwd: repo, encoding: "utf8" });
    assert.equal(result.status, 2, result.stdout);
    assert.match(result.stderr, /no write sandbox:/);
  });

  test("colored git output and diff attributes do not change targets", (t) => {
    const { repo } = basic(t);
    sh(repo, "git config color.ui always && git config color.diff always && echo '* -diff' > .git/info/attributes");
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh", "--max", "2"]);
    assert.deepEqual(rowsOf(result.out), BASIC_ROWS.slice(0, 2));
  });

  test("aliases of the original are protected", (t) => {
    const { repo } = basic(t);
    const lower = repo.toLowerCase();
    assert.equal(existsSync(lower), true);
    for (const command of [`echo x >> '${lower}/lib.sh'`, `echo x >> '${repo.toUpperCase()}/LIB.SH'`, `echo x >> '/System/Volumes/Data${repo}/lib.sh'`]) {
      const before = snapshot(repo);
      const result = runProbe(lower, ["--base", "HEAD", "--test", command]);
      assert.equal(result.status, 2, result.out);
      assert.match(result.out, /baseline failed: denied write by /);
      assert.deepEqual(snapshot(repo), before);
    }
    const tmp = basic(t, "/private/tmp");
    const alias = tmp.repo.replace(/^\/private\/tmp\//, "/tmp/");
    const before = snapshot(tmp.repo);
    const result = runProbe(alias, ["--base", "HEAD", "--test", `echo x >> '${alias}/lib.sh'`]);
    assert.equal(result.status, 2, result.out);
    assert.match(result.out, /baseline failed: denied write by /);
    assert.deepEqual(snapshot(tmp.repo), before);
  });

  test("an external git dir and a linked worktree are protected", (t) => {
    const { dir, repo } = basic(t);
    const external = join(dir, "external");
    sh(dir, `git init -q --separate-git-dir '${join(dir, "gitdir")}' external && cd external && git config user.email t@example.com && git config user.name t && git config commit.gpgSign false && printf ':\\n' > lib.sh && printf 'one 1\\n' > t.sh && git add -A && git commit -qm base`);
    put(external, { "lib.sh": LIB });
    for (const command of [`echo x >> '${join(dir, "gitdir")}/config'`, `echo x >> '${external}/lib.sh'`]) assertDenied(t, external, command);
    const worktree = join(dir, "wt");
    sh(repo, `git worktree add -q --detach '${worktree}' HEAD`);
    put(worktree, { "lib.sh": LIB });
    for (const command of [`echo x >> '${repo}/.git/config'`, `echo x >> '${repo}/.git/worktrees/wt/HEAD'`, `echo x >> '${worktree}/lib.sh'`]) {
      const before = snapshot(repo);
      assertDenied(t, worktree, command);
      assert.deepEqual(snapshot(repo), before);
    }
  });

  test("git filters and fsmonitor do not run or shift lines", (t) => {
    const { dir, repo } = fixture(t, { ".gitattributes": "*.sh filter=evil\n", "t.sh": ". ./lib.sh\none 1 || exit 1\necho ok\n", "lib.sh": ":\n" }, {});
    const log = join(dir, "log");
    put(dir, { "fsmonitor.sh": `#!/bin/sh\necho m >> '${log}'\n` });
    chmodSync(join(dir, "fsmonitor.sh"), 0o755);
    sh(repo, `git config filter.evil.clean "sh -c 'echo f >> ${log}; echo extra; cat'" && git config filter.evil.smudge cat && git config core.fsmonitor '${join(dir, "fsmonitor.sh")}'`);
    put(repo, { "lib.sh": LIB });
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh", "--max", "2"]);
    assert.deepEqual(rowsOf(result.out), BASIC_ROWS.slice(0, 2));
    assert.equal(existsSync(log), false);
  });

  test("--allow-write opens one directory", (t) => {
    const { repo } = basic(t);
    const allowed = mkdtempSync(join(homedir(), ".mutation-probe-allow-"));
    t.after(() => rmSync(allowed, { recursive: true, force: true }));
    const command = `echo x > '${allowed}/out'`;
    assertDenied(t, repo, command);
    const result = runProbe(repo, ["--base", "HEAD", "--test", command, "--max", "1", "--allow-write", allowed]);
    assert.equal(result.status, 0, result.out);
    assert.match(result.out, new RegExp(`allow-write: ${realpathSync.native(allowed)}`));
  });

  test("a denial in a child that left the process group is seen", (t) => {
    const { repo } = modeRepo(t, `perl -e 'setpgrp(0, 0); exec @ARGV' /bin/bash -c 'echo x >> "$ORIGINAL/lib.sh"' &\nwait`);
    const before = snapshot(repo);
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh", "--max", "1", "--timeout", "30"], { env: { ...process.env, ORIGINAL: repo } });
    assert.deepEqual(rowsOf(result.out), ["lib.sh:1 false->true denied"]);
    assert.deepEqual(snapshot(repo), before);
  });

  test("system temp dirs used by shell here-documents are writable", (t) => {
    const { repo } = basic(t);
    const result = runProbe(repo, ["--base", "HEAD", "--test", "read -r a <<< x && /bin/bash -c 'cat <<EOF\nok\nEOF'", "--max", "1"]);
    assert.equal(result.status, 0, result.out);
  });

  test("a denial reaped by the parent exit is still seen", (t) => {
    const { repo } = modeRepo(t, `( exec >/dev/null 2>&1; echo x >> "$ORIGINAL/lib.sh" ) &\nchild=$!\nwhile :; do case "$(ps -o stat= -p "$child")" in T*) break ;; esac; done\nexit 1`);
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh", "--max", "1"], { env: { ...process.env, ORIGINAL: repo } });
    assert.deepEqual(rowsOf(result.out), ["lib.sh:1 false->true denied"]);
  });

  test("pre-flight refuses hard links and symlinks in git metadata", (t) => {
    const linked = basic(t);
    linkSync(join(linked.repo, "lib.sh"), join(linked.dir, "alias"));
    const marker = join(linked.dir, "marker");
    let result = runProbe(linked.repo, ["--base", "HEAD", "--test", `touch '${marker}'`]);
    assert.equal(result.status, 2, result.out);
    assert.match(result.out, /hard-linked file in protected tree: .*lib\.sh/);
    const symlinked = basic(t);
    renameSync(join(symlinked.repo, ".git/objects/pack"), join(symlinked.dir, "pack"));
    symlinkSync(join(symlinked.dir, "pack"), join(symlinked.repo, ".git/objects/pack"));
    result = runProbe(symlinked.repo, ["--base", "HEAD", "--test", `touch '${marker}'`]);
    assert.equal(result.status, 2, result.out);
    assert.match(result.out, /symlink in git metadata: .*objects\/pack/);
    assert.equal(existsSync(marker), false);
    assert.doesNotMatch(result.out, /work directory/);
  });

  test("inherited descriptors give no write access", (t) => {
    const { repo } = basic(t);
    const fd = openSync(join(repo, "lib.sh"), "r+");
    t.after(() => closeSync(fd));
    const before = snapshot(repo);
    const result = runProbe(repo, ["--base", "HEAD", "--test", "echo hacked >&0; echo hacked >&3; true", "--max", "1"], { stdio: [fd, "pipe", "pipe", fd] });
    assert.equal(result.status, 0, result.out);
    assert.deepEqual(snapshot(repo), before);
  });

  test("hooks and templates do not run during the bootstrap", (t) => {
    const { dir, repo } = basic(t);
    const home = join(dir, "home");
    const marker = join(dir, "marker");
    const hook = `#!/bin/sh\ntouch '${marker}'\nexit 1\n`;
    put(home, { ".gitconfig": `[core]\n\thooksPath = ${home}/hooks\n[init]\n\ttemplateDir = ${home}/template\n` });
    for (const name of ["prepare-commit-msg", "post-commit", "post-index-change", "pre-commit"]) {
      put(home, { [`hooks/${name}`]: hook, [`template/hooks/${name}`]: hook });
      chmodSync(join(home, "hooks", name), 0o755);
      chmodSync(join(home, "template/hooks", name), 0o755);
    }
    const result = runProbe(repo, ["--base", "HEAD", "--test", "bash t.sh", "--max", "1"], { env: { ...process.env, HOME: home } });
    assert.equal(result.status, 0, result.out);
    assert.equal(existsSync(marker), false);
  });

  test("background children do not outlive their step", (t) => {
    const { dir, repo } = basic(t);
    const pidFile = join(dir, "pid");
    const result = runProbe(repo, ["--base", "HEAD", "--test", `sleep 60 & echo $! > '${pidFile}'`, "--max", "1"]);
    assert.equal(result.status, 0, result.out);
    const pid = Number(readFileSync(pidFile, "utf8"));
    assert.throws(() => process.kill(pid, 0), { code: "ESRCH" });
  });

  test("SIGTERM removes the work directory, kills the step and exits 143", async (t) => {
    const { dir, repo } = basic(t);
    const pidFile = join(dir, "pid");
    const child = spawn("node", [probe, "--base", "HEAD", "--test", `sleep 60 & echo $! > '${pidFile}'; wait`], { cwd: repo });
    let out = "";
    child.stdout.on("data", (chunk) => {
      out += chunk;
    });
    while (!/copy: /.test(out)) await new Promise((done) => setTimeout(done, 50));
    await new Promise((done) => setTimeout(done, 1500));
    child.kill("SIGTERM");
    const code = await new Promise((done) => child.on("exit", done));
    assert.equal(code, 143);
    assert.equal(existsSync(workOf(out)), false);
    assert.throws(() => process.kill(Number(readFileSync(pidFile, "utf8")), 0), { code: "ESRCH" });
  });

  test("a target changed during capture is refused", (t) => {
    const { repo } = basic(t);
    const writer = spawn("/bin/bash", ["-c", 'i=0; while :; do i=$((i+1)); echo "flag=true # $i" > ../lib.tmp && mv ../lib.tmp lib.sh; done'], { cwd: repo, stdio: "ignore" });
    t.after(() => writer.kill("SIGKILL"));
    const result = runProbe(repo, ["--base", "HEAD", "--test", "true"]);
    writer.kill("SIGKILL");
    assert.equal(result.status, 2, result.out);
    assert.match(result.out, /tree changed during capture: lib\.sh/);
  });

  test("targets, masks, paths and max", (t) => {
    const base = { "lib.sh": ":\n", "tpl.js": "\n", "tool": "#!/usr/bin/env node\n", "a[b].js": "\n", "ab.js": "\n", "doc.md": "\n" };
    const { repo } = fixture(t, base, {
      "lib.sh": '# a && b\ncat <<EOF\na && b\nEOF\necho "a && b" \'c || d\'\nreturnCode=0\n[ "$x" -eq 1 ] && echo hit\n',
      "tpl.js": "const s = `\na === b\n`;\nconst r = x === 1;\n",
      "tool": "#!/usr/bin/env node\nif (a == b) {}\n",
      "a[b].js": "x && y;\n",
      "ab.js": "p || q;\n",
      "doc.md": "a && b\n",
      "tests/t.sh": "x=true\n",
      "a.test.js": "x === 1;\n",
      "dist/d.js": "x === 1;\n",
      "new.sh": "[ 1 -lt 2 ]\n",
      "é ü.sh": "v=true\n",
      "x.ts": "const t = a === b;\n",
    });
    symlinkSync("new.sh", join(repo, "link.sh"));
    sh(repo, "git add ab.js");
    const all = runProbe(repo, ["--base", "HEAD", "--test", "true", "--max", "100"]);
    assert.equal(all.status, 0, all.out);
    assert.deepEqual(rowsOf(all.out).sort(), ["a[b].js:1 &&->|| survived", "ab.js:1 ||->&& survived", "lib.sh:7 -eq->-ne survived", "lib.sh:7 &&->|| survived", "new.sh:1 -lt->-ge survived", "tool:2 ==->!= survived", "tpl.js:4 ===->!== survived", "x.ts:1 ===->!== survived", "é ü.sh:1 true->false survived"].sort());
    assert.match(all.out, /^no type check: type errors count as killed$/m);
    const one = runProbe(repo, ["--base", "HEAD", "--test", "true", "--paths", "a[b]", "--max", "1"]);
    assert.deepEqual(rowsOf(one.out), ["a[b].js:1 &&->|| survived"]);
    assert.match(one.out, /generated 1, ran 1/);
    const two = runProbe(repo, ["--base", "HEAD", "--test", "true", "--paths", "lib.sh", "--paths", "tool", "--max", "2"]);
    assert.match(two.out, /generated 3, ran 2/);
    assert.doesNotMatch(two.out, /no type check/);
    const typed = runProbe(repo, ["--base", "HEAD", "--test", "true", "--paths", "x.ts", "--check", "true"]);
    assert.doesNotMatch(typed.out, /no type check/);
    const none = runProbe(repo, ["--base", "HEAD", "--test", "true", "--paths", "doc.md"]);
    assert.equal(none.status, 0, none.out);
    assert.match(none.out, /generated 0, ran 0\nn\/a: no mutable lines/);
  });

  test("an invalid extensionless node mutant is invalid", (t) => {
    const { repo } = fixture(t, { "tool": "#!/usr/bin/env node\n" }, { "tool": "#!/usr/bin/env node\nfunction f(x) {\n  if (x)\n    return 1;\n  else return 2;\n}\n" });
    const result = runProbe(repo, ["--base", "HEAD", "--test", "true"]);
    assert.deepEqual(rowsOf(result.out), ["tool:4 delete invalid"]);
  });

  test("usage errors exit 2", (t) => {
    const { dir, repo } = basic(t);
    for (const [cwd, args, message] of [
      [dir, ["--base", "HEAD", "--test", "true"], /not inside a git work tree/],
      [repo, ["--base", "nope", "--test", "true"], /unresolvable --base: nope/],
      [repo, ["--base", "HEAD"], /missing --test/],
      [repo, ["--base", "HEAD", "--test", "true", "--allow-write", "relative"], /--allow-write needs an existing absolute directory/],
    ]) {
      const result = runProbe(cwd, args);
      assert.equal(result.status, 2, result.out);
      assert.match(result.out, message);
      assert.match(result.out, /usage: mutation-probe\.mjs/);
    }
    const help = runProbe(repo, ["--help"]);
    assert.equal(help.status, 0);
    assert.match(help.out, /detach children from their process tree/);
  });
});

test("refusal without the macOS sandbox", { skip: darwin && "macOS cannot simulate a missing sandbox without an override" }, () => {
  const result = runProbe(temp, ["--base", "HEAD", "--test", "true"]);
  assert.equal(result.status, 2, result.out);
  assert.match(result.out, /no write sandbox/);
});
