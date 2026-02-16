# STORY-027: Fix config detection fails when chpwd hooks output text

**Epic:** Core Reliability
**Priority:** Must Have
**Story Points:** 3
**Status:** Pending
**Assigned To:** Unassigned
**Created:** 2026-02-16
**Sprint:** 5

---

## User Story

As a developer using worktree-helpers with zsh chpwd hooks (nvm, direnv, oh-my-zsh plugins)
I want `wt` commands to work correctly regardless of shell hooks that print output on directory change
So that I don't get false "Run 'wt --init' first" errors when my config is properly set up

---

## Description

### Background

`_main_repo_root()` in `lib/utils.sh:15-18` uses `(cd "$d/.." && pwd -P)` without suppressing cd output. When users have zsh `chpwd` hooks (nvm, direnv, oh-my-zsh plugins) that print text on directory change, that output contaminates the captured path. This causes `_config_load` to construct an invalid config path, resulting in "Run 'wt --init' first" even though `.worktrees/config.json` exists.

The correct pattern already exists in the same codebase at `wt.sh:17`:
```sh
(cd "$_dir" >/dev/null 2>&1 || exit; pwd -P)
```

But `lib/utils.sh:17` is missing the suppression:
```sh
(cd "$d/.." && pwd -P)
```

Additionally, `_require_pkg` at `lib/utils.sh:24` requires `package.json` to exist, meaning `wt` only works in Node.js projects. This is unnecessarily restrictive since `_project_name()` already falls back to `basename $PWD` when `package.json` is absent. Every command handler in `lib/commands.sh` calls `_require_pkg`, preventing `wt` from working in non-Node.js repositories.

### Scope

**In scope:**
- Fix `_main_repo_root` in `lib/utils.sh` to suppress cd output with `>/dev/null 2>&1`
- Audit all other `cd` calls in `lib/*.sh` for the same issue (only `_main_repo_root` is currently affected)
- Remove `_require_pkg` calls from all 11 command handlers in `lib/commands.sh`
- Keep `_require_pkg` function definition in `lib/utils.sh` (it may be useful for user hooks)
- Add BATS test for chpwd hook contamination scenario
- Update existing tests that depend on `_require_pkg` behavior

**Out of scope:**
- Removing the `_require_pkg` function definition entirely (keep for potential user hook use)
- Changing `_project_name()` fallback logic
- Adding new `package.json` detection warnings

### Backward Compatibility

- The cd suppression fix is transparent — output is identical for users without chpwd hooks
- Removing `_require_pkg` from command handlers is backward compatible for Node.js projects (they still work identically) and is a strict improvement for non-Node.js projects (they now work where they previously failed)

---

## Acceptance Criteria

- [ ] `_main_repo_root` suppresses cd output with `>/dev/null 2>&1`, matching the pattern in `wt.sh:17`
- [ ] No other `cd` calls in `lib/*.sh` are missing output suppression (audit confirms `_main_repo_root` was the only affected call)
- [ ] `_require_pkg` is removed from all 11 command handlers in `lib/commands.sh` (`_cmd_new`, `_cmd_dev`, `_cmd_switch`, `_cmd_remove`, `_cmd_open`, `_cmd_lock`, `_cmd_unlock`, `_cmd_clear`, `_cmd_log`, `_cmd_init`, `_cmd_rename`)
- [ ] `_require_pkg` function definition remains in `lib/utils.sh`
- [ ] `wt` commands work in non-Node.js git repositories (no `package.json` required)
- [ ] `wt` commands work correctly when zsh chpwd hooks print output on directory change
- [ ] All existing BATS tests pass (updated as needed)
- [ ] New BATS test verifies `_main_repo_root` is not contaminated by cd output

---

## Technical Notes

### Components

- **`lib/utils.sh`** — fix `_main_repo_root` cd output suppression (primary bug fix)
- **`lib/commands.sh`** — remove `_require_pkg` from 11 command handlers (secondary fix)
- **`test/utils.bats`** — add test for chpwd hook contamination; keep `_require_pkg` unit tests
- **`test/commands.bats`** and other command test files — remove or update tests that depend on `_require_pkg` gating behavior

### Changes Detail

**1. `lib/utils.sh` — `_main_repo_root` (line 17)**

```sh
# Before:
_main_repo_root() {
  local d; d=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
  (cd "$d/.." && pwd -P)
}

# After:
_main_repo_root() {
  local d; d=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
  (cd "$d/.." >/dev/null 2>&1 && pwd -P)
}
```

**2. `lib/commands.sh` — remove `_require_pkg` from all handlers**

Each handler's guard clause changes from:
```sh
_require_pkg && _repo_root >/dev/null && _config_load || return 1
```
To:
```sh
_repo_root >/dev/null && _config_load || return 1
```

And simpler guards change from:
```sh
_require_pkg && _repo_root >/dev/null || return 1
```
To:
```sh
_repo_root >/dev/null || return 1
```

The `_cmd_init` guard changes from:
```sh
_require_pkg && _repo_root >/dev/null && _require jq || return 1
```
To:
```sh
_repo_root >/dev/null && _require jq || return 1
```

All 11 occurrences (lines 5, 16, 27, 34, 54, 77, 84, 92, 432, 459, 509).

**3. `test/utils.bats` — add chpwd contamination test**

```sh
@test "_main_repo_root is not contaminated by cd output" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Simulate a chpwd hook that prints text when cd is invoked
  cd() { echo "chpwd: entering $1"; builtin cd "$@"; }
  export -f cd

  run _main_repo_root
  assert_success
  assert_output "$repo_dir"

  unset -f cd
}
```

Note: The exact test mechanism may need adjustment since POSIX subshells may not inherit function overrides. An alternative approach is to verify the output contains no newlines and matches expected path format.

### Edge Cases

- **Users without chpwd hooks:** No behavioral change — `>/dev/null 2>&1` silently discards empty stderr/stdout from cd
- **Users with multiple chpwd hooks:** All output is suppressed regardless of how many hooks fire
- **cd failure:** The `&&` chain still short-circuits correctly if cd fails (same error handling as before)
- **Non-Node.js projects without package.json:** Now work correctly with `_project_name()` fallback to `basename $PWD`
- **Projects with package.json:** No change in behavior — `_project_name()` still reads from package.json when available

### Security Considerations

- No new inputs or attack surface
- The cd suppression is purely cosmetic (discards hook output that was never intended to be captured)
- Removing `_require_pkg` does not introduce any security risk; it was a convenience check, not a security gate

---

## Dependencies

**Prerequisite Stories:**
- None (standalone bug fix)

**Blocked Stories:**
- None

**Related Stories:**
- STORY-026: Remove worktreesDir from config — also modifies `_config_load` path construction; ensure no merge conflicts if both are in-flight

**External Dependencies:**
- None

---

## Definition of Done

- [ ] `lib/utils.sh` — `_main_repo_root` cd call includes `>/dev/null 2>&1`
- [ ] `lib/commands.sh` — `_require_pkg` removed from all 11 command handler guard clauses
- [ ] `test/utils.bats` — new test verifying `_main_repo_root` output is not contaminated by cd hook output
- [ ] Existing `_require_pkg` unit tests in `test/utils.bats` remain (function still exists)
- [ ] Command test files updated to remove dependency on `package.json` existing (if applicable)
- [ ] Audit of all `cd` calls in `lib/*.sh` completed and documented (only `_main_repo_root` affected)
- [ ] All existing BATS tests pass
- [ ] Shellcheck passes on modified files
- [ ] CI pipeline green
- [ ] Manual testing: `wt` commands work in a git repo without `package.json`

---

## Story Points Breakdown

- **`_main_repo_root` fix:** 0.5 points (one-line change + audit of other cd calls)
- **`_require_pkg` removal:** 1 point (11 occurrences in commands.sh, straightforward but needs careful verification)
- **Test additions/updates:** 1 point (new contamination test + update command tests that relied on `_require_pkg`)
- **Manual testing and verification:** 0.5 points
- **Total:** 3 points

**Rationale:** Both fixes are well-understood and surgical. The primary effort is in updating tests and verifying all 11 command handlers work correctly without `_require_pkg`. The cd suppression fix is a one-liner with a clear pattern to follow.

---

## Additional Notes

- The chpwd hook contamination bug is particularly insidious because it only manifests for users with certain shell plugins (nvm auto-use, direnv, oh-my-zsh themes that print directory info). Users without these plugins never encounter the issue, making it hard to reproduce in CI.
- The `_require_pkg` restriction was likely a holdover from when the project was Node.js-specific. With `_project_name()` already having a `basename $PWD` fallback, there is no functional reason to require `package.json`.
- After this story, `wt` will work in any git repository regardless of language/framework — a significant improvement to the tool's generality.

---

## Progress Tracking

**Status History:**
- 2026-02-16: Created

**Actual Effort:** TBD
