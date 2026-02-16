# STORY-027: Fix config detection fails when chpwd hooks output text

**Epic:** Core Reliability
**Priority:** Must Have
**Story Points:** 3
**Status:** Complete
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

- [x] `_main_repo_root` suppresses cd output with `>/dev/null 2>&1`, matching the pattern in `wt.sh:17`
- [x] No other `cd` calls in `lib/*.sh` are missing output suppression (audit confirms `_main_repo_root` was the only affected call)
- [x] `_require_pkg` is removed from all 11 command handlers in `lib/commands.sh` (`_cmd_new`, `_cmd_dev`, `_cmd_switch`, `_cmd_remove`, `_cmd_open`, `_cmd_lock`, `_cmd_unlock`, `_cmd_clear`, `_cmd_log`, `_cmd_init`, `_cmd_rename`)
- [x] `_require_pkg` function definition remains in `lib/utils.sh`
- [x] `wt` commands work in non-Node.js git repositories (no `package.json` required)
- [x] `wt` commands work correctly when zsh chpwd hooks print output on directory change
- [x] All existing BATS tests pass (updated as needed)
- [x] New BATS test verifies `_main_repo_root` is not contaminated by cd output

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

- [x] `lib/utils.sh` — `_main_repo_root` cd call includes `>/dev/null 2>&1`
- [x] `lib/commands.sh` — `_require_pkg` removed from all 11 command handler guard clauses
- [x] `test/utils.bats` — new test verifying `_main_repo_root` output is not contaminated by cd hook output
- [x] Existing `_require_pkg` unit tests in `test/utils.bats` remain (function still exists)
- [x] Command test files updated to remove dependency on `package.json` existing (if applicable)
- [x] Audit of all `cd` calls in `lib/*.sh` completed and documented (only `_main_repo_root` affected)
- [x] All existing BATS tests pass
- [x] Shellcheck passes on modified files
- [ ] CI pipeline green
- [x] Manual testing: `wt` commands work in a git repo without `package.json`

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
- 2026-02-16: Implementation started
- 2026-02-16: Implementation complete, all tests passing, shellcheck clean

**Actual Effort:** 3 points (matched estimate)

**Files Changed:**

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/utils.sh` | Modified | Added `>/dev/null 2>&1` to `cd` call in `_main_repo_root` (line 17) to suppress chpwd hook output |
| `lib/commands.sh` | Modified | Removed `_require_pkg &&` from all 11 command handler guard clauses |
| `test/utils.bats` | Modified | Added 2 new tests: chpwd hook contamination simulation, single-line output verification |
| `test/cmd_init.bats` | Modified | Replaced `_cmd_init errors when package.json missing` with `_cmd_init works in non-Node.js repo` |
| `test/edge_cases.bats` | Modified | Replaced `commands error gracefully when package.json is missing` with `commands work in non-Node.js repo without package.json` |

**Tests Added:**
- `_main_repo_root is not contaminated by cd output (chpwd hook simulation)` -- verifies that overriding `cd` with a function that prints stdout/stderr does not contaminate `_main_repo_root` output
- `_main_repo_root output is a single line with no extra content` -- verifies output is exactly one line starting with `/`
- `_cmd_init works in non-Node.js repo (no package.json)` -- verifies `_cmd_init` works in a git repo without `package.json`
- `commands work in non-Node.js repo without package.json` -- verifies `_cmd_new` works in a git repo without `package.json`

**Test Results:**
- 180/180 BATS tests pass
- Shellcheck clean on all `lib/*.sh` files

**Decisions Made:**
- **cd audit:** Confirmed only `_main_repo_root` was affected. Other `cd` calls in `lib/commands.sh` are direct shell navigation (output goes to terminal, not captured) or embedded in hook script strings.
- **Test approach for chpwd simulation:** Used `export -f cd` in a bash subshell to override `cd` with a function that prints to both stdout and stderr, then verified `_main_repo_root` output is clean. Initial `cd` to repo dir uses `builtin cd` to avoid contamination from setup.
- **_require_pkg function retained:** Kept `_require_pkg()` definition in `lib/utils.sh` per story scope (may be useful for user hooks).
- **Existing _require_pkg unit tests retained:** Tests 152-153 still verify the function works correctly for users who call it from hooks.

---

## QA Review

### Files Reviewed
| File | Status | Notes |
|------|--------|-------|
| `lib/utils.sh` | Pass | `_main_repo_root` cd now suppresses output with `>/dev/null 2>&1`; `_require_pkg` function definition retained at line 24; all variables properly quoted; POSIX-compliant |
| `lib/commands.sh` | Pass | All 11 `_require_pkg &&` guard clauses removed from command handlers; no residual `_require_pkg` references; all other code unchanged; POSIX-compliant |
| `test/utils.bats` | Pass | 2 new tests added: chpwd contamination simulation (line 122) and single-line output verification (line 143); both use proper assertions; existing `_require_pkg` unit tests retained (tests 152-153) |
| `test/cmd_init.bats` | Pass | Replaced `_cmd_init errors when package.json missing` with `_cmd_init works in non-Node.js repo (no package.json)`; properly initializes a git repo with commit before testing; uses `bash -c` subshell for correct sourcing |
| `test/edge_cases.bats` | Pass | Replaced `commands error gracefully when package.json is missing` with `commands work in non-Node.js repo without package.json`; sets up bare origin + clone for realistic test environment with config |

### Issues Found
None

### AC Verification
- [x] AC 1 — `_main_repo_root` suppresses cd output: verified in `lib/utils.sh:17`, tested by `_main_repo_root is not contaminated by cd output (chpwd hook simulation)` (test #130)
- [x] AC 2 — No other `cd` calls missing suppression: audit of all `cd` calls in `lib/*.sh` confirms only `_main_repo_root` was affected (5 other `cd` calls are direct navigation or in hook strings, none captured via subshell)
- [x] AC 3 — `_require_pkg` removed from all 11 command handlers: verified by diff (11 removals) and grep (0 occurrences in `lib/commands.sh`)
- [x] AC 4 — `_require_pkg` function definition remains in `lib/utils.sh`: confirmed at line 24, unit tests 152-153 still exercise it
- [x] AC 5 — `wt` commands work in non-Node.js repos: tested by `commands work in non-Node.js repo without package.json` (test #108) and `_cmd_init works in non-Node.js repo (no package.json)` (test #29)
- [x] AC 6 — `wt` commands work with chpwd hooks: tested by `_main_repo_root is not contaminated by cd output (chpwd hook simulation)` (test #130)
- [x] AC 7 — All existing BATS tests pass: 180/180 pass
- [x] AC 8 — New BATS test verifies `_main_repo_root` not contaminated: test #130 and test #131

### Test Results
- Total: 180 / Passed: 180 / Failed: 0

### Shellcheck
- Clean: yes

## Manual Testing

### Test Scenarios
| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | `_main_repo_root` returns clean path (no extra output) in a git repo | Returns single absolute path, no extra lines | Returned single absolute path matching repo root exactly; line count = 1, starts with `/` | Pass |
| 2 | `wt` commands work in a git repository WITHOUT `package.json` | `_cmd_new`, `_cmd_list` succeed; worktree created correctly | `_cmd_new "test-branch"` exit 0, worktree visible in `git worktree list`; `_cmd_list` exit 0 with correct output | Pass |
| 3 | `wt` commands still work in a git repository WITH `package.json` | `_cmd_new`, `_cmd_list` succeed; `_project_name` reads from `package.json` | `_cmd_new` exit 0; `_cmd_list` exit 0; `_project_name` returned `my-node-project` from `package.json` | Pass |
| 4 | `_main_repo_root` with simulated chpwd hook output does not contaminate the path | Clean path even when `cd` override prints to stdout/stderr | 4a: single chpwd hook — PASS (clean path); 4b: multiple hooks (nvm, direnv, oh-my-zsh) — PASS; 4c: line count = 1 — PASS | Pass |
| 5 | `wt -h` works without `package.json` | Full help text printed, exit 0 | Full help text printed correctly, exit 0 | Pass |
| 6 | `wt -l` works without `package.json` (after `wt --init`) | Lists worktrees, exit 0 | `wt --init` created config with basename fallback for project name; `wt -l` listed main worktree; `wt -n feature-xyz` created worktree; second `wt -l` showed both worktrees | Pass |

### Additional Verifications
| # | Check | Result |
|---|-------|--------|
| 7 | `_require_pkg` removed from all command handlers in `lib/commands.sh` | Confirmed: `grep _require_pkg lib/commands.sh` returns 0 matches |
| 8 | `_require_pkg` function definition retained in `lib/utils.sh` | Confirmed: function exists at line 24 |
| 9 | cd audit in `lib/*.sh` — no other cd calls captured in subshells without suppression | Confirmed: 5 other cd calls are all direct navigation (not captured), only `_main_repo_root` was affected |
| 10 | Shellcheck clean on `lib/utils.sh`, `lib/commands.sh`, `lib/config.sh` | Clean: no warnings or errors |
| 11 | BATS test suite (automated) | 180/180 tests pass |

### Issues Found
None
