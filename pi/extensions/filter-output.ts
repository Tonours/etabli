import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/**
 * Filter Output — POST-EXECUTION secret redaction for tool results.
 *
 * Security layer 2 of 2 (with damage-control.ts):
 *   - damage-control.ts → intercepts tool_call BEFORE execution → blocks or asks
 *   - filter-output.ts  → intercepts tool_result AFTER execution  → redacts secrets
 *
 * Redacts sensitive data (API keys, tokens, secrets, credentials) from tool
 * output before the LLM sees it. Covers both `read` (file reads) and `bash`
 * (command output) to prevent accidental secret leakage.
 */
export default function (pi: ExtensionAPI) {
  // ---------------------------------------------------------------------------
  // Token patterns — prefixed / structurally identifiable keys
  // ---------------------------------------------------------------------------
  const tokenPatterns: { pattern: RegExp; label: string }[] = [
    // OpenAI (sk-proj-... is the new format, sk-... is legacy)
    { pattern: /\bsk-(?:proj-)?[a-zA-Z0-9_-]{20,}\b/g, label: "OPENAI_KEY" },
    // Anthropic
    { pattern: /\bsk-ant-[a-zA-Z0-9_-]{20,}\b/g, label: "ANTHROPIC_KEY" },
    // GitHub (PAT, OAuth, app, refresh tokens)
    { pattern: /\bg(?:hp|ho|hs|hu|hr)_[a-zA-Z0-9]{36,}\b/g, label: "GITHUB_TOKEN" },
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
    { pattern: /\brk_(?:live|test)_[a-zA-Z0-9]{20,}\b/g, label: "STRIPE_RESTRICTED" },
    { pattern: /\bwhsec_[a-zA-Z0-9]{20,}\b/g, label: "STRIPE_WEBHOOK" },
    // Vercel
    { pattern: /\bvercel_[a-zA-Z0-9_-]{20,}\b/gi, label: "VERCEL_TOKEN" },
    // Supabase
    { pattern: /\bsbp_[a-zA-Z0-9]{20,}\b/g, label: "SUPABASE_KEY" },
    { pattern: /\beyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/g, label: "SUPABASE_JWT" },
    // Cloudflare
    { pattern: /\bcf_[a-zA-Z0-9_-]{37,}\b/gi, label: "CLOUDFLARE_TOKEN" },
    // npm
    { pattern: /\bnpm_[a-zA-Z0-9]{36,}\b/g, label: "NPM_TOKEN" },
    // PyPI
    { pattern: /\bpypi-[a-zA-Z0-9_-]{20,}\b/g, label: "PYPI_TOKEN" },
    // Twilio
    { pattern: /\bSK[a-f0-9]{32}\b/g, label: "TWILIO_KEY" },
    // SendGrid
    { pattern: /\bSG\.[a-zA-Z0-9_-]{22,}\.[a-zA-Z0-9_-]{20,}\b/g, label: "SENDGRID_KEY" },
    // Firebase / Google service account
    { pattern: /\bAIza[a-zA-Z0-9_-]{35}\b/g, label: "GOOGLE_API_KEY" },
    // Doppler
    { pattern: /\bdp\.(?:st|ct|sa|scrt)\.[a-zA-Z0-9_-]{20,}\b/g, label: "DOPPLER_TOKEN" },
    // age encryption
    { pattern: /\bAGE-SECRET-KEY-[A-Z0-9]{59}\b/g, label: "AGE_SECRET_KEY" },
    // Grafana
    { pattern: /\bglc_[a-zA-Z0-9_-]{32,}\b/g, label: "GRAFANA_TOKEN" },
    // Linear
    { pattern: /\blin_api_[a-zA-Z0-9]{40,}\b/g, label: "LINEAR_KEY" },
    // Postmark
    { pattern: /\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b/g, label: "UUID" },
    // Resend
    { pattern: /\bre_[a-zA-Z0-9]{20,}\b/g, label: "RESEND_KEY" },
  ];

  // ---------------------------------------------------------------------------
  // Structural patterns — values identifiable by surrounding context
  // ---------------------------------------------------------------------------
  const structuralPatterns: { pattern: RegExp; replacement: string }[] = [
    // Generic key=value assignments where key suggests a secret
    {
      pattern: /\b(api[_-]?key|api[_-]?secret|access[_-]?key)\s*[=:]\s*['"]?([a-zA-Z0-9_\/.+=-]{16,})['"]?/gi,
      replacement: "$1=[REDACTED]",
    },
    {
      pattern: /\b(secret[_-]?key|private[_-]?key|auth[_-]?token|access[_-]?token|refresh[_-]?token)\s*[=:]\s*['"]?([^\s'"]{8,})['"]?/gi,
      replacement: "$1=[REDACTED]",
    },
    {
      pattern: /\b(password|passwd|pwd|pass)\s*[=:]\s*['"]?([^\s'"]{4,})['"]?/gi,
      replacement: "$1=[REDACTED]",
    },
    // Bearer tokens
    { pattern: /\b(bearer)\s+([a-zA-Z0-9._-]{20,})\b/gi, replacement: "Bearer [REDACTED]" },
    // Authorization headers
    { pattern: /(Authorization:\s*(?:Bearer|Basic|Token)\s+)([^\s]{8,})/gi, replacement: "$1[REDACTED]" },
    // Database connection strings
    { pattern: /((?:mongodb|postgres(?:ql)?|mysql|redis|amqp|nats|clickhouse)(?:\+srv)?:\/\/[^:]*:)[^@]+(@)/gi, replacement: "$1[REDACTED]$2" },
    // PEM private keys (multiline)
    {
      pattern: /-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----/g,
      replacement: "[PRIVATE_KEY_REDACTED]",
    },
    // AWS secret access key pattern (40 char base64 following a label)
    { pattern: /(aws_secret_access_key\s*[=:]\s*['"]?)[a-zA-Z0-9/+=]{40}['"]?/gi, replacement: "$1[REDACTED]" },
  ];

  // ---------------------------------------------------------------------------
  // Sensitive file patterns — block entire file reads
  // ---------------------------------------------------------------------------
  const sensitiveFiles: RegExp[] = [
    /\.env$/,                                        // .env
    /\.env\.(?!example$|sample$|template$)[^/]+$/,   // .env.local, .env.production (NOT .env.example/sample/template)
    /\.dev\.vars$/,                                  // Cloudflare .dev.vars
    /secrets?\.(json|ya?ml|toml)$/i,                 // secrets.json, secret.yaml
    /(?:^|\/)auth\.json$/i,                          // auth.json (OAuth/API secrets)
    /(?:^|\/).*\.token$/i,                           // *.token
    /(?:^|\/).*\.secrets\.json$/i,                  // *.secrets.json
    /credentials(\.json|\.ya?ml|\.toml)?$/i,         // credentials, credentials.json
    /\.(?:pem|key|p12|pfx|jks|keystore|kdbx)$/i,    // crypto key files
    /(?:^|\/)id_(?:rsa|ed25519|ecdsa|dsa)$/,         // SSH private keys
    /(?:^|\/)\.ssh\/(?!config$|known_hosts$)[^/]+$/, // .ssh/* except config and known_hosts
    /(?:^|\/)\.netrc$/,                              // .netrc (plaintext credentials)
    /(?:^|\/)\.htpasswd$/,                           // Apache htpasswd
    /(?:^|\/)\.pgpass$/,                             // PostgreSQL password file
    /(?:^|\/)\.npmrc$/,                              // npm config (can contain tokens)
    /(?:^|\/)\.pypirc$/,                             // PyPI config (can contain tokens)
    /(?:^|\/)\.docker\/config\.json$/,               // Docker credentials
  ];

  // ---------------------------------------------------------------------------
  // Sensitive bash commands — detect when bash reads sensitive files
  // ---------------------------------------------------------------------------
  const sensitiveCommandPatterns: RegExp[] = [
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*\.env\b/,
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*auth\.json\b/i,
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*\.token\b/i,
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*secrets?\.\w+/i,
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*credentials/i,
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*\.pem\b/,
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*id_(?:rsa|ed25519|ecdsa|dsa)\b/,
    /\b(?:cat|less|more|head|tail|bat|sed|awk)\s+[^\s|;]*\.key\b/,
    /\bprintenv\b/,
    /\benv\s*$/m,
    /\bexport\s+-p\b/,
  ];

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  function redactTokens(text: string): { result: string; count: number } {
    let count = 0;
    let result = text;
    for (const { pattern, label } of tokenPatterns) {
      // Reset lastIndex for safety (stateful /g regexes)
      pattern.lastIndex = 0;
      const newResult = result.replace(pattern, () => {
        count++;
        return `[${label}_REDACTED]`;
      });
      result = newResult;
    }
    return { result, count };
  }

  function redactStructural(text: string): { result: string; count: number } {
    let count = 0;
    let result = text;
    for (const { pattern, replacement } of structuralPatterns) {
      pattern.lastIndex = 0;
      const newResult = result.replace(pattern, (...args) => {
        count++;
        // Reconstruct replacement with captured groups
        return replacement.replace(/\$(\d)/g, (_, n) => args[parseInt(n)] || "");
      });
      result = newResult;
    }
    return { result, count };
  }

  function isSensitiveFile(filePath: string): boolean {
    return sensitiveFiles.some((p) => p.test(filePath));
  }

  function isSensitiveCommand(command: string): boolean {
    return sensitiveCommandPatterns.some((p) => p.test(command));
  }

  // ---------------------------------------------------------------------------
  // Hook: tool_result
  // ---------------------------------------------------------------------------
  pi.on("tool_result", async (event, ctx) => {
    if (event.isError) return undefined;

    const textContent = event.content.find(
      (c): c is { type: "text"; text: string } => c.type === "text",
    );
    if (!textContent) return undefined;

    // -- Block sensitive file reads --
    if (event.toolName === "read") {
      const filePath = (event.input.path ?? event.input.file_path ?? "") as string;
      if (isSensitiveFile(filePath)) {
        ctx.ui.notify(`Blocked read of sensitive file: ${filePath}`, "warning");
        return {
          content: [{ type: "text", text: `[Contents of ${filePath} redacted — sensitive file]` }],
        };
      }
    }

    // -- Block bash commands that dump sensitive files or env --
    if (event.toolName === "bash" || event.toolName === "shell") {
      const command = (event.input.command ?? event.input.cmd ?? "") as string;
      if (isSensitiveCommand(command)) {
        ctx.ui.notify(`Redacting output of sensitive command`, "warning");
        return {
          content: [{ type: "text", text: `[Output redacted — command reads sensitive data]` }],
        };
      }
    }

    // -- Redact inline secrets from any tool output --
    let result = textContent.text;
    const tokens = redactTokens(result);
    result = tokens.result;
    const structural = redactStructural(result);
    result = structural.result;

    const totalRedactions = tokens.count + structural.count;
    if (totalRedactions > 0) {
      ctx.ui.notify(
        `Redacted ${totalRedactions} secret${totalRedactions > 1 ? "s" : ""} from output`,
        "warning",
      );
      return { content: [{ type: "text", text: result }] };
    }

    return undefined;
  });
}
