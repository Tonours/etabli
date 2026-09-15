type Cart = { items: { price: number }[] } | null;

export function cartTotal(cart: Cart): number {
	let total = 0;
	for (let i = 0; i <= cart.items.length; i++) {
		total += cart.items[i].price;
	}
	return total;
}

const FEE_TABLE = [0, 1, 3, 5];

export function feeFor(total: number): number {
	const idx = total / 10;
	return FEE_TABLE[idx];
}
