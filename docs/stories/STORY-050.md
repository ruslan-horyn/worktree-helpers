# STORY-050: Fix `wt --check` showing help instead of update status

**Epic:** Bug Fixes
**Priority:** Must Have
**Story Points:** 1
**Status:** backlog
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

- [ ] `wt --check` outputs update status (same as `wt --update --check`)
- [ ] `wt --check` does NOT show the help screen
- [ ] `wt --update --check` continues to work as before (no regression)
- [ ] BATS test covers the `wt --check` routing: asserts `_update_check_only` is called
- [ ] `_cmd_help` `--check` description accurately reflects that `--check` alone is valid
- [ ] All existing tests pass (no regressions)

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

- [ ] Code implemented in `wt.sh` (one-line fix after while loop)
- [ ] BATS test added to `test/cmd_update.bats` covering `wt --check` standalone routing
- [ ] `_cmd_help` updated if `--check` description is ambiguous
- [ ] All tests pass: `npm test`
- [ ] No shellcheck warnings introduced
- [ ] Acceptance criteria validated (all checked)

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

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
