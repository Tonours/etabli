export function centsFrom(amount: number): number {
	return Math.trunc(amount * 100);
}

export function applyRefund(balanceCents: number, refundAmount: number): number {
	return balanceCents + centsFrom(refundAmount);
}
