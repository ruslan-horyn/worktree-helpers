# STORY-029: Protect main/dev branches from `wt -c` deletion

**Epic:** Core Reliability
**Priority:** Must Have
**Story Points:** 3
**Status:** Completed
**Assigned To:** Developer
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
- 2026-02-20: Implementation started
- 2026-02-20: Implementation complete — all tests pass, shellcheck clean

**Actual Effort:** 3 points (matched estimate)

**Files Changed:**

- `lib/utils.sh` — added: `_is_protected_branch` helper function (POSIX-compatible, uses `case` statement)
- `lib/commands.sh` — modified: `_cmd_clear` — added `protected_skipped` accumulator, protection check (step 6) before locked check (step 7), grouped warning output, dry-run section for protected worktrees
- `test/cmd_clear.bats` — added: 7 new BATS tests covering all protection scenarios

**Tests Added:**

- `_cmd_clear age-based: skips worktree whose branch is 'main'`
- `_cmd_clear age-based: skips worktree matching GWT_DEV_REF local equivalent`
- `_cmd_clear --merged: skips protected branch`
- `_cmd_clear --pattern: skips protected branch even when it matches pattern`
- `_cmd_clear: non-protected branch is still removed normally`
- `_cmd_clear --dry-run: shows [protected — skipped] for protected branches`
- `_cmd_clear --dry-run: shows protected even when no other worktrees to delete`

**Test Results:**

- 271/271 tests pass (including all 34 cmd_clear tests)
- 0 regressions
- shellcheck: clean (with project .shellcheckrc — shell=bash)

**Decisions Made:**

- `_is_protected_branch` placed in `lib/utils.sh` (available to all commands, reusable)
- Protection check inserted as step 6, after merged filter (step 5), before locked check (step 7) — consistent with the ordering described in the story
- Warning format: `Skipping <branch>: protected branch` (one line per protected branch, to stderr)
- Dry-run for protected worktrees also shown when `to_delete_count=0` (only-protected scenario) — shows in the "No worktrees would be removed" block
- Remote prefix stripping: `local_main="${GWT_MAIN_REF#*/}"` handles `origin/main` → `main` and `origin/release-next` → `release-next`

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## QA Review

### Files Reviewed
| File | Status | Notes |
|------|--------|-------|
| `lib/utils.sh` | Pass | `_is_protected_branch` helper added at lines 148-165; POSIX-compatible `case` statement; handles empty branch, detached HEAD, remote prefix stripping, and GWT_MAIN_REF/GWT_DEV_REF comparisons |
| `lib/commands.sh` | Pass | `_cmd_clear` updated: `protected_skipped` accumulator declared at line 137; protection check (step 6) inserted at lines 223-229 after merged filter (step 5) and before locked check (step 7); grouped warning output at lines 250-261; dry-run sections at lines 281-290 (no-delete path) and lines 335-344 (normal dry-run path) |
| `test/cmd_clear.bats` | Pass | 7 new BATS tests added (tests #28-34) covering all protection scenarios; all pass without regression |

### Issues Found

None

### AC Verification
- [x] AC 1 — `wt -c` never deletes worktree whose branch matches `GWT_MAIN_REF` or `GWT_DEV_REF`: verified in `lib/utils.sh:161-162` (`"$local_main"|"$GWT_MAIN_REF"` and `"$local_dev"|"$GWT_DEV_REF"` case arms); test: `_cmd_clear age-based: skips worktree matching GWT_DEV_REF local equivalent` (test #29)
- [x] AC 2 — `wt -c` never deletes worktree whose branch is `main`, `master`, `dev`, or `develop`: verified in `lib/utils.sh:160` (`main|master|dev|develop` case arm); tests: `_cmd_clear age-based: skips worktree whose branch is 'main'` (#28), `_cmd_clear --merged: skips protected branch` (#30 — uses `develop`), `_cmd_clear --pattern: skips protected branch even when it matches pattern` (#31 — uses `dev`)
- [x] AC 3 — Skipped protected worktrees print `Skipping <branch>: protected branch`: verified at `lib/commands.sh:256` (`echo "${C_YELLOW}Skipping $br: protected branch${C_RESET}" >&2`); tested implicitly by `assert_output --partial "protected branch"` in tests #28-32
- [x] AC 4 — `wt -c --dry-run` correctly marks protected worktrees as `[protected — skipped]`: verified at `lib/commands.sh:287` and `lib/commands.sh:341` (both output `[protected — skipped]`); tests: `_cmd_clear --dry-run: shows [protected — skipped] for protected branches` (#33), `_cmd_clear --dry-run: shows protected even when no other worktrees to delete` (#34)
- [x] AC 5 — Protection applies to all clear variants (`--merged`, `--pattern`, age-based): verified — protection check (step 6 at `lib/commands.sh:223`) sits after all variant filters (steps 3-5) and before locked check; all three variants tested: age-based (#28, #29), `--merged` (#30), `--pattern` (#31)
- [x] AC 6 — Existing BATS tests pass with no regressions: 271/271 tests pass, 0 failures
- [x] AC 7 — `shellcheck` passes: clean output on `wt.sh` and `lib/*.sh`

### Test Results
- Total: 271 / Passed: 271 / Failed: 0

### Shellcheck
- Clean: yes

## Manual Testing

### Test Scenarios
| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | `_is_protected_branch` with `main` | Returns 0 (protected) | Returns 0; `main\|master\|dev\|develop` case arm in `lib/utils.sh:160` matches | Pass |
| 2 | `_is_protected_branch` with `master` | Returns 0 (protected) | Returns 0; same case arm | Pass |
| 3 | `_is_protected_branch` with `dev` | Returns 0 (protected) | Returns 0; same case arm | Pass |
| 4 | `_is_protected_branch` with `develop` | Returns 0 (protected) | Returns 0; same case arm | Pass |
| 5 | `_is_protected_branch` with `GWT_MAIN_REF=origin/main`, branch=`main` | Returns 0 — local_main strips `origin/` prefix | Returns 0; `local_main="${GWT_MAIN_REF#*/}"` = `main`, matches `"$local_main"` arm | Pass |
| 6 | `_is_protected_branch` with `GWT_DEV_REF=origin/release-next`, branch=`release-next` | Returns 0 — local_dev strips prefix | Returns 0; `local_dev="${GWT_DEV_REF#*/}"` = `release-next`, matches `"$local_dev"` arm | Pass |
| 7 | `_is_protected_branch` with empty branch (`""`) | Returns 1 (not protected) | Returns 1; early exit `[ -z "$branch" ] && return 1` | Pass |
| 8 | `_is_protected_branch` with `(detached)` | Returns 1 (not protected) | Returns 1; `[ "$branch" = "(detached)" ] && return 1` guard | Pass |
| 9 | `_is_protected_branch` with `feature-xyz` | Returns 1 (not protected) | Returns 1; no case arm matches, falls through to `return 1` | Pass |
| 10 | Age-based `wt -c 1 -f`: worktree on `master` branch is old | `master` skipped, warning printed, non-protected worktree removed | BATS test #28 (`_cmd_clear age-based: skips worktree whose branch is 'main'`): passes | Pass |
| 11 | Age-based `wt -c 1 -f`: worktree on `release-next` (local equiv of `GWT_DEV_REF=origin/release-next`) | `release-next` skipped with warning | BATS test #29: passes | Pass |
| 12 | `wt -c --merged -f`: `develop` branch is merged into main | `develop` skipped (protected), warning printed, worktree preserved | BATS test #30: passes | Pass |
| 13 | `wt -c --pattern "dev*" -f`: both `dev` (protected) and `dev-feature` (non-protected) match pattern | `dev` skipped, `dev-feature` removed | BATS test #31: passes | Pass |
| 14 | Non-protected branch `feature-xyz` with age-based clear | Worktree removed normally | BATS test #32: passes | Pass |
| 15 | `wt -c 1 --dry-run -f` with `master` (old, protected) and `old-feat` (old, non-protected) | `[protected — skipped]` in output for `master`; `old-feat` in would-be-removed list; nothing deleted | BATS test #33: passes | Pass |
| 16 | `wt -c 1 --dry-run -f` with only a protected `dev` branch (old) | `[protected — skipped]` shown; `[dry-run] No worktrees would be removed` shown | BATS test #34: passes | Pass |
| 17 | Warning message format for skipped protected worktree | `Skipping <branch>: protected branch` printed to stderr | `lib/commands.sh:256`: `echo "${C_YELLOW}Skipping $br: protected branch${C_RESET}" >&2`; verified by BATS tests #28–32 | Pass |
| 18 | Protection check ordering: step 6 after merged filter (step 5), before locked check (step 7) | Protection applies after all variant filters so it correctly refuses protection even if a protected branch happens to match `--merged` or `--pattern` | Code order verified in `lib/commands.sh:198–240`; BATS tests #30–31 confirm | Pass |
| 19 | Detached HEAD worktrees not protected | Worktree with `(detached)` branch is treated normally | Guard at `lib/utils.sh:155`; existing BATS test #13 (`_cmd_clear --merged skips detached HEAD worktrees`) covers this | Pass |
| 20 | Empty `GWT_MAIN_REF` / `GWT_DEV_REF` (config not loaded) | Falls back to hardcoded names only (`main`, `master`, `dev`, `develop`) | When `GWT_MAIN_REF=""`, `local_main=""` — case arm `"$local_main"` matches empty string which never equals a real branch; hardcoded arm still fires | Pass |
| 21 | Full test suite regression check | 271/271 pass, 0 failures | `npm test` output: `271..271` all `ok` | Pass |
| 22 | `shellcheck` on all modified files | No warnings or errors | `shellcheck wt.sh lib/*.sh` produces no output | Pass |

### Issues Found

None
