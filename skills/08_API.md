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
| **Offline-to-Online Sample Sync** | Android → API → Supabase | `A,B,C,D` | Wrap `field_session` + `sample` + `sample_trait_value` + `consent_record` in one DB transaction with LWW `WHERE` gating (`db-design-choices.md` §6); stamp `created_by` from verified session; check `account.publishing_hold_until` (route held accounts to review/staging); generalize exact plot coordinates to `zone_uuid` in memory; promote completed valid batches from `staging` → `verified` (DB trigger verifies deck/trait alignment); support owner consent withdrawal. |
| **Zone-Pinned Sample Explorer** | Web, Android | `A,B,C,D,E` | Read via `v_explorer_sample` / `v_explorer_sample_trait` (verified, non-expired, opted-in, visible/restored only); filter by crop code/type, trait profile, deck version, and coarse zone; support read-only QR lookup by `sample_uuid` when online. |
| **Community-Guideline Hit Moderation** | Web, Android (flag) / Web (review) | Flag: `A,B,C,D`; Review/Override: `A,B,C` | Stamp `flagged_by` / `reviewed_by` server-side; DB enforces max `1` flag/user/`sample_uuid`, blocks self-flagging, auto-hides at `3` distinct flags, creates private `guideline_hit`, and sets `publishing_hold_until` at `3` confirmed hits; **never return public user reputation scores or `flag_count`**. |
| **Regulatory & Aggregated Trait Portal** | Web | `A,B,C,D,E` (admin config: `A,B`) | Serve disclosures via `v_public_privacy_disclosure` (`effective_at <= now()`); expose consent withdrawal endpoints; serve summaries via `v_regional_trait_summary` (grouped by immutable deck/descriptor/unit with per-trait `k >= 5`); schedule periodic `cleanup_expired_staging()` execution via `service_role`. |

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
