# Testing

The hooks and the store resolver are the tested code. Each `<name>.sh` has a `<name>.test.sh` beside it: a plain bash table test.

```sh
for t in hooks/*.test.sh scripts/*.test.sh; do bash "$t" || break; done
```

## Writing one

Copy the closest existing `*.test.sh`. They share one shape:

- **Sandboxed `HOME`** from `mktemp -d`, removed by an `EXIT` trap. Hooks write under the cross-project root, and a test that reaches the real one pollutes the audit ledger and refusal log. On macOS resolve it with `pwd -P` — `mktemp` hands back `/var/…` where git and `pwd` say `/private/var/…`, and the two never compare equal.
- **Hook stdin built with `jq -nc`**, in the shape the harness sends (`session_id`, `tool_name`, `tool_input`, `transcript_path`).
- **Every run under `env -u`** for the `KRU_*` kill switches, the `KRU_*` store roots and `CLAUDE_PLUGIN_ROOT`, so neither a switch nor a root set in the parent shell turns a refusal case green or sends a write outside the sandbox.
- **The plugin root passed as `$1`**: the repo root, so the hooks find the real `agents/` and `skills/`.
- **A fresh `session_id` per case** for any hook that writes a once-per-session mark (`require-lead.sh`, `nudge-audit.sh`), or one case's mark lets the next through.
- **A transcript fixture is jsonl written with `jq -c`**, matching what the hook greps for.

## Mutation check

A new case proves nothing until it has gone red. Copy the hook and its test to a scratch dir, symlink `agents/` and `skills/` beside them, break the branch the case covers, run the copy, then delete it. Never edit the real hook to check.
