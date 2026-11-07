# `std.Io`: async, concurrency and threads

0.17 moves blocking work behind an `Io` value the program passes around. Reproduced on **Zig 0.17.1** (`x86_64-linux`, 2026-11-07); the contracts quoted are the doc comments in `<lib_dir>/std/Io.zig`.

## Where `Io` comes from
`init.io` in `main(init: std.process.Init)` is the default implementation for the target; `std.testing.io` inside a `test`. `std.Io.Threaded` is the thread-pool implementation, and `var th: Io.Threaded = .init_single_threaded; const io = th.io();` builds one with no concurrency.

## `async` is a request; `concurrent` is a guarantee
- **`io.async(f, .{args})`** returns a `Future`; `f` *may* run to completion before `async` returns. On the single-threaded `Io` it did: a task that appended `t` and the caller that appended `a` after calling `async` produced `ta`. So a waiter and the setter it waits for, both started with `async` and the waiter first, finish on `init.io` (threaded) and **hang** on the single-threaded `Io` (the run was killed at 5 s): the waiter ran inline and blocked before the setter started.
- **`io.concurrent(f, .{args})`** returns `error.ConcurrencyUnavailable` where the `Io` cannot give the task its own unit of concurrency (the single-threaded `Io` returned it in the run). Work that must overlap uses `concurrent` and handles that error; work that merely may overlap uses `async`.
- **`future.await(io)`** returns the result; `future.cancel(io)` is `await` plus a cancellation request that the task's next cancellation point (an `Io` call that can return `error.Canceled`) receives.

## Fan-out with `Group`
`var g: Io.Group = .init; defer g.cancel(io);` then `g.async(io, f, .{args})` per task and `try g.await(io)`. The function's return type coerces to `Cancelable!void`, a task is not guaranteed to have started until `await` or `cancel`, and a `Group` that is neither awaited nor cancelled leaks its resources. Three tasks writing disjoint slots of a stack array produced `{ 0, 10, 20 }` after `await`.

## Locks and threads
- `Io.Mutex`: `var m: Io.Mutex = .init; m.lockUncancelable(io); defer m.unlock(io);`. `lock(io)` is a cancellation point and returns `error.Canceled`; `lockUncancelable` is the same lock without one. `Io.Event` (`set(io)`, `wait(io)`/`waitUncancelable(io)`) is the wait-until-set flag.
- `std.Thread.spawn(.{}, f, .{args})` plus `t.join()` still builds in 0.17. A program that already takes an `Io` uses it, so a single-threaded or test `Io` stays correct.
- `init.gpa` and `init.arena` are thread-safe, and `init.environ_map` is not.
