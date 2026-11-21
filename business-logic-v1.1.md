# Business Logic v1.1 — agora-ping

> Development of an Android and Web-based Offline-First Root Crop Trait Characterization and Community Data-Sharing Platform using Kotlin, Next.js, TypeScript, and Supabase for Root Crop Researchers and Agricultural Communities

- **Status:** Approved (supersedes [business-logic-v1.0.md](business-logic-v1.0.md))
- **Allowed Platforms:** Web, Android

---

## 1. Project Details

- **Company/Startup/Team Name:** `<Team Name>` *(confirm before external launch)*
- **Project Code Name:** `agora-ping`
- **Project Short Code:** `AP` (tag prefixes: `WAP`, `BAP`, `AAP`, `SAP` in [git-guidelines.md](git-guidelines.md))
- **Short Description:** Offline-first sequential Android field wizard with QR specimen labeling for standardized root crop trait characterization, paired with a privacy-first Web/Android community data-sharing platform.
- **Long Description:** Field characterization of root crops (Cassava, Sweet Potato, Taro, Yam) relies on standardized morphological and agronomic descriptor guides, yet manual paper recording forces researchers to spend hours transcribing paper tags and encoding categorical traits before statistical analysis. **agora-ping** solves this with a **single-player-first, offline sequential Android wizard** that guides enumerators crop-by-crop and plant-part-by-plant-part using versioned official descriptor choices, generates **offline QR specimen labels** to link field plants to harvest/lab measurements, and exports analysis-ready, numerically encoded per-crop tables for R, Weka, and STAR—paired with an **opt-in online community platform** where anonymized, zone-generalized crop samples help researchers and growers compare cultivar performance across local zones.

---

## 2. Positioning & Core Value Proposition

- **Single-Player Utility First (No Cold-Start Dependency):** Even with zero internet and zero community users, an enumerator gets immediate Day-1 value by eliminating paper transcription and manual research-code encoding before importing into R, Weka, or STAR.
- **Physical-to-Digital Specimen Continuity (Field → Harvest → Lab):** Root crop traits are often recorded across stages (foliage/stem in the field; storage root/corm weight at harvest). Offline QR specimen tags link physical plants and harvested bags directly to their `sample_uuid` for instant scan-to-retrieve and scan-to-update—eliminating specimen mix-ups.
- **Standardized & Privacy-Safe by Design:** Versioned official descriptor decks (Bioversity/IBPGR, CIP, IITA, PhilRootcrops conventions) prevent coding drift, while opt-in sharing, coarse zone polygons, zero-PII QR tags, private guideline-hit moderation (no public reputation scores), and zero financial bait protect enumerators and scientific integrity.

---

## 3. User Levels

| User Level | Description |
| --- | --- |
| A. System Administrator | Maintains/overrides system/server configurations, manages Supabase/API infrastructure, publishes canonical trait deck versions, and performs regular backups. |
| B. Administrator | Manages general system settings, retention schedules, zone polygon reference lists, and generates periodic regional trait analytics and reports gated by minimum sample aggregation thresholds. |
| C. Community Reviewer / Moderator | Automated threshold rule engine plus human moderator that review community-guideline flags on inaccurate entries, uphold or restore hidden samples, and enforce privacy/retention policies without displaying public user reputation scores. |
| D. Field Researcher / Enumerator | Conducts offline specimen-by-specimen trait logging in field sessions, generates/prints/scans offline QR specimen labels to retrieve or update records (e.g., adding harvest traits), exports coded per-crop datasets + codebooks locally for R/Weka/STAR, optionally publishes opted-in anonymized samples online, explores shared samples, and flags misclassified specimens. |
| E. Guest | Unauthenticated users who view public privacy disclosures, retention schedules, threshold-gated regional trait averages/summaries, and anonymized community sample previews on Web/Android. |

---

## 4. System Requirements (MVP)

1. **Authentication & Offline Boundary:** The app shall allow users to authenticate via Google Sign-In for online sync, publishing, flagging, consent management, and administrative actions, while keeping offline trait characterization, QR label generation/printing/scanning, local editing, and CSV/JSON export 100% functional with zero internet dependency and zero mandatory login.
2. **Official Guide Descriptor Engine (`Android` & `Supabase`):** The system shall store structured, immutable, versioned trait decks for Cassava (`CAS`), Sweet Potato (`SWP`), Taro (`TAR`), and Yam (`YAM`) ordered by plant part (`foliage`, `stem/vine`, `storage root/corm`) with standardized categorical choices, numeric research codes, and numeric validation ranges. The Android APK shall bundle a default `v1.0` core descriptor deck so fresh installs work offline on Day 1 and opportunistically cache newer versions when online.
3. **Sequential One-by-One Trait Wizard (`Android`):** The Android app shall prompt for crop type first, then present one plant part and morphological/agronomic trait per screen with official multiple-choice options, range-validated numeric inputs, back-navigation, and explicit `Skip / Not Observable` handling (encoded as `NA` rather than `0` so partial-stage logging—such as vegetative traits logged before harvest—never skews statistics).
4. **Offline QR Specimen Label Generator & Scanner (`Android`):** Upon specimen completion, the Android app shall automatically generate an offline QR code using a compact versioned payload encoding strictly non-PII metadata (`AP1|<sample_uuid>|<crop_code>|<YYYY-MM-DD>` — never enumerator identity or exact GPS), rendered with a **human-readable fallback line** (short ID, crop code, date, optional local accession label) for mud/damage resilience. Labels shall export individually (PNG/PDF) or as a per-session printable sheet (PDF) exclusively via Android's native share/print sheet. Scanning a tag offline shall open the matching local specimen for viewing or updating (e.g., completing harvest traits), and handle unknown/other-device tags gracefully (read-only online lookup if synced & public, or a clear offline-not-found message).
5. **Field Session & Continuous Multi-Specimen Loop (`Android`):** The Android app shall group logged specimens under a lightweight local `session_uuid` (with date and optional local accession/plot label), commit each completed specimen locally with a `sample_uuid` and `deck_version`, immediately return to crop-type selection for consecutive mixed-crop logging and labeling, and allow local review, edit, or deletion of specimens before export or sync.
6. **Automated Statistical Encoding & Local Export (`Android`):** The Android app shall map selected choices to standard numeric research codes, escape spreadsheet formula characters (`=`, `+`, `-`, `@`), and export clean, per-crop CSV/JSON tables (scoped by session or selection) plus a matching `deck_version` codebook legend ready for immediate offline import into R, Weka, or STAR.
7. **Offline-to-Online Sample Sync & Zone Explorer (`Android` -> `API` -> `Supabase` & `Web`):** The system shall default all local specimens to `local_only`, allow explicit opt-in consent to queue selected samples (`local_only` -> `queued` -> `synced` | `sync_failed`) via idempotent `sample_uuid` / `*_uuid` upserts (carrying `revision` / `updated_at` so owner scan-to-update edits sync cleanly), generalize exact plot coordinates to coarse zone polygons upon sync (discarding exact coordinates immediately), and let users filter shared samples by crop type, trait profile, and coarse geographic zone.
8. **Community-Guideline Hit Moderation & Regulatory Portal (`API` & `Web`):** The API and Web app shall allow authenticated peers to submit at most one flag per `sample_uuid` for misclassified specimens or malformed traits; reaching the flag threshold shall auto-hide the sample, record a private guideline hit (never a public reputation score), and queue it for `C. Community Reviewer / Moderator` review. The Web app shall host privacy disclosures, consent/withdrawal controls, retention schedules, and regional trait averages gated by minimum sample aggregation thresholds.

---

## 5. Required Solution Layers

1. **Security and privacy by design (Data Privacy Act compliance):**
   - **Location protection & zero-PII physical tags:** Exact plot coordinates are generalized to coarse zone polygons upon sync (in memory on API or on-device before upload) and never persisted or logged; enumerator movement paths are never tracked or stored; printed QR labels contain zero PII and zero GPS coordinates.
   - **Retention limits:** Unsynced local drafts and unverified transient server entries auto-expire after defined retention windows (with prior warning for local drafts).
   - **Aggregation thresholds:** Regional trait averages and summaries render only when a `(crop_type, coarse_zone)` bucket meets the minimum sample aggregation threshold.
   - **Explicit opt-in & revocable consent:** Samples remain `local_only` by default; explicit opt-in consent is required before online sharing, public dataset inclusion, or any data resale, and contributors can withdraw/delete their synced anonymized samples via consent controls.
2. **Non-monetary incentive model (Zero Financial Bait):**
   - No cash, credits, points, badges, or convertible rewards; user value is strictly faster research data preparation, physical specimen traceability, and shared agronomic knowledge.

---

## 6. MVP Features and Access

| Feature | Platform | Access | MVP Scope Guard |
| --- | --- | --- | --- |
| 1. Official Guide Descriptor Engine (bundled `v1.0` core deck + Supabase version sync) | Android & Supabase | Manage: A,B; Read: A,B,C,D,E | Ship concise core subset (10–15 key descriptors per crop) first; expand via deck versioning without app rewrites. |
| 2. Sequential One-by-One Trait Wizard (crop-first, plant-part ordered, skip/`NA`, back-step) | Android | A,B,C,D | Text/coded inputs + range validation only; no crop photo/CV pipeline in MVP. |
| 3. Offline QR Specimen Label Generator & Scanner (versioned non-PII `AP1` QR + human-readable text; single PNG/PDF & session PDF sheet via native share/print; scan to retrieve/update) | Android | A,B,C,D | Native Android share/print sheet only (no custom Bluetooth/thermal printer SDKs); camera used strictly for QR scanning. |
| 4. Field Session & Continuous Multi-Specimen Loop (`session_uuid` + `sample_uuid`, local edit/delete) | Android | A,B,C,D | Single-device local drafts; no multi-device live merge/CRDT. |
| 5. Automated Statistical Encoding & Local Export (per-crop CSV/JSON + codebook legend) | Android | A,B,C,D | Exports ready for R, Weka, STAR; no in-app ANOVA/charting engine. |
| 6. Offline-to-Online Opt-In Sync & Zone Explorer (`*_uuid` idempotent upsert with `revision`, coarse zone/trait filters) | Android -> API -> Supabase & Web | Sync: A,B,C,D; Explorer: A,B,C,D,E | Default `local_only`; explicit opt-in + coarse zone polygon generalization. |
| 7. Community-Guideline Hit Moderation & Regulatory Portal (1 flag/user/sample, auto-hide, private hits, consent/retention/thresholded summaries) | API & Web | Flag: A,B,C,D; Review: A,B,C; Portal: A,B,C,D,E | Private hits only; zero public reputation scores; simple uphold/restore review queue. |
| 8. System Configuration, Governance & Backups (settings/analytics for B; server overrides/backups for A) | API & Web | A,B | Essential operational controls only; leverage Supabase managed backups. |

---

## 7. Confirmed MVP Governance Defaults & Data Contracts

| Parameter | Confirmed Value | Rationale |
| --- | --- | --- |
| **QR payload contract** | `AP1\|<sample_uuid>\|<crop_code>\|<YYYY-MM-DD>` + human-readable label text below QR | Compact, versioned (`AP1`), zero-PII/zero-GPS, fast to scan in low light, and manually searchable if a physical tag gets muddy or torn. |
| **Crop codes** | `CAS` (Cassava), `SWP` (Sweet Potato), `TAR` (Taro), `YAM` (Yam) | Keeps QR payloads, file names, and per-crop CSV/JSON exports unambiguous. |
| **Minimum sample aggregation threshold (`k`)** | `k >= 5` samples per `(crop_type, coarse_zone)` | Prevents re-identification in low-density zones while keeping regional summaries attainable early. |
| **Auto-hide flag threshold** | `3` distinct authenticated flags per `sample_uuid` (max `1` flag/user/sample) | Blocks single-user griefing while quickly hiding obvious misclassifications. |
| **Private guideline hit escalation** | `3` confirmed hits → temporary publishing review hold (private only) | Protects dataset quality without public shaming or reputation scores. |
| **Transient draft retention window** | `30 days` for unsynced local drafts (warn at day 25); `7 days` for unverified server staging records | Enforces Data Privacy Act storage limitation without surprising active field researchers. |
| **Missing / unobservable trait code** | `NA` in CSV / `null` in JSON | Standard missing-value convention for R, STAR, and Weka; enables safe multi-stage logging (foliage now, roots at harvest). |
| **Coarse geographic zone unit** | Municipality/city-level polygon or standardized coarse grid cell | Preserves agronomic relevance across local zones without exposing farm plot pins. |
| **Backend API runtime (`agora-ping-api`)** | TypeScript (Node/Edge API) | Shares Zod/TypeScript schemas with Next.js (`agora-ping-web`) and Supabase SDK for fastest TTM. |

---

## 8. Explicit Non-Goals (Out of Scope for v1.1 MVP)

To protect time-to-market, the following are deliberately excluded from MVP:
- **No crop photo capture/upload, image storage, or AI/ML classification** (camera permission is strictly limited to offline QR specimen scanning; coded morphological descriptors are the MVP core).
- **No custom Bluetooth/thermal printer SDKs or hardware drivers** (all PNG/PDF label output uses Android's native share/print sheet).
- **No in-app statistical analysis engine** (ANOVA, PCA, clustering stay in R, Weka, and STAR).
- **No social features** (no comments, direct messaging, likes, follows, or public user profiles/reputation scores).
- **No monetary or gamified incentives** (no cash, credits, points, badges, or leaderboards).
- **No multi-device real-time draft sync or CRDTs** (each field session lives on one device until opted-in specimens are synced).
- **No iOS or desktop native apps** (strictly Android + Web).

---

## 9. MVP Readiness Criteria

The v1.1 MVP is ready for `beta` QA when all seven checks pass:
1. A fresh install of `agora-ping-android` in airplane mode logs 10 mixed-crop specimens (`CAS`, `SWP`, `TAR`, `YAM`) in one continuous session, including at least one skipped (`NA`) trait and one edited draft.
2. Completing a specimen offline generates a scannable `AP1` QR code (`sample_uuid`, crop code, date — zero PII/GPS) with human-readable fallback text, exports both a single label (PNG/PDF) and a session label sheet (PDF) via Android's native share/print sheet, and scanning the tag offline retrieves and updates the exact specimen record (while unknown tags show a clear graceful fallback).
3. Offline export produces clean per-crop CSV/JSON files + `deck_version` codebook that load into R/STAR/Weka with zero manual column or code cleaning.
4. Opting in and reconnecting syncs queued `sample_uuid` records (and owner scan-to-update revisions) idempotently with zero duplicates, storing only coarse zone polygons with zero raw plot coordinates in Supabase or logs.
5. Regional trait summaries suppress any `(crop_type, coarse_zone)` bucket with `< 5` samples and render once `>= 5` samples exist.
6. Submitting 3 distinct peer flags auto-hides the specimen from Explorer, logs a private guideline hit, exposes zero reputation fields in API responses, and lets `C. Community Reviewer` uphold or restore it.
7. A contributor can view privacy disclosures, check retention schedules, and withdraw/delete an opted-in synced sample from the portal.

---

## 10. Notes

- **Changelog from v1.0:** Added bundled `v1.0` core trait deck for Day-1 offline installs, `session_uuid` & local draft edit/delete, `NA`/`null` skip encoding, `deck_version` export codebook + CSV formula-injection guard, versioned `AP1` QR payload + human-readable fallback + session PDF label sheets + graceful unknown-tag handling, owner `revision` idempotent upsert semantics, confirmed governance constants (`k >= 5`, `3` flags, `3` private hits, `30d`/`7d` retention, `AP` short code, TypeScript API), explicit Non-Goals, and MVP Readiness Criteria.
