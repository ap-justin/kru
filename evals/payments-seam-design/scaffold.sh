#!/bin/bash
# stripe calls reached from three places
set -e
mkdir -p src/routes src/jobs
cat > package.json <<'J'
{ "name": "giving-api", "private": true, "type": "module", "dependencies": { "stripe": "18.5.0", "express": "5.1.0" } }
J
cat > src/stripe.ts <<'J'
import Stripe from "stripe";
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
J
cat > src/routes/checkout.ts <<'J'
import { stripe } from "../stripe.js";
export async function checkout(amountCents: number) {
  const s = await stripe.checkout.sessions.create({ mode: "payment", line_items: [{ price_data: { currency: "usd", unit_amount: amountCents, product_data: { name: "Donation" } }, quantity: 1 }], success_url: "https://example.org/thanks" });
  return s.url;
}
J
cat > src/routes/refund.ts <<'J'
import { stripe } from "../stripe.js";
export const refund = (paymentIntent: string) => stripe.refunds.create({ payment_intent: paymentIntent });
J
cat > src/jobs/payouts.ts <<'J'
import { stripe } from "../stripe.js";
export async function nightlyPayouts() {
  const balance = await stripe.balance.retrieve();
  if (balance.available[0].amount > 0) await stripe.payouts.create({ amount: balance.available[0].amount, currency: "usd" });
}
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
