# Sprint Plan: worktree-helpers v1.4+

**Date:** 2026-02-19
**Scrum Master:** Ruslan Horyn
**Project Level:** 1
**Total Stories:** 14
**Total Points:** 39
**Planned Sprints:** 3 (Sprints 6–8)

---

## Executive Summary

This sprint plan covers the v1.4+ development cycle for worktree-helpers. Building on
the solid foundation from Sprints 1–5 (53 pts delivered), this cycle focuses on three
themes: **critical bug fixes** from real-world usage (branch protection, slash-in-name
directory issues), **completions overhaul** (Warp + zsh compatibility, per-command help,
usage hints), and **UX polish** (verbose output, init improvements, metadata tracking).

**Key Metrics:**

- Total Stories: 14
- Total Points: 39
- Sprints: 3
- Team Capacity: 17 points per sprint
- Historical Velocity: 16.8 pts/sprint (rolling average, 5 sprints)
- Sprints 1–5 completed: 84 pts delivered

---

## Team Capacity

| Parameter | Value |
|-----------|-------|
| Team Size | 1 developer |
| Sprint Length | 2 weeks (10 workdays) |
| Productive Hours/Day | 5 hours |
| Total Hours/Sprint | 50 hours |
| Points per Sprint | ~17 points |
| Historical Velocity | S1: 14, S2: 17, S3: 17, S4: 18, S5: 18 (avg: 16.8) |

---

## Story Inventory

### STORY-029: Protect main/dev branches from `wt -c` deletion

**Epic:** Core Reliability
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer using `wt -c`
I want the clear command to never delete protected branches (main, dev)
So that I don't accidentally lose my primary development branch

**Acceptance Criteria:**

- [ ] `wt -c` never deletes worktrees whose branch matches `GWT_MAIN_REF` or `GWT_DEV_REF`
- [ ] `wt -c` never deletes worktrees whose branch is any of: `main`, `master`, `dev`, `develop`
- [ ] Skipped protected worktrees print: `Skipping <branch>: protected branch`
- [ ] `--dry-run` marks protected worktrees as `[protected — skipped]`
- [ ] Protection applies to all clear variants (`--merged`, `--pattern`, age-based)

**Dependencies:** None

---

### STORY-031: Replace slashes with dashes in worktree directory names

**Epic:** Core Reliability
**Priority:** Must Have
**Points:** 2

**User Story:**
As a developer working with Jira-style branch names like `bugfix/CORE-615-foo`
I want `wt -n bugfix/CORE-615-foo` to create a flat directory `bugfix-CORE-615-foo`
So that worktrees don't accidentally create nested subdirectories

**Acceptance Criteria:**

- [ ] `wt -n bugfix/CORE-615-foo` creates `<worktreesDir>/bugfix-CORE-615-foo`
- [ ] `wt -n feature/my-feature` creates `<worktreesDir>/feature-my-feature`
- [ ] Branch name preserved exactly; only the directory name uses dashes
- [ ] Same sanitisation applies to `wt -o`

**Dependencies:** None

---

### STORY-030: Fix completions in Warp + zsh to work like git

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 5

**User Story:**
As a developer using Warp terminal with zsh
I want `wt` tab completions to work the same way `git` completions do
So that I can complete branch names, worktree names, and flags without leaving the keyboard

**Acceptance Criteria:**

- [ ] `wt <TAB>` shows all flags in Warp + zsh
- [ ] `wt -s <TAB>` completes existing worktree names in Warp + zsh
- [ ] `wt -o <TAB>` completes local branch names in Warp + zsh
- [ ] `wt -r <TAB>` completes existing worktree names in Warp + zsh
- [ ] `wt --from <TAB>` completes git refs in Warp + zsh
- [ ] All existing completion behaviour preserved in standard zsh

**Dependencies:** STORY-014 (source), STORY-028 (context)

---

### STORY-032: Show only worktree name instead of full path everywhere

**Epic:** UX Polish
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer with a long worktrees path
I want every `wt` command to show just the worktree name, not the full absolute path
So that all output is readable and not cluttered with irrelevant path prefixes

**Acceptance Criteria:**

- [ ] `wt -l` displays only the worktree name, not the full path
- [ ] `wt -n` success message shows worktree name, not full path
- [ ] `wt -r` / `wt -s` fzf picker entries show only worktree name
- [ ] `wt -c` output shows worktree name, not full path
- [ ] All other commands that print paths updated consistently
- [ ] Shared `_wt_display_name` helper used across all commands

**Dependencies:** None

---

### STORY-033: Prompt to re-source after `wt --update`

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer who just ran `wt --update`
I want a clear prompt telling me how to activate the new version
So that I don't have to open a new terminal or figure out re-sourcing on my own

**Acceptance Criteria:**

- [ ] After a successful update, prints the install path and `source` command
- [ ] If already on latest: `Already up to date` (no re-source prompt)
- [ ] If update fails: no re-source prompt shown

**Dependencies:** STORY-013

---

### STORY-036: Per-command help (`wt <cmd> --help`)

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer who can't remember exact flag syntax
I want to run `wt -n --help` and see detailed help for just that command
So that I get focused, actionable information without reading the full help screen

**Acceptance Criteria:**

- [ ] `wt <cmd> --help` works for all main commands (`-n`, `-s`, `-o`, `-r`, `-l`, `-c`, `--init`, `--update`)
- [ ] Each shows: description, usage with placeholders, 2-3 concrete examples
- [ ] `--help` takes priority over running the command

**Dependencies:** STORY-038 (share placeholder style)

---

### STORY-034: Add verbose feedback to `wt -c` and `wt --init`

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer running `wt -c` or `wt --init`
I want to see step-by-step output of what the command is doing
So that I understand what happened and can diagnose failures

**Acceptance Criteria:**

- [ ] `wt -c`: prints decision per worktree + summary `Cleared X worktree(s)`
- [ ] `wt -c`: `No worktrees to clear` if nothing matches
- [ ] `wt --init`: prints each step (creating config, setting up hooks, etc.)
- [ ] `wt --init`: prints `✓ Done` with summary on success

**Dependencies:** None

---

### STORY-035: `wt --init` — offer to copy/backup existing hooks

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer re-initialising `wt` in a repo that already has hooks
I want to be asked whether to preserve my existing hooks
So that I don't accidentally lose custom hook scripts

**Acceptance Criteria:**

- [ ] Detects if hooks directory already contains files
- [ ] Prompts: keep / backup / overwrite (default: keep)
- [ ] Backup moves hooks to `<hooksDir>.bak/`
- [ ] Non-interactive mode defaults to keep

**Dependencies:** STORY-034

---

### STORY-037: Completions — show example usage hint when nothing to suggest

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer pressing `<TAB>` after a command that takes a free-form argument
I want to see an example placeholder rather than nothing
So that I know what to type without consulting the docs

**Acceptance Criteria:**

- [ ] `wt -n <TAB>` shows `<branch>` with description `new branch name`
- [ ] `wt --from <TAB>` shows `<ref>` with description `branch, tag, or commit`
- [ ] Works in both zsh and bash
- [ ] Existing dynamic completions unaffected

**Dependencies:** STORY-030

---

### STORY-038: Descriptive usage with placeholders in command output

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer reading `wt` command output or help text
I want to see concrete usage examples with real placeholders alongside flag descriptions
So that I immediately understand how to use each command without guessing

**Acceptance Criteria:**

- [ ] `wt -h` shows `<argument>` placeholder next to each flag that takes an argument
- [ ] Each flag entry includes 1-2 concrete example lines
- [ ] Consistent placeholder naming: `<branch>`, `<worktree>`, `<ref>`, `<days>`, `<pattern>`
- [ ] Same style used across `wt -h`, per-command help, and completion hints

**Dependencies:** STORY-036

---

### STORY-021: Improve `wt --init` UX

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer setting up `wt` in a new project
I want `wt --init` to be colorized, suggest hook templates, and auto-update `.gitignore`
So that the initial setup is fast, clear, and complete

**Acceptance Criteria:**

- [ ] Colorized output for success/warning/error messages
- [ ] Suggests hook templates based on detected project type
- [ ] Auto-adds `.worktrees/` to `.gitignore` if not present
- [ ] Summary of what was created at the end

**Dependencies:** STORY-034, STORY-035

---

### STORY-016: Add worktree metadata tracking

**Epic:** UX Polish
**Priority:** Could Have
**Points:** 5

**User Story:**
As a developer
I want to annotate worktrees with a purpose/description and see creation dates
So that I remember why each worktree exists

**Acceptance Criteria:**

- [ ] `wt -n <branch> --note "description"` — attach note at creation
- [ ] `wt -l` shows notes and creation dates
- [ ] Metadata stored in `.worktrees/metadata.json`
- [ ] Metadata auto-cleaned when worktree is removed

**Dependencies:** None

---

### STORY-017: Create Homebrew formula

**Epic:** Distribution
**Priority:** Could Have
**Points:** 3

**User Story:**
As a macOS user
I want to install `wt` via Homebrew
So that I can use a familiar package manager and get updates easily

**Acceptance Criteria:**

- [ ] Homebrew formula created and published to a tap
- [ ] `brew install` places files correctly with caveats
- [ ] Dependencies declared: git, jq
- [ ] Installation documented in README

**Dependencies:** None

---

### STORY-018: Create oh-my-zsh / zinit plugin

**Epic:** Distribution
**Priority:** Could Have
**Points:** 2

**User Story:**
As a zsh user
I want to install `wt` as a zsh plugin
So that it integrates with my existing plugin manager

**Acceptance Criteria:**

- [ ] Works with oh-my-zsh custom plugins
- [ ] zinit one-liner installation works
- [ ] Plugin auto-sources `wt.sh` and completions

**Dependencies:** None

---

## Sprint Allocation

### Sprint 6 (2026-02-23 → 2026-03-08) — 17/17 points

**Goal:** Fix critical bugs from real-world usage and overhaul completions

| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-029 | Protect main/dev branches from `wt -c` deletion | 3 | Must Have |
| STORY-031 | Replace slashes with dashes in worktree directory names | 2 | Must Have |
| STORY-030 | Fix completions in Warp + zsh to work like git | 5 | Should Have |
| STORY-032 | Show only worktree name instead of full path everywhere | 2 | Should Have |
| STORY-033 | Prompt to re-source after `wt --update` | 2 | Should Have |
| STORY-036 | Per-command help (`wt <cmd> --help`) | 3 | Should Have |

**Implementation Order:**

1. STORY-029 (3pts — Days 1-2, critical safety)
2. STORY-031 (2pts — Days 2-3, critical safety)
3. STORY-032 (2pts — Day 3, quick UX fix)
4. STORY-033 (2pts — Day 4, quick DX fix)
5. STORY-030 (5pts — Days 4-8, completions investigation + fix)
6. STORY-036 (3pts — Days 8-10, per-command help)

---

### Sprint 7 (2026-03-09 → 2026-03-22) — 17/17 points

**Goal:** Polish CLI output, init experience, and add worktree metadata

| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-034 | Add verbose feedback to `wt -c` and `wt --init` | 3 | Should Have |
| STORY-035 | `wt --init` — offer to copy/backup existing hooks | 2 | Should Have |
| STORY-037 | Completions: show example usage hint when nothing to suggest | 2 | Should Have |
| STORY-038 | Descriptive usage with placeholders in command output | 2 | Should Have |
| STORY-021 | Improve `wt --init` UX (colorized, hook suggestions, .gitignore) | 3 | Should Have |
| STORY-016 | Add worktree metadata tracking | 5 | Could Have |

**Implementation Order:**

1. STORY-034 (3pts — Days 1-3)
2. STORY-035 (2pts — Days 3-4)
3. STORY-021 (3pts — Days 4-6)
4. STORY-038 (2pts — Days 6-7)
5. STORY-037 (2pts — Days 7-8)
6. STORY-016 (5pts — Days 8-10)

---

### Sprint 8 (2026-03-23 → 2026-04-05) — 5/17 points

**Goal:** Expand distribution channels

| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-017 | Create Homebrew formula | 3 | Could Have |
| STORY-018 | Create oh-my-zsh / zinit plugin | 2 | Could Have |

**Buffer:** 12 points — room for stories discovered in Sprints 6-7

---

## Dependency Graph

```
STORY-029 (protect branches)     ── independent
STORY-031 (slash→dash dirs)      ── independent
STORY-030 (Warp completions)     ── independent
  └── STORY-037 (completion hints) ── after STORY-030
STORY-032 (display names)        ── independent
STORY-033 (re-source prompt)     ── independent
STORY-034 (verbose feedback)     ── independent
  └── STORY-035 (init hooks)    ── after STORY-034
  └── STORY-021 (init UX)       ── after STORY-034, STORY-035
STORY-036 (per-cmd help)         ── independent
  └── STORY-038 (placeholders)  ── after STORY-036
STORY-016 (metadata)             ── independent
STORY-017 (Homebrew)             ── independent
STORY-018 (zsh plugin)           ── independent
```

---

## Definition of Done

For a story to be considered complete:

- [ ] Code implemented and tested manually
- [ ] BATS tests written for new functionality
- [ ] Shellcheck passes
- [ ] Works on both macOS and Linux (or documented limitation)
- [ ] Works in both zsh and bash
- [ ] Help text updated (if applicable)
- [ ] No regressions in existing functionality
- [ ] Code follows existing patterns (`_` prefix, `GWT_*` globals, POSIX-compatible)

---

## Progress Tracking

**Sprint 6 (NEXT — 0/17 pts):**

- [ ] STORY-029 — Protect main/dev branches from `wt -c` deletion (3pts) **MUST HAVE**
- [ ] STORY-031 — Replace slashes with dashes in worktree directory names (2pts) **MUST HAVE**
- [ ] STORY-030 — Fix completions in Warp + zsh to work like git (5pts)
- [ ] STORY-032 — Show only worktree name instead of full path everywhere (2pts)
- [ ] STORY-033 — Prompt to re-source after `wt --update` (2pts)
- [ ] STORY-036 — Per-command help (`wt <cmd> --help`) (3pts)

**Sprint 7:**

- [ ] STORY-034 — Verbose feedback to `wt -c` and `wt --init` (3pts)
- [ ] STORY-035 — `wt --init` offer to copy/backup existing hooks (2pts)
- [ ] STORY-037 — Completions: example usage hints (2pts)
- [ ] STORY-038 — Descriptive usage with placeholders (2pts)
- [ ] STORY-021 — Improve `wt --init` UX (3pts)
- [ ] STORY-016 — Add worktree metadata tracking (5pts)

**Sprint 8:**

- [ ] STORY-017 — Create Homebrew formula (3pts)
- [ ] STORY-018 — Create oh-my-zsh / zinit plugin (2pts)

---

**This plan was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
