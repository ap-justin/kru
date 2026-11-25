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
check "the independent reviewers take GPT at any tier" 'model_is code-reviewer openai/gpt-6.2-sol && model_is architecture-reviewer openai/gpt-6.2-sol'
check "every other seat takes GLM by tier" 'model_is stripe-specialist zai/glm-5.3 && model_is test-writer zai/glm-5.3-flash && model_is dispatch-auditor zai/glm-5.3-flash'
check "a seat's effort carries over unchanged, and none is invented" 'effort_is code-reviewer high && effort_is dispatch-auditor medium && effort_is react-ui-builder "" && effort_is test-writer ""'
# grep exits 1 for "no match" and 2 for an error: `! grep` would pass on both, so the clean read is
# exit 1 exactly, paired with planted names the same pattern must find
model_re='claude-(opus|sonnet|haiku|fable)|\b(Opus|Sonnet|Haiku|Fable)\b'
grep -rEq "$model_re" "$out"; scan=$?
check "no Claude model name is anywhere in the build" '[ "$scan" -eq 1 ]' "grep exit $scan"
mkdir -p "$sandbox/planted"; printf 'pin claude-opus-5-5\n' > "$sandbox/planted/id"; printf 'ask Sonnet\n' > "$sandbox/planted/word"
check "the Claude model scan finds a planted model id and a planted model word" 'grep -rEl "$model_re" "$sandbox/planted" | wc -l | grep -q "^ *2$"'
check "reflect and text-fix say they need a Claude Code session and stop there" 'for n in reflect text-fix; do grep -q "needs a Claude Code session" "$out/skills/$n/SKILL.md" && [ "$(wc -l < "$out/skills/$n/SKILL.md")" -lt 12 ] || exit 1; done'
check "plugin-root and tool names are rewritten" '! grep -rq "CLAUDE_PLUGIN_ROOT" "$out/skills" && grep -q "<plugin-root>/references/routing.md" "$out/skills/lead/SKILL.md"'

# the check fails on each thing it guards, and says which: a bare non-zero exit would stay green
# if the check died for some other reason
edit() { sed "$1" "$2" > "$sandbox/x" && cp "$sandbox/x" "$2"; }
mutate() { # <label> <text the check must print> <edit, run inside a copy of the built tree>
  rm -rf "$sandbox/leak"; cp -R "$out" "$sandbox/leak"
  (cd "$sandbox/leak" && eval "$3")
  msg=$(bash "$build" --check "$sandbox/leak" 2>&1); c=$?
  report "$1" "$([ "$c" -ne 0 ] && printf '%s' "$msg" | grep -qF -- "$2" && echo true || echo false)" "exit $c, wanted [$2] in: $msg"
}
mutate "a plugin-root variable left in a skill fails the check" "CLAUDE_PLUGIN_ROOT left" 'printf "%s\n" "run \${CLAUDE_PLUGIN_ROOT}/x" >> skills/lead/SKILL.md'
mutate "a Claude tool name left in a skill fails the check" 'Claude Code tool name `Bash` left' 'printf "%s\n" "then use the \`Bash\` tool" >> skills/lead/SKILL.md'
mutate "a Claude model name left in a skill fails the check" "Claude model name 'claude-opus' left" 'printf "%s\n" "pin claude-opus-5-5" >> skills/lead/SKILL.md'
mutate "a subagent_type left in a skill fails the check" "skills/lead/SKILL.md: subagent_type left" 'printf "%s\n" "set subagent_type to x" >> skills/lead/SKILL.md'
mutate "a role that is not TOML fails the check" "code-reviewer.toml: does not parse as TOML" 'printf "%s\n" "not = = toml" >> roles/code-reviewer.toml'
mutate "a skill whose name differs from its folder fails the check" "skill folder lead: frontmatter name is 'leader'" 'edit "s/^name: lead\$/name: leader/" skills/lead/SKILL.md'
mutate "a role pinned off the model table fails the check" "code-reviewer.toml: model 'moonshotai/kimi-k3' / effort 'high' is not the table's" 'edit "s#^model = .*#model = \"moonshotai/kimi-k3\"#" roles/code-reviewer.toml'
mutate "a role on a model outside the gateway list fails the check" "code-reviewer.toml: model 'zz/unlisted' is not a gateway model" 'edit "s#^model = .*#model = \"zz/unlisted\"#" roles/code-reviewer.toml'
mutate "a role with an empty description fails the check" "code-reviewer.toml: needs name = file name, a description and developer_instructions" 'edit "s#^description = .*#description = \"\"#" roles/code-reviewer.toml'
mutate "a role file missing fails the check" "role count differs from the seat count" 'rm roles/test-writer.toml'
mutate "a manifest without its hooks key fails the check" "manifest has no hooks" 'jq "del(.hooks)" .codex-plugin/plugin.json > "$sandbox/x" && cp "$sandbox/x" .codex-plugin/plugin.json'
mutate "a manifest path that is not ./ fails the check" "manifest skills path 'skills/' is not a ./ path" 'jq ".skills = \"skills/\"" .codex-plugin/plugin.json > "$sandbox/x" && cp "$sandbox/x" .codex-plugin/plugin.json'
mutate "a skill dropped from the build fails the check" "skills differ from the source: ['lead']" 'rm -rf skills/lead'
mutate "a manual-only skill without its policy file fails the check" "skill reflect: implicit-use policy file does not match the source" 'rm "skills/reflect/"agents/*.yaml'
mutate "a hook command the check cannot read fails the check" "unreadable command" 'edit "s/codex-adapter\\.sh/codex-adaptor.sh/" hooks/hooks.json'
mutate "a hook whose script is not in the tree fails the check" "no hooks/lead-first.sh in the tree" 'rm hooks/lead-first.sh'
mutate "a plugin-root path that resolves in the source but not in the build fails the check" "<plugin-root>/README.md exists in the source but not in the build" 'printf "%s\n" "see <plugin-root>/README.md" >> skills/lead/SKILL.md'

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

# a failed build changes nothing: the previous tree stays whole, no temp folder is left, and a rerun
# after the cause is gone succeeds
fsrc="$sandbox/fsrc"; cp -R "$src" "$fsrc"; rm "$fsrc/agents/zz-new-seat.md"
fbuild="$fsrc/scripts/build-codex.sh"
fout="$sandbox/fbuilds/out"
bash "$fbuild" "$fout" >/dev/null 2>&1
cp -R "$fout" "$sandbox/fprev"
mkdir "$fsrc/skills/zz-broken"
msg=$(bash "$fbuild" "$fout" 2>&1); c=$?
check "a build that fails says which skill and exits 1" '[ "$c" -eq 1 ] && printf "%s" "$msg" | grep -q "skills/zz-broken: no SKILL.md"' "exit $c [$msg]"
check "a failed build leaves the previous tree intact" 'diff -r "$sandbox/fprev" "$fout" >/dev/null' "$(diff -rq "$sandbox/fprev" "$fout" 2>&1 | head -3)"
check "a failed build leaves no temp folder beside the tree" '[ "$(ls -A "$sandbox/fbuilds")" = "out" ]' "$(ls -A "$sandbox/fbuilds")"
rmdir "$fsrc/skills/zz-broken"
bash "$fbuild" "$fout" >/dev/null 2>&1; c=$?
check "a rerun after removing the cause succeeds" '[ "$c" -eq 0 ] && bash "$fbuild" --check "$fout" >/dev/null 2>&1' "exit $c"
mkdir "$fsrc/skills/zz-broken"
bash "$fbuild" "$sandbox/fbuilds/fresh" >/dev/null 2>&1; c=$?
check "a failed first build leaves neither a tree nor a temp folder" '[ "$c" -eq 1 ] && [ "$(ls -A "$sandbox/fbuilds")" = "out" ]' "exit $c [$(ls -A "$sandbox/fbuilds")]"
rmdir "$fsrc/skills/zz-broken"

# an install refused for a foreign role file writes nothing: the message names the file, the plugin
# dir and the other roles are absent, and what was there is as it was
ihome="$sandbox/ihome"; mkdir -p "$ihome/agents"
printf 'name = "code-reviewer"\n# mine\n' > "$ihome/agents/code-reviewer.toml"
printf '# kru-codex-build\nname = "gone-seat"\n' > "$ihome/agents/gone-seat.toml"
printf 'name = "mine"\n' > "$ihome/agents/mine.toml"
cp -R "$ihome" "$sandbox/ihome-before"
msg=$(bash "$build" --install "$ihome" 2>&1); c=$?
check "install over a foreign role file exits non-zero and names the file" '[ "$c" -eq 1 ] && printf "%s" "$msg" | grep -qF "$ihome/agents/code-reviewer.toml"' "exit $c [$msg]"
check "a refused install writes nothing" '[ ! -e "$ihome/plugins" ] && diff -r "$sandbox/ihome-before" "$ihome" >/dev/null' "$(diff -rq "$sandbox/ihome-before" "$ihome" 2>&1 | head -3)"
rm -rf "$ihome"; mkdir -p "$ihome"
bash "$build" --install "$ihome" >/dev/null 2>&1
printf 'name = "code-reviewer"\n# mine\n' > "$ihome/agents/code-reviewer.toml"
printf '# kru-codex-build\nname = "gone-seat"\n' > "$ihome/agents/gone-seat.toml"
cp -R "$ihome" "$sandbox/ihome-before2"
bash "$build" --install "$ihome" >/dev/null 2>&1; c=$?
check "a refused install over an earlier one leaves the plugin, the roles and a stale role as they were" '[ "$c" -eq 1 ] && diff -r "$sandbox/ihome-before2" "$ihome" >/dev/null' "exit $c $(diff -rq "$sandbox/ihome-before2" "$ihome" 2>&1 | head -3)"

# exit codes: 0 done, 1 failed, 64 usage
help=$(bash "$build" --help 2>"$sandbox/helperr"); c=$?
check "--help prints the usage to stdout and exits 0" '[ "$c" -eq 0 ] && printf "%s" "$help" | grep -q "^usage:" && [ ! -s "$sandbox/helperr" ]' "exit $c"
bash "$build" --nope >/dev/null 2>&1; c=$?
check "a bad flag exits 64" '[ "$c" -eq 64 ]' "exit $c"
bash "$build" >/dev/null 2>&1; c=$?
check "no arguments exits 64" '[ "$c" -eq 64 ]' "exit $c"
printf 'x' > "$sandbox/afile"
msg=$(bash "$build" "$sandbox/afile" 2>&1); c=$?
check "an output path that is a file exits 1 with one line, no traceback" '[ "$c" -eq 1 ] && ! printf "%s" "$msg" | grep -q Traceback && printf "%s" "$msg" | grep -qF "$sandbox/afile" && [ "$(printf "%s\n" "$msg" | wc -l | tr -d " ")" = 1 ] && [ "$(cat "$sandbox/afile")" = x ]' "exit $c [$msg]"
msg=$(bash "$build" --check "$sandbox/afile" 2>&1); c=$?
check "--check of a file exits 1 with no traceback" '[ "$c" -eq 1 ] && ! printf "%s" "$msg" | grep -q Traceback' "exit $c [$msg]"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
