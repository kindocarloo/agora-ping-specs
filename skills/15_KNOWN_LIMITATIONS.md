# 15 — Known Limitations

**Purpose:** Honest inventory of drift, remaining spec gaps, architectural constraints, security weaknesses, and redesign candidates — ordered by how likely they are to surprise an engineer today.

**Confidence note:** verified against approved `agora-ping-specs/business-logic-v1.1.md`, customized `agora-ping-specs/git-guidelines.md` (`AP`), and pushed `main` branches across all 4 repos on 2026-11-22. Every item below was directly verified on disk. The code wins (see 16 #7).

---

## Gaps Ordered by Surprise Likelihood

### #2 Remaining `<Team Name>` Placeholder in `business-logic-v1.1.md` (Minor Spec Gap — Verified)
- **What:** `business-logic-v1.1.md` confirms the full MVP scope, stack (Kotlin, Next.js, TypeScript API, Supabase), `AP` short code, `AP1` QR contract, and numeric governance constants (`k >= 5`, `3` flags, `3` private hits, `30d`/`7d` retention), leaving only `<Team Name>` to confirm before external launch/disclosures.
- **Why it surprises:** Regulatory/privacy disclosure pages on `agora-ping-web` need the real legal/team entity name before public launch.

### #3 Zero Application Code, Schemas, Tests, or CI Across `api`, `web`, and `android` (Bootstrap State — Verified)
- **What:** All four repos have initial commits pushed to `origin/main` (`api` `6578b62`, `web` `c7121f4`, `android` `c0b6e4b`, `specs` `dc3507f`), but the three runtime repos contain only `AGENTS.md` — no Kotlin, Next.js, TypeScript API, Supabase migrations, bundled `v1.0` core trait deck JSON, tests, or CI workflows exist yet.
- **Why it surprises:** No build or test commands exist to run until scaffolding lands (see 11).

### #4 Five Byte-Identical Placeholder `AGENTS.md` Files (Drift / Maintenance Risk — Verified)
- **What:** Root `AGENTS.md` and all four sub-repo `AGENTS.md` files still contain the exact same 9-line template pointing to sibling globs (`*-specs/skills/*.md`, etc.).
- **Why it surprises:** Opening a single sub-repo standalone breaks sibling globs (see 04 #2, 05 #3), and each repo lacks Kotlin/Next.js/TypeScript-API/Supabase build and test instructions.

### #6 No Automated Enforcement of Git, Privacy, or Security Rules (Security / Governance Weakness — Verified)
- **What:** No `.git/hooks`, commit-message linter, secret scanner, AI-author rejection hook, or verified GitHub branch protection on `main`/`beta`/`release`.
- **Why it surprises:** Commit formatting, AI-author exclusion, and branch promotion gates rely purely on manual discipline (see 03, 09, 10).

---

## Ranked Redesign / Cleanup Candidates

| Rank | Candidate | Trigger to Act |
|---|---|---|
| 1 | Author canonical `v1.0` core descriptor deck JSON (`CAS`, `SWP`, `TAR`, `YAM`, 10–15 traits/crop) and scaffold `api`, `web`, and `android` | Next implementation milestone |
| 2 | Split `AGENTS.md` per repo with Kotlin / Next.js / TypeScript-API / Supabase build & test commands | As soon as each repo is scaffolded |
| 3 | Add commit-msg / pre-commit hooks or GitHub Actions to enforce `scope: Summary`, no secrets, and no AI author | Before multiple contributors push to `main` |
| 4 | Confirm `<Team Name>` in `business-logic-v1.1.md` and consider versioning workspace root `AGENTS.md` / `handoff.md` in `agora-ping-specs/` | Before external launch / onboarding |

---

## Retired

### #1 Template Drift & Naming Conflict in `agora-ping-specs/git-guidelines.md`
- **Superseded (2026-11-22):** Resolved upon promotion of `business-logic-v1.1.md`. `git-guidelines.md` now uses `agora-ping`, short code `AP`, prefixes `WAP`/`BAP`/`AAP`/`SAP`, standardized `agora-ping-android:` scopes, domain feature scopes, and clean release-tag tables with stale 2026 template dates removed (see 04 #1, 06 #1). Kept here so nobody reintroduces `code-name-app` or `CN` placeholders.

### #5 Missing Environmental Scan (`agora-ping-specs/planning/sense-making.csv`)
- **Superseded (2026-11-22):** Completed against `business-logic-v1.1.md` — 21 verified STEEPLE findings (3 per factor) saved to `agora-ping-specs/planning/sense-making.csv` and summarized in `agora-ping-specs/planning/sense-making.md` (see 04 #5).
