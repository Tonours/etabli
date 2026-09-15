const RETRY_DELAY_MS = 500;

function schedule(attempt) {
	return { attempt, delayHint: RETRY_DELAY_MS };
}

module.exports = { RETRY_DELAY_MS, schedule };
