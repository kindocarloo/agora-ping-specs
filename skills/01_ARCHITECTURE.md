# 01 — Architecture

**Purpose:** Read this first. Explains the ecosystem's four-repository layout, ownership boundaries, end-to-end data flows, architectural decisions, and ranked technical debt.

**Confidence note:** verified against approved `agora-ping-specs/business-logic-v1.1.md`, customized `agora-ping-specs/git-guidelines.md` (`AP` / `WAP`/`BAP`/`AAP`/`SAP`), and pushed `main` branches (`api` `6578b62`, `web` `c7121f4`, `android` `c0b6e4b`, `specs` `dc3507f`) on 2026-11-22. No application code exists yet; stack and product flows are verified from `business-logic-v1.1.md`. The code wins (see 16 #7).

---

## One-Paragraph Model

`agora-ping` is an offline-first root crop trait characterization and community data-sharing platform for researchers and agricultural communities (Cassava, Sweet Potato, Taro, Yam). It spans four Git repositories: a **Kotlin** offline-first Android field wizard (`agora-ping-android`), a **Next.js** web portal (`agora-ping-web`), a backend API (`agora-ping-api`) backed by **Supabase**, and a specifications/skills repository (`agora-ping-specs`). Versioned **Official Guide Descriptor Engine** trait decks (ordered by plant part: foliage, stem/vine, storage root/corm, with standardized categorical choices and numeric research codes) power a one-trait-per-screen Android wizard with a continuous multi-specimen loop (`sample_uuid` per specimen, returning directly to crop-type selection). Enumerators export coded, per-crop CSV/JSON tables offline for R, Weka, or STAR, and optionally sync opted-in anonymized samples online via `*_uuid` keys where exact plot coordinates are generalized to coarse zone polygons, peers explore and flag records via private guideline hits (no public reputation scores, zero financial bait), and regional trait averages display only above minimum aggregation thresholds.

---

## Components and Ownership

| Repository | Remote (`origin`) | Planned Stack | Owns | Must NOT Own | Confidence |
|---|---|---|---|---|---|
| `agora-ping-specs` | `git@github.com:kindocarloo/agora-ping-specs.git` | Markdown / CSV | Business logic specs, research/sense-making, git/release guidelines, engineering skills (`skills/`), cross-repo contracts/schemas | Runtime application code or secrets | Verified |
| `agora-ping-api` | `git@github.com:kindocarloo/agora-ping-api.git` | TypeScript (Node/Edge API) + Supabase | HTTP API, Google Sign-In verification, RBAC (`A`–`E`), versioned descriptor deck delivery/validation, `sample_uuid` / `*_uuid` + `revision` idempotent sync ingestion, plot-coordinate-to-zone generalization, guideline-hit threshold engine (`3` flags / `3` hits), aggregation-gated summaries (`k >= 5`) | Client UI code, cross-repo governance docs | Verified in `business-logic-v1.1.md` (code TBD) |
| `agora-ping-web` | `git@github.com:kindocarloo/agora-ping-web.git` | Next.js | Zone-pinned community sample explorer (crop type, trait profile, coarse zone), moderation UI, regulatory & aggregated trait portal (privacy disclosures, consent controls, retention limits) | Direct DB access bypassing API privacy/aggregation rules, public reputation score UI | Verified in `business-logic-v1.0.md` (code TBD) |
| `agora-ping-android` | `git@github.com:kindocarloo/agora-ping-android.git` | Kotlin (offline-first) | Offline Official Guide Descriptor Engine cache, sequential one-by-one trait wizard, offline QR specimen label generator (PNG/PDF via native share/print sheet) & scanner, continuous multi-specimen loop (`sample_uuid`), numeric research-code auto-encoding, per-crop CSV/JSON export (R, Weka, STAR), local sync queue, mobile explorer | Server secrets, tracking enumerator movement paths, mandatory internet for logging, PII/GPS inside QR tags | Verified in `business-logic-v1.0.md` (code TBD) |

*(Root directory `agora-ping-ecosystem/` is a non-git container holding `AGENTS.md` and `handoff.md`; it is not deployed.)*

---

## End-to-End Data Flows (Verified from `business-logic-v1.0.md`; Implementation TBD)

1. **Descriptor Deck Sync (`Supabase` → `API` → `Android`):** Versioned trait decks for Cassava, Sweet Potato, Taro, and Yam (ordered by plant part: foliage, stem/vine, storage root/corm; standardized categorical choices + numeric research codes + numeric validation ranges) are stored in Supabase and cached offline in `agora-ping-android` (see 04 #6).
2. **Offline Sequential Wizard, QR Labeling & Continuous Multi-Specimen Loop (Zero Internet):** Enumerator picks crop type → steps through one plant part and trait per screen (official multiple-choice or range-validated numeric input) → commits specimen locally with a `sample_uuid` → app generates an offline QR code (`sample_uuid`, crop code, date; exportable as printable PNG/PDF via Android native share/print sheet, scannable to retrieve/update records) → wizard immediately returns to crop-type selection so mixed root crop specimens can be logged and labeled consecutively in one field session.
3. **Automated Statistical Encoding & Local Export (Zero Internet):** `agora-ping-android` maps each trait selection to its official numeric research code and exports clean, **per-crop** CSV/JSON tables ready for immediate import into R, Weka, or STAR.
4. **Offline-to-Online Sample Sync (`Android` → `API` → `Supabase`):** With explicit opt-in consent and Google Sign-In, queued specimens sync idempotently via `*_uuid` (`sample_uuid`) keys → `agora-ping-api` validates against the deck version, generalizes exact plot coordinates to coarse zone polygons, discards enumerator movement paths, and writes anonymized samples to Supabase.
5. **Zone Explorer, Guideline-Hit Moderation & Regulatory Portal (`Web` & `Android` ↔ `API`):** Users filter community samples by crop type, trait profile, and coarse geographic zone. Peer flags on misclassified specimens trigger the automated threshold rule engine to hide entries and log private guideline hits (never public reputation scores) for `C. Community Reviewer / Moderator`. The Web portal hosts privacy disclosures, consent controls, retention limits, and threshold-gated regional trait averages.
6. **Specification → Implementation Flow:** Requirements in `agora-ping-specs/business-logic-v1.0.md` drive `agora-ping-specs/sense-making.md` (`planning/sense-making.csv`) and lockstep implementation across `api`, `web`, and `android` (see 04 #3, #5, #6).

---

## Hard Boundaries

1. **Offline-first field core on Android:** Guided trait walk-through, `*_uuid` generation, validation, and CSV/JSON export must work with zero internet connectivity. *Miss →* Unusable in rural/field characterization sites.
2. **Privacy by design & location generalization:** Exact coordinates must be generalized to coarse zone polygons upon sync; enumerator movement trails are never tracked or stored; regional summaries require minimum sample thresholds (`business-logic-v1.0.md`). *Miss →* Violates Data Privacy Act compliance (see 07, 09, 16 #3).
3. **Zero financial bait & no public reputation scores:** No monetary payouts, credits, convertible rewards, or public user karma/reputation scores. *Miss →* Distorts scientific data quality and violates core product governance.
4. **Specifications repo contains no runnable code** and **only Web and Android are allowed client platforms**. *Miss →* Breaks spec release tagging (`git-guidelines.md`) and platform scope.
5. **Strict maturity-based branch promotion (`main` → `beta` → `release` → production).** Independent testers never test `main` or `beta` builds (`git-guidelines.md` lines 307–310).

---

## Decision Records

### Decision: Four-repository ecosystem split (verified 2026-11-21, repo bootstrap)
- **Status:** accepted
- **Context:** Platform ships an Android app, Web app, Backend API, and living specifications with independent release cadences.
- **Choice:** Separate Git repositories (`agora-ping-api`, `agora-ping-web`, `agora-ping-android`, `agora-ping-specs`) nested under a non-git local workspace folder.
- **Alternatives:** Single monorepo with shared tooling.
- **Consequences:** Independent weekly release tags (`00Z`), but cross-repo changes require explicit lockstep tracking (see 04) and root-level `git` commands fail (see 05 #1).

### Decision: Offline-first Kotlin Android + Next.js Web + Supabase stack with `*_uuid` keys (2026-11-22, `business-logic-v1.0.md`)
- **Status:** accepted
- **Context:** Field enumerators work offline in agricultural zones and need clean statistical datasets plus optional community sharing.
- **Choice:** Kotlin for offline-first Android logging/export, Next.js for Web explorer/portal, backend API + Supabase for sync/storage, and client-generated `*_uuid` record keys.
- **Alternatives:** Online-only web form or server-assigned sequential IDs.
- **Consequences:** Conflict-safe offline record creation and instant field usability, at the cost of maintaining local sync queues and schema parity across Kotlin, API, and Supabase (see 07, 08).

### Decision: Maturity-based branching and weekly ISO-week tagging (verified 2026-11-21, `git-guidelines.md`)
- **Status:** accepted
- **Context:** Developers, QA, independent integration testers, and final production approvers operate as separate gates.
- **Choice:** Enforce `main` → `beta` → `release` → production promotion with `<prefix>.0X.Y.00Z[a|b|rc][N]` tags cut on Fridays after 17:00 local time.
- **Alternatives:** Trunk-based continuous deployment or GitFlow.
- **Consequences:** Clear auditability and QA gating, requiring disciplined promotions and lockstep updates to `git-guidelines.md` (see 04 #4, 10).

### Decision: Google Sign-In, privacy-by-design, private moderation hits, and zero financial bait (2026-11-22, `business-logic-v1.0.md`)
- **Status:** accepted
- **Context:** Platform handles agronomic field records and community contributions under Data Privacy Act constraints.
- **Choice:** Google Sign-In for online actions, coarse zone polygon generalization, no per-user trails, transient draft auto-expiry, threshold-gated summaries, opt-in sharing consent, private guideline hits without public reputation scores, and zero monetary incentives.
- **Alternatives:** Gamified/paid crowdsourcing with exact GPS pins and public leaderboards.
- **Consequences:** Protects enumerator privacy and scientific integrity, constraining DB schema, moderation UI, and analytics queries from Day 1 (see 07, 09, 16 #3).

---

## Inherited Tradeoffs

- **Template bootstrap remnants:** `git-guidelines.md` still retains `code-name`/`CN` placeholders and `code-name-app` vs `agora-ping-android` naming drift until customized (see 06 #1, 15 #1).
- **Non-git workspace wrapper:** Root `AGENTS.md` and `handoff.md` sit outside the four Git repos and are not synced to GitHub unless mirrored into `agora-ping-specs/`.

---

## Debt Register (Ranked by Blast Radius)

| Rank | Item | Why It Hurts | Target Fix | Cross-ref |
|---|---|---|---|---|
| 1 | Zero application code, schemas, tests, or CI across `api`, `web`, and `android` | Platform exists only as specs and `AGENTS.md` stubs on `main` | Scaffold Kotlin, Next.js, TypeScript API, and Supabase schemas/migrations | 11, 15 #3 |
| 2 | All 5 `AGENTS.md` files are identical 9-line stubs | Sub-repos lack Kotlin/Next.js/TypeScript-API/Supabase build, lint, and test rules | Add stack-specific instructions to each `agora-ping-*/AGENTS.md` | 04 #2, 15 #4 |
| 3 | `<Team Name>` placeholder remains in `business-logic-v1.1.md` | Needed before external launch/disclosures | Confirm team name and update `business-logic-v1.1.md` | 15 #2 |
