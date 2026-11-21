# 07 — Database

**Purpose:** Data modeling rules, `*_uuid` identity strategy, privacy invariants, migration policy, and dangerous database operations for Supabase and Android offline storage.

**Confidence note:** verified against approved `agora-ping-specs/business-logic-v1.1.md` on 2026-11-22. **No schema migrations or SQL files exist in `agora-ping-api` or `agora-ping-android` yet.** Confirmed identity, versioning, and governance constants below are verified from `business-logic-v1.1.md`. The code wins (see 16 #7).

---

## Current Status

- **Backend database platform:** **Supabase** (Postgres-based; confirmed in `business-logic-v1.0.md`).
- **Offline client storage (`agora-ping-android`):** Local offline store (exact Kotlin persistence library e.g., Room/SQLDelight TBD) queuing opted-in samples and holding transient drafts.
- **Tables, migrations, constraints, and indexes:** None yet (0 schema files exist).

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
