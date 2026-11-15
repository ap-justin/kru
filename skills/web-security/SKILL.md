---
name: web-security
description: Browser-side security recipes — passkey sign-in order (conditional UI, immediate mode, reauth, Signal API), untrusted HTML (Sanitizer, Trusted Types), postMessage origin checks, SRI on third-party assets. Load for a sign-in form or rendered user HTML. Server auth and response-header config are out.
user-invocable: false
---

Recipes over Chrome's Modern Web Guidance security guides (`guides/security/<id>`, `GoogleChrome/modern-web-guidance-src`, Apache-2.0, read at `5e5cd33`). Ids in parentheses name the guide a claim comes from. What fails here fails quietly: the passkey prompt never appears, the sanitizer is missing in one browser, the origin check passes for the wrong sender.

## Status (`api.webstatus.dev`, read 2026-11-14)
| Feature | Baseline | Consequence |
|---|---|---|
| `webauthn`, `subresource-integrity` | Widely | no fallback for the core API; the newer WebAuthn helpers (`getClientCapabilities`, `parseRequestOptionsFromJSON`, `toJSON`) come from `webauthn-polyfills` where missing |
| `trusted-types` | Newly (2026-02-24) | enforce through CSP; the guide's tinyfill covers older browsers |
| `webauthn-signals` | Limited (no Firefox) | gate every call on `if (PublicKeyCredential.signalX)` |
| `sanitizer` (`setHTML`) | Limited (no Safari) | DOMPurify fallback, loaded only when `'setHTML' in Element.prototype` is false |
| `origin` (`Origin` API) | Limited (no Firefox) | `new URL` fallback |
| `url-integrity`, CSS `url()` modifiers | Limited | cascade declarations; `<link integrity>` where SRI must hold everywhere |

Recompute against today; the aging rule is `modern-css`'s.

## Sign-in, in this order (`passkey-authentication`, `passkeys`)
1. **`rpId` comes from the server's options** (`publicKey.rpId` or `publicKey.rp.id`) and goes to every Signal call. `location.hostname` fails on a parent-domain or related-origin RP ID with `SecurityError` or a silent wrong target.
2. **Feature-detect once on load**: `PublicKeyCredential.getClientCapabilities()` (the guides load `webauthn-polyfills` where it's missing). No `conditionalGet` → skip the passkey path; the form stays a working password form.
3. **Markup**: one `<form>` with labelled inputs, `autocomplete="username webauthn"` on the identifier, `current-password` on the password, a stable `name`/`id`, and a submit button named for what it does (`forms/autofill-sign-in-form`, not under `guides/security`). `autofocus` goes only on a dedicated sign-in page or dialog, with a page title or dialog name and `aria-describedby` for the instructions; it stays off a form embedded in a larger page.
4. **Conditional get**: decode the server's JSON with `PublicKeyCredential.parseRequestOptionsFromJSON()` (raw JSON in `publicKey` throws `TypeError`), then get with `mediation: "conditional"` and an `AbortController`. Swallow `NotAllowedError` and `AbortError`.
5. **A "Sign in with passkey" button** aborts the conditional request first, runs the modal get, and re-arms conditional get if the user cancels.
6. **Verify**: send `credential.toJSON()`. On HTTP `404` while signed out, call `signalUnknownCredential({ rpId, credentialId: encoded.id })`; `credentialId` is the base64url string, never `rawId`.

Traps, each as the failure it causes:
- **Immediate mode (`uiMode: 'immediate'`) on the dedicated sign-in page**: the button does nothing for anyone without a local credential, and QR and security-key options are suppressed (`quick-sign-ins`). It belongs on a "Sign in" link, checkout or favorite click, where `NotAllowedError` falls through to the real sign-in. Check `capabilities.immediateGet` first, or an unsupporting browser ignores the key and opens a blocking QR dialog. Call it from a click only, with no `allowCredentials` and no `signal`.
- **Reauthentication with empty `allowCredentials`** is a discoverable get: the user can pick a different account's passkey mid-session. List the signed-in user's credential ids, and have the server check the returned credential belongs to the session user (`passkey-reauthentication`).
- **Conditional create** runs only when `capabilities.conditionalCreate` is true, after a full sign-in that used a password, after every factor succeeded, after aborting the conditional get; it stays silent on `InvalidStateError`, `NotAllowedError`, `AbortError` (`passkey-conditional-create`). Magic-link, OTP and federated sign-ins never trigger it.
- **A "Create passkey" button shows only when `getClientCapabilities()` reports both `passkeyPlatformAuthenticator` and `conditionalGet`**. A promotion after sign-in sets `authenticatorAttachment: "platform"`; a settings page omits it so security keys work (`passkey-registration`).
- **Signal API ids must be unpadded base64url**; a placeholder like `'passkey-1'` throws `TypeError` on page load. Validate before the call, log failures with `console.warn`, and call `signalAllAcceptedCredentials` on the management page load and after every delete. Renaming a passkey is a server label and sends no signal; renaming the account calls `signalCurrentUserDetails` (`passkey-management`).
- **The AAGUID labels a row in the management list and decides nothing**: platform passkeys give no attestation, so it can be forged (`passkeys`).

## Untrusted HTML (`sanitize-untrusted-html`, `trusted-types`)
1. No markup needed → `textContent`; it is not a Trusted Types sink.
2. Markup needed → `el.setHTML(html, { sanitizer: { elements, attributes } })`, which sanitizes without a policy. The default sanitizer drops XSS-unsafe items, and a custom one can only narrow it; `setHTMLUnsafe` is where a wider one goes.
3. **Elements outside `elements` vanish with their text.** List wrappers whose text you want in `replaceWithChildrenElements`; DOMPurify has no equivalent, so leave that option out wherever a fallback must match.
4. **The DOMPurify fallback needs `ALLOW_ARIA_ATTR: false`, `ALLOW_DATA_ATTR: false`, `KEEP_CONTENT: false` and `#text` allowed** to match the native result; its defaults keep `aria-*`, `data-*` and the text of removed elements, so the same input renders differently per browser.
5. **`Document.parseHTML()` for a preview**, then `replaceChildren(...doc.body.childNodes)`. Serializing back to a string for `innerHTML` reintroduces mutation XSS.
6. **An escaping policy is not a sanitizer.** Entity-escaped output dropped into `href="${escaped}"` or an unquoted attribute still carries `javascript:`. A `default` policy of `s => s` turns Trusted Types into a no-op (`security`).
7. **Trusted Types rolls out report-only first**: `Content-Security-Policy-Report-Only: require-trusted-types-for 'script'`, enforce when reports reach zero. A framework or library that writes sinks with plain strings breaks under enforcement, so audit them before enforcing. The `trusted-types` allowlist names every policy, `dompurify` and any `default` included; with enforcement on, the DOMPurify fallback passes `RETURN_TRUSTED_TYPE: true`. A `<meta>` CSP works only as the first child of `<head>`. Content rendered elsewhere is sanitized on the server too.

## Origins (`validate-origins`)
- **Privilege boundary (a `postMessage` command)**: `Origin.from(event).isSameOrigin(TRUSTED)`. A sibling subdomain is a different origin on purpose. **Post-login `returnTo` and link classes**: `isSameSite`, which rejects `http:` downgrades and neighbours on `.github.io` or `.co.uk`.
- `isSameOrigin` takes an `Origin`, never a string (`TypeError`); `Origin.from('null')` throws; wrap runtime input in `try/catch` and answer `false`.
- **Sandboxed iframes serialize `event.origin` as `"null"`**, so `a === b` equates two unrelated frames. `Origin.from(event)` keeps their identities; pin one on init. Without the `Origin` API, check `event.source` or hand the frame a `MessageChannel` port.
- `startsWith`, `includes` and hostname splitting pass `https://app.example.com.attacker.example`.
- A synthetic `new MessageEvent` in a unit test lacks the browser's internal origin, so `Origin.from(event)` throws there; fall back to `Origin.from(event.origin)`.
- Without `Origin`: `new URL`, reject `origin === 'null'`, compare `.origin`. Same-site by hand works only for one registrable domain you control.

## Third-party assets (`secure-external-subresources`)
- **Hash at build from known-good bytes**, `sha384-` by default, against a version-pinned URL. A hash computed from the live response trusts whatever the host sends. A floating `latest/` URL breaks the hash on the next release; a vendor tag that updates in place gets no `integrity` and a CSP or sandbox instead.
- **`integrity`, `crossorigin="anonymous"` and `referrerpolicy="no-referrer"` travel together.** Without `crossorigin` the fetch is `no-cors`, the response is opaque, and the resource is blocked. The CDN must answer with CORS headers.
- **Document default** `Referrer-Policy: strict-origin-when-cross-origin` (or `<meta name="referrer">`) covers whatever omits a per-request value.
- **CSS `url()` modifiers** (`cross-origin()`, `referrer-policy()`, `integrity()`): the URL must be quoted, `background-image` and `@import` default to `no-cors`, and a browser that doesn't know a modifier drops the declaration. Cascade separate declarations, plain first, full last. A plain `url()` fallback inside the same comma-separated `@font-face` `src` list defeats the hash: the tampered font fails it, then loads from the fallback.

## Seam with `better-auth-specialist`
Better Auth owns the server: options and verify endpoints, the `passkey` plugin, challenge storage, session and cookies. This skill owns the browser: feature detection, form markup, autofill, abort handling, the Signal calls and the states around them. The WebAuthn call itself belongs to whichever side of the repo already makes it. Better Auth's `passkeyClient` makes the sign-in and register calls through SimpleWebAuthn's browser package, so keep those; the guides' native-call rule (`passkeys`) governs calls it doesn't make. What changes under `passkeyClient`:
- **Steps 2–3 apply; 4–5 don't.** `signIn.passkey` takes no `signal`: SimpleWebAuthn aborts a pending ceremony when the next one starts, and failures come back as `{ error: { code } }` rather than thrown, so there is no `NotAllowedError` to swallow. Call `signIn.passkey({ autoFill: true })` once for the conditional get (pass the boolean; don't rely on a default), with the `webauthn` input already in the DOM, and `signIn.passkey({ autoFill: false })` from the button.
- **`rpId`**: the options never reach app code. `better-auth-specialist` sets `passkey({ rpID })` explicitly to the registrable domain (the fallback is the `baseURL` host or `localhost`) and exposes the same value to the client for Signal calls.
- **Unknown credential**: verify answers `401` with code `PASSKEY_NOT_FOUND`, not `404`; the credential id comes from `signIn.passkey({ returnWebAuthnResponse: true })`.
- **`signalAllAcceptedCredentials` and `signalCurrentUserDetails` need the WebAuthn user handle**, which the plugin generates at random per registration and never stores. Passing the app's user id matches nothing, silently; skip both calls until the server stores the handle. `signalUnknownCredential` after a delete works with the row's `credentialID`.
- **Reauthentication**: the plugin's verify creates a session for the credential's owner and does not compare it to the current session. The ownership check is a server hook, `better-auth-specialist`'s.

## Left out
- Passkey server verification, challenge storage, credential tables: a vetted library per language (`passkeys`), or Better Auth.
- CSP, `Connection-Allowlist`, COOP/COEP, cookies and the other response headers (`security`, `restrict-outbound-connections`): the seat that owns the response sets them: the framework builder in middleware or hooks, the platform seat in host config, `better-auth-specialist` for session cookies. *Untrusted HTML* step 7 states only what Trusted Types needs from the page.
- Client-side verification of an email token, hand-rolled JWT or WebAuthn parsing (`verify-email-ownership`).

## Everything else
`restrict-outbound-connections`, `local-network-access`, `verify-email-ownership` (origin trial), `client-side-encryption`, `digital-signatures` and the rest of `guides/security`: query the Modern Web Guidance CLI as `SOURCES.md` → *Client-side web platform* says. A guide behind an origin trial or a volatile feature is gated on `retrieve` for the developer's consent: ask the user before running `set-allow-origin-trials` or `set-allow-volatile-features`, which write `.mwgrc` into the repo, and don't read the gated guide off `raw.githubusercontent.com` to get around the gate.
