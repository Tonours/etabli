#!/usr/bin/env bun
import { spawn } from "node:child_process";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
if (process.env.FAKE_PI_ARGV_FILE) writeFileSync(process.env.FAKE_PI_ARGV_FILE, JSON.stringify({ args, agentDir: process.env.PI_CODING_AGENT_DIR }));
const task = (args.at(-1) ?? "").replace(/^Task: /, "");
const mode = task.split(" ")[0];
spawn("sleep", ["600"], { stdio: "ignore" });
const say = (text: string, extra: Record<string, unknown> = {}) =>
	console.log(JSON.stringify({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text }], stopReason: "stop", ...extra } }));
const hang = () => setInterval(() => undefined, 1000);

if (mode === "success") {
	say(`done in ${process.cwd()}`);
	process.exit(0);
} else if (mode === "write") {
	writeFileSync(join(process.cwd(), "result.txt"), "written by child\n");
	say("wrote result.txt");
	process.exit(0);
} else if (mode === "linger") {
	spawn("sleep", ["600"], { stdio: "inherit" });
	say("finished, descendant still holds stdout");
	process.exit(0);
} else if (mode === "fail") {
	console.error("child failure detail");
	process.exit(3);
} else if (mode === "provider-error") {
	say("", { stopReason: "error", errorMessage: "provider rate limited" });
	process.exit(0);
} else if (mode === "ignore-term") {
	process.on("SIGTERM", () => undefined);
	if (process.env.FAKE_PI_ARGV_FILE) writeFileSync(process.env.FAKE_PI_ARGV_FILE, JSON.stringify({ args, ready: true }));
	hang();
} else if (mode === "slow") {
	setTimeout(() => { say("slow done"); process.exit(0); }, Number(task.split(" ")[1] ?? 500));
} else {
	hang();
}
