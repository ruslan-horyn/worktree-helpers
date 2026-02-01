# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**worktree-helpers** is a zsh/bash CLI tool (`wt`) for managing git worktrees. It wraps native git worktree commands with a single unified interface, project-specific configuration, and customizable hooks.

**Dependencies:** git, jq (required), fzf (optional for interactive selection)

## Architecture

```
wt.zsh                    # Entry point - source in .zshrc, contains wt() router
lib/
  utils.zsh               # Core utilities: _err, _info, _require, _repo_root, _branch_exists
  config.zsh              # _config_load - parses .worktrees/config.json, sets GWT_* globals
  worktree.zsh            # Worktree operations: _wt_create, _wt_open, _wt_resolve, _run_hook
  commands.zsh            # Command handlers: _cmd_new, _cmd_switch, _cmd_remove, etc.
git-worktrees.zsh         # Legacy single-file version (deprecated)
```

**Data flow:** `wt <flags>` → router parses flags → `_cmd_*` handler → loads config → performs git worktree ops → runs hooks

**Configuration:** `.worktrees/config.json` in repo root defines project name, worktrees directory, main/dev branches, and hook paths.

## Commands

```bash
# No build step - shell scripts

# Lint commits (husky pre-commit)
npm run commitlint

# Test manually by sourcing
source wt.zsh
wt -h
```

## Code Conventions

- Function names: underscore prefix (`_err`, `_cmd_new`, `_wt_create`)
- Global config vars: `GWT_*` prefix (e.g., `GWT_MAIN_REF`, `GWT_WORKTREES_DIR`)
- Keep functions short; validation at start with early returns
- POSIX-compatible where possible, zsh-specific syntax allowed

## Commit Guidelines

- Do NOT add Co-Authored-By lines to commits
- Use conventional commits format (feat:, fix:, refactor:, docs:, chore:, etc.)
- Subject must be lowercase (commitlint enforced)
