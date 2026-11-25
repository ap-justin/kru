# The Codex build

`scripts/build-codex.sh` generates a Codex plugin from this tree. Nothing it writes is committed, so the build cannot fall behind the Claude Code plugin: both come from the same skills, seat files and hook scripts. `scripts/verify.sh` builds into a temp dir and checks the result on every run.

This file says what each part becomes, every rewrite rule, and what does not carry over. How to build and install it is in `codex/README.md`. Source lines are in the Codex repository at tag `rust-v0.172.0`; each is `path:lines` under `codex-rs/`. The build has not been run in a live Codex session. Every mapping below rests on reading those sources, and each one a live session could contradict is marked **unverified**.

```
scripts/build-codex.sh <out-dir>               build the plugin tree
scripts/build-codex.sh --install <codex-home>  build into <codex-home>/plugins/cache/kru/kru/local and write
                                               the roles into <codex-home>/agents; config.toml is not touched
scripts/build-codex.sh --check <dir>           the checks verify runs on a build
scripts/build-codex.sh --verify                build into a temp dir, check it, remove it
```

## Layout

| kru path | Codex path | why |
|---|---|---|
| `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` | A plugin's manifest is looked for at `.codex-plugin/plugin.json` first, then `.claude-plugin/plugin.json` (`exec-server-protocol/src/protocol.rs:56-60`). The manifest takes `name`, `version`, `description`, `keywords`, `skills`, `mcpServers`, `apps`, `hooks`, `interface` (`core-plugins/src/manifest.rs:50-73`) and, read separately, `commands` (`:75-79`). It has no agents field. Paths must start with `./` and may not contain `..` (`:616-637`). The build writes `skills` and `hooks` only. |
| `skills/<name>/` | `skills/<name>/` | Same folder, same `SKILL.md`. Frontmatter is cut to `name` and `description`, the two keys Codex reads (`skills/src/parser.rs:6-14`). A skill's name is its plugin's name plus a colon plus its own name, so `kru:lead` stays `kru:lead` (`ext/skills/src/loader/namespace.rs:11-19,176-181`). |
| `skills/<name>/` with `disable-model-invocation: true` | `skills/<name>/` plus `skills/<name>/agents/openai.yaml` | See *Manual-only skills*. |
| `agents/<seat>.md` | `roles/<seat>.toml` in the plugin, copied to `<codex-home>/agents/<seat>.toml` by `--install` | A Codex agent role is a TOML file (`agent-roles/src/agent_role_config.rs:20-28`). Roles load from `<config folder>/agents` (`agent-roles/src/loader.rs:75-81`), any `*.toml` below it (`agent-roles/src/discovery.rs:27-33`). A plugin's own `agents/` is not read for roles, which is why the installer copies them. |
| `agents/<seat>.md` | `agents/<seat>.md`, cut to `name`, `description` and `tools` | Not for Codex. The hook scripts look here for a seat's existence, its `tools:` line and its return-pass heading. The manifest names no agents path, so Codex does not load them. |
| `hooks/hooks.json` | `hooks/hooks.json`, generated | See *Hooks*. |
| `hooks/*.sh` (not `*.test.sh`) | `hooks/*.sh`, byte for byte | The scripts run unchanged. |
| (new) `hooks/codex-adapter.sh` | `hooks/codex-adapter.sh` | The one reshaping layer between Codex's hook payloads and those scripts. |
| `references/`, `ROSTER.md`, `SOURCES.md`, `TRACKER.md`, `PREFERENCES.md`, `scripts/kru-store.sh`, `scripts/kru-merge-lines.sh`, `scripts/asset/`, `LICENSE`, `NOTICE`, `VERSION` | same paths | Skills and hooks point at them. `--check` fails when a plugin-root path that exists in the source is missing from the build. |
| `.claude/`, `brand/`, `evals/`, the other `scripts/`, tests | not shipped | They serve this repository, not an installed plugin. |

`--install` puts the plugin at `<codex-home>/plugins/cache/kru/kru/local`: installed plugins live at `plugins/cache/<marketplace>/<plugin>/<version>` (`core-plugins/src/store.rs:112-120`), and a version folder named `local` is the one picked when present (`core-plugin-common/src/installed.rs:10-11,47-68`).

A plugin only loads when the config names it: plugins come from the `plugins` table of the config layers and nowhere else (`core-plugins/src/marketplace_policy.rs:298-316`, `core-plugins/src/loader.rs:182-187`), as `[plugins."<name>@<marketplace>"]` with `enabled` (`config/src/types.rs:1170-1178,1198-1201`; the key is split on its last `@`, `core-plugin-common/src/plugin_id.rs:26-46`). The installer leaves `config.toml` alone and prints the two lines to add:

```toml
[plugins."kru@kru"]
enabled = true
```

## Skills

Every `skills/<name>/` is built, 119 today. Files in a skill folder other than `SKILL.md` are copied, with the rules below applied to the Markdown ones. A skill name is at most 64 characters and a description is required (`skills/src/parser.rs:82-85`); `--check` enforces both and that the folder name equals the frontmatter `name`.

### Manual-only skills

A skill with `disable-model-invocation: true` (32 today) becomes a skill, not a command, with `agents/openai.yaml` beside its `SKILL.md`:

```yaml
policy:
  allow_implicit_invocation: false
```

Why a skill and not a command:

- A skill can be kept from implicit use. The file is `agents/openai.yaml` (`ext/skills/src/loader/mod.rs:22-23`), its `policy.allow_implicit_invocation` is read by `skills/src/metadata.rs:53-56,93-98`, and a skill without it is implicit by default (`skills/src/model.rs:23-28`). Explicit selection by `$name` does not consult the field (`skills/src/selection.rs:44-112`).
- A command is not a separate thing in 0.172. The manifest's `commands` paths are migrated into skills named `source-command-<name>` (`core-plugins/src/command_migration.rs:14,339-341`, `core-plugins/src/command_migration/plugin.rs:25-53`), nothing in the migration marks them manual-only, and a migrated command is dropped when it uses `$ARGUMENTS`, `!` shell lines or `@` file references (`command_migration.rs:418-427`) or runs past 4,000 bytes (`command_migration/plugin.rs:17`). kru's manual skills hit all three.

So the plugin has no `commands`, and "commands" in the install listing is 0.

A skill is called with `$name`, `$kru:name` for a plugin skill (`skills/src/mentions.rs:41,79-86`; `:226-228` lets a name hold a colon).

### Rewrite rules

All of them live in the tables at the top of `scripts/build-codex.sh`, which `--check` reads too. A name added to the repo with no rule here fails `verify`.

| rule | in | out | why |
|---|---|---|---|
| plugin root | `${CLAUDE_PLUGIN_ROOT}` | the install path (`--install`), else `<plugin-root>` with a one-line note after the frontmatter saying what it is | `PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT` are set for a plugin's hook commands only (`hooks/src/engine/discovery.rs:312-320`), so a skill the model reads, and a shell command it runs, need a path. |
| tool names, in backticks | `Agent` | `spawn_agent` | The Codex tool names: `spawn_agent` (`core/src/tools/handlers/multi_agents/spawn.rs:34`, `multi_agents_v2/spawn.rs:37`), `send_input`, `wait_agent`, `close_agent` (`multi_agents_spec.rs:193,292,346`), `exec_command` (`unified_exec/exec_command.rs:96`), `apply_patch` (`handlers/apply_patch.rs:289`), `update_plan` (`handlers/plan_spec.rs:43`). |
| | `Bash` | `exec_command` | |
| | `Edit`, `Write` | `apply_patch` | |
| | `Read` | the verb *read* | Codex has no read tool, so a file is read through the shell. |
| | `Grep`, `Glob` | `rg`, `rg --files` | the same, through the shell |
| | `WebFetch` | `curl` | the same |
| | `SendMessage` | `send_input` | |
| | `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`, `TodoWrite` | `update_plan` | |
| | `TaskOutput`, `TaskStop` | `wait_agent`, `close_agent` | |
| | `Skill`, `Skill tool`, `Skill call` | `$skill` mention | Codex has no skill tool; a skill is selected by a `$name` mention. |
| permission patterns | `Bash(...)`, `Read(...)` | unchanged | They are Claude Code settings syntax, quoted by the skills that explain them. |
| slash form | `/kru:<skill>` | `$kru:<skill>` | the mention form above |
| dispatch field | `subagent_type` | `agent_type` | the `spawn_agent` argument (`multi_agents/spawn.rs:229-238`, `multi_agents_v2/spawn.rs:201-211`) |
| model ids | `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5` | the model most seats take for that tier, per *Models* | No Claude model name may appear in the output. |
| model names | `Opus`, `Sonnet`, `Haiku`, `Fable`, with or without a version or "Claude " | `a model` | the same |
| frontmatter | every key but `name`, `description` | dropped | Codex reads those two (`skills/src/parser.rs:6-14`); the rest is Claude Code's. |

Skills about other platforms use some of these words as their own vocabulary (`Agent` and `Workflow` are Cloudflare classes), so the tool-name rules skip `workers-best-practices`, `agents-sdk`, `cloudflare`, `durable-objects`, `wrangler` and `nextjs-on-cloudflare`. The rest of the rules still apply to them.

The rules are mechanical. A skill whose subject is Claude Code itself (`update`, `eval-review`, `sky`, `claude-code-delegation`) is rewritten by the same rules and can read oddly where it quotes Claude Code's own tool names or models.

### Nested passes

`reflect` and `text-fix` run through a nested `claude -p` session. A Codex session has no Claude login, so the nested call cannot run there. In this build both skills keep their name and description and their body is replaced by one notice: the pass needs a Claude Code session, say so and stop, do not attempt the call. A `codex exec` version is a later change.

## Seats

Each `agents/<seat>.md` becomes `roles/<seat>.toml`:

| field | from |
|---|---|
| `name` | the seat's `name`, which must equal the file name. A role file found by discovery must define one (`agent-roles/src/agent_role_config.rs:73-88`). |
| `description` | the seat's `description`, kept. It is required and may not be blank (`agent_role_config.rs:120-132`, `agent-roles/src/loader.rs:237-249`). |
| `developer_instructions` | the seat's body, rewritten by the rules above. Required, not blank (`agent_role_config.rs:134-157`). |
| `sandbox_mode = "read-only"` | the seats whose description says *does not edit*, *no edits* or *Reports only*: the five reviewers and auditors (`accessibility-reviewer`, `architecture-reviewer`, `code-reviewer`, `ux-auditor`, `visual-reviewer`). `sandbox_mode` is a config field (`config/src/config_toml.rs:235`) and a role file carries the whole config surface alongside its three own keys (`agent_role_config.rs:20-28`); the value is spelled `read-only` (`protocol/src/config_types.rs:102-112`). |
| `model`, `model_reasoning_effort` | the table below (`config_toml.rs:179,414`). |

Not carried: `tools:` (the role file's keys read above include no tool allowlist), `effort` as a Claude key, and `experimental`. The seat's reading limits and "report, do not edit" text stay in its body.

A role's `<plugin-root>` is resolved the same way as in skills: to the install path with `--install`, else left with a note at the top of the instructions.

### Models

A Codex session runs on a fixed set of models, never a Claude one. The table is `MODEL_TABLE` in `scripts/build-codex.sh`, in one place. A seat takes the model of its kind and, within the kind, of the tier its Claude `model:` pin names. Its `effort:` carries over unchanged as `model_reasoning_effort` (the values are `ReasoningEffort`'s, `protocol/src/openai_models.rs:75-88`), and a seat with no `effort:` gets none. Role fields: `model` is `config/src/config_toml.rs:179`, `model_reasoning_effort` is `:414`.

| seat kind | seats | Opus | Sonnet | Haiku |
|---|---|---|---|---|
| UI | `react-ui-builder`, `svelte-ui-builder`, `hono-ui-builder`, `web-components-builder`, `extension-builder`, `motion-designer`, `conversion-copywriter`, `ux-auditor`, `visual-reviewer`, `accessibility-reviewer` | `moonshotai/kimi-k3.1-pro` | `moonshotai/kimi-k3` | none: fails the build |
| independent reviewer | `code-reviewer`, `architecture-reviewer` | `deepseek/deepseek-v4.1-flash` | `deepseek/deepseek-v4.1-flash` | `deepseek/deepseek-v4.1-flash` |
| other | every remaining seat, listed by name in the table | `zai/glm-5.3` | `zai/glm-5.3-flash` | `zai/glm-5.3-flash` |

Every seat is listed once. A seat in no kind, a name with no seat file, a seat listed twice, and a kind with no entry for a seat's tier all fail the build, so a new seat has to be placed before verify passes. `--check` also fails when a role's model or effort is not what the table gives its seat, and when a Claude model name appears anywhere in the build, scripts and seat files included. In documents, a Claude model id becomes the model most seats take for that tier (`zai/glm-5.3` for Opus, `zai/glm-5.3-flash` for Sonnet and Haiku), and a display name becomes `a model`.

## Hooks

Codex runs hooks of the same wire shape as Claude Code: a command reads the event as JSON on stdin and answers with an exit status and JSON on stdout. Exit status 2 with a reason on stderr blocks a `PreToolUse` call (`hooks/src/events/pre_tool_use.rs:268-284`). The events a plugin's `hooks` file may declare (`protocol/src/hooks.rs:9-38`) include `SubagentStart` and `SubagentStop` as well as `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `SessionEnd`, `Stop` and `Interrupt`. The file is `{"description": ..., "hooks": {Event: [{"matcher": ..., "hooks": [{"type": "command", "command": ..., "timeout": seconds}]}]}}` (`config/src/hook_config.rs:12-19`, `protocol/src/hooks.rs:140-172`).

Every hook command is `bash "${PLUGIN_ROOT}/hooks/codex-adapter.sh" <Event> <hook> [args] "${PLUGIN_ROOT}"`. The adapter reshapes the payload, runs `hooks/<hook>.sh` unchanged, and reshapes what comes back.

### What the adapter changes

On the way in:

| Codex sends | the script reads | source |
|---|---|---|
| a `spawn_agent` call, `tool_name: "spawn_agent"`, `tool_input` the call's arguments | `tool_input.subagent_type` from `agent_type`, `prompt` from `message`, `description` from `task_name` | name and arguments: `core/src/tools/registry.rs:1217-1234`, `multi_agents/spawn.rs:229-238`, `multi_agents_v2/spawn.rs:201-211` |
| a shell call, `tool_name: "Bash"`, `tool_input.command` | unchanged | `hook_names.rs:54-56`, `unified_exec/exec_command.rs:331-342` |
| an edit, `tool_name: "apply_patch"`, `tool_input.command` the patch text | unchanged. The matcher `Write\|Edit\|Bash` still selects it, because `Write` and `Edit` are matcher aliases of `apply_patch`. | `hook_names.rs:34-39`, `handlers/apply_patch.rs:370-375` |
| a shell command that only reads a lead, designer, brainstorm or brief `SKILL.md` (`cat`, `head`, `tail`, `nl`, `bat`, `sed -n`) | a `Read` of that file | the scripts' own test for "the contract was loaded" |
| `transcript_path`, which is nullable | a shadow transcript the adapter keeps, in the shape the two transcript gates scan | `hooks/src/schema.rs:279-297` |

On the way out: an `updatedInput` from `check-handoff` gets `permissionDecision: "allow"` beside it, because Codex rejects an `updatedInput` without it (`hooks/src/engine/output_parser.rs:441-457`) and Claude Code did not need it; and the changed `prompt` goes back into `message` on a copy of the call's original arguments, so no argument Codex did not expect is added (`multi_agents_v2/spawn.rs:201` denies unknown fields). Exit status, stderr and every other line of JSON pass through. Hook output is read the same way in both: `additionalContext` and `systemMessage` on `SessionStart` (`schema.rs:385-404`), `decision: "block"` with a `reason` on `Stop` and `SubagentStop` (`schema.rs:452-480`).

### The mapping

| kru hook | Claude Code event and matcher | Codex event and matcher | status |
|---|---|---|---|
| `setup-nudge` | `SessionStart` `startup` | `SessionStart` `startup` | ported |
| `lead-first` | `SessionStart` `startup\|clear\|resume\|compact\|fork` | the same; Codex's sources are `startup`, `resume`, `clear`, `compact`, `fork` (`hooks/src/events/session_start.rs:24-40`) | ported |
| `store-sync start` | `SessionStart` | `SessionStart` | ported |
| `store-sync stop` | `Stop` | `Stop` (matchers are ignored on `Stop`, `hooks/src/events/common.rs:129-149`) | ported |
| `nudge-audit` | `Stop` | `Stop` | ported |
| `check-handoff` | `PreToolUse` `Agent` | `PreToolUse` `spawn_agent` | ported, payload and output reshaped as above |
| `log-dispatch` | `PostToolUse` `Agent` | `PostToolUse` `spawn_agent` | ported, payload reshaped as above |
| `log-return` | `SubagentStop` | `SubagentStop`. Codex sends the role name as `agent_type`, `last_assistant_message`, `agent_transcript_path` and `stop_hook_active`, the fields the script reads (`schema.rs:606-623`). | ported |
| `require-lead` | `PreToolUse` `*` | `PreToolUse` `*` | ported; its transcript scan reads the shadow transcript |
| `brainstorm-guard` | `PreToolUse` `Write\|Edit\|NotebookEdit\|Bash` | `PreToolUse` `Write\|Edit\|Bash`; `NotebookEdit` has no Codex tool | ported; its transcript scan reads the shadow transcript |
| (adapter) `record-prompt` | n/a | `UserPromptSubmit` (`schema.rs:567-584`) | new; writes the shadow transcript |
| `check-task-tools` | `SessionStart` `startup` | none | dropped: it warns that Claude Code's task tools are switched off, and Codex has no such switch (its worklist tool is `update_plan`) |

`readonly-bash.sh` is sourced by two of the scripts and is not a hook. The tests for the ported hooks are in `hooks/codex-adapter.test.sh`, one section each, run with payloads shaped like the ones above.

### The shadow transcript

`require-lead` and `brainstorm-guard` decide from the session's transcript: whether the lead contract was loaded, whether a brainstorm is locked. The gates parse Claude Code's transcript lines. Codex's `transcript_path` is nullable (`schema.rs:287`) and its line format was not read for this build. Rather than drop the two gates, the adapter keeps the facts they read in a file of its own, `tmp/codex-transcripts/<session>.jsonl` under the kru home:

- `record-prompt`, on every `UserPromptSubmit`, appends the prompt as a user line. A `$kru:lead`, `$kru:designer` or `$kru:brainstorm` mention in it also leaves the `<command-name>/kru:<skill></command-name>` tag a slash command would have, which is what the gates look for.
- `require-lead` appends a `Read` line for each shell read of a skill file it lets through.

The scripts then run unchanged on a transcript that has what they scan for. A skill loaded some other way, such as the model opening the file through a tool the adapter does not recognise, is not seen, and the lead gate then fires once, as the first call of any unloaded session does; its message says what to load. **Unverified**: the shadow transcript has not been exercised against a live session's event order.

## What does not carry over

- **Hook trust.** A plugin's hook commands must be trusted before they run (`hooks/src/engine/command_runner.rs:230-249`). The state is stored per hook in the config (`config/src/hook_config.rs:29-38`), which the installer does not edit, so each hook is reviewed and trusted once in Codex.
- **Plugin activation.** Described under *Layout*: two lines in `config.toml`.
- **Plugin options.** The Claude plugin's settings screen (`KRU_STORE_REPO` and the four `KRU_NO_*` switches) has no counterpart; export the same variables. `scripts/kru-store.sh` already honours them.
- **The repo sheet.** `skills/setup` writes the sheet to `.claude/CLAUDE.md`, which Codex does not load on its own. The skills that read it still read that path.
- **Tool allowlists.** A seat's `tools:` line does not become a restriction. The read-only seats get a sandbox instead. Reviewers are told to write their report under `$TMPDIR/kru-review`, which a read-only sandbox may refuse. **Unverified.**
- **`reflect` and `text-fix`.** They stop with a notice, as above.
- **Skill text about Claude Code.** Rewritten mechanically; see *Rewrite rules*.
- **MCP servers, apps, `interface` assets.** None are declared. The Claude plugin has none.
- **Events with no kru hook.** `PermissionRequest`, `PreCompact`, `PostCompact`, `SessionEnd`, `SubagentStart`, `Interrupt` and the model-request events have no kru behaviour behind them.
- **A live run.** Nothing here has been run in a Codex session. What is checked is what a build can check: the manifest parses, every skill folder name matches its frontmatter, every role file parses as TOML and carries a name, description and instructions, no `CLAUDE_PLUGIN_ROOT`, Claude Code tool name or Claude model name is left in what Codex or the model reads, every plugin-root path that resolves in the source resolves in the build, and the hook tests pass.

`--check` scans skills, references, the root documents, the role files and the manifests for `CLAUDE_PLUGIN_ROOT` and tool names. `hooks/` and `scripts/` are programs run as they are, and `agents/` is data they read, so they are not scanned for those two; the model-name check covers the whole tree.
