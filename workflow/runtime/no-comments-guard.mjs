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

const COMMENT_FAMILIES = new Map([
	[".py", "python"],
	[".rb", "ruby"],
	[".sh", "shell"],
	[".bash", "shell"],
	[".zsh", "shell"],
	[".sql", "sql"],
	[".lua", "lua"],
]);
const HASH_FAMILIES = new Set(["python", "ruby"]);
const DASH_FAMILIES = new Set(["sql", "lua"]);
const MULTILINE_STRING_FAMILIES = new Set(["ruby", "shell", "sql"]);

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
	return COMMENT_FAMILIES.get(extname(filePath)) ?? "clike";
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

const REGEX_LITERAL_PREFIX = /[=(,:[!&|?{;+]\s*$/;

function normalizeComment(text) {
	return String(text).replace(/\s+/g, " ").trim();
}

function lineCommentAt(source, index, family) {
	const char = source[index];
	if (family === "clike") return char === "/" && source[index + 1] === "/" && source[index - 1] !== ":";
	if (DASH_FAMILIES.has(family)) return char === "-" && source[index + 1] === "-";
	if (HASH_FAMILIES.has(family)) return char === "#";
	if (family === "shell") return char === "#" && (index === 0 || /\s/.test(source[index - 1]));
	return false;
}

function skipRegexLiteral(source, index) {
	let cursor = index + 1;
	let inClass = false;
	while (cursor < source.length && source[cursor] !== "\n") {
		const char = source[cursor];
		if (char === "\\") {
			cursor += 2;
			continue;
		}
		if (char === "[") inClass = true;
		else if (char === "]") inClass = false;
		else if (char === "/" && !inClass) {
			cursor += 1;
			while (cursor < source.length && /[dgimsuvy]/.test(source[cursor])) cursor += 1;
			return cursor;
		}
		cursor += 1;
	}
	return -1;
}

export function collectCommentLines(text, family) {
	const source = String(text || "");
	const found = [];
	const push = (chunk) => {
		if (chunk.trim() && !isExemptComment(chunk)) found.push(normalizeComment(chunk));
	};

	const skipString = (index) => {
		const quote = source[index];
		const triple = family === "python" && source.startsWith(quote.repeat(3), index);
		const delimiter = triple ? quote.repeat(3) : quote;
		const spansLines = triple || quote === "`" || MULTILINE_STRING_FAMILIES.has(family);
		const ansiC = family === "shell" && quote === "'" && source[index - 1] === "$";
		const escapes = ansiC || !((family === "shell" && quote === "'") || family === "sql");
		let cursor = index + delimiter.length;
		while (cursor < source.length) {
			if (escapes && source[cursor] === "\\") {
				cursor += 2;
				continue;
			}
			if (source.startsWith(delimiter, cursor)) return cursor + delimiter.length;
			if (family === "shell" && quote === '"' && source.startsWith("$(", cursor)) {
				cursor = scanCode(cursor + 2, true);
				continue;
			}
			if (source[cursor] === "\n" && !spansLines) return cursor;
			cursor += 1;
		}
		return cursor;
	};

	const scanCode = (start, untilParen) => {
		let lineCode = "";
		let depth = 0;
		let index = start;
		while (index < source.length) {
			const char = source[index];
			if (char === "\n") {
				lineCode = "";
				index += 1;
				continue;
			}
			if (untilParen && char === "(") depth += 1;
			if (untilParen && char === ")") {
				if (depth === 0) return index + 1;
				depth -= 1;
			}
			if (family === "clike" && char === "/" && source[index + 1] === "*") {
				const end = source.indexOf("*/", index + 2);
				const stop = end === -1 ? source.length : end + 2;
				for (const chunk of source.slice(index, stop).split("\n")) push(chunk);
				lineCode += " ";
				index = stop;
				continue;
			}
			if (lineCommentAt(source, index, family)) {
				const end = source.indexOf("\n", index);
				const stop = end === -1 ? source.length : end;
				push(source.slice(index, stop));
				index = stop;
				continue;
			}
			if (char === "'" || char === '"' || (family === "clike" && char === "`")) {
				index = skipString(index);
				lineCode += "S";
				continue;
			}
			if (family === "clike" && char === "/" && REGEX_LITERAL_PREFIX.test(lineCode)) {
				const stop = skipRegexLiteral(source, index);
				if (stop !== -1) {
					index = stop;
					lineCode += "RE";
					continue;
				}
			}
			lineCode += char;
			index += 1;
		}
		return index;
	};

	scanCode(0, false);
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
		replaceAll: edit?.replace_all === true || edit?.replaceAll === true,
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
	for (const { oldStr, newStr, replaceAll } of pairs) {
		if (!oldStr || !next.includes(oldStr)) return null;
		next = replaceAll ? next.split(oldStr).join(newStr) : next.replace(oldStr, () => newStr);
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
