# 08 — API

**Purpose:** HTTP/API contract conventions, response envelope, route inventory with auth/RBAC requirements, validators, and versioning rules for `agora-ping-api`.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. **This document barely applies yet because `agora-ping-api` contains only `AGENTS.md` and zero routes or server code.** Known requirements below are verified from `agora-ping-specs/business-logic-v1.0.md` and `agora-ping-specs/git-guidelines.md`. The code wins (see 16 #7).

---

## Current Status

- **Server framework / runtime:** TBD.
- **Response envelope:** TBD (define once `agora-ping-api` is scaffolded and lockstep across `agora-ping-web` and `agora-ping-android`).
- **Route inventory:** None (0 endpoints exist).
- **Validators:** None yet.

---

## Known Contract Constraints (Verified from Specs)

1. **Authentication provider:** Google Sign-In (`business-logic-v1.0.md` line 29). The API must verify Google-issued identity tokens server-side rather than trusting client-supplied user IDs or roles (see 09).
2. **RBAC Tiers (`business-logic-v1.0.md` lines 19–25):**
   - `A. System Administrator` — System/server config overrides and backups.
   - `B. Administrator` — General system settings and periodic analytics/reports.
   - `C. Moderator` — *(scope TBD in `business-logic-v1.0.md`)*.
   - `D. Contributor` — *(scope TBD in `business-logic-v1.0.md`)*.
   - `E. Guest` — Unauthenticated read-only access to limited content.
   - *Miss →* Relying only on client-side UI hiding lets any HTTP caller invoke admin/moderator endpoints directly.
3. **Breaking-change signaling (`git-guidelines.md` lines 222–231):**
   - Any breaking API change must use `<scope>:!` in the commit header and a `BREAKING CHANGE:` trailer naming the affected endpoint and client migration path.
   - *Miss →* `agora-ping-web` and `agora-ping-android` break silently against the deployed API because all three repos ship independently (see 01, 10).
4. **Privacy-enforced analytics responses (`business-logic-v1.0.md` line 39):**
   - Analytics/report endpoints for `B. Administrator` must enforce aggregation thresholds server-side and never return per-user trails or raw location histories.

---

## Checklist When Adding the First Endpoints

Once `agora-ping-api` is scaffolded, replace this stub with:
1. Exact JSON response & error envelope (status codes, machine-readable error codes, validation error format).
2. Route inventory table (`Method`, `Path`, `Allowed Roles A–E`, `Rate Limit`, `Privacy Notes`).
3. Step-by-step "How to add an endpoint" recipe linked to Lockstep Set #3 (`04 #3`).
4. Request validation layer and API versioning strategy (`/v1/...` or header-based).
