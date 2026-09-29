#!/bin/bash
set -e
mkdir -p app/routes
cat > package.json <<'J'
{ "name": "giving-app", "private": true, "type": "module", "dependencies": { "react": "19.1.1", "react-router": "7.9.2" } }
J
cat > app/routes/settings.billing.tsx <<'J'
export default function BillingSettings() {
  return (
    <section>
      <h2>Remittance Configuration</h2>
      <label><input type="checkbox" name="cover" /> Enable donor-side processing offset (DSPO)</label>
      <label>Payout cadence <select name="cadence"><option>T+2</option><option>Weekly (net)</option></select></label>
      <p>Note: changes propagate after the next settlement window unless overridden.</p>
      <button>Submit</button>
      <button>Terminate plan</button>
    </section>
  );
}
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
