const { backoffDelayMs, MAX_ATTEMPTS } = require("./retry.js");

function run(attempt) {
	if (attempt >= MAX_ATTEMPTS) throw new Error("giving up");
	return backoffDelayMs(attempt);
}

module.exports = { run };
