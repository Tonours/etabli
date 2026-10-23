import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

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
	[".sh", "shell"],
	[".bash", "shell"],
	[".zsh", "shell"],
	[".sql", "sql"],
	[".lua", "lua"],
]);
const DASH_FAMILIES = new Set(["sql", "lua"]);
const MULTILINE_STRING_FAMILIES = new Set(["shell", "sql"]);

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
	/(eslint-disable|eslint-enable|@ts-expect-error|@ts-ignore|@ts-nocheck|@ts-check|biome-ignore|prettier-ignore|stylelint-disable|c8 ignore|istanbul ignore|v8 ignore|@jsxImportSource|^\/\/\/\s*<reference\b|^\/\/go:[a-z]|type:\s*ignore|\bnoqa\b|\bshellcheck\s+(disable|enable|source|shell)=)/;

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

const REGEX_LITERAL_PREFIX = /(^|[=(,:[!&|?{;+]|=>|(?:^|[^.\w$])(?:return|throw|typeof|case|yield|await|else|void|delete))\s*$/;
const MAX_NESTING = 64;

function normalizeComment(text) {
	return String(text).replace(/\s+/g, " ").trim();
}

function lineCommentAt(source, index, family) {
	const char = source[index];
	if (family === "clike") return char === "/" && source[index + 1] === "/" && source[index - 1] !== ":";
	if (DASH_FAMILIES.has(family)) return char === "-" && source[index + 1] === "-";
	if (family === "python") return char === "#";
	if (family === "shell") return char === "#" && (index === 0 || /\s/.test(source[index - 1]));
	return false;
}

function blockEnd(source, index, opener, closer, nested) {
	let depth = 0;
	let cursor = index;
	while (cursor < source.length) {
		if (source.startsWith(closer, cursor)) {
			depth -= 1;
			cursor += closer.length;
			if (depth === 0 || !nested) return cursor;
			continue;
		}
		if (source.startsWith(opener, cursor) && (nested || depth === 0)) {
			depth += 1;
			cursor += opener.length;
			continue;
		}
		cursor += 1;
	}
	return -1;
}

function longBracketAt(source, index) {
	const match = /^\[(=*)\[/.exec(source.slice(index, index + 64));
	if (!match) return -1;
	const end = source.indexOf(`]${match[1]}]`, index + match[0].length);
	return end === -1 ? -1 : end + match[1].length + 2;
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
			while (cursor < source.length && /[a-z]/.test(source[cursor])) cursor += 1;
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
		const sqlEscaped = family === "sql" && quote === "'" && /[Ee]/.test(source[index - 1] ?? "") && !/\w/.test(source[index - 2] ?? "");
		const escapes = ansiC || sqlEscaped || !((family === "shell" && quote === "'") || family === "sql");
		let cursor = index + delimiter.length;
		while (cursor < source.length) {
			if (escapes && source[cursor] === "\\") {
				cursor += 2;
				continue;
			}
			if (source.startsWith(delimiter, cursor)) return cursor + delimiter.length;
			const substitution = family === "shell" && quote === '"' ? skipSubstitution(cursor) : -1;
			if (substitution !== -1) {
				cursor = substitution;
				continue;
			}
			if (quote === "`" && family === "clike" && source.startsWith("${", cursor)) {
				cursor = scanNested(cursor + 2, "}");
				continue;
			}
			if (source[cursor] === "\n" && !spansLines) return cursor;
			cursor += 1;
		}
		return cursor;
	};

	const heredocEnd = (start, word, indent) => {
		let cursor = start;
		while (cursor < source.length) {
			const end = source.indexOf("\n", cursor);
			const stop = end === -1 ? source.length : end;
			const line = source.slice(cursor, stop);
			if ((indent ? line.replace(indent, "") : line) === word) return { body: cursor, stop };
			cursor = stop + 1;
		}
		return null;
	};

	const skipHeredoc = (start, { word, indent, expands }) => {
		const end = heredocEnd(start, word, indent);
		if (!end) return start;
		let cursor = start;
		while (expands && cursor < end.body) {
			if (source[cursor] === "\\") cursor += 2;
			else cursor = Math.max(skipSubstitution(cursor), cursor + 1);
		}
		return Math.max(cursor, end.stop);
	};

	let nesting = 0;
	let capped = false;
	const scanNested = (start, closer) => {
		if (nesting >= MAX_NESTING) {
			capped = true;
			return source.length;
		}
		nesting += 1;
		const end = scanCode(start, closer);
		nesting -= 1;
		return end;
	};

	const skipSubstitution = (cursor) => {
		if (source.startsWith("$(", cursor)) return scanNested(cursor + 2, ")");
		if (source[cursor] === "`") return scanNested(cursor + 1, "`");
		return -1;
	};

	const pushBlock = (start, stop) => {
		const block = source.slice(start, stop);
		if (isExemptComment(block)) return;
		for (const chunk of block.split("\n")) push(chunk);
	};

	const scanCode = (start, closer) => {
		let codeTail = "";
		let depth = 0;
		const opener = { ")": "(", "}": "{" }[closer];
		let index = start;
		const heredocs = [];
		const appendCode = (text) => {
			if (codeTail.length > 128) codeTail = codeTail.slice(-32);
			if (!/^\s$/.test(text) || !/\s$/.test(codeTail)) codeTail += text;
		};
		while (index < source.length) {
			const char = source[index];
			if (char === "\n") {
				appendCode(" ");
				index += 1;
				for (const heredoc of heredocs.splice(0)) index = skipHeredoc(index, heredoc);
				continue;
			}
			if (family === "shell" && char === "\\") {
				appendCode("E");
				index += 2;
				continue;
			}
			if (family === "shell" && source.startsWith("<<", index) && source[index + 2] !== "<") {
				const match = /^<<(-?)[ \t]*(?:(['"])([^'"\s]+)\2|([^\s'"<>;|&()]+))/.exec(source.slice(index, index + 200));
				if (match) {
					heredocs.push({ word: match[3] ?? match[4], indent: match[1] === "-" ? /^\t+/ : null, expands: !match[2] });
					appendCode("H");
					index += match[0].length;
					continue;
				}
			}
			if (closer === "`" && char === "`") return index + 1;
			if (family === "shell" && source.startsWith("$(", index)) {
				index = skipSubstitution(index);
				appendCode("S");
				continue;
			}
			if (opener && char === opener) depth += 1;
			if (opener && char === closer) {
				if (depth === 0) return index + 1;
				if (depth > 0) depth -= 1;
			}
			if ((family === "clike" || family === "sql") && source.startsWith("/*", index)) {
				const stop = blockEnd(source, index, "/*", "*/", family === "sql");
				pushBlock(index, stop === -1 ? source.length : stop);
				appendCode(" ");
				index = stop === -1 ? source.length : stop;
				continue;
			}
			if (family === "lua" && source.startsWith("--[", index)) {
				const stop = longBracketAt(source, index + 2);
				if (stop !== -1) {
					pushBlock(index, stop);
					appendCode(" ");
					index = stop;
					continue;
				}
			}
			if (family === "sql" && char === "$" && !/[\p{L}\p{N}_$]/u.test(source[index - 1] ?? "")) {
				const tag = /^\$(?:[\p{L}_][\p{L}\p{N}_]*)?\$/u.exec(source.slice(index, index + 64))?.[0];
				const end = tag ? source.indexOf(tag, index + tag.length) : -1;
				if (end !== -1) {
					index = end + tag.length;
					appendCode("S");
					continue;
				}
			}
			if (family === "lua" && char === "[") {
				const stop = longBracketAt(source, index);
				if (stop !== -1) {
					index = stop;
					appendCode("S");
					continue;
				}
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
				appendCode("S");
				continue;
			}
			if (family === "clike" && char === "/" && REGEX_LITERAL_PREFIX.test(codeTail)) {
				const stop = skipRegexLiteral(source, index);
				if (stop !== -1) {
					index = stop;
					appendCode("RE");
					continue;
				}
			}
			appendCode(char);
			index += 1;
		}
		return index;
	};

	scanCode(0, null);
	return capped ? null : found;
}

export function addedCommentLines(previousText, nextText, family) {
	const previous = collectCommentLines(previousText, family);
	const next = collectCommentLines(nextText, family);
	if (previous === null || next === null) return [];
	const remaining = new Map();
	for (const comment of previous) {
		remaining.set(comment, (remaining.get(comment) ?? 0) + 1);
	}
	return next.filter((comment) => {
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

	if (toolName === "Write") {
		const content = writeContent(toolInput);
		if (content == null) return null;
		const added = addedCommentLines(
			previousFileText(cwd, filePath),
			content,
			family,
		);
		if (added.length === 0) return null;
		return deny(denyReason(filePath, added));
	}

	const pairs = editPairs(toolInput);
	const texts = editedFileTexts(previousFileText(cwd, filePath), pairs);
	const added = texts
		? addedCommentLines(texts.previous, texts.next, family)
		: pairs.flatMap((pair) => addedCommentLines(pair.oldStr, pair.newStr, family));
	if (added.length === 0) return null;
	return deny(denyReason(filePath, added));
}
