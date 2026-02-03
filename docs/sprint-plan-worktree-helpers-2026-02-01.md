# Sprint Plan: worktree-helpers

**Date:** 2026-02-01
**Scrum Master:** Ruslan Horyn
**Project Level:** 1
**Total Stories:** 8
**Total Points:** 31
**Planned Sprints:** 2
**Status:** Ready for Implementation

---

## Executive Summary

This sprint plan covers the complete development of worktree-helpers v1.0, a CLI tool for git worktree management. The work is organized into 2 sprints, with Sprint 1 focusing on core refactoring and bug fixes to establish a solid foundation, and Sprint 2 delivering new features and distribution setup.

**Key Metrics:**
- Total Stories: 8
- Total Points: 31
- Sprints: 2
- Team Capacity: 16-17 points per sprint
- Target Completion: 4 weeks (2 sprints × 2 weeks)

---

## Team Capacity

| Parameter | Value |
|-----------|-------|
| Team Size | 1 developer |
| Sprint Length | 2 weeks (10 workdays) |
| Productive Hours/Day | 5 hours |
| Total Hours/Sprint | 50 hours |
| Points per Sprint | ~17 points |

---

## Story Inventory

### STORY-001: Refactor CLI to flag-based interface

**Phase:** Core Refactoring
**Priority:** Must Have
**Points:** 8

**User Story:**
As a developer
I want to use a single `wt` command with flags
So that I have a consistent and intuitive interface for all worktree operations

**Acceptance Criteria:**
- [ ] Single `wt` command entry point with flag parsing
- [ ] All existing `wt-*` commands converted to flags (`-n`, `-s`, `-r`, `-o`, `-L`, `-U`, `--init`, `--log`)
- [ ] Long-form flags supported (`--new`, `--switch`, `--remove`, `--open`, `--lock`, `--unlock`)
- [ ] Modifier flags work (`-f/--force`, `-d/--dev`)
- [ ] `-h/--help` displays usage information
- [ ] Backward-compatible aliases for old commands (temporary)
- [ ] Code organized into clear modules (error handling, config, operations, etc.)

**Technical Notes:**
- Implement main router function with case/esac for flag parsing
- Refactor large functions into smaller, focused functions
- Remove redundant code during refactoring
- Keep all code in single file for easy sourcing

**Dependencies:** None (foundational work)

---

### STORY-002: Fix wt-open bugs

**Phase:** Bug Fixes
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer
I want `wt -o` to work correctly
So that I can open existing remote branches as worktrees without errors

**Acceptance Criteria:**
- [ ] `wt -o` (no argument) shows fzf picker with available branches
- [ ] `wt -o <branch>` opens specific branch as worktree
- [ ] Fetches from `origin` correctly, not the branch name
- [ ] Clear error message if branch doesn't exist
- [ ] Works with both local and remote branch names

**Technical Notes:**
- Bug 1: fzf picker not showing when no branch specified
- Bug 2: `git fetch` using branch name instead of remote name
- Review `gwt_worktree_creator_from_ref` function

**Dependencies:** STORY-001 (refactoring should be complete first)

---

### STORY-003: Add wt-list command

**Phase:** New Features
**Priority:** Must Have
**Points:** 3

**User Story:**
As a developer
I want to list all my worktrees with status information
So that I can see what branches I have active and where they are located

**Acceptance Criteria:**
- [ ] `wt -l` / `wt --list` lists all worktrees
- [ ] Shows: branch name, path, locked status
- [ ] Clean tabular or formatted output
- [ ] Handles case with no worktrees gracefully
- [ ] Shows main worktree distinguished from feature worktrees

**Technical Notes:**
- Use `git worktree list --porcelain` for machine-readable output
- Parse output and format for display
- Consider colorized output for locked/unlocked status

**Dependencies:** STORY-001

---

### STORY-004: Add wt-clear command

**Phase:** New Features
**Priority:** Should Have
**Points:** 5

**User Story:**
As a developer
I want to clean up old worktrees based on age
So that I can keep my workspace organized without manual cleanup

**Acceptance Criteria:**
- [ ] `wt -c <unit> <number>` clears worktrees older than specified time
- [ ] Units supported: `day`, `week`, `month` (e.g., `wt -c week 2`)
- [ ] `--dev-only` flag filters to only dev-based worktrees
- [ ] `--main-only` flag filters to only main-based worktrees
- [ ] Confirmation prompt before deletion (bypass with `-f`)
- [ ] Shows list of worktrees to be deleted before confirming
- [ ] Skips locked worktrees with warning

**Technical Notes:**
- Use file modification time or git log for age detection
- Parse dev suffix from config to identify dev worktrees
- Delete both worktree and associated branch

**Dependencies:** STORY-001, STORY-003 (uses list functionality)

---

### STORY-005: Implement hook symlinking

**Phase:** New Features
**Priority:** Should Have
**Points:** 3

**User Story:**
As a developer
I want hooks to be symlinked from main worktree
So that hook updates in main are automatically available in all worktrees

**Acceptance Criteria:**
- [ ] New worktrees symlink hooks from main worktree's `.worktrees/hooks/`
- [ ] Symlinks work on both macOS and Linux
- [ ] Falls back to copying if symlink fails (with warning)
- [ ] Existing worktrees continue to work with copied hooks

**Technical Notes:**
- Use `ln -s` for symlinking
- Test symlink creation across platforms
- Handle case where hooks directory doesn't exist

**Dependencies:** STORY-001

---

### STORY-006: Add hook protection on init

**Phase:** New Features
**Priority:** Should Have
**Points:** 2

**User Story:**
As a developer
I want my existing hooks backed up during init
So that I don't lose custom hook configurations

**Acceptance Criteria:**
- [ ] `wt --init` checks for existing hooks before overwriting
- [ ] Existing hooks renamed with `_old` suffix (e.g., `post-checkout_old`)
- [ ] User informed of backed-up hooks
- [ ] Backup only happens if hook content differs

**Technical Notes:**
- Check for existing files before writing
- Use diff or checksum to detect if content differs
- Simple rename operation

**Dependencies:** STORY-001

---

### STORY-007: Add worktree count warning

**Phase:** New Features
**Priority:** Could Have
**Points:** 2

**User Story:**
As a developer
I want to be warned when I have too many worktrees
So that I'm reminded to clean up and avoid repository bloat

**Acceptance Criteria:**
- [ ] Warning displayed when worktree count exceeds threshold
- [ ] Default threshold: 20 worktrees
- [ ] Threshold configurable via `worktreeWarningThreshold` in config
- [ ] Warning shown on worktree creation, not on every command
- [ ] Suggests running `wt -c` to clean up

**Technical Notes:**
- Count worktrees using `git worktree list`
- Read threshold from config (with default fallback)
- Non-blocking warning (doesn't prevent creation)

**Dependencies:** STORY-001

---

### STORY-008: Create install script and documentation

**Phase:** Distribution
**Priority:** Must Have
**Points:** 5

**User Story:**
As a potential user
I want to install the tool easily with a single command
So that I can start using it without complex setup

**Acceptance Criteria:**
- [ ] Install script works: `curl -fsSL <url>/install.sh | bash`
- [ ] Script detects shell (zsh/bash) and updates appropriate rc file
- [ ] Script checks for required dependencies (git, jq)
- [ ] README.md with:
  - Installation instructions
  - Quick start guide
  - All commands documented with examples
  - Configuration reference
  - Troubleshooting section
- [ ] CHANGELOG.md with v1.0 release notes
- [ ] Install script is auditable and secure

**Technical Notes:**
- Host on GitHub, use raw.githubusercontent.com for install URL
- Script should be idempotent (safe to run multiple times)
- Test on fresh macOS and Linux environments

**Dependencies:** All other stories (documentation covers complete feature set)

---

## Sprint Allocation

### Sprint 1 (Weeks 1-2) - 14/17 points

**Goal:** Establish solid foundation with refactored CLI and fix critical bugs

**Stories:**
| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-001 | Refactor CLI to flag-based interface | 8 | Must Have |
| STORY-002 | Fix wt-open bugs | 3 | Must Have |
| STORY-003 | Add wt-list command | 3 | Must Have |

**Total:** 14 points / 17 capacity (82% utilization)

**Sprint 1 Deliverables:**
- Single `wt` command with flag-based interface
- Working `wt -o` with fzf picker
- `wt -l` to list all worktrees

**Risks:**
- Refactoring may uncover additional issues in existing code
- Testing across both macOS and Linux needed

**Buffer:** 3 points for unexpected issues

---

### Sprint 2 (Weeks 3-4) - 17/17 points

**Goal:** Complete feature set and prepare for distribution

**Stories:**
| Story ID | Title | Points | Priority |
|----------|-------|--------|----------|
| STORY-004 | Add wt-clear command | 5 | Should Have |
| STORY-005 | Implement hook symlinking | 3 | Should Have |
| STORY-006 | Add hook protection on init | 2 | Should Have |
| STORY-007 | Add worktree count warning | 2 | Could Have |
| STORY-008 | Create install script and documentation | 5 | Must Have |

**Total:** 17 points / 17 capacity (100% utilization)

**Sprint 2 Deliverables:**
- Time-based worktree cleanup
- Improved hook management (symlinking + protection)
- Worktree count warnings
- Complete documentation and install script
- Ready for v1.0 release

**Risks:**
- Cross-platform testing for hook symlinking
- Install script edge cases

**Mitigation:** STORY-007 (2 points) can be deferred if sprint is at risk

---

## Requirements Coverage

| Requirement | Story | Sprint |
|-------------|-------|--------|
| Flag-based CLI interface | STORY-001 | 1 |
| Module separation | STORY-001 | 1 |
| Fix fzf picker in wt-open | STORY-002 | 1 |
| Fix fetch error in wt-open | STORY-002 | 1 |
| wt-list command | STORY-003 | 1 |
| wt-clear command | STORY-004 | 2 |
| Hook symlinking | STORY-005 | 2 |
| Hook protection on init | STORY-006 | 2 |
| Worktree count warning | STORY-007 | 2 |
| Install script | STORY-008 | 2 |
| README documentation | STORY-008 | 2 |
| Changelog | STORY-008 | 2 |

---

## Risks and Mitigation

**High:**
- None identified

**Medium:**
- **Hook symlinking cross-platform issues** - Mitigation: Test on macOS + Linux; implement copy fallback
- **Install script edge cases** - Mitigation: Test on fresh environments; document manual install

**Low:**
- **Breaking change for existing users** - Mitigation: Keep old `wt-*` aliases temporarily; document migration
- **Shell compatibility issues** - Mitigation: Test both zsh and bash; use POSIX where possible

---

## Dependencies

**External:**
- Git 2.15+ (for worktree features)
- jq (JSON parsing)
- fzf (optional, for interactive selection)

**Internal Story Dependencies:**
```
STORY-001 (Foundation)
    ├── STORY-002 (Bug fixes)
    ├── STORY-003 (List)
    │       └── STORY-004 (Clear - uses list)
    ├── STORY-005 (Hook symlinking)
    ├── STORY-006 (Hook protection)
    └── STORY-007 (Count warning)

STORY-008 (Documentation) depends on all stories
```

---

## Definition of Done

For a story to be considered complete:
- [ ] Code implemented and tested manually
- [ ] Works on both macOS and Linux (or documented limitation)
- [ ] Works in both zsh and bash
- [ ] Help text updated (if applicable)
- [ ] No regressions in existing functionality
- [ ] Code follows existing patterns in codebase

---

## Next Steps

**Immediate:** Begin Sprint 1

Run `/dev-story STORY-001` to start implementing the CLI refactoring.

**Sprint cadence:**
- Sprint length: 2 weeks
- Sprint planning: Day 1
- Sprint review: Day 10
- Sprint retrospective: Day 10

---

## Progress Tracking

Last updated: 2026-02-03

- [x] STORY-001 - Refactor CLI to flag-based interface
- [x] STORY-002 - Fix wt-open bugs
- [x] STORY-003 - Add wt-list command
- [x] STORY-004 - Add wt-clear command
- [x] STORY-005 - Implement hook symlinking
- [x] STORY-006 - Add hook protection on init
- [x] STORY-007 - Add worktree count warning
- [ ] STORY-008 - Create install script and documentation

### Remaining Work

**STORY-008 - Documentation & Distribution:**
- [ ] Create `README.md` (installation, usage, configuration)
- [ ] Create `CHANGELOG.md` (v1.0 release notes)
- [ ] Create `install.sh` script
- [x] Help text (`wt -h`) - already done

---

**This plan was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
