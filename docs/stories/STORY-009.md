# STORY-009: Add test suite with BATS

**Epic:** Quality Infrastructure
**Priority:** Must Have
**Story Points:** 8
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-08
**Sprint:** 3

---

## User Story

As a developer
I want automated tests for all `wt` commands
So that I can refactor and add features with confidence that existing functionality isn't broken

---

## Description

### Background

The worktree-helpers CLI (`wt`) has grown to 4 library modules with ~25 public functions, 11 commands, and multiple edge cases. All testing is currently manual — source `wt.sh`, run commands, visually verify. This is fragile: any change can silently break existing behavior. A comprehensive test suite is the foundation for safe iteration and CI integration (STORY-010).

### Scope

**In scope:**
- BATS framework setup (`bats-core`, `bats-support`, `bats-assert` as git submodules)
- Test helper with common setup/teardown (create temp git repos, mock configs, cleanup)
- Unit tests for `lib/utils.sh` functions (`_err`, `_info`, `_debug`, `_require`, `_repo_root`, `_main_repo_root`, `_branch_exists`, `_current_branch`, `_main_branch`, `_normalize_ref`, `_project_name`, `_calc_cutoff`, `_wt_age`, `_init_colors`, `_age_display`, `_wt_count`, `_wt_warn_count`)
- Unit tests for `lib/config.sh` (`_config_load` with various config.json inputs, defaults, missing config)
- Unit tests for `lib/worktree.sh` helpers (`_wt_path`, `_wt_branch`, `_wt_resolve`, `_symlink_hooks`, `_run_hook`, `_fetch`, `_wt_create`, `_wt_open`)
- Integration tests for each command handler in `lib/commands.sh`: `_cmd_new`, `_cmd_dev`, `_cmd_switch`, `_cmd_remove`, `_cmd_open`, `_cmd_lock`, `_cmd_unlock`, `_cmd_clear`, `_cmd_list`, `_cmd_log`, `_cmd_init`, `_cmd_help`
- Edge case coverage: missing config, missing dependencies (jq, fzf), invalid arguments, empty worktree list, locked worktrees, detached HEAD
- Hook execution tests with mock hook scripts
- `npm test` script in package.json for running the suite

**Out of scope:**
- Performance benchmarking
- Testing with alternative shells beyond bash (zsh-specific behavior)
- Code coverage reporting tooling (can be added later)
- fzf interactive selection testing (requires TTY mocking)

---

## User Flow

1. Developer makes a code change to `wt.sh` or any `lib/*.sh` file
2. Developer runs `npm test` (or `bats test/`)
3. BATS discovers and runs all `*.bats` test files
4. Tests execute in isolated temp directories — no effect on real repos
5. Pass/fail results shown in terminal with clear output
6. Developer gets immediate feedback on regressions

---

## Acceptance Criteria

- [ ] BATS framework installed and configured (`bats-core`, `bats-support`, `bats-assert` as git submodules under `test/libs/`)
- [ ] `npm test` script added to `package.json` that runs `bats test/`
- [ ] Test helper (`test/test_helper.bash`) provides:
  - Temp directory creation and cleanup (per-test isolation)
  - Mock git repo initialization (with at least one commit)
  - Mock `.worktrees/config.json` generation with configurable values
  - Helper to source all `wt` library files
  - Mock hook script creation
- [ ] Unit tests for core utilities (`lib/utils.sh`):
  - `_err` writes to stderr
  - `_info` writes to stdout
  - `_debug` only outputs when `GWT_DEBUG=1`
  - `_require` passes for installed commands, fails for missing
  - `_repo_root` returns correct path inside a git repo, errors outside
  - `_main_repo_root` returns correct path (including from worktrees)
  - `_branch_exists` detects existing/missing branches
  - `_current_branch` returns the checked-out branch name
  - `_main_branch` detects origin/main or origin/master
  - `_normalize_ref` adds origin/ prefix when needed
  - `_project_name` reads from package.json or falls back to dirname
  - `_calc_cutoff` returns correct timestamp
  - `_age_display` returns "today", "1 day ago", "N days ago"
  - `_wt_count` returns correct worktree count
  - `_wt_warn_count` warns only above threshold
- [ ] Unit tests for config loading (`lib/config.sh`):
  - `_config_load` parses all fields from config.json
  - `_config_load` applies defaults for missing fields
  - `_config_load` errors when config.json missing (prompts `wt --init`)
  - `_config_load` resolves relative hook paths to absolute
- [ ] Integration tests for command handlers (`lib/commands.sh`):
  - `_cmd_new` creates worktree and branch from main ref
  - `_cmd_new` rejects duplicate branch names
  - `_cmd_new` errors without branch argument
  - `_cmd_dev` creates branch with dev suffix
  - `_cmd_switch` resolves worktree by branch name
  - `_cmd_remove` removes worktree and deletes branch (with force)
  - `_cmd_open` opens existing remote branch as worktree
  - `_cmd_open` errors for non-existent branches
  - `_cmd_lock` / `_cmd_unlock` set lock state correctly
  - `_cmd_list` displays worktrees with branch names and lock status
  - `_cmd_clear` removes worktrees older than N days, skips locked
  - `_cmd_clear` errors on invalid input (non-numeric, no args)
  - `_cmd_clear` respects `--dev-only` and `--main-only` filters
  - `_cmd_clear` rejects mutually exclusive `--dev-only --main-only`
  - `_cmd_init` creates config.json and hook files
  - `_cmd_log` shows commits between main and feature branch
  - `_cmd_help` outputs usage text
- [ ] Hook execution tests (`lib/worktree.sh`):
  - `_run_hook` executes hook with correct arguments (wt_path, branch, base, root)
  - `_run_hook` skips non-executable hooks silently
  - `_run_hook` skips missing hooks silently
  - `_symlink_hooks` creates symlink from main repo to worktree
- [ ] Edge case tests:
  - Commands error gracefully when not in a git repo
  - Commands error gracefully when `package.json` is missing
  - Commands error gracefully when `jq` is not available
  - `_cmd_clear` handles empty worktree list (only main)
  - `_cmd_list` handles no worktrees (only main)
  - `_wt_resolve` returns path for directory input
- [ ] Tests pass on both macOS and Linux (POSIX-compatible assertions)
- [ ] All test files follow naming convention: `test/{module}.bats`

---

## Technical Notes

### Test Framework

- **bats-core**: Main test runner
- **bats-support**: Common assertion helpers (`fail`, `refute`)
- **bats-assert**: Output assertions (`assert_success`, `assert_failure`, `assert_output`, `assert_line`)
- Install as git submodules under `test/libs/` to keep them out of the runtime install

### Directory Structure

```
test/
  libs/
    bats-core/          # git submodule
    bats-support/       # git submodule
    bats-assert/        # git submodule
  test_helper.bash      # Shared setup/teardown, fixtures
  utils.bats            # Tests for lib/utils.sh
  config.bats           # Tests for lib/config.sh
  worktree.bats         # Tests for lib/worktree.sh (_wt_path, _wt_branch, etc.)
  cmd_new.bats          # Tests for _cmd_new, _cmd_dev
  cmd_switch.bats       # Tests for _cmd_switch
  cmd_remove.bats       # Tests for _cmd_remove
  cmd_open.bats         # Tests for _cmd_open
  cmd_lock.bats         # Tests for _cmd_lock, _cmd_unlock
  cmd_list.bats         # Tests for _cmd_list
  cmd_clear.bats        # Tests for _cmd_clear
  cmd_init.bats         # Tests for _cmd_init
  cmd_log.bats          # Tests for _cmd_log
  cmd_help.bats         # Tests for _cmd_help
  hooks.bats            # Tests for _run_hook, _symlink_hooks
```

### Test Helper Design (`test/test_helper.bash`)

```bash
# Load BATS libraries
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# Create isolated temp directory per test
setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"
}

# Cleanup after each test
teardown() {
  cd /
  rm -rf "$TEST_TEMP_DIR"
}

# Initialize a bare git repo (acts as "origin")
create_origin_repo() {
  local origin_dir="$TEST_TEMP_DIR/origin.git"
  git init --bare "$origin_dir"
  echo "$origin_dir"
}

# Initialize a working git repo with origin remote and initial commit
create_test_repo() {
  local repo_dir="$TEST_TEMP_DIR/repo"
  local origin_dir; origin_dir=$(create_origin_repo)
  git clone "$origin_dir" "$repo_dir" 2>/dev/null
  cd "$repo_dir"
  # Create initial commit
  echo "init" > README.md
  git add README.md
  git commit -m "initial commit"
  git push origin main 2>/dev/null || git push origin master 2>/dev/null
  # Create package.json
  echo '{"name":"test-project"}' > package.json
  echo "$repo_dir"
}

# Create .worktrees/config.json with test defaults
create_test_config() {
  local repo_dir="${1:-$PWD}"
  mkdir -p "$repo_dir/.worktrees/hooks"
  cat > "$repo_dir/.worktrees/config.json" <<JSON
{
  "projectName": "test-project",
  "worktreesDir": "$TEST_TEMP_DIR/test-project_worktrees",
  "mainBranch": "origin/main",
  "devBranch": "origin/main",
  "devSuffix": "_RN",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh",
  "worktreeWarningThreshold": 20
}
JSON
  # Create executable hook scripts
  echo '#!/usr/bin/env bash' > "$repo_dir/.worktrees/hooks/created.sh"
  echo 'cd "$1" || exit 1' >> "$repo_dir/.worktrees/hooks/created.sh"
  echo '#!/usr/bin/env bash' > "$repo_dir/.worktrees/hooks/switched.sh"
  echo 'cd "$1" || exit 1' >> "$repo_dir/.worktrees/hooks/switched.sh"
  chmod +x "$repo_dir/.worktrees/hooks"/*.sh
}

# Source all wt library files
load_wt() {
  local wt_dir="$PROJECT_ROOT"
  source "$wt_dir/lib/utils.sh"
  source "$wt_dir/lib/config.sh"
  source "$wt_dir/lib/worktree.sh"
  source "$wt_dir/lib/commands.sh"
}
```

### Key Testing Patterns

1. **Isolation**: Every test gets a fresh temp directory. No test touches the real filesystem outside `/tmp`.
2. **Real git repos**: Tests create actual git repositories (clone from bare origin) — not mocks. This ensures `git worktree` commands work correctly.
3. **Config injection**: `create_test_config()` writes config.json with temp paths so worktrees are created inside `$TEST_TEMP_DIR`.
4. **Hook testing**: Create mock hooks that write to a marker file, then assert the marker exists and contains expected args.
5. **stderr/stdout separation**: Use `run` with `assert_output` for stdout, capture stderr with `2>&1` redirection where needed.
6. **Skip fzf tests**: Any test that would invoke fzf is skipped (interactive selection can't be tested in BATS). Test the non-fzf code paths.
7. **Cross-platform**: Use POSIX date/stat variations already in the codebase (`date -v` vs `date -d`, `stat -f` vs `stat -c`).

### Edge Cases to Cover

- **No git repo**: Commands called from outside a git repository
- **No package.json**: Commands that require `_require_pkg`
- **Missing jq**: `_config_load` and `_cmd_init` behavior
- **Missing config**: Commands called before `wt --init`
- **Empty worktree list**: Only main repo in worktree list
- **Locked worktrees**: `_cmd_clear` skipping, `_cmd_lock`/`_cmd_unlock` toggling
- **Duplicate branches**: `_cmd_new` rejecting existing branch names
- **Detached HEAD**: Worktree listing with detached HEAD entries
- **Mutually exclusive flags**: `--dev-only` + `--main-only` on `_cmd_clear`
- **Age filtering**: Worktrees just above/below cutoff age

### Package.json Change

Add to `scripts`:
```json
"test": "bats test/"
```

### Git Submodule Commands

```bash
git submodule add https://github.com/bats-core/bats-core.git test/libs/bats-core
git submodule add https://github.com/bats-core/bats-support.git test/libs/bats-support
git submodule add https://github.com/bats-core/bats-assert.git test/libs/bats-assert
```

### Security Considerations

- Tests must clean up temp directories (no leftover git repos)
- Tests must not interact with the user's real git config or repos
- No network calls in tests (no `git fetch` from real remotes — use local bare repos)

---

## Dependencies

**Prerequisite Stories:**
- None (this is foundational work)

**Blocked Stories:**
- STORY-010: Add CI/CD pipeline — requires test suite to exist

**External Dependencies:**
- `bats-core` (installed as git submodule)
- `bats-support` (installed as git submodule)
- `bats-assert` (installed as git submodule)
- `git` (already required by the project)
- `jq` (already required by the project)

---

## Definition of Done

- [ ] BATS submodules added and loadable
- [ ] `test/test_helper.bash` provides setup/teardown and fixture helpers
- [ ] Unit tests for `lib/utils.sh` — all functions covered
- [ ] Unit tests for `lib/config.sh` — `_config_load` with valid, default, and missing configs
- [ ] Integration tests for all 12 command handlers in `lib/commands.sh`
- [ ] Hook execution tests (`_run_hook`, `_symlink_hooks`)
- [ ] Edge case tests (no git repo, no package.json, no jq, no config, empty list, locked worktrees)
- [ ] `npm test` runs the full suite successfully
- [ ] All tests pass on macOS (developer machine)
- [ ] Tests use only isolated temp directories — no side effects
- [ ] No regressions in existing functionality
- [ ] Code follows existing patterns (POSIX-compatible test code)

---

## Story Points Breakdown

- **Framework setup** (submodules, test_helper, npm script): 1 point
- **Utils unit tests** (~18 functions): 2 points
- **Config unit tests**: 1 point
- **Command integration tests** (12 commands): 3 points
- **Hook + edge case tests**: 1 point
- **Total:** 8 points

**Rationale:** The 8-point estimate reflects the high number of functions to test (~25), the need for real git repo fixtures (more complex than simple mocks), and platform-specific date/stat handling. The test helper setup is a one-time cost that accelerates individual test authoring.

---

## Additional Notes

- **Test naming**: Each `.bats` file should map to a source module or command for easy navigation
- **Run subset**: Developers can run individual test files: `bats test/utils.bats`
- **Future**: After STORY-010 (CI), these tests will run automatically on every PR
- **fzf paths**: Functions like `_wt_select`, `_branch_select` that depend on fzf should be tested only for their error case (fzf not installed). The interactive fzf flow cannot be tested in BATS.
- **.gitmodules**: The submodule additions will create/modify `.gitmodules` — ensure it's committed

---

## Progress Tracking

**Status History:**
- 2026-02-08: Created
- 2026-02-08: Completed

**Actual Effort:** 8 points (matched estimate)

**Implementation Notes:**
- BATS framework: bats-core, bats-support, bats-assert as git submodules under test/libs/
- Test helper (test/test_helper.bash): temp dir isolation with symlink resolution for macOS, mock git repo creation with bare origin, config generation, marker hook helpers
- 99 tests across 14 test files covering all 4 library modules
- Test files: utils.bats, config.bats, worktree.bats, hooks.bats, cmd_new.bats, cmd_switch.bats, cmd_remove.bats, cmd_open.bats, cmd_lock.bats, cmd_list.bats, cmd_clear.bats, cmd_init.bats, cmd_log.bats, cmd_help.bats, edge_cases.bats
- All tests use isolated temp directories with real git repos (clone from bare origin)
- `npm test` runs full suite via test/libs/bats-core/bin/bats
- Cross-platform: resolves macOS /var -> /private/var symlink for path matching

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
