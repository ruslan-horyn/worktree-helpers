# Repository Analysis Report: worktree-helpers

**Date:** 2026-02-01
**Analyzed by:** Business Analyst Agent

---

## Overview

**worktree-helpers** is a zsh/bash-based CLI tool designed to streamline git worktree management for Node.js projects. It provides a set of helper functions that simplify the creation, switching, and management of git worktrees while enforcing project-specific configuration and automation through custom hooks.

The tool is built entirely as a single zsh/bash module (`git-worktrees.zsh`, 870 lines) and operates within Node.js projects (requires `package.json`). It manages worktrees in a dedicated directory structure and supports automated post-action workflows via configurable hook scripts.

**Key Design Philosophy**: Configuration-driven, hook-extensible, and Node.js project-gated.

---

## Features List

### Initialization & Configuration
- **wt-init**: Interactive initialization of `.worktrees/config.json` and automatic creation of hook files (`created.sh`, `switched.sh`). Prompts user for:
  - Project name (auto-detected from `package.json`)
  - Worktrees directory path
  - Main branch reference (auto-detected: origin/main or origin/master)
  - Dev branch reference
  - Dev branch suffix
  - Hook file paths

### Worktree Creation
- **wt-new `<new-branch>`**: Creates a new worktree from the configured main branch (e.g., origin/main) with automatic:
  - Branch creation from the specified base reference
  - Upstream tracking configuration
  - Fetching from the base ref
  - Execution of the "created" hook

- **wt-dev `[baseName]`**: Creates a development worktree from the configured dev branch (e.g., origin/release-next) with automatic suffix appending. If no baseName provided, uses current branch name.

- **wt-open `[branch]`**: Creates or switches to a worktree for an existing local branch. If branch doesn't exist locally, fails gracefully. Executes appropriate hook (created for new worktrees, switched for existing).

### Worktree Navigation
- **wt-switch `[branch|path]`**: Interactive switching between worktrees. Accepts branch name or filesystem path as argument. Falls back to fzf-based picker if no argument provided. Executes the "switched" hook.

### Worktree Maintenance
- **wt-remove `[-f] [branch|path]`**: Removes a worktree and its associated local branch. Features:
  - `-f` flag: Force removal without confirmation
  - Interactive confirmation prompt (unless force flag used)
  - Automatic cleanup of local branch after worktree removal
  - Safety check: returns to main repo if currently in the removed worktree

- **wt-lock `[path|branch]`**: Locks a worktree to prevent accidental pruning. Interactive selection via fzf if no argument.

- **wt-unlock `[path|branch]`**: Unlocks a previously locked worktree. Interactive selection via fzf if no argument.

### Utilities
- **wt-log `[branch] [--reflog]`**: Displays feature branch log comparing against main branch. Options:
  - `--reflog`: Shows reflog instead of commit log
  - `--since=<date>`: Filter commits by date
  - `--author=<name>`: Filter commits by author
  - Uses git cherry and graph visualization

- **wt-help**: Shows command reference and displays current configuration if available.

---

## Technical Details

### Architecture & Code Organization

The 870-line `git-worktrees.zsh` file is organized into functional modules:

1. **Error Handling Module** - stderr/stdout handlers, debug logging
2. **Platform Detection Module** - macOS vs other platforms
3. **String Utilities Module** - POSIX-compliant whitespace trimming
4. **Dependency Checking Module** - Validates required CLI tools (jq, fzf, git)
5. **Repository Operations Module** - Git repo root finding, validation
6. **Configuration Management Module** - JSON config parsing, defaults, hook resolution
7. **Branch Reference Utilities Module** - Ref qualification and normalization
8. **Worktree Directory Management Module** - Directory structure creation
9. **Hook Runner Module** - Post-action hook execution with proper error handling
10. **Git Operations Module** - Fetching, branch operations
11. **Worktree Operations Module** - Path calculation, finding, resolution
12. **Interactive Selection Module** - fzf-based worktree picker
13. **Worktree Creation & Management Module** - Creation with upstream tracking
14. **Main Command Functions** - All 10 user-facing commands

### Technology Stack
- **Language**: Zsh/Bash (POSIX-compatible shell script)
- **Dependencies**:
  - git (core functionality)
  - jq (JSON parsing for config)
  - fzf (interactive worktree selection - optional but recommended)
  - bash (for hook execution)
  - package.json (project gating requirement)

### Configuration Format

The `.worktrees/config.json` file stores project-specific settings:

```json
{
  "projectName": "my-project",
  "worktreesDir": "../my-project_worktrees",
  "mainBranch": "origin/main",
  "devBranch": "origin/release-next",
  "devSuffix": "_RN",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh"
}
```

### Hook System

Two customizable hooks are automatically created during initialization:

1. **created.sh**: Executed after creating a new worktree
   - Arguments: `<path> <branch> <base_ref> <main_repo_root>`
   - Use case: Install dependencies, open editor, setup environment

2. **switched.sh**: Executed after switching to a worktree
   - Arguments: `<path> <branch> <base_ref> <main_repo_root>`
   - Use case: Focus editor window, start services, load environment

---

## User Workflow

### Typical Usage Scenario

**Step 1: Initialize a Project**
```bash
cd ~/projects/my-app
wt-init
# Interactive prompts for configuration
# Creates .worktrees/config.json and hook files
```

**Step 2: Create a New Feature Worktree**
```bash
wt-new feature/new-feature
# Creates worktree at ~/projects/my-app_worktrees/feature/new-feature
# Sets up tracking, fetches base ref
# Executes created.sh hook
```

**Step 3: Switch Between Worktrees**
```bash
wt-switch
# Interactive fzf picker shows all worktrees
# Selects and switches to chosen worktree
# Executes switched.sh hook
```

**Step 4: View Feature Branch Log**
```bash
wt-log feature/new-feature
# Shows commits unique to feature branch vs main
```

**Step 5: Remove Worktree When Done**
```bash
wt-remove feature/new-feature
# Confirms removal, deletes worktree and local branch
```

---

## Current Limitations & Gaps

1. **No GUI/TUI Interface** - CLI-only, limited without fzf
2. **No Worktree Status Command** - No overview of all worktrees with status
3. **No Automatic Cleanup** - No pruning of stale worktrees
4. **Limited Configuration Flexibility** - Hard-coded Node.js requirement
5. **No Export/Import of Config** - Team sharing is manual
6. **Inadequate Error Recovery** - No rollback mechanism
7. **Missing Documentation** - No README or user guide
8. **No Performance Optimization** - No caching of worktree list
9. **Limited Branch Selection** - Only main/dev branches
10. **No Metadata Tracking** - No notes or creation date tracking
11. **No Cross-Platform Validation** - Limited testing outside macOS/Linux
12. **No Test Suite** - No unit or integration tests
13. **No Remote Sync** - No team awareness of worktree usage

---

## Current State of Development

**Maturity Level**: Early Stage / MVP
- **Version**: 1.0.0
- **Commits**: 1 (initial commit: `1d7a63f`)
- **Project Status**: Pre-release, foundational phase

**What's Complete**:
- Core worktree creation, switching, and removal logic
- Configuration management system
- Hook execution framework
- Interactive fzf integration
- Basic error handling and validation
- Help documentation inline

**What's Missing**:
- User documentation (README, guides)
- Test suite
- CI/CD pipeline
- Release process

---

## Summary

| Aspect | Details |
|--------|---------|
| **Purpose** | Git worktree management for Node.js projects |
| **Language** | Zsh/Bash shell script |
| **Lines of Code** | ~870 (single file) |
| **Main File** | `git-worktrees.zsh` |
| **Core Dependencies** | git, jq, (optional: fzf) |
| **Config File** | `.worktrees/config.json` |
| **Maturity** | MVP / Early Stage |
| **Key Feature** | Hook-based automation for post-action workflows |
| **Primary Use Case** | Multi-branch development with isolated worktrees |

---

*This report was generated by the BMAD Business Analyst workflow.*
