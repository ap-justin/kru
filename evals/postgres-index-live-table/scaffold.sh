#!/bin/bash
# a small drizzle-on-postgres app: schema, one applied migration, the kit config
set -e
mkdir -p src/db drizzle
cat > package.json <<'J'
{
  "name": "giving-app",
  "private": true,
  "type": "module",
  "scripts": { "db:generate": "drizzle-kit generate", "db:migrate": "drizzle-kit migrate" },
  "dependencies": { "drizzle-orm": "0.44.5", "postgres": "3.4.7" },
  "devDependencies": { "drizzle-kit": "0.31.4", "typescript": "5.9.2" }
}
J
cat > drizzle.config.ts <<'J'
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dbCredentials: { url: process.env.DATABASE_URL! },
});
J
cat > src/db/schema.ts <<'J'
import { bigserial, integer, pgTable, text, timestamp } from "drizzle-orm/pg-core";

export const donations = pgTable("donations", {
  id: bigserial("id", { mode: "number" }).primaryKey(),
  donor_email: text("donor_email").notNull(),
  amount_cents: integer("amount_cents").notNull(),
  created_at: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
J
cat > drizzle/0000_init.sql <<'J'
CREATE TABLE "donations" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"donor_email" text NOT NULL,
	"amount_cents" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
