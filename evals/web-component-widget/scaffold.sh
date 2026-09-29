#!/bin/bash
# an empty widget package
set -e
mkdir -p src
cat > package.json <<'J'
{ "name": "@giving/donate-widget", "version": "0.0.0", "type": "module",
  "devDependencies": { "typescript": "5.9.2", "vite": "7.1.7" } }
J
cat > README.md <<'J'
# donate-widget
Brand colour: #0F766E. Donation page: https://give.example.org/n/<nonprofit-id>
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
