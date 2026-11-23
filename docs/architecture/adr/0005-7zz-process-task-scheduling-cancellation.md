# ADR-005 — 7zz Process Invocation, Task Scheduling and Cancellation

**Status:** Accepted · **Date:** 2026-11-23

> **中文摘要**：用独立于 SwiftUI 的 `TaskCenter` actor 统一调度所有压缩/解压子进程，默认并发 1；任务状态机为 queued→running→cancelling→succeeded/failed/cancelled；进度通过解析 `7zz -bsp1` 输出获得；取消时先 SIGINT 优雅终止、超时后强杀，并清理临时文件。

## Context

Archive operations are long-running, CPU/IO heavy, and must be cancellable, observable, and isolated from UI. 7zz is a subprocess (ADR-004). Running it naively (blocking, one-off `Process.run`) risks: main-thread stalls, pipe deadlocks, orphaned processes, zombie temp files, and unparsable progress. The user approved a centralized `TaskCenter` (Round 2, Q3).

## Decision Drivers

- UI responsiveness and clear task lifecycle.
- Reliable progress and cancellation.
- No SwiftUI dependency in the task engine (testable headless).
- Single source of truth for "what's running now".
- Bounded concurrency to protect memory/CPU on large archives.

## Considered Options

1. **Per-operation `Task {}` fire-and-forget**: simplest, but no queue, no unified progress/history, hard cancellation.
2. **Centralized `TaskCenter` actor with bounded queue (chosen)**.
3. External process manager/library: unnecessary dependency.

## Decision

- **`TaskCenter` is an `actor`**, independent of SwiftUI. It exposes `submit(_ operation) -> TaskHandle`, `cancel(handle)`, and an observable snapshot stream for UI.
- Default **concurrency = 1** (serialized archive operations), configurable later via a setting.
- **Task state machine:** `queued → running → cancelling → succeeded | failed | cancelled`.
- Each task carries: `id`, `kind` (create/extract/test/list), `title`, `progress` (`Double?`; `nil` = indeterminate), `startedAt/endedAt`, structured `ArchiveError?`, and a bounded **history** buffer.
- **Process execution** (in `SevenZipEngine`): launch via `Process` + `Pipe`s; **read stdout and stderr concurrently** (separate `readabilityHandler`/async sequences) to avoid pipe-buffer deadlock; set `standardInput` appropriately; capture exit status in `terminationHandler`.
- **Progress**: run with `-bsp1` and `-bs{o|e|p}1` so progress goes to a parsed stream; parse percentage tokens; if absent, report indeterminate. Exact line grammar is a **Proposed** detail validated by fixtures in `TKT-M2-03`.
- **Cancellation (graceful → forced):** send `SIGINT` (`process.interrupt()`); await exit up to a grace window (default 3 s); if still running, `terminate()` (SIGTERM) then `SIGKILL` after a final window; always reap the process and delete its staging/temp dirs. User-stop maps to exit code 255 → state `cancelled`.
- **Error mapping:** exit 0→success; 1→warning (surface but non-fatal); 2→fatal; 7→command-line/programming error; 8→out-of-memory; 255→cancelled; signal termination→cancelled/failed by context.
- **Password transport (verified from bundled 7-Zip 26.06 manual):** pass **`-p` with no value** and write the password to the child's **stdin** (7zz prompts interactively); **never** use `-p<password>` in argv (visible to `ps`). `-si` means *data from stdin*, not password — do not conflate. If an interactive stdin prompt cannot be established, **fail the operation** rather than silently falling back to an argv password. Document residual limitations (helper has the plaintext in memory/stdin).
- **No secrets in logs:** passwords passed via stdin or a protected argument as decided in ADR-008; command lines logged with `-p` redacted.

## Rationale

A centralized actor gives one place to enforce concurrency, cancellation, cleanup, and logging, and keeps UI totally decoupled. Concurrent pipe reads + bounded concurrency are the two classic failure modes this design fixes up front.

## Consequences

- UI observes `TaskCenter` snapshots via a thin `@MainActor` adapter; `TaskCenter` itself imports no SwiftUI.
- All engine calls must be cancellation-aware and idempotent on cleanup.
- Task history sizing is bounded to avoid unbounded memory.

## Risks / Trade-offs

- Killing subprocess trees (7zz is single-process, so acceptable) — if 7zz ever spawns children, switch to a process group.
- Progress grammar may change across 7zz versions → fixtures + version pin.
- 3 s grace may be too short on huge archives → make configurable.

## Related

- Specs: `SPEC-TM`, `SPEC-AE`
- ADRs: ADR-004, ADR-008
- Tickets: `TKT-M2-08`, `TKT-M2-09`
