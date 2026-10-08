import { execFileSync } from "node:child_process";
import { homedir, tmpdir } from "node:os";
import { basename, resolve, sep } from "node:path";

const PREFILTER = /\bgit\b[\s\S]*\bpush\b|\brm\b/;
const RECURSIVE_RM = /\brm\b[\s\S]*\s(?:-[A-Za-z]*[rR][A-Za-z]*|--recursive)\b/;
const SEPARATORS = new Set([";", "&&", "||", "|", "&", "\n", "(", ")"]);
const KEYWORDS = new Set(["then", "do", "else", "elif", "if", "while", "until", "{", "}", "!", "time"]);
const SHELLS = new Set(["bash", "sh", "zsh", "dash", "ksh"]);
const WRAPPERS = {
	sudo: ["-u", "-g", "-h", "-p", "-C", "-D", "-r", "-t", "-T", "-U", "--user", "--group", "--host", "--prompt", "--close-from", "--chdir", "--role", "--type", "--other-user", "--command-timeout"],
	doas: ["-u", "-C"],
	command: [],
	builtin: [],
	nohup: [],
	exec: ["-a"],
	nice: ["-n", "--adjustment"],
	ionice: ["-c", "-n", "-p", "--class", "--classdata", "--pid"],
	stdbuf: ["-i", "-o", "-e", "--input", "--output", "--error"],
	timeout: ["-s", "-k", "--signal", "--kill-after"],
	xargs: ["-I", "-n", "-L", "-P", "-s", "-d", "-E", "-a", "--replace", "--max-args", "--max-lines", "--max-procs", "--max-chars", "--delimiter", "--eof", "--arg-file"],
};
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
		if (character === "#" && !word && !quoted) {
			while (index + 1 < command.length && command[index + 1] !== "\n") index += 1;
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

function heredocDelimiters(line) {
	const visible = [...line];
	let quote = "";
	for (let index = 0; index < visible.length; index += 1) {
		const character = visible[index];
		if (quote) {
			if (character === quote) quote = "";
			visible[index] = " ";
		} else if (character === "'" || character === '"') {
			quote = character;
		} else if (character === "#" && (index === 0 || /\s/.test(visible[index - 1]))) {
			visible.fill(" ", index);
			break;
		}
	}
	const text = visible.join("").replace(/\$\(\([^)]*\)\)/g, (span) => " ".repeat(span.length));
	const delimiters = [];
	for (const match of text.matchAll(/(?<![<\d])<<-?(?!<)\s*/g)) {
		const rest = line.slice(match.index + match[0].length);
		const delimiter = rest.match(/^(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1/);
		if (delimiter) delimiters.push(delimiter[2]);
	}
	return delimiters;
}

function stripHeredocs(command) {
	const kept = [];
	const pending = [];
	for (const line of command.split("\n")) {
		if (pending.length) {
			if (line.trim() === pending[0]) pending.shift();
			continue;
		}
		kept.push(line);
		pending.push(...heredocDelimiters(line));
	}
	return kept.join("\n");
}

function quotedSubstitutionReason(command) {
	for (const [quoted] of command.matchAll(/"(?:[^"\\]|\\.)*"/g)) {
		if (!/\$\(|`/.test(quoted)) continue;
		if (/\bgit\b[\s\S]*\bpush\b/.test(quoted)) return "git push inside a command substitution";
		if (RECURSIVE_RM.test(quoted)) return "recursive rm inside a command substitution";
	}
	return null;
}

function stripQuoted(command) {
	return command
		.replace(/'[^']*'/g, "''")
		.replace(/"(?:[^"\\]|\\.)*"/g, (quoted) => (/\$\(|`/.test(quoted) ? '"$SUBST"' : '""'));
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

function skipOptions(words, index, valued) {
	while (index < words.length && words[index].startsWith("-") && words[index] !== "-") {
		const word = words[index];
		index += 1;
		if (word === "--") break;
		if (valued.includes(word)) index += 1;
	}
	return index;
}

function chdirOption(words, index, names) {
	const word = words[index];
	for (const name of names) {
		if (word === name) return words[index + 1] ?? "$UNKNOWN";
		if (name.startsWith("--") && word.startsWith(`${name}=`)) return word.slice(name.length + 1);
	}
	return undefined;
}

function unwrap(words) {
	let index = 0;
	let fromStdin = false;
	let chdir;
	while (index < words.length) {
		const word = words[index];
		const name = basename(word);
		if (KEYWORDS.has(word) || /^[A-Za-z_][A-Za-z0-9_]*=/.test(word)) {
			index += 1;
		} else if (name === "env") {
			index += 1;
			while (index < words.length && (words[index].startsWith("-") || /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[index]))) {
				const option = words[index];
				if (option === "-S" || option === "--split-string") {
					return { words: [], nested: words[index + 1] ?? "", fromStdin, chdir };
				}
				chdir = chdirOption(words, index, ["-C", "--chdir"]) ?? chdir;
				index += ["-u", "--unset", "-C", "--chdir"].includes(option) ? 2 : 1;
			}
		} else if (name === "rtk" && words[index + 1] === "proxy") {
			index += 2;
		} else if (Object.hasOwn(WRAPPERS, name)) {
			const end = skipOptions(words, index + 1, WRAPPERS[name]);
			if (name === "sudo") {
				for (let at = index + 1; at < end; at += 1) chdir = chdirOption(words, at, ["-D", "--chdir"]) ?? chdir;
			}
			index = end;
			if (name === "timeout") index += 1;
			if (name === "xargs") fromStdin = true;
		} else break;
	}
	return { words: words.slice(index), fromStdin, chdir };
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
	const value = ref.startsWith("refs/heads/") ? ref.slice("refs/heads/".length) : ref;
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
		if (arg === "--dry-run") return null;
		if (arg === "--force") force = true;
		else if (arg.startsWith("--force-with-lease") || arg === "--force-if-includes") continue;
		else if (arg === "--mirror" || arg === "--all" || arg === "--branches") everything = true;
		else if (arg === "--delete") deleting = true;
		else if (/^-[A-Za-z]+$/.test(arg)) {
			if (arg.includes("n")) return null;
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
		if (/^~[^/]/.test(target)) return `recursive rm of ${target} (unresolved home)`;
		let expanded = target
			.replace(/^~(?=\/|$)/, home)
			.replace(/^\$\{?HOME\}?(?=\/|$)/, home)
			.replace(/^\$\{?TMPDIR\}?(?=\/|$)/, tmpdir());
		if (expanded.includes("$")) return `recursive rm of ${target} (unresolved variable)`;
		const glob = expanded.search(/[*?[]/);
		let pattern = "";
		if (glob !== -1) {
			const prefix = expanded.slice(0, glob);
			const cut = prefix.lastIndexOf("/") + 1;
			pattern = expanded.slice(cut).split("/")[0];
			expanded = prefix.slice(0, cut) || ".";
		}
		const path = resolve(cwd, expanded);
		if (path === sep || path === home) return `recursive rm of ${target}`;
		const narrowGlob = pattern && !/^\.?\*+$/.test(pattern);
		if (root && path === root && !narrowGlob) return `recursive rm of the project root (${target})`;
		if (path.split(sep).includes(".git")) return `recursive rm inside .git (${target})`;
		if (root && insidePath(path, root)) continue;
		if (temps.some((temp) => insidePath(path, temp) && path !== temp)) continue;
		return `recursive rm outside the project (${target})`;
	}
	return null;
}

function shellCommandString(args) {
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (["-o", "+o", "-O", "+O"].includes(arg)) {
			index += 1;
			continue;
		}
		if (!/^[-+]/.test(arg)) return null;
		if (/^-[A-Za-z]*c[A-Za-z]*$/.test(arg)) return args.slice(index + 1).find((value) => !/^[-+]/.test(value)) ?? null;
	}
	return null;
}

function findExecDecision(args, cwd, project) {
	const starts = [];
	let index = 0;
	while (index < args.length && !/^[-(!]/.test(args[index])) starts.push(args[index++]);
	for (; index < args.length; index += 1) {
		if (!["-exec", "-execdir", "-ok", "-okdir"].includes(args[index])) continue;
		const end = args.findIndex((value, at) => at > index && (value === ";" || value === "+"));
		const exec = unwrap(args.slice(index + 1, end === -1 ? undefined : end)).words;
		if (exec.length && basename(exec[0]) === "rm") {
			const flags = exec.slice(1).filter((value) => value.startsWith("-"));
			const children = (starts.length ? starts : ["."]).map((start) => `${start.replace(/\/+$/, "")}/entry`);
			const reason = rmDecision([...flags, "--", ...children], cwd, false, project);
			if (reason) return reason;
		}
	}
	return null;
}

function segmentDecision(words, cwd, project) {
	const unwrapped = unwrap(words);
	const { words: command, fromStdin, nested } = unwrapped;
	if (unwrapped.chdir !== undefined) {
		const target = unwrapped.chdir;
		const inner = cwd == null || target.includes("$") ? null : resolve(cwd, target);
		return { reason: segmentDecision(command, inner, project).reason, cwd };
	}
	if (nested !== undefined) return { reason: opsStopReason(nested, cwd ?? process.cwd(), project), cwd };
	if (!command.length) return { cwd };
	const name = basename(command[0]);
	if (name === "cd" || name === "pushd") {
		const args = command.slice(1).filter((value) => value === "-" || !/^-(?:-|[LPe@]*)$/.test(value));
		const target = args[0] ?? homedir();
		if (cwd == null || target === "-" || target.includes("$") || /^[~][^/]/.test(target)) return { cwd: null };
		return { cwd: resolve(cwd, target.replace(/^~(?=\/|$)/, homedir())) };
	}
	if (name === "popd") return { cwd: null };
	if (SHELLS.has(name)) {
		const script = shellCommandString(command.slice(1));
		return { reason: script == null ? null : opsStopReason(script, cwd ?? process.cwd(), project), cwd };
	}
	if (name === "eval") return { reason: opsStopReason(command.slice(1).join(" "), cwd ?? process.cwd(), project), cwd };
	if (name === "find") return { reason: cwd == null ? null : findExecDecision(command.slice(1), cwd, project), cwd };
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
	const text = stripHeredocs(String(command ?? ""));
	if (!PREFILTER.test(text)) return null;
	let segments = segmentsOf(text);
	if (!segments) {
		const substituted = quotedSubstitutionReason(text);
		if (substituted) return substituted;
		const visible = stripQuoted(text);
		segments = segmentsOf(visible);
		if (!segments) {
			if (/\bgit\b[\s\S]*\bpush\b/.test(visible)) return "unparsed command containing git push";
			if (RECURSIVE_RM.test(visible)) return "unparsed command containing a recursive rm";
			return null;
		}
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
	const home = homedir();
	const fallback = start === sep || start === home || insidePath(home, start) ? null : start;
	const project = () => (root === undefined ? (root = git(start, ["rev-parse", "--show-toplevel"]) || fallback) : root);
	const reason = opsStopReason(command, start, project);
	if (!reason) return null;
	return {
		reason: `ops-stop: ${reason} is an irreversible action; confirm it explicitly, or run it yourself.`,
	};
}
