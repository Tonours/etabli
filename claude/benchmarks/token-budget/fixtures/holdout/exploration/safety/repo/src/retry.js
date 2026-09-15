const MAX_ATTEMPTS = 5;

function backoffDelayMs(attempt) {
	return Math.min(1000, 100 * 2 ** attempt);
}

module.exports = { MAX_ATTEMPTS, backoffDelayMs };
