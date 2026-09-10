export const DEFAULT_MIN_SECONDS = 0.5;
export const DEFAULT_RENDER_INTERVAL_MS = 250;
export const DEFAULT_CHARS_PER_TOKEN = 4;
export const DEFAULT_CALIBRATION_WEIGHT = 0.3;
export const DEFAULT_MIN_CALIBRATION_TOKENS = 10;
const MIN_CHARS_PER_TOKEN = 1;
const MAX_CHARS_PER_TOKEN = 16;

export interface TokenRateTrackerOptions {
	minSeconds?: number;
	renderIntervalMs?: number;
	initialCharsPerToken?: number;
	calibrationWeight?: number;
	minCalibrationTokens?: number;
}

export interface LiveRate {
	tokens: number;
	seconds: number;
	rate: number;
}

const clamp = (value: number, min: number, max: number): number =>
	Math.min(max, Math.max(min, value));

export class TokenRateTracker {
	private readonly minSeconds: number;
	private readonly renderIntervalMs: number;
	private readonly calibrationWeight: number;
	private readonly minCalibrationTokens: number;

	private chars = 0;
	private startedAt: number | null = null;
	private lastRenderAt: number | null = null;
	private ratio: number;

	constructor(options: TokenRateTrackerOptions = {}) {
		this.minSeconds = options.minSeconds ?? DEFAULT_MIN_SECONDS;
		this.renderIntervalMs =
			options.renderIntervalMs ?? DEFAULT_RENDER_INTERVAL_MS;
		this.calibrationWeight =
			options.calibrationWeight ?? DEFAULT_CALIBRATION_WEIGHT;
		this.minCalibrationTokens =
			options.minCalibrationTokens ?? DEFAULT_MIN_CALIBRATION_TOKENS;
		this.ratio = clamp(
			options.initialCharsPerToken ?? DEFAULT_CHARS_PER_TOKEN,
			MIN_CHARS_PER_TOKEN,
			MAX_CHARS_PER_TOKEN,
		);
	}

	get charsPerToken(): number {
		return this.ratio;
	}

	start(at: number): void {
		this.chars = 0;
		this.startedAt = at;
		this.lastRenderAt = null;
	}

	reset(): void {
		this.chars = 0;
		this.startedAt = null;
		this.lastRenderAt = null;
	}

	onDelta(delta: string, at: number): LiveRate | null {
		if (this.startedAt === null) return null;
		this.chars += delta.length;

		const seconds = (at - this.startedAt) / 1000;
		if (seconds < this.minSeconds) return null;
		if (
			this.lastRenderAt !== null &&
			at - this.lastRenderAt < this.renderIntervalMs
		) {
			return null;
		}
		this.lastRenderAt = at;

		const tokens = this.chars / this.ratio;
		return { tokens, seconds, rate: tokens / seconds };
	}

	finish(outputTokens: number, at: number): number | null {
		if (this.startedAt === null) return null;
		const seconds = (at - this.startedAt) / 1000;
		if (outputTokens <= 0 || seconds < this.minSeconds) return null;

		if (this.chars > 0 && outputTokens >= this.minCalibrationTokens) {
			const observed = this.chars / outputTokens;
			this.ratio = clamp(
				this.ratio * (1 - this.calibrationWeight) +
					observed * this.calibrationWeight,
				MIN_CHARS_PER_TOKEN,
				MAX_CHARS_PER_TOKEN,
			);
		}

		return outputTokens / seconds;
	}
}

export const formatRate = (rate: number): string =>
	rate >= 100 ? Math.round(rate).toString() : rate.toFixed(1);
