/**
 * Re-export scripts/lib/ledger-auto-emit via realpath so Pi loads correctly
 * when extensions are symlinked from ~/.pi/agent/extensions -> pi/extensions.
 */
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(realpathSync(fileURLToPath(import.meta.url)));
const target = pathToFileURL(
	join(here, "../../../scripts/lib/ledger-auto-emit.mjs"),
).href;
const mod = await import(target);

export const pickPrimaryActiveLedger = mod.pickPrimaryActiveLedger as (
	cwd: string,
) => {
	path: string;
	run: string;
	events: Array<Record<string, unknown>>;
} | null;

export const appendLedgerEvent = mod.appendLedgerEvent as (
	ledgerPath: string,
	event: string,
	detail: Record<string, unknown>,
	runSlug?: string,
) => void;

export const inferBashFailureFromToolResult =
	mod.inferBashFailureFromToolResult as (
		content: unknown,
		isError?: boolean,
	) => { failed: boolean; exit?: number; failure?: string };

export const isBashToolName = mod.isBashToolName as (name: unknown) => boolean;

export const isLikelyValidationCommand = mod.isLikelyValidationCommand as (
	command: string,
) => boolean;

export const recordBashValidationFailure = mod.recordBashValidationFailure as (
	cwd: string,
	input: { command: string; exit: number; failure?: string; head_sha?: string },
) => { emitted: boolean; reason: string; ledger?: string; events?: string[] };
