# 11 — Testing

**Purpose:** Honest view of current test coverage, how each maturity stage gains confidence, what must be tested, and the failure dimensions most likely to break.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. **Current automated test coverage is 0% across all four repositories because no application code or test harnesses exist yet.** Stage gates below are verified from `agora-ping-specs/git-guidelines.md`. The code wins (see 16 #7).

---

## Honest Coverage

| Repo | Unit Tests | System / Integration Tests | CI Pipeline | Confidence |
|---|---|---|---|---|
| `agora-ping-api` | 0 | 0 | None | Verified |
| `agora-ping-web` | 0 | 0 | None | Verified |
| `agora-ping-android` | 0 | 0 | None | Verified |
| `agora-ping-specs` | N/A (manual doc review & golden-code candidates) | N/A | None | Verified |

---

## How the Team Gains Confidence (Verified Stage Gates)

From `agora-ping-specs/git-guidelines.md` lines 327–340 and 479–482, testing is separated by branch and owner:

| Stage | Branch | Responsible Group | Gate Purpose |
|---|---|---|---|
| Unit testing | `main` | Developers | Verify individual units before promoting to QA. |
| System testing | `beta` | QA | Validate major product claims; gates promotion to `release`. |
| Integration testing | `release` | Independent testers | Test published release bundles through `a` → `b` → `rc` iterations (never unreleased code on `main`/`beta`). |
| Spec validation | `release` (`agora-ping-specs`) | Implementers & stakeholders | Validate golden-code spec candidates against implementation and stakeholder review. |
| Production approval | `release` (`rc`) | Designated final approver | Approve the exact `rc` candidate for production deployment. |

---

## What Must Be Tested Once Code Exists

1. **RBAC enforcement (`A`–`E`):** Every endpoint in `agora-ping-api` tested with authorized, unauthorized, and unauthenticated (`E. Guest`) callers (`business-logic-v1.0.md` lines 19–25, 45–53; see 08, 09).
2. **Google Sign-In token verification:** Valid tokens, expired tokens, wrong `aud` client ID, tampered signatures, and Guest fallback (`business-logic-v1.0.md` line 29).
3. **Privacy-by-design invariants:** Automated tests asserting location coarsening/protection, retention TTL purging, absence of per-user trails in DB/logs, and aggregation-threshold suppression on small buckets (`business-logic-v1.0.md` line 39; see 07, 09).
4. **Cross-client API contract compatibility:** Verify `agora-ping-web` and `agora-ping-android` against `agora-ping-api` schemas before promoting `beta` → `release`.

---

## Manual Drills, Mocking, and Dimensions That Break

- **Manual drills (current):** Before any initial commit or release tag, run the placeholder-leak and git-status checks in `05_DEBUGGING_PLAYBOOK.md` and `04_CHANGE_RULES.md`.
- **Mocking policy (TBD):** Define once frameworks are selected. Never mock out RBAC or privacy-aggregation guards in integration tests.
- **Dimensions most likely to break (inferred):**
  - Cross-repo schema/contract drift between `api`, `web`, and `android` (independent release cycles; see 01, 10).
  - Role/permission drift between `business-logic-v1.0.md` and code (see 04 #3).
  - Uncustomized template names leaking into Git history/tags (see 06 #1).
