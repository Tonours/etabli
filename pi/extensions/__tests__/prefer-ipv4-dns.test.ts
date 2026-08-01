import { describe, expect, test } from "bun:test";
import { getDefaultResultOrder } from "node:dns";
import {
	PREFERRED_DNS_RESULT_ORDER,
	applyPreferredDnsResultOrder,
} from "../prefer-ipv4-dns.ts";

describe("prefer-ipv4-dns", () => {
	test("applies ipv4first as the default DNS result order", () => {
		const applied = applyPreferredDnsResultOrder();
		expect(applied).toBe(PREFERRED_DNS_RESULT_ORDER);
		expect(getDefaultResultOrder()).toBe("ipv4first");
	});
});
