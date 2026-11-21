# 03 — Code Style

**Purpose:** Coding conventions, comment philosophy, anti-patterns, and the mandatory Git commit message standard.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. Commit conventions are verified from `agora-ping-specs/git-guidelines.md`; language-specific linters/formatters do not exist yet because no tech stack has been initialized. The code wins (see 16 #7).

---

## Comment Philosophy

- **Write the *why*, at the line** (`handoff.md` lines 11–13). Never narrate what the syntax already says.
- Document invariants, privacy/legal reasons (e.g., Data Privacy Act aggregation threshold), external API quirks, or rejected alternatives right beside the code that enforces them.
- Tag temporary compromises with `TODO(<owner/ticket>):` or `HACK:` and explain the exit condition so future skills refreshes can grep scar tissue (`because`, `never`, `must`, `HACK`, `TODO`, `FIXME`, `workaround`, `legacy`).

---

## Language Tooling, Naming, Error Handling, and Logging

**Status: Pre-code (TBD once tech stacks are selected in `business-logic-v1.0.md`).**

Once `agora-ping-api`, `agora-ping-web`, and `agora-ping-android` are scaffolded, update this section with each repo's formatter, linter, typechecker, error-handling pattern, and structured logging rules.

**Already-mandated logging rule (verified from `business-logic-v1.0.md` line 39):**
- **Never log per-user behavioral trails or raw precise locations** in application logs. *Miss →* Violates the Data Privacy Act / "no per-user trails" requirement even if the database complies (see 09, 16 #3).

---

## Preferred Patterns & Anti-Patterns

| Anti-Pattern | Cost That Bans It | Preferred Pattern | Source |
|---|---|---|---|
| Generic commit scopes (`ui:`, `api:`, `core:`) when a product/feature scope fits | Hides which repo/subsystem changed across a 4-repo ecosystem | Use `<product>/<feature>:` (e.g., `agora-ping-api/auth:`) or `<product>:` | `git-guidelines.md` lines 51–98 |
| Bundling unrelated changes into one commit | Breaks cherry-picks, reverts, and maturity promotions | Split into one atomic commit per logical scope | `git-guidelines.md` lines 97–98, 209–218 |
| Adding an AI agent as author or co-author of commits, tags, releases, or PRs | Explicitly prohibited by project governance | Always attribute commits, tags, releases, and PRs to human engineers only | `git-guidelines.md` line 257 |
| Ticket-only or past-tense commit summaries (`api: TT-9021`, `auth: Added login`) | Fails the One-Sentence Test; unreadable in `git log` | Imperative mood, ≤50 chars, sentence case, no trailing period | `git-guidelines.md` lines 117–131, 247–251 |
| Copying template placeholders (`code-name`, `CN`, `<Tech Stack>`) into real commits or docs | Leaks ambiguous names into permanent git history and tags | Customize ecosystem placeholders first (see 04 #1, 15 #1) | `git-guidelines.md` lines 5–7; 06 #1 |

---

## Commit Conventions (Verified from `agora-ping-specs/git-guidelines.md`)

Every commit across all four repositories **must** follow:

```text
scope: Imperative summary

Optional body explaining WHY (not mechanics), wrapped at 72 characters.
Leave a blank line between line 1 and the body.

Fixes #1234 — Short human-readable description of the ticket
See-also #1201 — Related prior change
```

### Rules Checklist

1. **Line 1 format:** `scope: Imperative summary`
   - Imperative mood (*"If applied, this commit will — [summary]"*).
   - Sentence case (capitalize only the first word after `scope: `).
   - **50 characters or fewer**; no trailing period.
   - For `agora-ping-specs`, describe the spec change (`Define`, `Clarify`, `Revise`, `Deprecate`), not future code.
2. **Scope selection:**
   - Focused feature: `<product>/<feature>:` (shared feature names: `auth`, `sync`, `security`, `backup`, `restore`, plus domain features once defined).
   - Cross-feature within one product: `<product>:`.
   - Cross-feature spec kinds in `agora-ping-specs`: `requirements`, `design`, `schema`, `contracts`.
   - General scopes (`db`, `config`, `test`, `docs`, `ci`, `deps`) only when no product/feature scope fits.
   - **Note:** Replace `code-name` in `git-guidelines.md` with the official ecosystem code name and standardize `agora-ping-android` vs `agora-ping-app` before making initial commits (see 04 #1, 06 #1).
3. **Breaking changes:** Append `!` after the scope (`<scope>:! Summary`) and include a `BREAKING CHANGE:` trailer (`git-guidelines.md` lines 222–231). *Miss →* Dependent clients (`web`, `android`) break unexpectedly on API rollout.
4. **Blank line on line 2:** Required whenever a body follows. *Miss →* Git log parsers and tooling concatenate the body into the subject line.
5. **The One-Sentence Test:** Would a developer joining next year understand what this commit did and why from line 1 alone? If not, rewrite it.
6. **No AI attribution:** Never add any AI agent as commit author, co-author (`Co-authored-by:`), tagger, or PR/release author (`git-guidelines.md` line 257).
