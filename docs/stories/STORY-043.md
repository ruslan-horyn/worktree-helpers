# STORY-043: Skip hooks flag (`--skip-hook`)

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** Backlog

---

## User Story

As a developer creating or switching worktrees in a scripted or CI context
I want to pass `--skip-hook` to suppress hook execution
So that I can use `wt` without triggering side effects (IDE opens, installs, etc.)

---

## Description

### Background

Hooks (`created.sh`, `switched.sh`) are powerful for interactive developer workflows — opening an IDE, running `npm install`, or changing the terminal's working directory. However, they become a liability in non-interactive contexts:

- Running `wt -n` in a shell script where an IDE open command would block or error
- CI pipelines using `wt` to set up parallel build worktrees (hooks would open IDEs on the build agent)
- Quick manual worktree creation when dependencies are already installed
- Debugging hook scripts themselves — triggering the hook while trying to fix it is disruptive

Currently the only way to suppress hooks is to edit `.worktrees/config.json` and remove the hook paths — a global, persistent change with no easy undo. `--skip-hook` provides a per-invocation escape hatch.

### Scope

**In scope:**
- `--skip-hook` flag accepted by `wt -n`, `wt -s`, and `wt -o`
- Hook script is still symlinked into the new worktree — it just is not executed
- An info message is printed: `[info] Hooks skipped (--skip-hook)`
- Flag is silently ignored for commands that have no hook behaviour (`-l`, `-c`, `-r`, `--init`, etc.)

**Out of scope:**
- Skipping hook symlinking (symlink still happens — only execution is suppressed)
- A global config option to disable hooks permanently (that is a separate concern)
- Skipping hooks for `wt -n -d` (dev branch variant) is not in scope unless trivial to include given shared code path

### User Flow

1. Developer calls `wt -n feature-x --skip-hook` (or `wt -s`, `wt -o`)
2. Router parses `--skip-hook` flag and sets `skip_hook=1`
3. `_cmd_new` / `_cmd_switch` / `_cmd_open` receives the flag and passes it through to `_wt_create` / `_wt_open` / `_run_hook`
4. `_wt_create` / `_wt_open` symlinks hooks as normal but does NOT call `_run_hook`
5. `_cmd_switch` skips the `_run_hook` call when flag is set
6. The info message `[info] Hooks skipped (--skip-hook)` is printed to stderr
7. All other worktree operations (branch creation, directory creation, git config) proceed normally

---

## Acceptance Criteria

- [ ] `--skip-hook` flag is accepted by `wt -n`, `wt -s`, and `wt -o` without error
- [ ] When `--skip-hook` is set, `_run_hook` is not called (hook script is not executed)
- [ ] Hook script is still symlinked into the new worktree when creating via `wt -n` or `wt -o`
- [ ] Info message is printed: `[info] Hooks skipped (--skip-hook)`
- [ ] `--skip-hook` is silently ignored for commands that do not use hooks (`-l`, `-c`, `-r`, etc.)
- [ ] `wt -n <branch> --help` shows `--skip-hook` in the options section
- [ ] `wt -s --help` shows `--skip-hook` in the options section
- [ ] `wt -o --help` shows `--skip-hook` in the options section
- [ ] BATS tests in `test/cmd_new.bats` verify hook is not called when `--skip-hook` is set
- [ ] BATS tests in `test/cmd_switch.bats` verify hook is not called when `--skip-hook` is set
- [ ] BATS tests in `test/cmd_open.bats` verify hook is not called when `--skip-hook` is set
- [ ] README updated with 1-3 lines describing the `--skip-hook` flag

---

## Technical Notes

### Components

- **`wt.sh`** — router: add `--skip-hook` to the flag-parsing `case` block, set `skip_hook=0` default, pass to affected `_cmd_*` calls
- **`lib/commands.sh`** — `_cmd_new`, `_cmd_switch`, `_cmd_open`: accept `skip_hook` parameter, pass to `_wt_create` / `_wt_open`, or guard `_run_hook` call directly; update `_help_new`, `_help_switch`, `_help_open`
- **`lib/worktree.sh`** — `_wt_create`, `_wt_open`: accept `skip_hook` parameter; guard the `_run_hook` call; print info message when skipping

### Implementation Approach

The cleanest approach is to pass `skip_hook` as a parameter rather than a global, keeping functions pure and testable.

```sh
# wt.sh router — add to locals and case block
local skip_hook=0
# ...
--skip-hook) skip_hook=1; shift ;;

# router dispatch — pass skip_hook
new)    _cmd_new "$arg" "$from_ref" "$skip_hook" ;;
switch) _cmd_switch "$arg" "$skip_hook" ;;
open)   _cmd_open "$arg" "$skip_hook" ;;
```

```sh
# lib/commands.sh
_cmd_new() {
  local branch="$1" from_ref="$2" skip_hook="${3:-0}"
  # ...
  _wt_create "$branch" "$base_ref" "$GWT_WORKTREES_DIR" "$skip_hook"
}

_cmd_switch() {
  local input="$1" skip_hook="${2:-0}"
  # ...
  if [ "$skip_hook" -eq 1 ]; then
    _info "Hooks skipped (--skip-hook)"
  else
    _run_hook switched "$wt_path" "$(_wt_branch "$wt_path")" "" "$(_main_repo_root)"
  fi
}

_cmd_open() {
  local branch="$1" skip_hook="${2:-0}"
  # ...
  _wt_open "$branch" "$GWT_WORKTREES_DIR" "$skip_hook"
}
```

```sh
# lib/worktree.sh
_wt_create() {
  local branch="$1" ref="$2" dir="$3" skip_hook="${4:-0}"
  # ... existing logic ...
  _symlink_hooks "$wt_path"
  _fetch "$ref"
  if [ "$skip_hook" -eq 1 ]; then
    _info "Hooks skipped (--skip-hook)"
  else
    _run_hook created "$wt_path" "$branch" "$ref" "$(_main_repo_root)"
  fi
  _wt_warn_count
}

_wt_open() {
  local branch="$1" dir="$2" skip_hook="${3:-0}"
  # ... existing logic ...
  _symlink_hooks "$wt_path"
  if [ "$skip_hook" -eq 1 ]; then
    _info "Hooks skipped (--skip-hook)"
  else
    _run_hook created "$wt_path" "$branch" "origin/$branch" "$(_main_repo_root)"
  fi
  _wt_warn_count
}
```

### Test Strategy

Tests should use `create_marker_hook` (from `test/test_helper.bash`) to create a hook that writes a marker file on execution. After calling the command with `--skip-hook`, assert that the marker file does NOT exist.

```bash
@test "_cmd_new --skip-hook does not execute created hook" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  create_marker_hook "$repo_dir/.worktrees/hooks/created.sh" "$repo_dir/hook_ran"

  run _cmd_new "feat-skip" "" "1"  # skip_hook=1
  assert_success
  assert_output --partial "Hooks skipped (--skip-hook)"
  assert [ ! -f "$repo_dir/hook_ran" ]
}
```

### Alternative Name Considered

`--no-hook` was considered (more idiomatic for negation flags). `--skip-hook` was chosen to match the project's existing naming style (imperative, action-oriented) and because it more clearly communicates the intent (skip this time, not disable globally).

### POSIX Compatibility

No bash/zsh-specific syntax needed. The parameter passing approach (`local skip_hook="${4:-0}"`) is POSIX-compatible.

---

## Dependencies

- None — this story has no prerequisite stories and does not block any known backlog story

---

## Definition of Done

- [ ] Code implemented in `wt.sh`, `lib/commands.sh`, and `lib/worktree.sh`
- [ ] `--skip-hook` flag parsed in the `wt()` router and passed through to all three affected commands
- [ ] Hook skip logic in `_wt_create`, `_wt_open`, and `_cmd_switch`
- [ ] Info message `[info] Hooks skipped (--skip-hook)` printed when flag is set and hook would otherwise run
- [ ] `_help_new`, `_help_switch`, `_help_open` updated with `--skip-hook` option
- [ ] README updated with 1-3 lines about `--skip-hook`
- [ ] BATS tests added covering:
  - [ ] `wt -n` with `--skip-hook` does not run hook, does symlink hooks
  - [ ] `wt -s` with `--skip-hook` does not run hook
  - [ ] `wt -o` with `--skip-hook` does not run hook
  - [ ] `wt -l --skip-hook` is silently ignored (no error)
  - [ ] Info message is present in output when flag is set
- [ ] All existing tests pass (`npm test`)
- [ ] Conventional commit with lowercase subject used

---

## Story Points Breakdown

- **Flag parsing (wt.sh router):** 0.5 points
- **Command handlers + worktree functions:** 1 point
- **Help text updates (3 functions):** 0.25 points
- **BATS tests:** 0.25 points
- **Total:** 2 points

**Rationale:** The change is additive and localised — no refactoring of existing logic required. The parameter threading through 4-5 functions is mechanical. Test coverage is straightforward using the existing `create_marker_hook` helper.

---

## Progress Tracking

**Status History:**
- 2026-02-21: Created (draft) as part of Sprint 6 backlog grooming
- 2026-02-22: Formalized by Scrum Master

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
