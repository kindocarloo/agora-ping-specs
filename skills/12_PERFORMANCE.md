# 12 — Performance

**Purpose:** Hard performance limits, hot paths, deliberate inefficiencies to leave alone, expensive operations, and profiling commands.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. **This document barely applies yet because no runtime code, database, or client apps exist.** Populate with measured baselines as soon as services and clients run. The code wins (see 16 #7).

---

## Current Status

- **Hard limits / SLAs:** None defined in `agora-ping-specs/business-logic-v1.0.md` yet.
- **Hot paths:** None (0 runtime endpoints or UI screens).
- **Deliberate inefficiencies to leave alone:** None yet.
- **Profiling commands:** None yet.

---

## Anticipated Performance & Cost Constraints (Inferred from Specs)

When implementing `agora-ping-api`, `agora-ping-web`, and `agora-ping-android`, watch these areas first and replace these notes with measurements:

1. **Aggregation-threshold analytics (`B. Administrator` reports):** Enforcing minimum group sizes and location bucketing across large event tables (`business-logic-v1.0.md` lines 22, 39) can become expensive without pre-aggregation or proper indexing (see 07).
2. **Retention purge jobs:** Deleting expired records under retention limits (`business-logic-v1.0.md` line 39) must run in bounded batches so cleanup does not lock hot tables.
3. **Android battery/network budget:** If location or periodic sync (`sync` scope in `git-guidelines.md` line 71) is added to `agora-ping-android`, measure wakeups and payload sizes on real devices before optimizing prematurely.
