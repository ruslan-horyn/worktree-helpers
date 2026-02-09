# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0](https://github.com/ruslan-horyn/worktree-helpers/compare/v1.0.1...v1.1.0) (2026-02-09)


### Added

* add --rename command to rename current worktree's branch ([53a5459](https://github.com/ruslan-horyn/worktree-helpers/commit/53a5459d1fca92f1a8841803b0e57c62bb1bb01d))
* add --version flag ([92d5505](https://github.com/ruslan-horyn/worktree-helpers/commit/92d5505d85823709e8df5b1e1ee24b91bc13f2dc))
* add uninstall command and script ([514f147](https://github.com/ruslan-horyn/worktree-helpers/commit/514f147503357e910e05180ca30e04559fb420ba))


### Fixed

* resolve ci failures on linux ([29875f4](https://github.com/ruslan-horyn/worktree-helpers/commit/29875f4dcdccacd1cb23f2fb477bffa46a6f6794))

## [1.0.1](https://github.com/ruslan-horyn/worktree-helpers/compare/v1.0.0...v1.0.1) (2026-02-08)


### Fixed

* resolve shell parsing and scoping bugs ([74a8793](https://github.com/ruslan-horyn/worktree-helpers/commit/74a879333bbcb914fd28c4b17e5e6c02469cc559))


### Changed

* simplify wt -c to accept days instead of unit and number ([cb1f575](https://github.com/ruslan-horyn/worktree-helpers/commit/cb1f575193630e351e9d96e0c9835b9f8feddb3e))

## [1.0.0] - 2026-02-05

### Added

- **POSIX-compatible shell** - Works with bash, zsh, and other POSIX-compliant shells
- **Flag-based CLI interface** - Single `wt` command with intuitive flags replacing multiple `wt-*` commands
- **Worktree creation** (`wt -n <branch>`) - Create worktrees from main branch with automatic remote tracking setup
- **Dev branch worktrees** (`wt -n -d [name]`) - Create worktrees from dev/release branch with configurable suffix
- **Worktree switching** (`wt -s [branch]`) - Switch to existing worktree with fzf picker support
- **Worktree removal** (`wt -r [branch]`) - Remove worktree and associated branch with confirmation prompt
- **Open existing branch** (`wt -o [branch]`) - Create worktree for existing local/remote branch with fzf picker
- **List worktrees** (`wt -l`) - Display worktrees with branch, path, and lock status in formatted output
- **Clear old worktrees** (`wt -c <unit> <n>`) - Age-based cleanup with day/week/month units
  - `--dev-only` flag to filter dev-based worktrees
  - `--main-only` flag to filter main-based worktrees
  - Respects locked worktrees (skips with warning)
- **Lock/unlock worktrees** (`wt -L` / `wt -U`) - Protect important worktrees from removal
- **Project initialization** (`wt --init`) - Interactive setup creating `.worktrees/config.json`
- **Commit comparison** (`wt --log [branch]`) - Show commits vs main with `--since` and `--author` filters
- **Hook system** - Customizable scripts run on worktree create/switch
  - `created.sh` hook for post-creation tasks (npm install, open editor)
  - `switched.sh` hook for post-switch tasks
- **Hook symlinking** - Automatically symlinks hooks from main repo to worktrees
- **Hook protection on init** - Backs up existing hooks before overwriting
- **Worktree count warning** - Configurable threshold with cleanup suggestion
- **fzf integration** - Interactive selection for worktree and branch operations
- **Colored terminal output** - Status indicators and formatting
- **Modular code structure** - Split into `lib/` directory for maintainability
  - `utils.sh` - Core utilities
  - `config.sh` - Configuration loading
  - `worktree.sh` - Worktree operations
  - `commands.sh` - Command handlers
- **Install script** - One-liner installation with shell detection
- **Comprehensive documentation** - README with examples and troubleshooting

### Fixed

- `wt -o` fzf picker not showing when no branch argument provided
- `git fetch` using branch name instead of remote name for fetching

### Changed

- Migrated from multiple `wt-*` commands to unified `wt` command with flags
- Refactored single-file script into modular library structure
