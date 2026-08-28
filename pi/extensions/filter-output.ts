import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export type TokenPattern = { pattern: RegExp; label: string };
export type StructuralPattern = { pattern: RegExp; replacement: string };

/**
 * Filter Output — POST-EXECUTION secret redaction for tool results.
 *
 * Redacts sensitive data (API keys, tokens, secrets, credentials) from tool
 * output before the LLM sees it. Covers both `read` (file reads) and `bash`
 * (command output) to prevent accidental secret leakage.
 */
// ---------------------------------------------------------------------------
// Token patterns — prefixed / structurally identifiable keys
// ---------------------------------------------------------------------------
export const tokenPatterns: TokenPattern[] = [
	// Anthropic
	{ pattern: /\bsk-ant-[a-zA-Z0-9_-]{20,}\b/g, label: "ANTHROPIC_KEY" },
	// OpenAI (sk-proj-... is the new format, sk-... is legacy)
	{
		pattern: /\bsk-(?!ant-)(?:proj-)?[a-zA-Z0-9_-]{20,}\b/g,
		label: "OPENAI_KEY",
	},
	// GitHub (PAT, OAuth, app, refresh tokens)
	{
		pattern: /\bg(?:hp|ho|hs|hu|hr)_[a-zA-Z0-9]{36,}\b/g,
		label: "GITHUB_TOKEN",
	},
	// GitHub fine-grained PAT
	{ pattern: /\bgithub_pat_[a-zA-Z0-9_]{20,}\b/g, label: "GITHUB_PAT" },
	// Slack (bot, user, app, config)
	{ pattern: /\bxox[bpasrc]-[a-zA-Z0-9-]{10,}\b/g, label: "SLACK_TOKEN" },
	// AWS access key
	{ pattern: /\bAKIA[A-Z0-9]{16}\b/g, label: "AWS_ACCESS_KEY" },
	{ pattern: /\bASIA[A-Z0-9]{16}\b/g, label: "AWS_TEMP_KEY" },
	// Stripe (secret, publishable, restricted)
	{ pattern: /\b[sr]k_(?:live|test)_[a-zA-Z0-9]{20,}\b/g, label: "STRIPE_KEY" },
	{ pattern: /\bpk_(?:live|test)_[a-zA-Z0-9]{20,}\b/g, label: "STRIPE_PK" },
	{
		pattern: /\brk_(?:live|test)_[a-zA-Z0-9]{20,}\b/g,
		label: "STRIPE_RESTRICTED",
	},
	{ pattern: /\bwhsec_[a-zA-Z0-9]{20,}\b/g, label: "STRIPE_WEBHOOK" },
	// Vercel
	{ pattern: /\bvercel_[a-zA-Z0-9_-]{20,}\b/gi, label: "VERCEL_TOKEN" },
	// Supabase
	{ pattern: /\bsbp_[a-zA-Z0-9]{20,}\b/g, label: "SUPABASE_KEY" },
	{
		pattern:
			/\beyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g,
		label: "SUPABASE_JWT",
	},
	// Cloudflare
	{ pattern: /\bcf_[a-zA-Z0-9_-]{37,}\b/gi, label: "CLOUDFLARE_TOKEN" },
	// npm
	{ pattern: /\bnpm_[a-zA-Z0-9]{36,}\b/g, label: "NPM_TOKEN" },
	// PyPI
	{ pattern: /\bpypi-[a-zA-Z0-9_-]{20,}\b/g, label: "PYPI_TOKEN" },
	// Twilio
	{ pattern: /\bSK[a-f0-9]{32}\b/g, label: "TWILIO_KEY" },
	// SendGrid
	{
		pattern: /\bSG\.[a-zA-Z0-9_-]{22,}\.[a-zA-Z0-9_-]{20,}\b/g,
		label: "SENDGRID_KEY",
	},
	// Firebase / Google service account
	{ pattern: /\bAIza[a-zA-Z0-9_-]{35}\b/g, label: "GOOGLE_API_KEY" },
	// Doppler
	{
		pattern: /\bdp\.(?:st|ct|sa|scrt)\.[a-zA-Z0-9_-]{20,}\b/g,
		label: "DOPPLER_TOKEN",
	},
	// age encryption
	{ pattern: /\bAGE-SECRET-KEY-[A-Z0-9]{59}\b/g, label: "AGE_SECRET_KEY" },
	// Grafana
	{ pattern: /\bglc_[a-zA-Z0-9_-]{32,}\b/g, label: "GRAFANA_TOKEN" },
	// Linear
	{ pattern: /\blin_api_[a-zA-Z0-9]{40,}\b/g, label: "LINEAR_KEY" },
	// Resend
	{ pattern: /\bre_[a-zA-Z0-9]{20,}\b/g, label: "RESEND_KEY" },
	// GitLab PAT
	{ pattern: /\bglpat-[a-zA-Z0-9_-]{20}\b/g, label: "GITLAB_TOKEN" },
	// HuggingFace access token
	{ pattern: /\bhf_[a-zA-Z0-9]{34,}\b/g, label: "HUGGINGFACE_TOKEN" },
	// Notion internal integration token
	{ pattern: /\bsecret_[a-zA-Z0-9]{43}\b/g, label: "NOTION_TOKEN" },
	// DigitalOcean access token
	{ pattern: /\bdop_v1_[a-f0-9]{64}\b/g, label: "DIGITALOCEAN_TOKEN" },
	// Mailgun API key
	{ pattern: /\bkey-[a-f0-9]{32}\b/g, label: "MAILGUN_KEY" },
	// Shopify (pat/secret/app/ca)
	{
		pattern: /\bsh(?:pat|pss|pca|ppa)_[a-zA-Z0-9]{32}\b/g,
		label: "SHOPIFY_TOKEN",
	},
	// JFrog / Artifactory token
	{ pattern: /\bcmVmdGtu[a-zA-Z0-9_-]{40,}\b/g, label: "JFROG_TOKEN" },
	// Square (access/secret)
	{ pattern: /\bsq0(?:atp|csp)-[a-zA-Z0-9_-]{22,}\b/g, label: "SQUARE_TOKEN" },
	// Atlassian (Jira/Confluence PAT)
	{ pattern: /\bATATT3[A-Za-z0-9_-]{60,}\b/g, label: "ATLASSIAN_TOKEN" },
	// Generic JWT (header.payload.signature; distinct from Supabase-specific)
	{
		pattern: /\beyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g,
		label: "JWT",
	},
	// Alibaba / Aliyun Access Key ID
	{ pattern: /\bLTAI[a-zA-Z0-9]{12,}\b/g, label: "ALIYUN_KEY" },
	// Tencent Cloud SecretId
	{ pattern: /\bAKID[a-zA-Z0-9]{32,}\b/g, label: "TENCENT_KEY" },
	// Sentry org auth token
	{ pattern: /\bsntrys_[a-zA-Z0-9_-]{40,}\b/g, label: "SENTRY_TOKEN" },
	// Docker personal access token
	{ pattern: /\bdckr_pat_[a-zA-Z0-9_-]{27,}\b/g, label: "DOCKER_TOKEN" },
	// HashiCorp Vault service token
	{ pattern: /\bhvs\.[a-zA-Z0-9_-]{40,}\b/g, label: "VAULT_TOKEN" },
	// Slack incoming webhook URL
	{
		pattern: /\bhttps:\/\/hooks\.slack\.com\/services\/[A-Za-z0-9_/-]{20,}\b/g,
		label: "SLACK_WEBHOOK",
	},
	// Sentry DSN
	{
		pattern: /\bhttps:\/\/[a-f0-9]{32}@o\d+\.ingest\.[a-z.]*sentry\.io\/\d+\b/gi,
		label: "SENTRY_DSN",
	},
	// Google OAuth access token
	{
		pattern: /\bya29\.[a-zA-Z0-9_-]{20,}\b/g,
		label: "GOOGLE_OAUTH",
	},
	// Mailchimp API key (<32>-us<datacenter>)
	{
		pattern: /\b[a-zA-Z0-9]{32}-us\d{1,2}\b/g,
		label: "MAILCHIMP_KEY",
	},
];

// ---------------------------------------------------------------------------
// Structural patterns — values identifiable by surrounding context
// ---------------------------------------------------------------------------
export const structuralPatterns: StructuralPattern[] = [
	// Generic key=value assignments where key suggests a secret
	{
		pattern:
			/\b(api[_-]?key|api[_-]?secret|access[_-]?key)\s*[=:]\s*['"]?([a-zA-Z0-9_/.+=-]{16,})['"]?/gi,
		replacement: "$1=[REDACTED]",
	},
	{
		pattern:
			/\b(secret[_-]?key|private[_-]?key|auth[_-]?token|access[_-]?token|refresh[_-]?token)\s*[=:]\s*['"]?([^\s'"]{8,})['"]?/gi,
		replacement: "$1=[REDACTED]",
	},
	{
		pattern:
			/\b(postmark[_-]?(?:server[_-]?)?token)\s*[=:]\s*['"]?([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})['"]?/gi,
		replacement: "$1=[REDACTED]",
	},
	{
		pattern:
			/(["'])([a-zA-Z0-9_-]*(?:token|secret|credential)[a-zA-Z0-9_-]*)\1\s*:\s*(["'])([^"'\s]{8,})\3/gi,
		replacement: "$1$2$1:$3[REDACTED]$3",
	},
	{
		pattern:
			/\b([a-zA-Z0-9_-]*(?:token|secret|credential)[a-zA-Z0-9_-]*)\s*[=:]\s*['"]?([^\s'"]{8,})['"]?/gi,
		replacement: "$1=[REDACTED]",
	},
	{
		pattern: /\b(password|passwd|pwd|pass)\s*[=:]\s*['"]?([^\s'"]{4,})['"]?/gi,
		replacement: "$1=[REDACTED]",
	},
	// Bearer tokens
	{
		pattern: /\b(bearer)\s+([a-zA-Z0-9._-]{20,})\b/gi,
		replacement: "Bearer [REDACTED]",
	},
	// Authorization headers
	{
		pattern: /(Authorization:\s*(?:Bearer|Basic|Token)\s+)([^\s]{8,})/gi,
		replacement: "$1[REDACTED]",
	},
	// Database connection strings
	{
		pattern:
			/((?:mongodb|postgres(?:ql)?|mysql|redis|amqp|nats|clickhouse)(?:\+srv)?:\/\/[^:]*:)[^@]+(@)/gi,
		replacement: "$1[REDACTED]$2",
	},
	// PEM private keys (multiline)
	{
		pattern:
			/-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----/g,
		replacement: "[PRIVATE_KEY_REDACTED]",
	},
	// AWS secret access key pattern (40 char base64 following a label)
	{
		pattern: /(aws_secret_access_key\s*[=:]\s*['"]?)[a-zA-Z0-9/+=]{40}['"]?/gi,
		replacement: "$1[REDACTED]",
	},
];

// ---------------------------------------------------------------------------
// Required-literal prefilters — index-aligned with the pattern arrays above.
// Each entry lists needle sets (outer OR, inner AND): the pattern can only
// match the input when at least one needle set is fully present. Patterns whose
// needles are absent are skipped without running their regex. `ci` entries
// check needles against the lowercased input (patterns using the `i` flag).
// ---------------------------------------------------------------------------
export type PatternNeedles = {
	readonly needleSets: readonly (readonly string[])[];
	readonly ci: boolean;
};

export const tokenPatternNeedles: readonly PatternNeedles[] = [
	{ needleSets: [["sk-"]], ci: false }, // sk-ant-
	{ needleSets: [["sk-"]], ci: false }, // sk- / sk-proj-
	{
		needleSets: [["ghp_"], ["gho_"], ["ghs_"], ["ghu_"], ["ghr_"]],
		ci: false,
	},
	{ needleSets: [["github_pat_"]], ci: false },
	{ needleSets: [["xox"]], ci: false },
	{ needleSets: [["AKIA"]], ci: false },
	{ needleSets: [["ASIA"]], ci: false },
	{ needleSets: [["k_live_"], ["k_test_"]], ci: false },
	{ needleSets: [["pk_live_"], ["pk_test_"]], ci: false },
	{ needleSets: [["rk_live_"], ["rk_test_"]], ci: false },
	{ needleSets: [["whsec_"]], ci: false },
	{ needleSets: [["vercel_"]], ci: true },
	{ needleSets: [["sbp_"]], ci: false },
	{
		needleSets: [["eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."]],
		ci: false,
	},
	{ needleSets: [["cf_"]], ci: true },
	{ needleSets: [["npm_"]], ci: false },
	{ needleSets: [["pypi-"]], ci: false },
	{ needleSets: [["SK"]], ci: false },
	{ needleSets: [["SG."]], ci: false },
	{ needleSets: [["AIza"]], ci: false },
	{ needleSets: [["dp."]], ci: false },
	{ needleSets: [["AGE-SECRET-KEY-"]], ci: false },
	{ needleSets: [["glc_"]], ci: false },
	{ needleSets: [["lin_api_"]], ci: false },
	{ needleSets: [["re_"]], ci: false },
	{ needleSets: [["glpat-"]], ci: false },
	{ needleSets: [["hf_"]], ci: false },
	{ needleSets: [["secret_"]], ci: false },
	{ needleSets: [["dop_v1_"]], ci: false },
	{ needleSets: [["key-"]], ci: false },
	{
		needleSets: [["shpat_"], ["shpss_"], ["shpca_"], ["shppa_"]],
		ci: false,
	},
	{ needleSets: [["cmVmdGtu"]], ci: false },
	{ needleSets: [["sq0atp-"], ["sq0csp-"]], ci: false },
	{ needleSets: [["ATATT3"]], ci: false },
	{ needleSets: [["eyJ"]], ci: false },
	{ needleSets: [["LTAI"]], ci: false },
	{ needleSets: [["AKID"]], ci: false },
	{ needleSets: [["sntrys_"]], ci: false },
	{ needleSets: [["dckr_pat_"]], ci: false },
	{ needleSets: [["hvs."]], ci: false },
	{ needleSets: [["hooks.slack.com/services"]], ci: false },
	{ needleSets: [["ingest", "sentry.io"]], ci: true },
	{ needleSets: [["ya29."]], ci: false },
	{ needleSets: [["-us"]], ci: false },
];

export const structuralPatternNeedles: readonly PatternNeedles[] = [
	{ needleSets: [["key"], ["api"]], ci: true }, // api_key / api_secret / access_key
	{ needleSets: [["key"], ["token"]], ci: true }, // *_key / *_token
	{ needleSets: [["postmark"]], ci: true },
	{
		needleSets: [["token"], ["secret"], ["credential"]],
		ci: true,
	}, // JSON fields
	{
		needleSets: [["token"], ["secret"], ["credential"]],
		ci: true,
	}, // generic assignments
	{ needleSets: [["pass"], ["pwd"]], ci: true }, // password/passwd/pwd/pass
	{ needleSets: [["bearer"]], ci: true },
	{ needleSets: [["authorization"]], ci: true },
	{ needleSets: [["://"]], ci: true }, // db connection strings
	{ needleSets: [["-----BEGIN"]], ci: false }, // PEM blocks
	{ needleSets: [["aws_secret"]], ci: true },
];

// ---------------------------------------------------------------------------
// Compiled needle tables — per needle, the flat char-code sequence [c, alt, c,
// alt, ...] where `alt` is the other-case variant for `ci` needles. A needle is
// bitmap-rejected when any of its chars is absent from the input (both-case
// check for `ci`), avoiding a full substring scan for most needles.
// ---------------------------------------------------------------------------
type CompiledNeedle = {
	readonly needle: string;
	readonly codes: Int32Array;
	readonly pairCodes: Int32Array;
};
type CompiledNeedleSet = readonly CompiledNeedle[];
export type CompiledPatternNeedles = {
	readonly ci: boolean;
	readonly sets: readonly CompiledNeedleSet[];
};

function lowerCode(c: number): number {
	return c >= 65 && c <= 90 ? c + 32 : c;
}

function compileNeedles(
	needles: readonly PatternNeedles[],
): CompiledPatternNeedles[] {
	return needles.map(({ needleSets, ci }) => ({
		ci,
		sets: needleSets.map((set) =>
			set.map((needle) => {
				const codes = new Int32Array(needle.length * 2);
				const pairCodes = new Int32Array(Math.max(needle.length - 1, 0));
				let prevLo = -1;
				for (let i = 0; i < needle.length; i++) {
					const c = needle.charCodeAt(i);
					codes[i * 2] = c;
					codes[i * 2 + 1] = ci && c >= 97 && c <= 122 ? c - 32 : c;
					const lo = lowerCode(c);
					if (i > 0) pairCodes[i - 1] = prevLo * 128 + lo;
					prevLo = lo;
				}
				return { needle, codes, pairCodes };
			}),
		),
	}));
}

const compiledTokenNeedles = compileNeedles(tokenPatternNeedles);
const compiledStructuralNeedles = compileNeedles(structuralPatternNeedles);

// Scratch state for a single needle-evaluation pass (no reentrancy: replace
// callbacks never call back into the redaction path). The pair bitmap uses a
// generation counter so stale bits never need a 16KB clear per call.
const charBits = new Uint8Array(128);
const pairBits = new Uint8Array(128 * 128);
let pairBitsGen = 0;
const tokenFlags = new Uint8Array(tokenPatternNeedles.length);
const structuralFlags = new Uint8Array(structuralPatternNeedles.length);
let lowerText: string | undefined;

/** One pass over `text` recording which ASCII chars and lowercased char pairs occur. */
function buildCharBits(text: string): void {
	charBits.fill(0);
	if (pairBitsGen >= 255) {
		pairBits.fill(0);
		pairBitsGen = 0;
	}
	pairBitsGen++;
	lowerText = undefined;
	let prevLo = 0;
	for (let i = 0; i < text.length; i++) {
		const c = text.charCodeAt(i);
		if (c < 128) {
			charBits[c] = 1;
			const lo = c >= 65 && c <= 90 ? c + 32 : c;
			pairBits[prevLo * 128 + lo] = pairBitsGen;
			prevLo = lo;
		} else {
			prevLo = 0;
		}
	}
}

function needleCharsPresent(
	codes: Int32Array,
	pairCodes: Int32Array,
	ci: boolean,
): boolean {
	// Pairs (lowercase-folded) are the most selective check; run it first.
	for (let i = 0; i < pairCodes.length; i++) {
		if (pairBits[pairCodes[i]] !== pairBitsGen) return false;
	}
	if (ci) return true; // ci chars are lowercase-folded like the pairs: implied
	for (let i = 0; i < codes.length; i += 2) {
		if (!charBits[codes[i]]) return false;
	}
	return true;
}

/**
 * For each needle group, mark which patterns could still match `text`.
 * Requires buildCharBits(text) first. A pattern is inactive when none of its
 * needle sets is fully present in the input.
 */
function activePatternFlags(
	text: string,
	needles: readonly (readonly CompiledPatternNeedles[])[],
	flags: readonly Uint8Array[],
): void {
	for (let g = 0; g < needles.length; g++) {
		const group = needles[g];
		const groupFlags = flags[g];
		for (let i = 0; i < group.length; i++) {
			const { ci, sets } = group[i];
			let active = 0;
			for (let si = 0; si < sets.length && active === 0; si++) {
				const set = sets[si];
				let present = 1;
				for (let ni = 0; ni < set.length; ni++) {
					const { needle, codes, pairCodes } = set[ni];
					if (!needleCharsPresent(codes, pairCodes, ci)) {
						present = 0;
						break;
					}
					let haystack = text;
					if (ci) {
						if (lowerText === undefined) lowerText = text.toLowerCase();
						haystack = lowerText;
					}
					if (!haystack.includes(needle)) {
						present = 0;
						break;
					}
				}
				if (present === 1) active = 1;
			}
			groupFlags[i] = active;
		}
	}
}

export const tokenGateNeedles = [
	"sk-ant-",
	"sk-",
	"ghp_",
	"gho_",
	"ghs_",
	"ghu_",
	"ghr_",
	"github_pat_",
	"xox",
	"AKIA",
	"ASIA",
	"sk_live_",
	"sk_test_",
	"rk_live_",
	"rk_test_",
	"pk_live_",
	"pk_test_",
	"whsec_",
	"sbp_",
	"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.",
	"npm_",
	"pypi-",
	"SK",
	"SG.",
	"AIza",
	"dp.",
	"AGE-SECRET-KEY-",
	"glc_",
	"lin_api_",
	"re_",
	"glpat-",
	"hf_",
	"secret_",
	"dop_v1_",
	"key-",
	"shpat_",
	"shpss_",
	"shpca_",
	"shppa_",
	"cmVmdGtu",
	"sq0atp-",
	"sq0csp-",
	"ATATT3",
	"eyJ",
	"LTAI",
	"AKID",
	"sntrys_",
	"dckr_pat_",
	"hvs.",
	"hooks.slack.com/services",
	"ingest.sentry.io",
	"ya29.",
	"-us",
] as const;
export const caseInsensitiveTokenGateNeedles = ["vercel_", "cf_"] as const;
export const structuralGateNeedles = [
	"key",
	"secret",
	"token",
	"credential",
	"password",
	"passwd",
	"pwd",
	"pass",
	"bearer",
	"authorization",
	"mongodb",
	"postgres",
	"mysql",
	"redis",
	"amqp",
	"nats",
	"clickhouse",
	"begin",
	"aws_secret",
] as const;

// Compiled gate needles — the flat gate lists with a per-needle prefilter:
// the distinct lowercase-folded char codes. A needle can only be a substring
// of `text` when every one of its chars occurs in `text` (case-insensitively
// for `ci` needles — a weaker but still sound necessary condition for the
// case-sensitive ones), so the `includes` scan only runs for surviving
// needles and truth values stay identical to the linear containsAny sweep.
// This dedicated bitmap is cheaper than the pair-bitmap machinery because the
// short gate needles are rejected by single-char checks almost everywhere.
type GateNeedle = {
	readonly needle: string;
	readonly ci: boolean;
	readonly chars: Uint8Array;
};

// 64K fold table (ASCII -> lowercase, everything else -> 128 sentinel) so the
// scan is branch-free: one load + one store per char.
const gateFoldTable = new Uint8Array(65536).map((_, i) =>
	i < 128 ? (i >= 65 && i <= 90 ? i + 32 : i) : 128,
);

function compileGateNeedles(
	needles: readonly string[],
	ci: boolean,
): GateNeedle[] {
	return needles.map((needle) => {
		const seen = new Set<number>();
		for (let i = 0; i < needle.length; i++) {
			seen.add(gateFoldTable[needle.charCodeAt(i)]);
		}
		const chars = new Uint8Array(seen.size);
		let j = 0;
		for (const c of seen) chars[j++] = c;
		return { needle, ci, chars };
	});
}

const gateTokenNeedles = [
	...compileGateNeedles(tokenGateNeedles, false),
	...compileGateNeedles(caseInsensitiveTokenGateNeedles, true),
];
const gateStructuralNeedles = compileGateNeedles(structuralGateNeedles, true);

const gateFoldedBits = new Uint8Array(129); // index 128 = non-ASCII sentinel
let gateLowerText: string | undefined;

function buildGateBits(text: string): void {
	gateFoldedBits.fill(0);
	gateLowerText = undefined;
	// 8x unrolled: one table load + byte store per char.
	const len = text.length;
	let i = 0;
	const n = len - 7;
	for (; i < n; i += 8) {
		gateFoldedBits[gateFoldTable[text.charCodeAt(i)]] = 1;
		gateFoldedBits[gateFoldTable[text.charCodeAt(i + 1)]] = 1;
		gateFoldedBits[gateFoldTable[text.charCodeAt(i + 2)]] = 1;
		gateFoldedBits[gateFoldTable[text.charCodeAt(i + 3)]] = 1;
		gateFoldedBits[gateFoldTable[text.charCodeAt(i + 4)]] = 1;
		gateFoldedBits[gateFoldTable[text.charCodeAt(i + 5)]] = 1;
		gateFoldedBits[gateFoldTable[text.charCodeAt(i + 6)]] = 1;
		gateFoldedBits[gateFoldTable[text.charCodeAt(i + 7)]] = 1;
	}
	for (; i < len; i++) {
		gateFoldedBits[gateFoldTable[text.charCodeAt(i)]] = 1;
	}
}

function gateContainsAny(
	text: string,
	entries: readonly GateNeedle[],
): boolean {
	for (let i = 0; i < entries.length; i++) {
		const entry = entries[i];
		const chars = entry.chars;
		let possible = true;
		for (let j = 0; j < chars.length; j++) {
			if (gateFoldedBits[chars[j]] === 0) {
				possible = false;
				break;
			}
		}
		if (!possible) continue;
		let haystack = text;
		if (entry.ci) {
			if (gateLowerText === undefined) gateLowerText = text.toLowerCase();
			haystack = gateLowerText;
		}
		if (haystack.includes(entry.needle)) return true;
	}
	return false;
}

export function shouldRedactTokens(text: string): boolean {
	buildGateBits(text);
	return gateContainsAny(text, gateTokenNeedles);
}

export function shouldRedactStructural(text: string): boolean {
	buildGateBits(text);
	return gateContainsAny(text, gateStructuralNeedles);
}

/**
 * For each needle group, compute which patterns could still match `text`.
 * A pattern is inactive when none of its needle sets is fully present in the
 * input. Needles of `ci` entries are checked against the lowercased input.
 */
function evaluateTokenFlags(text: string): Uint8Array {
	buildCharBits(text);
	activePatternFlags(text, [compiledTokenNeedles], [tokenFlags]);
	return tokenFlags;
}

function evaluateStructuralFlags(text: string): Uint8Array {
	buildCharBits(text);
	activePatternFlags(text, [compiledStructuralNeedles], [structuralFlags]);
	return structuralFlags;
}

function runTokenPatterns(
	text: string,
	patterns: readonly TokenPattern[],
	active: Uint8Array | null,
): { result: string; count: number } {
	let count = 0;
	let result = text;
	for (let i = 0; i < patterns.length; i++) {
		if (active && !active[i]) continue;
		const { pattern, label } = patterns[i];
		pattern.lastIndex = 0;
		const newResult = result.replace(pattern, () => {
			count++;
			return `[${label}_REDACTED]`;
		});
		result = newResult;
	}
	return { result, count };
}

function runStructuralPatterns(
	text: string,
	patterns: readonly StructuralPattern[],
	active: Uint8Array | null,
): { result: string; count: number } {
	let count = 0;
	let result = text;
	for (let i = 0; i < patterns.length; i++) {
		if (active && !active[i]) continue;
		const { pattern, replacement } = patterns[i];
		pattern.lastIndex = 0;
		const newResult = result.replace(pattern, (...args) => {
			const replacementText = replacement.replace(
				/\$(\d)/g,
				(_, n) => args[parseInt(n, 10)] || "",
			);
			if (replacementText !== args[0]) {
				count++;
			}
			return replacementText;
		});
		result = newResult;
	}
	return { result, count };
}

export function redactTokens(
	text: string,
	patterns: TokenPattern[] = tokenPatterns,
): { result: string; count: number } {
	// Custom pattern lists run unfiltered (no index-aligned needle table).
	const active = patterns === tokenPatterns ? evaluateTokenFlags(text) : null;
	return runTokenPatterns(text, patterns, active);
}

export function redactStructural(
	text: string,
	patterns: StructuralPattern[] = structuralPatterns,
): { result: string; count: number } {
	const active =
		patterns === structuralPatterns ? evaluateStructuralFlags(text) : null;
	return runStructuralPatterns(text, patterns, active);
}

export function redactInlineSecrets(text: string): {
	result: string;
	count: number;
} {
	// Both needle checks run against the ORIGINAL text (mirroring the original
	// gate semantics): token redaction labels such as "[GITHUB_TOKEN_REDACTED]"
	// introduce the words token/key, which must not trigger the structural pass.
	buildCharBits(text);
	activePatternFlags(
		text,
		[compiledTokenNeedles, compiledStructuralNeedles],
		[tokenFlags, structuralFlags],
	);
	const tokenActive = tokenFlags;
	const structuralActive = structuralFlags;
	let count = 0;
	let result = text;

	if (tokenActive.some(Boolean)) {
		const tokens = runTokenPatterns(result, tokenPatterns, tokenActive);
		result = tokens.result;
		count += tokens.count;
	}

	if (structuralActive.some(Boolean)) {
		const structural = runStructuralPatterns(
			result,
			structuralPatterns,
			structuralActive,
		);
		result = structural.result;
		count += structural.count;
	}

	return { result, count };
}

export default function (pi: ExtensionAPI) {
	// ---------------------------------------------------------------------------
	// Sensitive file patterns — block entire file reads
	// ---------------------------------------------------------------------------
	const sensitiveFiles: RegExp[] = [
		/\.env$/, // .env
		/\.env\.(?!example$|sample$|template$)[^/]+$/, // .env.local, .env.production (NOT .env.example/sample/template)
		/(?:^|\/)\.envrc$/, // direnv .envrc
		/\.dev\.vars$/, // Cloudflare .dev.vars
		/secrets?\.(json|ya?ml|toml)$/i, // secrets.json, secret.yaml
		/(?:^|\/)auth\.json$/i, // auth.json (OAuth/API secrets)
		/(?:^|\/).*\.token$/i, // *.token
		/(?:^|\/).*\.secrets\.json$/i, // *.secrets.json
		/credentials(\.json|\.ya?ml|\.toml)?$/i, // credentials, credentials.json
		/\.(?:pem|key|p12|pfx|jks|keystore|kdbx)$/i, // crypto key files
		/(?:^|\/)id_(?:rsa|ed25519|ecdsa|dsa)$/, // SSH private keys
		/(?:^|\/)\.ssh\/(?!config$|known_hosts$)[^/]+$/, // .ssh/* except config and known_hosts
		/(?:^|\/)\.netrc$/, // .netrc (plaintext credentials)
		/(?:^|\/)\.htpasswd$/, // Apache htpasswd
		/(?:^|\/)\.pgpass$/, // PostgreSQL password file
		/(?:^|\/)\.npmrc$/, // npm config (can contain tokens)
		/(?:^|\/)\.pypirc$/, // PyPI config (can contain tokens)
		/(?:^|\/)\.docker\/config\.json$/, // Docker credentials
	];

	// ---------------------------------------------------------------------------
	// Sensitive bash commands — detect when bash reads sensitive files
	// ---------------------------------------------------------------------------
	const readCommandPattern =
		/\b(cat|less|more|head|tail|bat|sed|awk|jq|yq|grep|rg|ripgrep|base64|xxd|hexdump|od|strings)\s+([^\n|;]+)/gi;
	const inputRedirectionPattern =
		/(?:^|[^<])\d*<\s*(?![<(&])(['"]?)([^'"\s;&|()]+)\1/g;
	const sourceCommandPattern =
		/(?:^|[;&|()]\s*)(?:source|\.)\s+(['"]?)([^'"\s;&|()]+)\1/g;
	const shellCommandPattern =
		/\b(?:bash|sh|zsh)((?:\s+-[A-Za-z-]+)+)\s+(['"])([\s\S]*?)\2/g;
	const inlineInterpreterPattern =
		/\b(?:python3?|ruby|perl)\s+(?:-[A-Za-z]*[ce][A-Za-z]*|--(?:command|eval))\s+(['"])([\s\S]*?)\1|\bnode\s+(?:-[A-Za-z]*[ep][A-Za-z]*|--(?:eval|print))\s+(['"])([\s\S]*?)\3|\bdeno\s+eval\s+(['"])([\s\S]*?)\5|\bbun\s+(?:-[A-Za-z]*e[A-Za-z]*|--eval)\s+(['"])([\s\S]*?)\7/g;
	const heredocInterpreterPattern =
		/\b(?:python3?|node|ruby|perl|deno|bun)(?:\s+-)?\s+<<-?\s*['"]?([A-Za-z0-9_]+)['"]?\s*\n([\s\S]*?)\n\1\b/g;
	const inlineFileReadPattern =
		/\b(?:open|readFile|readFileSync|createReadStream|read_text|read_bytes|File\.read|IO\.read|Bun\.file|Deno\.readTextFile|Deno\.readFile)\b/;
	const searchCommands = new Set(["grep", "rg", "ripgrep"]);
	const searchPathOptionNames = new Set([
		"--file",
		"--glob",
		"--iglob",
		"--include",
		"-f",
		"-g",
	]);
	const grepRecursiveOptionNames = new Set([
		"--recursive",
		"--dereference-recursive",
		"-r",
		"-R",
	]);
	const ripgrepSensitiveScopeOptionNames = new Set([
		"--hidden",
		"--no-ignore",
		"--no-ignore-vcs",
		"--no-ignore-dot",
		"-u",
		"-uu",
		"-uuu",
	]);
	const sensitiveCommandPatterns: RegExp[] = [
		/\bprintenv\b/,
		/(^|[;&|()]\s*)(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*(?:env|\/usr\/bin\/env|\/bin\/env)(?:\s+(?:-\S+|[A-Za-z_][A-Za-z0-9_]*=\S+))*\s*(?:$|[|>])/m,
		/(^|[;&|()]\s*)set\s*(?:$|[|>])/m,
		/(^|[;&|()]\s*)(?:declare|typeset)\s+-[A-Za-z-]*p[A-Za-z-]*\b/,
		/(^|[;&|()]\s*)export\s*(?:-p\s*)?(?:$|[|>])/m,
	];

	// ---------------------------------------------------------------------------
	// Helpers
	// ---------------------------------------------------------------------------
	function isSensitiveFile(filePath: string): boolean {
		return sensitiveFiles.some((p) => p.test(filePath));
	}

	function stringLiteralValues(code: string): string[] {
		const values: string[] = [];
		const literalPattern = /(['"])((?:\\.|(?!\1)[^\\])*)\1/g;

		for (const match of code.matchAll(literalPattern)) {
			values.push((match[2] ?? "").replace(/\\(['"\\])/g, "$1"));
		}

		return values;
	}

	function inlineCodeReadsSensitiveFile(command: string): boolean {
		inlineInterpreterPattern.lastIndex = 0;

		for (const match of command.matchAll(inlineInterpreterPattern)) {
			const code = match[2] ?? match[4] ?? match[6] ?? match[8] ?? "";
			if (!inlineFileReadPattern.test(code)) {
				continue;
			}

			if (stringLiteralValues(code).some(isSensitiveFile)) {
				return true;
			}
		}

		return false;
	}

	function heredocCodeReadsSensitiveFile(command: string): boolean {
		heredocInterpreterPattern.lastIndex = 0;

		for (const match of command.matchAll(heredocInterpreterPattern)) {
			const code = match[2] ?? "";
			if (!inlineFileReadPattern.test(code)) {
				continue;
			}

			if (stringLiteralValues(code).some(isSensitiveFile)) {
				return true;
			}
		}

		return false;
	}

	function shellTokens(args: string): string[] {
		return args
			.split(/\s+/)
			.map((token) => token.replace(/^['"]|['"]$/g, ""))
			.filter((token) => token !== "");
	}

	function isBroadSearchPath(token: string): boolean {
		return token === "." || token === "./" || token === ".." || token === "../";
	}

	function hasOption(
		tokens: string[],
		names: Set<string>,
		shortFlags: string[],
	): boolean {
		return tokens.some((token) => {
			if (names.has(token)) return true;
			if (token.startsWith("--")) return false;
			return shortFlags.some(
				(flag) => token.startsWith("-") && token.includes(flag),
			);
		});
	}

	function searchCanTraverseSensitiveFiles(
		commandName: string,
		args: string,
	): boolean {
		const normalizedCommand = commandName.toLowerCase();
		const tokens = shellTokens(args);
		const pathTokens = commandPathTokens(commandName, args);
		const hasBroadPath = pathTokens.some(isBroadSearchPath);

		if (normalizedCommand === "grep") {
			const hasRecursiveOption = hasOption(tokens, grepRecursiveOptionNames, [
				"r",
				"R",
			]);
			return hasRecursiveOption && (hasBroadPath || pathTokens.length === 0);
		}

		if (normalizedCommand === "rg" || normalizedCommand === "ripgrep") {
			const hasSensitiveScopeOption = hasOption(
				tokens,
				ripgrepSensitiveScopeOptionNames,
				["u"],
			);
			return hasSensitiveScopeOption && (hasBroadPath || pathTokens.length === 0);
		}

		return false;
	}

	function searchOutputReferencesSensitiveFile(
		commandName: string,
		output: string,
	): boolean {
		if (!searchCommands.has(commandName.toLowerCase())) {
			return false;
		}

		return output.split(/\r?\n/).some((line) => {
			const match = line.match(/^([^:\0]+)(?::|\0)/);
			return match ? isSensitiveFile(match[1]) : false;
		});
	}

	function commandPathTokens(commandName: string, args: string): string[] {
		const tokens = shellTokens(args);

		if (!searchCommands.has(commandName.toLowerCase())) {
			return tokens.filter((token) => !token.startsWith("-"));
		}

		const pathTokens: string[] = [];
		let patternSeen = false;
		let nextTokenIsPathOptionValue = false;

		for (const token of tokens) {
			if (nextTokenIsPathOptionValue) {
				pathTokens.push(token);
				nextTokenIsPathOptionValue = false;
				continue;
			}

			const optionWithValue = token.match(
				/^(--(?:file|glob|iglob|include))=(.+)$/,
			);
			if (optionWithValue) {
				pathTokens.push(optionWithValue[2]);
				continue;
			}

			const attachedShortPathOption = token.match(/^-[fg](.+)$/);
			if (attachedShortPathOption) {
				pathTokens.push(attachedShortPathOption[1]);
				continue;
			}

			if (searchPathOptionNames.has(token)) {
				nextTokenIsPathOptionValue = true;
				continue;
			}

			if (token.startsWith("-")) {
				continue;
			}

			if (!patternSeen) {
				patternSeen = true;
				continue;
			}

			pathTokens.push(token);
		}

		return pathTokens;
	}

	function readsSensitiveFile(command: string): boolean {
		readCommandPattern.lastIndex = 0;
		inputRedirectionPattern.lastIndex = 0;
		sourceCommandPattern.lastIndex = 0;

		for (const match of command.matchAll(readCommandPattern)) {
			const commandName = match[1] ?? "";
			const args = match[2] ?? "";
			if (searchCanTraverseSensitiveFiles(commandName, args)) {
				return true;
			}

			for (const token of commandPathTokens(commandName, args)) {
				if (isSensitiveFile(token)) {
					return true;
				}
			}
		}

		for (const match of command.matchAll(inputRedirectionPattern)) {
			const token = match[2] ?? "";
			if (isSensitiveFile(token)) {
				return true;
			}
		}

		for (const match of command.matchAll(sourceCommandPattern)) {
			const token = match[2] ?? "";
			if (isSensitiveFile(token)) {
				return true;
			}
		}

		return false;
	}

	function commandFragments(command: string): string[] {
		const fragments = [command];
		shellCommandPattern.lastIndex = 0;

		for (const match of command.matchAll(shellCommandPattern)) {
			const shellOptions = match[1] ?? "";
			const hasCommandOption = shellOptions
				.split(/\s+/)
				.some((option) => /^-[A-Za-z-]*c[A-Za-z-]*$/.test(option));
			const fragment = hasCommandOption ? (match[3] ?? "") : "";
			if (fragment !== "") {
				fragments.push(fragment);
			}
		}

		return fragments;
	}

	function isSensitiveCommand(command: string): boolean {
		return commandFragments(command).some(
			(fragment) =>
				readsSensitiveFile(fragment) ||
				inlineCodeReadsSensitiveFile(fragment) ||
				heredocCodeReadsSensitiveFile(fragment) ||
				sensitiveCommandPatterns.some((p) => p.test(fragment)),
		);
	}

	function outputReferencesSensitiveSearchResult(
		command: string,
		output: string,
	): boolean {
		return commandFragments(command).some((fragment) => {
			readCommandPattern.lastIndex = 0;
			for (const match of fragment.matchAll(readCommandPattern)) {
				if (searchOutputReferencesSensitiveFile(match[1] ?? "", output)) {
					return true;
				}
			}

			return false;
		});
	}

	// ---------------------------------------------------------------------------
	// Hook: tool_result
	// ---------------------------------------------------------------------------
	pi.on("tool_result", (event, ctx) => {
		if (event.isError) return undefined;

		const hasTextContent = event.content.some((c) => c.type === "text");
		if (!hasTextContent) return undefined;

		// -- Block sensitive file reads --
		if (event.toolName === "read") {
			const filePath = (event.input.path ?? event.input.file_path ?? "") as string;
			if (isSensitiveFile(filePath)) {
				ctx.ui.notify(`Blocked read of sensitive file: ${filePath}`, "warning");
				return {
					content: [
						{
							type: "text",
							text: `[Contents of ${filePath} redacted — sensitive file]`,
						},
					],
				};
			}
		}

		// -- Block bash commands that dump sensitive files or env --
		if (event.toolName === "bash" || event.toolName === "shell") {
			const command = (event.input.command ?? event.input.cmd ?? "") as string;
			const output = event.content
				.filter((content) => content.type === "text")
				.map((content) => content.text)
				.join("\n");
			if (
				isSensitiveCommand(command) ||
				outputReferencesSensitiveSearchResult(command, output)
			) {
				ctx.ui.notify(`Redacting output of sensitive command`, "warning");
				return {
					content: [
						{
							type: "text",
							text: `[Output redacted — command reads sensitive data]`,
						},
					],
				};
			}
		}

		// -- Redact inline secrets from any tool output --
		let totalRedactions = 0;
		const redactedContent = event.content.map((content) => {
			if (content.type !== "text") return content;

			const redacted = redactInlineSecrets(content.text);
			totalRedactions += redacted.count;

			return redacted.result === content.text
				? content
				: { ...content, text: redacted.result };
		});

		if (totalRedactions > 0) {
			ctx.ui.notify(
				`Redacted ${totalRedactions} secret${totalRedactions > 1 ? "s" : ""} from output`,
				"warning",
			);
			return { content: redactedContent };
		}

		return undefined;
	});
}
