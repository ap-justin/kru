# kru for Codex

Codex loads no Claude Code plugin, so this repo also builds one for it. The build is generated and never committed: every skill, every seat (as an agent role) and the hooks, from the same files as the Claude Code plugin.

```bash
bash scripts/build-codex.sh /tmp/kru-codex            # the plugin tree
bash scripts/build-codex.sh --install ~/.codex        # into a Codex home: the plugin under plugins/cache, the roles under agents
bash scripts/build-codex.sh --check /tmp/kru-codex    # the checks scripts/verify.sh runs on a build
```

The install leaves `config.toml` alone and prints the two lines that turn the plugin on. Hook commands need a one-time trust in Codex.

## What is missing

- `reflect` and `text-fix` need a Claude Code session and say so in Codex.
- A seat's tool list does not carry over; the read-only seats get a read-only sandbox instead.
- Seats run on the Codex models in `MODEL_TABLE`, by seat kind, never a Claude model.
- The plugin's settings screen has no counterpart: export the same `KRU_*` variables.
- The Claude-only `check-task-tools` hook is dropped.
- The build has not been run in a live Codex session.

`PORTING.md` has the layout, every rewrite rule, the hook mapping and the Codex source line behind each.
