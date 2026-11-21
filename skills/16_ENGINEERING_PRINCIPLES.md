# 16 — Engineering Principles

**Purpose:** Proven, quotable rules that govern how `agora-ping-ecosystem` is built and maintained, each backed by reasoning, evidence, and its source story.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. Baseline principles below come from verified governance documents (`business-logic-v1.0.md`, `git-guidelines.md`, `handoff.md`) and bootstrap audit findings. Append new proven principles after Principle #7; never renumber. The code wins (see #7 below).

---

### #1 Specifications precede implementation — and unfinished templates are not specifications.
- **Reasoning:** Building schemas, endpoints, or research on placeholder specs guarantees rework and misnamed contracts across four separate repositories.
- **Evidence:** `agora-ping-specs/business-logic-v1.0.md` still contains `<Tech Stack>`, `<Code Name>`, and `...` placeholders, blocking `sense-making.md` and stack scaffolding (see 01, 04 #5, 15 #2).
- **Source:** Bootstrap audit (06 #1).

### #2 One ecosystem identity, zero silent renames across repos.
- **Reasoning:** With four independent Git repositories sharing one product identity, a single naming mismatch splits commit history, breaks tag prefixes, and confuses cross-repo tooling.
- **Evidence:** `git-guidelines.md` mixes `code-name-app` with `code-name-android` while the actual repository is `agora-ping-android` (see 04 #1, 15 #1).
- **Source:** Failure Story 06 #1.

### #3 Privacy by design is an architectural boundary, not a post-launch patch.
- **Reasoning:** Retrofitting "no per-user trails", location protection, retention limits, and aggregation thresholds onto an existing database and log pipeline requires destructive migrations and leaves historical exposure behind.
- **Evidence:** Mandated as Required Solution Layer #1 in `agora-ping-specs/business-logic-v1.0.md` line 39 (see 01, 07, 09).
- **Source:** `agora-ping-specs/business-logic-v1.0.md` line 39.

### #4 Promotion through `main` → `beta` → `release` → production requires passing each gate in order.
- **Reasoning:** Independent integration testers and production users must only ever evaluate builds that passed developer unit testing and QA system testing; skipping gates invalidates release tags and auditability.
- **Evidence:** Maturity-based branching and tagging rules in `agora-ping-specs/git-guidelines.md` lines 286–340 (see 01, 10, 11).
- **Source:** `agora-ping-specs/git-guidelines.md` Part 2.

### #5 Every commit must pass the One-Sentence Test and carry a human author.
- **Reasoning:** Commit history is the permanent audit trail across four repositories; vague messages destroy debugging speed, and AI attribution is explicitly banned by project governance.
- **Evidence:** Required commit standard (`scope: Imperative summary`, ≤50 chars) and Exclusion of AI Agent rule in `agora-ping-specs/git-guidelines.md` lines 34–38, 247–258 (see 03, 14).
- **Source:** `agora-ping-specs/git-guidelines.md` Part 1.

### #6 Mark every silent failure where the guard lives, and label what you verified vs. inferred.
- **Reasoning:** Rules without reasons get ignored under deadline pressure, and unverified guesses presented as fact mislead engineers into trusting broken assumptions.
- **Evidence:** `handoff.md` lines 20–24; verified during bootstrap where template dates and placeholders in `git-guidelines.md` looked active until checked against `git status` (see 04, 06 #1, 15).
- **Source:** `handoff.md` standards & Failure Story 06 #1.

### #7 Trust the code over any document, including this one.
- **Reasoning:** Code executes; documents drift. Whenever any skills file, spec, or comment disagrees with the running codebase or Git history, the code wins and the document has a bug that must be fixed immediately (or logged in `INBOX.md`).
- **Evidence:** `handoff.md` lines 24, 73–79, 151.
- **Source:** `handoff.md`.
