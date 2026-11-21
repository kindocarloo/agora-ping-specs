# 13 — Dependencies

**Purpose:** Dependency selection policy, inventory of external libraries/services with why each exists, upgrade traps, and deliberate rejections.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. **This document barely applies yet because there are zero package manifests (`package.json`, `build.gradle*`, `pyproject.toml`, `go.mod`, etc.) in any of the four repositories.** The code wins (see 16 #7).

---

## Policy

1. **No dependency without a reason.** Every runtime dependency added to `agora-ping-api`, `agora-ping-web`, or `agora-ping-android` must be justified in PR review and logged here if it introduces cross-repo coupling, security surface, or upgrade risk.
2. **Respect privacy by design (`business-logic-v1.0.md` line 39):** Do **not** add third-party analytics, crash-tracking, or location SDKs that automatically collect per-user trails or send raw user coordinates/identifiers to third parties without Data Privacy Act compliance and consent (see 09, 16 #3).
3. **Commit scope:** Use `deps:` only for cross-repo dependency updates; use `<product>:` (e.g., `agora-ping-api:`) for single-repo dependency updates (`git-guidelines.md` lines 94–113).

---

## Confirmed External Service Dependencies (Verified from Specs & Git Config)

| Dependency | Surface | Why It Exists | Status / Notes |
|---|---|---|---|
| **Google Sign-In** | `agora-ping-web`, `agora-ping-android`, `agora-ping-api` | Mandated by System Requirement #1 (`business-logic-v1.0.md` line 29) | SDKs and OAuth client IDs TBD; verify ID tokens server-side (see 09). |
| **GitHub (`kindocarloo/agora-ping-*`)** | All 4 repos | Source control, SSH remotes, release tags (`git-guidelines.md`) | Remotes configured; no commits pushed yet (`origin/main [gone]`). |

---

## Upgrade Traps & Deliberate Rejections

- **Upgrade traps:** None recorded yet (0 code dependencies installed).
- **Deliberate rejections:**
  - **Platforms outside Web & Android** — Explicitly excluded by `Allowed Platforms: Web, Android` in `agora-ping-specs/business-logic-v1.0.md` line 5 (no iOS/desktop native client dependencies).
  - *(Add rejected frameworks/libraries here as soon as the tech stack is chosen in `business-logic-v1.0.md` so newcomers don't re-litigate them.)*
