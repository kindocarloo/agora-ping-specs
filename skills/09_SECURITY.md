# 09 — Security

**Purpose:** Threat model, authentication, authorization layers, mandatory privacy controls, secrets handling, and security checklist for changes.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. No runtime security controls exist yet; requirements below are verified from `agora-ping-specs/business-logic-v1.0.md` and `handoff.md`. The code wins (see 16 #7).

---

## Threat Model (Baseline — Inferred from Platform & Specs)

`agora-ping-ecosystem` will expose a public API to Web and Android clients with five user tiers (including unauthenticated Guests) and privacy-sensitive data (including location/activity data). Primary threat classes:

1. **Privilege escalation:** Guest (`E`), Contributor (`D`), or Moderator (`C`) invoking Administrator (`B`) or System Administrator (`A`) endpoints.
2. **Privacy & re-identification leaks:** Persisting or exposing raw location traces, per-user trails, or small-bucket analytics that violate Data Privacy Act requirements (`business-logic-v1.0.md` line 39).
3. **Auth token spoofing:** Trusting client-claimed email/user IDs instead of verifying Google Sign-In ID tokens server-side.
4. **Secret leakage across 4 repos:** Committing OAuth client secrets, signing keystores, DB credentials, or API keys into any of the four GitHub repos (`kindocarloo/agora-ping-*`).

---

## Authentication & Authorization Layers

- **Authentication (Verified requirement):** Google Sign-In integration (`business-logic-v1.0.md` line 29). Implementation TBD.
  - *Rule:* `agora-ping-api` must verify Google ID tokens (signature, `aud` client ID, `iss`, `exp`) on the server. *Miss →* Forged tokens grant arbitrary account takeover.
- **Authorization (Verified role skeleton):** Five-tier RBAC (`A`–`E` in `business-logic-v1.0.md` lines 19–25):
  - `A. System Administrator` — System/server configuration overrides, backups.
  - `B. Administrator` — General settings, periodic analytics/reports.
  - `C. Moderator` — TBD.
  - `D. Contributor` — TBD.
  - `E. Guest` — Unauthenticated, limited public views only.
  - *Rule:* Enforce role checks on every API route by default (deny-by-default; explicitly opt in `E. Guest`). *Miss →* New endpoints default to public access.

---

## Mandatory Privacy-by-Design Controls (Verified from `business-logic-v1.0.md` line 39)

1. **Data Privacy Act compliance** — Minimize personal data collected and document lawful basis.
2. **Location protection** — Fuzz, bucket, or strip precise coordinates before persistence or display.
3. **Retention limits** — Enforce automated expiration/deletion for personal and event records.
4. **No per-user trails** — Do not link sequential location/behavior records into a reconstructable per-user history in DBs or logs.
5. **Aggregation thresholds** — Enforce minimum group sizes before releasing aggregated metrics.
6. **Consent for any data resale** — Require explicit, revocable opt-in consent before any data is shared or resold.

---

## Secrets Handling

- **Never commit secrets** to any of the four repos or mention secret values in `agora-ping-specs/skills/` (`handoff.md` line 29). Name environment variables only.
- **Current secret inventory:** None yet (no `.env.example`, keystore config, or CI secrets exist). Add an env-var inventory table here (names and owners only, never values) as soon as the first repo introduces config.

---

## Injection Surfaces, Debug Gates, and Accepted Gaps

- **Injection surfaces & debug gates:** None yet (no application code). Populate once ORM/SQL, web rendering, Android intents/WebViews, and debug flags exist.
- **Accepted gaps (current bootstrap state):**
  - No automated secret scanning, branch protection, or CI security checks are configured yet (see 15 #6).
  - `C. Moderator` and `D. Contributor` permissions are undefined in `business-logic-v1.0.md` (see 15 #2).

---

## Security Change Checklist

Before merging any auth, data, or API change:
1. Does every new endpoint enforce its exact role set from `business-logic-v1.0.md` (`A`–`E`) server-side?
2. Does any new table, response, or log line accidentally create a per-user trail or leak raw location?
3. Does any new analytics query enforce an aggregation threshold?
4. Does any new personal/event table define a retention limit?
5. Are all credentials loaded from environment variables / secret stores with zero secrets in git diffs?
