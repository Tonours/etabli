import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const GH_PR = /(?:^|[;&|(\n]|\$\()[ \t]*(?:[A-Za-z_][A-Za-z0-9_]*=\S*[ \t]+)*(?:rtk[ \t]+)?gh[ \t]+pr[ \t]+(create|new|edit)\b/;
const BODY_FILE = /[ \t](?:--body-file|-F)(?:=|[ \t]+)(?:'([^']*)'|"([^"]*)"|(\S+))/;
const INLINE_BODY = /[ \t](?:--body|-b)(?:=|[ \t])/;
const OUR_HEADINGS = ["## What", "## Why", "## How to test"];
const ATTRIBUTION = /generated with|co-authored-by:|claude\.ai\/code/i;
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
		if (!existsSync(dir)) continue;
		const name = readdirSync(dir).find((file) => file.toLowerCase() === "pull_request_template.md");
		if (!name) continue;
		return readFileSync(join(dir, name), "utf8")
			.replace(/<!--[\s\S]*?-->/g, "")
			.split("\n")
			.map((line) => line.trim())
			.filter((line) => /^## \S/.test(line));
	}
	return [];
}

function hasHeading(body, heading) {
	const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	return new RegExp(`(?:^|\\n|\\\\n)[ \\t]*${escaped}[ \\t]*(?=$|\\r?\\n|\\\\n)`).test(body);
}

function proseOutsideCode(body) {
	let fenced = false;
	const kept = [];
	for (const line of body.split("\n")) {
		if (/^\s*(```|~~~)/.test(line)) {
			fenced = !fenced;
			continue;
		}
		if (fenced || /^\s*[|>]/.test(line)) continue;
		kept.push(line.replace(/`[^`]*`/g, ""));
	}
	return kept.join("\n");
}

export function prBodyGuardDecision({ cwd, tool_name, tool_input }) {
	if (String(tool_name || "").toLowerCase() !== "bash") return null;
	const command = String(tool_input?.command || "");
	const match = GH_PR.exec(command);
	if (!match) return null;
	const rest = command.slice(match.index + match[0].length);
	const fileMatch = BODY_FILE.exec(rest);
	const inline = INLINE_BODY.test(rest);
	if (!fileMatch && !inline) {
		if (match[1] === "edit") return null;
		return deny(["no body given (--fill, --web or no --body/--body-file)"]);
	}
	const workdir = cwd || process.cwd();
	let body = command;
	const file = fileMatch && (fileMatch[1] ?? fileMatch[2] ?? fileMatch[3]);
	if (file && file !== "-") {
		const path = resolve(workdir, file.replace(/^~(?=\/)/, process.env.HOME || "~"));
		if (!existsSync(path)) return deny([`body file ${file} not found from ${workdir}; pass an absolute path`]);
		body = readFileSync(path, "utf8");
	}

	const problems = [];
	const template = templateHeadings(workdir);
	const templateCovers =
		template.some((h) => /\bwhat\b|chang/i.test(h)) && template.some((h) => /test|verif|validat/i.test(h));
	const required = [...template, ...(templateCovers ? [] : OUR_HEADINGS)];
	const missing = required.filter((heading) => !hasHeading(body, heading));
	if (missing.length) problems.push(`missing ${missing.join(", ")}`);
	if (ATTRIBUTION.test(body)) problems.push("AI attribution in the body");
	const nonAscii = proseOutsideCode(body).match(/[^\x09\x0a\x0d\x20-\x7e]/g);
	if (nonAscii) problems.push(`non-ASCII outside code, tables and quotes: ${[...new Set(nonAscii)].join(" ")}`);
	return problems.length ? deny(problems) : null;
}
