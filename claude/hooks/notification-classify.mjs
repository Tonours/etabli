#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { pickPrimaryActiveLedger } from "../../scripts/lib/ledger-auto-emit.mjs";
import { readHookInput } from "./workflow-router-lib.mjs";

const CONSENT_CLASSES = {
	permission_prompt: "permission_request",
	idle_prompt: "input_request",
};

const input = readHookInput();
const notificationType = String(
	input.notification_type || input.notificationType || "",
);
const consentClass = CONSENT_CLASSES[notificationType];
if (!consentClass) process.exit(0);

const cwd = input.cwd || process.cwd();
const eventCli = join(cwd, "scripts", "workflow-event");

let ledger = null;
try {
	ledger = pickPrimaryActiveLedger(cwd);
} catch {
	process.exit(0);
}
if (!ledger) process.exit(0);
if (!existsSync(eventCli)) process.exit(0);

const detail = {
	category: "notification",
	consent_class: consentClass,
	decision: "requested",
	target: notificationType,
};
const dir = dirname(dirname(ledger.path));
spawnSync(
	eventCli,
	["--dir", dir, "append", ledger.run, "human_checkpoint", JSON.stringify(detail)],
	{ cwd, encoding: "utf8", timeout: 4000 },
);
process.exit(0);
