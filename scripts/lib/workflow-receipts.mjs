/**
 * Non-cryptographic runtime receipts. A receipt binds a ledger assertion
 * (validation command, file change, review, archive, completion) to a
 * parent-process observation: a SHA-256 of the subject path or command, an
 * exit code, and optional worktree/artifact hashes. It stores ONLY allowlisted
 * hashes and metadata — never raw tool output, file contents, or command text
 * that may carry secrets.
 *
 * Trust label: parent-process observed. A receipt is not a cryptographic
 * attestation and must not be presented as proof of isolation.
 */
import { createHash } from "node:crypto";
import { appendFileSync } from "node:fs";
import { basename, dirname } from "node:path";

export const RECEIPT_KINDS = Object.freeze([
	"file_change",
	"validation",
	"review",
	"archive",
	"completion",
]);

function isoTs() {
	return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function sha256(value) {
	return createHash("sha256").update(String(value), "utf8").digest("hex");
}

function isNonEmptyString(value) {
	return typeof value === "string" && value.trim() !== "";
}

/**
 * Build a receipt detail. The subject (path or command) is hashed in-process
 * and never persisted; only subject_sha256 survives.
 * @param {{receiptFor: string, source: string, kind: string, subject: string, exit?: number, worktreeSha?: string, artifactSha?: string}} input
 */
export function buildReceipt(input) {
	const receiptFor = String(input?.receiptFor || "").trim();
	const source = String(input?.source || "").trim();
	const kind = String(input?.kind || "").trim();
	const subject = String(input?.subject ?? "");
	if (!receiptFor || !source || !kind || !isNonEmptyString(subject)) {
		throw new Error(
			"runtime receipt requires receiptFor, source, kind, and subject",
		);
	}
	if (!RECEIPT_KINDS.includes(kind)) {
		throw new Error(`unsupported receipt kind: ${kind}`);
	}
	const detail = {
		receipt_for: receiptFor,
		source,
		kind,
		subject_sha256: sha256(subject),
		observed_by: "parent-process",
		cryptographic: false,
	};
	if (Number.isInteger(input?.exit) && input.exit >= 0)
		detail.exit = input.exit;
	if (isNonEmptyString(input?.worktreeSha))
		detail.worktree_sha256 = sha256(input.worktreeSha);
	if (isNonEmptyString(input?.artifactSha))
		detail.artifact_sha256 = sha256(input.artifactSha);
	return detail;
}

/**
 * Append a runtime_receipt event to a ledger. Never throws on I/O so it cannot
 * break the tool_result pipeline; returns the emitted line or null.
 * @param {string} ledgerPath
 * @param {string} runSlug
 * @param {ReturnType<typeof buildReceipt>} detail
 */
export function issueReceipt(ledgerPath, runSlug, detail) {
	if (!ledgerPath || !detail) return null;
	const slug = runSlug || basename(dirname(ledgerPath));
	const line = JSON.stringify({
		schema_version: 2,
		ts: isoTs(),
		event: "runtime_receipt",
		run: slug,
		detail,
	});
	try {
		appendFileSync(ledgerPath, `${line}\n`, "utf8");
		return line;
	} catch {
		return null;
	}
}
