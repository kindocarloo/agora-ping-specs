# 01 — Architecture

**Purpose:** Read this first. Explains the ecosystem's four-repository layout, ownership boundaries, planned data flows, architectural decisions, and ranked technical debt.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. No application code exists yet; architectural boundaries are verified from repo topology, `agora-ping-specs/business-logic-v1.0.md`, and `agora-ping-specs/git-guidelines.md`. The code wins (see 16 #7).

---

## One-Paragraph Model

`agora-ping-ecosystem` is a multi-repository platform split into three runtime products — a backend API (`agora-ping-api`), a web frontend (`agora-ping-web`), and an Android client (`agora-ping-android`) — governed by a fourth specification repository (`agora-ping-specs`). At the time of verification, all four repositories are freshly initialized with no commits, no tech stack manifests, and no deployed services. The confirmed architectural anchors are Google Sign-In authentication, a five-tier RBAC model (`A`–`E`), a mandatory privacy-by-design layer (Data Privacy Act compliance, location protection, retention limits, no per-user trails, aggregation thresholds, and consent for any data resale), and a maturity-based release pipeline (`main` → `beta` → `release` → production).

---

## Components and Ownership

| Repository | Remote (`origin`) | Owns | Must NOT Own | Confidence |
|---|---|---|---|---|
| `agora-ping-specs` | `git@github.com:kindocarloo/agora-ping-specs.git` | Business logic specs, research/sense-making, git/release guidelines, engineering skills (`skills/`), cross-repo contracts/schemas | Runtime application code or secrets | Verified |
| `agora-ping-api` | `git@github.com:kindocarloo/agora-ping-api.git` | Backend HTTP API, auth verification, RBAC enforcement, persistence, retention/aggregation enforcement | Client UI code, cross-repo governance docs | Verified (repo exists; internals inferred from `git-guidelines.md`) |
| `agora-ping-web` | `git@github.com:kindocarloo/agora-ping-web.git` | Web frontend UI for allowed platforms | Direct DB access, bypassing API auth/privacy rules | Verified (repo exists; internals inferred) |
| `agora-ping-android` | `git@github.com:kindocarloo/agora-ping-android.git` | Android client UI for allowed platforms | Direct DB access, bypassing API auth/privacy rules, storing raw unconsented user trails | Verified (repo exists; internals inferred) |

*(Root directory `agora-ping-ecosystem/` is a non-git container holding `AGENTS.md` and `handoff.md`; it is not deployed.)*

---

## End-to-End Data Flows (Target State — Inferred from Specs)

No runtime code exists yet. Based on `agora-ping-specs/business-logic-v1.0.md`:

1. **Authentication Flow:** User signs in via Google Sign-In on `agora-ping-web` or `agora-ping-android` → client sends identity credential to `agora-ping-api` → API validates token and maps user to a role (`A`–`D`; unauthenticated callers operate as `E. Guest`).
2. **Feature & Privacy Flow:** Client submits domain actions → `agora-ping-api` enforces RBAC (`MVP Features and Access`), strips/protects location precision and per-user trails, enforces retention limits, and applies aggregation thresholds before exposing analytics to `B. Administrator` or external consumers.
3. **Specification → Implementation Flow:** Requirements are authored in `agora-ping-specs/business-logic-v1.0.md` → environmental scan runs via `agora-ping-specs/sense-making.md` into `agora-ping-specs/planning/sense-making.csv` → features and contracts are implemented in lockstep across `api`, `web`, and `android` (see 04 #3).

---

## Hard Boundaries

1. **Specifications repo contains no runnable code.** *Miss →* `agora-ping-specs` release tags (`SCN` / ecosystem spec prefix) lose their baseline-approval semantics defined in `git-guidelines.md` lines 467–482.
2. **Only Web and Android are allowed client platforms** (`business-logic-v1.0.md` line 5). *Miss →* Unbudgeted platform scope breaks feature parity and release coordination.
3. **No per-user tracking trails & enforced aggregation thresholds** (`business-logic-v1.0.md` line 39). *Miss →* Violates the mandatory Data Privacy Act solution layer and requires breaking schema migrations later (see 07, 09, 16 #3).
4. **Strict maturity-based branch promotion (`main` → `beta` → `release` → production).** Independent testers never test `main` or `beta` builds (`git-guidelines.md` lines 307–310). *Miss →* Unverified development code leaks into integration testing and invalidates release tags.

---

## Decision Records

### Decision: Four-repository ecosystem split (verified 2026-11-21, repo bootstrap)
- **Status:** accepted
- **Context:** The platform ships a backend API, a web client, an Android client, and living specifications with independent release cadences.
- **Choice:** Separate Git repositories (`agora-ping-api`, `agora-ping-web`, `agora-ping-android`, `agora-ping-specs`) nested under a non-git local workspace folder (`agora-ping-ecosystem/`).
- **Alternatives:** Single monorepo with shared tooling.
- **Consequences:** Each product gets its own weekly release tag stream (`00Z`), but cross-repo changes require explicit lockstep tracking (see 04) and root-level `git` commands fail (see 05 #1).

### Decision: Maturity-based branching and weekly ISO-week tagging (verified 2026-11-21, `git-guidelines.md`)
- **Status:** accepted
- **Context:** Developers, QA, independent integration testers, and final production approvers operate as separate gates.
- **Choice:** Enforce `main` → `beta` → `release` → production promotion with `<prefix>.0X.Y.00Z[a|b|rc][N]` tags cut on Fridays after 17:00 local time.
- **Alternatives:** Trunk-based continuous deployment or GitFlow feature/hotfix branching.
- **Consequences:** Clear auditability and QA gating, but requires disciplined branch promotions and manual tag-table updates in `git-guidelines.md` (see 04 #4, 10).

### Decision: Google Sign-In as baseline authentication (verified 2026-11-21, `business-logic-v1.0.md`)
- **Status:** accepted (implementation TBD)
- **Context:** Users authenticate across both Web and Android clients.
- **Choice:** Requirement #1 mandates Google Sign-In integration; unauthenticated users fall into `E. Guest`.
- **Alternatives:** Custom email/password authentication or multi-provider OAuth.
- **Consequences:** Offloads password storage risk, but requires coordinating Google OAuth client IDs across Web, Android, and API token verification (see 09).

### Decision: Privacy-by-design as a mandatory solution layer (verified 2026-11-21, `business-logic-v1.0.md`)
- **Status:** accepted (implementation TBD)
- **Context:** System handles user activity and potentially location/analytics data under Data Privacy Act constraints.
- **Choice:** Mandate location protection, retention limits, no per-user trails, aggregation thresholds, and explicit consent for any data resale at the architecture layer.
- **Alternatives:** Adding privacy controls after MVP launch.
- **Consequences:** Constrains database schema, logging, and analytics queries from Day 1 (see 07, 09, 16 #3).

---

## Inherited Tradeoffs

- **Template bootstrap state:** `agora-ping-specs` was seeded from a reusable project template (`code-name` / `CN`), which accelerates governance setup but leaves placeholder strings and naming drift (`code-name-app` vs `agora-ping-android`) until customized (see 06 #1, 15 #1).
- **Non-git workspace wrapper:** Keeping `AGENTS.md` and `handoff.md` in `agora-ping-ecosystem/` outside any git repo means root-level edits are not version-controlled unless mirrored into `agora-ping-specs/`.

---

## Debt Register (Ranked by Blast Radius)

| Rank | Item | Why It Hurts | Target Fix | Cross-ref |
|---|---|---|---|---|
| 1 | `business-logic-v1.0.md` is still an unfilled template | Blocks tech stack choice, DB schema, API design, RBAC matrix, and `sense-making.md` research | Fill all `<...>` fields, requirements 2–7, Moderator/Contributor roles, and MVP access matrix | 15 #2 |
| 2 | `git-guidelines.md` still has `code-name`/`CN` placeholders and `app` vs `android` drift | Causes inconsistent commit scopes and wrong release tag prefixes from the very first commit | Replace `code-name`/`CN` with Agora Ping's official code name & short code; standardize `android` vs `app` | 04 #1, 06 #1, 15 #1 |
| 3 | All 5 `AGENTS.md` files are identical 9-line stubs | Sub-repos lack stack-specific build, lint, test, and architecture rules | Add repo-specific instructions to each `agora-ping-*/AGENTS.md` as stacks are chosen | 04 #2, 15 #4 |
| 4 | All 4 repos have unborn `HEAD` (`origin/main [gone]`) | No shared baseline commit, no CI, no branch protection | Make initial commits following customized `git-guidelines.md` and push `main` | 05 #2, 15 #3 |
