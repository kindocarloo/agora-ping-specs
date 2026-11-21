# 07 — Database

**Purpose:** Data modeling rules, identity strategy, privacy invariants, migration policy, and dangerous database operations.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. **This document barely applies yet because no database engine, schema, or migrations exist in `agora-ping-api`.** Only the mandatory privacy/data invariants verified in `agora-ping-specs/business-logic-v1.0.md` are recorded below. Populate the remaining sections as soon as the first schema is designed. The code wins (see 16 #7).

---

## Current Status

- **Database engine:** TBD (not yet specified in `agora-ping-specs/business-logic-v1.0.md` or `agora-ping-api/`).
- **Tables & migrations:** None (0 files in `agora-ping-api/` aside from `AGENTS.md`).
- **Identity strategy / constraints / soft-delete / indexing:** TBD. *(Note: `git-guidelines.md` line 91 gives a generic example of soft-delete columns, but that is template boilerplate, not an adopted Agora Ping schema decision.)*

---

## Non-Negotiable Data Invariants (Verified from `business-logic-v1.0.md`)

Even before picking a database engine, every table and query must satisfy the Required Solution Layer (`agora-ping-specs/business-logic-v1.0.md` line 39):

| Invariant | Architectural Implication | What Breaks If Violated (*Miss →*) |
|---|---|---|
| **No per-user trails** | Do not store linkable time-series movement/activity histories tied to a persistent user ID | *Miss →* Direct violation of Data Privacy Act solution layer; requires destructive migration to remediate (see 09, 16 #3). |
| **Location protection** | Avoid storing raw high-precision user coordinates when coarse/anonymized/ephemeral spatial buckets suffice | *Miss →* Re-identification of individuals from home/work points. |
| **Retention limits** | Every table holding personal or operational event data must define a TTL / purge strategy at creation time | *Miss →* Unbounded personal data retention violates compliance and bloats storage. |
| **Aggregation thresholds** | Analytics views/queries exposed to `B. Administrator` (or external consumers) must suppress small buckets below a minimum `k`-anonymity / aggregation threshold | *Miss →* Small-group queries leak individual user records. |
| **Consent for any data resale** | Any dataset eligible for third-party/resale export requires an explicit, auditable user consent flag/record | *Miss →* Unlawful data resale under the Data Privacy Act. |
| **Regular backups** | `A. System Administrator` owns performing regular backups (`business-logic-v1.0.md` line 21) | *Miss →* Unrecoverable data loss; backup/restore scope is already reserved in `git-guidelines.md` line 71 (`backup`, `restore`). |

---

## Sections to Populate on First Migration

When the first database migration lands in `agora-ping-api/`, fill in:
1. Engine, connection pooling, and local dev setup (no secret values — env var names only).
2. Primary key / identity strategy (UUID vs auto-increment, user ID decoupling for privacy).
3. Table map with retention TTLs and PII classification.
4. Migration tool, forward-only vs rollback policy, and dangerous-operation checklist (table locks, non-null backfills, index builds).
