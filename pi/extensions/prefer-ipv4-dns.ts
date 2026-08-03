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

applyPreferredDnsResultOrder();

export default function preferIpv4Dns(_pi: ExtensionAPI): void {
	applyPreferredDnsResultOrder();
}
