import { spawn } from "node:child_process";

const kill = () => process.kill(-process.pid, "SIGKILL");
process.on("SIGTERM", () => {});
process.on("disconnect", kill);
process.stdin.on("end", kill);
process.stdin.on("error", kill);
process.stdin.resume();

let reported = false;
function report(code, signal) {
	if (reported) return;
	reported = true;
	try {
		if (process.send) process.send({ type: "child_exit", code, signal }, () => kill());
		else kill();
	} catch {
		kill();
	}
}

const [command, ...args] = process.argv.slice(2);
const child = spawn(command, args, { stdio: ["ignore", "inherit", "inherit"], env: process.env });
child.on("error", (error) => {
	console.error(`Could not start subagent: ${error.message}`);
	report(127, null);
});
child.on("exit", report);
