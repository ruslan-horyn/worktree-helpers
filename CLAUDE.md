# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**worktree-helpers** is a POSIX-compatible shell CLI tool (`wt`) for managing git worktrees. It wraps native git worktree commands with a single unified interface, project-specific configuration, and customizable hooks. Works with bash, zsh, and other POSIX-compliant shells.

**Dependencies:** git, jq (required), fzf (optional for interactive selection)

## Architecture

```
wt.sh                     # Entry point - source in .zshrc/.bashrc, contains wt() router
lib/
  utils.sh                # Core utilities: _err, _info, _require, _repo_root, _branch_exists, _read_input
  config.sh               # _config_load - parses .worktrees/config.json, sets GWT_* globals
  worktree.sh             # Worktree operations: _wt_create, _wt_open, _wt_resolve, _run_hook
  commands.sh             # Command handlers: _cmd_new, _cmd_switch, _cmd_remove, etc.
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
source wt.sh
wt -h
```

## Code Conventions

- Function names: underscore prefix (`_err`, `_cmd_new`, `_wt_create`)
- Global config vars: `GWT_*` prefix (e.g., `GWT_MAIN_REF`, `GWT_WORKTREES_DIR`)
- Keep functions short; validation at start with early returns
- POSIX-compatible shell syntax required (no bash/zsh-specific features)

## Commit Guidelines

- Do NOT add Co-Authored-By lines to commits
- Use conventional commits format (feat:, fix:, refactor:, docs:, chore:, etc.)
- Subject must be lowercase (commitlint enforced)
