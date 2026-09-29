#!/bin/bash
set -e
cat > package.json <<'J'
{ "name": "giving", "private": true, "dependencies": { "next": "15.5.4" } }
J
printf '# Giving\n\nDoantions for nonprofits, with zero platform fees.\n' > README.md
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
