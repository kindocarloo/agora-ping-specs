# 10 — Deployment

**Purpose:** Maturity-based branch promotion flow, release tagging rules, cross-component release order, and release checklist.

**Confidence note:** verified against approved `agora-ping-specs/business-logic-v1.1.md` and customized `agora-ping-specs/git-guidelines.md` (`AP` / `WAP`, `BAP`, `AAP`, `SAP`) on 2026-11-22. Branching and tagging governance is verified from `git-guidelines.md` (Part 2); hosting/CI/CD pipelines do not exist yet. The code wins (see 16 #7).

---

## Release Order Across Components (Inferred Baseline)

No live infrastructure exists yet. Once deployables exist, ship in backward-compatible order:

1. **`agora-ping-specs`** — Approve spec/contract baseline (`S<SC>.0X.Y.00Z`).
2. **`agora-ping-api`** — Deploy database migrations and backward-compatible API changes (`B<SC>.0X.Y.00Z`) before clients call new endpoints.
3. **`agora-ping-web`** — Deploy web frontend (`W<SC>.0X.Y.00Z`).
4. **`agora-ping-android`** — Publish Android release bundle (`A<SC>.0X.Y.00Z`), keeping API backward compatibility for older installed app versions.

*Miss →* Deploying Web or Android before `agora-ping-api` causes client runtime failures on missing routes/fields.

---

## Branching and Promotion Model (Verified from `git-guidelines.md` lines 284–340)

Every repository follows a strict maturity-based promotion pipeline:

```text
main (Development / Unit Testing)
  → beta (QA / System Testing)
    → release (Published Bundles / Independent Integration Testing: a → b → rc)
      → Production (Separate Final Approval)
```

- **`main`:** Ongoing development and developer unit testing. Never sent to independent integration testers.
- **`beta`:** QA validates major product claims and stabilizes the build. Promotion to `release` is gated on QA acceptance.
- **`release`:** Controlled release-testing branch. Promoted code is bundled and published to the release website for independent integration testing. Presence on `release` does **not** mean production approval.
- **Production:** Deploy the exact approved `rc` candidate.
- **Post-production maintenance (`git-guidelines.md` lines 365–390):** Do **not** reopen `a`/`b`/`rc` for an already-deployed release. Escalate Tier 1 → Tier 2 → Tier 3 → Sustaining team, open a maintenance branch from the production baseline, increment `Y`, reset `00Z` to `001`, and run all gates. Carry fixes forward to `main` via reviewed merge/cherry-pick.

---

## Versioning & Tagging Rules (Verified from `git-guidelines.md` lines 391–520)

Format: `<prefix>.0X.Y.00Z[a|b|rc][N]` (exact zero-padding; never collapse `01.0.001` to `1.0.1`).

| Product | Repo | Tag Prefix Formula | Confirmed Prefix |
|---|---|---|---|
| Web App | `agora-ping-web` | `W` + `AP` | `WAP` (Next: `WAP.01.0.001`) |
| Backend API | `agora-ping-api` | `B` + `AP` | `BAP` (Next: `BAP.01.0.001`) |
| Android App | `agora-ping-android` | `A` + `AP` | `AAP` (Next: `AAP.01.0.001`) |
| Specifications | `agora-ping-specs` | `S` + `AP` | `SAP` (Next: `SAP.01.0.001`) |

### Hard Tag Rules

1. **Tag from `release` only** for release/pre-release candidates — never from `main` or `beta` (`git-guidelines.md` line 313). *Miss →* Tag points to untested code.
2. **Start `001` on the first commit's ISO-8601 week** (Monday–Sunday). Empty weeks get no tag and do not consume a build number.
3. **Never tag an ongoing week before Friday 5:00 PM local time** (`git-guidelines.md` lines 499–502). *Miss →* Splits a week's work across multiple tags.
4. **Annotated tags only, dated on Friday** (clamped forward to the commit date if the week's last commit landed on the weekend), pointing to the last commit of that ISO week.
5. **Never move or reuse an existing tag.** Tags must remain strictly chronological.
6. **Pre-release suffixes (`a`, `b`, `rc`, then `a2`, `b2`, `rc2`, …):**
   - Used only when planned development is 100% complete (WBS/Gantt at 100%).
   - Never append `1` to the first candidate (`a`, not `a1`).
   - Numeric suffixes do not carry across stages (`a2` passing → `b`, not `b2`).
   - These are **Git tags**, not GitHub Releases (`git-guidelines.md` line 442).
   - Suffixes do not increment `0X`, `Y`, or `00Z`.
7. **No AI attribution:** Tags and releases must never be authored by an AI agent (`git-guidelines.md` line 257).
8. **Update the registry in lockstep:** Record every new tag in `agora-ping-specs/git-guidelines.md` (Lockstep Set #4, `04 #4`).

---

## How Each Deployable Ships

**Status: TBD** — No Dockerfiles, build scripts, CI workflows, release website URL, or hosting targets exist yet. Populate per-repo build/deploy steps here once infrastructure is chosen.

---

## Release Checklist

1. Confirm ecosystem short code is finalized (no placeholder `CN`; see 04 #1, 15 #1).
2. Confirm promotion gate passed (`main` unit tests → `beta` QA sign-off → `release` bundle).
3. Confirm it is **Friday ≥ 17:00 local time** if cutting a weekly tag for the current ISO week.
4. Confirm human git identity (`git config user.name` / `user.email`) — no AI agent attribution.
5. Create the annotated tag on `release` pointing to the exact week-end / candidate commit.
6. Update the product's Release Tags table and `Next release:` line in `agora-ping-specs/git-guidelines.md` (see 04 #4).
7. For `rc` production deploys, verify written approval from the designated final approver and deploy that exact candidate artifact.
