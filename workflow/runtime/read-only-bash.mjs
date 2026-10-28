const READ_ONLY_BASH_COMMANDS = new Set([
	"basename",
	"cat",
	"cd",
	"cut",
	"diff",
	"dirname",
	"echo",
	"grep",
	"head",
	"jq",
	"ls",
	"pwd",
	"rg",
	"sha256sum",
	"shasum",
	"stat",
	"tail",
	"tr",
	"uniq",
	"wc",
	"which",
]);
const ALWAYS_READ_ONLY_GIT_SUBCOMMANDS = new Set([
	"--version",
	"diff",
	"grep",
	"log",
	"ls-files",
	"ls-tree",
	"merge-base",
	"rev-parse",
	"show",
	"status",
]);
const READ_ONLY_GIT_FETCH_FLAGS = new Set(["-q", "--quiet", "--dry-run"]);
const READ_ONLY_GH_COMMANDS = new Set([
	"--version",
	"auth status",
	"issue list",
	"issue view",
	"label list",
	"pr checks",
	"pr diff",
	"pr list",
	"pr status",
	"pr view",
	"release list",
	"release view",
	"repo view",
	"run list",
	"run view",
	"search",
	"workflow list",
	"workflow view",
]);
const GH_WRITE_ARG = /^(?:-X|--method|-f|-F|--raw-field|--field|--input|--web)$/;
const READ_ONLY_GIT_BRANCH_ARGS = new Set([
	"--all",
	"--list",
	"--remotes",
	"--show-current",
	"--verbose",
	"-a",
	"-r",
	"-v",
	"-vv",
]);
// Git accepts any unambiguous prefix of a long option, so `--open-files-in-page`
// runs a pager command too.
const UNSAFE_GIT_LONG_OPTIONS = ["output", "ext-diff", "textconv", "open-files-in-pager", "show-signature", "help"];
const SYSTEM_BIN_EXECUTABLE =
	/^\/(?:s?bin|usr\/s?bin|usr\/local\/bin|opt\/homebrew\/bin)\/[^/]+$/;
const RG_EXEC_OPTION = /^--(?:pre|hostname-bin|search-zip)(?:=|$)|^-[^-]*z/;
const GH_SHORT_WRITE_CLUSTER = /^-[^-]*[XfFw]/;
const EXPANDING_DOLLAR = /^[A-Za-z_{@*#?!$0-9'[-]/;
const ARGV_SENSITIVE_READERS = new Set(["diff", "rg", "uniq"]);

/** Split a simple shell pipeline while respecting quoted search expressions. */
function splitReadOnlyPipeline(command) {
	const value = String(command || "").trim();
	if (!value) return [];
	const segments = [];
	let current = "";
	let quote = "";
	let escaped = false;

	for (let index = 0; index < value.length; index += 1) {
		const character = value[index];
		if (escaped) {
			current += character;
			escaped = false;
			continue;
		}
		if (character === "\\" && quote !== "'") {
			current += character;
			escaped = true;
			continue;
		}
		if (quote) {
			if (
				quote === '"' &&
				(character === "`" || (character === "$" && value[index + 1] === "("))
			) {
				return null;
			}
			current += character;
			if (character === quote) quote = "";
			continue;
		}
		if (character === "'" || character === '"') {
			quote = character;
			current += character;
			continue;
		}
		// Two-char logical operators (&&, ||) join read-only segments.
		if (
			(character === "&" || character === "|") &&
			value[index + 1] === character
		) {
			if (current.trim() === "") return null;
			segments.push(current.trim());
			current = "";
			index += 1;
			continue;
		}
		if (character === "\n" || character === ";") {
			if (current.trim() !== "") segments.push(current.trim());
			current = "";
			continue;
		}
		// Unquoted `#` starts a comment that can hide a quote; `(` and `)` open
		// subshells and zsh process substitutions or glob qualifiers.
		if (
			character === "&" ||
			character === "`" ||
			character === "<" ||
			character === ">" ||
			character === "#" ||
			character === "(" ||
			character === ")" ||
			(character === "$" && value[index + 1] === "(")
		) {
			return null;
		}
		if (character === "|") {
			if (current.trim() === "") return null;
			segments.push(current.trim());
			current = "";
			continue;
		}
		current += character;
	}
	if (quote || escaped) return null;
	if (current.trim() !== "") segments.push(current.trim());
	if (segments.length === 0) return null;
	return segments;
}

function splitShellWords(segment) {
	const words = [];
	let current = "";
	let quote = "";
	let escaped = false;

	for (const character of segment.trim()) {
		if (escaped) {
			current += character;
			escaped = false;
			continue;
		}
		if (character === "\\" && quote !== "'") {
			escaped = true;
			continue;
		}
		if (quote) {
			if (character === quote) quote = "";
			else current += character;
			continue;
		}
		if (character === "'" || character === '"') {
			quote = character;
			continue;
		}
		if (/\s/.test(character)) {
			if (current) {
				words.push(current);
				current = "";
			}
			continue;
		}
		current += character;
	}
	if (escaped || quote) return null;
	if (current) words.push(current);
	return words;
}

function isReadOnlyGitFetch(args) {
	// Configured remote-tracking updates are the read. A destination refspec,
	// a forced refspec, prune, or another option rewrites or deletes refs.
	let sawRemote = false;
	for (const argument of args) {
		if (READ_ONLY_GIT_FETCH_FLAGS.has(argument)) continue;
		if (
			sawRemote ||
			argument.startsWith("-") ||
			argument.startsWith("+") ||
			argument.includes(":")
		) {
			return false;
		}
		sawRemote = true;
	}
	return true;
}

// In a `git grep` cluster, `-O` takes the rest of the word as a pager command
// unless an option that takes a value (`-e`, `-f`, `-A`, `-B`, `-C`, `-m`) comes first.
function isUnsafeGitInspectionArg(argument, subcommand) {
	if (argument.startsWith("-O")) return true;
	if (subcommand === "grep" && /^-[^-efABCm]*O/.test(argument)) return true;
	// `%G` placeholders in a format run the signature verifier.
	if (/%G/.test(argument)) return true;
	const name = /^--([^=]+)/.exec(argument)?.[1];
	return Boolean(name) && UNSAFE_GIT_LONG_OPTIONS.some((option) => option.startsWith(name));
}

function isReadOnlyGitSegment(segment) {
	const words = splitShellWords(segment);
	if (!words || words[0].replace(/^.*\//, "") !== "git") return false;

	let index = 1;
	while (words[index] === "-C") {
		if (!words[index + 1]) return false;
		index += 2;
	}
	const subcommand = words[index];
	if (!subcommand) return false;
	const args = words.slice(index + 1);
	if (args.some((argument) => isUnsafeGitInspectionArg(argument, subcommand))) return false;

	if (ALWAYS_READ_ONLY_GIT_SUBCOMMANDS.has(subcommand)) return true;
	if (subcommand === "fetch") return isReadOnlyGitFetch(args);
	if (subcommand === "branch") {
		return (
			args.length === 0 ||
			args.every((argument) => READ_ONLY_GIT_BRANCH_ARGS.has(argument))
		);
	}
	if (subcommand === "remote") {
		return (
			args.length === 0 ||
			(args.length === 1 && ["-v", "--verbose"].includes(args[0])) ||
			["get-url", "show"].includes(args[0])
		);
	}
	if (subcommand === "tag") {
		return args.length === 0 || ["-l", "--list"].includes(args[0]);
	}
	if (subcommand === "worktree") return args[0] === "list";
	return false;
}

function isReadOnlyGhSegment(segment) {
	const words = splitShellWords(segment);
	if (!words || words[0].replace(/^.*\//, "") !== "gh") return false;

	const args = words.slice(1);
	if (args.length === 0) return false;

	const twoWord = `${args[0]} ${args[1]}`;
	const isAllowlistedCommand =
		READ_ONLY_GH_COMMANDS.has(twoWord) || READ_ONLY_GH_COMMANDS.has(args[0]);
	if (!isAllowlistedCommand && args[0] !== "api") return false;
	if (twoWord === "auth status" && args.some((argument) => /^--show-token(?:=|$)/.test(argument) || /^-[^-]*t/.test(argument))) {
		return false;
	}

	return !args.some((argument, index) => {
		const attachedJq = /^(?:--jq=|-[^-]*?q)(.*)$/.exec(argument);
		let filter = "";
		if (argument === "--jq") filter = args[index + 1] || "";
		else if (attachedJq) filter = attachedJq[1] || args[index + 1] || "";
		if (/\benv\b|\$ENV\b/.test(filter)) return true;
		if (argument === "--method" || argument === "-X") {
			return String(args[index + 1] || "").toUpperCase() !== "GET";
		}
		if (GH_SHORT_WRITE_CLUSTER.test(argument)) return true;
		return GH_WRITE_ARG.test(argument.replace(/=.*$/, ""));
	});
}

function hasPotentialWriteOption(segment, shortOption, longOption) {
	const words = splitShellWords(segment);
	if (!words) return true;
	return words.slice(1).some((argument) => {
		if (
			argument === `--${longOption}` ||
			argument.startsWith(`--${longOption}=`)
		) {
			return true;
		}
		return /^-[^-]/.test(argument) && argument.slice(1).includes(shortOption);
	});
}

function shellHazards(segment) {
	const hazards = { expansion: false, glob: false };
	let quote = "";
	for (let index = 0; index < segment.length; index += 1) {
		const character = segment[index];
		if (quote === "'") {
			if (character === "'") quote = "";
		} else if (character === "\\") {
			if (segment[index + 1] === "\n") hazards.expansion = true;
			index += 1;
		} else if (character === '"') {
			quote = quote ? "" : '"';
		} else if (character === "'" && !quote) {
			quote = "'";
		} else if (character === "$" && (EXPANDING_DOLLAR.test(segment[index + 1] ?? "") || (!quote && segment[index + 1] === '"'))) {
			hazards.expansion = true;
		} else if (!quote && (character === "{" || (character === "=" && /^\s?$/.test(segment[index - 1] ?? "")))) {
			hazards.expansion = true;
		} else if (!quote && /[*?[]/.test(character)) {
			hazards.glob = true;
		}
	}
	return hazards;
}

function isReadOnlyPipelineSegment(segment) {
	const trimmed = segment.trim();
	const invoked = trimmed.match(/^([A-Za-z0-9_./-]+)/)?.[1];
	const hazards = shellHazards(trimmed);
	if (!invoked || hazards.expansion || splitShellWords(trimmed)?.[0] !== invoked) return false;
	if (invoked.includes("/") && !SYSTEM_BIN_EXECUTABLE.test(invoked)) return false;
	const executable = invoked.replace(/^.*\//, "");
	if (!executable) return false;
	if (hazards.glob && (!READ_ONLY_BASH_COMMANDS.has(executable) || ARGV_SENSITIVE_READERS.has(executable))) return false;
	const basenamed =
		executable === invoked
			? trimmed
			: `${executable}${trimmed.slice(invoked.length)}`;
	if (executable === "git") return isReadOnlyGitSegment(basenamed);
	if (executable === "gh") return isReadOnlyGhSegment(basenamed);
	if (executable === "find") {
		const words = splitShellWords(trimmed);
		if (!words) return false;
		const mutatingFindActions = new Set([
			"-delete",
			"-exec",
			"-execdir",
			"-ok",
			"-okdir",
			"-fprint",
			"-fprint0",
			"-fprintf",
			"-fls",
		]);
		return !words.slice(1).some((word) => mutatingFindActions.has(word));
	}
	// sed and awk programs can write or execute without an in-place flag. The
	// read-only agents already have Read/Grep, so deny them rather than parse
	// their command languages here.
	if (executable === "sed" || executable === "awk") return false;
	// sort may spill temporary files or execute --compress-program. Deny it
	// instead of maintaining a fragile option denylist.
	if (executable === "sort") return false;
	if (executable === "diff") {
		// `-l` (`--paginate`) pipes the output through `pr`.
		return !hasPotentialWriteOption(basenamed, "o", "output") && !hasPotentialWriteOption(basenamed, "l", "paginate");
	}
	if (executable === "rg") {
		const words = splitShellWords(basenamed);
		return Boolean(words) && !words.some((word) => RG_EXEC_OPTION.test(word));
	}
	if (executable === "uniq") {
		const words = splitShellWords(basenamed);
		if (!words) return false;
		const rest = words.slice(1);
		let start = rest.findIndex((word) => word === "--" || !/^-./.test(word));
		if (start !== -1 && rest[start] === "--") start += 1;
		return start === -1 || rest.length - start <= 1;
	}
	if (executable === "node" || executable === "nodejs") {
		return /^(?:node|nodejs)\s+--version$/.test(basenamed);
	}
	if (executable === "jq") {
		// jq reads the environment through `env` and `$ENV`, also from a program file.
		const words = splitShellWords(basenamed);
		return Boolean(words) && !words.slice(1).some((word) => /\benv\b|\$ENV\b|^-[^-]*f|^--from-file(?:=|$)/.test(word));
	}
	if (executable === "bash" || executable === "sh") {
		// `-n` alone: an extra option such as `-i` makes the shell run the script.
		return /^(?:bash|sh)\s+(?:-n\s+[^-+\s]\S*|--version)$/.test(basenamed);
	}
	return READ_ONLY_BASH_COMMANDS.has(executable);
}

export function isReadOnlyBashCommand(command) {
	const segments = splitReadOnlyPipeline(command);
	return Boolean(segments && segments.every(isReadOnlyPipelineSegment));
}
