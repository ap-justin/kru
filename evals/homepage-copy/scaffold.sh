#!/bin/bash
set -e
mkdir -p app/routes
cat > package.json <<'J'
{ "name": "giving-site", "private": true, "type": "module", "dependencies": { "react": "19.1.1", "react-router": "7.9.2" } }
J
cat > app/routes/_index.tsx <<'J'
export default function Home() {
  return (
    <main>
      <h1>Lorem ipsum dolor sit amet</h1>
      <p>Consectetur adipiscing elit, sed do eiusmod tempor.</p>
      <a href="/signup">Get started</a>
    </main>
  );
}
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
