#!/usr/bin/env node
// installs this fork into an opencode config directory, and reports on how it
// sits beside the claude-code fork when both are present.
//
// install is a copy rather than a symlink on purpose: the ported prompts carry a
// {KRU_HOME} placeholder that has to become a real absolute path, and a symlink
// cannot be rewritten on the way through. so the repo is the source, the config
// dir is the build, and `kru-oc sync` is the edit loop.

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, rmSync, statSync, copyFileSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"
import { homedir, tmpdir } from "node:os"
import { execFileSync } from "node:child_process"
import { migrateStore } from "../scripts/kru-store-migrate.mjs"

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..")
// the store's cross-project root, as scripts/kru-store.sh resolves it — KRU_HOME
// is upstream's env var for the store, not this fork's {KRU_HOME} placeholder
const STORE = process.env.KRU_HOME || join(homedir(), ".kru")
const CLAUDE_CACHE = join(homedir(), ".claude", "plugins", "cache", "kru", "kru")

const args = process.argv.slice(2)
const cmd = args.find((a) => !a.startsWith("-")) ?? "help"
const flag = (name) => args.includes(`--${name}`)
const opt = (name) => {
  const i = args.indexOf(`--${name}`)
  return i === -1 ? undefined : args[i + 1]
}

const configDir = () =>
  opt("dir") ??
  process.env.OPENCODE_CONFIG_DIR ??
  join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "opencode")

// what lands where. a source of `kru/` means the support tree the prompts read
// through {KRU_HOME}/kru/ — docs, references, the asset script, the shell hooks.
const LAYOUT = [
  ["agent/kru.md", "agent/kru.md"],
  ["agent/kru", "agent/kru"],
  ["command/kru", "command/kru"],
  ["plugin/kru.ts", "plugin/kru.ts"],
  ["ROSTER.md", "kru/ROSTER.md"],
  ["SOURCES.md", "kru/SOURCES.md"],
  ["TRACKER.md", "kru/TRACKER.md"],
  ["PREFERENCES.md", "kru/PREFERENCES.md"],
  ["VERSION", "kru/VERSION"],
  ["references", "kru/references"],
  ["hooks", "kru/hooks"],
  ["scripts", "kru/scripts"],
]

// the placeholders install fills in. a seat's external_directory block lists
// {KRU_TMP} beside /tmp, so where they coincide the second line is dropped —
// opencode rejects a frontmatter mapping with a repeated key.
const PLACEHOLDERS = () => [
  ["{KRU_HOME}", null],
  ["{KRU_STORE}", STORE],
  ["{KRU_TMP}", tmpdir()],
]
const PLACEHOLDER = /\{KRU_(HOME|STORE|TMP)\}/
function materialize(src, home) {
  let out = src
  for (const [token, value] of PLACEHOLDERS()) out = out.replaceAll(token, value ?? home)
  const seen = new Set()
  return out
    .split("\n")
    .filter((l) => {
      if (!/^ {4}".*": allow$/.test(l)) return true
      if (seen.has(l)) return false
      seen.add(l)
      return true
    })
    .join("\n")
}

const TEXT = /\.(md|sh|ts|mjs|js|json|txt|html|css|py)$/
// the repo's own checks: they run from a checkout, never from a config dir
const DEV_ONLY = new Set(["verify.sh", "verify-tree.mjs", "smoke.sh", "hooks.test.sh", "kru-store-migrate.test.mjs"].map((f) => join(REPO, "scripts", f)))
const version = () => readFileSync(join(REPO, "VERSION"), "utf8").trim()
const log = (...a) => console.log(...a)

function copyTree(from, to, home, stats) {
  const st = statSync(from)
  if (st.isDirectory()) {
    mkdirSync(to, { recursive: true })
    for (const e of readdirSync(from)) {
      if (e === "node_modules" || e.startsWith(".venv") || e === ".DS_Store" || DEV_ONLY.has(join(from, e))) continue
      copyTree(join(from, e), join(to, e), home, stats)
    }
    return
  }
  mkdirSync(dirname(to), { recursive: true })
  if (TEXT.test(from)) {
    const src = readFileSync(from, "utf8")
    // the placeholders are the one thing install materializes; everything
    // else ships as the repo spells it
    const next = materialize(src, home)
    const prev = existsSync(to) ? readFileSync(to, "utf8") : null
    if (prev !== next) {
      writeFileSync(to, next)
      stats.written++
    } else stats.same++
  } else {
    copyFileSync(from, to)
    stats.written++
  }
}

function claudeSide() {
  if (!existsSync(CLAUDE_CACHE)) return null
  // numeric per part: a plain sort puts 0.99.0 after 0.148.0
  const parts = (v) => v.split(/[.+-]/).map((n) => parseInt(n, 10) || 0)
  const newer = (a, b) => {
    const [x, y] = [parts(a), parts(b)]
    for (let i = 0; i < Math.max(x.length, y.length); i++) if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) - (y[i] ?? 0)
    return 0
  }
  const versions = readdirSync(CLAUDE_CACHE).filter((v) => /^\d/.test(v)).sort(newer)
  return versions.length ? versions[versions.length - 1] : null
}

function upstreamPin() {
  // the fork's own version is `<fork>+kru<upstream>`; the pin is the half after +
  const m = version().match(/\+kru(.+)$/)
  return m?.[1]
}

function portCheck() {
  try {
    execFileSync("node", [join(REPO, "scripts", "port.mjs"), "--check", "--quiet"], { stdio: "pipe" })
    return null
  } catch (err) {
    return String(err.stdout ?? "") + String(err.stderr ?? "")
  }
}

function install() {
  const home = configDir()
  const problem = portCheck()
  if (problem && !flag("force")) {
    console.error(`refusing to install an un-normalized tree:\n${problem}\nrun: node scripts/port.mjs   (or --force)`)
    process.exit(1)
  }
  const stats = { written: 0, same: 0 }
  for (const [from, to] of LAYOUT) {
    const src = join(REPO, from)
    if (!existsSync(src)) continue
    copyTree(src, join(home, to), home, stats)
  }
  // every skill, each under its own kru- directory so the loader's name check
  // passes and nothing of the user's own is claimed
  for (const dir of readdirSync(join(REPO, "skill")).filter((d) => d.startsWith("kru-")))
    copyTree(join(REPO, "skill", dir), join(home, "skill", dir), home, stats)

  // the shared state store: briefs, plans, tickets, todos, the learnings inbox.
  // both forks read and write it, which is what makes a plan portable between them.
  // an older store under ~/.claude moves first, or the mkdir below would shadow it
  const moved = migrateStore()
  if (moved) log(moved)
  mkdirSync(join(STORE, "management"), { recursive: true })

  if (flag("default-agent")) setDefaultAgent(home)

  log(`installed kru ${version()} → ${home}`)
  log(`  ${stats.written} file(s) written, ${stats.same} unchanged`)
  log(`  agents: kru (primary) + kru/<seat> · commands: /kru/<name> · skills: kru-<name>`)
  const claude = claudeSide()
  if (claude) {
    const pin = upstreamPin()
    log(`\nclaude-code kru ${claude} is also installed — they share the store at ${STORE}`)
    if (pin && claude !== pin)
      log(`  this fork is ported from kru ${pin}; re-port before trusting a contract difference (see PORTING.md)`)
  }
  log(`\nnext: opencode, then tab to the \`kru\` agent (or: kru-oc install --default-agent)`)
}

function setDefaultAgent(home) {
  const path = join(home, "opencode.json")
  let cfg = {}
  if (existsSync(path)) {
    try {
      cfg = JSON.parse(readFileSync(path, "utf8"))
    } catch {
      console.error(`cannot parse ${path} — leaving default_agent alone`)
      return
    }
  }
  cfg.$schema ??= "https://opencode.ai/config.json"
  cfg.default_agent = "kru"
  writeFileSync(path, JSON.stringify(cfg, null, 2) + "\n")
  log(`  default_agent: kru → ${path}`)
}

function uninstall() {
  const home = configDir()
  const targets = [
    ...LAYOUT.map(([, to]) => to),
    // a config dir that never got skills (or lost them) has no skill/ at all
    ...(existsSync(join(home, "skill")) ? readdirSync(join(home, "skill"), { withFileTypes: true }) : [])
      .filter((e) => e.name.startsWith("kru-"))
      .map((e) => join("skill", e.name)),
  ]
  let n = 0
  for (const t of targets) {
    const p = join(home, t)
    if (!existsSync(p)) continue
    rmSync(p, { recursive: true, force: true })
    n++
  }
  log(`removed ${n} path(s) from ${home}`)
  log(`left alone: ${STORE} — the shared store (plans, tickets, todos, learnings inbox)`)
}

function doctor() {
  const home = configDir()
  const rows = []
  const ok = (label, detail) => rows.push(["ok", label, detail])
  const bad = (label, detail) => rows.push(["!!", label, detail])

  try {
    ok("opencode", execFileSync("opencode", ["--version"], { encoding: "utf8" }).trim())
  } catch {
    bad("opencode", "not on PATH")
  }

  const problem = portCheck()
  problem ? bad("tree normalized", "run: node scripts/port.mjs") : ok("tree normalized", "scripts/port.mjs --check clean")

  const installed = join(home, "kru", "VERSION")
  if (!existsSync(installed)) bad("installed", `nothing at ${home} — run: kru-oc install`)
  else {
    const v = readFileSync(installed, "utf8").trim()
    v === version() ? ok("installed", `${v} at ${home}`) : bad("installed", `${v} at ${home}, repo is ${version()} — run: kru-oc sync`)
  }

  // a placeholder that survived install is a prompt pointing at a path that
  // does not exist
  let stale = 0
  const scan = (dir) => {
    if (!existsSync(dir)) return
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      const p = join(dir, e.name)
      if (e.isDirectory()) scan(p)
      else if (TEXT.test(p) && PLACEHOLDER.test(readFileSync(p, "utf8"))) stale++
    }
  }
  for (const d of ["agent", "command", "skill", "kru", "plugin"]) scan(join(home, d))
  stale ? bad("paths materialized", `${stale} file(s) still carry a {KRU_*} placeholder — run: kru-oc sync`) : ok("paths materialized", "no placeholders left")

  const seats = existsSync(join(home, "agent", "kru")) ? readdirSync(join(home, "agent", "kru")).length : 0
  const skills = existsSync(join(home, "skill")) ? readdirSync(join(home, "skill")).filter((d) => d.startsWith("kru-")).length : 0
  const cmds = existsSync(join(home, "command", "kru")) ? readdirSync(join(home, "command", "kru")).length : 0
  ok("inventory", `${seats} seats · ${skills} skills · ${cmds} commands`)

  existsSync(STORE) ? ok("store", STORE) : bad("store", `${STORE} missing — run: kru-oc install`)

  const claude = claudeSide()
  const pin = upstreamPin()
  if (!claude) ok("claude-code kru", "not installed (opencode-only)")
  else if (pin && claude !== pin) bad("claude-code kru", `${claude} installed, this fork ports ${pin} — see PORTING.md`)
  else ok("claude-code kru", `${claude} — same upstream, shared store`)

  for (const [state, label, detail] of rows) log(`${state === "ok" ? " ✓" : " ✗"} ${label.padEnd(20)} ${detail}`)
  if (rows.some(([s]) => s === "!!")) process.exit(1)
}

function claudeInstructions() {
  const pin = upstreamPin()
  log(`to run the claude-code fork alongside this one, install upstream kru${pin ? ` ${pin}` : ""}:\n`)
  log(`  claude plugin marketplace add ap-justin/kru`)
  log(`  claude plugin install kru@kru\n`)
  log(`both forks then share ${STORE} — the same briefs, plans, tickets, todos and learnings inbox.`)
  log(`this fork is a port, so the two can differ: \`kru-oc doctor\` compares versions and PORTING.md says what opencode has no equivalent for.`)
}

switch (cmd) {
  case "install":
  case "sync":
    install()
    break
  case "uninstall":
    uninstall()
    break
  case "doctor":
    doctor()
    break
  case "claude":
    claudeInstructions()
    break
  default:
    log(`kru-oc ${version()} — kru for opencode

  kru-oc install [--dir <config>] [--default-agent] [--force]
      copy the team into an opencode config dir (default: ~/.config/opencode)
  kru-oc sync                 re-copy after editing the repo (same as install)
  kru-oc doctor               check the install, the port, and the claude-code side
  kru-oc uninstall            remove what install wrote; never touches the store
  kru-oc claude               how to add the claude-code fork beside this one

the repo is the source: edit, run \`node scripts/port.mjs\`, then \`kru-oc sync\`.`)
}
