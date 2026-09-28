#!/usr/bin/env node
import { join } from "node:path";
import { pickPrimaryActiveLedger } from "../../scripts/lib/ledger-auto-emit.mjs";
import { buildHandoff, markdown, planHeadline } from "../../scripts/lib/session-handoff.mjs";
import { COMPACT_INSTRUCTIONS, readHookInput } from "./workflow-router-lib.mjs";

const orNull = (read) => {
	try {
		return read();
	} catch {
		return null;
	}
};

const cwd = readHookInput().cwd;
if (typeof cwd === "string" && cwd !== "") {
	const run = orNull(() => pickPrimaryActiveLedger(cwd)?.run);
	const state = [
		orNull(() => planHeadline(cwd)),
		run ? orNull(() => markdown(buildHandoff({ repo: cwd, workflowDir: join(cwd, ".workflow"), run }))) : null,
	].filter(Boolean);
	if (state.length > 0) {
		const additionalContext = [COMPACT_INSTRUCTIONS, ...state].join("\n\n");
		process.stdout.write(`${JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext } })}\n`);
	}
}
