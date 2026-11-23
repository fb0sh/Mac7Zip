# SPEC-TM — Background Task Management

**Status:** Accepted · **Milestone:** M2 (MVP), M3 · **Last updated:** 2026-11-23

> **中文摘要**：后台任务规格——`TaskCenter` actor 统一管理压缩/解压/测试任务，默认并发 1，状态机与进度/取消/历史；通过轻量适配层向 SwiftUI 暴露状态；任务引擎不含 SwiftUI。

## 1. Overview

Long-running archive operations must be queued, observable, cancellable, and recoverable. `TaskCenter` is the single owner of running work and its history. It is UI-framework-free; a thin adapter publishes snapshots to SwiftUI.

## 2. Goals

- One authoritative queue and lifecycle for archive tasks.
- Reliable progress (or explicit indeterminate) and cancellation.
- Bounded concurrency and bounded history (predictable memory).
- Clean teardown of processes and temp files.

## 3. Non-goals

- General-purpose job scheduler for non-archive work (extensible later).
- Persisting task history across launches (in-memory MVP).
- Background execution when app is quit (later).

## 4. User Scenarios

- **S1**: Start extract → task appears in Tasks popover as running with %.
- **S2**: Start a second task → queued until first finishes (concurrency 1).
- **S3**: Cancel running task → status cancelling → cancelled; process gone; temps removed.
- **S4**: Task fails → failed with message; history retains it.
- **S5**: Indeterminate progress (no % from engine) → spinner not fake %.

## 5. Functional Requirements

| ID | Requirement |
|---|---|
| FR-TM-01 | `TaskCenter` is an `actor`; `submit(Operation) -> TaskHandle`. |
| FR-TM-02 | Lifecycle: `queued → running → cancelling → succeeded|failed|cancelled`. |
| FR-TM-03 | Default concurrency 1; configurable. |
| FR-TM-04 | Each task exposes id, kind, title, progress `Double?`, state, timestamps, error. |
| FR-TM-05 | `cancel(handle)` performs graceful→forced termination per ADR-005. |
| FR-TM-06 | Bounded history (e.g., last 50 completed) with eviction. |
| FR-TM-07 | Publish snapshots to UI via an `@MainActor` adapter (e.g., `TaskCenterAdapter: ObservableObject`). |
| FR-TM-08 | On cancel/failure, delete staging/temp directories owned by the task. |
| FR-TM-09 | Task engine imports no SwiftUI/AppKit. |

## 6. UX / Interaction Design

- **Status bar**: active task count + linear progress for the current task; clicking opens Tasks popover/drawer.
- **Tasks popover**: list of running/queued/completed with progress, Cancel button, error text; empty state "No tasks".
- **Notifications** (M5): optional user notification on completion.

## 7. Technical Design

- `actor TaskCenter` holds `queue`, `running`, `history`, `configuration`.
- `TaskHandle` is a `Sendable` value (id + cancellation channel).
- Progress callback from engine (`AsyncStream<TaskEvent>`) updates an internal `TaskRecord`; published snapshots are value types.
- Cancellation sets state `cancelling`, signals engine; engine returns; center transitions to `cancelled`.
- Cleanup hooks run in `defer` inside the operation runner.

## 8. Data Models / Interfaces

```swift
enum TaskKind: String, Sendable { case list, extract, create, test }
enum TaskState: String, Sendable { case queued, running, cancelling, succeeded, failed, cancelled }

struct TaskRecord: Identifiable, Sendable {
    let id: UUID; let kind: TaskKind; var title: String
    var state: TaskState; var progress: Double?      // nil = indeterminate
    var startedAt: Date?; var endedAt: Date?
    var error: ArchiveError?
}

protocol TaskOperation: Sendable {
    var kind: TaskKind { get }; var title: String { get }
    func run(progress: @Sendable (Double?) -> Void) async throws
}
```

## 9. Error Handling

- Operation errors are caught and stored as `ArchiveError`; state `failed`.
- Cancellation is not an error: state `cancelled`, no error dialog.
- Unexpected engine crash → `failed` with diagnostic.

## 10. Performance Requirements

- Snapshot publication coalesced to ≤ 10 Hz to avoid UI churn.
- History bounded to ≤ 50 records (or ≤ 5 MB).
- Overhead of TaskCenter itself negligible (< 1% CPU while waiting).

## 11. Security Requirements

- Temp/staging dirs created under app-managed temp; unique per task; removed on completion.
- Task titles/paths sanitized in UI; passwords never stored in `TaskRecord`.

## 12. Acceptance Criteria

- **AC-TM-1** — Given two submitted tasks and concurrency 1, When the first runs, Then the second is `queued` and starts only after the first completes.
- **AC-TM-2** — Given a running task, When cancelled, Then state becomes `cancelled` within the grace window and no temp dirs remain.
- **AC-TM-3** — Given indeterminate engine progress, Then UI shows a spinner and `progress == nil`.
- **AC-TM-4** — Given > 50 completed tasks, Then history retains only the latest 50.

## 13. Test Strategy

- Unit: state machine transitions; queue ordering; history eviction; cancellation signaling.
- Integration: run real 7zz task, cancel, assert cleanup.
- No UI framework needed for core tests (host-free).

## 14. Dependencies

- ADR-005; SPEC-AE engine events; ADR-008 cleanup.

## 15. Related ADRs / Tickets

- ADRs: ADR-005, ADR-008
- Tickets: `TKT-M2-08`, `TKT-M2-09`, `TKT-M3-05`
