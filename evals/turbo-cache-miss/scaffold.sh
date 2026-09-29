#!/bin/bash
# a pnpm + turbo monorepo whose build task declares no outputs
set -e
mkdir -p apps/web/src packages/ui/src
cat > package.json <<'J'
{ "name": "giving", "private": true, "packageManager": "pnpm@10.17.1",
  "scripts": { "build": "turbo build" }, "devDependencies": { "turbo": "2.5.8" } }
J
printf 'packages:\n  - "apps/*"\n  - "packages/*"\n' > pnpm-workspace.yaml
cat > turbo.json <<'J'
{
  "$schema": "https://turborepo.com/schema.json",
  "tasks": {
    "build": { "dependsOn": ["^build"] },
    "test": {}
  }
}
J
cat > apps/web/package.json <<'J'
{ "name": "web", "private": true, "scripts": { "build": "vite build" }, "dependencies": { "ui": "workspace:*" }, "devDependencies": { "vite": "7.1.7" } }
J
cat > packages/ui/package.json <<'J'
{ "name": "ui", "private": true, "scripts": { "build": "tsc -p . --outDir dist" }, "devDependencies": { "typescript": "5.9.2" } }
J
echo 'export const hello = "hi";' > packages/ui/src/index.ts
echo 'console.log("web");' > apps/web/src/main.ts
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
