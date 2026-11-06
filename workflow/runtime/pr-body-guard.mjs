import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const PREFIX =
	"(?:^|[;&|(){}\\n]|\\b(?:then|do|else)[ \\t])[ \\t]*(?:(?:[A-Za-z_][A-Za-z0-9_]*=\\S*|command|env|exec|time|nohup|rtk|proxy|sudo(?:[ \\t]+(?:-[ugCDhpRrTU][ \\t]+\\S+|-\\S+))*|if|elif|while|until|!|timeout(?:[ \\t]+(?:-[ks][ \\t]+\\S+|-\\S+))*[ \\t]+\\d\\S*)[ \\t]+)*";
const INVOCATION = new RegExp(
	`${PREFIX}gh(?:[ \\t]+(?:-R\\S+|-R[ \\t]+\\S+|--repo=\\S+|--repo[ \\t]+\\S+))?[ \\t]+pr[ \\t]+(create|new|edit)(?=[ \\t;&|)\\n]|$)`,
	"g",
);
const COMMIT = new RegExp(
	`${PREFIX}git((?:[ \\t]+(?:-C[ \\t]+\\S+|-C\\S+|-c[ \\t]+\\S+|-c\\S+|--[a-z-]+(?:=\\S+)?))*)[ \\t]+commit(?=[ \\t;&|)\\n]|$)`,
	"g",
);
const CD = /(?:^|[;&|(){}\n])[ \t]*cd[ \t]+([^\s;&|()]+)/g;
const OUR_HEADINGS = ["## What", "## Why", "## How to test"];
const ATTRIBUTION = /claude-session:|generated with|co-authored-by:|claude\.ai\/code/i;
const MODELS = "chatgpt|gpt(?:-?\\d\\w*)?|openai|codex|glm|zai|z\\.ai|zhipu|gemini|deepseek|mistral|grok|qwen|llama|kimi";
const COMMIT_ATTRIBUTION = new RegExp(
	`^\\s*(?:claude-session|co-authored-by)\\s*:|generated (?:with|by)\\b[^\\n]*\\b(?:${MODELS}|claude|copilot|windsurf|tabnine)\\b|claude\\.ai\\/code`,
	"im",
);
const PROPER_CREDIT = /[Gg]enerated (?:[Ww]ith|[Bb]y)\b[^\n]*\b(?:Cursor|Aider|Devin|Cline|AI|LLM)\b/m;
const MODEL_NAME = new RegExp(`\\b(?:${MODELS})\\b`, "gi");
const MAX_BODY_BYTES = 1024 * 1024;
const REMEDIATION =
	"Write the body with the `pr` skill (workflow/pr-body-contract.md): one opening line, then ## What, ## Why, ## How to test, in English, and pass it with --body-file <file>.";
const COMMIT_REMEDIATION =
	"Write the subject line only (workflow/git-contract.md): no trailers, no AI attribution, and no non-Claude model or provider name in a work-org repo (an identifier in a backtick code span inside a single-quoted -m passes).";

function deny(prProblems, commitProblems) {
	const reasons = [];
	if (prProblems.length) reasons.push(`PR body refused: ${prProblems.join("; ")}. ${REMEDIATION}`);
	if (commitProblems.length) reasons.push(`Commit message refused: ${commitProblems.join("; ")}. ${COMMIT_REMEDIATION}`);
	return {
		hookSpecificOutput: {
			hookEventName: "PreToolUse",
			permissionDecision: "deny",
			permissionDecisionReason: reasons.join(" "),
		},
	};
}

export function scanShell(command) {
	const length = command.length;
	const visible = command.split("");
	const heredocs = [];
	const stack = [];
	const pending = [];
	const hide = (from, to) => {
		for (let k = from; k < Math.min(to, length); k += 1) visible[k] = "_";
	};
	let i = 0;
	while (i < length) {
		const ch = command[i];
		const top = stack[stack.length - 1];
		if (stack.includes('"')) visible[i] = "_";
		if (top === '"') {
			if (ch === "\\") {
				hide(i, i + 2);
				i += 2;
			} else if (ch === '"') {
				stack.pop();
				i += 1;
			} else if (ch === "$" && command[i + 1] === "(") {
				hide(i, i + 2);
				stack.push("$(");
				i += 2;
			} else {
				i += 1;
			}
			continue;
		}
		if (ch === "\\") {
			if (command[i + 1] === "\n" && !stack.includes('"')) {
				visible[i] = " ";
				visible[i + 1] = " ";
			} else {
				hide(i, i + 2);
			}
			i += 2;
			continue;
		}
		if (ch === "'") {
			const close = command.indexOf("'", i + 1);
			const stop = close === -1 ? length : close;
			hide(i + 1, stop);
			i = stop + 1;
			continue;
		}
		if (ch === "$" && command[i + 1] === "'") {
			let k = i + 2;
			while (k < length && command[k] !== "'") k += command[k] === "\\" ? 2 : 1;
			hide(i + 2, k);
			i = k + 1;
			continue;
		}
		if (ch === '"') {
			stack.push('"');
			i += 1;
			continue;
		}
		if (ch === "$" && command[i + 1] === "(") {
			if (stack.includes('"')) hide(i, i + 2);
			stack.push("$(");
			i += 2;
			continue;
		}
		if (ch === ")" && top === "$(") {
			stack.pop();
			i += 1;
			continue;
		}
		if (ch === "#" && (i === 0 || /[\s;&|(]/.test(command[i - 1]))) {
			const newline = command.indexOf("\n", i);
			const stop = newline === -1 ? length : newline;
			hide(i, stop);
			i = stop;
			continue;
		}
		const here =
			ch === "<" && command[i - 1] !== "<"
				? /^<<(-?)[ \t]*(?:(['"])([A-Za-z0-9_.-]+)\2|(\\?)([A-Za-z_][A-Za-z0-9_.-]*))(?![A-Za-z0-9_.-])/.exec(command.slice(i, i + 256))
				: null;
		if (here && command[i + 2] !== "<") {
			pending.push({ at: i, word: here[3] ?? here[5], strip: here[1] === "-", quoted: Boolean(here[2] || here[4]) });
			if (stack.includes('"')) hide(i, i + here[0].length);
			i += here[0].length;
			continue;
		}
		if (ch === "\n" && pending.length) {
			let pos = i + 1;
			let resume = length;
			for (const doc of pending.splice(0)) {
				const start = pos;
				let end = length;
				while (pos < length) {
					const newline = command.indexOf("\n", pos);
					const stop = newline === -1 ? length : newline;
					const line = command.slice(pos, stop);
					if ((doc.strip ? line.replace(/^\t+/, "") : line) === doc.word) {
						end = pos;
						hide(pos, stop);
						resume = stop;
						pos = stop + 1;
						break;
					}
					pos = stop + 1;
				}
				if (end === length) resume = length;
				hide(start, end);
				heredocs.push({ at: doc.at, body: command.slice(start, end), quoted: doc.quoted });
			}
			i = Math.max(resume, i + 1);
			continue;
		}
		i += 1;
	}
	return { visible: visible.join(""), heredocs };
}

function ansiC(raw, from) {
	const escapes = { n: "\n", t: "\t", r: "\r", "\\": "\\", "'": "'", '"': '"', a: "\x07", b: "\b", e: "\x1b", f: "\f", v: "\v" };
	let text = "";
	let k = from;
	while (k < raw.length && raw[k] !== "'") {
		if (raw[k] !== "\\") {
			text += raw[k];
			k += 1;
			continue;
		}
		const next = raw[k + 1] ?? "";
		const octal = /^[0-7]{1,3}/.exec(raw.slice(k + 1));
		const hex = /^x([0-9A-Fa-f]{1,2})/.exec(raw.slice(k + 1));
		const unicode = /^(?:u([0-9A-Fa-f]{1,4})|U([0-9A-Fa-f]{1,8}))/.exec(raw.slice(k + 1));
		if (octal) {
			text += Buffer.from([Number.parseInt(octal[0], 8) & 0xff]).toString("latin1");
			k += 1 + octal[0].length;
		} else if (hex) {
			text += Buffer.from([Number.parseInt(hex[1], 16)]).toString("latin1");
			k += 1 + hex[0].length;
		} else if (unicode) {
			const point = Number.parseInt(unicode[1] ?? unicode[2], 16);
			text += point <= 0x10ffff ? String.fromCodePoint(point) : "\ufffd";
			k += 1 + unicode[0].length;
		} else {
			text += escapes[next] ?? `\\${next}`;
			k += 2;
		}
	}
	return k < raw.length ? { text, end: k } : null;
}

// vars: known shell variables, read only as $NAME or ${NAME}; any other expansion stays unknown.
export function staticWord(raw, vars = null) {
	let out = "";
	let i = 0;
	const known = (at, quoted) => {
		const match = vars && /^\$(?:\{(\w+)\}|([A-Za-z_]\w*))/.exec(raw.slice(at));
		const value = match && Object.hasOwn(vars, match[1] ?? match[2]) ? vars[match[1] ?? match[2]] : undefined;
		if (value === undefined || /^[:[]/.test(raw.slice(at + match[0].length)) || (!quoted && /[\s*?[]/.test(value))) return null;
		return { value, end: at + match[0].length };
	};
	while (i < raw.length) {
		const ch = raw[i];
		if (ch === "'") {
			const close = raw.indexOf("'", i + 1);
			if (close === -1) return null;
			out += raw.slice(i + 1, close);
			i = close + 1;
		} else if (ch === "$" && raw[i + 1] === "'") {
			const decoded = ansiC(raw, i + 2);
			if (!decoded) return null;
			out += decoded.text;
			i = decoded.end + 1;
		} else if (ch === '"') {
			let k = i + 1;
			while (k < raw.length && raw[k] !== '"') {
				if (raw[k] === "\\" && '"\\$`\n'.includes(raw[k + 1])) {
					out += raw[k + 1];
					k += 2;
					continue;
				}
				if (raw[k] === "$") {
					const variable = known(k, true);
					if (!variable) return null;
					out += variable.value;
					k = variable.end;
					continue;
				}
				if (raw[k] === "`") return null;
				out += raw[k];
				k += 1;
			}
			if (k >= raw.length) return null;
			i = k + 1;
		} else if (ch === "\\") {
			out += raw[i + 1] ?? "";
			i += 2;
		} else if (ch === "$") {
			const variable = known(i, false);
			if (!variable) return null;
			out += variable.value;
			i = variable.end;
		} else if (ch === "`") {
			return null;
		} else {
			out += ch;
			i += 1;
		}
	}
	return out;
}

function expandHome(path) {
	const home = process.env.HOME;
	if (!home) return path;
	if (path === "~") return home;
	return path.startsWith("~/") ? join(home, path.slice(2)) : path;
}

function effectiveCwd(command, visible, before, cwd) {
	let dir = cwd;
	CD.lastIndex = 0;
	for (let match = CD.exec(visible); match && match.index < before; match = CD.exec(visible)) {
		const start = match.index + match[0].length - match[1].length;
		let depth = 0;
		let scoped = false;
		for (const ch of visible.slice(start, before)) {
			if (ch === "(") depth += 1;
			else if (ch === ")" && --depth < 0) scoped = true;
		}
		if (scoped) continue;
		const target = staticWord(command.slice(start, start + match[1].length));
		if (target === null || target === "-") return null;
		dir = resolve(dir, expandHome(target));
	}
	return dir;
}

function gitRoot(cwd) {
	let dir = resolve(cwd);
	while (true) {
		if (existsSync(join(dir, ".git"))) return dir;
		const parent = dirname(dir);
		if (parent === dir) return null;
		dir = parent;
	}
}

function workOrgs() {
	const file = process.env.ETABLI_WORK_ORGS_FILE || expandHome("~/.config/etabli/work-orgs");
	try {
		return new Set(
			readFileSync(file, "utf8")
				.split(/\r?\n/)
				.map((line) => line.trim())
				.filter((line) => /^[A-Za-z0-9-]+$/.test(line))
				.map((line) => line.toLowerCase()),
		);
	} catch {
		return new Set();
	}
}

function githubUrlOwner(url) {
	const match = /^(?:(?:ssh|https?|git):\/\/)?(?:[^@/\s]+@)?github\.com(?::\d+\/|[:/])([A-Za-z0-9-]+)\/[A-Za-z0-9_.-]+?(?:\.git)?\/?$/i.exec(url.trim());
	return match ? match[1].toLowerCase() : null;
}

function githubOwner(target) {
	const short = /^(?:github\.com\/)?([A-Za-z0-9-]+)\/[A-Za-z0-9_.-]+$/i.exec(target.trim());
	return short ? short[1].toLowerCase() : githubUrlOwner(target);
}

function originOwner(dir) {
	if (dir === null) return null;
	try {
		const url = execFileSync("git", ["-C", dir, "config", "--get", "remote.origin.url"], {
			encoding: "utf8",
			timeout: 2000,
			stdio: ["ignore", "pipe", "ignore"],
		});
		return githubUrlOwner(url);
	} catch {
		return null;
	}
}

function repoFlag(command, args) {
	for (let k = 0; k < args.length; k += 1) {
		const flag = /^(?:--repo=|-R(?=.))/.exec(args[k].text);
		const value = flag
			? { start: args[k].start + flag[0].length, end: args[k].end }
			: /^(?:--repo|-R)$/.test(args[k].text)
				? args[k + 1]
				: null;
		if (value) return staticWord(command.slice(value.start, value.end)) ?? "";
	}
	return null;
}

function modelNameProblems(body, isWork) {
	const names = markdownLines(body, { keepComments: true }).join("\n").replace(/`[^`]*`/g, "").match(MODEL_NAME);
	if (!names || !isWork()) return [];
	return [`non-Claude model or provider name in a work-org repo: ${[...new Set(names)].join(", ")}`];
}

function templateHeadings(cwd) {
	const root = gitRoot(cwd);
	if (!root) return [];
	for (const sub of [".github", "", "docs"]) {
		const dir = join(root, sub);
		if (!existsSync(dir) || !statSync(dir).isDirectory()) continue;
		const name = readdirSync(dir).find((file) => file.toLowerCase() === "pull_request_template.md");
		if (!name) continue;
		return markdownLines(readFileSync(join(dir, name), "utf8")).filter((line) => /^#{1,6} \S/.test(line));
	}
	return [];
}

function markdownLines(body, { dropQuotesAndTables = false, keepComments = false } = {}) {
	const lines = [];
	let fence = null;
	let comment = false;
	let previous = "";
	let indentedCode = false;
	for (const source of body.split(/\r?\n/)) {
		let raw = source;
		if (comment) {
			const close = raw.indexOf("-->");
			if (keepComments) lines.push((close === -1 ? raw : raw.slice(0, close)).trim());
			if (close === -1) continue;
			raw = raw.slice(close + 3);
			comment = false;
		}
		const marker = /^ {0,3}(`{3,}|~{3,})/.exec(raw);
		if (fence) {
			if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && raw.trim() === marker[1]) fence = null;
			continue;
		}
		if (marker) {
			fence = marker[1];
			continue;
		}
		const blank = raw.trim() === "";
		indentedCode = !blank && /^(?: {4}|\t)/.test(raw) && (indentedCode || previous === "");
		previous = blank ? "" : raw;
		if (indentedCode) continue;
		raw = raw.replace(/<!--([\s\S]*?)-->/g, keepComments ? " $1 " : "");
		const open = raw.indexOf("<!--");
		const tail = open === -1 ? "" : raw.slice(open + 4);
		if (open !== -1) {
			raw = raw.slice(0, open);
			comment = true;
		}
		if (dropQuotesAndTables && /^\s*[|>]/.test(raw)) continue;
		lines.push(raw.trim());
		if (keepComments && tail) lines.push(tail.trim());
	}
	return lines;
}

function words(visible, from, to) {
	const found = [];
	const pattern = /\S+/g;
	const slice = visible.slice(from, to);
	for (let match = pattern.exec(slice); match; match = pattern.exec(slice)) {
		found.push({ text: match[0], start: from + match.index, end: from + match.index + match[0].length });
	}
	return found;
}

function heredocText(doc) {
	if (!doc.quoted && /[$`]/.test(doc.body)) {
		return { problem: "unquoted heredoc expands $ or backticks at run time; quote its delimiter (<<'EOF')" };
	}
	return { text: doc.body };
}

function bodyOf(command, scan, args, segment, cwd) {
	let source = null;
	for (let k = 0; k < args.length; k += 1) {
		const flag = /^(?:(--body-file|--body)(=|$)|(-F|-b)(?=.))/.exec(args[k].text) ?? /^(-F|-b)$/.exec(args[k].text);
		if (!flag) continue;
		const name = flag[1] ?? flag[3] ?? flag[0];
		const kind = name === "--body-file" || name === "-F" ? "file" : "inline";
		const attached = flag[2] === "=" || Boolean(flag[3]);
		const value = attached ? { start: args[k].start + flag[0].length, end: args[k].end } : args[k + 1];
		source = { kind, raw: value ? command.slice(value.start, value.end) : "", value };
	}
	if (!source) return { none: true };
	const heredoc = scan.heredocs.find((doc) => source.value && doc.at >= source.value.start && doc.at < source.value.end)
		?? scan.heredocs.find((doc) => doc.at >= segment.start && doc.at < segment.end);
	if (source.kind === "inline") {
		const text = staticWord(source.raw);
		if (text !== null) return { text };
		if (/^"?\$\(\s*cat\s+<</.test(source.raw) && heredoc) return heredocText(heredoc);
		return { problem: "body value is built at run time and cannot be checked" };
	}
	let name = staticWord(source.raw);
	if (name === "-") {
		const stdin = stdinSource(command, scan, segment);
		if (stdin?.doc) return heredocText(stdin.doc);
		if (!stdin?.file) return { problem: "body read from a pipe cannot be checked" };
		name = stdin.file;
	}
	if (!name) return { problem: "body file name is built at run time and cannot be checked" };
	if (cwd === null) return { problem: `body file ${name} sits behind a cd that cannot be resolved` };
	const path = resolve(cwd, expandHome(name));
	if (!existsSync(path)) return { problem: `body file ${name} not found from ${cwd}; pass an absolute path` };
	const stat = statSync(path);
	if (!stat.isFile()) return { problem: `body file ${name} is not a regular file` };
	if (stat.size > MAX_BODY_BYTES) return { problem: `body file ${name} is over 1 MiB` };
	return { text: readFileSync(path, "utf8") };
}

const EXPANSION = /^(?:\$\([^)]*\)|`[^`]*`|\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@*#?$!-])/;

function literalText(raw) {
	let out = "";
	let quote = null;
	let i = 0;
	while (i < raw.length) {
		const ch = raw[i];
		if (quote === "'") {
			if (ch === "'") quote = null;
			else out += ch;
			i += 1;
		} else if (ch === '"') {
			quote = quote === '"' ? null : '"';
			i += 1;
		} else if (ch === "'" && quote === null) {
			quote = "'";
			i += 1;
		} else if (ch === "$" && raw[i + 1] === "'" && quote === null) {
			const decoded = ansiC(raw, i + 2);
			out += decoded ? decoded.text : "";
			i = decoded ? decoded.end + 1 : raw.length;
		} else if (ch === "\\") {
			out += raw[i + 1] ?? "";
			i += 2;
		} else {
			const expansion = EXPANSION.exec(raw.slice(i));
			if (!expansion) out += ch;
			i += expansion ? expansion[0].length : 1;
		}
	}
	return out;
}

function messageText(raw, scan, at) {
	const text = staticWord(raw);
	if (text !== null) return text;
	const heredoc = scan.heredocs.find((doc) => doc.at >= at.start && doc.at < at.end);
	if (/^"?\$\(\s*cat\s+<</.test(raw) && heredoc) {
		const rest = raw.slice(raw.indexOf(heredoc.body) + heredoc.body.length).replace(/^[^\n]*\n?/, "");
		const close = /^(?:[ \t]*(?:#[^\n]*)?\n)*[ \t]*\)/.exec(rest);
		const body = heredoc.body.replace(/\n+$/, "");
		if (!close) return `${body}\n${literalText(rest)}`;
		return `${body}${literalText(`${raw.startsWith('"') ? '"' : ""}${rest.slice(close[0].length)}`)}`;
	}
	return literalText(raw);
}

function commandWords(visible, from, to) {
	return words(visible, from, to)
		.map((arg) => {
			const cut = arg.text.search(/[<>]/);
			return cut === -1 ? arg : { text: arg.text.slice(0, cut), start: arg.start, end: arg.start + cut };
		})
		.filter((arg) => arg.text);
}

function commandEnd(visible, from) {
	for (let k = from; k < visible.length; k += 1) {
		if (";|)\n".includes(visible[k]) || (visible[k] === "&" && !"<>".includes(visible[k - 1]) && visible[k + 1] !== ">")) return k;
	}
	return visible.length;
}

function stdinSource(command, scan, segment) {
	const end = segment.end;
	const fds = new Map();
	const redirect = /(\d*)(<<<|<<-?|<&|<>|<|>&|>>|>\|?)/g;
	const line = scan.visible.slice(segment.start, end);
	for (let match = redirect.exec(line); match; match = redirect.exec(line)) {
		const explicit = match[1] && /^$|[\s;&|(]$/.test(line.slice(0, match.index).slice(-1));
		const fd = explicit ? match[1] : match[2].startsWith(">") ? "1" : "0";
		const after = segment.start + match.index + match[0].length;
		if (match[2].startsWith("<<") && match[2] !== "<<<") {
			const doc = scan.heredocs.find((entry) => entry.at === after - match[2].length);
			fds.set(fd, doc ? { text: doc.body, doc } : null);
			continue;
		}
		const word = words(scan.visible, after, end)[0];
		const operator = word ? word.text.search(/[<>]/) : -1;
		const raw = word ? command.slice(word.start, operator === -1 ? word.end : word.start + operator) : "";
		if (match[2] === "<&" || match[2] === ">&") {
			const source = raw.replace(/-$/, "");
			fds.set(fd, fds.get(source) ?? null);
			if (raw.endsWith("-") && source !== fd) fds.delete(source);
		}
		else if (match[2] === "<<<") fds.set(fd, { text: `${staticWord(raw) ?? literalText(raw)}\n` });
		else if (match[2] === "<") fds.set(fd, { file: staticWord(raw) });
		else fds.set(fd, null);
	}
	return fds.get("0") ?? null;
}

// $PWD is the tracked shell directory only in an otherwise static command: no line
// continuation and no directory change the cd tracking misses, and with quotes and
// escapes dropped and its plain $PWD or ${PWD} reads removed, no $, backtick,
// brace, PW or IFS is left. Anything else stays unknown.
function pwdVars(command, dir) {
	if (dir === null || /\\\n|\b(?:pushd|popd|builtin)\b/.test(command)) return null;
	const rest = command
		.replace(/[\\'"]/g, "")
		.replace(/\$PWD(?![\w=:[])|\$\{PWD\}(?![:[])/g, "");
	return /[$`{]|PW|IFS/.test(rest) ? null : { PWD: dir };
}

function commitMessages(command, scan, args, segment, dirs) {
	const messages = [];
	for (let k = 0; k < args.length; k += 1) {
		const raw = command.slice(args[k].start, args[k].end);
		const decoded = staticWord(raw);
		const word = decoded ?? literalText(raw);
		if (word === "--") break;
		const flag = /^--(message|file|trailer)(=|$)/.exec(word) ?? /^-(?!-)[A-Za-z]*?([mF])/.exec(word);
		if (!flag) continue;
		const kind = flag[1] === "file" || flag[1] === "F" ? "file" : "message";
		const attached =
			flag[2] === "=" || (flag[2] === undefined && (word.length > flag[0].length || (raw.startsWith(flag[0]) && raw.length > flag[0].length)));
		let text;
		let name;
		if (attached && raw.startsWith(flag[0])) {
			const valueRaw = raw.slice(flag[0].length);
			text = messageText(valueRaw, scan, { start: args[k].start + flag[0].length, end: args[k].end });
			name = staticWord(valueRaw, dirs.vars);
		} else if (attached) {
			text = word.slice(flag[0].length);
			name = decoded === null ? (staticWord(raw, dirs.vars)?.slice(flag[0].length) ?? null) : text;
		} else {
			k += 1;
			if (!args[k]) continue;
			const valueRaw = command.slice(args[k].start, args[k].end);
			text = messageText(valueRaw, scan, args[k]);
			name = staticWord(valueRaw, dirs.vars);
		}
		if (kind === "message") {
			messages.push(flag[1] === "trailer" ? text.replace(/^([^:=]*)=/, "$1:") : text);
			continue;
		}
		const stdin = name === "-" ? stdinSource(command, scan, segment) : null;
		if (stdin?.text !== undefined) messages.push(stdin.text);
		const file = name === "-" ? stdin?.file : name;
		const cwd = name === "-" ? dirs.shell : dirs.git;
		if (!file || cwd === null) continue;
		const path = resolve(cwd, expandHome(file));
		const stat = existsSync(path) ? statSync(path) : null;
		if (stat?.isFile() && stat.size <= MAX_BODY_BYTES) messages.push(readFileSync(path, "utf8"));
	}
	return messages;
}

function gitDir(command, globals, base, dir) {
	let current = dir;
	const pattern = /(?:^|[ \t])-C(?:[ \t]+|(?=\S))(\S+)/g;
	for (let match = pattern.exec(globals); match && current !== null; match = pattern.exec(globals)) {
		const start = base + match.index + match[0].length - match[1].length;
		const target = staticWord(command.slice(start, start + match[1].length));
		current = target === null ? null : resolve(current, expandHome(target));
	}
	return current;
}

function checkBody(body, cwd, isWork) {
	const problems = [];
	const lines = markdownLines(body);
	const template = cwd === null ? [] : templateHeadings(cwd);
	const templateCovers =
		template.some((h) => /\bwhat\b|chang/i.test(h)) && template.some((h) => /test|verif|validat/i.test(h));
	const required = [...template, ...(templateCovers ? [] : OUR_HEADINGS)];
	const missing = required.filter((heading) => !lines.includes(heading));
	if (missing.length) problems.push(`missing ${missing.join(", ")}`);
	if (ATTRIBUTION.test(body)) problems.push("AI attribution in the body");
	const prose = markdownLines(body, { dropQuotesAndTables: true })
		.map((line) => line.replace(/`[^`]*`/g, ""))
		.join("\n");
	const nonAscii = prose.match(/[^\x09\x0a\x0d\x20-\x7e]/gu);
	if (nonAscii) problems.push(`non-ASCII outside code, tables and quotes: ${[...new Set(nonAscii)].join(" ")}`);
	problems.push(...modelNameProblems(body, isWork));
	return problems;
}

export function prBodyGuardDecision({ cwd, tool_name, tool_input }) {
	if (String(tool_name || "").toLowerCase() !== "bash") return null;
	const command = String(tool_input?.command || "");
	const prCandidate = /\bgh\b/.test(command) && /\bpr\b/.test(command);
	const commitCandidate = /\bgit\b/.test(command) && /\bcommit\b/.test(command);
	if (!prCandidate && !commitCandidate) return null;
	const scan = scanShell(command);
	const problems = [];
	const commitProblems = [];
	let orgs = null;
	const inWorkOrg = (owner) => {
		orgs ??= workOrgs();
		return owner !== null && orgs.has(owner);
	};
	INVOCATION.lastIndex = 0;
	for (let match = INVOCATION.exec(scan.visible); match; match = INVOCATION.exec(scan.visible)) {
		const start = match.index + match[0].length;
		const segment = { start: match.index, end: commandEnd(scan.visible, start) };
		const args = commandWords(scan.visible, start, segment.end);
		if (args.some((arg) => arg.text === "--help" || arg.text === "-h")) continue;
		const label = `gh pr ${match[1]}`;
		const dir = effectiveCwd(command, scan.visible, match.index, cwd || process.cwd());
		const body = bodyOf(command, scan, args, segment, dir);
		if (body.none) {
			if (match[1] !== "edit") problems.push(`${label}: no body given (--fill, --web or no --body/--body-file)`);
			continue;
		}
		if (body.problem) {
			problems.push(`${label}: ${body.problem}`);
			continue;
		}
		const repo = repoFlag(command, words(scan.visible, match.index, segment.end));
		const isWork = () => inWorkOrg(repo === null ? originOwner(dir) : githubOwner(repo));
		for (const problem of checkBody(body.text, dir, isWork)) problems.push(`${label}: ${problem}`);
	}
	COMMIT.lastIndex = 0;
	for (let match = COMMIT.exec(scan.visible); match; match = COMMIT.exec(scan.visible)) {
		const start = match.index + match[0].length;
		const segment = { start: match.index, end: commandEnd(scan.visible, start) };
		const globalsStart = start - /[ \t]+commit$/.exec(match[0])[0].length - match[1].length;
		const shellDir = effectiveCwd(command, scan.visible, match.index, cwd || process.cwd());
		const dir = gitDir(command, match[1], globalsStart, shellDir);
		const isWork = () => inWorkOrg(originOwner(dir));
		const args = commandWords(scan.visible, start, segment.end);
		for (const message of commitMessages(command, scan, args, segment, { git: dir, shell: shellDir, vars: pwdVars(command, shellDir) })) {
			if (COMMIT_ATTRIBUTION.test(message) || PROPER_CREDIT.test(message)) commitProblems.push("git commit: trailer or AI attribution in the message");
			commitProblems.push(...modelNameProblems(message, isWork).map((problem) => `git commit: ${problem}`));
		}
	}
	return problems.length || commitProblems.length ? deny(problems, [...new Set(commitProblems)]) : null;
}
