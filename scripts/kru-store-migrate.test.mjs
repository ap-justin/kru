// the one-time store move: each case builds a home in a temp dir and checks
// what migrateStore leaves behind. run: node --test scripts/kru-store-migrate.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync, symlinkSync, lstatSync } from "node:fs"
import { join } from "node:path"
import { tmpdir } from "node:os"
import { migrateStore } from "./kru-store-migrate.mjs"

function home(t) {
  const dir = mkdtempSync(join(tmpdir(), "kru-migrate-"))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  return dir
}

function put(path, text) {
  mkdirSync(join(path, ".."), { recursive: true })
  writeFileSync(path, text)
}

test("moves the old store when the new one is absent", (t) => {
  const h = home(t)
  put(join(h, ".claude/kru/inbox.md"), "a preference\n")
  put(join(h, ".claude/kru/management/acme/brief.md"), "the brief\n")
  const msg = migrateStore({ home: h, env: {} })
  assert.match(msg, /moved the store/)
  assert.equal(existsSync(join(h, ".claude/kru")), false)
  assert.equal(readFileSync(join(h, ".kru/inbox.md"), "utf8"), "a preference\n")
  assert.equal(readFileSync(join(h, ".kru/management/acme/brief.md"), "utf8"), "the brief\n")
})

test("never overwrites a new store that holds files", (t) => {
  const h = home(t)
  put(join(h, ".claude/kru/inbox.md"), "old\n")
  put(join(h, ".kru/inbox.md"), "new\n")
  const msg = migrateStore({ home: h, env: {} })
  assert.match(msg, /left at/)
  assert.equal(readFileSync(join(h, ".claude/kru/inbox.md"), "utf8"), "old\n")
  assert.equal(readFileSync(join(h, ".kru/inbox.md"), "utf8"), "new\n")
})

test("a new root of empty dirs counts as absent", (t) => {
  const h = home(t)
  put(join(h, ".claude/kru/TODOS.md"), "todo\n")
  mkdirSync(join(h, ".kru/management"), { recursive: true })
  assert.match(migrateStore({ home: h, env: {} }), /moved the store/)
  assert.equal(readFileSync(join(h, ".kru/TODOS.md"), "utf8"), "todo\n")
  assert.equal(existsSync(join(h, ".claude/kru")), false)
})

test("does nothing without an old store", (t) => {
  const h = home(t)
  assert.equal(migrateStore({ home: h, env: {} }), null)
  assert.equal(existsSync(join(h, ".kru")), false)
})

test("does nothing when KRU_HOME picks the root", (t) => {
  const h = home(t)
  put(join(h, ".claude/kru/inbox.md"), "old\n")
  assert.equal(migrateStore({ home: h, env: { KRU_HOME: join(h, "elsewhere") } }), null)
  assert.equal(existsSync(join(h, ".claude/kru/inbox.md")), true)
  assert.equal(existsSync(join(h, ".kru")), false)
})

test("a second run is a no-op", (t) => {
  const h = home(t)
  put(join(h, ".claude/kru/inbox.md"), "x\n")
  migrateStore({ home: h, env: {} })
  assert.equal(migrateStore({ home: h, env: {} }), null)
  assert.equal(readFileSync(join(h, ".kru/inbox.md"), "utf8"), "x\n")
})

test("leaves a symlinked new root alone", (t) => {
  const h = home(t)
  put(join(h, ".claude/kru/inbox.md"), "old\n")
  mkdirSync(join(h, "elsewhere"))
  symlinkSync(join(h, "elsewhere"), join(h, ".kru"))
  assert.match(migrateStore({ home: h, env: {} }), /left at/)
  assert.equal(lstatSync(join(h, ".kru")).isSymbolicLink(), true)
  assert.equal(readFileSync(join(h, ".claude/kru/inbox.md"), "utf8"), "old\n")
})

test("leaves a file at the new root alone", (t) => {
  const h = home(t)
  put(join(h, ".claude/kru/inbox.md"), "old\n")
  writeFileSync(join(h, ".kru"), "not a dir\n")
  assert.match(migrateStore({ home: h, env: {} }), /left at/)
  assert.equal(readFileSync(join(h, ".claude/kru/inbox.md"), "utf8"), "old\n")
})

// two sessions starting at once, over the empty root an earlier install left:
// whichever wins, the store ends up whole at the new root
test("concurrent moves never lose the store", async (t) => {
  const { spawn } = await import("node:child_process")
  const mod = new URL("./kru-store-migrate.mjs", import.meta.url).href
  const script = `import(${JSON.stringify(mod)}).then((m) => m.migrateStore({ home: process.argv[1], env: {} }))`
  for (let i = 0; i < 150; i++) {
    const h = home(t)
    put(join(h, ".claude/kru/management/acme/brief.md"), "brief\n")
    mkdirSync(join(h, ".kru/management/acme"), { recursive: true })
    const run = () => new Promise((resolve) => spawn(process.execPath, ["-e", script, h]).on("exit", resolve))
    await Promise.all([run(), run(), run()])
    assert.equal(readFileSync(join(h, ".kru/management/acme/brief.md"), "utf8"), "brief\n", `trial ${i}`)
    assert.equal(existsSync(join(h, ".claude/kru")), false, `trial ${i}`)
  }
})
