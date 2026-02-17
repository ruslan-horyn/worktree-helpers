# STORY-011: Show dirty/clean status in `wt -l`

**Epic:** UX Polish
**Priority:** Should Have
**Story Points:** 3
**Status:** Complete
**Assigned To:** Developer
**Created:** 2026-02-16
**Sprint:** 5

---

## User Story

As a developer
I want to see which worktrees have uncommitted changes when I list them
So that I know which worktrees need attention before cleanup

---

## Description

### Background

The `wt -l` command currently displays worktrees with their branch name, path, and locked/active status. However, it provides no visibility into the working state of each worktree. A developer managing multiple worktrees needs to know at a glance which ones have uncommitted changes (dirty) versus which are clean. Without this, developers must manually `cd` into each worktree and run `git status` to determine if there is pending work, making cleanup decisions (e.g., before `wt -c` or `wt -r`) error-prone.

The current `_cmd_list` output format (in `lib/commands.sh:360-428`) parses `git worktree list --porcelain` and displays:

- Worktree path (50-char column)
- Branch name (with yellow coloring and "(main)" annotation for main worktree)
- Lock/active indicator (`[locked]` in red or `[active]` in green)

This story adds a dirty/clean status indicator to each line, providing at-a-glance visibility into which worktrees have pending changes.

### Scope

**In scope:**

- Add a dirty/clean indicator to each worktree line in `wt -l` output
- Detect dirty state via `git -C <path> status --porcelain` (staged changes, unstaged changes, untracked files)
- Colored indicators: `[dirty]` in red/yellow, `[clean]` in green/dim
- Graceful handling of inaccessible worktree paths (pruned, deleted, permission errors)
- Graceful handling of bare/detached HEAD worktrees
- BATS tests for the new functionality
- Performance consideration for repositories with many worktrees

**Out of scope:**

- Detailed file-level change listing (just dirty/clean indicator)
- Stash count or ahead/behind tracking (future enhancement, potentially STORY-016 metadata)
- Parallel execution of git status checks (POSIX shell limitation; sequential is acceptable for typical counts)
- Filtering or sorting by dirty/clean status (could be a future flag)
- Changes to `wt -c` behavior based on dirty status (separate story)

### User Flow

1. Developer runs `wt -l`
2. For each worktree, `wt` runs `git -C <path> status --porcelain` to check for changes
3. Output displays each worktree with path, branch, lock status, and dirty/clean indicator
4. Developer sees at a glance which worktrees have pending work
5. Developer can decide which worktrees to clean up, switch to, or continue working in

---

## Acceptance Criteria

- [ ] `wt -l` shows a dirty/clean indicator per worktree
- [ ] Dirty is detected when there are staged changes, unstaged changes, OR untracked files (any non-empty output from `git -C <path> status --porcelain`)
- [ ] Clean is displayed when the working tree matches HEAD (empty `git status --porcelain` output)
- [ ] Visual indicator uses colored labels: `[dirty]` and `[clean]` with appropriate colors
- [ ] Existing output columns are preserved (path, branch name, locked/active status)
- [ ] Main worktree also shows dirty/clean status
- [ ] Handles inaccessible worktree paths gracefully (e.g., `[?]` or skip indicator for pruned/missing paths)
- [ ] Handles detached HEAD worktrees correctly
- [ ] Performance is acceptable with 10+ worktrees (completes within a few seconds)
- [ ] All existing `_cmd_list` BATS tests continue to pass
- [ ] New BATS tests cover: clean worktree, dirty worktree (unstaged), dirty worktree (staged), dirty worktree (untracked files), inaccessible worktree path

---

## Technical Notes

### Components

- **`lib/commands.sh`** -- modify `_cmd_list` function (lines 360-428) to add dirty/clean detection and display
- **`lib/utils.sh`** -- (optional) add `_wt_is_dirty` helper function if reusable across commands
- **`test/cmd_list.bats`** -- add new BATS tests for dirty/clean indicator

### Implementation Approach

**1. Add dirty/clean detection function in `lib/utils.sh`:**

```sh
# Check if a worktree has uncommitted changes
# Usage: _wt_is_dirty <worktree_path>
# Returns: 0 if dirty, 1 if clean, 2 if inaccessible
_wt_is_dirty() {
  local wt_path="$1"
  [ ! -d "$wt_path" ] && return 2
  local status_output
  status_output=$(git -C "$wt_path" status --porcelain 2>/dev/null) || return 2
  [ -n "$status_output" ] && return 0
  return 1
}
```

**2. Modify `_cmd_list` in `lib/commands.sh`:**

In the empty-line record-processing block (around line 391-416), after computing `lock_indicator`, add:

```sh
# Format dirty/clean indicator
local dirty_indicator=""
if _wt_is_dirty "$worktree"; then
  dirty_indicator="${C_RED}[dirty]${C_RESET}"
elif [ $? -eq 2 ]; then
  dirty_indicator="${C_DIM}[?]${C_RESET}"
else
  dirty_indicator="${C_DIM}[clean]${C_RESET}"
fi
```

Note: The return code check above has a subtlety -- `_wt_is_dirty` returns 0 (dirty), 1 (clean), or 2 (inaccessible). The `if` consumes the 0 case, the `elif [ $? -eq 2 ]` must be checked carefully since `$?` after a failed `if` test holds the function's actual return code. A cleaner approach:

```sh
local dirty_indicator=""
_wt_is_dirty "$worktree"
case $? in
  0) dirty_indicator="${C_RED}[dirty]${C_RESET}" ;;
  1) dirty_indicator="${C_DIM}[clean]${C_RESET}" ;;
  *) dirty_indicator="${C_DIM}[?]${C_RESET}" ;;
esac
```

**3. Update the printf format line:**

Current:

```sh
printf "%-50s %s %s\n" "$worktree" "$branch_display" "$lock_indicator"
```

Updated:

```sh
printf "%-50s %s %s %s\n" "$worktree" "$branch_display" "$lock_indicator" "$dirty_indicator"
```

### Color Scheme

| State | Label | Color | Rationale |
|-------|-------|-------|-----------|
| Dirty | `[dirty]` | `C_RED` (red) or `C_YELLOW` (yellow) | Draws attention to worktrees needing action |
| Clean | `[clean]` | `C_DIM` (gray) | De-emphasized since clean is the "normal" state |
| Inaccessible | `[?]` | `C_DIM` (gray) | Non-intrusive for edge cases |

Using `C_YELLOW` for dirty (instead of `C_RED`) may be preferable since red is already used for `[locked]`, and dirty is informational rather than an error. This avoids visual confusion between locked and dirty states.

### Performance Considerations

- `git -C <path> status --porcelain` runs per worktree. For N worktrees, this is N sequential git status calls.
- Each `git status` call typically takes 10-50ms on an SSD for a typical project.
- For 10 worktrees: ~100-500ms total (acceptable).
- For 20+ worktrees: ~1-2 seconds (still acceptable, and users with 20+ worktrees already get a warning from `_wt_warn_count`).
- POSIX shell does not support background jobs with wait-for-all easily, so parallel execution is not practical without introducing complexity. Sequential execution is the pragmatic choice.
- Optimization: `git status --porcelain` is already the fastest git status mode (no formatting overhead).

### Edge Cases

- **Pruned worktree** (path deleted but git still references it): `[ ! -d "$wt_path" ]` returns early with code 2, shown as `[?]`
- **Permission denied on worktree path**: `git -C` fails, returns code 2, shown as `[?]`
- **Detached HEAD worktree**: `git status --porcelain` works identically on detached HEAD; no special handling needed
- **Worktree with only untracked files**: `--porcelain` includes `??` lines for untracked files; these count as dirty
- **Worktree in middle of merge/rebase**: `git status --porcelain` still works and reports uncommitted changes; shown as dirty
- **Main worktree (bare repo root)**: Treated the same as any other worktree; gets dirty/clean indicator
- **Empty repository (no commits)**: `git status --porcelain` still works; shows untracked files as dirty
- **Submodule changes**: `git status --porcelain` includes submodule changes by default; this is correct behavior

### Security Considerations

- No new inputs or user-controlled data flows
- `git -C` is scoped to the worktree path already known from `git worktree list`
- No shell injection risk since paths come from git's own porcelain output

---

## Dependencies

**Prerequisite Stories:**

- None (standalone enhancement)

**Blocked Stories:**

- None directly, but STORY-016 (worktree metadata) will also modify `_cmd_list` output -- coordinate to avoid merge conflicts

**Related Stories:**

- STORY-003 (Add wt-list command) -- original implementation of `_cmd_list`
- STORY-016 (Add worktree metadata tracking) -- also adds columns to `wt -l` output (notes, creation dates)

**External Dependencies:**

- None (uses only `git status --porcelain` which is available in all supported git versions)

---

## Definition of Done

- [ ] `_wt_is_dirty` helper function added to `lib/utils.sh` (or inline in `_cmd_list`)
- [ ] `_cmd_list` in `lib/commands.sh` displays dirty/clean indicator per worktree
- [ ] Color scheme applied: dirty uses attention color, clean uses dim/subdued color
- [ ] Inaccessible worktrees display `[?]` instead of crashing
- [ ] All existing BATS tests in `test/cmd_list.bats` pass (3 existing tests)
- [ ] New BATS tests added for dirty/clean scenarios:
  - [ ] Clean worktree shows `[clean]`
  - [ ] Dirty worktree (unstaged changes) shows `[dirty]`
  - [ ] Dirty worktree (untracked files) shows `[dirty]`
  - [ ] Main worktree shows dirty/clean indicator
- [ ] Shellcheck passes on modified files (`lib/commands.sh`, `lib/utils.sh`)
- [ ] POSIX-compatible (no bash/zsh-specific features)
- [ ] Works on both macOS and Linux
- [ ] Help text in `_cmd_help` unchanged (no new flags added)
- [ ] Manual testing confirms output is readable and well-aligned
- [ ] CI pipeline green

---

## Story Points Breakdown

- **`_wt_is_dirty` helper function:** 0.5 points (small utility, well-defined behavior with 3 return codes)
- **`_cmd_list` modification:** 1 point (integrate dirty check into existing parsing loop, update printf format)
- **BATS tests:** 1 point (4-5 new test cases covering clean, dirty variants, and edge cases)
- **Manual testing and polish:** 0.5 points (verify color contrast, column alignment, performance with multiple worktrees)
- **Total:** 3 points

**Rationale:** The implementation is straightforward -- a single `git status --porcelain` call per worktree integrated into the existing `_cmd_list` parsing loop. The main effort is in test coverage for the various dirty states and edge cases. No new flags, no new dependencies, no architectural changes.

---

## Additional Notes

- The dirty/clean indicator positions after the lock/active indicator. The output format becomes:

  ```
  /path/to/worktree                                  branch-name [active] [clean]
  /path/to/worktree2                                 feature-xyz [active] [dirty]
  /path/to/worktree3                                 hotfix-123  [locked] [clean]
  ```

- Consider whether `[dirty]` should use `C_YELLOW` (yellow) instead of `C_RED` (red) to differentiate from `[locked]`. Yellow = "attention needed", red = "restricted/locked". This is a minor UX decision to finalize during implementation.
- If STORY-016 (metadata) is implemented later, the output will gain additional columns. The dirty/clean indicator should be placed at the end of the line to accommodate future additions gracefully.
- The `_wt_is_dirty` helper function could also be useful for a future `wt -c --clean-only` filter that only clears worktrees with no uncommitted changes.

---

## Progress Tracking

**Status History:**

- 2026-02-16: Created
- 2026-02-17: Implementation started
- 2026-02-17: Implementation completed, all tests passing

**Actual Effort:** 3 points (matched estimate)

**Files Changed:**

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/utils.sh` | Modified | Added `_wt_is_dirty` helper function (returns 0=dirty, 1=clean, 2=inaccessible) |
| `lib/commands.sh` | Modified | Integrated dirty/clean indicator into `_cmd_list` output using `case $?` pattern |
| `test/cmd_list.bats` | Modified | Added 6 new BATS tests for dirty/clean scenarios |
| `docs/stories/STORY-011.md` | Modified | Updated progress tracking |

**Tests Added:**

| Test | Description |
|------|-------------|
| `_cmd_list shows [clean] for worktree with no changes` | Verifies clean worktrees display `[clean]` |
| `_cmd_list shows [dirty] for worktree with unstaged changes` | Verifies modified files trigger `[dirty]` |
| `_cmd_list shows [dirty] for worktree with untracked files` | Verifies untracked files trigger `[dirty]` |
| `_cmd_list shows dirty/clean indicator for main worktree` | Verifies main worktree also gets the indicator |
| `_cmd_list shows [dirty] for worktree with staged changes` | Verifies staged-only changes trigger `[dirty]` |
| `_cmd_list shows [?] for inaccessible worktree path` | Verifies deleted/missing worktree paths display `[?]` |

**Test Results:** 186/186 tests passing (including 3 pre-existing + 6 new cmd_list tests)

**Shellcheck:** Clean (no warnings on `lib/utils.sh` or `lib/commands.sh`)

**Decisions Made:**

- Used `C_YELLOW` for `[dirty]` (not `C_RED`) to differentiate from `[locked]` which uses `C_RED`. Yellow = "attention needed", red = "restricted/locked".
- Used `C_DIM` for `[clean]` to de-emphasize the normal/expected state.
- Used `C_DIM` for `[?]` for inaccessible/pruned worktrees (non-intrusive edge case).
- Placed dirty/clean indicator after the lock/active indicator at end of line.
- Used `case $?` pattern (not `if/elif`) for cleaner 3-way return code handling.
- Added `_wt_is_dirty` as a standalone function in `lib/utils.sh` for potential reuse in future stories (e.g., `wt -c --clean-only`).

---

## QA Review

**Reviewer:** QA Engineer (Claude)
**Date:** 2026-02-17

### Files Reviewed

| File | Status | Notes |
|------|--------|-------|
| `lib/utils.sh` | Pass | `_wt_is_dirty` correctly implements 3-return-code pattern. Comment block for `_wt_warn_count` is now correctly placed directly above its function (lines 142-143). |
| `lib/commands.sh` | Pass | `case $?` pattern used correctly for 3-way return code handling. `printf` format updated with 4th `%s` for dirty indicator. Color scheme uses `C_YELLOW` for dirty (differentiated from `C_RED` locked). |
| `test/cmd_list.bats` | Pass | 6 new tests cover all AC scenarios. Clean, unstaged, untracked, staged, main worktree, and inaccessible path. |

### Issues Found

| # | Severity | File | Description | Status |
|---|----------|------|-------------|--------|
| 1 | minor | `lib/utils.sh` | Lines 130-131: The comment block `# Warn if worktree count exceeds threshold` / `# Usage: _wt_warn_count (call after worktree creation)` was orphaned from `_wt_warn_count` because `_wt_is_dirty` was inserted between the comment and its function. | Fixed / Verified |
| 2 | minor | `docs/stories/STORY-011.md` | Progress Tracking section previously said "7 new BATS tests" but the actual count is 6 new tests. | Fixed / Verified |

### QA Cycle 2

**Date:** 2026-02-17

Both issues from QA cycle 1 have been verified as fixed:
- Issue 1: `_wt_warn_count` comment block (lines 142-143) now sits directly above its function (line 144), with a blank line (141) separating it from `_wt_is_dirty`.
- Issue 2: Progress Tracking correctly states 6 new tests and "3 pre-existing + 6 new cmd_list tests".

No new issues found. All 186 tests pass. Shellcheck clean. QA cycle 2 passed.

### AC Verification

- [x] AC 1 -- `wt -l` shows dirty/clean indicator per worktree: verified in `lib/commands.sh:407-413` (`case $?` block), tests: `_cmd_list shows [clean]...`, `_cmd_list shows [dirty]...`
- [x] AC 2 -- Dirty detected for staged, unstaged, OR untracked: verified in `lib/utils.sh:135-142` (`_wt_is_dirty` uses `git status --porcelain`), tests: `_cmd_list shows [dirty] for worktree with unstaged changes`, `_cmd_list shows [dirty] for worktree with untracked files`, `_cmd_list shows [dirty] for worktree with staged changes`
- [x] AC 3 -- Clean displayed when working tree matches HEAD: verified in `lib/utils.sh:141` (empty `status_output` returns 1), test: `_cmd_list shows [clean] for worktree with no changes`
- [x] AC 4 -- Visual indicator uses colored labels `[dirty]` and `[clean]`: verified in `lib/commands.sh:410-411` (`C_YELLOW` for dirty, `C_DIM` for clean)
- [x] AC 5 -- Existing output columns preserved: verified in `lib/commands.sh:422` (`printf` format adds 4th field, preserves path/branch/lock columns)
- [x] AC 6 -- Main worktree also shows dirty/clean status: verified in `lib/commands.sh:392-413` (no skip for main worktree in dirty check), test: `_cmd_list shows dirty/clean indicator for main worktree`
- [x] AC 7 -- Handles inaccessible worktree paths gracefully with `[?]`: verified in `lib/utils.sh:137` (`[ ! -d ]` returns 2) and `lib/commands.sh:412` (`*` case shows `[?]`), test: `_cmd_list shows [?] for inaccessible worktree path`
- [x] AC 8 -- Handles detached HEAD worktrees: verified by code analysis -- `git status --porcelain` works identically on detached HEAD, no special handling needed. `_cmd_list` already parses `detached` line (commands.sh:383).
- [x] AC 9 -- Performance acceptable with 10+ worktrees: verified by design -- sequential `git status --porcelain` calls (~10-50ms each), acceptable for typical counts.
- [x] AC 10 -- All existing `_cmd_list` BATS tests continue to pass: verified -- tests 30-32 (3 pre-existing) all pass.
- [x] AC 11 -- New BATS tests cover required scenarios: clean worktree (test 33), dirty unstaged (test 34), dirty untracked (test 35), dirty staged (test 37), inaccessible path (test 38). All covered.

### Test Results

- Total: 186 / Passed: 186 / Failed: 0

### Shellcheck

- Clean: yes (standard mode with `-x` flag; `local` warnings in `--shell=sh` mode are pre-existing across entire codebase, not introduced by this story)

---

## Manual Testing

**Tester:** QA Engineer (Claude)
**Date:** 2026-02-17
**Environment:** macOS Darwin 24.6.0, zsh, git worktree-helpers v1.2.1

### Test Scenarios

| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | Run `wt -l` -- dirty/clean indicators appear for all worktrees | Each worktree line shows `[dirty]`, `[clean]`, or `[?]` | All 9 worktrees displayed with correct indicators (`[clean]` for clean worktrees, `[dirty]` for worktrees with uncommitted changes) | Pass |
| 2 | Create untracked file in clean worktree, run `wt -l` | Worktree shows `[dirty]` | Worktree flipped from `[clean]` to `[dirty]` after creating untracked file | Pass |
| 3 | Stage a change in clean worktree, run `wt -l` | Worktree shows `[dirty]` | Worktree showed `[dirty]` with staged-only change | Pass |
| 4 | Verify clean worktrees show `[clean]` | Worktrees with no changes show `[clean]` | Multiple clean worktrees (story-025, story-026, story-027) showed `[clean]` | Pass |
| 5 | Main worktree shows dirty/clean indicator | Main worktree line includes `[clean]` or `[dirty]` | Main worktree displayed `main (main) [active] [clean]` | Pass |
| 6 | Remove worktree directory (simulate inaccessible path), run `wt -l` | Worktree shows `[?]` | Inaccessible worktree displayed `[active] [?]` | Pass |
| 7 | Create detached HEAD worktree, run `wt -l` | Worktree shows `(detached)` with dirty/clean indicator | Detached HEAD worktree displayed `(detached) [active] [clean]` | Pass |
| 8 | Remove untracked file from dirty worktree, run `wt -l` | Worktree returns to `[clean]` | Worktree correctly returned to `[clean]` after cleanup | Pass |
| 9 | Color verification: `[dirty]` uses C_YELLOW (ANSI 33) | ANSI escape `\033[33m` wraps `[dirty]` | Confirmed via forced-color output: `^[[33m[dirty]^[[0m` | Pass |
| 10 | Color verification: `[clean]` uses C_DIM (ANSI 90) | ANSI escape `\033[90m` wraps `[clean]` | Confirmed via forced-color output: `^[[90m[clean]^[[0m` | Pass |
| 11 | Color verification: `[?]` uses C_DIM (ANSI 90) | ANSI escape `\033[90m` wraps `[?]` | Confirmed by code inspection (`lib/commands.sh:412`) | Pass |
| 12 | Output alignment is readable | Columns are consistently formatted | Path column uses 50-char width; indicators consistently placed at end of line | Pass |
| 13 | Existing columns preserved (path, branch, lock/active) | Pre-existing columns unchanged | All existing columns present and unchanged | Pass |
| 14 | All 186 BATS tests pass (`npm test`) | 186/186 pass, 0 fail | 186/186 pass, 0 fail | Pass |

### Issues Found

None

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
