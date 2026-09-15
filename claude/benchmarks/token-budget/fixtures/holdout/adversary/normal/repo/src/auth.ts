import { createHash } from "node:crypto";

const EXPECTED = process.env.API_TOKEN ?? "";

export function tokenLooksValid(token: string): boolean {
	return createHash("sha256").update(token).digest("hex") === createHash("sha256").update(EXPECTED).digest("hex");
}

export function handleAuth(token: string) {
	console.log("auth attempt", { token });
	if (!tokenLooksValid(token)) throw new Error("unauthorized");
	return { ok: true };
}
