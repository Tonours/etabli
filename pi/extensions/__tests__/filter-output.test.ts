import { describe, expect, test } from "bun:test";
import filterOutput, {
	redactInlineSecrets,
	redactStructural,
	redactTokens,
	structuralPatterns,
	tokenPatterns,
} from "../filter-output.ts";

type TextContent = { type: "text"; text: string };
type NotifyLevel = "info" | "warning" | "error";
type Notification = { message: string; level: NotifyLevel };
type ToolResultEvent = {
	isError?: boolean;
	content: TextContent[];
	toolName: string;
	input: Record<string, unknown>;
};
type ToolResultResponse = { content: TextContent[] };
type ToolContext = {
	ui: {
		notifications: Notification[];
		notify(message: string, level: NotifyLevel): void;
	};
};
type ToolResultHandler = (
	event: ToolResultEvent,
	ctx: ToolContext,
) => Promise<ToolResultResponse | undefined>;

function setupExtension(): ToolResultHandler {
	let handler: ToolResultHandler | undefined;
	const pi = {
		on(event: "tool_result", nextHandler: ToolResultHandler): void {
			if (event === "tool_result") handler = nextHandler;
		},
	};

	filterOutput(pi as unknown as Parameters<typeof filterOutput>[0]);

	if (!handler) throw new Error("tool_result handler not registered");
	return handler;
}

function createContext(): ToolContext {
	const notifications: Notification[] = [];

	return {
		ui: {
			notifications,
			notify(message: string, level: NotifyLevel) {
				notifications.push({ message, level });
			},
		},
	};
}

function ungatedRedact(text: string): string {
	return redactStructural(redactTokens(text).result).result;
}

describe("filter-output", () => {
	test("labels Anthropic and OpenAI keys distinctly", async () => {
		const handler = setupExtension();
		const ctx = createContext();
		const anthropicKey = `sk-ant-${"a".repeat(24)}`;
		const openAiKey = `sk-proj-${"b".repeat(24)}`;

		const result = await handler(
			{
				content: [
					{
						type: "text",
						text: `anthropic=${anthropicKey}\nopenai=${openAiKey}`,
					},
				],
				input: {},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toContain("[ANTHROPIC_KEY_REDACTED]");
		expect(result?.content[0]?.text).toContain("[OPENAI_KEY_REDACTED]");
		expect(result?.content[0]?.text).not.toContain(anthropicKey);
		expect(result?.content[0]?.text).not.toContain(openAiKey);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacted 2 secrets from output", level: "warning" },
		]);
	});

	test("keeps ordinary UUIDs but redacts contextual Postmark tokens", async () => {
		const handler = setupExtension();
		const ctx = createContext();
		const businessId = "123e4567-e89b-12d3-a456-426614174000";
		const postmarkToken = [
			"89abcdef",
			"0123",
			"4567",
			"89ab",
			"cdef01234567",
		].join("-");

		const result = await handler(
			{
				content: [
					{
						type: "text",
						text: `order_id=${businessId}\npostmark_server_token=${postmarkToken}`,
					},
				],
				input: {},
				toolName: "read",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toContain(`order_id=${businessId}`);
		expect(result?.content[0]?.text).toContain(
			"postmark_server_token=[REDACTED]",
		);
		expect(result?.content[0]?.text).not.toContain(postmarkToken);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacted 1 secret from output", level: "warning" },
		]);
	});

	test("redacts secrets from every text content chunk", async () => {
		const handler = setupExtension();
		const ctx = createContext();
		const openAiKey = `sk-proj-${"c".repeat(24)}`;

		const result = await handler(
			{
				content: [
					{ type: "text", text: "first chunk has no secret" },
					{ type: "text", text: `second chunk has ${openAiKey}` },
				],
				input: {},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content).toEqual([
			{ type: "text", text: "first chunk has no secret" },
			{ type: "text", text: "second chunk has [OPENAI_KEY_REDACTED]" },
		]);
		expect(result?.content[1]?.text).not.toContain(openAiKey);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacted 1 secret from output", level: "warning" },
		]);
	});

	test("redacts generic token and secret assignments by contextual name", async () => {
		const handler = setupExtension();
		const ctx = createContext();
		const postmarkToken = "plain-postmark-token-value";
		const jwtSecret = "plain-jwt-secret-value";

		const result = await handler(
			{
				content: [
					{
						type: "text",
						text: `POSTMARK_TOKEN=${postmarkToken}\nJWT_SECRET="${jwtSecret}"`,
					},
				],
				input: {},
				toolName: "read",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toContain("POSTMARK_TOKEN=[REDACTED]");
		expect(result?.content[0]?.text).toContain("JWT_SECRET=[REDACTED]");
		expect(result?.content[0]?.text).not.toContain(postmarkToken);
		expect(result?.content[0]?.text).not.toContain(jwtSecret);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacted 2 secrets from output", level: "warning" },
		]);
	});

	test("redacts generic token and secret JSON fields by contextual name", async () => {
		const handler = setupExtension();
		const ctx = createContext();
		const postmarkToken = "plain-postmark-token-value";
		const jwtSecret = "plain-jwt-secret-value";

		const result = await handler(
			{
				content: [
					{
						type: "text",
						text: `{"POSTMARK_TOKEN":"${postmarkToken}","JWT_SECRET":"${jwtSecret}"}`,
					},
				],
				input: {},
				toolName: "read",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toContain('"POSTMARK_TOKEN":"[REDACTED]"');
		expect(result?.content[0]?.text).toContain('"JWT_SECRET":"[REDACTED]"');
		expect(result?.content[0]?.text).not.toContain(postmarkToken);
		expect(result?.content[0]?.text).not.toContain(jwtSecret);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacted 2 secrets from output", level: "warning" },
		]);
	});

	test("redacts gated token prefixes mid-text and uppercase structural secrets", async () => {
		const handler = setupExtension();
		const ctx = createContext();
		const openAiKey = `sk-proj-${"d".repeat(24)}`;
		const password = "UpperCasePasswordValue";

		const result = await handler(
			{
				content: [
					{
						type: "text",
						text: `prefix ${openAiKey} suffix\nPASSWORD=${password}`,
					},
				],
				input: {},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toContain("[OPENAI_KEY_REDACTED]");
		expect(result?.content[0]?.text).toContain("PASSWORD=[REDACTED]");
		expect(result?.content[0]?.text).not.toContain(openAiKey);
		expect(result?.content[0]?.text).not.toContain(password);
	});

	test("gated inline redaction matches an ungated full sweep", () => {
		const tokenSamples = [
			`sk-ant-${"a".repeat(24)}`,
			`sk-proj-${"b".repeat(24)}`,
			`ghp_${"A".repeat(36)}`,
			`github_pat_${"A".repeat(20)}`,
			`xoxb-${"A".repeat(10)}`,
			`AKIA${"A".repeat(16)}`,
			`ASIA${"A".repeat(16)}`,
			`sk_live_${"a".repeat(20)}`,
			`pk_test_${"b".repeat(20)}`,
			`rk_live_${"c".repeat(20)}`,
			`whsec_${"d".repeat(20)}`,
			`VERCEL_${"A".repeat(20)}`,
			`sbp_${"e".repeat(20)}`,
			"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abc.def",
			`CF_${"f".repeat(37)}`,
			`npm_${"g".repeat(36)}`,
			`pypi-${"h".repeat(20)}`,
			`SK${"a".repeat(32)}`,
			`SG.${"i".repeat(22)}.${"j".repeat(20)}`,
			`AIza${"k".repeat(35)}`,
			`dp.st.${"l".repeat(20)}`,
			`AGE-SECRET-KEY-${"A".repeat(59)}`,
			`glc_${"m".repeat(32)}`,
			`lin_api_${"n".repeat(40)}`,
			`re_${"o".repeat(20)}`,
			`glpat-${"G".repeat(20)}`,
			`hf_${"G".repeat(34)}`,
			`secret_${"G".repeat(43)}`,
			`dop_v1_${"1".repeat(64)}`,
			`key-${"1".repeat(32)}`,
			`shpat_${"G".repeat(32)}`,
			`cmVmdGtu${"G".repeat(40)}`,
			`sq0atp-${"G".repeat(22)}`,
			`ATATT3${"G".repeat(60)}`,
			`eyJ${"a".repeat(10)}.eyJ${"a".repeat(10)}.${"a".repeat(10)}`,
			`LTAI${"G".repeat(16)}`,
			`AKID${"G".repeat(32)}`,
			`sntrys_${"G".repeat(40)}`,
			`dckr_pat_${"G".repeat(36)}`,
			`hvs.${"G".repeat(90)}`,
			`https://hooks.slack.com/services/T${"G".repeat(8)}/B${"G".repeat(8)}/${"G".repeat(24)}`,
			`https://${"1".repeat(32)}@o${"1".repeat(6)}.ingest.sentry.io/123`,
			`ya29.${"G".repeat(40)}`,
			`${"G".repeat(32)}-us21`,
		];
		const structuralSamples = [
			`api_key=${"a".repeat(16)}`,
			`secret_key=${"b".repeat(8)}`,
			[
				"postmark_server_token",
				["89abcdef", "0123", "4567", "89ab", "cdef01234567"].join("-"),
			].join("="),
			`"client_token":"${"c".repeat(8)}"`,
			`custom_credential=${"d".repeat(8)}`,
			"PASSWORD=MixedCaseValue",
			`Bearer ${"e".repeat(20)}`,
			`Authorization: Basic ${"f".repeat(8)}`,
			"postgres://user:pass@example.test/db",
			`-----BEGIN PRIVATE KEY-----\n${"g".repeat(64)}\n-----END PRIVATE KEY-----`,
			`aws_secret_access_key=${"A".repeat(40)}`,
		];
		const cleanSamples = [
			'export const value = "plain";',
			"README.md: mentions env example only",
			'{"public_url":"https://example.test"}',
			"task list done",
			"src/index.ts:TODO",
		];
		const extraSamples = [`VerCel_${"p".repeat(20)}`, `cF_${"q".repeat(37)}`];

		expect(tokenSamples).toHaveLength(tokenPatterns.length);
		expect(structuralSamples).toHaveLength(structuralPatterns.length);

		for (const sample of [
			...tokenSamples,
			...structuralSamples,
			...cleanSamples,
			...extraSamples,
		]) {
			const input = `before ${sample} after`;
			const gated = redactInlineSecrets(input).result;
			const ungated = ungatedRedact(input);
			expect(gated).toBe(ungated);
			// Every token/structural sample must actually be redacted — guards the
			// required-literal prefilter tables against a needle that would skip
			// a pattern that should have matched.
			if (
				tokenSamples.includes(sample) ||
				structuralSamples.includes(sample) ||
				extraSamples.includes(sample)
			) {
				expect(gated).not.toBe(input);
			}
		}
	});

	test("allows example env file command output", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: "cat .env.example" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});

	test("blocks piped env dumps", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "env | grep POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks env dumps with inline assignments", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "POSTMARK_TOKEN=example-token\nFOO=bar" },
				],
				input: { command: "env FOO=bar | grep POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks env dumps after pipeline separators", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "true | env | grep POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks env dumps inside quoted subshell commands", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "bash -lc 'env | grep POSTMARK_TOKEN'" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks env dumps inside quoted login shell commands", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "bash -l -c 'env | grep POSTMARK_TOKEN'" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("allows commands that only print the word env", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "env" }],
				input: { command: "echo env | cat" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});

	test("blocks shell variable dumps", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "set | grep POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks declared shell variable dumps", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: 'declare -x POSTMARK_TOKEN="example-token"' },
				],
				input: { command: "declare -p | grep POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks export dumps without explicit -p", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: 'declare -x POSTMARK_TOKEN="example-token"' },
				],
				input: { command: "export | grep POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("allows shell option setup commands", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "" }],
				input: { command: "set -e" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});

	test("blocks local env file command output", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: "cat .env.local" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks sensitive files read through process substitution", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "diff <(cat .env.local) README.md" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks direnv file command output", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "export SECRET_KEY=example" }],
				input: { command: "cat .envrc" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks shell input redirection from sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: "cat<.env.local" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks sourcing sensitive env files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: '. .env.local && echo "$PUBLIC_API_URL"' },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks search commands that read local env files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: "rg PUBLIC_API_URL .env.local" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks search commands that include sensitive file globs", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: "rg --glob .env.local PUBLIC_API_URL ." },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks search commands with attached sensitive short globs", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: "rg -g.env.local PUBLIC_API_URL ." },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks search commands with equals-attached sensitive short globs", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "PUBLIC_API_URL=https://example.test" },
				],
				input: { command: "rg -g=.env.local PUBLIC_API_URL ." },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks ripgrep commands that read sensitive pattern files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "src/index.ts:match" }],
				input: { command: "rg -f .env.local ." },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks grep commands that read sensitive pattern files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "README.md:match" }],
				input: { command: "grep --file=.env.local README.md" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks search commands that read other sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: '"password":"example"' }],
				input: { command: "grep password secrets.json" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks recursive grep over broad paths that may traverse sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "./.env.local:POSTMARK_TOKEN=example-token" },
				],
				input: { command: "grep -R POSTMARK_TOKEN ." },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks recursive grep without explicit paths", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "grep -Rh POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks hidden ripgrep over broad paths that may traverse sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: ".env.local:POSTMARK_TOKEN=example-token" },
				],
				input: { command: "rg --hidden POSTMARK_TOKEN ." },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks hidden ripgrep without explicit paths", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "rg --hidden --no-heading POSTMARK_TOKEN" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks search output that reports matches from sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{
						type: "text",
						text: 'config/secrets.json:1:{"password":"example"}',
					},
				],
				input: { command: "rg password config" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks structured readers that read sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: '{"password":"example"}' }],
				input: { command: "jq . secrets.json" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks encoded readers that read sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{ type: "text", text: "UE9TVE1BUktfVE9LRU49ZXhhbXBsZS10b2tlbgo=" },
				],
				input: { command: "base64 .env.local" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks hex and string readers that read sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [
					{
						type: "text",
						text: "00000000: 504f 5354 4d41 524b 5f54 4f4b 454e",
					},
				],
				input: { command: "xxd .env.local" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks inline Python reads of sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: { command: "python -c 'print(open(\".env.local\").read())'" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks inline Node reads of sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: {
					command:
						'node -e \'console.log(require("fs").readFileSync(".env.local", "utf8"))\'',
				},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks inline Node print-mode reads of sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: {
					command:
						'node -p \'require("fs").readFileSync(".env.local", "utf8")\'',
				},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks inline Node long-option reads of sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: {
					command:
						'node --eval \'console.log(require("fs").readFileSync(".env.local", "utf8"))\'',
				},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks inline Node stream reads of sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: {
					command:
						'node -e \'require("fs").createReadStream(".env.local").pipe(process.stdout)\'',
				},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("blocks inline Deno and Bun reads of sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const denoResult = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: {
					command:
						"deno eval 'console.log(await Deno.readTextFile(\".env.local\"))'",
				},
				toolName: "bash",
			},
			ctx,
		);
		const bunResult = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: {
					command:
						"bun -e 'console.log(await Bun.file(\".env.local\").text())'",
				},
				toolName: "bash",
			},
			ctx,
		);

		expect(denoResult?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(bunResult?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("allows inline interpreter commands that only mention sensitive filenames", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: ".env.local" }],
				input: { command: "python -c 'print(\".env.local\")'" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});

	test("allows inline Node print-mode commands that only mention sensitive filenames", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: ".env.local" }],
				input: { command: "node --print '\".env.local\"'" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});

	test("blocks interpreter heredocs that read sensitive files", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "POSTMARK_TOKEN=example-token" }],
				input: {
					command: [
						"python <<'PY'",
						"print(open('.env.local').read())",
						"PY",
					].join("\n"),
				},
				toolName: "bash",
			},
			ctx,
		);

		expect(result?.content[0]?.text).toBe(
			"[Output redacted — command reads sensitive data]",
		);
		expect(ctx.ui.notifications).toEqual([
			{ message: "Redacting output of sensitive command", level: "warning" },
		]);
	});

	test("allows interpreter heredocs that only mention sensitive filenames", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: ".env.local" }],
				input: {
					command: ["python <<'PY'", "print('.env.local')", "PY"].join("\n"),
				},
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});

	test("allows search patterns that look like sensitive filenames when safe files are searched", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "README.md:mentions secrets.json" }],
				input: { command: "rg secrets.json README.md" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});

	test("allows focused code searches in ordinary source directories", async () => {
		const handler = setupExtension();
		const ctx = createContext();

		const result = await handler(
			{
				content: [{ type: "text", text: "src/index.ts:TODO" }],
				input: { command: "rg TODO src" },
				toolName: "bash",
			},
			ctx,
		);

		expect(result).toBeUndefined();
		expect(ctx.ui.notifications).toEqual([]);
	});
});
