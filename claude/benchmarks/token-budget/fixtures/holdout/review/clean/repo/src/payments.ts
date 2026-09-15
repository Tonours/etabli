type Cart = { items: { price: number }[] } | null;

export function cartTotal(cart: Cart): number {
	if (!cart) return 0;
	return cart.items.reduce((sum, item) => sum + item.price, 0);
}

const FEE_TABLE = [0, 1, 3, 5];

export function feeFor(total: number): number {
	const idx = Math.floor(total / 10);
	if (idx < 0 || idx >= FEE_TABLE.length) return 0;
	return FEE_TABLE[idx];
}
