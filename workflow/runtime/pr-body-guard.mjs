import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const INVOCATION =
	/(?:^|[;&|(){}\n]|\b(?:then|do|else)[ \t])[ \t]*(?:(?:[A-Za-z_][A-Za-z0-9_]*=\S*|command|env|exec|time|nohup|rtk|proxy)[ \t]+)*gh(?:[ \t]+(?:-R\S+|-R[ \t]+\S+|--repo=\S+|--repo[ \t]+\S+))?[ \t]+pr[ \t]+(create|new|edit)(?=[ \t;&|)\n]|$)/g;
const CD = /(?:^|[;&|(){}\n])[ \t]*cd[ \t]+([^\s;&|()]+)/g;
const OUR_HEADINGS = ["## What", "## Why", "## How to test"];
const ATTRIBUTION = /generated with|co-authored-by:|claude\.ai\/code/i;
const MAX_BODY_BYTES = 1024 * 1024;
const REMEDIATION =
	"Write the body with the `pr` skill (workflow/pr-body-contract.md): one opening line, then ## What, ## Why, ## How to test, in English, and pass it with --body-file <file>.";

function deny(problems) {
	return {
		hookSpecificOutput: {
			hookEventName: "PreToolUse",
			permissionDecision: "deny",
			permissionDecisionReason: `PR body refused: ${problems.join("; ")}. ${REMEDIATION}`,
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

export function staticWord(raw) {
	let out = "";
	let i = 0;
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
				if (raw[k] === "$" || raw[k] === "`") return null;
				out += raw[k];
				k += 1;
			}
			if (k >= raw.length) return null;
			i = k + 1;
		} else if (ch === "\\") {
			out += raw[i + 1] ?? "";
			i += 2;
		} else if (ch === "$" || ch === "`") {
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

function markdownLines(body, { dropQuotesAndTables = false } = {}) {
	const lines = [];
	let fence = null;
	let comment = false;
	let previous = "";
	let indentedCode = false;
	for (const source of body.split(/\r?\n/)) {
		let raw = source;
		if (comment) {
			const close = raw.indexOf("-->");
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
		raw = raw.replace(/<!--[\s\S]*?-->/g, "");
		const open = raw.indexOf("<!--");
		if (open !== -1) {
			raw = raw.slice(0, open);
			comment = true;
		}
		if (dropQuotesAndTables && /^\s*[|>]/.test(raw)) continue;
		lines.push(raw.trim());
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
	const name = staticWord(source.raw);
	if (name === "-") return heredoc ? heredocText(heredoc) : { problem: "body read from a pipe cannot be checked" };
	if (!name) return { problem: "body file name is built at run time and cannot be checked" };
	if (cwd === null) return { problem: `body file ${name} sits behind a cd that cannot be resolved` };
	const path = resolve(cwd, expandHome(name));
	if (!existsSync(path)) return { problem: `body file ${name} not found from ${cwd}; pass an absolute path` };
	const stat = statSync(path);
	if (!stat.isFile()) return { problem: `body file ${name} is not a regular file` };
	if (stat.size > MAX_BODY_BYTES) return { problem: `body file ${name} is over 1 MiB` };
	return { text: readFileSync(path, "utf8") };
}

function checkBody(body, cwd) {
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
	return problems;
}

export function prBodyGuardDecision({ cwd, tool_name, tool_input }) {
	if (String(tool_name || "").toLowerCase() !== "bash") return null;
	const command = String(tool_input?.command || "");
	if (!/\bgh\b/.test(command) || !/\bpr\b/.test(command)) return null;
	const scan = scanShell(command);
	const problems = [];
	INVOCATION.lastIndex = 0;
	for (let match = INVOCATION.exec(scan.visible); match; match = INVOCATION.exec(scan.visible)) {
		const start = match.index + match[0].length;
		const stop = /[;&|)\n]/.exec(scan.visible.slice(start));
		const segment = { start: match.index, end: stop ? start + stop.index : command.length };
		const args = words(scan.visible, start, segment.end);
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
		for (const problem of checkBody(body.text, dir)) problems.push(`${label}: ${problem}`);
	}
	return problems.length ? deny(problems) : null;
}
