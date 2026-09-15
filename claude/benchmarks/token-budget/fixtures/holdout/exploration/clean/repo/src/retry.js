const MAX_ATTEMPTS = 5;

function attemptsLeft(attempt) {
	return Math.max(0, MAX_ATTEMPTS - attempt);
}

module.exports = { MAX_ATTEMPTS, attemptsLeft };
