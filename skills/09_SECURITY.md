# 09 — Security

**Purpose:** Threat model, authentication, authorization layers, mandatory privacy & non-monetary controls, secrets handling, and security checklist for changes.

**Confidence note:** verified against updated `agora-ping-specs/business-logic-v1.0.md` on 2026-11-22. No runtime security controls exist yet; requirements below are verified from `business-logic-v1.0.md` and `handoff.md`. The code wins (see 16 #7).

---

## Threat Model (Baseline — Derived from `business-logic-v1.0.md`)

`agora-ping` combines offline Android field data collection, community data sharing, Supabase persistence, and public Guest access. Primary threat classes:

1. **Location & trail re-identification:** Syncing raw farm/field GPS coordinates or sequential enumerator locations enables tracking researchers or growers.
2. **Small-bucket deanonymization:** Returning regional trait summaries with too few samples exposes individual submissions.
3. **Privilege escalation:** `E. Guest` or `D. Field Researcher` invoking `C. Community Reviewer`, `B. Administrator`, or `A. System Administrator` endpoints (or reading private guideline hits).
4. **Auth token spoofing:** Accepting unverified Google Sign-In claims from clients instead of verifying tokens server-side in `agora-ping-api`.
5. **Malicious/noisy trait poisoning or flag abuse:** Coordinated flagging or malformed trait uploads corrupting shared datasets without threshold moderation.
6. **Secret leakage across 4 repos:** Committing Supabase service-role keys, Google OAuth secrets, or Android signing keystores to `kindocarloo/agora-ping-*`.

---

## Authentication & Authorization Layers

- **Authentication:** Google Sign-In integration (`business-logic-v1.0.md`) for online sync, publishing, flagging, and admin actions. Offline field logging and local CSV/JSON export on Android require zero internet dependency.
  - *Rule:* `agora-ping-api` must verify Google ID tokens (`signature`, `aud`, `iss`, `exp`) server-side. *Miss →* Forged identities bypass consent and moderation controls.
- **Authorization (5-tier RBAC, deny-by-default):**
  - `A. System Administrator` — Server/infrastructure config overrides (Supabase/API) and regular backups.
  - `B. Administrator` — General settings, retention schedules, periodic regional analytics/reports.
  - `C. Community Reviewer / Moderator` — Automated threshold rule engine + human reviewer processing community-guideline flags.
  - `D. Field Researcher / Enumerator` — Offline trait logging/export, opted-in sync/publish, sample exploration, peer flagging.
  - `E. Guest` — Unauthenticated read-only access to privacy disclosures, retention schedules, threshold-gated summaries, and public anonymized previews.

---

## Mandatory Privacy & Governance Controls (Verified from `business-logic-v1.1.md`)

1. **Data Privacy Act compliance** — Minimize personal data collected and publish clear disclosures on the Web portal.
2. **Coarse zone polygon location protection & zero-PII `AP1` QR tags** — Generalize exact plot coordinates to coarse zone polygons (municipality/city-level or coarse grid cell) upon sync; never persist/log exact pins; encode only `AP1|<sample_uuid>|<crop_code>|<YYYY-MM-DD>` (zero PII/GPS) inside printed QR labels (see 04 #7).
3. **No per-user trails** — Never track, store, or log enumerator movement paths.
4. **Retention limits** — Auto-expire unsynced local drafts after **30 days** (warn at day 25) and unverified transient server staging records after **7 days**.
5. **Minimum sample aggregation threshold (`k >= 5`) & statistical isolation** — `system_setting` rejects `min_aggregation_k < 5` or non-integers, `effective_min_aggregation_k()` enforces a hard `GREATEST(5, ...)` floor, and `v_regional_trait_summary` requires `>= k` distinct verified contributing specimens with real non-null values per immutable `(crop_code, zone_uuid, trait_deck_uuid, trait_descriptor_uuid)` group (`v1.0.1.sql`).
6. **Explicit opt-in & revocable consent** — Default `local_only`; require explicit opt-in before online sharing, public dataset inclusion, or data resale; revoking `community_share` in `consent_record` automatically propagates `consent_status = 'withdrawn'` to `sample` (`v1.0.1.sql`).
7. **Private guideline hits & PostgREST lockdown** — Direct base-table access and maintenance RPCs (`cleanup_expired_staging`) are revoked from `PUBLIC`/`anon`/`authenticated`; public PostgREST reads use only column-safe views (`v_public_*`, `v_explorer_*`, `v_regional_trait_summary`) that omit server `id`, `created_by`, drafts, unverified/expired staging rows, and moderation hits (`v1.0.1.sql`). Max `1` flag/user/`sample_uuid`, self-flag blocked, `3` distinct flags auto-hide, `3` confirmed hits set private `publishing_hold_until`.
8. **Zero financial bait** — No cash, credits, points, badges, or convertible rewards.

---

## Secrets Handling

- **Never commit secrets** to any of the four repos or include values in `skills/` (`handoff.md` line 29). Name environment variables only.
- **Anticipated secret boundaries (env var names TBD on scaffold):** Supabase service-role key (server-only in `agora-ping-api`, never shipped in `agora-ping-web` or `agora-ping-android`), Google OAuth client secrets, Android release signing keystore.

---

## Injection Surfaces, Debug Gates, and Accepted Gaps

- **Injection surfaces & debug gates:** None yet (no application code). Watch CSV formula injection on local Android CSV exports (`=`, `+`, `-`, `@` cells opened in spreadsheets) when implementing export!
- **Accepted gaps (current state):** No CI secret scanning, branch protection, or automated security tests exist yet (see 15 #6).

---

## Security Change Checklist

1. Does every new endpoint enforce its exact role set (`A`–`E`) server-side?
2. Are exact coordinates generalized to coarse zone polygons before online persistence, with zero per-user trails in DB or logs?
3. Are regional summaries gated by minimum sample aggregation thresholds?
4. Do unsynced/unverified drafts enforce fixed retention auto-expiry, and does online sync require explicit opt-in consent?
5. Are moderation hits kept strictly private (zero public reputation fields in API responses)?
6. Are Supabase service keys and OAuth secrets absent from client bundles and git diffs?
