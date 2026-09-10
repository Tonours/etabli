import { describe, expect, test } from "bun:test";
import {
	DEFAULT_CALIBRATION_WEIGHT,
	DEFAULT_CHARS_PER_TOKEN,
	formatRate,
	TokenRateTracker,
} from "../lib/token-rate-runtime.ts";

const START = 1_000_000;

describe("TokenRateTracker.onDelta", () => {
	test("returns null before the minimum window has elapsed", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		expect(tracker.onDelta("abcd".repeat(50), START + 400)).toBeNull();
	});

	test("returns a live estimate once the window is long enough", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		const live = tracker.onDelta("abcd".repeat(50), START + 600);
		expect(live).not.toBeNull();
		expect(live?.seconds).toBe(0.6);
		expect(live?.tokens).toBeCloseTo(50, 5);
		expect(live?.rate).toBeCloseTo(50 / 0.6, 5);
	});

	test("throttles renders to one per interval while still accumulating chars", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		expect(tracker.onDelta("a".repeat(40), START + 600)).not.toBeNull();
		expect(tracker.onDelta("b".repeat(40), START + 700)).toBeNull();
		const live = tracker.onDelta("c".repeat(40), START + 900);
		expect(live).not.toBeNull();
		expect(live?.tokens).toBeCloseTo(30, 5);
	});

	test("ignores deltas when no stream window is open", () => {
		const tracker = new TokenRateTracker();
		expect(tracker.onDelta("abcd", START)).toBeNull();
	});
});

describe("TokenRateTracker.finish", () => {
	test("returns the exact rate for a measurable window", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		expect(tracker.finish(120, START + 2_000)).toBe(60);
	});

	test("returns null for degenerate windows", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		expect(tracker.finish(0, START + 2_000)).toBeNull();
		expect(tracker.finish(10, START + 400)).toBeNull();
	});

	test("returns null when no stream window is open", () => {
		const tracker = new TokenRateTracker();
		expect(tracker.finish(10, START)).toBeNull();
	});
});

describe("TokenRateTracker calibration", () => {
	test("moves the chars-per-token EMA toward observed samples", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		tracker.onDelta("a".repeat(500), START + 600);
		tracker.finish(200, START + 2_000);
		const expected =
			DEFAULT_CHARS_PER_TOKEN * (1 - DEFAULT_CALIBRATION_WEIGHT) +
			2.5 * DEFAULT_CALIBRATION_WEIGHT;
		expect(tracker.charsPerToken).toBeCloseTo(expected, 5);
	});

	test("skips calibration for small outputs", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		tracker.onDelta("a".repeat(9), START + 600);
		tracker.finish(9, START + 2_000);
		expect(tracker.charsPerToken).toBe(DEFAULT_CHARS_PER_TOKEN);
	});

	test("survives reset and start of the next message", () => {
		const tracker = new TokenRateTracker();
		tracker.start(START);
		tracker.onDelta("a".repeat(500), START + 600);
		tracker.finish(200, START + 2_000);
		tracker.reset();
		tracker.start(START + 3_000);
		const live = tracker.onDelta("a".repeat(50), START + 3_600);
		expect(live?.tokens).toBeCloseTo(50 / tracker.charsPerToken, 5);
	});

	test("clamps the calibrated ratio to sane bounds", () => {
		const tracker = new TokenRateTracker({
			calibrationWeight: 1,
			initialCharsPerToken: 4,
		});
		tracker.start(START);
		tracker.onDelta("a".repeat(4), START + 600);
		tracker.finish(1_000, START + 2_000);
		expect(tracker.charsPerToken).toBe(1);
	});
});

describe("formatRate", () => {
	test("rounds to integer at or above 100 and keeps one decimal below", () => {
		expect(formatRate(100)).toBe("100");
		expect(formatRate(142.7)).toBe("143");
		expect(formatRate(99.96)).toBe("100.0");
		expect(formatRate(42.34)).toBe("42.3");
	});
});
