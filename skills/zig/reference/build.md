# `build.zig` and `build.zig.zon`

The build graph is Zig code that declares steps; `zig build` runs them. Reproduced on **Zig 0.17.1** (`x86_64-linux`, 2026-11-07) from a `zig init` project; the field list of `build.zig.zon` is the commented template `zig init` writes, which is the schema's own documentation.

## Wire `optimize` into every module that has tests
`zig init` writes the library module with `b.addModule("name", .{ .root_source_file, .target })` and the executable's root module with `.target` **and** `.optimize`. A module with no `.optimize` compiles in Debug whatever you pass: under `zig build test -Doptimize=ReleaseSafe`, the library's `test` blocks printed `optimize=debug` and the executable's `optimize=safe`. Add `.optimize = optimize` to `addModule` and both print `safe`. A suite meant to run in the shipped mode checks `@import("builtin").optimize` once in a test to prove it did.

## Options and release modes
- `b.standardOptimizeOption(.{})` is `-Doptimize=debug|safe|fast|small` and defaults to Debug. Setting `.preferred_optimize_mode` switches the repo to `--release[=mode]`: `zig build --release=safe` gives `safe`, and a bare `--release` exits 1 asking for a mode when the build file names none.
- `b.standardTargetOptions(.{})` is what makes `-Dtarget=aarch64-macos` and `-Dcpu=…` work: `zig build -Dtarget=aarch64-macos -Doptimize=ReleaseSafe --prefix out` produced a Mach-O arm64 binary, `x86_64-windows` a `.exe` and `.pdb`, `aarch64-linux-musl` an ELF, all from a Linux host with no cross toolchain installed. Code that must differ per target reads `builtin.target.os.tag`, not the host.
- Passthrough arguments are `run_cmd.addPassthruArgs()`. `b.args` no longer exists (`no field named 'args' in struct 'Build'`), and build scripts cannot observe whether arguments were given.

## Packages
- **Add a dependency with `zig fetch --save[=name] <url-or-path>`**, never by typing a hash: it writes `.url` and `.hash` into the `.dependencies` table. The hash is the source of truth and the URL is one mirror. `.path = "dir"` is an in-repo dependency with no hash, and `.lazy = true` fetches it only when the build asks for it.
- **Wire it in `build.zig`**: `const dep = b.dependency("name", .{ .target = target, .optimize = optimize });`, then `.imports = &.{.{ .name = "name", .module = dep.module("name") }}` on the module that imports it; `@import("name")` works in that module's files. For a `.lazy` one, `b.dependencyLazy` returns `error.LazyDependencyNeeded` and the build system fetches and re-runs.
- **`zig build --fetch`** fetches the whole dependency tree and exits (`--fetch=all` includes lazy ones); a `zig build` after it needs no network. CI runs it as its own step so a network failure reads as one.
- **`zig-pkg/`** appears in the project root once dependencies are fetched, beside `.zig-cache/` and `zig-out/`; `rm -rf zig-pkg && zig build --fetch` restores it. `zig init` writes no `.gitignore`.
- **The fingerprint belongs to the name.** A hand-typed or copied `.fingerprint` fails with `invalid fingerprint: 0x…; if this is a new or forked package, use this value: 0x…`. A new package takes the value the error prints; an existing package never changes it. `.minimum_zig_version` is the floor `zig` checks against.

## Format and test steps
- `zig fmt --check <paths>` exits 1 and names each non-conforming file (`error: src/a.zig: non-conforming formatting`). As a build step, `b.addFmt(.{ .paths = b.pathList(&.{ "src", "build.zig", "build.zig.zon" }), .check = true })`: `.paths` takes `LazyPath`s, so a bare string slice is a type error.
- `b.addTest(.{ .root_module = … })` plus `b.addRunArtifact(t)` per module, all under one `test` step; tests of separate modules run in parallel. A `test` step that no run step is attached to succeeds with nothing run (`exit 0` over a test that calls `expect(false)`), so check the collected-test count in the summary. `zig build test --summary all` prints each compile and run step with its optimize mode.
