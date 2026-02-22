# Sprint Plan: worktree-helpers v1.4+

**Date:** 2026-02-19 (updated 2026-02-22)
**Scrum Master:** Ruslan Horyn
**Project Level:** 1
**Total Stories:** 22
**Total Points:** 77
**Planned Sprints:** 5 (Sprints 6–10)

---

## Executive Summary

This sprint plan covers the v1.4+ development cycle for worktree-helpers. Building on
the solid foundation from Sprints 1–5 (84 pts delivered), this cycle focuses on:

- **Sprint 6** (COMPLETE — 17pts): Critical bug fixes from real-world usage and completions overhaul
- **Sprint 7** (ACTIVE — 17pts): Docs audit, CLI polish, init UX, dry-run readability
- **Sprint 8** (PLANNED — 16pts): Metadata tracking, new commands (run/repair/skip-hook), Homebrew
- **Sprint 9** (PLANNED — 13pts): Distribution plugin, detach mode, smart hooks, multi-select
- **Sprint 10** (PLANNED — 8pts): Major codebase refactor

**Key Metrics:**

- Total Stories Remaining: 16 (Sprint 7–10)
- Total Points Remaining: 54
- Historical Velocity: 16.8 pts/sprint (Sprints 1–6 average)
- Sprints 1–6 completed: 101 pts delivered

---

## Team Capacity

| Parameter | Value |
|-----------|-------|
| Team Size | 1 developer |
| Sprint Length | 2 weeks (10 workdays) |
| Productive Hours/Day | 5 hours |
| Total Hours/Sprint | 50 hours |
| Points per Sprint | ~17 points |
| Historical Velocity | S1: 14, S2: 17, S3: 17, S4: 18, S5: 18, S6: 17 (avg: 16.8) |

---

## Story Inventory

### Completed Sprints (reference only)

Sprints 1–6 complete. See sprint-status.yaml for full history.

---

### Sprint 7 Stories

#### STORY-047: Documentation audit — align README and per-command `--help` with current state

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer discovering `wt` for the first time (or returning after a gap)
I want the README and per-command `--help` to accurately reflect all current features
So that I can understand the tool without reading source code

**Acceptance Criteria:**
- [ ] All 8 `_help_*` functions audited and gaps corrected
- [ ] `_cmd_help` (wt -h) matches actual command set including `--rename`, `-L`/`-U`, `--log`
- [ ] README "Commands" section covers all user-facing commands with descriptions
- [ ] README "Shell Completions" has "Known Limitations" subsection (Warp workaround)
- [ ] `docs/hooks.md` arg table (`$1–$4`) consistent with README
- [ ] `CLAUDE.md` updated with DoD requirement for user-visible changes

**Dependencies:** STORY-036 (completed)

**Story doc:** docs/stories/STORY-047.md

---

#### STORY-034: Add verbose feedback to `wt -c` and `wt --init`

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

**Story doc:** docs/stories/STORY-034.md

---

#### STORY-035: `wt --init` — offer to copy/backup existing hooks

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

**Story doc:** docs/stories/STORY-035.md

---

#### STORY-037: Completions — show example usage hint when nothing to suggest

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

**Story doc:** docs/stories/STORY-037.md

---

#### STORY-038: Descriptive usage with placeholders in command output

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

**Story doc:** docs/stories/STORY-038.md

---

#### STORY-039: Improve `wt -c` dry-run output readability

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer running `wt -c --dry-run`
I want the output to be clearly formatted and easy to scan
So that I can confidently decide whether to run the actual clear

**Acceptance Criteria:**
- [ ] Dry-run output uses distinct visual style (e.g., `[DRY RUN]` prefix or color)
- [ ] Protected worktrees clearly labeled
- [ ] Summary line shows count of what would be removed

**Dependencies:** None

**Story doc:** docs/stories/STORY-039.md

---

#### STORY-021: Improve `wt --init` UX

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

**Story doc:** (existing)

---

### Sprint 8 Stories

#### STORY-016: Add worktree metadata tracking

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

**Story doc:** docs/stories/STORY-016.md

---

#### STORY-040: Run command in another worktree without switching (`wt --run`)

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 4

**User Story:**
As a developer working in one worktree
I want to run a command in a different worktree without switching to it
So that I can execute quick tasks (tests, linting, builds) without losing my current context

**Acceptance Criteria:**
- [ ] `wt --run <worktree> <cmd>` runs `<cmd>` in the target worktree's directory
- [ ] Exit code of `<cmd>` is preserved
- [ ] If no args: fzf picker for worktree, then prompt for command
- [ ] Hooks NOT triggered
- [ ] `wt --run --help` prints usage

**Dependencies:** None

**Story doc:** docs/stories/STORY-040.md

---

#### STORY-041: Repair corrupted worktree refs (`wt --repair`, `wt --prune`)

**Epic:** Core Reliability
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer who manually moved or deleted a worktree directory
I want `wt` to fix orphaned or corrupted `.git/worktrees` entries
So that `git worktree list` stays clean without manual intervention

**Acceptance Criteria:**
- [ ] `wt --prune` runs `git worktree prune` and reports what was cleaned
- [ ] `wt --prune --dry-run` shows what would be pruned without doing it
- [ ] `wt --repair [<path>]` runs `git worktree repair`

**Dependencies:** None

**Story doc:** docs/stories/STORY-041.md

---

#### STORY-043: Skip hooks flag (`--skip-hook`)

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer creating or switching worktrees in a scripted or CI context
I want to pass `--skip-hook` to suppress hook execution
So that I can use `wt` without triggering side effects (IDE opens, installs, etc.)

**Acceptance Criteria:**
- [ ] `--skip-hook` flag accepted by `wt -n`, `wt -s`, `wt -o`
- [ ] Hook script is still symlinked (just not executed)
- [ ] Info message: `[info] Hooks skipped (--skip-hook)`
- [ ] Silently ignored by commands that don't use hooks

**Dependencies:** None

**Story doc:** docs/stories/STORY-043.md

---

#### STORY-017: Create Homebrew formula

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

**Story doc:** docs/stories/STORY-017.md

---

### Sprint 9 Stories

#### STORY-018: Create oh-my-zsh / zinit plugin

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

**Story doc:** docs/stories/STORY-018.md

---

#### STORY-042: Throwaway worktree without branch (`wt -n --detach`)

**Epic:** Developer Experience
**Priority:** Could Have
**Points:** 3

**User Story:**
As a developer who wants to quickly test an older version or run a spike
I want to create a worktree in detached HEAD mode without creating a branch
So that I can experiment freely without polluting branch history

**Acceptance Criteria:**
- [ ] `wt -n --detach <ref>` creates a worktree with detached HEAD at `<ref>`
- [ ] `wt -l` shows `[detached @ <short-sha>]` for detached worktrees
- [ ] `wt -r` removes detached worktree normally
- [ ] `wt -n --detach -d` exits with error (mutually exclusive)

**Dependencies:** None

**Story doc:** docs/stories/STORY-042.md

---

#### STORY-044: Improve default hooks (smart templates, restore command, arg docs)

**Epic:** Developer Experience
**Priority:** Should Have
**Points:** 5

**User Story:**
As a developer setting up `wt` for the first time
I want the default hooks to contain useful, commented examples based on my project type
So that I can quickly configure my workflow without consulting external docs

**Acceptance Criteria:**
- [ ] `wt --init` detects project type (package.json, Makefile, go.mod, etc.)
- [ ] Generated hooks contain stack-relevant commented examples
- [ ] `wt --restore-hooks` restores both hooks using smart templates
- [ ] Every hook file includes `# Hook args: $1–$4` comment block

**Dependencies:** STORY-034, STORY-035

**Story doc:** docs/stories/STORY-044.md

---

#### STORY-045: Multi-select for `wt -r` and other commands

**Epic:** Developer Experience
**Priority:** Could Have
**Points:** 3

**User Story:**
As a developer who wants to remove or act on multiple worktrees at once
I want fzf multi-select in `wt -r`, `wt -L`, and `wt -U`
So that I can handle batch operations without repeating the same command

**Acceptance Criteria:**
- [ ] `wt -r` (no args) opens fzf with `--multi` enabled (Tab to select multiple)
- [ ] Confirmation prompt shows count: `Remove N worktrees? [y/N]`
- [ ] `wt -L` and `wt -U` also support multi-select
- [ ] Empty selection (Esc) exits cleanly

**Dependencies:** None

**Story doc:** docs/stories/STORY-045.md

---

### Sprint 10 Stories

#### STORY-046: Code refactoring — SOLID, DRY, KISS, one file per command

**Epic:** Technical Debt
**Priority:** Should Have
**Points:** 8

**User Story:**
As a developer maintaining and extending the `wt` codebase
I want the code organized with one file per command and no duplicated logic
So that each module is independently understandable, testable, and editable

**Acceptance Criteria:**
- [ ] `lib/` restructured into `lib/core/` and `lib/cmd/` (one file per command)
- [ ] All existing BATS tests pass unchanged
- [ ] `shellcheck` passes on all files
- [ ] No function duplicated across files (DRY)
- [ ] `_cmd_clear` decomposed into sub-functions (none >40 lines)

**Dependencies:** Ideally after STORY-040–045 (but can go independently)

**Story doc:** docs/stories/STORY-046.md

---

## Sprint Allocation

### Sprint 6 (2026-02-19 → 2026-02-21) — 17/17 points ✅ COMPLETE

**Goal:** Fix critical bugs from real-world usage and overhaul completions

| Story ID | Title | Points | Status |
|----------|-------|--------|--------|
| STORY-029 | Protect main/dev branches from `wt -c` deletion | 3 | ✅ Done |
| STORY-031 | Replace slashes with dashes in worktree directory names | 2 | ✅ Done |
| STORY-030 | Fix completions in Warp + zsh to work like git | 5 | ✅ Done |
| STORY-032 | Show only worktree name instead of full path everywhere | 2 | ✅ Done |
| STORY-033 | Prompt to re-source after `wt --update` | 2 | ✅ Done |
| STORY-036 | Per-command help (`wt <cmd> --help`) | 3 | ✅ Done |

---

### Sprint 7 (2026-02-22 → 2026-03-07) — 17/17 points 🔄 ACTIVE

**Goal:** Docs audit, CLI output polish, init UX overhaul

**Rebalanced from original plan:**
- ➕ Added STORY-047 (3pts — Sprint 6 retro action item)
- ➕ Added STORY-039 (2pts — dry-run readability)
- ➖ Deferred STORY-016 (5pts, could_have) → Sprint 8

| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-047 | Documentation audit — align README and --help | 3 | Should Have |
| STORY-034 | Add verbose feedback to `wt -c` and `wt --init` | 3 | Should Have |
| STORY-035 | `wt --init` — offer to copy/backup existing hooks | 2 | Should Have |
| STORY-038 | Descriptive usage with placeholders in command output | 2 | Should Have |
| STORY-037 | Completions: show example usage hint when nothing to suggest | 2 | Should Have |
| STORY-039 | Improve `wt -c` dry-run output readability | 2 | Should Have |
| STORY-021 | Improve `wt --init` UX (colorized, auto .gitignore) | 3 | Should Have |

**Implementation Order:**

1. STORY-047 (3pts — Days 1-2, docs audit; unblocks clear DoD for rest of sprint)
2. STORY-034 (3pts — Days 2-4, verbose feedback foundation)
3. STORY-035 (2pts — Days 4-5, init hook backup; unblocks STORY-021)
4. STORY-039 (2pts — Days 5-6, dry-run polish)
5. STORY-021 (3pts — Days 6-8, init UX; requires STORY-034+035)
6. STORY-038 (2pts — Days 8-9, placeholder usage)
7. STORY-037 (2pts — Days 9-10, completion hints)

---

### Sprint 8 (2026-03-09 → 2026-03-22) — 16/17 points

**Goal:** Metadata tracking, new execution/repair commands, distribution start

| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-016 | Add worktree metadata tracking | 5 | Could Have |
| STORY-040 | Run command in another worktree (`wt --run`) | 4 | Should Have |
| STORY-041 | Repair corrupted worktree refs (`wt --repair`, `wt --prune`) | 2 | Should Have |
| STORY-043 | Skip hooks flag (`--skip-hook`) | 2 | Should Have |
| STORY-017 | Create Homebrew formula | 3 | Could Have |

**Total:** 16 points (1pt buffer)

**Implementation Order:**

1. STORY-041 (2pts — Days 1-2, thin wrappers; quick win)
2. STORY-043 (2pts — Days 2-3, skip-hook flag)
3. STORY-040 (4pts — Days 3-6, wt --run)
4. STORY-016 (5pts — Days 6-9, metadata tracking)
5. STORY-017 (3pts — Days 9-10, Homebrew formula)

---

### Sprint 9 (2026-03-23 → 2026-04-05) — 13/17 points

**Goal:** Plugin distribution, detached HEAD mode, smart hooks, multi-select

**Note:** 4pt buffer for stories discovered during Sprint 8.

| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-018 | Create oh-my-zsh / zinit plugin | 2 | Could Have |
| STORY-042 | Throwaway worktree without branch (`wt -n --detach`) | 3 | Could Have |
| STORY-044 | Improve default hooks (smart templates, restore command) | 5 | Should Have |
| STORY-045 | Multi-select for `wt -r` and other commands | 3 | Could Have |

**Total:** 13 points (4pt buffer)

**Implementation Order:**

1. STORY-018 (2pts — Days 1-2, plugin distribution)
2. STORY-042 (3pts — Days 2-4, detach mode)
3. STORY-044 (5pts — Days 4-8, smart hooks; requires S7 STORY-034+035 done)
4. STORY-045 (3pts — Days 8-10, multi-select)

---

### Sprint 10 (2026-04-06 → 2026-04-19) — 8/17 points

**Goal:** Structural refactor for long-term maintainability

**Note:** 9pt buffer — groom new backlog items to fill. This sprint is intentionally
smaller to allow the refactor to land cleanly without time pressure.

| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-046 | Code refactoring — SOLID, DRY, KISS, one file per command | 8 | Should Have |

**Total:** 8 points (9pt buffer)

**Implementation Order:**

1. STORY-046 (8pts — Full sprint, work in dedicated worktree `wt -n story-046-refactor`)

---

## Dependency Graph

```
STORY-047 (docs audit)           ── independent (use in Sprint 7)
STORY-034 (verbose feedback)     ── independent
  └── STORY-035 (init hooks)     ── after STORY-034
      └── STORY-021 (init UX)    ── after STORY-034, STORY-035
      └── STORY-044 (smart hooks)── after STORY-034, STORY-035 (Sprint 9)
STORY-036 (per-cmd help) ✅      ── COMPLETE
  └── STORY-038 (placeholders)   ── after STORY-036
STORY-030 (completions)  ✅      ── COMPLETE
  └── STORY-037 (hints)          ── after STORY-030
STORY-039 (dry-run UX)           ── independent
STORY-040 (wt --run)             ── independent
STORY-041 (wt --repair/prune)    ── independent
STORY-042 (wt --detach)          ── independent
STORY-043 (--skip-hook)          ── independent
STORY-045 (multi-select)         ── independent
STORY-016 (metadata)             ── independent
STORY-017 (Homebrew)             ── independent
STORY-018 (zsh plugin)           ── independent
STORY-046 (refactor)             ── ideally after STORY-040–045
```

---

## Definition of Done

For a story to be considered complete (Sprint 6 retro standard):

- [ ] Code implemented and tested manually
- [ ] BATS tests written for new functionality
- [ ] shellcheck passes (no new warnings)
- [ ] Works in both zsh and bash (POSIX-compatible)
- [ ] **If user-visible change:** relevant `_help_*` function updated in `lib/commands.sh`
- [ ] **If user-visible change:** 1–3 lines added to README (Commands section)
- [ ] No regressions in existing functionality
- [ ] Code follows conventions (`_` prefix, `GWT_*` globals, POSIX)

---

## Progress Tracking

**Sprint 6 (COMPLETE — 17/17 pts):**
- [x] STORY-029 — Protect main/dev branches from `wt -c` deletion (3pts)
- [x] STORY-031 — Replace slashes with dashes in worktree directory names (2pts)
- [x] STORY-030 — Fix completions in Warp + zsh to work like git (5pts)
- [x] STORY-032 — Show only worktree name instead of full path everywhere (2pts)
- [x] STORY-033 — Prompt to re-source after `wt --update` (2pts)
- [x] STORY-036 — Per-command help (`wt <cmd> --help`) (3pts)

**Sprint 7 (ACTIVE — 0/17 pts):**
- [ ] STORY-047 — Documentation audit — align README and --help (3pts) **retro action item**
- [ ] STORY-034 — Verbose feedback to `wt -c` and `wt --init` (3pts)
- [ ] STORY-035 — `wt --init` offer to copy/backup existing hooks (2pts)
- [ ] STORY-039 — Improve `wt -c` dry-run output readability (2pts)
- [ ] STORY-021 — Improve `wt --init` UX (3pts)
- [ ] STORY-038 — Descriptive usage with placeholders (2pts)
- [ ] STORY-037 — Completions: example usage hints (2pts)

**Sprint 8:**
- [ ] STORY-016 — Add worktree metadata tracking (5pts)
- [ ] STORY-040 — Run command in another worktree (4pts)
- [ ] STORY-041 — Repair corrupted worktree refs (2pts)
- [ ] STORY-043 — Skip hooks flag `--skip-hook` (2pts)
- [ ] STORY-017 — Create Homebrew formula (3pts)

**Sprint 9:**
- [ ] STORY-018 — Create oh-my-zsh / zinit plugin (2pts)
- [ ] STORY-042 — Throwaway worktree without branch `--detach` (3pts)
- [ ] STORY-044 — Improve default hooks (smart templates, restore) (5pts)
- [ ] STORY-045 — Multi-select for `wt -r` and other commands (3pts)

**Sprint 10:**
- [ ] STORY-046 — Code refactoring — SOLID, DRY, KISS (8pts)

---

**This plan was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
