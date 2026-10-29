#!/usr/bin/env node
import { spawn, spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, extname, isAbsolute, join, sep } from "node:path";
import { fileURLToPath } from "node:url";

export const USAGE = 'usage: mutation-probe.mjs --base <ref> --test "<command>" [--check "<command>"] [--paths <substring>]... [--allow-write <dir>]... [--max <n>] [--timeout <s>]';
const HELP = `${USAGE}

Mutates the added lines of the diff against <ref> (staged, unstaged and untracked
sources), runs the test per mutant in a fresh clone of the work tree under a macOS
write sandbox, and lists the survivors. No process it starts can write the original
repository or its copies. It refuses to run without sandbox-exec, inside another
sandbox, where a denied write does not stop the writer (measured on macOS 14.4), or with
hard-linked files or symlinks in git metadata.
Outcomes: killed, survived, invalid (a check failed), denied (a write was denied),
timeout. Only killed and survived are scored.
Tests that detach children from their process tree (double fork, daemons) are not
supported. Defaults: --max 30, --timeout 300 (at most 86400).`;

const OPTIONS = new Map([["--base", "base"], ["--test", "test"], ["--check", "check"], ["--paths", "paths"], ["--allow-write", "allowWrite"], ["--max", "max"], ["--timeout", "timeout"]]);
const SOURCES = new Map([[".sh", "sh"], [".bash", "sh"], [".js", "js"], [".mjs", "js"], [".cjs", "js"], [".ts", "ts"], [".tsx", "ts"]]);
const SKIPPED_DIRS = new Set(["test", "tests", "__tests__", "spec", "dist", "build"]);
const SWAPS = [["===", "!=="], ["!==", "==="], ["==", "!="], ["!=", "=="], ["&&", "||"], ["||", "&&"], ["-eq", "-ne"], ["-ne", "-eq"], ["-lt", "-ge"], ["-ge", "-lt"], ["-gt", "-le"], ["-le", "-gt"], ["true", "false"], ["false", "true"]];
const SANDBOX = "/usr/bin/sandbox-exec";
const HEADER = "| file:line | operator | outcome | note |\n| --- | --- | --- | --- |";
const SIGNALS = [["SIGHUP", 1], ["SIGINT", 2], ["SIGTERM", 15]];
const OUTPUT_TAIL = 64 * 1024;

export class Refusal extends Error {}
export class UsageError extends Refusal {}

export function parseArgs(argv) {
  const options = { paths: [], allowWrite: [], max: 30, timeout: 300 };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag === "--help" || flag === "-h") return { help: true };
    const key = OPTIONS.get(flag);
    if (!key) throw new UsageError(`unknown option: ${flag}`);
    const value = argv[++index];
    if (value === undefined) throw new UsageError(`missing value for ${flag}`);
    if (key === "max" || key === "timeout") {
      if (!/^[1-9]\d*$/.test(value) || (key === "timeout" && Number(value) > 86400)) throw new UsageError(`${flag} needs an integer >= 1${key === "timeout" ? " and <= 86400" : ""}: ${value}`);
      options[key] = Number(value);
    } else if (key === "allowWrite") {
      if (!isAbsolute(value) || !existsSync(value) || !statSync(value).isDirectory()) throw new UsageError(`--allow-write needs an existing absolute directory: ${value}`);
      options.allowWrite.push(value);
    } else if (key === "paths") {
      options.paths.push(value);
    } else {
      options[key] = value;
    }
  }
  if (!options.base) throw new UsageError("missing --base");
  if (!options.test) throw new UsageError("missing --test");
  return options;
}

export function excluded(path) {
  const parts = path.split("/");
  const name = parts.at(-1);
  return parts.slice(0, -1).some((part) => SKIPPED_DIRS.has(part)) || /\.(test|spec)\./.test(name) || name.includes(".min.") || /\.lockb?$|^(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml)$/.test(name);
}

export function sourceKind(path, firstLine) {
  const extension = extname(path);
  if (extension) return SOURCES.get(extension) ?? null;
  if (!firstLine.startsWith("#!")) return null;
  const words = firstLine.slice(2).trim().split(/\s+/);
  let index = 0;
  if (basename(words[0] ?? "") === "env") {
    index = 1;
    while (words[index]?.startsWith("-")) index += 1;
  }
  const interpreter = basename(words[index] ?? "");
  if (interpreter === "bash" || interpreter === "sh") return "sh";
  return interpreter === "node" ? "node" : null;
}

export function addedLines(diff) {
  const added = [];
  let line = 0;
  let inHunk = false;
  for (const text of diff.split("\n")) {
    const header = /^@@ -\S+ \+(\d+)(?:,\d+)? @@/.exec(text);
    if (header) {
      line = Number(header[1]);
      inHunk = true;
    } else if (inHunk && text.startsWith("+")) {
      added.push(line);
      line += 1;
    } else if (inHunk && text.startsWith(" ")) {
      line += 1;
    }
  }
  return added;
}

function scan(line, kind, open) {
  let code = "";
  let quote = open;
  for (let at = 0; at < line.length; at += 1) {
    const char = line[at];
    if (quote) {
      code += " ";
      if (char === "\\" && at + 1 < line.length && (kind !== "sh" || quote !== "'")) {
        code += " ";
        at += 1;
      } else if (char === quote) {
        quote = null;
      }
    } else if (kind === "sh" && char === "\\") {
      code += at + 1 < line.length ? "\\ " : "\\";
      at += 1;
    } else if (char === "'" || char === '"' || char === "`") {
      quote = char;
      code += " ";
    } else if (kind === "sh" ? char === "#" && (at === 0 || /[\s;&|()<>]/.test(line[at - 1])) : char === "/" && line[at + 1] === "/") {
      break;
    } else if (kind !== "sh" && char === "/" && line[at + 1] === "*") {
      const end = line.indexOf("*/", at + 2);
      const stop = end === -1 ? line.length : end + 2;
      code += " ".repeat(stop - at);
      at = stop - 1;
    } else {
      code += char;
    }
  }
  return { code, quote };
}

export const codeOnly = (line, kind) => scan(line, kind, null).code;

function blankArithmetic(code) {
  let blanked = "";
  for (let at = 0; at < code.length; ) {
    if (!code.startsWith("((", at)) {
      blanked += code[at];
      at += 1;
      continue;
    }
    let end = at;
    for (let depth = 0; end < code.length; end += 1) {
      if (code[end] === "(") depth += 1;
      else if (code[end] === ")" && --depth === 0) break;
    }
    end = Math.min(end + 1, code.length);
    blanked += " ".repeat(end - at);
    at = end;
  }
  return blanked;
}

export function maskedLines(text, kind) {
  const masked = new Set();
  const lines = text.split("\n");
  if (kind === "sh") {
    const pending = [];
    let quote = null;
    let joined = false;
    lines.forEach((line, index) => {
      if (pending.length) {
        masked.add(index + 1);
        const { word, dash, literal } = pending[0];
        if (!joined && (dash ? line.replace(/^\t+/, "") : line) === word) pending.shift();
        joined = !literal && /(^|[^\\])(\\\\)*\\$/.test(line);
        return;
      }
      if (quote) masked.add(index + 1);
      const scanned = scan(line, "sh", quote);
      quote = scanned.quote;
      const code = blankArithmetic(scanned.code);
      for (const match of line.matchAll(/(?<!<)<<(?!<)(-?)[ \t]*((?:\\.|'[^']*'|"[^"]*"|[^\s;|&<>()'"\\])+)/g)) {
        if (code[match.index] === "<") pending.push({ word: match[2].replace(/["'\\]/g, ""), dash: match[1] === "-", literal: /["'\\]/.test(match[2]) });
      }
    });
    return masked;
  }
  let state = null;
  lines.forEach((line, index) => {
    if (state === "`" || state === "/*") masked.add(index + 1);
    if (state === "'" || state === '"') state = null;
    for (let at = 0; at < line.length; at += 1) {
      const char = line[at];
      if (state === "/*") {
        if (char === "*" && line[at + 1] === "/") {
          state = null;
          at += 1;
        }
      } else if (state) {
        if (char === "\\") at += 1;
        else if (char === state) state = null;
      } else if (char === "/" && line[at + 1] === "/") {
        break;
      } else if (char === "/" && line[at + 1] === "*") {
        state = "/*";
        at += 1;
      } else if (char === "'" || char === '"' || char === "`") {
        state = char;
      }
    }
  });
  return masked;
}

function tokenPositions(code, token) {
  const positions = [];
  const word = /^[-\w]/.test(token);
  for (let at = code.indexOf(token); at !== -1; at = code.indexOf(token, at + 1)) {
    const before = code[at - 1] ?? "";
    const after = code[at + token.length] ?? "";
    const free = word ? !/[\w$-]/.test(before) && !/[\w$]/.test(after) : !/[=!<>]/.test(before) && !(token === "&&" || token === "||" ? /=/ : /[=!<>]/).test(after);
    if (free) positions.push(at);
  }
  return positions;
}

export function lineMutants(line, kind) {
  const trimmed = line.trim();
  if (kind === "sh" ? trimmed.startsWith("#") : /^(\/\/|\/\*|\*|#!)/.test(trimmed)) return [];
  const code = codeOnly(line, kind);
  const mutants = [];
  for (const [from, to] of SWAPS) {
    for (const at of tokenPositions(code, from)) mutants.push({ at, op: `${from}->${to}`, text: line.slice(0, at) + to + line.slice(at + from.length) });
  }
  mutants.sort((left, right) => left.at - right.at);
  const statement = code.trim();
  if (/^(return|throw|continue|break|exit)\b/.test(statement) || /(\|\||&&)\s*return\b|\|\|\s*exit\b/.test(statement)) mutants.push({ at: line.length, op: "delete", text: "" });
  return mutants.map(({ op, text }) => ({ op, text }));
}

export function fileMutants(path, text, kind, lines) {
  const masked = maskedLines(text, kind);
  const source = text.split("\n");
  return lines.filter((line) => !masked.has(line) && source[line - 1] !== undefined).flatMap((line) => lineMutants(source[line - 1], kind).map((mutant) => ({ path, kind, line, ...mutant })));
}

export function summary(rows, generated) {
  const count = (outcome) => rows.filter((row) => row.outcome === outcome).length;
  const lines = [`generated ${generated}, ran ${rows.length}`];
  if (generated === 0) return [...lines, "n/a: no mutable lines"];
  const scored = count("killed") + count("survived");
  const unscored = count("invalid") + count("denied") + count("timeout");
  const detail = `${scored} scored (${count("invalid")} invalid, ${count("denied")} denied, ${count("timeout")} timeout)`;
  lines.push(scored > 0 && unscored * 2 <= rows.length ? `survived: ${count("survived")} of ${detail}` : `inconclusive: ${detail}`);
  return lines;
}

export function tableRow(row) {
  const cell = (value) => String(value).replace(/[\r\n]+/g, " ").replace(/\|/g, "\\|");
  return `| ${cell(`${row.path}:${row.line}`)} | ${cell(row.op)} | ${row.outcome} | ${cell(row.note)} |`;
}

export function profile({ roots, work, allowed, own }) {
  const quote = (path) => {
    if (/["\\]/.test(path)) throw new Refusal(`unsupported character in path: ${path}`);
    return `"${path}"`;
  };
  const ancestors = new Set();
  for (const path of [...roots, work]) {
    for (let dir = dirname(path); ; dir = dirname(dir)) {
      ancestors.add(dir);
      if (dir === dirname(dir)) break;
    }
  }
  const rules = [
    "(version 1)",
    "(allow default)",
    "(deny lsopen)",
    "(deny file-write* (with send-signal SIGSTOP))",
    `(allow file-write* ${allowed.map((path) => `(subpath ${quote(path)})`).join(" ")})`,
    `(deny file-write* (with send-signal SIGSTOP) ${[...roots, work].map((path) => `(subpath ${quote(path)})`).join(" ")} ${[...ancestors].map((path) => `(literal ${quote(path)})`).join(" ")})`,
  ];
  if (own) rules.push(`(allow file-write* (subpath ${quote(own)}))`);
  return `${rules.join("\n")}\n`;
}

export function parseProcesses(listing) {
  return listing.split("\n").map((line) => /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(.*)$/.exec(line)).filter(Boolean).map((match) => ({ pid: Number(match[1]), ppid: Number(match[2]), pgid: Number(match[3]), stat: match[4], command: match[5] }));
}

export function trackTree(processes, tracked, group) {
  const alive = new Set(processes.map((entry) => entry.pid));
  for (const pid of tracked) if (!alive.has(pid)) tracked.delete(pid);
  for (let grew = true; grew; ) {
    grew = false;
    for (const entry of processes) {
      if (!tracked.has(entry.pid) && (entry.pgid === group || tracked.has(entry.ppid))) {
        tracked.add(entry.pid);
        grew = true;
      }
    }
  }
  return processes.filter((entry) => tracked.has(entry.pid));
}

export function witnessRefusal(name, result) {
  if (result.failure) return `no write sandbox: ${result.failure}`;
  if (result.stopped) return null;
  if (result.timedOut) return `no write sandbox: the ${name} witness timed out`;
  return `no write sandbox: a denied ${name} does not stop the writer on this macOS; denials cannot be told from test failures`;
}

export const inside = (path, root) => path === root || path.startsWith(root.endsWith(sep) ? root : root + sep);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const canonical = (path) => realpathSync.native(path);
const ENV = Object.fromEntries(Object.entries(process.env).filter(([name]) => !name.startsWith("GIT_")));
let activeKill = null;

function listProcesses() {
  const result = spawnSync("/bin/ps", ["-A", "-o", "pid=,ppid=,pgid=,stat=,command="], { encoding: "utf8", env: {}, maxBuffer: 1 << 26, timeout: 10000 });
  if (result.status !== 0) throw new Refusal(`cannot list processes: ${result.error?.message ?? result.stderr}`);
  return parseProcesses(result.stdout);
}

function signal(pid, name) {
  try {
    process.kill(pid, name);
  } catch {
    return;
  }
}

function remove(path) {
  try {
    rmSync(path, { recursive: true, force: true });
  } catch {
    spawnSync("/bin/chmod", ["-R", "u+w", path]);
    rmSync(path, { recursive: true, force: true });
  }
}

function sandboxed(sandbox, argv, cwd, timeout, keepStdout = false) {
  return new Promise((resolve) => {
    const child = spawn(SANDBOX, [...sandbox, ...argv], { cwd, env: ENV, detached: true, stdio: ["ignore", "pipe", "pipe"] });
    const tracked = new Set(child.pid ? [child.pid] : []);
    const stdout = [];
    const tail = [];
    let tailSize = 0;
    let stopped = null;
    let failure = null;
    let timedOut = false;
    let killTimer = null;
    let finished = false;
    const closed = new Promise((done) => child.on("close", done));
    const keep = (chunk) => {
      tail.push(chunk);
      tailSize += chunk.length;
      while (tailSize > OUTPUT_TAIL && tail.length > 1) tailSize -= tail.shift().length;
    };
    child.stdout.on("data", (chunk) => {
      if (keepStdout) stdout.push(chunk);
      keep(chunk);
    });
    child.stderr.on("data", keep);
    let known = [];
    const members = () => {
      if (!child.pid) return [];
      if (failure) return known;
      try {
        known = trackTree(listProcesses(), tracked, child.pid);
        stopped ??= known.find((member) => member.stat.startsWith("T"))?.command ?? null;
        return known;
      } catch (error) {
        failure = error.message;
        return known;
      }
    };
    const killAll = (live, name) => {
      if (child.pid) signal(-child.pid, name);
      for (const member of live) {
        signal(member.pid, name);
        if (member.pgid === member.pid) signal(-member.pid, name);
      }
    };
    const finish = async (code) => {
      if (finished) return;
      finished = true;
      clearInterval(poll);
      clearTimeout(timer);
      clearTimeout(killTimer);
      for (let wait = 0; wait < 200; wait += 1) {
        const live = members();
        killAll(live, "SIGKILL");
        if (!live.length || failure) break;
        await sleep(50);
      }
      await Promise.race([closed, sleep(1000)]);
      child.stdout.destroy();
      child.stderr.destroy();
      activeKill = null;
      resolve({ code, stopped, failure, timedOut, stdout: Buffer.concat(stdout).toString("utf8"), output: Buffer.concat(tail).toString("utf8") });
    };
    activeKill = () => killAll(members(), "SIGKILL");
    const poll = setInterval(() => {
      const live = members();
      if (stopped || failure) killAll(live, "SIGKILL");
    }, 100);
    const timer = setTimeout(() => {
      timedOut = true;
      killAll(members(), "SIGTERM");
      killTimer = setTimeout(() => killAll(members(), "SIGKILL"), 5000);
    }, timeout * 1000);
    child.on("error", (error) => {
      failure ??= `cannot start ${argv[0]}: ${error.message}`;
      finish(127);
    });
    child.on("exit", (code) => finish(code ?? 128));
  });
}

function lastLines(text, count = 20) {
  return text.trimEnd().split("\n").slice(-count).join("\n");
}

function firstFailure(text) {
  const line = text.split("\n").find((entry) => /FAIL|not ok|✗|fail|error/i.test(entry));
  return (line ?? "").trim().slice(0, 100);
}

function walk(root, visit) {
  const stack = [root];
  while (stack.length) {
    const dir = stack.pop();
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      visit(path, entry);
      if (entry.isDirectory()) stack.push(path);
    }
  }
}

function builtinCheck(kind, path) {
  if (kind === "sh") return ["/bin/bash", "-n", path];
  if (kind === "js") return ["node", "--check", path];
  if (kind === "node") return ["/bin/bash", "-c", 'node --check --input-type=module < "$1" 2>/dev/null || node --check --input-type=commonjs < "$1"', "check", path];
  return null;
}

async function probe(options, out) {
  if (process.platform !== "darwin") throw new Refusal(`no write sandbox: ${process.platform} has no sandbox-exec`);
  if (!existsSync(SANDBOX)) throw new Refusal(`no write sandbox: ${SANDBOX} is missing`);
  const locked = ["-p", "(version 1)(allow default)(deny lsopen)(deny file-write* (with send-signal SIGSTOP))(allow file-write* (subpath \"/dev\"))"];
  const nested = spawnSync(SANDBOX, [...locked, "/usr/bin/true"], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  if (nested.status !== 0) throw new Refusal(`no write sandbox: sandbox-exec failed (${(nested.stderr || nested.error?.message || "").trim()}); macOS refuses a profile inside another sandbox`);
  const baseGit = ["--no-optional-locks", "--literal-pathspecs", "-c", "core.quotePath=false", "-c", "core.fsmonitor=false", "-c", "diff.autoRefreshIndex=false", "-c", "diff.suppressBlankEmpty=false", "-c", "gc.auto=0", "-c", "maintenance.auto=false"];
  const found = await sandboxed(locked, ["git", ...baseGit, "rev-parse", "--path-format=absolute", "--show-toplevel", "--absolute-git-dir", "--git-common-dir"], process.cwd(), 60, true);
  if (found.failure) throw new Refusal(found.failure);
  const [topPath, gitDirPath, commonPath] = found.stdout.split("\n");
  if (found.code !== 0 || !topPath || !gitDirPath || !commonPath) throw new UsageError("not inside a git work tree");
  const top = canonical(topPath);
  const roots = [...new Set([top, canonical(gitDirPath), canonical(commonPath)])];
  const temp = canonical(tmpdir());
  const allowed = [...new Set(["/private/tmp", "/private/var/tmp", temp, "/dev", ...options.allowWrite.map(canonical)])];

  for (const root of roots.slice(1)) {
    walk(root, (path, entry) => {
      if (entry.isSymbolicLink()) throw new Refusal(`symlink in git metadata: ${path}`);
    });
  }
  for (const root of roots.filter((root) => !roots.some((other) => other !== root && inside(root, other)))) {
    walk(root, (path, entry) => {
      if (entry.isFile() && lstatSync(path).nlink > 1) throw new Refusal(`hard-linked file in protected tree: ${path}`);
    });
  }

  const sameDevice = statSync(temp).dev === statSync(top).dev;
  const suffix = `${process.pid}-${randomBytes(4).toString("hex")}`;
  const requested = sameDevice ? join(temp, `mutation-probe-${suffix}`) : join(dirname(top), `.mutation-probe-${suffix}`);
  if (roots.some((root) => inside(requested, root))) throw new Refusal(`work directory inside a protected root: ${requested}`);
  try {
    mkdirSync(requested);
  } catch (error) {
    throw new Refusal(`cannot create work directory ${requested}: ${error.message}`);
  }
  out.work = requested;
  const work = canonical(requested);
  out.work = work;
  if (roots.some((root) => inside(work, root))) throw new Refusal(`work directory inside a protected root: ${work}`);
  out.log(`work directory: ${work}`);
  for (const path of options.allowWrite) out.log(`allow-write: ${canonical(path)}`);

  const profilePath = (name, own) => {
    const path = join(work, `${name}.sb`);
    writeFileSync(path, profile({ roots, work, allowed, own }));
    return ["-f", path];
  };
  const readProfile = profilePath("read", null);
  const usable = await sandboxed(readProfile, ["/usr/bin/true"], work, 60);
  if (usable.code !== 0) throw new Refusal(`no write sandbox: ${usable.failure ?? lastLines(usable.output, 3)}`);
  const witness = join(work, "stop-witness");
  writeFileSync(witness, "", { flag: "wx" });
  for (const [name, argv] of [["create", ["/usr/bin/touch", join(work, "stop-new")]], ["remove", ["/bin/rm", "-f", witness]], ["rename", ["/bin/mv", witness, join(work, "stop-moved")]]]) {
    const refusal = witnessRefusal(name, await sandboxed(readProfile, ["/bin/sh", "-c", '"$@"; exit $?', "sh", ...argv], work, 10));
    if (refusal) throw new Refusal(refusal);
  }

  let policy = baseGit;
  const git = async (args, accept = [0]) => {
    const result = await sandboxed(readProfile, ["git", ...policy, ...args], top, 300, true);
    if (result.failure) throw new Refusal(result.failure);
    if (result.stopped) throw new Refusal(`git read denied a write: ${result.stopped}`);
    if (!accept.includes(result.code)) throw new Refusal(`git ${args.join(" ")} failed: ${lastLines(result.output, 5)}`);
    return result.stdout;
  };
  const filters = (await git(["config", "--name-only", "--get-regexp", "^filter\\..*\\.(clean|smudge|process)$"], [0, 1])).split("\n").filter(Boolean).map((key) => key.slice("filter.".length, key.lastIndexOf(".")));
  policy = [...baseGit, ...[...new Set(filters)].flatMap((name) => ["-c", `filter.${name}.clean=`, "-c", `filter.${name}.smudge=`, "-c", `filter.${name}.process=`, "-c", `filter.${name}.required=false`])];

  const base = (await git(["rev-parse", "--verify", "--quiet", "--end-of-options", `${options.base}^{commit}`], [0, 1])).trim();
  if (!base) throw new UsageError(`unresolvable --base: ${options.base}`);

  const changed = (await git(["diff", "--name-only", "-z", "--no-renames", "--diff-filter=AM", base])).split("\0").filter(Boolean);
  const untracked = (await git(["ls-files", "--others", "--exclude-standard", "-z"])).split("\0").filter(Boolean);
  const candidates = [];
  for (const [path, isNew] of [...changed.map((path) => [path, false]), ...untracked.map((path) => [path, true])]) {
    if (excluded(path) || (options.paths.length && !options.paths.some((part) => path.includes(part)))) continue;
    const absolute = join(top, path);
    const stat = existsSync(absolute) ? lstatSync(absolute) : null;
    if (!stat?.isFile()) continue;
    const bytes = readFileSync(absolute);
    const kind = sourceKind(path, bytes.subarray(0, 512).toString("utf8").split("\n")[0]);
    if (!kind) continue;
    if (!Buffer.from(bytes.toString("utf8"), "utf8").equals(bytes)) {
      out.log(`skipped, not UTF-8: ${path}`);
      continue;
    }
    candidates.push({ path, isNew, kind, bytes });
  }
  const mutants = [];
  for (const target of candidates) {
    const text = target.bytes.toString("utf8");
    const lines = target.isNew ? text.split("\n").map((_, index) => index + 1) : addedLines(await git(["diff", "--no-color", "--text", "--no-ext-diff", "--no-textconv", "--no-renames", "--inter-hunk-context=0", "-U0", base, "--", target.path]));
    mutants.push(...fileMutants(target.path, text, target.kind, lines));
  }
  if (mutants.length === 0) return { rows: [], generated: 0 };
  const ran = mutants.slice(0, options.max);

  const pristine = join(work, "pristine");
  const empty = join(work, "empty");
  mkdirSync(empty);
  const entries = readdirSync(top).filter((name) => name !== ".git").map((name) => join(top, name));
  const bootstrap = profilePath("pristine", pristine);
  const copyTree = async (flags) => {
    remove(pristine);
    mkdirSync(pristine);
    return entries.length ? sandboxed(bootstrap, ["/bin/cp", ...flags, ...entries, `${pristine}/`], work, 1800) : { code: 0, stopped: null, failure: null };
  };
  let cloneFlags = ["-c", "-R"];
  let copied = await copyTree(cloneFlags);
  if (copied.code !== 0 && !copied.stopped && !copied.failure) {
    cloneFlags = ["-R"];
    copied = await copyTree(cloneFlags);
  }
  if (copied.code !== 0 || copied.stopped || copied.failure) throw new Refusal(`copy failed: ${copied.failure ?? copied.stopped ?? lastLines(copied.output, 5)}`);
  out.log(`copy: ${cloneFlags.includes("-c") ? "clone" : "full"}`);
  const commitConfig = ["-c", `core.hooksPath=${empty}`, "-c", "commit.gpgSign=false", "-c", "init.defaultBranch=pristine", "-c", "user.name=mutation-probe", "-c", "user.email=mutation-probe@localhost"];
  for (const args of [["init", "-q", `--template=${empty}`], ["add", "-A"], ["commit", "-q", "--no-verify", "--allow-empty", "-m", "pristine"]]) {
    const result = await sandboxed(bootstrap, ["git", ...policy, ...commitConfig, ...args], pristine, 600);
    if (result.code !== 0 || result.stopped || result.failure) throw new Refusal(`bootstrap git ${args[0]} failed: ${result.failure ?? result.stopped ?? lastLines(result.output, 5)}`);
  }

  for (const target of candidates) {
    const read = (path) => (existsSync(path) ? readFileSync(path) : Buffer.alloc(0));
    if (!read(join(top, target.path)).equals(target.bytes) || !read(join(pristine, target.path)).equals(target.bytes)) throw new Refusal(`tree changed during capture: ${target.path}`);
  }
  if (!options.check && ran.some((mutant) => mutant.kind === "ts")) out.log("no type check: type errors count as killed");

  const runStep = async (index, mutant) => {
    const dir = join(work, `m${index}`);
    const own = profilePath(`m${index}`, dir);
    const cloned = await sandboxed(own, ["/bin/cp", ...cloneFlags, pristine, dir], work, 1800);
    if (cloned.code !== 0 || cloned.stopped || cloned.failure) throw new Refusal(`clone failed: ${cloned.failure ?? cloned.stopped ?? lastLines(cloned.output, 5)}`);
    try {
      if (mutant) {
        const file = join(dir, mutant.path);
        const stat = lstatSync(file);
        if (!stat.isFile() || stat.nlink !== 1 || !inside(canonical(dirname(file)), canonical(dir))) throw new Refusal(`mutant target is not a single-link regular file in the clone: ${mutant.path}`);
        const source = readFileSync(file, "utf8").split("\n");
        source[mutant.line - 1] = mutant.text;
        writeFileSync(file, source.join("\n"));
      }
      const checks = (mutant ? [mutant] : candidates).map((target) => builtinCheck(target.kind, target.path)).filter(Boolean);
      if (options.check) checks.push(["/bin/bash", "-c", options.check]);
      for (const argv of checks) {
        const result = await sandboxed(own, argv, dir, options.timeout);
        if (result.failure) throw new Refusal(result.failure);
        if (result.stopped || result.timedOut || result.code !== 0) return { stage: "check", result };
      }
      const result = await sandboxed(own, ["/bin/bash", "-c", options.test], dir, options.timeout);
      if (result.failure) throw new Refusal(result.failure);
      return { stage: "test", result };
    } finally {
      remove(dir);
    }
  };

  const baseline = await runStep(0, null);
  if (baseline.result.stopped) throw new Refusal(`baseline failed: denied write by ${baseline.result.stopped}`);
  if (baseline.result.timedOut || baseline.result.code !== 0 || baseline.stage === "check") throw new Refusal(`baseline failed: ${baseline.stage}${baseline.result.timedOut ? " (timeout)" : ""}\n${lastLines(baseline.result.output)}`);

  out.log(HEADER);
  const rows = [];
  for (const [index, mutant] of ran.entries()) {
    const { stage, result } = await runStep(index + 1, mutant);
    let outcome = "survived";
    let note = "";
    if (result.stopped) {
      outcome = "denied";
      note = result.stopped.slice(0, 120);
    } else if (result.timedOut) {
      outcome = "timeout";
    } else if (stage === "check") {
      outcome = "invalid";
      note = firstFailure(result.output);
    } else if (result.code !== 0) {
      outcome = "killed";
      note = firstFailure(result.output) || `exit ${result.code}`;
    }
    const row = { path: mutant.path, line: mutant.line, op: mutant.op, outcome, note };
    rows.push(row);
    out.log(tableRow(row));
  }
  return { rows, generated: mutants.length };
}

async function main(argv) {
  let options;
  try {
    options = parseArgs(argv);
  } catch (error) {
    console.error(`${error.message}\n${USAGE}`);
    return 2;
  }
  if (options.help) {
    console.log(HELP);
    return 0;
  }
  const out = { work: null, log: (line) => console.log(line) };
  const cleanup = () => {
    activeKill?.();
    if (!out.work) return;
    try {
      remove(out.work);
    } catch {
      console.error(`work directory left: ${out.work}`);
    }
    out.work = null;
  };
  for (const [name, number] of SIGNALS) {
    process.on(name, () => {
      cleanup();
      process.exit(128 + number);
    });
  }
  process.on("uncaughtException", (error) => {
    cleanup();
    console.error(error.stack);
    process.exit(2);
  });
  try {
    const { rows, generated } = await probe(options, out);
    if (generated === 0) out.log(HEADER);
    out.log("");
    for (const line of summary(rows, generated)) out.log(line);
    return 0;
  } catch (error) {
    if (error instanceof UsageError) console.error(`${error.message}\n${USAGE}`);
    else console.error(error instanceof Refusal ? error.message : error.stack);
    return 2;
  } finally {
    cleanup();
  }
}

if (process.argv[1] && existsSync(process.argv[1]) && canonical(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
