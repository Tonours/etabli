import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Filter Output — POST-EXECUTION secret redaction for tool results.
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
    // Anthropic
    { pattern: /\bsk-ant-[a-zA-Z0-9_-]{20,}\b/g, label: "ANTHROPIC_KEY" },
    // OpenAI (sk-proj-... is the new format, sk-... is legacy)
    { pattern: /\bsk-(?!ant-)(?:proj-)?[a-zA-Z0-9_-]{20,}\b/g, label: "OPENAI_KEY" },
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
      pattern: /\b(postmark[_-]?(?:server[_-]?)?token)\s*[=:]\s*['"]?([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})['"]?/gi,
      replacement: "$1=[REDACTED]",
    },
    {
      pattern: /(["'])([a-zA-Z0-9_-]*(?:token|secret|credential)[a-zA-Z0-9_-]*)\1\s*:\s*(["'])([^"'\s]{8,})\3/gi,
      replacement: "$1$2$1:$3[REDACTED]$3",
    },
    {
      pattern: /\b([a-zA-Z0-9_-]*(?:token|secret|credential)[a-zA-Z0-9_-]*)\s*[=:]\s*['"]?([^\s'"]{8,})['"]?/gi,
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
    /(?:^|\/)\.envrc$/,                              // direnv .envrc
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
  const readCommandPattern = /\b(cat|less|more|head|tail|bat|sed|awk|jq|yq|grep|rg|ripgrep|base64|xxd|hexdump|od|strings)\s+([^\n|;]+)/gi;
  const inputRedirectionPattern = /(?:^|[^<])\d*<\s*(?![<(&])(['"]?)([^'"\s;&|()]+)\1/g;
  const sourceCommandPattern = /(?:^|[;&|()]\s*)(?:source|\.)\s+(['"]?)([^'"\s;&|()]+)\1/g;
  const shellCommandPattern = /\b(?:bash|sh|zsh)((?:\s+-[A-Za-z-]+)+)\s+(['"])([\s\S]*?)\2/g;
  const inlineInterpreterPattern = /\b(?:python3?|ruby|perl)\s+(?:-[A-Za-z]*[ce][A-Za-z]*|--(?:command|eval))\s+(['"])([\s\S]*?)\1|\bnode\s+(?:-[A-Za-z]*[ep][A-Za-z]*|--(?:eval|print))\s+(['"])([\s\S]*?)\3|\bdeno\s+eval\s+(['"])([\s\S]*?)\5|\bbun\s+(?:-[A-Za-z]*e[A-Za-z]*|--eval)\s+(['"])([\s\S]*?)\7/g;
  const heredocInterpreterPattern = /\b(?:python3?|node|ruby|perl|deno|bun)(?:\s+-)?\s+<<-?\s*['"]?([A-Za-z0-9_]+)['"]?\s*\n([\s\S]*?)\n\1\b/g;
  const inlineFileReadPattern = /\b(?:open|readFile|readFileSync|createReadStream|read_text|read_bytes|File\.read|IO\.read|Bun\.file|Deno\.readTextFile|Deno\.readFile)\b/;
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
        // Reconstruct replacement with captured groups
        const replacementText = replacement.replace(/\$(\d)/g, (_, n) => args[parseInt(n)] || "");
        if (replacementText !== args[0]) {
          count++;
        }
        return replacementText;
      });
      result = newResult;
    }
    return { result, count };
  }

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

  function hasOption(tokens: string[], names: Set<string>, shortFlags: string[]): boolean {
    return tokens.some((token) => {
      if (names.has(token)) return true;
      if (token.startsWith("--")) return false;
      return shortFlags.some((flag) => token.startsWith("-") && token.includes(flag));
    });
  }

  function searchCanTraverseSensitiveFiles(commandName: string, args: string): boolean {
    const normalizedCommand = commandName.toLowerCase();
    const tokens = shellTokens(args);
    const pathTokens = commandPathTokens(commandName, args);
    const hasBroadPath = pathTokens.some(isBroadSearchPath);

    if (normalizedCommand === "grep") {
      const hasRecursiveOption = hasOption(tokens, grepRecursiveOptionNames, ["r", "R"]);
      return hasRecursiveOption && (hasBroadPath || pathTokens.length === 0);
    }

    if (normalizedCommand === "rg" || normalizedCommand === "ripgrep") {
      const hasSensitiveScopeOption = hasOption(tokens, ripgrepSensitiveScopeOptionNames, ["u"]);
      return hasSensitiveScopeOption && (hasBroadPath || pathTokens.length === 0);
    }

    return false;
  }

  function searchOutputReferencesSensitiveFile(commandName: string, output: string): boolean {
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

      const optionWithValue = token.match(/^(--(?:file|glob|iglob|include))=(.+)$/);
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
      const hasCommandOption = shellOptions.split(/\s+/).some((option) => /^-[A-Za-z-]*c[A-Za-z-]*$/.test(option));
      const fragment = hasCommandOption ? match[3] ?? "" : "";
      if (fragment !== "") {
        fragments.push(fragment);
      }
    }

    return fragments;
  }

  function isSensitiveCommand(command: string): boolean {
    return commandFragments(command).some((fragment) => (
      readsSensitiveFile(fragment)
      || inlineCodeReadsSensitiveFile(fragment)
      || heredocCodeReadsSensitiveFile(fragment)
      || sensitiveCommandPatterns.some((p) => p.test(fragment))
    ));
  }

  function outputReferencesSensitiveSearchResult(command: string, output: string): boolean {
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
  pi.on("tool_result", async (event, ctx) => {
    if (event.isError) return undefined;

    const hasTextContent = event.content.some((c) => c.type === "text");
    if (!hasTextContent) return undefined;

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
      const output = event.content
        .filter((content) => content.type === "text")
        .map((content) => content.text)
        .join("\n");
      if (isSensitiveCommand(command) || outputReferencesSensitiveSearchResult(command, output)) {
        ctx.ui.notify(`Redacting output of sensitive command`, "warning");
        return {
          content: [{ type: "text", text: `[Output redacted — command reads sensitive data]` }],
        };
      }
    }

    // -- Redact inline secrets from any tool output --
    let totalRedactions = 0;
    const redactedContent = event.content.map((content) => {
      if (content.type !== "text") return content;

      let text = content.text;
      const tokens = redactTokens(text);
      text = tokens.result;
      const structural = redactStructural(text);
      text = structural.result;
      totalRedactions += tokens.count + structural.count;

      return text === content.text ? content : { ...content, text };
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
