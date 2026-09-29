#!/bin/bash
# a node cli on better-sqlite3 with a user_version migration stepper
set -e
mkdir -p src migrations
cat > package.json <<'J'
{ "name": "pledge-desk", "private": true, "type": "module",
  "dependencies": { "better-sqlite3": "12.2.0" }, "devDependencies": { "typescript": "5.9.2", "@types/better-sqlite3": "7.6.13" } }
J
cat > migrations/001_init.sql <<'J'
CREATE TABLE donors (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE pledges (
  id INTEGER PRIMARY KEY,
  donor_id INTEGER NOT NULL REFERENCES donors(id) ON DELETE CASCADE,
  amount TEXT NOT NULL,
  pledged_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE pledge_notes (id INTEGER PRIMARY KEY, pledge_id INTEGER NOT NULL REFERENCES pledges(id) ON DELETE CASCADE, body TEXT NOT NULL);
J
cat > src/db.ts <<'J'
import Database from "better-sqlite3";
import { readdirSync, readFileSync } from "node:fs";

export function open(path: string) {
  const db = new Database(path);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");
  migrate(db);
  return db;
}

// each file in migrations/ runs once, in name order, tracked by user_version
function migrate(db: Database.Database) {
  const files = readdirSync(new URL("../migrations", import.meta.url)).sort();
  const current = db.pragma("user_version", { simple: true }) as number;
  for (const [i, file] of files.entries()) {
    if (i < current) continue;
    db.exec(readFileSync(new URL(`../migrations/${file}`, import.meta.url), "utf8"));
    db.pragma(`user_version = ${i + 1}`);
  }
}
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
