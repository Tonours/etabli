import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const TOOLS = ["subagent", "bg_wait", "subagent_supervisor"];
const LOADER = "load_workflow_tools";
const TOOL_FLAGS = new Set([
	"--tools", "-t", "--exclude-tools", "-xt", "--no-tools", "-nt", "--no-builtin-tools", "-nbt",
]);

export default function workflowTools(pi: ExtensionAPI) {
	const args = process.argv.slice(2);
	const separator = args.indexOf("--");
	const options = separator < 0 ? args : args.slice(0, separator);
	if (process.env.ETABLI_EAGER_TOOLS === "1" || options.some((arg) => TOOL_FLAGS.has(arg.split("=")[0]))) return;

	let eligible = new Set<string>();
	pi.registerTool({
		name: LOADER,
		label: "Load workflow tools",
		description: "Enable the delegation tools for this session: subagent, bg_wait and subagent_supervisor. Call before using those tools.",
		parameters: Type.Object({}),
		async execute() {
			const registered = new Set(pi.getAllTools().map((tool) => tool.name));
			const available = TOOLS.filter((name) => eligible.has(name) && registered.has(name));
			if (!available.length) {
				return { content: [{ type: "text", text: "No delegation tools are available in this session." }], details: { added: [] }, isError: true };
			}
			const active = pi.getActiveTools();
			const added = available.filter((name) => !active.includes(name));
			if (added.length) pi.setActiveTools([...active, ...added]);
			return {
				content: [{ type: "text", text: added.length ? `Enabled: ${added.join(", ")}.` : "Delegation tools are already active." }],
				details: { added },
			};
		},
	});

	pi.on("session_start", () => {
		const active = pi.getActiveTools();
		const registered = new Set(pi.getAllTools().map((tool) => tool.name));
		eligible = new Set(active.filter((name) => TOOLS.includes(name) && registered.has(name)));
		if (!eligible.size) {
			pi.setActiveTools(active.filter((name) => name !== LOADER));
			return;
		}
		pi.setActiveTools([...new Set([...active.filter((name) => !eligible.has(name)), LOADER])]);
	});
}
