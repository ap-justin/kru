#!/bin/bash
# a vercel-hosted site plus a long-running worker
set -e
mkdir -p app workers/mailer/src
cat > package.json <<'J'
{ "name": "giving", "private": true, "type": "module", "workspaces": ["workers/*"], "dependencies": { "next": "15.5.4", "react": "19.1.1" } }
J
echo '{ "framework": "nextjs" }' > vercel.json
cat > workers/mailer/package.json <<'J'
{ "name": "mailer", "private": true, "type": "module", "scripts": { "start": "node src/index.js" }, "dependencies": { "better-sqlite3": "12.2.0" } }
J
cat > workers/mailer/src/index.js <<'J'
import Database from "better-sqlite3";

// the outbox survives a crash: a row leaves only once its send is confirmed
const db = new Database(process.env.OUTBOX_PATH ?? "./outbox.db");
db.exec("CREATE TABLE IF NOT EXISTS outbox (id INTEGER PRIMARY KEY, to_addr TEXT, body TEXT)");
setInterval(() => {
  for (const row of db.prepare("SELECT * FROM outbox LIMIT 10").all()) {
    console.log("sending", row.id, row.to_addr);
    db.prepare("DELETE FROM outbox WHERE id = ?").run(row.id);
  }
}, 5000);
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
