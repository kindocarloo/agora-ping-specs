# 00 — Index

**Purpose:** Entry point for the `agora-ping-specs/skills/` knowledge base. Use this to pick the right reading order for your task, check document freshness, and track changes.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. The code wins (see 16 #7).

---

## Reading Order by Task

| Task | Read in order |
|---|---|
| First day on the project | `01` → `02` → `03` → `15` → `16` |
| Finishing project bootstrap (specs & repo setup) | `01` → `04` → `14` → `15` |
| Adding a feature across API / Web / Android | `01` → `04` → `07` → `08` → `09` → `11` → `14` |
| Designing data models or privacy controls | `01` → `07` → `09` → `16` |
| Debugging a broken setup or workflow | `05` → `06` → `15` |
| Cutting a weekly release or promoting a branch | `03` → `04` → `10` → `11` |
| Adding or upgrading a dependency | `13` → `09` → `12` |
| Updating skills after a release, incident, or decision | `INBOX.md` → affected docs → `00_INDEX.md` |

---

## Document Inventory

| File | Topic | Current Maturity | Last Verified |
|---|---|---|---|
| [00_INDEX.md](00_INDEX.md) | Reading order, inventory, changelog | Active (bootstrap) | 2026-11-21 |
| [INBOX.md](INBOX.md) | Contribution intake template & routing | Active | 2026-11-21 |
| [01_ARCHITECTURE.md](01_ARCHITECTURE.md) | System model, repo ownership, boundaries, decisions, debt | Bootstrap (no code yet) | 2026-11-21 |
| [02_PROJECT_STRUCTURE.md](02_PROJECT_STRUCTURE.md) | Workspace tree, placement rules, naming conventions | Bootstrap (no code yet) | 2026-11-21 |
| [03_CODE_STYLE.md](03_CODE_STYLE.md) | Style, comments, anti-patterns, commit conventions | Commit rules active; code TBD | 2026-11-21 |
| [04_CHANGE_RULES.md](04_CHANGE_RULES.md) | Lockstep sets, hidden couplings, retest checklists | Bootstrap lockstep sets active | 2026-11-21 |
| [05_DEBUGGING_PLAYBOOK.md](05_DEBUGGING_PLAYBOOK.md) | Logs, exact error symptoms, diagnostic commands | Minimal (workspace/git only) | 2026-11-21 |
| [06_FAILURE_STORIES.md](06_FAILURE_STORIES.md) | Numbered incidents and template scars | 1 bootstrap scar; 0 runtime incidents | 2026-11-21 |
| [07_DATABASE.md](07_DATABASE.md) | Data model, privacy invariants, migration rules | Pre-schema (privacy mandates only) | 2026-11-21 |
| [08_API.md](08_API.md) | API contract, routes, auth, validators, versioning | Pre-code (stub + requirements) | 2026-11-21 |
| [09_SECURITY.md](09_SECURITY.md) | Threat model, auth/RBAC, privacy layer, secrets | Requirements active; controls TBD | 2026-11-21 |
| [10_DEPLOYMENT.md](10_DEPLOYMENT.md) | Branch promotion, weekly tags, release checklist | Git/tag policy active; infra TBD | 2026-11-21 |
| [11_TESTING.md](11_TESTING.md) | Stage gates, coverage reality, testing strategy | Stage gates active; 0 tests yet | 2026-11-21 |
| [12_PERFORMANCE.md](12_PERFORMANCE.md) | Limits, hot paths, profiling | Pre-code (stub) | 2026-11-21 |
| [13_DEPENDENCIES.md](13_DEPENDENCIES.md) | Dependency policy, inventory, rejections | Pre-code (0 manifests yet) | 2026-11-21 |
| [14_DEVELOPER_WORKFLOWS.md](14_DEVELOPER_WORKFLOWS.md) | Setup and step-by-step recipes | Bootstrap & git workflows active | 2026-11-21 |
| [15_KNOWN_LIMITATIONS.md](15_KNOWN_LIMITATIONS.md) | Ranked drift, missing specs, gaps, redesign list | Active (6 verified bootstrap gaps) | 2026-11-21 |
| [16_ENGINEERING_PRINCIPLES.md](16_ENGINEERING_PRINCIPLES.md) | Proven rules with evidence and source links | Active (7 baseline principles) | 2026-11-21 |

---

## How to Contribute

1. **Quick capture:** Drop a rough note into [INBOX.md](INBOX.md) using its template. A rough entry beats losing the lesson.
2. **Direct edit:** Edit the target document directly if you can verify every path, command, and claim against the current code. Keep every rule paired with what breaks without it.
3. **Refresh triggers:** Always update affected documents (and their **Confidence note**) after a release, an incident, a new design decision, a new lockstep set, a full inbox, or the first commit in any sub-repo.
4. **Retire, never delete:** Move obsolete guidance to a `## Retired` section marked `Superseded (<date>): by <replacement>, because <reason>`. Append new numbered items; never renumber existing ones.

---

## Changelog

- **2026-11-21** — Initial generation of `agora-ping-specs/skills/` (`00`–`16` + `INBOX.md`) from `handoff.md` against the pre-initial-commit `agora-ping-ecosystem` workspace. Captured verified repository topology, `git-guidelines.md` governance, `business-logic-v1.0.md` privacy/auth requirements, and 6 active bootstrap gaps.
