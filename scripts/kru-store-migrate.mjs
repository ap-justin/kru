// one-time move of the store from where this fork's earlier versions kept it
// (~/.claude/kru) to where upstream and this fork keep it now (~/.kru).
// plugin/kru.ts runs it at load and bin/kru-oc.mjs before install creates the
// new root, so whichever runs first moves it and the other finds nothing to do.
//
// never overwrites: a new root holding any file wins and the old one stays put.
// a new root holding only empty dirs (an install that ran before this move
// existed) counts as absent. a symlinked new root is the user's own wiring and
// is left alone. KRU_HOME set means the user chose the root, so nothing moves.

import { existsSync, lstatSync, readdirSync, renameSync, rmdirSync, rmSync, cpSync } from "node:fs"
import { join } from "node:path"
import { homedir } from "node:os"

function holdsFiles(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (!e.isDirectory()) return true
    if (holdsFiles(join(dir, e.name))) return true
  }
  return false
}

// bottom-up and never recursive: two processes migrating at once must not
// let the slower one delete the store the faster one just moved into place.
// a dir that turns out non-empty throws ENOTEMPTY, which the caller reads as
// someone else's move landing first
function removeEmptyTree(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) if (e.isDirectory()) removeEmptyTree(join(dir, e.name))
  rmdirSync(dir)
}

const racing = (err) => err?.code === "ENOENT" || err?.code === "ENOTEMPTY" || err?.code === "EEXIST"

// returns one line saying what happened, or null when there was nothing to do
export function migrateStore({ home = homedir(), env = process.env } = {}) {
  if (env.KRU_HOME) return null
  const from = join(home, ".claude", "kru")
  const to = join(home, ".kru")
  try {
    if (!existsSync(from) || !lstatSync(from).isDirectory()) return null
    const st = lstatSync(to, { throwIfNoEntry: false })
    if (st) {
      const occupied = !st.isDirectory() || holdsFiles(to)
      if (occupied) return existsSync(from) ? `kru: store left at ${from} — ${to} already exists; merge them by hand` : null
      removeEmptyTree(to)
    }
    try {
      renameSync(from, to)
    } catch (err) {
      if (racing(err)) return null
      if (err?.code !== "EXDEV") throw err
      // a copy that dies halfway must not leave a half store at the new root,
      // where every later run would read it as the user's own
      const staging = `${to}.migrating-${process.pid}`
      cpSync(from, staging, { recursive: true, errorOnExist: true, force: false })
      try {
        renameSync(staging, to)
      } catch (e) {
        rmSync(staging, { recursive: true, force: true })
        if (racing(e)) return null
        throw e
      }
      rmSync(from, { recursive: true })
    }
    return `kru: moved the store from ${from} to ${to}`
  } catch (err) {
    if (racing(err)) return null
    return `kru: store move from ${from} to ${to} failed (${err?.message ?? err}); move it by hand`
  }
}
