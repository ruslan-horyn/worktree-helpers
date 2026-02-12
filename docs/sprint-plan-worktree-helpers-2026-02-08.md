# Sprint Plan: worktree-helpers v1.1

**Date:** 2026-02-08
**Scrum Master:** Ruslan Horyn
**Project Level:** 1
**Total Stories:** 12
**Total Points:** 43
**Planned Sprints:** 3
**Status:** Ready for Implementation

---

## Executive Summary

This sprint plan covers the v1.1 development cycle for worktree-helpers. Building on the solid v1.0 foundation (8 stories, 31 points delivered across 2 sprints), v1.1 focuses on three themes: **quality infrastructure** (tests, CI, linting), **developer experience** (shell completions, self-update, granular clear), and **polish** (dirty/clean status, metadata, packaging). The work is organized into 3 balanced sprints.

**Key Metrics:**

- Total Stories: 17
- Total Points: 58
- Sprints: 4
- Team Capacity: 17 points per sprint
- Historical Velocity: 15.5 points/sprint (rolling average)
- Target Completion: 8 weeks (4 sprints × 2 weeks)

---

## Team Capacity

| Parameter | Value |
|-----------|-------|
| Team Size | 1 developer |
| Sprint Length | 2 weeks (10 workdays) |
| Productive Hours/Day | 5 hours |
| Total Hours/Sprint | 50 hours |
| Points per Sprint | ~17 points |
| Historical Velocity | Sprint 1: 14, Sprint 2: 17 (avg: 15.5) |

---

## Story Inventory

### STORY-009: Add test suite with BATS

**Phase:** Quality Infrastructure
**Priority:** Must Have
**Points:** 8

**User Story:**
As a developer
I want automated tests for all `wt` commands
So that I can refactor and add features with confidence that existing functionality isn't broken

**Acceptance Criteria:**

- [ ] BATS framework installed and configured (`bats-core`, `bats-support`, `bats-assert`)
- [ ] Test fixtures: mock git repos, config files, isolated temp directories
- [ ] Unit tests for core utilities (`_err`, `_info`, `_require`, `_repo_root`, `_branch_exists`)
- [ ] Unit tests for config loading (`_config_load`)
- [ ] Integration tests for each command: `_cmd_new`, `_cmd_switch`, `_cmd_remove`, `_cmd_list`, `_cmd_clear`, `_cmd_open`, `_cmd_lock`, `_cmd_unlock`, `_cmd_init`, `_cmd_log`
- [ ] Edge case coverage: missing config, missing dependencies, invalid arguments, empty worktree list
- [ ] Hook execution tests (with mock hooks)
- [ ] Tests pass on both macOS and Linux
- [ ] All major code paths covered

**Technical Notes:**

- Use [bats-core](https://github.com/bats-core/bats-core) with `bats-support` and `bats-assert`
- Tests run in isolated temp directories to avoid affecting real repos
- Create test helper for common setup/teardown (init git repo, create config, etc.)
- Estimated 15-25 test files

**Dependencies:** None (foundational work)

---

### STORY-010: Add CI/CD pipeline (shellcheck + tests)

**Phase:** Quality Infrastructure
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer
I want PRs automatically linted and tested
So that code quality is enforced before merging

**Acceptance Criteria:**

- [ ] GitHub Actions workflow triggered on push/PR to main
- [ ] Shellcheck runs against all `.sh` files (`wt.sh`, `lib/*.sh`, `install.sh`)
- [ ] BATS test suite runs as part of CI
- [ ] All existing shellcheck warnings/errors fixed
- [ ] `.shellcheckrc` configuration if needed
- [ ] CI status badge in README
- [ ] Tests run on ubuntu-latest with bash

**Technical Notes:**

- Use `koalaman/shellcheck-action` and `bats-core/bats-action` GitHub Actions
- Matrix testing: ubuntu-latest (bash + zsh) if feasible
- Integrate with existing release workflow

**Dependencies:** STORY-009 (tests must exist to run)

---

### STORY-011: Show dirty/clean status in `wt -l`

**Phase:** UX Polish
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer
I want to see which worktrees have uncommitted changes when I list them
So that I know which worktrees need attention before cleanup

**Acceptance Criteria:**

- [ ] `wt -l` shows dirty/clean indicator per worktree
- [ ] Dirty = uncommitted changes (staged or unstaged) or untracked files
- [ ] Clean = working tree matches HEAD
- [ ] Visual indicator: colored label or icon (e.g., `[dirty]` / `[clean]`)
- [ ] Existing output columns preserved (branch, path, locked status)
- [ ] Handles edge cases: pruned worktrees, broken worktrees
- [ ] Performance acceptable with 10+ worktrees

**Technical Notes:**

- Use `git -C <worktree-path> status --porcelain` to detect dirty state
- Performance: runs git status per worktree — consider parallel execution or caching for large counts
- Graceful handling if worktree path is inaccessible

**Dependencies:** None

---

### STORY-012: Add `--version` flag

**Phase:** Developer Experience
**Priority:** Should Have
**Points:** 1

**User Story:**
As a user
I want to check which version of `wt` I have installed
So that I can troubleshoot issues or verify updates

**Acceptance Criteria:**

- [ ] `wt -v` / `wt --version` prints version (e.g., `wt version 1.1.0`)
- [ ] Version sourced from a single canonical location
- [ ] Router in `wt.sh` handles the flag
- [ ] Install script embeds the version correctly
- [ ] Version stays in sync with `package.json`

**Technical Notes:**

- Store version in `VERSION` file at repo root or embed in `wt.sh` header
- Install script reads and embeds version during install
- Keep in sync with `package.json` version (consider generating from one source)

**Dependencies:** None

---

### STORY-013: Add self-update mechanism (`wt --update`)

**Phase:** Developer Experience
**Priority:** Should Have
**Points:** 5

**User Story:**
As a user
I want to update the tool with a single command
So that I can get bug fixes and new features without re-running the install script

**Scope adjustments (per user request):**

- Update check is **non-blocking** — runs after any `wt` action completes
- Displays a notification on the next `wt` invocation if a new version is available
- `wt --update` explicitly triggers the update

**Acceptance Criteria:**

- [ ] `wt --update` fetches latest version from GitHub and installs it
- [ ] Background version check after `wt` actions (non-blocking)
- [ ] Notification shown on next `wt` invocation if new version available (e.g., `Update available: 1.1.0 → 1.2.0. Run 'wt --update' to install.`)
- [ ] `wt --update --check` just checks without installing
- [ ] Shows changelog summary of what changed
- [ ] Backs up current installation before updating
- [ ] Handles network errors gracefully (no crash, just skip)
- [ ] Check frequency: at most once per day (cached check result)

**Technical Notes:**

- Use GitHub API (`api.github.com/repos/.../releases/latest`) to check version
- Cache last check timestamp in `~/.wt_update_check` or similar
- Download tarball and extract to install location
- Requires knowing the install path (from initial install — store in a config file)
- Compare semver versions
- Non-blocking check: run in background subshell after main command completes

**Dependencies:** STORY-012 (needs `--version` to compare against latest)

---

### STORY-014: Add shell completions (bash + zsh)

**Phase:** Developer Experience
**Priority:** Should Have
**Points:** 5

**User Story:**
As a user
I want tab completion for `wt` commands and branch names
So that I can work faster and discover available options

**Acceptance Criteria:**

- [ ] Zsh completion: all flags (`-n`, `-s`, `-r`, `-o`, `-l`, `-c`, `-L`, `-U`, `-v`, `-h`), long forms, and dynamic branch names
- [ ] Bash completion: same coverage as zsh
- [ ] Dynamic completion of branch names for `-s`, `-r`, `-o` commands
- [ ] Dynamic completion of worktree paths where applicable
- [ ] Completions installed automatically during `install.sh`
- [ ] Completions work when sourced from `.zshrc` / `.bashrc`
- [ ] Documented in README

**Technical Notes:**

- Zsh: `compdef _wt wt` with `_arguments` for structured completions
- Bash: `complete -F _wt_completions wt` with `compgen`
- Dynamic completions: call `git worktree list` and `git branch` for real-time data
- Separate completion files: `completions/_wt` (zsh), `completions/wt.bash`
- Install script sources completion file from shell config

**Dependencies:** None

---

### STORY-015: Add more granular clear options

**Phase:** Developer Experience
**Priority:** Could Have
**Points:** 3

**User Story:**
As a developer
I want to clear worktrees using flexible filters (merged status, pattern, dry-run)
So that I have finer control over cleanup beyond just age

**Acceptance Criteria:**

- [ ] `wt -c --merged` — clear worktrees whose branches are merged into main
- [ ] `wt -c --pattern <glob>` — clear worktrees matching a branch name pattern
- [ ] `wt -c --dry-run` — show what would be cleared without deleting
- [ ] Filters combinable (e.g., `wt -c 30 --merged --dev-only`)
- [ ] Dry-run output clearly labeled as simulation
- [ ] Skips locked worktrees (existing behavior preserved)

**Technical Notes:**

- Merged detection: `git branch --merged <main-branch>`
- Pattern matching: shell glob against branch names
- Dry-run: reuse existing clear logic, skip delete step, prefix output with `[dry-run]`
- Extend existing `_cmd_clear` function

**Dependencies:** None

---

### STORY-016: Add worktree metadata tracking

**Phase:** UX Polish
**Priority:** Could Have
**Points:** 5

**User Story:**
As a developer
I want to annotate worktrees with a purpose/description and see creation dates
So that I remember why each worktree exists

**Acceptance Criteria:**

- [ ] `wt -n <branch> --note "description"` — attach note at creation
- [ ] `wt --note [branch] "text"` — update note on existing worktree (current worktree if no branch)
- [ ] `wt -l` shows notes and creation dates alongside existing columns
- [ ] Metadata stored in `.worktrees/metadata.json`
- [ ] Metadata auto-cleaned when worktree is removed
- [ ] Creation date auto-populated on worktree creation

**Technical Notes:**

- Manage `.worktrees/metadata.json` with jq
- Schema: `{ "<branch>": { "created": "2026-02-08", "note": "fixing login bug" } }`
- Auto-populate `created` in `_wt_create`
- Clean up entry in `_cmd_remove`
- Display in `_cmd_list` (truncate long notes)

**Dependencies:** None

---

### STORY-017: Create Homebrew formula

**Phase:** Distribution
**Priority:** Could Have
**Points:** 3

**User Story:**
As a macOS user
I want to install `wt` via Homebrew
So that I can use a familiar package manager and get updates easily

**Acceptance Criteria:**

- [ ] Homebrew formula (`Formula/worktree-helpers.rb`) created
- [ ] Formula downloads release tarball from GitHub
- [ ] `brew install` places files correctly and shows caveats
- [ ] `brew upgrade` works for version updates
- [ ] Dependencies declared: git, jq
- [ ] Published to a tap (`homebrew-worktree-helpers`)
- [ ] Installation documented in README

**Technical Notes:**

- Create separate `homebrew-tap` repository
- Formula: URL, SHA256, install method, caveats
- Test with `brew install --build-from-source`
- Caveats: remind user to add `source` line to shell config

**Dependencies:** None

---

### STORY-018: Create oh-my-zsh / zinit plugin

**Phase:** Distribution
**Priority:** Could Have
**Points:** 2

**User Story:**
As a zsh user
I want to install `wt` as a zsh plugin
So that it integrates with my existing plugin manager

**Acceptance Criteria:**

- [ ] `worktree-helpers.plugin.zsh` entry point works with oh-my-zsh
- [ ] zinit one-liner installation works: `zinit light <user>/worktree-helpers`
- [ ] antigen and sheldon installation documented
- [ ] Plugin auto-sources `wt.sh` and completions
- [ ] README documents all plugin installation methods

**Technical Notes:**

- oh-my-zsh: create `.plugin.zsh` file that sources `wt.sh` + completions
- zinit/antigen: repo structure already compatible, just needs the entry point
- Test with oh-my-zsh custom plugins directory

**Dependencies:** None (but benefits from STORY-014 completions)

---

### STORY-019: Add `wt --rename` command

**Phase:** Developer Experience
**Priority:** Could Have
**Points:** 3

**User Story:**
As a developer
I want to rename my current worktree's branch
So that I can fix typos or update branch names without recreating the worktree

**Scope adjustment (per user request):**

- `wt --rename <new-branch>` — renames the **current** worktree's branch (no need to specify old branch)

**Acceptance Criteria:**

- [ ] `wt --rename <new-branch>` renames current worktree's branch
- [ ] Worktree directory renamed to match new branch name
- [ ] Remote tracking branch updated if remote branch exists
- [ ] Metadata updated (if STORY-016 is done)
- [ ] Error if not inside a worktree
- [ ] Error if new branch name already exists
- [ ] Confirmation prompt before rename (bypass with `-f`)

**Technical Notes:**

- Detect current branch: `git rev-parse --abbrev-ref HEAD`
- Rename branch: `git branch -m <old> <new>`
- Move worktree: `git worktree move <old-path> <new-path>`
- Update remote tracking: `git branch -u origin/<new> <new>` (if remote exists)
- Handle: renaming while inside the worktree (cd to new path)

**Dependencies:** None

---

### STORY-022: Improve wt --init worktrees path prompt

**Phase:** Developer Experience
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer
I want `wt --init` to suggest a clearer default worktrees directory path
So that the initial setup is more intuitive

**Dependencies:** None

---

### STORY-023: Add `--from`/`-b` flag to `wt -n` for custom base branch

**Phase:** Developer Experience
**Priority:** Should Have
**Points:** 2
**Status:** Done

**User Story:**
As a developer
I want to specify a custom base branch when creating a new worktree
So that I can branch off any ref, not just main or dev

**Dependencies:** None

---

### STORY-024: Fix race condition in concurrent worktree creation

**Phase:** Core Reliability
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer
I want concurrent `wt -n` calls to not fail with config lock errors
So that I can safely open multiple worktrees in parallel

**Dependencies:** None

---

### STORY-025: Improve UX when opening worktree from existing branch

**Phase:** Developer Experience
**Priority:** Must Have
**Points:** 5

**User Story:**
As a developer using `wt`
I want clear guidance and correct behavior when working with existing branches
So that I don't waste time debugging cryptic errors and can quickly open worktrees from branches that already exist

**Acceptance Criteria:**

- [ ] `wt -n <existing-branch>` suggests `wt -o <branch>` instead of bare "Branch exists"
- [ ] `_wt_open` passes `origin/<branch>` as base ref to hook (not bare branch name)
- [ ] After worktree creation, `_wt_open` fast-forwards to `origin/<branch>` if available
- [ ] Fast-forward is non-fatal (warning only)

**Dependencies:** None

---

## Dependency Graph

```
STORY-009 (Tests - 8pts)
    └── STORY-010 (CI/CD - 3pts)

STORY-012 (--version - 1pt)
    └── STORY-013 (--update - 5pts)

STORY-011 (dirty status - 3pts)     ── independent
STORY-014 (completions - 5pts)      ── independent
STORY-015 (granular clear - 3pts)   ── independent
STORY-016 (metadata - 5pts)         ── independent
STORY-017 (Homebrew - 3pts)         ── independent
STORY-018 (zsh plugin - 2pts)       ── independent (benefits from 014)
STORY-019 (--rename - 3pts)         ── independent
STORY-020 (uninstall - 2pts)        ── independent
STORY-022 (--init path - 2pts)      ── independent
STORY-023 (--from flag - 2pts)      ── independent (DONE)
STORY-024 (race condition - 3pts)   ── independent
STORY-025 (open existing - 5pts)    ── independent
STORY-026 (remove worktreesDir - 3pts) ── independent
```

---

## Sprint Allocation

### Sprint 3 (Weeks 5-6) — 15/17 points

**Goal:** Establish quality infrastructure with tests, CI, and essential CLI improvements

**Stories:**

| Story ID | Title | Points | Priority | Blocked By |
|----------|-------|--------|----------|------------|
| STORY-009 | Add test suite with BATS | 8 | Must Have | — |
| STORY-010 | Add CI/CD pipeline (shellcheck + tests) | 3 | Must Have | STORY-009 |
| STORY-012 | Add `--version` flag | 1 | Should Have | — |
| STORY-019 | Add `wt --rename` command | 3 | Could Have | — |
| STORY-020 | Add uninstall script | 2 | Should Have | — |

**Total:** 17 points / 17 capacity (100% utilization)

**Sprint 3 Deliverables:**

- Full test suite with BATS
- GitHub Actions CI (shellcheck + tests)
- `wt -v` / `wt --version`
- `wt --rename <new-branch>` from current worktree
- `wt --uninstall` / `uninstall.sh` script

**Implementation Order:**

1. STORY-012 (1pt, quick win — Day 1)
2. STORY-019 (3pts — Days 1-2)
3. STORY-009 (8pts — Days 2-8)
4. STORY-010 (3pts — Days 8-10, after tests exist)

**Risks:**

- Test suite may take longer than estimated if edge cases are complex
- Shellcheck may reveal issues requiring fixes

**Buffer:** 0 points (at full capacity)

---

### Sprint 4 (Weeks 7-8) — 17/17 points

**Goal:** Fix core reliability issues, improve existing branch UX, and polish init/clear workflows

**Stories:**

| Story ID | Title | Points | Priority | Status |
|----------|-------|--------|----------|--------|
| STORY-023 | Add `--from`/`-b` flag to `wt -n` | 2 | Should Have | Done |
| STORY-024 | Fix race condition in concurrent worktree creation | 3 | Must Have | Not Started |
| STORY-025 | Improve UX when opening worktree from existing branch | 5 | Must Have | Not Started |
| STORY-026 | Remove worktreesDir from config, always auto-derive | 3 | Must Have | Not Started |
| STORY-022 | Improve `wt --init` worktrees path prompt | 2 | Should Have | Not Started |
| STORY-015 | Add more granular clear options | 3 | Could Have | Not Started |

**Total:** 18 points remaining + 2 done = 20 points committed

**Sprint 4 Deliverables:**

- `wt -n --from <ref>` custom base branch (done)
- Race condition fix for concurrent worktree creation
- Better error messages when branch exists + hook fetch fix + FF after open
- Remove `worktreesDir` from config, always auto-derive path
- Improved `--init` path prompt
- `--merged`, `--pattern`, `--dry-run` flags for `wt -c`

**Implementation Order:**

1. STORY-024 (3pts — Days 1-2, Must Have bug fix)
2. STORY-025 (5pts — Days 2-5, Must Have UX fix)
3. STORY-026 (3pts — Days 5-7, Must Have simplification + bug fix)
4. STORY-022 (2pts — Days 7-8)
5. STORY-015 (3pts — Days 8-10)

**Risks:**

- STORY-025 FF logic has edge cases (diverged branches, no remote)
- STORY-024 config lock retry needs cross-platform testing

**Buffer:** 2 points (STORY-023 already done)

---

### Sprint 5 (Weeks 9-10) — 15/17 points

**Goal:** Enhance developer experience with update mechanism and completions

**Stories:**

| Story ID | Title | Points | Priority | Blocked By |
|----------|-------|--------|----------|------------|
| STORY-013 | Add self-update mechanism (`wt --update`) | 5 | Should Have | STORY-012 |
| STORY-014 | Add shell completions (bash + zsh) | 5 | Should Have | — |
| STORY-011 | Show dirty/clean status in `wt -l` | 3 | Should Have | — |
| STORY-018 | Create oh-my-zsh / zinit plugin | 2 | Could Have | — |

**Total:** 15 points / 17 capacity (88% utilization)

**Sprint 5 Deliverables:**

- Non-blocking update check + `wt --update`
- Tab completion for bash and zsh
- Dirty/clean indicators in `wt -l`
- oh-my-zsh / zinit plugin

**Implementation Order:**

1. STORY-013 (5pts — Days 1-4)
2. STORY-014 (5pts — Days 1-5, parallel with 013)
3. STORY-011 (3pts — Days 5-7)
4. STORY-018 (2pts — Days 7-8, benefits from 014)

**Risks:**

- Update mechanism has network/API complexity
- Completion systems differ significantly between bash and zsh

**Buffer:** 2 points for unexpected complexity

---

### Sprint 6 (Weeks 11-12) — 8/17 points

**Goal:** Polish UX and expand distribution channels

**Stories:**

| Story ID | Title | Points | Priority | Blocked By |
|----------|-------|--------|----------|------------|
| STORY-016 | Add worktree metadata tracking | 5 | Could Have | — |
| STORY-017 | Create Homebrew formula | 3 | Could Have | — |

**Total:** 8 points / 17 capacity (47% utilization)

**Sprint 6 Deliverables:**

- Worktree notes and creation dates
- `brew install` support

**Implementation Order:**

1. STORY-016 (5pts — Days 1-4)
2. STORY-017 (3pts — Days 4-6)

**Risks:**

- Homebrew tap requires separate repo setup
- Metadata storage may need design iteration

**Buffer:** 9 points — room for new stories or spillover

---

## Requirements Coverage

| Requirement Source | Story | Sprint |
|--------------------|-------|--------|
| Repo gap: No test suite | STORY-009 | 3 |
| Repo gap: No CI/CD | STORY-010 | 3 |
| Codebase: Missing --version | STORY-012 | 3 |
| UX: Branch rename | STORY-019 | 3 |
| DX: Clean uninstall | STORY-020 | 3 |
| DX: Custom base branch for -n | STORY-023 | 4 (Done) |
| Core: Race condition fix | STORY-024 | 4 |
| UX: Existing branch worktree flow | STORY-025 | 4 |
| Core: Remove worktreesDir, auto-derive | STORY-026 | 4 |
| DX: Init path prompt | STORY-022 | 4 |
| v1.1 scope: Granular clear options | STORY-015 | 4 |
| v1.1 scope: Update mechanism | STORY-013 | 5 |
| UX: Shell completions | STORY-014 | 5 |
| v1.1 scope: Worktree status (dirty/clean) | STORY-011 | 5 |
| Distribution: zsh plugin | STORY-018 | 5 |
| UX: Worktree metadata | STORY-016 | 6 |
| Distribution: Homebrew | STORY-017 | 6 |

---

## Risks and Mitigation

**Medium:**

- **BATS test complexity** — Shell testing is harder than typical unit testing. Mitigation: start with simple tests, iterate.
- **Shellcheck findings** — May surface issues requiring code changes. Mitigation: buffer points allocated.
- **Update mechanism network issues** — GitHub API rate limits, offline usage. Mitigation: graceful fallback, cached checks.
- **Completion system differences** — bash and zsh completions are fundamentally different. Mitigation: separate files, test each independently.

**Low:**

- **Homebrew tap maintenance** — Requires separate repo and formula updates per release. Mitigation: automate with GitHub Actions.
- **Metadata file conflicts** — Multiple worktrees writing to same metadata file. Mitigation: file locking or per-worktree metadata.

---

## Dependencies

**External:**

- Git 2.15+ (for worktree features)
- jq (JSON parsing)
- fzf (optional, for interactive selection)
- GitHub API (for update mechanism)
- BATS (for testing — installed as dev dependency)
- Shellcheck (for CI — available as GitHub Action)

**Internal Story Dependencies:**

```
Sprint 3 (COMPLETE):
  STORY-012 (--version) ─── no deps ✓
  STORY-019 (--rename) ─── no deps ✓
  STORY-009 (tests) ─── no deps ✓
  STORY-010 (CI/CD) ─── blocked by STORY-009 ✓
  STORY-020 (uninstall) ── no deps ✓

Sprint 4 (CURRENT):
  STORY-023 (--from flag) ─── no deps ✓ DONE
  STORY-024 (race condition) ─── no deps
  STORY-025 (open existing branch UX) ─── no deps
  STORY-026 (remove worktreesDir) ─── no deps
  STORY-022 (--init path) ─── no deps
  STORY-015 (granular clear) ─── no deps

Sprint 5:
  STORY-013 (--update) ─── blocked by STORY-012
  STORY-014 (completions) ─── no deps
  STORY-011 (dirty status) ─── no deps
  STORY-018 (zsh plugin) ─── no deps (benefits from STORY-014)

Sprint 6:
  STORY-016 (metadata) ─── no deps
  STORY-017 (Homebrew) ─── no deps
```

---

## Definition of Done

For a story to be considered complete:

- [ ] Code implemented and tested manually
- [ ] BATS tests written for new functionality (after STORY-009)
- [ ] Shellcheck passes (after STORY-010)
- [ ] Works on both macOS and Linux (or documented limitation)
- [ ] Works in both zsh and bash
- [ ] Help text updated (if applicable)
- [ ] No regressions in existing functionality
- [ ] Code follows existing patterns (`_` prefix, `GWT_*` globals, POSIX-compatible)

---

## Next Steps

**Immediate:** Continue Sprint 4

Run `/bmad:dev-story STORY-024` to fix the race condition, or `/bmad:dev-story STORY-025` to improve the existing branch UX.

**Sprint cadence:**

- Sprint length: 2 weeks
- Sprint planning: Day 1
- Sprint review: Day 10
- Sprint retrospective: Day 10

---

## Progress Tracking

Last updated: 2026-02-12

**Sprint 3 (COMPLETE — 17/17 pts):**

- [x] STORY-009 — Add test suite with BATS (8pts)
- [x] STORY-010 — Add CI/CD pipeline (3pts)
- [x] STORY-012 — Add `--version` flag (1pt)
- [x] STORY-019 — Add `wt --rename` command (3pts)
- [x] STORY-020 — Add uninstall script (2pts)

**Sprint 4 (CURRENT — 2/17 pts done):**

- [x] STORY-023 — Add `--from`/`-b` flag to `wt -n` (2pts)
- [ ] STORY-024 — Fix race condition in concurrent worktree creation (3pts)
- [ ] STORY-025 — Improve UX when opening worktree from existing branch (5pts)
- [ ] STORY-026 — Remove worktreesDir from config, always auto-derive (3pts)
- [ ] STORY-022 — Improve `wt --init` worktrees path prompt (2pts)
- [ ] STORY-015 — Add more granular clear options (3pts)

**Sprint 5:**

- [ ] STORY-013 — Add self-update mechanism (5pts)
- [ ] STORY-014 — Add shell completions (5pts)
- [ ] STORY-011 — Show dirty/clean status in `wt -l` (3pts)
- [ ] STORY-018 — Create oh-my-zsh / zinit plugin (2pts)

**Sprint 6:**

- [ ] STORY-016 — Add worktree metadata tracking (5pts)
- [ ] STORY-017 — Create Homebrew formula (3pts)

---

**This plan was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
