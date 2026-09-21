import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(realpathSync(fileURLToPath(import.meta.url)));
const target = pathToFileURL(join(here, "../../../scripts/lib/pi-run-binding.mjs")).href;
const mod = await import(target);

export type PiRunBinding = {
	schema_version: number;
	algorithm: "sha256";
	fingerprint: string;
};

export const PI_RUN_BINDING_TYPE = mod.PI_RUN_BINDING_TYPE as string;
export const createPiRunBinding = mod.createPiRunBinding as (
	sessionId: string,
	run: string,
	genesis: Record<string, unknown>,
) => PiRunBinding;
