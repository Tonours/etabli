import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { recordGuardDenial } from "./guard-journal.mjs";

function normalizeToolName(toolName) {
	const raw = String(toolName || "");
	const lower = raw.toLowerCase();
	if (lower === "write") return "Write";
	if (lower === "edit") return "Edit";
	if (lower === "multiedit") return "MultiEdit";
	if (
		lower === "bash" ||
		lower === "shell" ||
		lower === "run_terminal_command"
	) {
		return "Bash";
	}
	return raw;
}

const CODE_EXTENSIONS = new Set([
	".ts",
	".tsx",
	".js",
	".jsx",
	".mjs",
	".cjs",
	".mts",
	".cts",
	".py",
	".rb",
	".go",
	".rs",
	".java",
	".kt",
	".kts",
	".swift",
	".c",
	".h",
	".cpp",
	".cc",
	".cxx",
	".hpp",
	".hh",
	".cs",
	".php",
	".sh",
	".bash",
	".zsh",
	".lua",
	".sql",
	".scala",
	".vue",
	".svelte",
	".astro",
	".css",
	".sass",
	".scss",
	".less",
]);

const HASH_EXTENSIONS = new Set([".py", ".rb", ".sh", ".bash", ".zsh"]);
const DASH_EXTENSIONS = new Set([".lua", ".sql"]);

function extname(filePath) {
	const base = String(filePath || "")
		.split(/[\\/]/)
		.pop();
	if (!base) return "";
	const dot = base.lastIndexOf(".");
	if (dot <= 0) return "";
	return base.slice(dot).toLowerCase();
}

export function isGuardedCodeFile(filePath) {
	return CODE_EXTENSIONS.has(extname(filePath));
}

export function commentFamilyFor(filePath) {
	const ext = extname(filePath);
	if (HASH_EXTENSIONS.has(ext)) return "hash";
	if (DASH_EXTENSIONS.has(ext)) return "dash";
	return "clike";
}

const TOOL_DIRECTIVE =
	/(eslint-disable|eslint-enable|@ts-expect-error|@ts-ignore|@ts-nocheck|biome-ignore|prettier-ignore|stylelint-disable|c8 ignore|istanbul ignore|v8 ignore|@jsxImportSource)/;

function isExemptComment(text) {
	const trimmed = String(text || "").trim();
	if (/^#!/.test(trimmed)) return true;
	if (TOOL_DIRECTIVE.test(trimmed)) return true;
	if (/spdx-license-identifier/i.test(trimmed)) return true;
	if (/\bcopyright\b/i.test(trimmed)) return true;
	if (
		/\blicen[sc]e\b/i.test(trimmed) &&
		/\b(mit|apache|bsd|isc|gpl|mpl)\b/i.test(trimmed)
	) {
		return true;
	}
	return false;
}

function stripStrings(text, family) {
	let out = "";
	let i = 0;
	const n = text.length;
	while (i < n) {
		const c = text[i];
		const quote =
			c === "'" || c === '"' || (family === "clike" && c === "`") ? c : "";
		if (!quote) {
			out += c;
			i += 1;
			continue;
		}
		out += quote;
		i += 1;
		while (i < n) {
			const d = text[i];
			if (d === "\\") {
				out += "  ";
				i += 2;
				continue;
			}
			if (d === quote) {
				out += quote;
				i += 1;
				break;
			}
			if (d === "\n" && quote !== "`") {
				break;
			}
			out += d === "\n" ? "\n" : " ";
			i += 1;
		}
	}
	return out;
}

const REGEX_LITERAL_PREFIX = /[=(,:[!&|?{;+]\s*$/;

function stripRegexLiterals(line) {
	let out = "";
	let index = 0;

	while (index < line.length) {
		const opensComment = line[index + 1] === "/" || line[index + 1] === "*";
		if (line[index] !== "/" || opensComment || !REGEX_LITERAL_PREFIX.test(out)) {
			out += line[index];
			index += 1;
			continue;
		}

		let cursor = index + 1;
		let inClass = false;
		let closed = false;
		while (cursor < line.length) {
			const char = line[cursor];
			if (char === "\\") {
				cursor += 2;
				continue;
			}
			if (char === "[") inClass = true;
			else if (char === "]") inClass = false;
			else if (char === "/" && !inClass) {
				closed = true;
				break;
			}
			cursor += 1;
		}

		if (!closed) {
			out += line.slice(index);
			break;
		}

		out += "RE";
		index = cursor + 1;
		while (index < line.length && /[dgimsuvy]/.test(line[index])) index += 1;
	}

	return out;
}

function stripLiterals(text, family) {
	const source = family === "clike" ? text.split("\n").map(stripRegexLiterals).join("\n") : text;
	return stripStrings(source, family);
}

function lineCommentStart(line) {
	const match = /(^|[^:])\/\//.exec(line);
	return match ? match.index + match[1].length : -1;
}

function normalizeComment(text) {
	return String(text).replace(/\s+/g, " ").trim();
}

export function collectCommentLines(text, family) {
	const stripped = stripLiterals(String(text || ""), family);
	const lines = stripped.split("\n");
	const found = [];
	let inBlock = false;

	for (let idx = 0; idx < lines.length; idx += 1) {
		let line = lines[idx];
		if (inBlock) {
			const end = line.indexOf("*/");
			if (end === -1) {
				if (line.trim() && !isExemptComment(line)) {
					found.push(normalizeComment(line));
				}
				continue;
			}
			const chunk = line.slice(0, end + 2);
			if (chunk.trim() && !isExemptComment(chunk)) {
				found.push(normalizeComment(chunk));
			}
			line = line.slice(end + 2);
			inBlock = false;
		}

		if (family === "clike") {
			const blockStart = line.indexOf("/*");
			const lineStart = lineCommentStart(line);
			if (blockStart !== -1 && (lineStart === -1 || blockStart < lineStart)) {
				const end = line.indexOf("*/", blockStart + 2);
				const chunk =
					end === -1
						? line.slice(blockStart)
						: line.slice(blockStart, end + 2);
				if (chunk.trim() && !isExemptComment(chunk)) {
					found.push(normalizeComment(chunk));
				}
				if (end === -1) inBlock = true;
				continue;
			}
			if (lineStart !== -1) {
				const chunk = line.slice(lineStart);
				if (chunk.trim() && !isExemptComment(chunk)) {
					found.push(normalizeComment(chunk));
				}
			}
			continue;
		}

		if (family === "hash") {
			const match = /(^|\s)#/.exec(line);
			if (!match) continue;
			const hash = match.index + match[1].length;
			const chunk = line.slice(hash);
			if (idx === 0 && /^#!/.test(chunk.trim())) continue;
			if (chunk.trim() && !isExemptComment(chunk)) {
				found.push(normalizeComment(chunk));
			}
			continue;
		}

		const dash = line.indexOf("--");
		if (dash === -1) continue;
		const chunk = line.slice(dash);
		if (chunk.trim() && !isExemptComment(chunk)) {
			found.push(normalizeComment(chunk));
		}
	}

	return found;
}

export function addedCommentLines(previousText, nextText, family) {
	const remaining = new Map();
	for (const comment of collectCommentLines(previousText, family)) {
		remaining.set(comment, (remaining.get(comment) ?? 0) + 1);
	}
	return collectCommentLines(nextText, family).filter((comment) => {
		const count = remaining.get(comment) ?? 0;
		if (count === 0) return true;
		remaining.set(comment, count - 1);
		return false;
	});
}

function toolFilePath(toolInput) {
	return String(
		toolInput.file_path || toolInput.path || toolInput.filePath || "",
	);
}

function writeContent(toolInput) {
	const content =
		toolInput.content ??
		toolInput.contents ??
		toolInput.new_string ??
		toolInput.newString;
	return typeof content === "string" ? content : null;
}

function editPairs(toolInput) {
	const edits = Array.isArray(toolInput.edits) ? toolInput.edits : [toolInput];
	return edits.map((edit) => ({
		oldStr: String(edit?.old_string ?? edit?.oldString ?? edit?.oldText ?? ""),
		newStr: String(edit?.new_string ?? edit?.newString ?? edit?.newText ?? ""),
	}));
}

function previousFileText(cwd, filePath) {
	const abs = resolve(cwd || process.cwd(), filePath);
	if (!existsSync(abs)) return "";
	try {
		return readFileSync(abs, "utf8");
	} catch {
		return "";
	}
}

function editedFileTexts(fileText, pairs) {
	let next = fileText;
	for (const { oldStr, newStr } of pairs) {
		if (!oldStr || !next.includes(oldStr)) return null;
		next = next.replace(oldStr, () => newStr);
	}
	return { previous: fileText, next };
}

function deny(reason) {
	return {
		hookSpecificOutput: {
			hookEventName: "PreToolUse",
			permissionDecision: "deny",
			permissionDecisionReason: reason,
		},
	};
}

function denyReason(filePath, comments) {
	const sample = comments[0] || "//";
	return `no-comments: ${filePath} adds a code comment (${sample}). Cut comments that restate the code (implementation-loop 12b). Rewrite without the comment.`;
}

export function noCommentsGuardDecision(event) {
	const toolName = normalizeToolName(event.tool_name || event.toolName);
	if (toolName !== "Write" && toolName !== "Edit" && toolName !== "MultiEdit") {
		return null;
	}

	const toolInput = event.tool_input || event.input || {};
	const filePath = toolFilePath(toolInput);
	if (!isGuardedCodeFile(filePath)) return null;

	const family = commentFamilyFor(filePath);
	const cwd = event.cwd || process.cwd();
	const record = () =>
		recordGuardDenial({ cwd, harness: event.harness, guard: "no-comments", pattern: "code-comment-added", target: filePath, tool: toolName });

	if (toolName === "Write") {
		const content = writeContent(toolInput);
		if (content == null) return null;
		const added = addedCommentLines(
			previousFileText(cwd, filePath),
			content,
			family,
		);
		if (added.length === 0) return null;
		record();
		return deny(denyReason(filePath, added));
	}

	const pairs = editPairs(toolInput);
	const texts = editedFileTexts(previousFileText(cwd, filePath), pairs);
	const added = texts
		? addedCommentLines(texts.previous, texts.next, family)
		: pairs.flatMap((pair) => addedCommentLines(pair.oldStr, pair.newStr, family));
	if (added.length === 0) return null;
	record();
	return deny(denyReason(filePath, added));
}
