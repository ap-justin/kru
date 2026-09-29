#!/bin/bash
# a worker with a d1 binding
set -e
mkdir -p src migrations
cat > package.json <<'J'
{ "name": "donor-api", "private": true, "type": "module",
  "scripts": { "dev": "wrangler dev", "deploy": "wrangler deploy" },
  "devDependencies": { "wrangler": "4.40.0", "@cloudflare/workers-types": "4.20250926.0", "typescript": "5.9.2" } }
J
cat > wrangler.jsonc <<'J'
{
  "name": "donor-api",
  "main": "src/index.ts",
  "compatibility_date": "2025-09-01",
  "d1_databases": [{ "binding": "DB", "database_name": "donors", "database_id": "00000000-0000-0000-0000-000000000000" }]
}
J
cat > migrations/0001_init.sql <<'J'
CREATE TABLE donors (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE);
J
cat > src/index.ts <<'J'
export interface Env { DB: D1Database }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/donors") {
      const { results } = await env.DB.prepare("SELECT id, name, email FROM donors ORDER BY id").all();
      return Response.json({ donors: results });
    }
    return new Response("not found", { status: 404 });
  },
} satisfies ExportedHandler<Env>;
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
