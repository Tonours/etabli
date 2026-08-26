/**
 * Web search tools (Brave Search API)
 *
 * Exposes the local brave-search skill scripts as real LLM tools, so any
 * model can call them reliably instead of pattern-matching a skill folder.
 * Requires: BRAVE_API_KEY in env, skill installed at
 * ~/.pi/agent/skills/brave-search (search.js + content.js).
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const execFileAsync = promisify(execFile);
const SKILL_DIR = join(homedir(), ".pi/agent/skills/brave-search");
const MAX_OUTPUT_CHARS = 24_000;

function run(script: string, args: string[]): Promise<string> {
	return execFileAsync(script, args, {
		cwd: SKILL_DIR,
		timeout: 60_000,
		maxBuffer: 8 * 1024 * 1024,
		env: process.env,
	}).then(({ stdout }) => stdout);
}

function clip(text: string): string {
	if (text.length <= MAX_OUTPUT_CHARS) return text;
	return `${text.slice(0, MAX_OUTPUT_CHARS)}\n\n[... truncated ${text.length - MAX_OUTPUT_CHARS} chars]`;
}

export default function webSearchExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "web_search",
		label: "Web Search",
		description:
			"Search the web with Brave Search. Returns titles, links, ages and snippets for the top results. Use for current events, product releases, documentation lookups, or any fact you are unsure about.",
		parameters: Type.Object({
			query: Type.String({
				description: "Search query (natural language or keywords)",
			}),
			count: Type.Optional(
				Type.Number({
					description: "Number of results (1-20, default 5)",
					minimum: 1,
					maximum: 20,
				}),
			),
		}),
		execute: async (_toolCallId, params) => {
			const args = [String(params.query)];
			if (params.count) args.push("-n", String(params.count));
			try {
				const out = await run("./search.js", args);
				return {
					content: [{ type: "text", text: clip(out) }],
					details: { query: String(params.query) },
				};
			} catch (err) {
				const msg = err instanceof Error ? err.message : String(err);
				const hint = msg.includes("BRAVE_API_KEY")
					? " (BRAVE_API_KEY missing from environment)"
					: "";
				return {
					content: [{ type: "text", text: `web_search failed:${hint} ${msg}` }],
					details: { query: String(params.query) },
				};
			}
		},
	});

	pi.registerTool({
		name: "web_fetch",
		label: "Web Fetch",
		description:
			"Fetch a web page and return its readable content as markdown. Use after web_search to read a specific result, or for any public URL.",
		parameters: Type.Object({
			url: Type.String({ description: "Full URL including https://" }),
		}),
		execute: async (_toolCallId, params) => {
			try {
				const out = await run("./content.js", [String(params.url)]);
				return {
					content: [{ type: "text", text: clip(out) }],
					details: { url: String(params.url) },
				};
			} catch (err) {
				const msg = err instanceof Error ? err.message : String(err);
				return {
					content: [{ type: "text", text: `web_fetch failed: ${msg}` }],
					details: { url: String(params.url) },
				};
			}
		},
	});
}
