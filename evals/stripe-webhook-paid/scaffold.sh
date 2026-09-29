#!/bin/bash
# an express api that creates checkout sessions
set -e
mkdir -p src
cat > package.json <<'J'
{ "name": "donate-api", "private": true, "type": "module",
  "dependencies": { "express": "5.1.0", "stripe": "18.5.0" },
  "devDependencies": { "typescript": "5.9.2", "@types/express": "5.0.3", "vitest": "3.2.4" } }
J
cat > src/donations.ts <<'J'
export type Donation = { id: string; amountCents: number; status: "pending" | "paid" };
const donations = new Map<string, Donation>();
export const createDonation = (id: string, amountCents: number) => donations.set(id, { id, amountCents, status: "pending" });
export const getDonation = (id: string) => donations.get(id);
export const markPaid = (id: string) => { const d = donations.get(id); if (d) d.status = "paid"; };
J
cat > src/app.ts <<'J'
import express from "express";
import Stripe from "stripe";
import { createDonation } from "./donations.js";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
export const app = express();
app.use(express.json());

app.post("/checkout", async (req, res) => {
  const { amountCents } = req.body as { amountCents: number };
  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    line_items: [{ price_data: { currency: "usd", unit_amount: amountCents, product_data: { name: "Donation" } }, quantity: 1 }],
    success_url: "https://example.org/thanks",
  });
  createDonation(session.id, amountCents);
  res.json({ url: session.url });
});
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
