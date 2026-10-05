#!/usr/bin/env node
import {
	isReadOnlyBashCommand,
	readHookInput,
} from "./workflow-router-lib.mjs";
import { recordGuardDenial } from "../../workflow/runtime/guard-journal.mjs";

function commandForPolicy(command) {
	return command.replace(/^rtk\s+/, "");
}

const input = readHookInput();
const toolName = input.tool_name || input.toolName || "";

if (toolName === "Bash") {
	const toolInput = input.tool_input || input.input || {};
	const command = String(toolInput.command || toolInput.cmd || "");

	if (command !== "" && !isReadOnlyBashCommand(commandForPolicy(command))) {
		recordGuardDenial({
			cwd: input.cwd,
			harness: "claude",
			guard: "read-only-agent-guard",
			pattern: "non-read-only-bash",
			target: "Bash",
			tool: "Bash",
		});
		process.stdout.write(
			`${JSON.stringify({
				hookSpecificOutput: {
					hookEventName: "PreToolUse",
					permissionDecision: "deny",
					permissionDecisionReason:
						"This agent is read-only. Use Read/Grep/Glob or a proven read-only Bash/Git command; return to the parent for mutations and validation runs.",
				},
			})}\n`,
		);
	}
}
