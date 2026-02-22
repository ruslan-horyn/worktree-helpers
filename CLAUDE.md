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
  commands.sh             # Command handlers: _cmd_new, _cmd_switch, _cmd_remove, etc. + all _help_* functions
  update.sh               # Self-update logic: GitHub API check, version comparison, install
git-worktrees.zsh         # Legacy single-file version (deprecated)
```

**Data flow:** `wt <flags>` → router parses flags → `_cmd_*` handler → loads config → performs git worktree ops → runs hooks

**Configuration:** `.worktrees/config.json` in repo root defines project name, worktrees directory, main/dev branches, and hook paths.

**Tests:** BATS test suite in `test/`. Each file maps to a command (e.g., `test/cmd_new.bats`). Helpers in `test/test_helper.bash` provide `setup_test_repo` (creates isolated git repo + config + sources lib files) and `create_marker_hook` for hook invocation testing.

## Commands

```bash
# Run all tests
npm test

# Run a single test file
./test/libs/bats-core/bin/bats test/cmd_new.bats

# Lint commits (husky pre-commit)
npm run commitlint
```

## Code Conventions

- Function names: underscore prefix (`_err`, `_cmd_new`, `_wt_create`)
- Global config vars: `GWT_*` prefix (e.g., `GWT_MAIN_REF`, `GWT_WORKTREES_DIR`)
- Keep functions short; validation at start with early returns
- POSIX-compatible shell syntax required (no bash/zsh-specific features)
- Branch names must not contain slashes — use dashes instead (slashes create nested directories under `worktreesDir`)

## Definition of Done (user-facing changes)

Every story that adds or changes a user-visible feature must also:

- Update the relevant `_help_*` function in `lib/commands.sh` (per-command `--help` is the single source of truth)
- Add 1–3 lines to README (Commands section or appropriate subsection)

*Established in Sprint 6 retrospective (2026-02-21). See STORY-047 for the documentation audit that aligns existing content.*

## Commit Guidelines

- Do NOT add Co-Authored-By lines to commits
- Use conventional commits format (feat:, fix:, refactor:, docs:, chore:, etc.)
- Subject must be lowercase (commitlint enforced)
