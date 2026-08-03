import { describe, expect, test } from "bun:test";
import {
	PREFERRED_DNS_RESULT_ORDER,
	applyPreferredDnsResultOrder,
} from "../prefer-ipv4-dns.ts";

describe("prefer-ipv4-dns", () => {
	test("applies ipv4first as the default DNS result order", () => {
		expect(applyPreferredDnsResultOrder()).toBe(PREFERRED_DNS_RESULT_ORDER);
		expect(PREFERRED_DNS_RESULT_ORDER).toBe("ipv4first");
	});

	test("is idempotent across repeated applications", () => {
		applyPreferredDnsResultOrder();
		expect(applyPreferredDnsResultOrder()).toBe(PREFERRED_DNS_RESULT_ORDER);
	});
});
