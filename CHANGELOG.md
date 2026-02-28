# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0](https://github.com/ruslan-horyn/worktree-helpers/compare/v1.4.0...v1.5.0) (2026-02-28)


### Added

* **STORY-021:** improve wt --init ux — colorized output, hook hints, auto .gitignore ([#26](https://github.com/ruslan-horyn/worktree-helpers/issues/26)) ([308f43f](https://github.com/ruslan-horyn/worktree-helpers/commit/308f43ff2da0d2426a3212d7616d65d6aa3e510a))
* **STORY-034:** add verbose feedback to wt -c and wt --init ([#20](https://github.com/ruslan-horyn/worktree-helpers/issues/20)) ([cd39226](https://github.com/ruslan-horyn/worktree-helpers/commit/cd39226e54b7a2fce8b00c82f682ab96f90b5c7a))
* **STORY-035:** offer to copy/backup existing hooks on wt --init ([#24](https://github.com/ruslan-horyn/worktree-helpers/issues/24)) ([c4831d5](https://github.com/ruslan-horyn/worktree-helpers/commit/c4831d527c5ac51b5b6b21b32e320ee41146c5ca))
* **STORY-037:** show placeholder hints in completions for free-form args ([#23](https://github.com/ruslan-horyn/worktree-helpers/issues/23)) ([a276e16](https://github.com/ruslan-horyn/worktree-helpers/commit/a276e16a09ac42b4f2a3a37f72382d43bb5af08b))
* **STORY-038:** add placeholders and examples to command help output ([#22](https://github.com/ruslan-horyn/worktree-helpers/issues/22)) ([ac6c431](https://github.com/ruslan-horyn/worktree-helpers/commit/ac6c431eb99f607245c836433e26abb75b4a6820))
* **STORY-039:** improve wt -c dry-run output readability ([#19](https://github.com/ruslan-horyn/worktree-helpers/issues/19)) ([9c4a4ac](https://github.com/ruslan-horyn/worktree-helpers/commit/9c4a4ac51f232a2916f3edf55d46332adb478b95))
* **STORY-049:** install wt as executable binary for non-interactive shell support ([#28](https://github.com/ruslan-horyn/worktree-helpers/issues/28)) ([09d1a3c](https://github.com/ruslan-horyn/worktree-helpers/commit/09d1a3cd4b48169b5ba4746244849b3e5c9ab0e9))


### Fixed

* **STORY-048:** fix install.sh false-positive already configured check ([#21](https://github.com/ruslan-horyn/worktree-helpers/issues/21)) ([f373d0a](https://github.com/ruslan-horyn/worktree-helpers/commit/f373d0a42a4972aacc7414001f3122eee3dd1b95))
* **worktree:** propagate fzf ESC exit code in _wt_select and _branch_select ([#27](https://github.com/ruslan-horyn/worktree-helpers/issues/27)) ([777ff06](https://github.com/ruslan-horyn/worktree-helpers/commit/777ff064ac9dafae18f0ca0e97bbc801482e2bd9))
* **wt:** wt --check routes to update check-only mode ([#25](https://github.com/ruslan-horyn/worktree-helpers/issues/25)) ([831e3e5](https://github.com/ruslan-horyn/worktree-helpers/commit/831e3e5aac9c0006e8735dc4b7663d0d838c7f1a))

## [1.4.0](https://github.com/ruslan-horyn/worktree-helpers/compare/v1.3.1...v1.4.0) (2026-02-22)


### Added

* **STORY-029:** protect main/dev branches from wt -c deletion ([#16](https://github.com/ruslan-horyn/worktree-helpers/issues/16)) ([172f4db](https://github.com/ruslan-horyn/worktree-helpers/commit/172f4db79ef588a5c7305322caf2b1e0f5bbdae5))
* **STORY-031:** replace slashes with dashes in worktree directory names ([#14](https://github.com/ruslan-horyn/worktree-helpers/issues/14)) ([e2e9971](https://github.com/ruslan-horyn/worktree-helpers/commit/e2e99711283f70c72140378a3ce45ac8a964ffcd))
* **STORY-032:** show only worktree name instead of full path everywhere ([#12](https://github.com/ruslan-horyn/worktree-helpers/issues/12)) ([cf2dbed](https://github.com/ruslan-horyn/worktree-helpers/commit/cf2dbeda9a44fedd3cf8ee6e7046fbab5ce86ff3))
* **STORY-033:** prompt to re-source after wt --update ([#13](https://github.com/ruslan-horyn/worktree-helpers/issues/13)) ([a560825](https://github.com/ruslan-horyn/worktree-helpers/commit/a5608252657ac211ded1e02ca41229251b50f432))
* **STORY-036:** add per-command help (wt <cmd> --help) ([#17](https://github.com/ruslan-horyn/worktree-helpers/issues/17)) ([ab42303](https://github.com/ruslan-horyn/worktree-helpers/commit/ab42303d7854b4462e65e212924ed6d13c8981c6))


### Fixed

* **STORY-030:** fix completions in warp + zsh to work like git ([#15](https://github.com/ruslan-horyn/worktree-helpers/issues/15)) ([471cf48](https://github.com/ruslan-horyn/worktree-helpers/commit/471cf4867460afc6822e1e79b31455c471ee0fef))

## [1.3.1](https://github.com/ruslan-horyn/worktree-helpers/compare/v1.3.0...v1.3.1) (2026-02-19)


### Fixed

* **STORY-028:** fix zsh completions and improve completion ux ([1db1f01](https://github.com/ruslan-horyn/worktree-helpers/commit/1db1f01ac6797372178ecffca4bde00c9a1a1645))

## [1.3.0](https://github.com/ruslan-horyn/worktree-helpers/compare/v1.2.0...v1.3.0) (2026-02-19)


### Added

* **STORY-011:** show dirty/clean status indicator in wt -l ([#9](https://github.com/ruslan-horyn/worktree-helpers/issues/9)) ([957b9a4](https://github.com/ruslan-horyn/worktree-helpers/commit/957b9a4b5f01fd0d7150f18396d5b1ef5ad8a41a))
* **STORY-013:** add self-update mechanism (wt --update) ([#11](https://github.com/ruslan-horyn/worktree-helpers/issues/11)) ([6913467](https://github.com/ruslan-horyn/worktree-helpers/commit/6913467e12debea2d35ac8046cb92411544f1237))
* **STORY-014:** add shell completions for bash and zsh ([ff6b019](https://github.com/ruslan-horyn/worktree-helpers/commit/ff6b019a9369c7f48de26fffbd3af821eef9ae70))


### Fixed

* suppress chpwd hook output in config detection, remove package.json requirement ([#8](https://github.com/ruslan-horyn/worktree-helpers/issues/8)) ([31dc412](https://github.com/ruslan-horyn/worktree-helpers/commit/31dc4125b46e7bd9478d49f6b8f308458a065923))

## [1.2.1](///compare/v1.2.0...v1.2.1) (2026-02-16)


### Fixed

* **STORY-027:** suppress chpwd hook output in _main_repo_root and remove _require_pkg gates f2de68d

## [1.2.0](https://github.com/ruslan-horyn/worktree-helpers/compare/v1.1.0...v1.2.0) (2026-02-16)


### Added

* add --from/-b flag to wt -n for custom base branch ([#2](https://github.com/ruslan-horyn/worktree-helpers/issues/2)) ([c019061](https://github.com/ruslan-horyn/worktree-helpers/commit/c0190618b2ad054601612bcbcd8914714f23707c))
* **STORY-015:** add granular clear options (--merged, --pattern, --dry-run) ([#6](https://github.com/ruslan-horyn/worktree-helpers/issues/6)) ([c7e9da2](https://github.com/ruslan-horyn/worktree-helpers/commit/c7e9da22d5a774f61a198aaf674a22a39ca6f4d5))
* **STORY-022:** add shell-aware tab completion to wt --init prompts ([#5](https://github.com/ruslan-horyn/worktree-helpers/issues/5)) ([10c8e6b](https://github.com/ruslan-horyn/worktree-helpers/commit/10c8e6bd55daddf55d5b130e360fe66468410524))
* **STORY-025:** improve UX when opening worktree from existing branch ([#3](https://github.com/ruslan-horyn/worktree-helpers/issues/3)) ([3f5a5d0](https://github.com/ruslan-horyn/worktree-helpers/commit/3f5a5d086a6eb59f6442979671dadcced50914b7))
* warp tabs + sprint-orchestrator worktree mode for launch-sprint ([ec79473](https://github.com/ruslan-horyn/worktree-helpers/commit/ec79473af6bd378774daed88c8d28f605b5a5283))


### Fixed

* handle config.lock race in concurrent worktree creation ([48d1294](https://github.com/ruslan-horyn/worktree-helpers/commit/48d1294683fa2902b6bd1761e7a791262e007697))
* prevent double origin/ prefix in _normalize_ref without remotes ([#7](https://github.com/ruslan-horyn/worktree-helpers/issues/7)) ([e100235](https://github.com/ruslan-horyn/worktree-helpers/commit/e100235ae0aac0d7752c1e3e4800967314036e04))


### Changed

* redesign launch-sprint and sprint-orchestrator skills ([4ede421](https://github.com/ruslan-horyn/worktree-helpers/commit/4ede4210c288b30b2d8c6242050ab8284e95cc8f))
* remove worktreesDir from config, always auto-derive path ([#4](https://github.com/ruslan-horyn/worktree-helpers/issues/4)) ([b362cec](https://github.com/ruslan-horyn/worktree-helpers/commit/b362cecc63f8f99852548ef73b356bdba11bfa6b))

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
