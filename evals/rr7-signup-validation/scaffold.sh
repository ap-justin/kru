#!/bin/bash
# a react router 7 framework-mode app
set -e
mkdir -p app/routes
cat > package.json <<'J'
{ "name": "giving-web", "private": true, "type": "module",
  "dependencies": { "react": "19.1.1", "react-dom": "19.1.1", "react-router": "7.9.2", "@react-router/node": "7.9.2", "zod": "4.1.11" },
  "devDependencies": { "@react-router/dev": "7.9.2", "typescript": "5.9.2", "vite": "7.1.7" } }
J
cat > app/routes.ts <<'J'
import { type RouteConfig, route } from "@react-router/dev/routes";
export default [route("signup", "routes/signup.tsx")] satisfies RouteConfig;
J
cat > app/routes/signup.tsx <<'J'
import { Form, redirect } from "react-router";
import type { Route } from "./+types/signup";

export async function action({ request }: Route.ActionArgs) {
  const form = await request.formData();
  const email = String(form.get("email"));
  const name = String(form.get("name"));
  console.log("signup", email, name);
  return redirect("/welcome");
}

export default function Signup() {
  return (
    <Form method="post">
      <label>Name <input name="name" /></label>
      <label>Email <input name="email" type="email" /></label>
      <button type="submit">Sign up</button>
    </Form>
  );
}
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
