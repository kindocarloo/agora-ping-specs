# 02 — Project Structure

**Purpose:** Annotated map of the workspace, strict rules on where new code and specs belong, and naming conventions that carry operational meaning.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. Every listed path was verified on disk. The code wins (see 16 #7).

---

## Annotated Workspace Tree

```text
agora-ping-ecosystem/                  # Local workspace root (NOT a git repository)
├── AGENTS.md                          # Workspace entrypoint rule pointing to sub-repo AGENTS.md, skills, git-guidelines
├── handoff.md                         # Prompt/standard for generating and refreshing agora-ping-specs/skills/
├── agora-ping-api/                    # [Git repo] Backend API (origin: kindocarloo/agora-ping-api.git)
│   └── AGENTS.md                      # Currently identical to root AGENTS.md (placeholder)
├── agora-ping-web/                    # [Git repo] Web frontend (origin: kindocarloo/agora-ping-web.git)
│   └── AGENTS.md                      # Currently identical to root AGENTS.md (placeholder)
├── agora-ping-android/                # [Git repo] Android app (origin: kindocarloo/agora-ping-android.git)
│   └── AGENTS.md                      # Currently identical to root AGENTS.md (placeholder)
└── agora-ping-specs/                  # [Git repo] Specs & skills (origin: kindocarloo/agora-ping-specs.git)
    ├── AGENTS.md                      # Currently identical to root AGENTS.md (placeholder)
    ├── business-logic-v1.0.md         # Master business requirements, user levels, MVP access matrix (template; unfilled)
    ├── git-guidelines.md              # Commit format, branching model, versioning, release tag tables (template; uncustomized)
    ├── sense-making.md                # Environmental scanning prompt; outputs to planning/sense-making.csv
    └── skills/                        # Engineering knowledge base (00_INDEX.md .. 16_ENGINEERING_PRINCIPLES.md + INBOX.md)
```

---

## Where New Code and Docs Go — and Must NOT Go

| Artifact | Goes Here | Must NOT Go Here | Why (*Miss →*) |
|---|---|---|---|
| Business requirements, user levels, feature matrix | `agora-ping-specs/business-logic-vX.Y.md` | Inside `api/`, `web/`, or `android/` READMEs | *Miss →* Specs fragment across repos and agents fail to find the latest baseline. |
| Environmental scan output | `agora-ping-specs/planning/sense-making.csv` | Repo root or `skills/` | `sense-making.md` line 28 hardcodes `*-specs/planning/sense-making.csv`. *Miss →* Downstream planning scripts/reviewers won't find it. |
| Engineering playbooks, decisions, lockstep rules, incidents | `agora-ping-specs/skills/NN_TOPIC.md` (or `INBOX.md`) | `AGENTS.md` or random markdown files | `AGENTS.md` points specifically to `*-specs/skills/*.md`. *Miss →* Agents and newcomers skip the rule. |
| Repo-specific build/test/architecture rules | `agora-ping-{api,web,android,specs}/AGENTS.md` | Only in workspace root `AGENTS.md` | Root is not a git repo. *Miss →* Teammates cloning a single repo never receive the rule (see 04 #2). |
| Backend API code, migrations, server config | `agora-ping-api/` | `agora-ping-specs/` or client repos | Violates repo ownership and tag streams (see 01). *Miss →* Mixed releases and broken deployment boundaries. |
| Web frontend code | `agora-ping-web/` | `agora-ping-api/` or `agora-ping-android/` | Breaks independent web versioning (`W<SC>`). |
| Android app code | `agora-ping-android/` | `agora-ping-web/` or `agora-ping-api/` | Breaks independent Android versioning (`A<SC>`). |
| Secrets, `.env` values, keystores, OAuth client secrets | Local untracked env / secret manager | Committed to any of the 4 repos or `skills/` | *Miss →* Credential exposure in git history (see 09). |

---

## Naming Conventions That Carry Meaning

1. **Repo suffix convention (`agora-ping-<surface>`):**
   - `AGENTS.md` relies on glob patterns `*-api/AGENTS.md`, `*-android/AGENTS.md`, `*-web/AGENTS.md`, `*-specs/AGENTS.md`, `*-specs/skills/*.md`, and `*-specs/git-guidelines.md`.
   - *Miss →* Renaming a folder away from `*-api`, `*-android`, `*-web`, or `*-specs` breaks agent auto-discovery rules.
   - **Active drift warning:** `git-guidelines.md` uses `code-name-app` in several places while the actual repo is `agora-ping-android` (see 06 #1, 15 #1). Resolve before the first commit.
2. **Versioned business-logic filename (`business-logic-v1.0.md`):**
   - `sense-making.md` line 3 says `"Read the latest business-logic file."` Major/minor spec revisions increment the filename version rather than overwriting silently.
3. **Skills file numbering (`00`–`16` + `INBOX.md`):**
   - Cross-references across skills use document numbers (`see 04 #1`, `see 06 #1`). Never renumber files or items once published (see `handoff.md` line 91).
4. **Release tag prefixes (`<ProductLetter><ShortCode>.0X.Y.00Z`):**
   - Product letter encodes the repo (`W` = Web, `B` = Backend/API, `A` = Android, `S` = Specs) followed by the ecosystem short code (currently placeholder `CN` in `git-guidelines.md`; see 04 #1, 10).
