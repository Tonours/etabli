#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { registerUserPrompt } from "../../scripts/lib/ledger-auto-emit.mjs";
import { readHookInput } from "./workflow-router-lib.mjs";

const input = readHookInput();
const cwd = input.cwd || process.cwd();
const sessionId = input.session_id || input.sessionId || "";
const prompt = typeof input.prompt === "string" ? input.prompt : "";
const eventCli = join(cwd, "scripts", "workflow-event");

function writeEvent(ledgerPath, run, detail) {
	if (!existsSync(eventCli)) return false;
	const dir = dirname(dirname(ledgerPath));
	const result = spawnSync(
		eventCli,
		["--dir", dir, "append", run, "correction", JSON.stringify(detail)],
		{ cwd, encoding: "utf8", timeout: 4000 },
	);
	return result.status === 0;
}

try {
	registerUserPrompt(cwd, sessionId, "claude", prompt, writeEvent);
} catch {
}

process.exit(0);
