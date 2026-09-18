# Testing

The hooks are the only tested code. Each `hooks/<name>.sh` has a `hooks/<name>.test.sh` beside it: a plain bash table test.

```sh
for t in hooks/*.test.sh; do bash "$t" || break; done
```

## Writing one

Copy the closest existing `*.test.sh`. They share one shape:

- **Sandboxed `HOME`** from `mktemp -d`, removed by an `EXIT` trap. Hooks write under `~/.kru/`, and a test that reaches the real one pollutes the audit ledger and refusal log.
- **Hook stdin built with `jq -nc`**, in the shape the harness sends (`session_id`, `tool_name`, `tool_input`, `transcript_path`).
- **Every run under `env -u`** for the `KRU_*` kill switches and `CLAUDE_PLUGIN_ROOT`, so a switch set in the parent shell can't turn a refusal case green.
- **The plugin root passed as `$1`**: the repo root, so the hooks find the real `agents/` and `skills/`.
- **A fresh `session_id` per case** for any hook that writes a once-per-session mark (`require-lead.sh`, `nudge-audit.sh`), or one case's mark lets the next through.
- **A transcript fixture is jsonl written with `jq -c`**, matching what the hook greps for.

## Mutation check

A new case proves nothing until it has gone red. Copy the hook and its test to a scratch dir, symlink `agents/` and `skills/` beside them, break the branch the case covers, run the copy, then delete it. Never edit the real hook to check.
