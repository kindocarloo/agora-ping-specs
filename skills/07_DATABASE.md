# 07 — Database

**Purpose:** Data modeling rules, `*_uuid` identity strategy, privacy invariants, migration policy, and dangerous database operations for Supabase and Android offline storage.

**Confidence note:** verified against `agora-ping-specs/db-schema/v1.0.0.sql`, forward migration `agora-ping-specs/db-schema/v1.0.1.sql`, `agora-ping-specs/db-design-choices.md`, and `agora-ping-specs/business-logic-v1.1.md` on 2026-11-22. Static SQL/trigger verification completed; live PostgreSQL test execution is pending because `psql`/`postgres`/`docker`/`supabase` are not installed locally (reproducible suite saved in `db-schema/tests/v1.0.1.test.sql`). The code wins (see 16 #7).

---

## Current Status

- **Backend database platform:** **Supabase PostgreSQL** — applied baseline `agora-ping-specs/db-schema/v1.0.0.sql` + hardening forward migration `agora-ping-specs/db-schema/v1.0.1.sql` (14 tables, 12 enums, 9 column-safe public views, published-deck/sync/moderation/retention triggers, base-table grant lockdown, bounded staging cleanup RPC, and MVP seed rows).
- **Offline client storage (`agora-ping-android`):** Local SQLite (same table/column names minus server `id` plus client-only `synchronized_at`, per `db-design-choices.md` §1, §6); Kotlin schema TBD.
- **Schema file versioning (`db-design-choices.md` §9):**
  - Forward migrations (dev/AI adds/alters tables): bump patch (`v1.0.0` → `v1.0.1` → `v1.0.2`); never edit an applied baseline.
  - Full SQL snapshots (exported from Supabase to local): bump minor (`v1.0.0` → `v1.1.0` → `v1.2.0`).

---

## Table & View Map (`db-schema/v1.0.0.sql` + `v1.0.1.sql`)

Every table carries server-only `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` (for indexing/arrival order only, never synced), global `uuid uuid NOT NULL UNIQUE`, attribution (`created_by`, `created_at`, `updated_at`), and soft-delete `archived_at`. Offline-synced tables use indexed `*_uuid` columns with **no declared `REFERENCES`** so out-of-order sync batches never fail (`db-design-choices.md` §3). Direct base-table privileges are revoked from `PUBLIC`/`anon`/`authenticated`; public PostgREST reads go exclusively through the `v_public_*` / `v_explorer_*` / `v_regional_trait_summary` views (`security_invoker = false`).

| Table / View | Role | Key Privacy / Integrity Guard (`v1.0.1`) |
|---|---|---|
| `account` | Authenticated users (`role` enum, private `publishing_hold_until`) | No public reputation score; 3 confirmed hits set private hold via trigger |
| `system_setting` | Feature-scoped governance rows (`feature`, `name`, `value`) | Write-time trigger rejects invalid values and `min_aggregation_k < 5`; helper enforces `GREATEST(5, ...)` |
| `zone` | Coarse geographic polygons (`polygon_geojson`) | Replaces exact farm coordinates upon sync |
| `crop` | Seeded root crops (`CAS`, `SWP`, `TAR`, `YAM`) | Live unique `code` |
| `trait_deck` | Versioned Official Guide decks (`published_at`, `retired_at`/`retired_by`) | Trigger blocks unpublishing/editing/deleting published decks; allows explicit retirement only |
| `trait_descriptor` | Ordered plant-part descriptors (`foliage`, `stem_vine`, `storage_root_corm`) | Validates BOTH `OLD` & `NEW` decks with `FOR SHARE` locking; blocks reparenting & orphans |
| `trait_option` | Categorical choices + numeric `research_code` | Locks `OLD` & `NEW` descriptors + ancestor decks (`FOR SHARE`); blocks published mutation |
| `field_session` | Lightweight `session_uuid` grouping + `staging_status` / `expires_at` | Enforces 7-day staging expiry; coarse `zone_uuid` only; immutable `created_by` |
| `sample` | Synced specimen (`sample_uuid`, `revision`, `staging_status`, `qr_payload`, `consent_status`, `moderation_status`) | Zero GPS columns; enforces 7-day staging expiry, non-regressing `revision`, immutable `created_by`, pre-revoked consent check, and deck/trait verification on `verified` |
| `sample_trait_value` | Coded/numeric trait rows (`is_skipped = true` → NULL/`NA`) | Validates descriptor snapshot, `input_type`, option code, numeric range, and deck match (preserving out-of-order arrival before `sample`) |
| `consent_record` | Opt-in & revocation log (`granted_at`, `revoked_at`, `revoked_by`) | Trigger auto-propagates `community_share` withdrawal to `sample.consent_status = 'withdrawn'` |
| `sample_flag` | Peer flags on misclassified/malformed specimens | Live unique `(sample_uuid, flagged_by)` (max 1/user); blocks self-flag; trigger updates `flag_count`, auto-hides at threshold, and issues private `guideline_hit` |
| `guideline_hit` | Strictly private moderation hits (`pending_review`/`confirmed`/`dismissed`) | RLS deny-by-default + revoked base-table grants; 3 confirmed hits set private account hold |
| `privacy_disclosure` | Versioned Web portal disclosures/retention notices | RLS & public view require `effective_at <= now()` |
| `v_public_*` (6 views) | Safe public catalog views (`crop`, `zone`, `trait_deck`, `trait_descriptor`, `trait_option`, `privacy_disclosure`) | Omit `id`/`created_by`/`published_by`/`retired_by`; enforce full published parent chain |
| `v_explorer_sample` & `v_explorer_sample_trait` | Public anonymized sample feed & trait-profile filter views | Require `staging_status = 'verified'`, non-expired, `opted_in`, `visible`/`restored`, published deck; omit `created_by` & moderation fields |
| `v_regional_trait_summary` | Regional trait averages & modal research codes | Groups strictly by immutable `(trait_deck_uuid, deck_version, trait_descriptor_uuid, input_type, unit)`; enforces `k >= 5` per distinct contributing specimen with real non-null values |

---

## DB vs. API Responsibility Boundary (`v1.0.1`)

- **Database enforces:** Published-deck immutability & concurrency locking, unbreakable `k >= 5` per-trait suppression & unit/deck isolation, base-table grant/RLS isolation, 7-day staging expiry cap & bounded tombstone cleanup (`cleanup_expired_staging()`), immutable `created_by`, non-regressing `revision`, consent-withdrawal propagation, self-flag prevention, flag-threshold auto-hide + private hit creation, 3-hit publishing hold, and descriptor/option/range/deck-match validation (preserving out-of-order arrival in `staging`).
- **API (`agora-ping-api`) enforces:** Google Sign-In ID token verification & server-side `created_by`/`flagged_by`/`reviewed_by` stamping, RBAC (`A`–`E`), in-memory GPS-to-coarse-zone generalization (discarding raw GPS before SQL), atomic transaction wrapping (`field_session` + `sample` + `sample_trait_value` + `consent_record`) with LWW `WHERE` gating (`db-design-choices.md` §6), transitioning completed batches from `staging` → `verified`, enforcing `account.publishing_hold_until` on new submissions, scheduling periodic `cleanup_expired_staging()` runs, and verifying exact `qr_payload` contents against `sample_uuid`/`crop_code`/`observed_date`.

---

## Identity & Versioning Strategy (Verified from `business-logic-v1.1.md`)

- **Client-generated `session_uuid` & `sample_uuid` (`*_uuid`) keys + `revision`:** Android groups field logging under `session_uuid` and commits each specimen locally with a `sample_uuid`, `deck_version`, sync state (`local_only` → `queued` → `synced` | `sync_failed`), and monotonic `revision` / `updated_at` so owner QR scan-to-update edits (e.g., adding harvest traits weeks later) upsert idempotently through `Android` → `API` → `Supabase`.
  - *Miss →* Sequential server IDs break offline multi-specimen sessions, retry idempotency, and physical QR tag linkage.
- **Versioned Official Guide Trait Decks & Crop Codes:** Immutable trait decks for `CAS` (Cassava), `SWP` (Sweet Potato), `TAR` (Taro), and `YAM` (Yam) ordered by plant part (`foliage`, `stem/vine`, `storage root/corm`), with standardized categorical choices, numeric research codes, and `NA`/`null` encoding for skipped/unobservable traits. Bundled `v1.0` core deck (10–15 descriptors/crop) ships inside the APK; newer versions sync from Supabase (see 04 #6).
  - *Miss →* Mutating a deck in place corrupts previously logged numeric research codes, and encoding skipped traits as `0` skews statistical averages.

---

## Non-Negotiable Data Invariants (Verified from `business-logic-v1.1.md`)

Every Supabase table, Android local table, and analytics view must enforce these confirmed rules from Day 1:

| Invariant | Confirmed Rule / Implication | What Breaks If Violated (*Miss →*) |
|---|---|---|
| **Location generalization** | Convert exact **plot coordinates** into **coarse zone polygons** (municipality/city-level or coarse grid cell) upon sync; never persist or log raw exact coordinates | *Miss →* Re-identifies farms/enumerators and violates Data Privacy Act location protection (see 09, 16 #3). |
| **No per-user trails** | Never store linkable enumerator movement paths or location histories tied to a persistent user ID | *Miss →* Direct privacy violation requiring destructive schema migration. |
| **Retention limits** | **30 days** for unsynced local drafts (warn at day 25); **7 days** for unverified server staging records | *Miss →* Stale personal/unverified field data accumulates indefinitely. |
| **Aggregation thresholds** | **`k >= 5`** samples per `(crop_type, coarse_zone)` required before displaying regional trait averages/summaries | *Miss →* Small-group queries leak individual submissions. |
| **Explicit opt-in & revocable consent** | Default `local_only`; require explicit opt-in before online sync/public dataset/resale, and support contributor sample withdrawal/deletion | *Miss →* Unconsented publication or Data Privacy Act revocation failure. |
| **Private guideline hits only** | `3` distinct peer flags (max `1`/user/sample) auto-hide the sample and log a private hit; `3` confirmed hits trigger a private review hold — **never** public reputation scores | *Miss →* Violates non-reputation governance and introduces gaming/harassment incentives. |
| **Regular backups** | `A. System Administrator` owns regular backups (leveraging Supabase managed backups) | *Miss →* Unrecoverable loss of community agronomic datasets. |

---

## Sections to Populate on First Migration

When the first Supabase migration lands in `agora-ping-api/` (and local DB schema lands in `agora-ping-android/`), add:
1. Exact Supabase migration tool, RLS policies, and local dev commands (env var names only, never values).
2. Table map (crop samples, trait descriptors, zone polygons, moderation flags/hits, consent records, retention schedules) with retention TTLs and PII classification.
3. Hard-delete vs soft-delete rules (especially for hidden flagged samples vs expired drafts).
4. Dangerous-operation checklist (table locks, backfill safety, index creation).
