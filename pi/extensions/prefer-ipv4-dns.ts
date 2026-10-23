import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { setDefaultResultOrder } from "node:dns";

export default function preferIpv4Dns(_pi: ExtensionAPI): void {
	setDefaultResultOrder("ipv4first");
}
