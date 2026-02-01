# Product Brief: worktree-helpers

**Date:** 2026-02-01
**Author:** Ruslan Horyn
**Version:** 1.0
**Project Type:** CLI
**Project Level:** 1

---

## Executive Summary

**worktree-helpers** is a CLI tool that simplifies git worktree management for developers working on any project type. It's designed for developers who work on multiple projects or branches simultaneously and need seamless worktree creation, switching, and cleanup with automated hooks. It removes the friction of native git worktree commands, making multi-branch workflows effortless.

---

## Problem Statement

### The Problem

Developers working on multiple projects or branches simultaneously face friction when switching contexts. Native git worktree commands are powerful but cumbersome, requiring multiple steps and manual management.

**Example scenario:** You're working on a feature branch, get a critical bug report, need to switch to another branch to fix it, then return—each switch involves manual worktree setup, dependency reinstalls, and context switching overhead.

**Current workarounds:**
- `git stash` + `checkout` — risky (stash conflicts, forgotten stashes, lost work)
- Native `git worktree` commands — verbose, no automation, easy to forget cleanup

### Why Now?

Personal productivity is suffering. The current workflow is slowing down development and causing unnecessary friction when working across multiple branches.

### Impact if Unsolved

- **Lost productivity:** Developers waste time on manual worktree management
- **Context-switching errors:** Mistakes from incomplete stashes or wrong branch states
- **Friction discourages worktrees:** Developers avoid worktrees entirely, missing their benefits

---

## Target Audience

### Primary Users

Individual developers working on multiple features or projects simultaneously. These are advanced users comfortable with git, CLI tools, and shell configuration.

### Secondary Users

Team members who could benefit from streamlined worktree management once the tool is shared and documented.

### User Needs

1. Quick worktree creation without remembering complex git commands
2. Seamless context switching with automated environment setup (hooks)
3. Easy cleanup of worktrees and associated branches

---

## Solution Overview

### Proposed Solution

A zsh/bash CLI tool providing a single `wt` command with flags for all operations, project-specific configuration, and customizable hooks.

### Command Structure (Simplified)

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

**Examples:**
```bash
wt -n feature/login      # Create worktree from main
wt -n -d hotfix-123      # Create worktree from dev branch
wt -s                    # Interactive switch (fzf)
wt -s feature/login      # Switch to specific worktree
wt -r -f old-branch      # Force remove worktree
wt -c week 2             # Clear worktrees older than 2 weeks
wt -c month --dev-only   # Clear dev worktrees older than 1 month
wt -l                    # List all worktrees
```

### Key Features

**Core Functionality:**
- Single `wt` command with intuitive flags
- Interactive fzf-based selection when no argument provided
- Automatic hook execution (created/switched)
- Hook symlinking from main worktree (not copying)
- Hook protection on init (backup existing with `_old` suffix)
- Worktree count warning (configurable, default: 20)

**Infrastructure:**
- Configuration via `.worktrees/config.json`
- Install via `curl -fsSL <url>/install.sh | bash`
- Changelog and versioning

### Value Proposition

One command, simple flags, zero friction. Reduces git worktree complexity to muscle memory.

---

## Business Objectives

### Goals

- Build a personal productivity tool that solves real workflow pain
- Share with team members to improve collective efficiency
- Potentially open source for community benefit

### Success Metrics

- **Personal productivity:** Tool is used daily in active development
- **Team adoption:** 2-3 team members actively using the tool
- **Stability:** Core commands work reliably without errors

### Business Value

Time saved on manual worktree operations compounds across every branch switch.

---

## Scope

### In Scope (v1.0)

**Code Refactoring:**
- Refactor to single `wt` command with flag-based interface
- Cleaner architecture with better module separation
- Reduce code complexity (break down large functions)
- Remove redundancy

**Bug Fixes:**
- `wt -o` (open) branch list display — should show fzf picker
- `wt -o` (open) fetch error — fetches branch name instead of origin

**New Features:**
- `wt -l` (list) — List all worktrees with status
- `wt -c` (clear) — Time-based cleanup with filters
- Hook symlinking instead of copying
- Hook protection on init (backup with `_old` suffix)
- Worktree count warning (default: 20)

**Distribution:**
- Install script (`curl -fsSL <url>/install.sh | bash`)
- README documentation
- Changelog

### In Scope (v1.1)

- Update mechanism (`wt --update`)
- More granular clear options
- Worktree status (dirty/clean) in list

### Out of Scope

- GUI/TUI interface
- Cross-team sync/remote awareness
- Issue tracker integration
- Windows native support (WSL only)
- Rewrite to another language (must remain shell-based)

### Future Considerations

- Homebrew formula
- oh-my-zsh / zinit plugin
- Worktree metadata (creation date, purpose)

---

## Key Stakeholders

- **Ruslan Horyn (Owner)** — High influence. Primary developer and decision-maker.
- **Team members** — Medium influence. End users who will provide feedback.

---

## Constraints and Assumptions

### Constraints

- Must remain zsh/bash shell-based
- Must work on macOS and Linux
- Dependencies: git, jq, fzf (optional but recommended)

### Assumptions

- Users have `git`, `jq` installed
- Users are on macOS or Linux with zsh/bash
- Users understand basic git concepts

---

## Success Criteria

- [ ] Tool is used daily in development workflow
- [ ] 2-3 team members actively using it
- [ ] Core commands work reliably
- [ ] `curl | bash` installation works
- [ ] README explains usage
- [ ] Known bugs are fixed
- [ ] Code is simplified and maintainable

---

## Timeline and Milestones

### Target Launch

1-2 weeks to stable v1.0

### Key Milestones

1. Refactor to flag-based `wt` command
2. Fix `wt -o` bugs (list + fetch)
3. Add `wt -l` (list) and `wt -c` (clear)
4. Implement hook symlinking + protection
5. Create install script + README
6. Release v1.0

---

## Risks and Mitigation

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hook symlinking breaks on some systems | Medium | Test macOS + Linux; fallback to copy |
| Install script fails on edge cases | Medium | Clear error messages; manual fallback |
| Breaking change for existing users | Medium | Document migration; keep old commands as aliases temporarily |
| Team doesn't adopt | Low | Demo early; gather feedback |
| Shell compatibility issues | Low | POSIX-compatible; test both shells |

---

## Known Issues (to fix)

1. `wt-open` doesn't display branch list for selection
2. `wt-open` fetch error — fetches branch name as remote

---

## Next Steps

1. Create Tech Spec — `/tech-spec`
2. Refactor to flag-based CLI
3. Fix bugs and add new features
4. Create install script and documentation
5. Release v1.0

---

**Created using BMAD Method v6 - Phase 1 (Analysis)**

*Run `/workflow-status` to see progress and next workflow.*
