# 08 — API

**Purpose:** HTTP/API contract conventions, response envelope, planned capability surface with auth/RBAC requirements, validators, and versioning rules for `agora-ping-api`.

**Confidence note:** verified against approved `agora-ping-specs/business-logic-v1.1.md` on 2026-11-22. **No server code or HTTP routes exist in `agora-ping-api` yet.** Confirmed runtime (`TypeScript`), capability surface, and thresholds below are verified from `business-logic-v1.1.md` and `git-guidelines.md`. The code wins (see 16 #7).

---

## Current Status

- **Server runtime / framework:** **TypeScript** (Node/Edge API; shares Zod/TS schemas with Next.js and Supabase SDK).
- **Response envelope & error codes:** TBD (lockstep across `agora-ping-api`, `agora-ping-web`, and `agora-ping-android` once scaffolded).
- **Implemented routes & validators:** None (0 endpoints exist).

---

## Planned API Capability Surface (Verified from `business-logic-v1.1.md`)

| Capability | Clients | Allowed Roles | Key Contract Rules |
|---|---|---|---|
| **Authentication (Google Sign-In)** | Web, Android | `A`–`D` (unauth → `E. Guest`) | Verify Google ID tokens server-side; never trust client-supplied user IDs or roles (see 09). |
| **Official Guide Descriptor Decks** | Android (cache sync), Web (labels/filters) | Read: `A,B,C,D,E`; Manage: `A,B` | Serve immutable versioned trait decks (`CAS`, `SWP`, `TAR`, `YAM`; ordered by foliage, stem/vine, storage root/corm) with categorical choices, numeric research codes, and validation ranges (see 04 #6). |
| **Offline-to-Online Sample Sync** | Android → API → Supabase | `A,B,C,D` | Idempotent upsert keyed by `sample_uuid` + owner `revision` / `updated_at`; validate against recorded `deck_version`; accept `null` for skipped (`NA`) traits; require explicit opt-in consent; generalize exact plot coordinates to coarse zone polygons; strip movement paths; support owner withdrawal/deletion. |
| **Zone-Pinned Sample Explorer** | Web, Android | `A,B,C,D,E` | Filter shared samples by crop code/type, trait profile, and coarse geographic zone; exclude auto-hidden flagged samples; support read-only QR lookup by `sample_uuid` when online. |
| **Community-Guideline Hit Moderation** | Web, Android (flag) / Web (review) | Flag: `A,B,C,D`; Review/Override: `A,B,C` | Enforce max `1` flag/user/`sample_uuid`; `3` distinct flags auto-hide sample and record private hit; `3` confirmed hits trigger private publishing review hold; **never return public user reputation scores**. |
| **Regulatory & Aggregated Trait Portal** | Web | `A,B,C,D,E` (admin config: `A,B`) | Serve privacy disclosures, consent/withdrawal controls, retention schedules (`30d` local / `7d` server staging), and regional trait averages gated by `k >= 5` samples per `(crop_type, coarse_zone)`. |

---

## Versioning & Breaking-Change Rules

- **Breaking changes (`git-guidelines.md` lines 222–231):** Append `!` after the commit scope (`agora-ping-api/<feature>:! ...`) and include a `BREAKING CHANGE:` trailer naming the affected endpoint and client migration path.
- *Miss →* Because `agora-ping-android` has offline-queued records and slower client update cycles, unannounced breaking API changes strand unsynced field samples on enumerator devices (see 01, 10).

---

## Checklist When Adding the First Endpoints

Once `agora-ping-api` is scaffolded, replace the TBD stubs above with:
1. Exact JSON response & validation error envelope.
2. Concrete route inventory table (`Method`, `Path`, `Roles`, `Idempotency`, `Privacy/Threshold Guard`).
3. Standardized trait descriptor schema validator (shared with Android's offline CSV/JSON formatter so online and offline encodings never diverge — add as a new lockstep set in `04_CHANGE_RULES.md`).
4. API versioning strategy (`/v1/...` or header-based).
