# 14 — Developer Workflows

**Purpose:** Local workspace setup and step-by-step recipes for common tasks, each linked to the lockstep sets and failure stories it guards against.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. Recipes below cover workspace setup, bootstrap completion, committing, environmental scanning, and release tagging. Add build/run/test recipes once stacks are chosen. The code wins (see 16 #7).

---

## Workspace Setup

1. Open the parent folder `agora-ping-ecosystem/` as your IDE workspace root — **not** an individual sub-repo.
   - *Miss →* Relative globs in `AGENTS.md` (`*-specs/skills/*.md`, `*-specs/git-guidelines.md`) fail to resolve (see 04 #2, 05 #3).
2. Verify all four sibling repos exist and point to the expected remotes:
   ```powershell
   foreach ($d in "agora-ping-api","agora-ping-web","agora-ping-android","agora-ping-specs") {
     Write-Output "=== $d ==="
     git -C $d remote -v
     git -C $d status -s -b
   }
   ```
3. Confirm your human Git identity (`user.name` and `user.email`) is configured in Git. Never configure or attribute commits/tags to an AI agent (`git-guidelines.md` line 257).
4. Read `01_ARCHITECTURE.md`, `03_CODE_STYLE.md`, `04_CHANGE_RULES.md`, and `15_KNOWN_LIMITATIONS.md` before writing code or specs.

*When done, add what surprised you to `INBOX.md`.*

---

## Recipe 1: Complete Ecosystem Bootstrap (Before First Commits)

Guards against: **Lockstep Set #1 (`04 #1`)**, **Failure Story #1 (`06 #1`)**, and **Limitations #1–#2 (`15 #1`, `15 #2`)**.

1. Finalize `agora-ping-specs/business-logic-v1.0.md`:
   - Fill `<Platform>`, `<App/Software Type>`, `<Tech Stack>`, `<Userbase>`, `<Team Name>`, `<Code Name>`, `<short-code>`, descriptions, `C. Moderator` and `D. Contributor` roles, System Requirements 2–7, and the `MVP Features and Access` table.
2. Customize `agora-ping-specs/git-guidelines.md` in lockstep (`04 #1`):
   - Replace every `code-name`, `Code Name`, `CN`, `WCN`, `BCN`, `ACN`, `SCN`, and `<featureN>` placeholder with the finalized values.
   - Resolve `code-name-app` vs `agora-ping-android` consistently across all scope tables and examples (see 06 #1).
   - Remove stale template dates (`2026-07-04`, `2026-10-05`, `2026-10-09`, `ISO 2026-W41`) from the Release Tags section.
3. Verify zero template placeholders remain:
   ```powershell
   Select-String -Path "agora-ping-specs\*.md" -Pattern "code-name|WCN|BCN|ACN|SCN|<[A-Za-z]|xxx"
   ```
   - *Miss →* Placeholder names leak into your first permanent commits and release tags.
4. Make the initial commit in each repo on `main` using the finalized commit format (`03_CODE_STYLE.md`) and push `origin main`.
5. Refresh `agora-ping-specs/skills/` confidence notes with the real commit hashes and log the update in `00_INDEX.md`.

*When done, add what surprised you to `INBOX.md`.*

---

## Recipe 2: Make a Compliant Commit

Guards against: **Commit standard (`03_CODE_STYLE.md`)** and **AI-author violation (`git-guidelines.md` line 257)**.

1. Ensure you are targeting the right sub-repo (`git -C <repo> ...`) — never the root folder (see 05 #1).
2. Confirm your diff touches one cohesive scope; if it spans unrelated scopes, split it into separate commits.
3. Write the message:
   - Line 1: `<scope>: <Imperative summary>` (≤50 chars, sentence case, no period; add `!` after scope for breaking changes).
   - Line 2: Blank line if adding a body.
   - Body (optional): Explain *why*, wrapped at 72 chars; add `BREAKING CHANGE:` and ticket references (`Fixes #NNN — description`) if applicable.
4. Apply the **One-Sentence Test** (`03_CODE_STYLE.md`) and confirm **no AI agent** is listed as author or co-author.
5. Commit and verify: `git -C <repo> show --stat HEAD`.

*When done, add what surprised you to `INBOX.md`.*

---

## Recipe 3: Run Environmental Scanning (`sense-making.md`)

Guards against: **Lockstep Set #5 (`04 #5`)**, **Symptom #4 (`05 #4`)**, and **Limitation #5 (`15 #5`)**.

1. Verify `agora-ping-specs/business-logic-v1.0.md` (or the latest versioned `business-logic-v*.md`) has no remaining `<...>` placeholders (see 05 #4).
   - *Miss →* Research sources won't match the real domain or solution.
2. Follow `agora-ping-specs/sense-making.md` strictly:
   - Verify every source against the publisher's page or database; drop unverifiable sources.
   - Cover all 7 exact factors (`Social`, `Technological`, `Economic`, `Environmental`, `Political`, `Legal`, `Ethical`) with ≥2 key findings per factor (≥14 total) and ≥3 credible sources per factor.
   - Keep each `Key Finding` and `APA Reference` ≤256 characters, double-quoted, with internal quotes escaped as `""`.
3. Save the CSV to `agora-ping-specs/planning/sense-making.csv`.

*When done, add what surprised you to `INBOX.md`.*

---

## Recipe 4: Promote a Branch and Cut a Weekly Release Tag

Guards against: **Lockstep Set #4 (`04 #4`)** and **Branching/Tagging rules (`10_DEPLOYMENT.md`)**.

1. Promote in strict order: `main` (unit tests pass) → `beta` (QA system tests pass) → `release` (published bundle for independent integration testing).
   - *Miss →* Untested code enters independent testing (`git-guidelines.md` line 309).
2. Confirm the current week cutoff: do **not** tag an ongoing ISO-8601 week before **Friday 5:00 PM local time** (`git-guidelines.md` line 500).
3. On `release`, create an **annotated** tag (`git tag -a <tag> -m "..."`) on the week's last commit, using a human identity and never moving an existing tag.
4. Update the repo's Release Tags table and `Next release:` line in `agora-ping-specs/git-guidelines.md` (`04 #4`).
   - *Miss →* Next release engineer misnumbers `00Z`.

*When done, add what surprised you to `INBOX.md`.*

---

## Recipe 5: Refresh `agora-ping-specs/skills/`

Guards against: **Stale skills (`handoff.md` lines 71–92)**.

1. Diff each repo since the last **Confidence note** date/commit (`git -C <repo> log --since=...`).
2. Process every entry in `INBOX.md`: verify against code (or mark *unverified*), merge into its home doc with credit, and clear it from `INBOX.md`.
3. Retire outdated rules under a `## Retired` section (`Superseded (<date>): by ..., because ...`) instead of deleting silently; never renumber existing items.
4. Update the **Confidence note** in every rechecked file and append a dated entry at the top of `00_INDEX.md`'s Changelog.

*When done, add what surprised you to `INBOX.md`.*
