# Technical Specification: worktree-helpers

**Date:** 2026-02-01
**Author:** Ruslan Horyn
**Version:** 1.0
**Project Type:** CLI
**Project Level:** 1
**Status:** Draft

---

## Document Overview

This Technical Specification provides focused technical planning for worktree-helpers. It is designed for smaller projects (Level 0-1) that need clear requirements without heavyweight PRD overhead.

**Related Documents:**
- Product Brief: `docs/product-brief-worktree-helpers-2026-02-01.md`

---

## Problem & Solution

### Problem Statement

Developers working on multiple projects or branches simultaneously face friction when switching contexts. Native git worktree commands are powerful but cumbersome, requiring multiple steps and manual management. Current workarounds like `git stash` + `checkout` are risky (stash conflicts, forgotten stashes, lost work), and native `git worktree` commands are verbose with no automation and easy-to-forget cleanup.

### Proposed Solution

A zsh/bash CLI tool providing a single `wt` command with intuitive flags for all operations, project-specific configuration via `.worktrees/config.json`, and customizable hooks for automation. The tool will support interactive fzf-based selection when no argument is provided, making multi-branch workflows effortless.

---

## Requirements

### What Needs to Be Built

**Code Refactoring:**
- Refactor from multiple `wt-*` commands to single `wt` command with flag-based interface
- Cleaner architecture with better module separation
- Reduce code complexity (break down large functions)
- Remove redundancy and dead code

**Bug Fixes:**
- `wt -o` (open) branch list display — should show fzf picker when no branch specified
- `wt -o` (open) fetch error — currently fetches branch name instead of origin

**New Features:**
- `wt -l` (list) — List all worktrees with status information
- `wt -c <time>` (clear) — Time-based cleanup of old worktrees with filters (`--dev-only`, `--main-only`)
- Hook symlinking from main worktree instead of copying
- Hook protection on init (backup existing hooks with `_old` suffix)
- Worktree count warning when exceeding threshold (default: 20)

**Distribution:**
- Install script (`curl -fsSL <url>/install.sh | bash`)
- README documentation with usage examples
- Changelog for version tracking

### What This Does NOT Include

- GUI/TUI interface
- Cross-team sync/remote awareness
- Issue tracker integration
- Windows native support (WSL only)
- Rewrite to another language (must remain shell-based)
- Update mechanism (`wt --update`) — deferred to v1.1
- Worktree status (dirty/clean) in list — deferred to v1.1

---

## Technical Approach

### Technology Stack

- **Language/Runtime:** zsh/bash shell script (POSIX-compatible where possible)
- **Platform:** macOS and Linux
- **Dependencies:**
  - `git` (required) — core worktree operations
  - `jq` (required) — JSON config parsing
  - `fzf` (optional but recommended) — interactive selection

### Architecture Overview

The tool follows a modular single-file architecture with clearly separated concerns:

```
git-worktrees.zsh
├── Error Handling Module      # gwt_error_handler, gwt_info_handler, gwt_debug_handler
├── Platform Detection         # gwt_platform_detector (macos/other)
├── String Utilities          # gwt_string_trimmer
├── Dependency Checking       # gwt_dependency_checker
├── Repository Operations     # gwt_repo_finder, gwt_main_repo_root_finder, validators
├── Configuration Module      # gwt_config_loader, parsers, validators
├── Branch Utilities          # gwt_branch_ref_normalizer, existence checks
├── Worktree Operations       # gwt_worktree_creator_from_ref, gwt_worktree_preparer
├── Interactive Selection     # gwt_interactive_worktree_selector (fzf integration)
├── Hook Runner               # gwt_hook_file_runner
└── Main Command Router       # wt() - single entry point with flag parsing
```

**Data Flow:**
1. User invokes `wt <flags> [args]`
2. Main router parses flags and routes to appropriate handler
3. Handler loads config from `.worktrees/config.json`
4. Handler performs git worktree operations
5. Hooks execute post-operation (created/switched)

### Data Model (if applicable)

**Configuration File:** `.worktrees/config.json`
```json
{
  "projectName": "string",      // Project identifier
  "worktreesDir": "string",     // Path for worktree directories
  "mainBranch": "string",       // e.g., "origin/main"
  "devBranch": "string",        // e.g., "origin/release-next"
  "devSuffix": "string",        // e.g., "_RN"
  "openCmd": "string",          // Path to created hook
  "switchCmd": "string",        // Path to switched hook
  "worktreeWarningThreshold": 20  // NEW: warning threshold
}
```

**Hook Arguments:**
- `$1` - worktree path
- `$2` - branch name
- `$3` - base ref (for created hook)
- `$4` - main repository root path

### API Design (if applicable)

**Command Structure:**

| Flag | Long Form | Description |
|------|-----------|-------------|
| `wt -n <branch>` | `--new` | Create worktree from main branch |
| `wt -n -d [name]` | `--new --dev` | Create worktree from dev branch |
| `wt -l` | `--list` | List all worktrees |
| `wt -s [branch]` | `--switch` | Switch worktree (fzf picker if no arg) |
| `wt -r [branch]` | `--remove` | Remove worktree and branch |
| `wt -o [branch]` | `--open` | Open existing branch as worktree |
| `wt -L [branch]` | `--lock` | Lock worktree from pruning |
| `wt -U [branch]` | `--unlock` | Unlock worktree |
| `wt -c <time>` | `--clear` | Cleanup old worktrees |
| `wt -h` | `--help` | Show help |
| `wt --init` | — | Initialize project config |
| `wt --log [branch]` | — | View feature branch commits |

**Modifier Flags:**
| Flag | Description |
|------|-------------|
| `-f` / `--force` | Force operation without confirmation |
| `-d` / `--dev` | Use dev branch as base |
| `--dev-only` | Filter: only dev worktrees (for clear) |
| `--main-only` | Filter: only main worktrees (for clear) |

---

## Implementation Plan

### Stories

1. **Refactor CLI to flag-based interface** - Convert from `wt-*` commands to single `wt` command with flag parsing
2. **Fix wt-open bugs** - Fix fzf picker display and fetch error (fetches branch name instead of origin)
3. **Add wt-list command** - Implement `wt -l` to list all worktrees with status
4. **Add wt-clear command** - Implement `wt -c` with time-based cleanup and filters
5. **Implement hook symlinking** - Symlink hooks from main worktree instead of copying
6. **Add hook protection on init** - Backup existing hooks with `_old` suffix before overwriting
7. **Add worktree count warning** - Warn when worktree count exceeds configurable threshold
8. **Create install script and documentation** - curl-based install, README, changelog

### Development Phases

**Phase 1: Core Refactoring**
- Story 1: Refactor CLI to flag-based interface

**Phase 2: Bug Fixes**
- Story 2: Fix wt-open bugs

**Phase 3: New Features**
- Story 3: Add wt-list command
- Story 4: Add wt-clear command
- Story 5: Implement hook symlinking
- Story 6: Add hook protection on init
- Story 7: Add worktree count warning

**Phase 4: Distribution**
- Story 8: Create install script and documentation

---

## Acceptance Criteria

How we'll know it's done:

- [ ] Single `wt` command works with all documented flags
- [ ] `wt -o` shows fzf picker when no branch specified
- [ ] `wt -o` fetches from origin correctly
- [ ] `wt -l` lists all worktrees with relevant info
- [ ] `wt -c week 2` clears worktrees older than 2 weeks
- [ ] Hooks are symlinked, not copied
- [ ] `wt --init` backs up existing hooks before overwriting
- [ ] Warning displayed when worktree count exceeds threshold
- [ ] `curl -fsSL <url>/install.sh | bash` successfully installs tool
- [ ] README documents all commands with examples
- [ ] All tests pass on both macOS and Linux

---

## Non-Functional Requirements

### Performance

- Commands should execute in <1 second for typical operations
- fzf picker should respond immediately to user input
- Git operations should use efficient commands (no unnecessary fetches)

### Security

- No credentials or secrets stored in configuration
- Install script should be auditable (simple, readable)
- Hooks execute with user permissions only
- No remote code execution beyond user-defined hooks

### Other

- Shell compatibility: zsh and bash
- POSIX-compatible where feasible for wider compatibility
- Graceful degradation when fzf is not installed
- Clear error messages for missing dependencies

---

## Dependencies

- Git (2.15+ for worktree features)
- jq (for JSON parsing)
- fzf (optional, for interactive selection)
- curl (for install script)
- macOS or Linux environment

---

## Risks & Mitigation

- **Risk:** Hook symlinking breaks on some systems
  - **Mitigation:** Test on macOS + Linux; implement fallback to copy if symlink fails

- **Risk:** Install script fails on edge cases
  - **Mitigation:** Clear error messages; document manual installation fallback

- **Risk:** Breaking change for existing users
  - **Mitigation:** Document migration; optionally keep old `wt-*` commands as aliases temporarily

- **Risk:** Team doesn't adopt
  - **Mitigation:** Demo early; gather feedback; keep tool simple

- **Risk:** Shell compatibility issues
  - **Mitigation:** Test both zsh and bash; stick to POSIX where possible

---

## Timeline

**Target Completion:** 1-2 weeks

**Milestones:**
1. CLI refactoring complete (flag-based interface working)
2. Bug fixes complete (`wt -o` working correctly)
3. New features complete (list, clear, hooks, warnings)
4. Distribution ready (install script, README, changelog)
5. Release v1.0

---

## Approval

**Reviewed By:**
- [ ] Ruslan Horyn (Author)
- [ ] Technical Lead
- [ ] Product Owner

---

## Next Steps

### Phase 4: Implementation

For Level 1 projects (1-10 stories):
- Run `/sprint-planning` to plan your sprint
- Then create and implement stories

---

**This document was created using BMAD Method v6 - Phase 2 (Planning)**

*To continue: Run `/workflow-status` to see your progress and next recommended workflow.*
