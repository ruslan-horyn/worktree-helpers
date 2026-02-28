# STORY-050: Fix `wt --check` showing help instead of update status

**Epic:** Bug Fixes
**Priority:** Must Have
**Story Points:** 1
**Status:** completed
**Assigned To:** Unassigned
**Created:** 2026-02-24

---

## User Story

As a developer using worktree-helpers,
I want `wt --check` to show update status,
So that I can check for updates without typing the longer `wt --update --check` form.

---

## Description

### Background

`wt --check` is documented in `_cmd_help` as a flag for checking updates without installing. However, running `wt --check` alone shows the main help screen instead of checking for updates. Only `wt --update --check` works correctly.

The root cause is in the flag parser inside `wt()` in `wt.sh`. When `--check` is parsed, it sets `check_only=1` but does NOT set `action`. After the parsing loop, the router evaluates `${action:-help}`, which defaults to `"help"` when `action` is empty — causing `_cmd_help` to be called instead of `_cmd_update`.

```sh
# Current (broken) flag parser:
--check)  check_only=1; shift ;;   # sets flag but NOT action

# After loop — action is empty, defaults to "help":
case "${action:-help}" in
  update) _cmd_update "$check_only" ;;
  help)   _cmd_help ;;              # <-- this is what executes
```

The fix is one line added after the `while` parsing loop and before the `if [ "$help" -eq 1 ]` guard:

```sh
# If --check given without explicit action, treat as --update --check
if [ "$check_only" -eq 1 ] && [ -z "$action" ]; then action="update"; fi
```

### Scope

**In scope:**
- Single-line fix in `wt()` in `wt.sh` (after the `while` loop, before `if [ "$help" -eq 1 ]`)
- BATS integration test: `wt --check` routes to `_update_check_only`, not `_cmd_help`
- Update `_cmd_help` `--check` description if it is misleading (currently says "with --update"; should also reflect that `--check` alone works)

**Out of scope:**
- Changes to `lib/update.sh` or `_cmd_update` logic
- Changes to `_help_update` (already documents `wt --update --check`)
- Any changes to completions

---

## User Flow

1. Developer runs `wt --check`
2. `wt.sh` parser sets `check_only=1` and (after fix) `action="update"`
3. Router matches `update` → calls `_cmd_update 1`
4. `_cmd_update` calls `_update_check_only`
5. Developer sees update status output (e.g., "wt is up to date (1.3.0)")

---

## Acceptance Criteria

1. [x] When `wt --check` is run, it calls `_update_check_only` (not `_cmd_help`) and exits with status 0.
2. [x] When `wt --check` is run, the output does NOT contain help screen text (e.g. the string "Usage:" from `_cmd_help`).
3. [x] When `wt --update --check` is run, it calls `_update_check_only` — existing behaviour is preserved (no regression).
4. [x] When `wt --check --update` is run (flags reversed), it also calls `_update_check_only` — argument order must not matter.
5. [x] When `wt --check --help` is run, it shows `_help_update` output (action="update", help=1 path), not the full help screen.
6. [x] The `--check` description in `_cmd_help` output does NOT include the qualifier "(with --update)" — it must reflect standalone usage.
7. [x] All existing BATS tests continue to pass after the fix (no regressions).

---

## Technical Notes

### Files to Change

- **`wt.sh`** — `wt()` function, after the `while` flag-parsing loop, before `if [ "$help" -eq 1 ]`:

```sh
# If --check given without explicit action, treat as --update --check
if [ "$check_only" -eq 1 ] && [ -z "$action" ]; then action="update"; fi
```

- **`test/cmd_update.bats`** — Add a new integration test using `load_wt_full`:

```sh
@test "wt --check alone routes to check-only mode" {
  load_wt_full

  _update_check_only() { echo "check_only_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check
  assert_success
  assert_output "check_only_called"
}
```

- **`lib/commands.sh`** — `_cmd_help`, `--check` line (currently `--check  Check for update without installing (with --update)`). Consider updating to reflect standalone usage:

```
  --check                Check for updates without installing (alias for --update --check)
```

### Router Context

The fix must be placed between the end of the `while` loop (line 83 in `wt.sh`) and the `if [ "$help" -eq 1 ]` guard (line 86). Exact location:

```sh
  done  # end of while loop

  # If --check given without explicit action, treat as --update --check
  if [ "$check_only" -eq 1 ] && [ -z "$action" ]; then action="update"; fi

  # Standalone --help with no command: show full help
  if [ "$help" -eq 1 ] && [ -z "$action" ]; then _cmd_help; return 0; fi
```

### Edge Cases

- `wt --check --help` — should show `_help_update` (action="update", help=1 → handled by `update)` case in router)
- `wt --update --check` — must continue to work (action is explicitly set to "update" before `--check` is processed)
- `wt --check --update` — argument order should not matter; both flags set their respective vars independently

---

## Dependencies

**Prerequisite Stories:** None

**Blocked Stories:** None

**External Dependencies:** None

---

## Definition of Done

- [x] One-line fix added to `wt()` in `wt.sh` — after the `while` loop, before the `if [ "$help" -eq 1 ]` guard: `if [ "$check_only" -eq 1 ] && [ -z "$action" ]; then action="update"; fi`
- [x] `_cmd_help` `--check` description updated in `lib/commands.sh` to remove "(with --update)" qualifier — must read "Check for updates without installing (alias for --update --check)" or equivalent without the "(with --update)" constraint
- [x] BATS test added to `test/cmd_update.bats`: `wt --check` alone routes to `_update_check_only`, exits 0
- [x] BATS test added to `test/STORY-050.bats` covering all 7 ACs (happy paths, edge cases, no-regression)
- [x] `npm test` passes with zero failures
- [x] No new shellcheck warnings introduced in modified files
- [x] All 7 Acceptance Criteria above are checked off

---

## Story Points Breakdown

- **Fix:** 0.5 points (single line in `wt.sh`)
- **Test:** 0.5 points (one BATS test + possible help text tweak)
- **Total:** 1 point

**Rationale:** Trivial one-line root cause fix. The test pattern already exists in `cmd_update.bats` — the new test follows the same `load_wt_full` + mock pattern as `wt --update --check routes to check-only mode`.

---

## Progress Tracking

**Status History:**
- 2026-02-24: Created by Scrum Master
- 2026-02-27: Implementation started
- 2026-02-27: Completed — all tests pass, shellcheck clean

**Actual Effort:** 1 point (matched estimate)

**Files Changed:**
- `wt.sh` — fix: added one-line flag normalization after the `while` parsing loop: `if [ "$check_only" -eq 1 ] && [ -z "$action" ]; then action="update"; fi`
- `lib/commands.sh` — fix: updated `--check` description in `_cmd_help` from "(with --update)" to "(alias for --update --check)"

**Tests:**
- `test/STORY-050.bats` — already existed with 11 tests covering all 7 ACs + edge cases; all pass after fix
- `test/cmd_update.bats` — already contained `wt --check alone routes to check-only mode` test; passes after fix
- Total: 53 tests in targeted run, zero failures
- `npm test` (full suite): all tests pass

**Decisions:**
- The test files (STORY-050.bats and cmd_update.bats) already had the required tests written — no new test code needed
- The fix is exactly the one-line change specified in Technical Notes
- shellcheck -x wt.sh lib/*.sh produces zero warnings

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## Pattern Guidelines

### Guard Clauses
Validate at the top of every function, return early on failure.
Never nest happy-path logic inside `if` blocks.

The fix in this story is itself a guard clause pattern: after the `while` parsing loop, check whether `check_only` was set without an `action` and assign the implied action before any other routing logic runs.

### Single Responsibility
Each function does exactly one thing.

The `wt()` router in `wt.sh` only parses flags and dispatches; it must not contain update logic itself. The one-line fix belongs here only because it is flag-dispatch normalization, not business logic.

### Utility Reuse (DRY)
Before writing new logic, check these existing utilities:
- `lib/utils.sh`:    `_err`, `_info`, `_debug`, `_require`, `_repo_root`, `_branch_exists`, `_read_input`, `_current_branch`
- `lib/worktree.sh`: `_wt_create`, `_wt_open`, `_wt_resolve`, `_run_hook`, `_wt_branch`
- `lib/config.sh`:   `_config_load` (sets all `GWT_*` globals)

For this story: the update path is entirely handled by `_cmd_update "$check_only"` in `lib/update.sh`. No new utility functions are needed.

### Output Streams
Errors and user prompts go to stderr. Data/output goes to stdout.

`_cmd_help` writes to stdout; the check for accidental help output in the tests uses `refute_output --partial "wt - Git Worktree Helpers"` on stdout to confirm the wrong function was not called.

### Flag Normalization Pattern
When a flag implies an action (i.e., `--check` implies `--update`), normalize it immediately after the `while` parsing loop ends and before any guard or dispatch logic:

```sh
# If --check given without explicit action, treat as --update --check
if [ "$check_only" -eq 1 ] && [ -z "$action" ]; then action="update"; fi
```

This keeps the `case "${action:-help}"` dispatch clean and avoids conditional duplication.

### Help Description Update
When updating `_cmd_help` in `lib/commands.sh`, the `--check` line in the Flags section (currently line 811) must be changed from:

```
  --check                   Check for update without installing (with --update)
```

to:

```
  --check                   Check for updates without installing (alias for --update --check)
```

The phrase "(with --update)" incorrectly implies `--check` only works when combined with `--update`. After the fix, `--check` works standalone.

### Test Location Convention
- Router integration tests (tests that call `wt <flags>`) belong in the test file for the command they exercise: `test/cmd_update.bats` for `wt --check`.
- Story-level AC coverage tests belong in `test/STORY-050.bats`.
- Both files must have a test for the `wt --check` standalone routing case.

---

## QA Review

### Files Reviewed
| File | Status | Notes |
|------|--------|-------|
| `wt.sh` | Pass | One-line fix placed correctly after `while` loop, before `if [ "$help" -eq 1 ]` guard |
| `lib/commands.sh` | Pass | `--check` description updated from "(with --update)" to "(alias for --update --check)" |
| `test/cmd_update.bats` | Pass | New test "wt --check alone routes to check-only mode" appended correctly |
| `test/STORY-050.bats` | Pass | 11 tests covering all 7 ACs plus 3 edge cases |

### Issues Found
None

### AC Verification
- [x] AC 1 — verified: `wt.sh` line 86 sets `action="update"` when `check_only=1` and `action` is empty; test: `STORY-050.bats` "AC1: wt --check alone calls _update_check_only and exits 0"
- [x] AC 2 — verified: output does not contain "wt - Git Worktree Helpers" or "Usage: wt [flags]"; test: `STORY-050.bats` "AC2: wt --check alone does not print help screen text"
- [x] AC 3 — verified: `wt --update --check` still routes to `_update_check_only`; test: `STORY-050.bats` "AC3: wt --update --check still routes to _update_check_only (no regression)"
- [x] AC 4 — verified: flags in either order work because each flag sets its own variable independently; test: `STORY-050.bats` "AC4: wt --check --update (flags reversed) routes to _update_check_only"
- [x] AC 5 — verified: `wt --check --help` sets `action="update"` via the normalization line, then `help=1`, so router shows `_help_update`; test: `STORY-050.bats` "AC5: wt --check --help shows _help_update output (wt --update section)"
- [x] AC 6 — verified: `lib/commands.sh` line 811 no longer contains "(with --update)"; now reads "(alias for --update --check)"; tests: `STORY-050.bats` "AC6: _cmd_help --check description does not contain '(with --update)'" and "AC6: _cmd_help --check description reflects standalone usage"
- [x] AC 7 — verified: all 451 tests in full suite pass; test: `npm test` (451 total, 0 failures)

### Pattern Guidelines Compliance
| Pattern | Status | Issues |
|---------|--------|--------|
| Guard Clauses | Pass | Fix placed as guard clause immediately after `while` loop, before any routing logic |
| Single Responsibility | Pass | One-line normalization in `wt()` router only; no update logic added to `wt.sh` |
| Utility Reuse (DRY) | Pass | No new utility functions created; dispatches through existing `_cmd_update "$check_only"` |
| Output Streams | Pass | No stdout/stderr changes in the fix; tests use `refute_output --partial` on stdout correctly |
| Flag Normalization Pattern | Pass | Fix matches the exact pattern specified: `if [ "$check_only" -eq 1 ] && [ -z "$action" ]; then action="update"; fi` |
| Help Description Update | Pass | `lib/commands.sh` line 811 updated exactly as specified in pattern guidelines |
| Test Location Convention | Pass | Integration test in `test/cmd_update.bats`, AC coverage in `test/STORY-050.bats`; both have `wt --check` standalone test |

### Test Results
- Total: 451 / Passed: 451 / Failed: 0
- STORY-050.bats: 11 / Passed: 11 / Failed: 0
- cmd_update.bats: 42 / Passed: 42 / Failed: 0

### Shellcheck
- Clean: yes
