# 04 — Change Rules

**Purpose:** Inventory of every lockstep set, hidden cross-file/cross-repo coupling, and high-risk change area. Read before modifying shared names, specs, instructions, or release tags.

**Confidence note:** verified against updated `agora-ping-specs/business-logic-v1.0.md` on 2026-11-22. Lockstep Set #6 captures the cross-repo Official Guide Descriptor Engine contract; populate exact file paths for #6 once Supabase/API/Android/Web code lands. The code wins (see 16 #7).

---

## Lockstep Sets

### #1 Ecosystem Identity (Code Name, Short Code, Product Prefixes)

Confirmed identity: **`agora-ping`** / short code **`AP`** / prefixes **`WAP`**, **`BAP`**, **`AAP`**, **`SAP`**. When changing ecosystem names or prefixes, update **all** of these together:

1. `agora-ping-specs/business-logic-v1.1.md` — `Project Code Name` and `Project Short Code`.
2. `agora-ping-specs/git-guidelines.md` — Preferred & general scopes (`agora-ping-api`, `agora-ping-web`, `agora-ping-android`, `agora-ping-specs`), Ecosystem-wide identity (`Agora Ping`, `AP`), Product prefixes (`WAP`, `BAP`, `AAP`, `SAP`), and Release Tags headings/next-release lines.
3. Repository folder names & GitHub remotes (`agora-ping-api`, `agora-ping-web`, `agora-ping-android`, `agora-ping-specs`).

- *Miss →* Commit scopes and release tags drift across repos (see 06 #1).

### #2 Agent Instruction Entrypoints (`AGENTS.md`)

When changing shared workspace-wide agent rules or required reading lists, keep all 5 files aligned (while allowing repo-specific sections below the shared header):

1. `AGENTS.md` (workspace root — untracked by any repo)
2. `agora-ping-api/AGENTS.md`
3. `agora-ping-android/AGENTS.md`
4. `agora-ping-web/AGENTS.md`
5. `agora-ping-specs/AGENTS.md`

- *Miss →* An engineer or AI agent opening a single sub-repo directly misses updated skills/guidelines pointers or follows stale instructions (see 05 #3, 15 #4).

### #3 Features, User Levels (`A`–`E`), and Shared Commit Scopes

When adding, renaming, or removing a feature or user role:

1. `agora-ping-specs/business-logic-v1.0.md` — `User Levels` (lines 19–25), `System Requirements` (lines 29–35), and `MVP Features and Access` (lines 45–53).
2. `agora-ping-specs/git-guidelines.md` — Shared feature scope list (line 71: `auth`, `sync`, `security`, `backup`, `restore`, `<feature1>`, …).
3. Future implementations across `agora-ping-api` (RBAC middleware/endpoints), `agora-ping-web` (route guards/UI), and `agora-ping-android` (screen/action guards).

- *Miss →* Web/Android expose actions the API rejects (or worse, API forgets to enforce a role restriction defined in the MVP access matrix), and commit scopes diverge across repos.

### #4 Release Tags and the `git-guidelines.md` Tag Registry

Whenever cutting a weekly build or pre-release tag on a repo's `release` branch:

1. Annotated Git tag on the `release` branch in the target repo (`agora-ping-api`, `agora-ping-web`, `agora-ping-android`, or `agora-ping-specs`).
2. Corresponding product table and `Next release:` line in `agora-ping-specs/git-guidelines.md` (lines 521–552).

- *Miss →* Next release engineer reuses or skips a `00Z` number, violating chronological tag monotonicity (`git-guidelines.md` lines 506–511; see 10).

### #5 Business Logic Spec → Environmental Scanning

Whenever `agora-ping-specs/business-logic-v*.md` changes meaningfully:

1. `agora-ping-specs/business-logic-v1.0.md` (or newer versioned file)
2. `agora-ping-specs/sense-making.md` (reads "the latest business-logic file")
3. `agora-ping-specs/planning/sense-making.csv` (generated output — not yet created)

- *Miss →* Environmental scan scores (`Impact`, `Relevance`, `Uncertainty`, `Urgency`) reflect stale or placeholder requirements (see 05 #4, 15 #5).

### #6 Official Guide Trait Decks & Numeric Research Codes (Planned Cross-Repo Contract)

Whenever adding a crop, changing plant-part ordering (`foliage`, `stem/vine`, `storage root/corm`), editing categorical choices, changing numeric validation ranges, or updating numeric research codes:

1. Canonical versioned trait deck definitions in `agora-ping-specs/` (contract/schema) and Supabase (`agora-ping-api` migrations/seeds)
2. Server-side deck version validator in `agora-ping-api` (validating synced `sample_uuid` payloads against the deck version they were recorded under)
3. Offline cached trait deck, sequential wizard screens, and per-crop CSV/JSON encoder in `agora-ping-android`
4. Trait-profile filter definitions and human-readable label renderers in `agora-ping-web`

- *Miss →* Offline Android exports emit different numeric research codes than Supabase/Web expect, or synced specimens logged on an older cached deck fail validation and stay stranded in the Android queue (see 01, 07, 08). Always bump the deck version rather than mutating existing research code meanings in place.

### #7 Offline QR Specimen Label Contract (`AP1`)

Confirmed format: `AP1|<sample_uuid>|<crop_code>|<YYYY-MM-DD>` with crop codes `CAS` (Cassava), `SWP` (Sweet Potato), `TAR` (Taro), `YAM` (Yam), and zero PII/GPS. Whenever extending the QR payload or crop code list, update together:

1. `agora-ping-specs/business-logic-v1.1.md` (Section 7 contract)
2. QR generator & printable PNG/PDF label renderer (plus human-readable fallback line) in `agora-ping-android`
3. QR scanner parser in `agora-ping-android` (must remain backward-compatible with `AP1` tags already printed on physical specimens)
4. Crop-code mapping in `agora-ping-api` and `agora-ping-web`

- *Miss →* Printed field tags become unscannable after an app update, breaking Field → Harvest → Lab specimen continuity (see 01, 09).

---

## Hidden Dependencies

- **Workspace root globs in `AGENTS.md`:** `AGENTS.md` uses relative globs (`*-api/AGENTS.md`, `*-specs/skills/*.md`, etc.). If a sub-repo is opened standalone outside `agora-ping-ecosystem/`, sibling globs like `../agora-ping-specs/skills/*.md` will not resolve from the sub-repo root. *Miss →* Agents silently skip reading `skills/` and `git-guidelines.md`.
- **Local clock dependency for weekly tags:** `git-guidelines.md` line 500 forbids tagging the current ISO week before **Friday 5:00 PM local time**. *Miss →* Premature weekly tags split one week's commits across two `00Z` numbers.

---

## High-Risk Areas

| Area | Risk | Guard |
|---|---|---|
| First commit in any of the 4 repos | Locks in ISO week `001` anchor (`git-guidelines.md` line 494) and initial scope naming | Finalize Lockstep Set #1 (`code-name`, `short-code`, `android` vs `app`) before first commit |
| Git history & tags | Tags must never be moved or reused; AI agents must never appear as authors | Review `git show` and `git tag -v/-n` before pushing (see 03, 10) |
| Privacy & location data model (future) | Retrofitting "no per-user trails" after collecting linked user+location rows is legally and technically painful | Design schema and logs around `business-logic-v1.0.md` line 39 from Day 1 (see 07, 09) |

---

## What to Retest After Changes

- **After updating Lockstep Set #1 (`git-guidelines.md` / `business-logic-v1.0.md`):** Grep `agora-ping-specs/` for `code-name`, `CN`, `<`, and `xxx` to confirm zero leftover placeholders.
- **After updating Lockstep Set #2 (`AGENTS.md`):** Verify all 5 `AGENTS.md` files exist and point to valid relative paths.
- **After cutting a release tag (Lockstep Set #4):** Verify the tag is annotated (`git tag -n`), points to a commit on `release` (not `main`/`beta`), falls after Friday 17:00 for the current week, and matches `git-guidelines.md`.
- **Once application code exists:** Replace this list with concrete unit, integration, API contract, and cross-client RBAC test suites (see 11).
