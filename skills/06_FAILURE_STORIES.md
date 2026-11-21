# 06 — Failure Stories

**Purpose:** Numbered record of real incidents and near-misses so engineers don't relearn the same lesson the hard way. Link every story back to `04_CHANGE_RULES.md`, `05_DEBUGGING_PLAYBOOK.md`, and `16_ENGINEERING_PRINCIPLES.md`.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. There are **0 runtime/production incidents** because no code has been committed or deployed yet. Entry #1 documents a verified bootstrap/template scar already present in the workspace. The code wins (see 16 #7).

---

## Incidents

### #1 Android Scope & Template Placeholder Drift in `git-guidelines.md` (Pre-Commit Bootstrap Scar)

- **Confidence in reconstruction:** Verified directly from files on disk on 2026-11-21 (no runtime outage — caught during initial `handoff.md` audit).
- **What happened:** The workspace was initialized with four repos named `agora-ping-api`, `agora-ping-web`, `agora-ping-android`, and `agora-ping-specs`. However, `agora-ping-specs/git-guidelines.md` was copied from a generic template without customization:
  - It still uses `code-name` / `CN` / `WCN` / `BCN` / `ACN` / `SCN` throughout.
  - Worse, it disagrees with itself on the Android product name: line 521 writes `code-name-android — Android (ACN)`, while lines 59, 63, 68, 84–85, 281, and 559 write `code-name-app`.
  - Lines 486 and 557–559 also retain historical template dates (`2026-07-04`, `2026-10-05`, `2026-10-09`, `ISO 2026-W41`) from an unrelated repository's retroactive tagging.
- **Why:** Reusable governance templates were dropped into `agora-ping-specs/` ahead of customizing `business-logic-v1.0.md` and before the first commit.
- **How it was found:** Reading `agora-ping-specs/git-guidelines.md` against the actual directory names and `git remote -v` output during initial skills generation.
- **Fix (resolved 2026-11-22):** Upon promoting `business-logic-v1.1.md`, confirmed `agora-ping` / `AP` (`WAP`, `BAP`, `AAP`, `SAP`), standardized Android scopes to `agora-ping-android:`, populated domain feature scopes, and removed the stale 2026 template dates in `agora-ping-specs/git-guidelines.md` (see 04 #1, 15 Retired).
- **Lesson:** Never treat an uncustomized template as an active contract. Standardize cross-repo names before the first commit so permanent commit scopes and release tags don't fragment (see 04 #1, 15 #1, 16 #1, 16 #2).
