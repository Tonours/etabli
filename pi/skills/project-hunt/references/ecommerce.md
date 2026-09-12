# Ecommerce cash-test reference

This is a research and validation gate, not permission to trade. The default
test cap is a hypothetical **€150 total**; the user must explicitly approve any
account, listing, purchase, paid call, advertisement, or outreach.
Those approvals are hard stops: record `pending_approval` and wait; do not
create the account, publish the listing, spend, or contact anyone while waiting.

## Eligible first tests

Prefer offers that can be tested without stock: made-to-order, print-on-demand,
supplier-fulfilled, digital, local service plus a product, or a clearly labelled
pre-order/waitlist. Do not recommend inventory-first, dropshipping promises,
counterfeit, unsafe, ingestible/cosmetic, medical-claim, financial, children’s
safety, or heavily regulated products without explicit expertise, licence, and
risk budget.

## Unit economics

Record the target country, sales channel, local currency, cap currency, tax
treatment, payout delay, FX source/date, and every assumption. All operands in
the formulas below are already converted to the cap currency; keep the original
amount, source currency, FX rate, and converted amount in a `money_ledger`. If a
line's currency or FX is `N/A`, the low-capital gate cannot pass. The default cap
is **€150 EUR**; for a non-EUR offer, convert each monetary line with
`fx_target_to_cap_currency` (cap-currency units per local-currency unit) from a
dated source before summing.

```text
customer_cash_per_order_cap = item_price_TTC_cap
                               + shipping_charged_to_customer_cap
                               - discounts_cap
net_sale_ex_tax_per_order_cap = customer_cash_per_order_cap
                                - VAT_or_sales_tax_amount_cap
landed_cost_per_order_cap = product_cost_per_order_cap
                             + inbound_shipping_per_order_cap
                             + duties_or_customs_per_order_cap
payment_fee_per_order_cap = payment_fee_fixed_cap
                             + payment_fee_rate * payment_fee_base_cap
marketplace_fee_per_order_cap = marketplace_fee_fixed_cap
                                + marketplace_fee_rate * marketplace_fee_base_cap
variable_cost_per_order_cap = landed_cost_per_order_cap + packaging_per_order_cap
                              + payment_fee_per_order_cap
                              + marketplace_fee_per_order_cap
                              + outbound_shipping_paid_by_seller_per_order_cap
                              + expected_returns_refunds_per_order_cap
                              + chargeback_reserve_per_order_cap
contribution_per_order_cap = net_sale_ex_tax_per_order_cap
                             - variable_cost_per_order_cap
contribution_margin = contribution_per_order_cap / net_sale_ex_tax_per_order_cap
break_even_orders = ceil(max(0, test_fixed_cost_cap) / contribution_per_order_cap)
upfront_cash_outflow_per_order_cap = landed_cost_per_order_cap
                                     + packaging_per_order_cap
                                     + outbound_shipping_paid_by_seller_per_order_cap
                                     + nonrefundable_fees_paid_before_payout_per_order_cap
                                     + other_cash_outflows_before_payout_per_order_cap
cash_at_risk_in_cap_currency = test_fixed_cost_cap
                               + planned_orders * upfront_cash_outflow_per_order_cap
                               + planned_orders * expected_returns_refunds_per_order_cap
                               + planned_orders * chargeback_reserve_per_order_cap
cap_headroom = hypothetical_test_cap_cap - cash_at_risk_in_cap_currency
```

Reject an offer when observed economics establish `net_sale_ex_tax_per_order_cap <= 0`
or `contribution_per_order_cap <= 0`; never divide by a non-positive sale.
A missing material amount is a watchlist gap until verified, not proof of
nonviability. Apply the shared per-finalist counter-search before ranking. Treat `VAT_or_sales_tax_amount_cap`, duties,
payment/marketplace fee bases, refunds, chargebacks, payout timing, and every
cash-outflow-before-payout line as material whenever the target country or
channel makes them applicable. `landed_cost_per_order_cap` is the unique sum of
product, inbound shipping, and duties; do not add those components again.
`shipping_charged_to_customer_cap` reduces the seller's shipping burden only
through `customer_cash_per_order_cap`;
`outbound_shipping_paid_by_seller_per_order_cap` remains a cost. If shipping is
already included in `item_price_TTC_cap`, set
`shipping_charged_to_customer_cap` to zero.
For the default low-capital screen, prefer `contribution_margin >= 30%`,
`break_even_orders <= 10`, and first payout cash within 30 days. These are
triage thresholds, not promises; show sensitivity for shipping, returns, fees,
and payout delay.

`break_even_orders` is not a liquidity gate. Require `planned_orders` to be an
integer of at least 3; the default test plans the first three orders. All
per-order amounts above use the cap currency after line-by-line conversion.
`upfront_cash_outflow_per_order_cap` explicitly includes every non-reserve cash
outflow required before payout and excludes the two reserve fields, which are
multiplied by `planned_orders` in the cash-at-risk calculation. Require
`cash_at_risk_in_cap_currency <= hypothetical_test_cap_cap` for a low-capital pass;
if the first three orders need more cash before payout, keep the offer in the
watchlist for a revised funding/fulfilment test even when its margin is positive;
reject only when evidence establishes incompatibility with the user's fixed
constraints. Report the conservative
cash-at-risk amount in cap currency, the line-level local ledger, the number of
planned orders, and the payout-delay range.
Fee rates are decimal fractions of the stated base; model tiered/capped fees
with their actual schedule rather than an unexplained average. Choose
`payment_fee_base_cap` and `marketplace_fee_base_cap` explicitly from
`customer_cash_per_order_cap`, `net_sale_ex_tax_per_order_cap`, or the
provider's documented base, and cite that fee schedule. All cash-outflow fields
are non-negative, including `test_fixed_cost_cap`; if any pre-payout line is not
known, keep the item out of the low-capital shortlist. Every fee appears once in
its variable-cost line. If that fee is paid before payout, also include it once
in the pre-payout cash-outflow ledger; if it is deducted from settlement, do not
include it in upfront cash. The same fee may therefore appear in both different
calculations, but never twice within either sum.

`test_fixed_cost_cap` may include one sample, packaging, a listing fee, or a small
tool subscription. It excludes unapproved ads and stock. Never count unpaid
labour as cash profit; report hours separately.

## Demand and access gate

Require two independent demand signals with distinct `evidence_id`s and
publisher/domain/author ownership: for example, a dated buyer request plus
dated marketplace complaints, or a repeat purchase pattern plus a price/return
problem. A trend chart, bestseller badge, influencer video, affiliate page, or
two pages from the same seller is only a lead.

The test plan must name the first three qualified buyers/preorders, the organic
channel, the offer wording, the delivery promise, the refund/return handling,
and the date that stops the test. If the route needs a new marketplace account,
paid reach, or private-group access, mark that dependency and keep the item in
the watchlist until the user approves it.

## Stop rules

Stop and do not scale when any of these occurs:

- three qualified conversations produce no paid order/preorder by the stop date;
- contribution margin falls below the stated threshold after real quotes;
- supplier availability, delivery, VAT/tax, payout timing, IP, or return cost is unknown;
- the offer requires paid ads, a large minimum order, or a recurring tool cost;
- a safety, licence, platform-policy, counterfeit, or consumer-rights question is
  unresolved.

## Product-type and cash-risk branches

For a digital product or service-plus-product, set physical shipping/landed
cost to zero only when that is factually true, then verify the applicable VAT
place-of-supply, platform/payment fees, refund/chargeback exposure, licence, and
consumer withdrawal rules separately. Do not reuse physical-return assumptions
for a digital delivery or service.

## Card fields

```text
job / buyer:
demand_proofs: evidence_id + independent publisher/domain/author for each signal
target_country / channel / local_currency / cap_currency:
fx_target_to_cap_currency / fx_source / fx_date / money_ledger:
organic_channel:
offer_and_supplier:
hypothetical_test_cap_cap:
item_price_TTC_cap / shipping_charged_to_customer_cap / shipping_included_in_item_price:
discounts_cap / VAT_or_sales_tax_rate / VAT_or_sales_tax_amount_cap:
product_cost_per_order_cap / inbound_shipping_per_order_cap / duties_or_customs_per_order_cap:
landed_cost_per_order_cap / packaging_per_order_cap:
payment_fee_fixed_cap / payment_fee_rate / payment_fee_base_cap:
marketplace_fee_fixed_cap / marketplace_fee_rate / marketplace_fee_base_cap:
outbound_shipping_paid_by_seller_per_order_cap / expected_returns_refunds_per_order_cap / chargeback_reserve_per_order_cap:
contribution_per_order_cap / contribution_margin:
cap_headroom:
planned_orders / test_fixed_cost_cap / upfront_cash_outflow_per_order_cap:
nonrefundable_fees_paid_before_payout_per_order_cap / other_cash_outflows_before_payout_per_order_cap:
cash_at_risk_in_cap_currency:
break_even_orders:
time_to_first_cash / payout_delay:
test_and_stop_date:
legal_fulfilment_risks:
differentiation:
assumptions:
```

Keep `N/A` visible. A cash test is a hypothesis until the user independently
executes it and records actual orders, costs, refunds, and payout timing.
