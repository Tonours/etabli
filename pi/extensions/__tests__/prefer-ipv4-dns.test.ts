import { describe, expect, test } from "bun:test";
import { getDefaultResultOrder, setDefaultResultOrder } from "node:dns";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

describe("prefer-ipv4-dns", () => {
	test("sets ipv4first when the extension starts, not when its module loads", async () => {
		setDefaultResultOrder("verbatim");
		const { default: preferIpv4Dns } = await import("../prefer-ipv4-dns.ts");
		expect(getDefaultResultOrder()).toBe("verbatim");
		preferIpv4Dns({} as ExtensionAPI);
		expect(getDefaultResultOrder()).toBe("ipv4first");
	});
});
