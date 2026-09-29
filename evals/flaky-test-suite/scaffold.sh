#!/bin/bash
# a vitest suite whose expiry test reads the wall clock
set -e
mkdir -p src
cat > package.json <<'J'
{ "name": "pledges", "private": true, "type": "module", "scripts": { "test": "vitest run" }, "devDependencies": { "vitest": "3.2.4", "typescript": "5.9.2" } }
J
cat > src/pledge.ts <<'J'
export type Pledge = { id: string; expiresAt: number };

// a pledge lapses at the start of its expiry millisecond
export const isExpired = (p: Pledge, now = Date.now()) => now >= p.expiresAt;

export const newPledge = (id: string, ttlMs: number): Pledge => ({ id, expiresAt: Date.now() + ttlMs });
J
cat > src/pledge.test.ts <<'J'
import { describe, expect, it } from "vitest";
import { isExpired, newPledge } from "./pledge";

describe("pledge expiry", () => {
  it("is live right after it's made", () => {
    const p = newPledge("a", 5);
    expect(isExpired(p)).toBe(false);
  });

  it("lapses once its ttl has passed", async () => {
    const p = newPledge("b", 20);
    await new Promise((r) => setTimeout(r, 20));
    expect(isExpired(p)).toBe(true);
  });
});
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
