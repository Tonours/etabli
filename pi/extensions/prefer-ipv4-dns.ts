/**
 * Prefer IPv4 when Node resolves dual-stack model API hosts.
 *
 * Measured on this machine: api.z.ai cold TLS handshake is often ~370–575 ms
 * when IPv6 is tried first (Node defaultResultOrder "verbatim") vs ~55–95 ms
 * with ipv4first. Applied at extension load so Pi inherits the preference even
 * without shell NODE_OPTIONS.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { setDefaultResultOrder } from "node:dns";

export const PREFERRED_DNS_RESULT_ORDER = "ipv4first" as const;

export function applyPreferredDnsResultOrder(): string | null {
	try {
		setDefaultResultOrder(PREFERRED_DNS_RESULT_ORDER);
		return PREFERRED_DNS_RESULT_ORDER;
	} catch {
		return null;
	}
}

// Apply immediately on load (before the first provider HTTP call).
applyPreferredDnsResultOrder();

export default function preferIpv4Dns(_pi: ExtensionAPI): void {
	// Side effect at import is sufficient; re-apply in case a host reset order.
	applyPreferredDnsResultOrder();
}
