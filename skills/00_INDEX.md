# 00 — Index

**Purpose:** Entry point for the `agora-ping-specs/skills/` knowledge base. Use this to pick the right reading order for your task, check document freshness, and track changes.

**Confidence note:** verified against approved `agora-ping-specs/business-logic-v1.1.md`, customized `agora-ping-specs/git-guidelines.md` (`AP`), and pushed `main` branches (`api` `6578b62`, `web` `c7121f4`, `android` `c0b6e4b`, `specs` `dc3507f`) on 2026-11-22. The code wins (see 16 #7).

---

## Reading Order by Task

| Task | Read in order |
|---|---|
| First day on the project | `01` → `02` → `03` → `15` → `16` |
| Finishing project bootstrap (specs & repo setup) | `01` → `04` → `14` → `15` |
| Adding a feature across API / Web / Android | `01` → `04` → `07` → `08` → `09` → `11` → `14` |
| Designing data models, `*_uuid` sync, or privacy controls | `01` → `07` → `09` → `16` |
| Debugging a broken setup or workflow | `05` → `06` → `15` |
| Cutting a weekly release or promoting a branch | `03` → `04` → `10` → `11` |
| Adding or upgrading a dependency | `13` → `09` → `12` |
| Updating skills after a release, incident, or decision | `INBOX.md` → affected docs → `00_INDEX.md` |

---

## Document Inventory

| File | Topic | Current Maturity | Last Verified |
|---|---|---|---|
| [00_INDEX.md](00_INDEX.md) | Reading order, inventory, changelog | Active | 2026-11-22 |
| [INBOX.md](INBOX.md) | Contribution intake template & routing | Active | 2026-11-21 |
| [01_ARCHITECTURE.md](01_ARCHITECTURE.md) | System model (Kotlin/Next.js/API/Supabase), flows, decisions, debt | Spec-backed (code TBD) | 2026-11-22 |
| [02_PROJECT_STRUCTURE.md](02_PROJECT_STRUCTURE.md) | Workspace tree, placement rules, naming conventions | Bootstrap (no code yet) | 2026-11-21 |
| [03_CODE_STYLE.md](03_CODE_STYLE.md) | Style, comments, anti-patterns, commit conventions | Commit rules active; code TBD | 2026-11-21 |
| [04_CHANGE_RULES.md](04_CHANGE_RULES.md) | Lockstep sets, hidden couplings, retest checklists | Bootstrap + descriptor deck lockstep active | 2026-11-22 |
| [05_DEBUGGING_PLAYBOOK.md](05_DEBUGGING_PLAYBOOK.md) | Logs, exact error symptoms, diagnostic commands | Minimal (workspace/git only) | 2026-11-21 |
| [06_FAILURE_STORIES.md](06_FAILURE_STORIES.md) | Numbered incidents and template scars | 1 resolved bootstrap scar; 0 runtime incidents | 2026-11-22 |
| [07_DATABASE.md](07_DATABASE.md) | Supabase, `sample_uuid`/`session_uuid`, `k>=5`, `30d`/`7d` invariants | Spec-backed v1.1 (migrations TBD) | 2026-11-22 |
| [08_API.md](08_API.md) | TypeScript API surface, sync upserts, moderation, RBAC, versioning | Spec-backed v1.1 (routes TBD) | 2026-11-22 |
| [09_SECURITY.md](09_SECURITY.md) | Threat model, auth/RBAC, `AP1` QR privacy, confirmed thresholds | Spec-backed v1.1 (controls TBD) | 2026-11-22 |
| [10_DEPLOYMENT.md](10_DEPLOYMENT.md) | Branch promotion, `WAP`/`BAP`/`AAP`/`SAP` tags, release checklist | Git/tag policy customized; infra TBD | 2026-11-22 |
| [11_TESTING.md](11_TESTING.md) | Stage gates, coverage reality, testing strategy | Stage gates active; 0 tests yet | 2026-11-21 |
| [12_PERFORMANCE.md](12_PERFORMANCE.md) | Limits, hot paths, profiling | Pre-code (stub) | 2026-11-21 |
| [13_DEPENDENCIES.md](13_DEPENDENCIES.md) | Dependency policy, confirmed stack (Kotlin/Next.js/Supabase), rejections | Spec-backed (0 manifests yet) | 2026-11-22 |
| [14_DEVELOPER_WORKFLOWS.md](14_DEVELOPER_WORKFLOWS.md) | Setup and step-by-step recipes | Bootstrap & git workflows active | 2026-11-21 |
| [15_KNOWN_LIMITATIONS.md](15_KNOWN_LIMITATIONS.md) | Ranked drift, remaining spec gaps, redesign list | Active (6 verified gaps) | 2026-11-22 |
| [16_ENGINEERING_PRINCIPLES.md](16_ENGINEERING_PRINCIPLES.md) | Proven rules with evidence and source links | Active (7 baseline principles) | 2026-11-21 |

---

## How to Contribute

1. **Quick capture:** Drop a rough note into [INBOX.md](INBOX.md) using its template. A rough entry beats losing the lesson.
2. **Direct edit:** Edit the target document directly if you can verify every path, command, and claim against the current code. Keep every rule paired with what breaks without it.
3. **Refresh triggers:** Always update affected documents (and their **Confidence note**) after a release, an incident, a new design decision, a new lockstep set, a full inbox, or the first code scaffold in any sub-repo.
4. **Retire, never delete:** Move obsolete guidance to a `## Retired` section marked `Superseded (<date>): by <replacement>, because <reason>`. Append new numbered items; never renumber existing ones.

---

## Changelog

- **2026-11-22 (rev 4)** — Promoted `business-logic-v1.1-proposed.md` to approved `business-logic-v1.1.md` (confirming `AP` short code, `AP1` QR contract, `CAS`/`SWP`/`TAR`/`YAM` crop codes, `k >= 5`, `3` flags, `3` private hits, `30d`/`7d` retention, TypeScript API), customized `git-guidelines.md` (`WAP`/`BAP`/`AAP`/`SAP` + `agora-ping-android`), added Lockstep Set `#7`, retired Limitation `#1`, and refreshed `00`, `01`, `04`, `06`, `07`, `08`, `09`, `10`, `13`, and `15`.
- **2026-11-22 (rev 3)** — Added Offline QR Specimen Label Generator & Scanner (`sample_uuid`, crop code, date; PNG/PDF via Android native share/print sheet; scan to retrieve/update) to `business-logic-v1.0.md`, `business-logic-v1.1-proposed.md`, `01_ARCHITECTURE.md`, and `09_SECURITY.md`.
- **2026-11-22 (rev 2)** — Refined `business-logic-v1.0.md` with the Official Guide Descriptor Engine (versioned trait decks ordered by plant part with numeric research codes), sequential one-by-one trait wizard, continuous multi-specimen loop (`sample_uuid`), and per-crop CSV/JSON export; synced `00`, `01`, `04` (added Lockstep Set `#6`), `07`, and `08`.
- **2026-11-22** — Populated `business-logic-v1.0.md` for `agora-ping` (offline-first Kotlin Android root crop trait characterization + Next.js Web + API + Supabase, `*_uuid` sync, coarse zone polygons, private guideline hits, zero financial bait) and refreshed `00`, `01`, `07`, `08`, `09`, `13`, and `15` to match pushed `main` commits and updated specs.
- **2026-11-21** — Initial generation of `agora-ping-specs/skills/` (`00`–`16` + `INBOX.md`) from `handoff.md` against the pre-initial-commit `agora-ping-ecosystem` workspace. Captured verified repository topology, `git-guidelines.md` governance, `business-logic-v1.0.md` privacy/auth requirements, and 6 active bootstrap gaps.
