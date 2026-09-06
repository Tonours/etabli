import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export type TokenPattern = {
	pattern: RegExp;
	label: string;
	needleSets: readonly (readonly string[])[];
};
export type StructuralPattern = {
	pattern: RegExp;
	replacement: string;
	needleSets: readonly (readonly string[])[];
};

/**
 * Filter Output — POST-EXECUTION secret redaction for tool results.
 *
 * Redacts sensitive data (API keys, tokens, secrets, credentials) from tool
 * output before the LLM sees it. Covers both `read` (file reads) and `bash`
 * (command output) to prevent accidental secret leakage.
 */
export const tokenPatterns: TokenPattern[] = [
	// Anthropic
	{
		pattern: /\bsk-ant-[a-zA-Z0-9_-]{20,}\b/g,
		label: "ANTHROPIC_KEY",
		needleSets: [["sk-"]],
	},
	// OpenAI (sk-proj-... is the new format, sk-... is legacy)
	{
		pattern: /\bsk-(?!ant-)(?:proj-)?[a-zA-Z0-9_-]{20,}\b/g,
		label: "OPENAI_KEY",
		needleSets: [["sk-"]],
	},
	// GitHub (PAT, OAuth, app, refresh tokens)
	{
		pattern: /\bg(?:hp|ho|hs|hu|hr)_[a-zA-Z0-9]{36,}\b/g,
		label: "GITHUB_TOKEN",
		needleSets: [["ghp_"], ["gho_"], ["ghs_"], ["ghu_"], ["ghr_"]],
	},
	// GitHub fine-grained PAT
	{
		pattern: /\bgithub_pat_[a-zA-Z0-9_]{20,}\b/g,
		label: "GITHUB_PAT",
		needleSets: [["github_pat_"]],
	},
	// Slack (bot, user, app, config)
	{
		pattern: /\bxox[bpasrc]-[a-zA-Z0-9-]{10,}\b/g,
		label: "SLACK_TOKEN",
		needleSets: [["xox"]],
	},
	// AWS access key
	{
		pattern: /\bAKIA[A-Z0-9]{16}\b/g,
		label: "AWS_ACCESS_KEY",
		needleSets: [["AKIA"]],
	},
	{
		pattern: /\bASIA[A-Z0-9]{16}\b/g,
		label: "AWS_TEMP_KEY",
		needleSets: [["ASIA"]],
	},
	// Stripe (secret, publishable, restricted)
	{
		pattern: /\b[sr]k_(?:live|test)_[a-zA-Z0-9]{20,}\b/g,
		label: "STRIPE_KEY",
		needleSets: [["k_live_"], ["k_test_"]],
	},
	{
		pattern: /\bpk_(?:live|test)_[a-zA-Z0-9]{20,}\b/g,
		label: "STRIPE_PK",
		needleSets: [["pk_live_"], ["pk_test_"]],
	},
	{
		pattern: /\brk_(?:live|test)_[a-zA-Z0-9]{20,}\b/g,
		label: "STRIPE_RESTRICTED",
		needleSets: [["rk_live_"], ["rk_test_"]],
	},
	{
		pattern: /\bwhsec_[a-zA-Z0-9]{20,}\b/g,
		label: "STRIPE_WEBHOOK",
		needleSets: [["whsec_"]],
	},
	// Vercel
	{
		pattern: /\bvercel_[a-zA-Z0-9_-]{20,}\b/gi,
		label: "VERCEL_TOKEN",
		needleSets: [["vercel_"]],
	},
	// Supabase
	{
		pattern: /\bsbp_[a-zA-Z0-9]{20,}\b/g,
		label: "SUPABASE_KEY",
		needleSets: [["sbp_"]],
	},
	{
		pattern:
			/\beyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g,
		label: "SUPABASE_JWT",
		needleSets: [["eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."]],
	},
	// Cloudflare
	{
		pattern: /\bcf_[a-zA-Z0-9_-]{37,}\b/gi,
		label: "CLOUDFLARE_TOKEN",
		needleSets: [["cf_"]],
	},
	// npm
	{
		pattern: /\bnpm_[a-zA-Z0-9]{36,}\b/g,
		label: "NPM_TOKEN",
		needleSets: [["npm_"]],
	},
	// PyPI
	{
		pattern: /\bpypi-[a-zA-Z0-9_-]{20,}\b/g,
		label: "PYPI_TOKEN",
		needleSets: [["pypi-"]],
	},
	// Twilio
	{
		pattern: /\bSK[a-f0-9]{32}\b/g,
		label: "TWILIO_KEY",
		needleSets: [["SK"]],
	},
	// SendGrid
	{
		pattern: /\bSG\.[a-zA-Z0-9_-]{22,}\.[a-zA-Z0-9_-]{20,}\b/g,
		label: "SENDGRID_KEY",
		needleSets: [["SG."]],
	},
	// Firebase / Google service account
	{
		pattern: /\bAIza[a-zA-Z0-9_-]{35}\b/g,
		label: "GOOGLE_API_KEY",
		needleSets: [["AIza"]],
	},
	// Doppler
	{
		pattern: /\bdp\.(?:st|ct|sa|scrt)\.[a-zA-Z0-9_-]{20,}\b/g,
		label: "DOPPLER_TOKEN",
		needleSets: [["dp."]],
	},
	// age encryption
	{
		pattern: /\bAGE-SECRET-KEY-[A-Z0-9]{59}\b/g,
		label: "AGE_SECRET_KEY",
		needleSets: [["AGE-SECRET-KEY-"]],
	},
	// Grafana
	{
		pattern: /\bglc_[a-zA-Z0-9_-]{32,}\b/g,
		label: "GRAFANA_TOKEN",
		needleSets: [["glc_"]],
	},
	// Linear
	{
		pattern: /\blin_api_[a-zA-Z0-9]{40,}\b/g,
		label: "LINEAR_KEY",
		needleSets: [["lin_api_"]],
	},
	// Resend
	{
		pattern: /\bre_[a-zA-Z0-9]{20,}\b/g,
		label: "RESEND_KEY",
		needleSets: [["re_"]],
	},
	// GitLab PAT
	{
		pattern: /\bglpat-[a-zA-Z0-9_-]{20}\b/g,
		label: "GITLAB_TOKEN",
		needleSets: [["glpat-"]],
	},
	// HuggingFace access token
	{
		pattern: /\bhf_[a-zA-Z0-9]{34,}\b/g,
		label: "HUGGINGFACE_TOKEN",
		needleSets: [["hf_"]],
	},
	// Notion internal integration token
	{
		pattern: /\bsecret_[a-zA-Z0-9]{43}\b/g,
		label: "NOTION_TOKEN",
		needleSets: [["secret_"]],
	},
	// DigitalOcean access token
	{
		pattern: /\bdop_v1_[a-f0-9]{64}\b/g,
		label: "DIGITALOCEAN_TOKEN",
		needleSets: [["dop_v1_"]],
	},
	// Mailgun API key
	{
		pattern: /\bkey-[a-f0-9]{32}\b/g,
		label: "MAILGUN_KEY",
		needleSets: [["key-"]],
	},
	// Shopify (pat/secret/app/ca)
	{
		pattern: /\bsh(?:pat|pss|pca|ppa)_[a-zA-Z0-9]{32}\b/g,
		label: "SHOPIFY_TOKEN",
		needleSets: [["shpat_"], ["shpss_"], ["shpca_"], ["shppa_"]],
	},
	// JFrog / Artifactory token
	{
		pattern: /\bcmVmdGtu[a-zA-Z0-9_-]{40,}\b/g,
		label: "JFROG_TOKEN",
		needleSets: [["cmVmdGtu"]],
	},
	// Square (access/secret)
	{
		pattern: /\bsq0(?:atp|csp)-[a-zA-Z0-9_-]{22,}\b/g,
		label: "SQUARE_TOKEN",
		needleSets: [["sq0atp-"], ["sq0csp-"]],
	},
	// Atlassian (Jira/Confluence PAT)
	{
		pattern: /\bATATT3[A-Za-z0-9_-]{60,}\b/g,
		label: "ATLASSIAN_TOKEN",
		needleSets: [["ATATT3"]],
	},
	// Generic JWT (header.payload.signature; distinct from Supabase-specific)
	{
		pattern: /\beyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g,
		label: "JWT",
		needleSets: [["eyJ"]],
	},
	// Alibaba / Aliyun Access Key ID
	{
		pattern: /\bLTAI[a-zA-Z0-9]{12,}\b/g,
		label: "ALIYUN_KEY",
		needleSets: [["LTAI"]],
	},
	// Tencent Cloud SecretId
	{
		pattern: /\bAKID[a-zA-Z0-9]{32,}\b/g,
		label: "TENCENT_KEY",
		needleSets: [["AKID"]],
	},
	// Sentry org auth token
	{
		pattern: /\bsntrys_[a-zA-Z0-9_-]{40,}\b/g,
		label: "SENTRY_TOKEN",
		needleSets: [["sntrys_"]],
	},
	// Docker personal access token
	{
		pattern: /\bdckr_pat_[a-zA-Z0-9_-]{27,}\b/g,
		label: "DOCKER_TOKEN",
		needleSets: [["dckr_pat_"]],
	},
	// HashiCorp Vault service token
	{
		pattern: /\bhvs\.[a-zA-Z0-9_-]{40,}\b/g,
		label: "VAULT_TOKEN",
		needleSets: [["hvs."]],
	},
	// Slack incoming webhook URL
	{
		pattern: /\bhttps:\/\/hooks\.slack\.com\/services\/[A-Za-z0-9_/-]{20,}\b/g,
		label: "SLACK_WEBHOOK",
		needleSets: [["hooks.slack.com/services"]],
	},
	// Sentry DSN
	{
		pattern: /\bhttps:\/\/[a-f0-9]{32}@o\d+\.ingest\.[a-z.]*sentry\.io\/\d+\b/gi,
		label: "SENTRY_DSN",
		needleSets: [["ingest", "sentry.io"]],
	},
	// Google OAuth access token
	{
		pattern: /\bya29\.[a-zA-Z0-9_-]{20,}\b/g,
		label: "GOOGLE_OAUTH",
		needleSets: [["ya29."]],
	},
	// Mailchimp API key (<32>-us<datacenter>)
	{
		pattern: /\b[a-zA-Z0-9]{32}-us\d{1,2}\b/g,
		label: "MAILCHIMP_KEY",
		needleSets: [["-us"]],
	},
];

export const structuralPatterns: StructuralPattern[] = [
	// Generic key=value assignments where key suggests a secret
	{
		pattern:
			/\b(api[_-]?key|api[_-]?secret|access[_-]?key)\s*[=:]\s*['"]?([a-zA-Z0-9_/.+=-]{16,})['"]?/gi,
		replacement: "$1=[REDACTED]",
		needleSets: [["key"], ["api"]],
	},
	{
		pattern:
			/\b(secret[_-]?key|private[_-]?key|auth[_-]?token|access[_-]?token|refresh[_-]?token)\s*[=:]\s*['"]?([^\s'"]{8,})['"]?/gi,
		replacement: "$1=[REDACTED]",
		needleSets: [["key"], ["token"]],
	},
	{
		pattern:
			/\b(postmark[_-]?(?:server[_-]?)?token)\s*[=:]\s*['"]?([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})['"]?/gi,
		replacement: "$1=[REDACTED]",
		needleSets: [["postmark"]],
	},
	{
		pattern:
			/(["'])([a-zA-Z0-9_-]*(?:token|secret|credential)[a-zA-Z0-9_-]*)\1\s*:\s*(["'])([^"'\s]{8,})\3/gi,
		replacement: "$1$2$1:$3[REDACTED]$3",
		needleSets: [["token"], ["secret"], ["credential"]],
	},
	{
		pattern:
			/\b([a-zA-Z0-9_-]*(?:token|secret|credential)[a-zA-Z0-9_-]*)\s*[=:]\s*['"]?([^\s'"]{8,})['"]?/gi,
		replacement: "$1=[REDACTED]",
		needleSets: [["token"], ["secret"], ["credential"]],
	},
	{
		pattern: /\b(password|passwd|pwd|pass)\s*[=:]\s*['"]?([^\s'"]{4,})['"]?/gi,
		replacement: "$1=[REDACTED]",
		needleSets: [["pass"], ["pwd"]],
	},
	// Bearer tokens
	{
		pattern: /\b(bearer)\s+([a-zA-Z0-9._-]{20,})\b/gi,
		replacement: "Bearer [REDACTED]",
		needleSets: [["bearer"]],
	},
	// Authorization headers
	{
		pattern: /(Authorization:\s*(?:Bearer|Basic|Token)\s+)([^\s]{8,})/gi,
		replacement: "$1[REDACTED]",
		needleSets: [["authorization"]],
	},
	// Database connection strings
	{
		pattern:
			/((?:mongodb|postgres(?:ql)?|mysql|redis|amqp|nats|clickhouse)(?:\+srv)?:\/\/[^:]*:)[^@]+(@)/gi,
		replacement: "$1[REDACTED]$2",
		needleSets: [["://"]],
	},
	// PEM private keys (multiline)
	{
		pattern:
			/-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----/g,
		replacement: "[PRIVATE_KEY_REDACTED]",
		needleSets: [["-----BEGIN"]],
	},
	// AWS secret access key pattern (40 char base64 following a label)
	{
		pattern: /(aws_secret_access_key\s*[=:]\s*['"]?)[a-zA-Z0-9/+=]{40}['"]?/gi,
		replacement: "$1[REDACTED]",
		needleSets: [["aws_secret"]],
	},
];

// Required-literal prefilters: each pattern lists needle sets (outer OR,
// inner AND). The regex runs only when at least one set is fully present.
// `ci` follows the pattern's `i` flag (needles checked against lowercased input).
type CompiledNeedle = {
	readonly needle: string;
	readonly codes: Int32Array;
	readonly pairCodes: Int32Array;
};
type CompiledNeedleSet = readonly CompiledNeedle[];
type CompiledPatternNeedles = {
	readonly ci: boolean;
	readonly sets: readonly CompiledNeedleSet[];
};

function lowerCode(c: number): number {
	return c >= 65 && c <= 90 ? c + 32 : c;
}

function compileNeedles(
	patterns: readonly (TokenPattern | StructuralPattern)[],
): CompiledPatternNeedles[] {
	return patterns.map(({ needleSets, pattern }) => {
		const ci = pattern.ignoreCase;
		return {
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
		};
	});
}

const compiledTokenNeedles = compileNeedles(tokenPatterns);
const compiledStructuralNeedles = compileNeedles(structuralPatterns);

// Scratch state for a single needle-evaluation pass (no reentrancy: replace
// callbacks never call back into the redaction path). The pair bitmap uses a
// generation counter so stale bits never need a 16KB clear per call.
const charBits = new Uint8Array(128);
const pairBits = new Uint8Array(128 * 128);
let pairBitsGen = 0;
const tokenFlags = new Uint8Array(tokenPatterns.length);
const structuralFlags = new Uint8Array(structuralPatterns.length);
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
