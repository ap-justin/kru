#!/bin/bash
# tests for build-codex.sh: the build is repeatable, the install writes only what it owns, and the
# check catches what the build must never leave. run: bash scripts/build-codex.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
build="$here/build-codex.sh"

sandbox=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$sandbox"' EXIT
pass=0 fail=0
report() {
  if $2; then pass=$((pass + 1)); else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  %s\n' "$1" "$3"
  fi
}
check() { report "$1" "$( eval "$2" && echo true || echo false)" "${3:-}"; }

out="$sandbox/out"
bash "$build" "$out" >/dev/null 2>&1
check "builds a tree with a manifest" 'jq -e ".name == \"kru\" and .skills == \"./skills/\"" "$out/.codex-plugin/plugin.json" >/dev/null'
check "the build passes its own check" 'bash "$build" --check "$out" >/dev/null 2>&1'

cp -R "$out" "$sandbox/first"
bash "$build" "$out" >/dev/null 2>&1
check "a rebuild is byte-identical" 'diff -r "$sandbox/first" "$out" >/dev/null'

want=$(ls "$root/skills" | wc -l | tr -d ' ')
check "every skill folder is built" '[ "$(ls "$out/skills" | wc -l | tr -d " ")" = "$want" ]'
manual=$(grep -rl --include=SKILL.md '^disable-model-invocation: true' "$root/skills" | wc -l | tr -d ' ')
check "exactly the manual-only skills carry the implicit-use policy" '[ "$(ls "$out"/skills/*/agents/openai.yaml | wc -l | tr -d " ")" = "$manual" ] && grep -q "allow_implicit_invocation: false" "$out/skills/reflect/agents/openai.yaml"'
check "every seat is a role" '[ "$(ls "$out/roles" | wc -l | tr -d " ")" = "$(ls "$root/agents" | wc -l | tr -d " ")" ]'
check "a reviewer is read-only and a builder is not" 'grep -q "^sandbox_mode = \"read-only\"" "$out/roles/code-reviewer.toml" && ! grep -q "^sandbox_mode" "$out/roles/react-ui-builder.toml"'
model_is() { grep -q "^model = \"$2\"" "$out/roles/$1.toml"; }
effort_is() { if [ -z "$2" ]; then ! grep -q "^model_reasoning_effort" "$out/roles/$1.toml"; else grep -q "^model_reasoning_effort = \"$2\"" "$out/roles/$1.toml"; fi; }
check "UI seats take Kimi by tier" 'model_is react-ui-builder moonshotai/kimi-k3.1-pro && model_is visual-reviewer moonshotai/kimi-k3'
check "the independent reviewers take DeepSeek at any tier" 'model_is code-reviewer deepseek/deepseek-v4.1-flash && model_is architecture-reviewer deepseek/deepseek-v4.1-flash'
check "every other seat takes GLM by tier" 'model_is stripe-specialist zai/glm-5.3 && model_is test-writer zai/glm-5.3-flash && model_is dispatch-auditor zai/glm-5.3-flash'
check "a seat's effort carries over unchanged, and none is invented" 'effort_is code-reviewer high && effort_is dispatch-auditor medium && effort_is react-ui-builder "" && effort_is test-writer ""'
check "no Claude model name is anywhere in the build" '! grep -rEq "claude-(opus|sonnet|haiku|fable)|\b(Opus|Sonnet|Haiku|Fable)\b" "$out"'
check "reflect and text-fix say they need a Claude Code session and stop there" 'for n in reflect text-fix; do grep -q "needs a Claude Code session" "$out/skills/$n/SKILL.md" && [ "$(wc -l < "$out/skills/$n/SKILL.md")" -lt 12 ] || exit 1; done'
check "plugin-root and tool names are rewritten" '! grep -rq "CLAUDE_PLUGIN_ROOT" "$out/skills" && grep -q "<plugin-root>/references/routing.md" "$out/skills/lead/SKILL.md"'

# the check fails on each thing it guards
leak() { # <name> <file> <text>
  rm -rf "$sandbox/leak"; cp -R "$out" "$sandbox/leak"
  printf '%s\n' "$3" >> "$sandbox/leak/$2"
  bash "$build" --check "$sandbox/leak" >/dev/null 2>&1 && ok=false || ok=true
  report "$1" "$ok" "the check passed"
}
leak "a plugin-root variable left in a skill fails the check" skills/lead/SKILL.md 'run ${CLAUDE_PLUGIN_ROOT}/x'
leak "a Claude tool name left in a skill fails the check" skills/lead/SKILL.md 'then use the `Bash` tool'
leak "a Claude model name left in a skill fails the check" skills/lead/SKILL.md 'pin claude-opus-5-5'
leak "a role that is not TOML fails the check" roles/code-reviewer.toml 'not = = toml'
rm -rf "$sandbox/leak"; cp -R "$out" "$sandbox/leak"
sed 's/^name: lead$/name: leader/' "$sandbox/leak/skills/lead/SKILL.md" > "$sandbox/x" && cp "$sandbox/x" "$sandbox/leak/skills/lead/SKILL.md"
bash "$build" --check "$sandbox/leak" >/dev/null 2>&1 && ok=false || ok=true
report "a skill whose name differs from its folder fails the check" "$ok" "the check passed"

rm -rf "$sandbox/leak"; cp -R "$out" "$sandbox/leak"
sed 's#^model = "deepseek/deepseek-v4.1-flash"#model = "moonshotai/kimi-k3"#' "$sandbox/leak/roles/code-reviewer.toml" > "$sandbox/x" && cp "$sandbox/x" "$sandbox/leak/roles/code-reviewer.toml"
bash "$build" --check "$sandbox/leak" >/dev/null 2>&1 && ok=false || ok=true
report "a role pinned off the model table fails the check" "$ok" "the check passed"

# a seat in no kind of the model table fails the build until it is placed
src="$sandbox/src"; mkdir -p "$src"
git -C "$root" ls-files -z | tar -C "$root" --null -T - -cf - | tar -C "$src" -xf -
sed 's/^name: stripe-specialist$/name: zz-new-seat/' "$root/agents/stripe-specialist.md" > "$src/agents/zz-new-seat.md"
msg=$(bash "$src/scripts/build-codex.sh" "$sandbox/unlisted" 2>&1); c=$?
check "a new seat missing from the model table fails the build" '[ "$c" -ne 0 ] && printf "%s" "$msg" | grep -q "agents/zz-new-seat.md is in no seat kind"' "$msg"

# the install
home="$sandbox/codex-home"
mkdir -p "$home/agents"
printf 'model = "kept"\n' > "$home/config.toml"
printf 'name = "mine"\ndescription = "x"\ndeveloper_instructions = "x"\n' > "$home/agents/mine.toml"
msg=$(bash "$build" --install "$home" 2>&1)
plugin="$home/plugins/cache/kru/kru/local"
check "install puts the plugin where Codex keeps an installed one" '[ -f "$plugin/.codex-plugin/plugin.json" ]'
check "install puts the roles in the home's agents folder" '[ "$(ls "$home"/agents/*.toml | wc -l | tr -d " ")" = "$(( $(ls "$root/agents" | wc -l) + 1 ))" ]'
check "install leaves config.toml and a role it did not write alone" '[ "$(cat "$home/config.toml")" = "model = \"kept\"" ] && [ -f "$home/agents/mine.toml" ]'
check "install resolves the plugin root to the install path" 'grep -q "$plugin/references/routing.md" "$plugin/skills/lead/SKILL.md" && ! grep -rq "<plugin-root>" "$plugin/skills" "$plugin/roles"'
check "install names the config entry and does not write it" 'printf "%s" "$msg" | grep -q "plugins.\"kru@kru\"" && ! grep -q plugins "$home/config.toml"'
check "an installed tree passes the check" 'bash "$build" --check "$plugin" >/dev/null 2>&1'
bash "$build" --install "$home" >/dev/null 2>&1
check "a second install is a no-op in effect" '[ "$(ls "$home"/agents/*.toml | wc -l | tr -d " ")" = "$(( $(ls "$root/agents" | wc -l) + 1 ))" ]'

mkdir -p "$sandbox/other" && printf 'x' > "$sandbox/other/file"
bash "$build" "$sandbox/other" >/dev/null 2>&1; c=$?
check "a directory the script did not build is refused, not wiped" '[ "$c" -ne 0 ] && [ -f "$sandbox/other/file" ]'

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
