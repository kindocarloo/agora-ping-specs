# 15 — Known Limitations

**Purpose:** Honest inventory of drift, unfinished specs, architectural constraints, security weaknesses, and redesign candidates — ordered by how likely they are to surprise an engineer today.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. Every item below was directly verified on disk. The code wins (see 16 #7).

---

## Gaps Ordered by Surprise Likelihood

### #1 Template Drift & Naming Conflict in `agora-ping-specs/git-guidelines.md` (Drift — Verified)
- **What:** `git-guidelines.md` still contains template placeholders (`code-name`, `Code Name`, `CN`, `WCN`/`BCN`/`ACN`/`SCN`, `<feature1>`), conflicts with itself on Android naming (`code-name-android` on line 521 vs `code-name-app` on lines 59, 63, 68, 84–85, 281, 559), and carries hardcoded historical dates (`2026-07-04`, `2026-10-05`, `2026-10-09`, `ISO 2026-W41`) from another project.
- **Why it surprises:** Anyone copying commit scopes or tag prefixes verbatim on Day 1 writes invalid scopes/tags into permanent Git history (see 04 #1, 06 #1).

### #2 Unfilled `agora-ping-specs/business-logic-v1.0.md` (Deferred Spec — Verified)
- **What:** Tech stack, project code name, short code, descriptions, `C. Moderator` / `D. Contributor` descriptions, System Requirements 2–7, and the `MVP Features and Access` table are all placeholders (`<...>`, `...`, `- xxx`).
- **Why it surprises:** Blocks architecture, database schema, API contracts, RBAC enforcement, and `sense-making.md` research (see 01, 05 #4).

### #3 Zero Application Code, Commits, Tests, or CI Across All 4 Repos (Bootstrap State — Verified)
- **What:** `agora-ping-api`, `agora-ping-web`, `agora-ping-android`, and `agora-ping-specs` all report `No commits yet on main...origin/main [gone]`. No runtime code, manifests, schemas, tests, or CI workflows exist yet.
- **Why it surprises:** Running standard git commands (`git log`, `git diff`) or looking for build scripts immediately fails until initial commits are made (see 05 #2, 11).

### #4 Five Byte-Identical Placeholder `AGENTS.md` Files (Drift / Maintenance Risk — Verified)
- **What:** Root `AGENTS.md` and all four sub-repo `AGENTS.md` files contain the exact same 9-line template pointing to `*-api/AGENTS.md`, `*-android/AGENTS.md`, `*-web/AGENTS.md`, `*-specs/AGENTS.md`, `*-specs/skills/*.md`, and `*-specs/git-guidelines.md`.
- **Why it surprises:** Opening a sub-repo standalone breaks those sibling globs (see 04 #2, 05 #3), and each sub-repo lacks stack-specific build/test/style instructions.

### #5 Missing Environmental Scan (`agora-ping-specs/planning/sense-making.csv`) (Deferred Deliverable — Verified)
- **What:** `agora-ping-specs/sense-making.md` specifies output at `*-specs/planning/sense-making.csv`, but neither `planning/` nor `sense-making.csv` exists yet.
- **Why it surprises:** Downstream planning docs referencing sense-making findings will find nothing until `business-logic-v1.0.md` is filled and `sense-making.md` is executed (see 04 #5, 14 Recipe 3).

### #6 No Automated Enforcement of Git, Privacy, or Security Rules (Security / Governance Weakness — Verified)
- **What:** No `.git/hooks` (only default `.sample` hooks), no commit-message linter, no secret scanner, no AI-author rejection hook, and no verified GitHub branch protection on `main`/`beta`/`release`.
- **Why it surprises:** Every governance rule in `git-guidelines.md` (commit format, no AI author, branch promotion gates) currently relies 100% on manual discipline (see 03, 09, 10).

---

## Ranked Redesign / Cleanup Candidates

| Rank | Candidate | Trigger to Act |
|---|---|---|
| 1 | Complete `business-logic-v1.0.md` and customize `git-guidelines.md` (`04 #1`) | **Immediately — before the first commit in any repo** |
| 2 | Split `AGENTS.md` so each sub-repo adds stack-specific commands/rules while referencing `agora-ping-specs/` | As soon as each repo's tech stack is initialized |
| 3 | Add lightweight commit-msg / pre-commit hooks or GitHub Actions to enforce `scope: Summary`, no secrets, and no AI author | Immediately after initial push to `origin/main` |
| 4 | Consider versioning workspace root `AGENTS.md` / `handoff.md` inside `agora-ping-specs/` (or a meta-repo) so workspace instructions aren't untracked locally | Before onboarding additional engineers |
