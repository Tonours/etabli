#!/usr/bin/env node
import { readFileSync } from "node:fs";

function commandForPolicy(command) {
	return command.replace(/^rtk\s+/, "");
}

function readInput() {
	try {
		return JSON.parse(readFileSync(0, "utf8") || "{}") || {};
	} catch {
		return {};
	}
}

function deny(reason) {
	process.stdout.write(
		`${JSON.stringify({
			hookSpecificOutput: {
				hookEventName: "PreToolUse",
				permissionDecision: "deny",
				permissionDecisionReason: reason,
			},
		})}\n`,
	);
}

const input = readInput();
const toolName = input.tool_name || input.toolName || "";
const toolInput = input.tool_input || input.input || {};
const command = String(toolInput.command || toolInput.cmd || "");

if (toolName === "Bash" && command !== "") {
	let isReadOnlyBashCommand;
	let recordGuardDenial;
	try {
		({ isReadOnlyBashCommand } = await import("./workflow-router-lib.mjs"));
		({ recordGuardDenial } = await import("../../workflow/runtime/guard-journal.mjs"));
	} catch (error) {
		deny(
			`read-only-agent-guard failed (${error?.message ?? error}); Bash stays blocked for this read-only agent. Repair the Etabli install with scripts/deploy-agent-workflow --apply from the etabli checkout.`,
		);
		process.exit(0);
	}
	let readOnly = false;
	try {
		readOnly = isReadOnlyBashCommand(commandForPolicy(command));
	} catch {
		readOnly = false;
	}
	if (!readOnly) {
		try {
			recordGuardDenial({
				cwd: input.cwd,
				harness: "claude",
				guard: "read-only-agent-guard",
				pattern: "non-read-only-bash",
				target: "Bash",
				tool: "Bash",
			});
		} catch {}
		deny(
			"This agent is read-only. Use Read/Grep/Glob or a proven read-only Bash/Git command; return to the parent for mutations and validation runs.",
		);
	}
}
