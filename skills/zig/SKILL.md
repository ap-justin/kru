---
name: zig
description: "Zig 0.17 recipes. Use when writing or reviewing Zig in a repo with `build.zig`: the 0.17 std moves (`std.Io`, `init.gpa`), allocators and leak checks, ReleaseSafe vs Debug, `build.zig.zon` packages, threads and async. Pinned to 0.17; C interop and the language reference are out."
user-invocable: false
---

**Zig's dangerous failure is the one the compiler accepts.** A deprecated declaration still compiles, a leaking test still prints `OK`, an unflushed writer still exits 0, and a module the build graph never told about `-Doptimize` still compiles in Debug. Three consequences drive the file: the std library moved faster than its tutorials (code written from memory of 0.14 fails or rots) · a check only runs in the optimize mode that enables it · the build graph is code, and an option you did not wire through reaches nothing.

Reproduced on **Zig 0.17.1** (`x86_64-linux`, 2026-11-07), against the 0.17.0 release notes (`ziglang.org/download/0.17.0/release-notes.html`) and the installed std source. The `aarch64-macos` and `x86_64-windows` cross builds were built from Linux, not run. A repo's `build.zig.zon` `.minimum_zig_version` is the floor a feature must clear, even when it builds on your machine.

## Read the install, not a tutorial
- **`zig version`, then the std source.** `zig env` prints `lib_dir` (relative to the directory you ran it in); `<lib_dir>/std` is the authority for what 0.17 has. A signature, a `///` doc comment and a `test` block there answer faster than a search.
- **Deprecated compiles, removed errors.** `grep -rn "Deprecated in favor" <lib_dir>/std` lists what still builds (`std.fmt.allocPrint` → `gpa.print(fmt, args)`, `std.mem.indexOf` → `std.mem.find`, `std.builtin` → `std.lang`); new code uses the replacement because an alias is on a removal clock (`@import("builtin").cpu`, `.os` and `.abi` are slated for 0.18; use `.target.cpu` and so on). What older code reaches for and no longer exists: `std.io` (it is `std.Io`), `std.heap.GeneralPurposeAllocator`, `std.ArrayList(T).init(gpa)`, `std.os.argv`, `b.args` in a build script.
- **A swapped parameter is the quiet kind.** `std.mem.containsAtLeastScalar` now takes `(T, list, element, minimum)`; the pre-0.17 order still compiles for byte data (`'a'` becomes the count) and answers `false`.
- **`**` is gone, and the error does not say so.** `[1]u8{0} ** 4` reports ``binary operator '*' has whitespace on one side, but not the other``. The replacement is `var a: [4]u8 = @splat(0);`, or `.data = @splat(0)` in a struct initializer.
- **`@hasDecl` answers `true` only for `pub` declarations**, in every file. A duck-typed probe on a private `const` is `false`.

## `main`, output, input
- **`pub fn main(init: std.process.Init) !void`.** `init.gpa` (leak-checked in Debug and ReleaseSafe), `init.arena` (process lifetime, freed at exit; allocate and never free), `init.io`, `init.minimal.args.toSlice(arena)`, `init.environ_map`. There is no `std.os.argv`.
- **Output is a buffered writer you flush.** `var w: Io.File.Writer = .init(.stdout(), io, &buf); try w.interface.print(…); try w.interface.flush();`. Without the `flush`, a 64-byte buffer program wrote **0 bytes** to a pipe and exited 0. A reader that leaves early (`| head -1`) shows up as `error.WriteFailed` from the writer; returned out of `main` it is a stack trace on stderr and exit status 1. Diagnostics go through `std.debug.print` (stderr, unbuffered). Input mirrors it: `Io.File.Reader = .init(.stdin(), io, &buf)` and `interface.takeDelimiter('\n')`.
- **File and process calls take `io`.** `dir.createFile(io, …)`, `file.close(io)`, `std.process.run(gpa, io, …)`. A function that touches the OS takes an `Io` parameter the way one that allocates takes an `Allocator`; tests pass `std.testing.io`.

## Allocators and leaks
- **Allocators are parameters; ownership is a sentence.** A function that returns allocated memory says who frees it. `std.ArrayList(T)` is `.empty`, and every call that can grow it takes the allocator: `list.append(gpa, x)`, `list.deinit(gpa)`.
- **Arena for work freed in bulk, `init.gpa` for the rest.** `var arena: std.heap.ArenaAllocator = .init(gpa); defer arena.deinit();` per request or per command: two allocations under it pass the leak check, and the same arena without its `deinit` reports one leak for the whole arena rather than one per allocation.
- **A leak does not fail the program.** `init.gpa` prints `error(SafeAllocator): leaked …` at exit in Debug and ReleaseSafe and the process still exits **0**; ReleaseFast prints nothing. The `SafeAllocator` trace is empty in ReleaseSafe. A gate that reads only the exit status never sees a runtime leak, so leak coverage lives in tests.
- **`std.testing.allocator` fails the run, not the test.** A leaking test prints `…OK`; the summary then reports `1 tests leaked memory` (`1 leaks` under `zig build test`) and the exit status is 1. Read the whole output, not the per-test lines.

## Optimize modes
- **Debug and ReleaseSafe keep the checks; ReleaseFast and ReleaseSmall delete them.** `x += n` past a `u8`'s max: Debug and ReleaseSafe `panic: integer overflow` (exit 134); ReleaseFast and ReleaseSmall wrap to 4 and exit 0. An out-of-range `@intCast` panics in the first two and is undefined behavior in ReleaseFast (a segfault, exit 139, in the run), and a `switch` arm that is `unreachable` panics in the first two and carries on with an arbitrary value in ReleaseFast (it returned 2 in the run). `builtin.optimize.runtimeSafety()` tells code which side it is on. The tags are `.debug .safe .fast .small` (`std.lang.Optimize`).
- **Run the suite in the mode you ship.** The checks fire only in the modes that keep them: a Debug suite proves the code passes Debug's checks, and a ReleaseFast binary has none left to fire. CI runs `zig build test -Doptimize=ReleaseSafe` beside the Debug edit loop, and the build file says which release mode the repo ships.

## Disclosed
- Read `reference/build.md` when the task touches `build.zig` or `build.zig.zon`: the module that stays Debug under `-Doptimize`, the fingerprint, `zig fetch --save` and `zig build --fetch`, passthrough args, cross-compiling, `zig fmt --check`.
- Read `reference/io-concurrency.md` when the task spawns work, locks or waits: `Io.async` vs `Io.concurrent`, `Group`, the single-threaded `Io`, `Io.Mutex`, `std.Thread`.
