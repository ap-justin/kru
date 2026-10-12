/// <reference types="@opencode-ai/plugin" />
// the mechanized half of the lead contract, as an opencode plugin. most gates
// are upstream's shell scripts run through an adapter — the logic stays where
// upstream edits it, and this file only translates opencode's hook shape into
// the claude-shaped json those scripts read on stdin.
//
// two gates have no script left to call: upstream's lead gate and brainstorm
// guard read the session transcript, which opencode does not expose to a hook,
// so the session state they inferred is tracked here instead. the read-only
// bash test both share stays upstream's (hooks/readonly-bash.sh). those two are
// the pieces to hand-mirror when upstream changes require-lead.sh or
// brainstorm-guard.sh (PORTING.md).

import type { Plugin } from "@opencode-ai/plugin"
import { execFile, execFileSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"
import { homedir } from "node:os"

// <config>/plugin/kru.ts → <config>, which is what the ported prompts spell as
// {KRU_HOME} and what the shell hooks take as their root
const KRU_HOME = dirname(dirname(fileURLToPath(import.meta.url)))
const HOOKS = join(KRU_HOME, "kru", "hooks")
// the store's cross-project root, resolved the way scripts/kru-store.sh does.
// the env var is upstream's name for the store, not this fork's {KRU_HOME}
// placeholder. shared with the claude-code fork on purpose: a plan, ticket
// queue or learnings inbox started in one harness continues in the other
const STORE = process.env.KRU_HOME || join(homedir(), ".kru")
const LEDGER_DIR = join(STORE, "audit")

const LEAD_MARKER = "You are the engineering lead."
const GATE_MESSAGE =
  "kru: refused — load the lead contract first. Switch to the `kru` agent (tab), or call the skill tool with name `kru-lead`, then take this action again with the same arguments. Every tool stays available, and read-only commands run ungated."
const BRAINSTORM_MESSAGE =
  "kru: /kru/brainstorm writes nothing until the user says go — reads stay open. Keep grilling; the brief is written on their go."
const WRITE_TOOLS = new Set(["edit", "write", "patch", "multiedit", "apply_patch"])
// what upstream counts as the user's go: a turn that opens with it
const GO = /^\s*(go|brief it)([^a-z0-9]|$)/i

// every verb has to read, or the gate stands — and anything the test cannot
// run counts as a write, because a miss is a silent ungated build
function readOnlyBash(command: string): boolean {
  if (!command) return false
  try {
    execFileSync("bash", ["-c", '. "$1" && kru_readonly_bash "$2"', "_", join(HOOKS, "readonly-bash.sh"), command], {
      stdio: "ignore",
      timeout: 5_000,
    })
    return true
  } catch {
    return false
  }
}

type HookResult = { blocked?: string; stdout?: string }

// the scripts expect claude's hook payload on stdin and answer the way claude's
// protocol answers: exit 2 with a reason on stderr is a refusal, stdout is json
// (or context) to hand back.
function runHook(script: string, payload: unknown, cwd: string, args: string[] = [KRU_HOME]): HookResult {
  const path = join(HOOKS, script)
  if (!existsSync(path)) return {}
  try {
    const stdout = execFileSync("bash", [path, ...args], {
      input: JSON.stringify(payload),
      encoding: "utf8",
      timeout: 10_000,
      cwd,
      stdio: ["pipe", "pipe", "pipe"],
    })
    return { stdout: stdout.trim() || undefined }
  } catch (err: any) {
    if (err?.status === 2) return { blocked: String(err.stderr ?? "").trim() || "kru: refused" }
    return {} // fail open: a gate that misfires costs more than one that lets through
  }
}

// store-sync clones and pushes, so it never holds a tool call up
function runHookAsync(script: string, payload: unknown, cwd: string, args: string[]): Promise<string> {
  const path = join(HOOKS, script)
  if (!existsSync(path)) return Promise.resolve("")
  return new Promise((resolve) => {
    const child = execFile("bash", [path, ...args], { cwd, timeout: 60_000, encoding: "utf8" }, (_err, stdout) =>
      resolve(String(stdout ?? "").trim()),
    )
    child.stdin?.end(JSON.stringify(payload))
  })
}

const json = (s?: string): any => {
  if (!s) return undefined
  try {
    return JSON.parse(s)
  } catch {
    return undefined
  }
}

const ledgerPath = (sessionID: string) => join(LEDGER_DIR, `${sessionID}.jsonl`)

function ledgerCount(sessionID: string): number {
  const path = ledgerPath(sessionID)
  if (!existsSync(path)) return 0
  try {
    return readFileSync(path, "utf8").split("\n").filter(Boolean).length
  } catch {
    return 0
  }
}

const textOf = (parts: any[]): string =>
  parts
    .filter((p) => p?.type === "text" && !p.synthetic)
    .map((p) => String(p.text ?? ""))
    .join("\n")

export const kru: Plugin = async ({ client, directory }) => {
  // session state, not durable: a session either carries the contract or it does
  // not, and the answer dies with the session
  const lead = new Set<string>()
  const gated = new Set<string>()
  const brainstorming = new Set<string>()
  const synced = new Set<string>()
  // a seat whose return already went back once without the pass line
  const unstated = new Set<string>()
  // a dispatched seat runs in a child session; every gate here is the lead's,
  // and claude's hooks see a subagent under its parent's session id
  const children = new Map<string, boolean>()

  const markLead = (sessionID?: string) => sessionID && lead.add(sessionID)

  async function isChild(sessionID: string): Promise<boolean> {
    if (children.has(sessionID)) return children.get(sessionID)!
    let child = true // fail open: an unknown session is never gated
    try {
      const res: any = await client.session.get({ path: { id: sessionID } })
      child = Boolean(res?.data?.parentID)
    } catch {}
    children.set(sessionID, child)
    return child
  }

  const log = (message: string) =>
    client.app.log({ body: { service: "kru", level: "info", message } }).catch(() => {})

  // a repo that never ran /kru/setup gets the reminder once per session's context
  let setupNudge: string | undefined | null = null
  const nudge = () => {
    if (setupNudge === null)
      setupNudge = json(runHook("setup-nudge.sh", { cwd: directory }, directory).stdout)?.hookSpecificOutput?.additionalContext
    return setupNudge
  }

  const storeSync = async (mode: "start" | "stop", sessionID: string) => {
    const out = await runHookAsync("store-sync.sh", { session_id: sessionID, cwd: directory }, directory, [mode, KRU_HOME])
    for (const line of out.split("\n")) {
      const msg = json(line)?.systemMessage
      if (msg) await log(msg)
    }
  }

  return {
    // the kru primary agent carries the contract as its system prompt; anything
    // else has to load the skill. this is also where the audit nudge lands,
    // since opencode has no blocking stop hook to refuse the turn's end.
    "experimental.chat.system.transform": async (input, output) => {
      const joined = output.system.join("\n")
      if (joined.includes(LEAD_MARKER)) markLead(input.sessionID)
      if (!input.sessionID || (await isChild(input.sessionID))) return
      if (!synced.has(input.sessionID)) {
        synced.add(input.sessionID)
        await storeSync("start", input.sessionID)
      }
      const setup = nudge()
      if (setup) output.system.push(setup)
      const n = ledgerCount(input.sessionID)
      if (!n || process.env.KRU_NO_AUDIT) return
      output.system.push(
        [
          `kru dispatch audit pending: ${n} team-seat dispatch(es) this session, logged at ${ledgerPath(input.sessionID)}.`,
          `Before this turn ends, dispatch the \`kru/dispatch-auditor\` subagent once with the prompt:`,
          `"Audit the dispatch ledger at ${ledgerPath(input.sessionID)}. Lead contract (for exact wording only): ${join(KRU_HOME, "agent", "kru.md")}, Step 3."`,
          `It files its own learnings and deletes the ledger. Relay its one-line return only when it names something the user must act on.`,
        ].join(" "),
      )
    },

    // /kru/brainstorm locks writes until the user's go; /kru/brief is a go
    "command.execute.before": async (input) => {
      if (input.command === "kru/brainstorm") brainstorming.add(input.sessionID)
      if (input.command === "kru/brief") brainstorming.delete(input.sessionID)
    },

    "chat.message": async (input, output) => {
      if (brainstorming.has(input.sessionID) && GO.test(textOf(output.parts ?? [])))
        brainstorming.delete(input.sessionID)
    },

    "tool.execute.before": async (input, output) => {
      const args = (output.args ?? {}) as Record<string, any>

      // the load itself is a skill call — gating it would close the only door out
      if (input.tool === "skill") {
        if (typeof args.name === "string" && args.name === "kru-lead") markLead(input.sessionID)
        return
      }

      if (input.tool === "task") {
        const seat = String(args.subagent_type ?? "")
        if (seat.startsWith("kru/")) {
          const { blocked, stdout } = runHook(
            "check-handoff.sh",
            {
              tool_name: "Task",
              tool_input: { subagent_type: seat, prompt: args.prompt ?? "", description: args.description ?? "" },
              session_id: input.sessionID,
              cwd: directory,
            },
            directory,
          )
          if (blocked) throw new Error(blocked)
          // the gate supplies what a brief lacks (the learnings channel, a report
          // path) by rewriting the prompt rather than refusing over it
          const prompt = json(stdout)?.hookSpecificOutput?.updatedInput?.prompt
          if (typeof prompt === "string") output.args.prompt = prompt
        }
      }

      const writes = WRITE_TOOLS.has(input.tool) || input.tool === "bash"
      const reads = () => input.tool === "bash" && readOnlyBash(String(args.command ?? ""))

      if (brainstorming.has(input.sessionID) && writes && !reads()) throw new Error(BRAINSTORM_MESSAGE)

      // --- the lead gate -----------------------------------------------------
      if (process.env.KRU_NO_LEAD_GATE) return
      if (existsSync(join(STORE, "lead-gate", "off"))) return
      if (!input.sessionID || lead.has(input.sessionID)) return
      if (["todowrite", "todoread", "question", "read", "grep", "glob", "list", "webfetch", "websearch"].includes(input.tool)) return
      if (reads()) return
      if (gated.has(input.sessionID)) return // fires once per session
      if (await isChild(input.sessionID)) return

      gated.add(input.sessionID)
      throw new Error(GATE_MESSAGE)
    },

    "tool.execute.after": async (input, output) => {
      if (input.tool !== "task") return
      const args = (input.args ?? {}) as Record<string, any>
      const seat = String(args.subagent_type ?? "")
      if (!seat.startsWith("kru/")) return
      const base = { session_id: input.sessionID, cwd: directory }
      runHook(
        "log-dispatch.sh",
        {
          ...base,
          tool_name: "Task",
          tool_input: { subagent_type: seat, prompt: args.prompt ?? "", description: args.description ?? "" },
        },
        directory,
      )
      // upstream checks the return at subagentstop and keeps the seat running
      // once to state its pass. opencode's task is synchronous and cannot be
      // kept running, so the ask goes to the lead with the return, and a second
      // miss from the same seat is what reaches the ledger.
      const ret = { ...base, agent_type: seat, last_assistant_message: output.output ?? "" }
      const key = `${input.sessionID}:${seat}`
      const missing = json(runHook("log-return.sh", { ...ret, stop_hook_active: false }, directory).stdout)?.decision === "block"
      if (!missing) {
        unstated.delete(key)
        return
      }
      if (unstated.has(key)) {
        runHook("log-return.sh", { ...ret, stop_hook_active: true }, directory)
        unstated.delete(key)
        return
      }
      unstated.add(key)
      output.output = `${output.output ?? ""}\n\nkru: ${seat} carries \`## The return pass\` and this return states no \`Return pass:\` line — the slice arrives unread as a whole. Ask that seat for the pass (a \`task\` call with the same \`task_id\`) before routing on this return.`
    },

    event: async ({ event }) => {
      if (event.type !== "session.idle") return
      const sessionID = (event as any).properties?.sessionID
      if (!sessionID || (await isChild(sessionID))) return
      // every turn end is a save point: a cloud vm is reclaimed without an end event
      await storeSync("stop", sessionID)
      const n = ledgerCount(sessionID)
      if (n && !process.env.KRU_NO_AUDIT) await log(`dispatch audit pending: ${n} dispatch(es)`)
    },
  }
}
