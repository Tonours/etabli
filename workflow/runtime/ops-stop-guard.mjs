import { execFileSync } from "node:child_process";
import { homedir, tmpdir } from "node:os";
import { basename, resolve, sep } from "node:path";

const PREFILTER = /\bgit\b[\s\S]*\bpush\b|\brm\b/;
const RECURSIVE_RM = /\brm\b[\s\S]*\s(?:-[A-Za-z]*[rR][A-Za-z]*|--recursive)\b/;
const SEPARATORS = new Set([";", "&&", "||", "|", "&", "\n", "(", ")"]);
const WRAPPERS = new Set(["sudo", "command", "nohup", "time", "exec", "builtin", "rtk"]);
const PUSH_VALUE_OPTIONS = new Set(["-o", "--push-option", "--repo", "--receive-pack", "--exec"]);
const GIT_VALUE_OPTIONS = new Set(["-c", "--git-dir", "--work-tree", "--namespace"]);

function tokenize(command) {
	const tokens = [];
	let word = "";
	let quoted = false;
	let quote = "";
	const flush = () => {
		if (word || quoted) tokens.push({ word });
		word = "";
		quoted = false;
	};
	for (let index = 0; index < command.length; index += 1) {
		const character = command[index];
		const next = command[index + 1];
		if (quote) {
			if (character === quote) quote = "";
			else if (quote === '"' && (character === "`" || (character === "$" && next === "("))) return null;
			else if (quote === '"' && character === "\\" && next !== undefined) {
				word += next;
				index += 1;
			} else word += character;
			continue;
		}
		if (character === "\\" && next !== undefined) {
			if (next !== "\n") word += next;
			index += 1;
			continue;
		}
		if (character === "'" || character === '"') {
			quote = character;
			quoted = true;
			continue;
		}
		if (character === "`" || (character === "$" && next === "(")) return null;
		if ((character === "<" || character === ">") && next === "(") return null;
		if (character === ">" || character === "<" || (character === "&" && next === ">")) {
			if (/^\d+$/.test(word)) word = "";
			flush();
			while (/[<>&|]/.test(command[index + 1] ?? "")) index += 1;
			tokens.push({ redirect: true });
			continue;
		}
		if (/\s/.test(character) && character !== "\n") {
			flush();
			continue;
		}
		const pair = character + (next ?? "");
		if (pair === "&&" || pair === "||") {
			flush();
			tokens.push({ op: pair });
			index += 1;
			continue;
		}
		if (SEPARATORS.has(character)) {
			flush();
			tokens.push({ op: character });
			continue;
		}
		word += character;
	}
	if (quote) return null;
	flush();
	return tokens;
}

function segmentsOf(command) {
	const tokens = tokenize(command);
	if (!tokens) return null;
	const segments = [];
	let current = [];
	let skipRedirectTarget = false;
	for (const token of tokens) {
		if (token.op) {
			if (current.length) segments.push(current);
			current = [];
			skipRedirectTarget = false;
			continue;
		}
		if (token.redirect) {
			skipRedirectTarget = true;
			continue;
		}
		if (skipRedirectTarget) {
			skipRedirectTarget = false;
			continue;
		}
		current.push(token.word);
	}
	if (current.length) segments.push(current);
	return segments;
}

function unwrap(words) {
	let index = 0;
	while (index < words.length) {
		const word = words[index];
		const name = basename(word);
		if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(word)) {
			index += 1;
		} else if (name === "env") {
			index += 1;
			while (index < words.length && (words[index].startsWith("-") || /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[index]))) {
				index += words[index] === "-u" ? 2 : 1;
			}
		} else if (name === "rtk" && words[index + 1] === "proxy") {
			index += 2;
		} else if (WRAPPERS.has(name)) {
			index += 1;
			while (index < words.length && words[index].startsWith("-")) index += 1;
		} else if (name === "xargs") {
			index += 1;
			while (index < words.length && words[index].startsWith("-")) index += 1;
			return { words: words.slice(index), fromStdin: true };
		} else break;
	}
	return { words: words.slice(index), fromStdin: false };
}

function git(cwd, args) {
	try {
		return execFileSync("git", ["-C", cwd, ...args], {
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
	} catch {
		return "";
	}
}

function defaultBranches(cwd, remote) {
	const branches = new Set(["main", "master"]);
	const head = git(cwd, ["symbolic-ref", "--quiet", "--short", `refs/remotes/${remote}/HEAD`]);
	if (head.startsWith(`${remote}/`)) branches.add(head.slice(remote.length + 1));
	return branches;
}

function branchName(ref, currentBranch) {
	const value = ref.replace(/^refs\/heads\//, "");
	return value === "HEAD" || value === "@" ? currentBranch : value;
}

function pushDecision(args, cwd) {
	let force = false;
	let everything = false;
	let deleting = false;
	const positionals = [];
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (arg === "--") {
			positionals.push(...args.slice(index + 1));
			break;
		}
		if (PUSH_VALUE_OPTIONS.has(arg)) {
			index += 1;
			continue;
		}
		if (arg === "--force") force = true;
		else if (arg.startsWith("--force-with-lease") || arg === "--force-if-includes") continue;
		else if (arg === "--mirror" || arg === "--all" || arg === "--branches") everything = true;
		else if (arg === "--delete") deleting = true;
		else if (/^-[A-Za-z]+$/.test(arg)) {
			if (arg.includes("f")) force = true;
			if (arg.includes("d")) deleting = true;
		} else if (!arg.startsWith("-")) positionals.push(arg);
	}
	const [remote = "origin", ...refspecs] = positionals;
	if ([remote, ...refspecs].some((value) => value.includes("$"))) {
		return "git push with an unresolved variable";
	}
	if (everything) return "git push of every branch";
	const currentBranch = git(cwd, ["branch", "--show-current"]);
	const defaults = defaultBranches(cwd, remote);
	const targets = refspecs.length
		? refspecs.map((spec) => {
			if (spec.startsWith("+")) force = true;
			const bare = spec.replace(/^\+/, "");
			const destination = bare.includes(":") ? bare.slice(bare.indexOf(":") + 1) : bare;
			return branchName(destination, currentBranch);
		})
		: [currentBranch];
	const hit = targets.find((target) => target && defaults.has(target));
	if (hit) return `git push to the default branch ${hit}${deleting ? " (delete)" : ""}`;
	if (force) return "git push --force without a lease";
	return null;
}

function insidePath(path, root) {
	return path === root || path.startsWith(root.endsWith(sep) ? root : root + sep);
}

function rmDecision(args, cwd, fromStdin, project) {
	let recursive = false;
	const targets = [];
	let options = true;
	for (const arg of args) {
		if (options && arg === "--") {
			options = false;
			continue;
		}
		if (options && arg === "--recursive") recursive = true;
		else if (options && /^-[A-Za-z]+$/.test(arg)) {
			if (/[rR]/.test(arg)) recursive = true;
		} else if (options && arg.startsWith("--")) continue;
		else targets.push(arg);
	}
	if (!recursive) return null;
	if (fromStdin) return "recursive rm on targets read from stdin";
	if (cwd == null) return "recursive rm after an unresolved cd";
	const home = homedir();
	const root = project();
	const temps = [tmpdir(), "/tmp", "/private/tmp", "/var/folders"].map((path) => resolve(path));
	for (const target of targets) {
		let expanded = target
			.replace(/^~(?=\/|$)/, home)
			.replace(/^\$\{?HOME\}?(?=\/|$)/, home)
			.replace(/^\$\{?TMPDIR\}?(?=\/|$)/, tmpdir());
		if (expanded.includes("$")) return `recursive rm of ${target} (unresolved variable)`;
		const glob = expanded.search(/[*?[]/);
		if (glob !== -1) expanded = expanded.slice(0, glob).replace(/[^/]*$/, "") || ".";
		const path = resolve(cwd, expanded);
		if (path === sep || path === home) return `recursive rm of ${target}`;
		if (path === root) return `recursive rm of the project root (${target})`;
		if (path.split(sep).includes(".git")) return `recursive rm inside .git (${target})`;
		if (insidePath(path, root)) continue;
		if (temps.some((temp) => insidePath(path, temp) && path !== temp)) continue;
		return `recursive rm outside the project (${target})`;
	}
	return null;
}

function segmentDecision(words, cwd, project) {
	const { words: command, fromStdin } = unwrap(words);
	if (!command.length) return { cwd };
	const name = basename(command[0]);
	if (name === "cd") {
		const target = command[1] ?? homedir();
		if (cwd == null || target === "-" || target.includes("$")) return { cwd: null };
		return { cwd: resolve(cwd, target.replace(/^~(?=\/|$)/, homedir())) };
	}
	if ((name === "bash" || name === "sh" || name === "zsh") && command[1] === "-c" && command[2]) {
		return { reason: opsStopReason(command[2], cwd ?? process.cwd(), project), cwd };
	}
	if (name === "git") {
		let index = 1;
		let gitCwd = cwd;
		while (index < command.length && command[index].startsWith("-")) {
			if (command[index] === "-C") {
				gitCwd = gitCwd == null ? null : resolve(gitCwd, command[index + 1] ?? ".");
				index += 2;
			} else if (GIT_VALUE_OPTIONS.has(command[index])) index += 2;
			else index += 1;
		}
		if (command[index] !== "push") return { cwd };
		if (gitCwd == null) return { reason: "git push after an unresolved cd", cwd };
		return { reason: pushDecision(command.slice(index + 1), gitCwd), cwd };
	}
	if (name === "rm") return { reason: rmDecision(command.slice(1), cwd, fromStdin, project), cwd };
	return { cwd };
}

function opsStopReason(command, cwd, project) {
	const text = String(command ?? "");
	if (!PREFILTER.test(text)) return null;
	const segments = segmentsOf(text);
	if (!segments) {
		if (/\bgit\b[\s\S]*\bpush\b/.test(text)) return "unparsed command containing git push";
		if (RECURSIVE_RM.test(text)) return "unparsed command containing a recursive rm";
		return null;
	}
	let current = cwd;
	for (const words of segments) {
		const result = segmentDecision(words, current, project);
		if (result.reason) return result.reason;
		current = result.cwd;
	}
	return null;
}

export function opsStopGuardDecision({ command, cwd } = {}) {
	const start = resolve(cwd || process.cwd());
	let root;
	const project = () => (root ??= git(start, ["rev-parse", "--show-toplevel"]) || start);
	const reason = opsStopReason(command, start, project);
	if (!reason) return null;
	return {
		reason: `ops-stop: ${reason} is an irreversible action; confirm it explicitly, or run it yourself.`,
	};
}
