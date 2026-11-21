# Business Logic v1.0 — agora-ping

> Development of an Android and Web-based Offline-First Root Crop Trait Characterization and Community Data-Sharing Platform using Kotlin, Next.js, and Supabase for Root Crop Researchers and Agricultural Communities

- Allowed Platforms: Web, Android

## Project Details

- Company/Startup/Team Name: `<Team Name>`
- Project Code Name: `agora-ping`
- Project Short Code: `<short-code>`
- Short Description: Offline-first sequential Android field wizard for root crop trait characterization and Web/Android community data-sharing platform for researchers and agricultural communities.
- Long Description: Field characterization of root crops relies on standardized morphological and agronomic guides, yet manual paper recording forces researchers to spend hours encoding categorical traits before statistical analysis. **agora-ping** streamlines this through an **offline sequential field wizard** that guides enumerators crop-by-crop and part-by-part using official descriptor choices—automatically encoding each specimen into analysis-ready tables—paired with an **online community platform** where anonymized crop samples are shared across zones.

## User Levels

> Note: Modify/rename the list of users based on the actual users that you expect to use the system.

| User Level | Description |
| --- | --- |
| A. System Administrator | Maintains/overrides system/server configurations, manages Supabase/API infrastructure and official descriptor deck deployments, and performs regular backups. |
| B. Administrator | Manages general system settings, versioned trait deck governance, retention schedules, and generates periodic regional trait analytics and reports gated by minimum sample aggregation thresholds. |
| C. Community Reviewer / Moderator | Automated threshold handler and human moderator that process community-guideline flags on inaccurate entries and enforce privacy/retention policies without displaying public user reputation scores. |
| D. Field Researcher / Enumerator | Conducts offline specimen-by-specimen trait logging in the field, exports coded per-crop datasets locally for statistical tools (R, Weka, STAR), optionally publishes opted-in anonymized samples online, explores shared samples, and flags misclassified specimens. |
| E. Guest | Users who do not log in, but view limited public content on the app/web (such as privacy disclosures, retention schedules, threshold-gated regional trait averages/summaries, and public anonymized sample previews). |

## System Requirements

1. The app shall allow users to authenticate using Google Sign-In integration for online sync, publishing, flagging, and administrative actions, while keeping offline field characterization, QR specimen labeling/scanning, and local dataset export 100% functional with zero internet dependency.
2. The Android app and Supabase backend shall provide an **Official Guide Descriptor Engine** storing structured, versioned trait decks for multiple root crops (Cassava, Sweet Potato, Taro, Yam) ordered by plant part (foliage, stem/vine, storage root/corm) with standardized categorical choices and numeric research codes.
3. The Android app shall provide a **Sequential One-by-One Trait Wizard** that guides the user through identifying the crop type first, then presents one plant part and morphological/agronomic trait per screen with official multiple-choice options and range-validated numeric fields.
4. The Android app shall provide an **Offline QR Specimen Label Generator & Scanner** that automatically generates an offline QR code encoding the specimen's `sample_uuid`, crop code, and date upon completion—exportable as a printable PNG/PDF label via Android's native share/print sheet—and allows scanning tags to retrieve or update specimen records.
5. The Android app shall provide a **Continuous Multi-Specimen Loop** that commits each completed specimen locally and returns immediately to crop-type selection so researchers can log and label mixed root crop specimens consecutively within a single field session.
6. The Android app shall perform **Automated Statistical Encoding & Local Export** by automatically mapping selected choices to standard numeric research codes and exporting clean, per-crop CSV/JSON tables ready for immediate offline import into R, Weka, or STAR.
7. The platform shall support **Offline-to-Online Sample Sync & Zone Explorer** (`Android` -> `API` -> `Supabase` & `Web`), syncing opted-in samples via `*_uuid` keys once online and letting users filter community samples by crop type, trait profile, and coarse geographic zone.
8. The API and Web app shall implement **Community-Guideline Hit Moderation & Regulatory Portal**, enabling peers to flag misclassified specimens (issuing private guideline hits rather than public reputation scores) while hosting privacy disclosures, consent controls, retention limits, and threshold-gated regional trait averages/summaries on the web.

## Required Solution Layers

1. **Security and privacy by design (Data Privacy Act compliance):**
   - **Location protection & no per-user trails:** Exact plot coordinates are generalized to coarse zone polygons upon sync, and enumerator movement paths are never tracked or stored.
   - **Retention limits:** Unsynced local drafts or unverified transient entries follow defined retention limits.
   - **Aggregation thresholds:** Regional trait averages and summaries display only after meeting minimum sample aggregation thresholds.
   - **Explicit consent:** Explicit opt-in consent is required before any sample is shared online, included in public datasets, or used for any data resale.
2. **Non-monetary incentive model (Zero Financial Bait):**
   - No cash, credits, or convertible rewards; user motivation is strictly faster research data preparation and shared agronomic knowledge.

## MVP Features and Access

> See the User Levels table for reference.

| Feature | Platform | Access |
| --- | --- | --- |
| 1. Official Guide Descriptor Engine (versioned trait decks for Cassava, Sweet Potato, Taro, Yam ordered by plant part with standardized categorical choices & numeric research codes) | Android & Supabase | A,B,C,D,E *(manage/version: A,B; read/use: A,B,C,D,E)* |
| 2. Sequential One-by-One Trait Wizard (crop-type selection first, then one plant part & trait per screen with official choices and range-validated numeric inputs) | Android | A,B,C,D |
| 3. Offline QR Specimen Label Generator & Scanner (offline QR encoding `sample_uuid`, crop code, and date; exportable as printable PNG/PDF via Android native share/print sheet; scan tags to retrieve or update records) | Android | A,B,C,D |
| 4. Continuous Multi-Specimen Loop (local commit and immediate return to crop-type selection so researchers can log and label mixed root crop specimens consecutively in one field session) | Android | A,B,C,D |
| 5. Automated Statistical Encoding & Local Export (auto-map selections to standard numeric research codes; export clean per-crop CSV/JSON tables offline for R, Weka, STAR) | Android | A,B,C,D |
| 6. Offline-to-Online Sample Sync & Zone Explorer (sync opted-in samples via `*_uuid` keys; filter community samples by crop type, trait profile, and coarse geographic zone) | Android -> API -> Supabase & Web | Sync: A,B,C,D; Explorer: A,B,C,D,E |
| 7. Community-Guideline Hit Moderation & Regulatory Portal (peer flagging with private guideline hits, no public reputation scores, privacy disclosures, consent controls, retention limits, threshold-gated regional summaries) | API & Web | Flag: A,B,C,D; Review: A,B,C; Portal: A,B,C,D,E |
| 8. System Configuration, Governance & Backups (general settings/analytics for B; server overrides and backups for A) | API & Web | A,B |

## Notes

- **Tech Stack:** Kotlin (`agora-ping-android`), Next.js (`agora-ping-web`), Backend API (`agora-ping-api`), and Supabase (database/backend data layer).
- **Target Root Crops & Plant-Part Ordering:** Cassava, Sweet Potato, Taro, and Yam; trait decks ordered by plant part (`foliage`, `stem/vine`, `storage root/corm`) with standardized categorical choices and numeric research codes.
- **Offline Sync Identity:** Each completed specimen receives a locally generated `sample_uuid` (and related `*_uuid` keys) for conflict-safe offline logging and idempotent sync.
- **Moderation Philosophy:** Automated threshold rule engine + human reviewers process peer flags using private guideline hits only; never expose public user reputation scores.
- **Zero Financial Bait:** No cash, credits, or convertible rewards anywhere in the platform.
