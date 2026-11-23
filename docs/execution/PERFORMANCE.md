# Performance Baselines (TKT-M6-01)

Timing is **advisory** (tracked, not a hard gate) because CI runner variance is
significant. Correctness is always asserted; the harness records `measure` values.

| Scenario | Entries | Metric | Baseline (arm64 CI, advisory) |
|----------|---------|--------|-------------------------------|
| Sort by size | 100,000 | wall time | recorded in CI logs |
| Filter + sort (archive-style listing) | 100,000 | wall time | recorded in CI logs |
| Directory listing parse (7zz `-slt`) | fixture | wall time | recorded in CI logs |

Regressions are reviewed from CI logs; a >2× slowdown warrants investigation but
does not fail the build (per SPEC-REL gating policy).
