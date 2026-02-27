/**
 * Auto-hide header after the first user message.
 * Shows the full banner (logo + keybindings) on startup,
 * then collapses to a minimal logo once chatting starts.
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { VERSION } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	let hidden = false;

	// Use tool_call like welcome.ts — fires reliably when agent starts working
	pi.on("tool_call", async (_event, ctx) => {
		if (hidden || !ctx.hasUI) return;
		hidden = true;

		ctx.ui.setHeader((_tui, theme) => ({
			render(_width: number): string[] {
				const logo =
					theme.bold(theme.fg("accent", "pi")) +
					theme.fg("dim", ` v${VERSION}`);
				return [logo];
			},
			invalidate() {},
		}));
	});
}
