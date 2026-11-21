# 05 — Debugging Playbook

**Purpose:** Where to find logs, exact error messages you will hit in this workspace, their causes ranked by frequency, and fast diagnostic commands.

**Confidence note:** verified against pre-initial-commit workspace (unborn `HEAD` on `main` across all 4 repos) on 2026-11-21. No runtime services, build logs, or production logs exist yet; symptoms below cover verified workspace and Git setup issues. Expand as soon as `agora-ping-api`, `agora-ping-web`, and `agora-ping-android` run. The code wins (see 16 #7).

---

## Where the Logs Are

- **Application / Server / Client Logs:** None yet (no runtime code or deployables exist).
- **Git & Workspace State:** Checked per sub-repo via `git -C <repo> status` and `git -C <repo> log`.
- **Privacy constraint for future logs:** Never emit per-user tracking trails or raw precise locations to logs (see 03, 09).

---

## Symptoms and Diagnostics

### #1 `fatal: not a git repository (or any of the parent directories): .git`
- **Most likely cause (verified):** Running `git` inside the workspace root `agora-ping-ecosystem/`. The root folder is a non-git container; each of the four sub-folders is its own Git repository (see 01, 02).
- **Diagnostic shortcut:** Target the sub-repo explicitly:
  ```powershell
  git -C agora-ping-specs status -s -b
  ```

### #2 `## No commits yet on main...origin/main [gone]`
- **Most likely cause (verified):** All four repositories are freshly initialized with an unborn `HEAD` and a configured tracking branch against empty GitHub remotes (`git@github.com:kindocarloo/agora-ping-*.git`).
- **Secondary cause (inferred):** Remote `main` was deleted or renamed after cloning.
- **Diagnostic shortcut:** Check local commits and remote connectivity:
  ```powershell
  git -C agora-ping-specs remote -v
  git -C agora-ping-specs log --oneline -n 5
  ```
- **Fix:** Complete Lockstep Set #1 (`04 #1`) first, then make the initial commit and push (`git -C <repo> push -u origin main`).

### #3 Agent skips skills or `git-guidelines.md`
- **Most likely cause (verified):** Opening a single sub-repo (e.g., `agora-ping-api/`) as the IDE workspace root instead of `agora-ping-ecosystem/`. All 5 `AGENTS.md` files use relative globs (`*-specs/skills/*.md`) that only resolve from the parent workspace root (see 04 #2).
- **Secondary cause (historical — resolved 2026-11-21):** `agora-ping-specs/skills/` did not exist before bootstrap.
- **Diagnostic shortcut:** Confirm your workspace root contains all 4 `agora-ping-*` sibling directories and `agora-ping-specs/skills/00_INDEX.md`.

### #4 `sense-making.md` produces off-topic or placeholder research
- **Most likely cause (verified):** `agora-ping-specs/business-logic-v1.0.md` still contains template placeholders (`<Platform>`, `<Tech Stack>`, `<Code Name>`, requirements 2–7 as `...`; see 15 #2).
- **Diagnostic shortcut:** Search for unfilled placeholders before running `sense-making.md`:
  ```powershell
  Select-String -Path "agora-ping-specs/business-logic-v1.0.md" -Pattern "<|xxx|\.\.\."
  ```

---

## Useful Diagnostic Commands (PowerShell)

Check Git status, branch, and tags across all 4 repos in one pass:

```powershell
foreach ($d in "agora-ping-api","agora-ping-web","agora-ping-android","agora-ping-specs") {
  Write-Output "=== $d ==="
  git -C $d status -s -b
  git -C $d tag -l
}
```

Check for leftover template placeholders across specs:

```powershell
Select-String -Path "agora-ping-specs\*.md" -Pattern "code-name|WCN|BCN|ACN|SCN|<[A-Za-z]|xxx"
```
