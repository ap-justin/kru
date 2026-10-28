# Test credentials

Read before a test run that needs secrets or a database — the lead before a scoped run or a `test-writer` dispatch, and any seat writing or running those tests. A failed guard stops the slice.

1. **Source.** Secrets come only from the environment the session runs in, through the variable names the app already reads. Prompts, repo files, chat and pasted output are never a source.

2. **One command.** Every Bash call starts a fresh shell, so the guard and the run it protects go in the same command, in the calling shell (no `( … )` subshell): `exit` has to stop the run. Start it with `{ set +x; } 2>/dev/null` so no line expands a secret under xtrace.

3. **Stripe.** Every Stripe **secret** key variable the run needs (`STRIPE_SECRET_KEY` and the like) must start `sk_test_`; any other prefix aborts, `rk_test_` and `sk_live_` included. Every **publishable** key variable must start `pk_test_`:

   ```sh
   { set +x; } 2>/dev/null
   case "${STRIPE_SECRET_KEY-}" in
     sk_test_*) ;;
     '') echo 'ABORT: STRIPE_SECRET_KEY is not set'; exit 1 ;;
     *) echo 'ABORT: STRIPE_SECRET_KEY is not a test secret key'; exit 1 ;;
   esac
   case "${STRIPE_PUBLISHABLE_KEY-}" in
     pk_test_*) ;;
     '') echo 'ABORT: STRIPE_PUBLISHABLE_KEY is not set'; exit 1 ;;
     *) echo 'ABORT: STRIPE_PUBLISHABLE_KEY is not a test publishable key'; exit 1 ;;
   esac
   ```

   Substitute the variable names the app uses (`NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`, say).

4. **Output.** The only lines a guard prints are fixed status lines like the `ABORT` ones above. No part of a secret value reaches output, a log, a commit or a screenshot — `echo`, `printf`, `cut` and `head` on one included. To check presence alone, use `[ -n "${VAR:+x}" ]` after the same `set +x`.

5. **Database.** Use only the `DATABASE_URL` (or the app's equivalent) the environment provides; a database URL is never derived, swapped or typed by hand. Whoever sets it points it at a schema-only test branch, and the URL alone can't prove which branch it is (a Neon host is an endpoint id). When the environment also provides a branch marker (`TEST_DB_BRANCH`, say), require it to match `test-e2e-*` and abort otherwise. Seed the data the test needs yourself.

6. **Missing.** A required secret that is unset is named in the return and the test slice stops: no placeholder, no silent skip of the case that needed it.
