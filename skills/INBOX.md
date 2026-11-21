# INBOX — Skills Contributions

**Purpose:** Low-friction intake queue for lessons, gotchas, design decisions, incidents, and corrections before they are verified and merged into `01`–`16`.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. The code wins (see 16 #7).

---

## How to Use This File

**A rough entry beats none.** If something surprised you, broke silently, or took longer than five minutes to figure out, append it under `## Pending Entries` below before you forget.

During a skills refresh, a maintainer verifies each entry (or marks it *unverified*), merges it into its home document with author credit, logs the update in [00_INDEX.md](00_INDEX.md), and removes it from this file. If an entry conflicts with an existing rule, both positions are recorded with evidence for the team to decide.

### Routing Table

| Contribution Type | Home Document |
|---|---|
| Best practice | `03_CODE_STYLE.md` (code) or `14_DEVELOPER_WORKFLOWS.md` (workflow) |
| Methodology | `10_DEPLOYMENT.md`, `11_TESTING.md`, or `14_DEVELOPER_WORKFLOWS.md` |
| Design choice | `01_ARCHITECTURE.md` (as a decision record) |
| Change rule / lockstep set | `04_CHANGE_RULES.md` |
| Failure story / incident | `06_FAILURE_STORIES.md` (linked from `04`, `05`, and `16`) |
| Debugging tip / error symptom | `05_DEBUGGING_PLAYBOOK.md` |
| Known limitation / drift | `15_KNOWN_LIMITATIONS.md` |
| Dependency note / upgrade trap | `13_DEPENDENCIES.md` |
| Engineering principle | `16_ENGINEERING_PRINCIPLES.md` (once proven) |

---

## Entry Template

Copy and fill out as much as you know:

```markdown
### <summary>
- **Type / Author / Date:**
- **What:**
- **Why:** what improves, or what breaks without it.
- **Evidence:** files, commits, PRs, or the incident.
```

---

## Pending Entries

*(Empty — add new entries below.)*
