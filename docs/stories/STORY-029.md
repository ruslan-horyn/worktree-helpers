# STORY-029: Protect main/dev branches from `wt -c` deletion

**Epic:** Core Reliability
**Priority:** Must Have
**Story Points:** 3
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-19
**Sprint:** 6

---

## User Story

As a developer using `wt -c`
I want the clear command to never delete protected branches (main, dev)
So that I don't accidentally lose my primary development branch

---

## Description

### Background

`wt -c` (clear) removed a worktree whose branch was `release-next` — the main dev branch
for the project. The clear command should refuse to delete any worktree whose branch
matches a protected ref (`mainRef` or `devRef` from config, plus common names like `main`,
`master`, `dev`, `develop`).

This is a real-world data-loss scenario: a developer ran `wt -c 30` to clean up old
worktrees, and the command also deleted the worktree for their primary dev branch because
it happened to be older than 30 days. The branch was deleted along with the worktree.

### Scope

**In scope:**

- `_is_protected_branch` helper that checks a branch name against a protected list
- Protection applied inside `_cmd_clear` before any worktree deletion
- Warning message printed for each skipped protected worktree
- Protection applies to the age-based, `--merged`, and `--pattern` clear variants
- `--dry-run` output marks protected worktrees as skipped with a reason

**Out of scope:**

- Protecting worktrees in `wt -r` (remove) — that command is intentional single-target removal
- User-configurable protected branch list beyond `mainRef`/`devRef`
- Protecting detached HEAD worktrees

### User Flow

1. Developer runs `wt -c 30` or `wt -c --merged` to clean up old worktrees
2. For each candidate worktree, the command checks if the branch is protected
3. Protected worktrees print a warning and are skipped: `Skipping <branch>: protected branch`
4. Non-protected worktrees proceed through the existing deletion logic unchanged
5. With `--dry-run`, protected worktrees appear in output as `[protected — skipped]`

---

## Acceptance Criteria

- [ ] `wt -c` never deletes a worktree whose branch matches `GWT_MAIN_REF` or `GWT_DEV_REF`
- [ ] `wt -c` never deletes a worktree whose branch is any of: `main`, `master`, `dev`, `develop`
- [ ] Skipped protected worktrees print a warning: `Skipping <branch>: protected branch`
- [ ] `wt -c --dry-run` correctly marks protected worktrees as `[protected — skipped]`
- [ ] Protection applies to all clear variants (`--merged`, `--pattern`, age-based)
- [ ] Existing BATS tests pass with no regressions
- [ ] `shellcheck` passes

---

## Technical Notes

### Components

- **`lib/commands.sh`:** `_cmd_clear` — the main location for the protection check
- **`lib/utils.sh`** (or top of `lib/commands.sh`): `_is_protected_branch` helper

### Implementation

**New helper function:**

```sh
# Returns 0 if the branch is protected, 1 otherwise
_is_protected_branch() {
  local branch="$1"
  [ -z "$branch" ] && return 1
  # Strip remote prefix for comparison (e.g. origin/main -> main)
  local local_main="${GWT_MAIN_REF#*/}"
  local local_dev="${GWT_DEV_REF#*/}"
  case "$branch" in
    main|master|dev|develop) return 0 ;;
    "$local_main"|"$GWT_MAIN_REF") return 0 ;;
    "$local_dev"|"$GWT_DEV_REF") return 0 ;;
  esac
  return 1
}
```

**Integration point in `_cmd_clear`:**

The protection check should be inserted in the worktree collection loop (steps 1–5)
immediately after the locked status check (step 6), or as a new step between the
existing filters and the locked check. Specifically: after step 5 (merged filter)
and before or alongside step 6 (locked check).

The item should be added to a `protected_skipped` accumulator (similar to `locked_skipped`)
so warnings are printed in a grouped block before the deletion phase — consistent with
how locked worktrees are currently reported.

**Branch extraction:** Branch name is already available as `$branch` within the
`_cmd_clear` loop (parsed from `git worktree list --porcelain` output via the
`branch refs/heads/<name>` lines). No additional git subprocess is needed.

**`--dry-run` integration:**

In the dry-run output block, add a section for protected worktrees:

```
[dry-run] Protected worktrees (skipped):
  /path/to/worktree (main) [protected]
```

### Edge Cases

- `GWT_MAIN_REF` is typically `origin/main` — strip the remote prefix when comparing
  against local branch names reported by `git worktree list --porcelain`
- `GWT_DEV_REF` may be `origin/release-next` — same stripping required
- Detached HEAD worktrees (`branch = "(detached)"`) are never protected
- If `GWT_MAIN_REF` / `GWT_DEV_REF` are empty (config not loaded), fall back to
  hardcoded names only

### POSIX Compatibility

- Use `case` statement for pattern matching, not `[[ =~ ]]`
- Helper must be defined before `_cmd_clear` is called (place in `lib/utils.sh` or
  at top of `lib/commands.sh`)

---

## Dependencies

- None

---

## Definition of Done

- [ ] `_is_protected_branch` helper implemented and POSIX-compatible
- [ ] `_cmd_clear` checks protection before adding each worktree to the deletion list
- [ ] Warning message printed for skipped protected worktrees (grouped, similar to locked)
- [ ] `--dry-run` output shows protected worktrees as skipped with reason
- [ ] BATS tests in `test/cmd_clear.bats` cover:
  - [ ] Protected branch (`main`) is skipped by age-based clear
  - [ ] Protected branch (`GWT_MAIN_REF` local equivalent) is skipped
  - [ ] Protected branch skipped by `--merged` clear
  - [ ] Protected branch skipped by `--pattern` clear
  - [ ] Non-protected branch is still removed normally
  - [ ] `--dry-run` shows `[protected — skipped]` for protected branches
- [ ] `shellcheck` passes on all modified files
- [ ] No regressions in existing `test/cmd_clear.bats` tests

---

## Story Points Breakdown

- **Helper implementation (`_is_protected_branch`):** 0.5 points
- **`_cmd_clear` integration + warning output:** 1 point
- **`--dry-run` integration:** 0.5 points
- **BATS tests:** 1 point
- **Total:** 3 points

**Rationale:** Straightforward guard clause insertion with no new data structures.
The filtering loop and its patterns are already well-established. Most complexity
is in writing thorough BATS tests that cover all clear variants.

---

## Additional Notes

- The `_cmd_rename` function already has a precedent for protected branch checking
  (`[ "$old_branch" = "$main_local" ] && { _err "Cannot rename the main branch"; return 1; }`)
  — `_is_protected_branch` should consolidate this pattern for reuse
- Consider whether `_cmd_rename` should be updated to use `_is_protected_branch`
  (out of scope for this story but worth noting for a follow-up)

---

## Progress Tracking

**Status History:**

- 2026-02-19: Created by Ruslan Horyn (enhanced from sprint plan)

**Actual Effort:** TBD (will be filled during/after implementation)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
