# STORY-039: Improve `wt -c` dry-run output readability

**Epic:** UX Polish
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** 7

---

## User Story

As a developer using `wt -c --dry-run`
I want cleaner, easier-to-scan output
So that I can quickly understand what will be removed and what will be skipped

---

## Description

### Background

During real-world testing of STORY-029 (branch protection), two readability issues were noticed in `wt -c` output:

1. **Redundant branch name in parentheses.** When the worktree directory name matches the branch name, the `(branch)` suffix is redundant noise. For example, `develop (develop) [protected — skipped]` — the parenthesised part adds nothing.

2. **Dry-run sections are visually merged.** There are no blank lines between the "would be removed" and "protected (skipped)" sections, making it hard to scan when both sections appear.

### Scope

**In scope:**
- Omit `(branch)` when `display_name == branch` (in all `_cmd_clear` display paths)
- Add a blank line between dry-run sections (`would be removed` / `protected (skipped)` / summary line)

**Out of scope:**
- Changing output in the non-dry-run confirmation prompt (that's STORY-034)
- Changing locked worktree display format

### User Flow

Before:
```
[dry-run] Worktrees that would be removed (older than 7 day(s)):
  CORE-667-fix-login (CORE-667-fix-login) - 2 days ago
  test-ai-mlm-assistant (NO_TASK/test-ai-mlm-assistant) - 11 days ago
[dry-run] Protected worktrees (skipped):
  develop (develop) [protected — skipped]
[dry-run] 2 worktree(s) would be removed
```

After:
```
[dry-run] Worktrees that would be removed (older than 7 day(s)):
  CORE-667-fix-login - 2 days ago
  test-ai-mlm-assistant (NO_TASK/test-ai-mlm-assistant) - 11 days ago

[dry-run] Protected worktrees (skipped):
  develop [protected — skipped]

[dry-run] 2 worktree(s) would be removed
```

---

## Acceptance Criteria

- [ ] When `basename(worktree_path) == branch`, the entry is displayed without the `(branch)` suffix
- [ ] When `basename(worktree_path) != branch` (e.g. `NO_TASK/feature`), the `(branch)` suffix is still shown
- [ ] Dry-run output has a blank line after the "would be removed" list (before next section or summary)
- [ ] Dry-run output has a blank line after the "protected (skipped)" list (before summary line)
- [ ] The same name-deduplication logic applies in the "protected (skipped)" section
- [ ] Non-dry-run confirmation output is unchanged
- [ ] All existing `cmd_clear` BATS tests continue to pass
- [ ] New tests cover: name-match suppression, name-mismatch retention, section spacing

---

## Technical Notes

### Components

- `lib/commands.sh` — `_cmd_clear` function: all display paths that emit worktree entries
- `lib/utils.sh` — optional new helper `_wt_format_clear_entry` to avoid duplicating the deduplication logic
- `test/cmd_clear.bats` — extend with new format assertions

### Key Display Paths in `_cmd_clear`

There are four places that build a worktree entry string (all in `lib/commands.sh`):

1. **Dry-run to-delete list** (line ~328–330):
   ```sh
   echo "  $(_wt_display_name "$wt_path") ($br) - $(_age_display "$ts")"
   echo "  $(_wt_display_name "$wt_path") ($br)"
   ```

2. **Dry-run protected list** (line ~341):
   ```sh
   echo "  $(_wt_display_name "$wt_path") ($br) [protected — skipped]"
   ```

3. **Dry-run protected list (empty-count path)** (line ~287):
   ```sh
   echo "  $(_wt_display_name "$wt_path") ($br) [protected — skipped]"
   ```

4. **Non-dry-run confirmation list** (line ~359–361) — out of scope, leave unchanged.

### Suggested Helper

```sh
# Returns formatted "name (branch)" or just "name" when they match.
# Usage: _wt_format_entry <worktree_path> <branch>
_wt_format_entry() {
  local display; display=$(_wt_display_name "$1")
  if [ "$display" = "$2" ]; then
    echo "$display"
  else
    echo "$display ($2)"
  fi
}
```

Place in `lib/utils.sh` alongside other display helpers.

### Blank-Line Insertion Points

In dry-run mode:
- After the `to_delete` loop → `echo ""`
- After the `protected_skipped` loop → `echo ""`
- Then the summary line: `[dry-run] N worktree(s) would be removed`

### Edge Cases

- Protected-only scenario (0 to-delete, some protected): the `echo ""` after the protected list should still appear before the summary.
- To-delete-only scenario (no protected): no extra blank line needed after protected section (section is absent).
- Both absent (0 to-delete, 0 protected): current `[dry-run] No worktrees would be removed` path — no change needed.

---

## Dependencies

**Prerequisite Stories:**
- STORY-029: Protect main/dev branches from `wt -c` deletion (provides the `protected_skipped` display path being improved)
- STORY-015: Add more granular clear options (provides `--dry-run` flag)

**Blocked Stories:**
- None

---

## Definition of Done

- [ ] Code implemented in `lib/commands.sh` (and optionally `lib/utils.sh`)
- [ ] Helper `_wt_format_entry` added to `lib/utils.sh` (or inline logic if simpler)
- [ ] BATS tests added to `test/cmd_clear.bats` covering:
  - [ ] Name-match → no parentheses in output
  - [ ] Name-mismatch → parentheses retained
  - [ ] Blank line between dry-run sections when both sections present
  - [ ] Blank line after protected section before summary
- [ ] All existing BATS tests pass (`bats test/`)
- [ ] shellcheck passes on modified files
- [ ] PR merged to main

---

## Story Points Breakdown

- **Logic change (`_cmd_clear` display paths):** 1 point
- **Tests (`cmd_clear.bats` additions):** 1 point
- **Total:** 2 points

**Rationale:** Purely cosmetic output change with no state or config impact. The main effort is writing thorough BATS assertions for the formatting.

---

## Additional Notes

This story was identified during manual testing of STORY-029. The notes were captured in `docs/stories/STORY-039-notes.md` (Polish language, original observations).

---

## Progress Tracking

**Status History:**
- 2026-02-21: Created by Ruslan Horyn
- 2026-02-22: Implementation started (in_progress)
- 2026-02-22: Implementation complete, all tests passing

**Actual Effort:** 2 points (matched estimate)

**Files Changed:**

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/utils.sh` | modified | Added `_wt_format_entry` helper function that returns `"name (branch)"` or just `"name"` when they match |
| `lib/commands.sh` | modified | Updated three dry-run display paths to use `_wt_format_entry`; added `echo ""` blank lines between dry-run sections |
| `test/cmd_clear.bats` | modified | Added 6 new tests covering name-match suppression, name-mismatch retention, and section spacing |

**Tests Added (6 new tests):**
1. `_cmd_clear --dry-run: name-match suppresses (branch) suffix in to-delete list`
2. `_cmd_clear --dry-run: name-mismatch retains (branch) suffix in to-delete list`
3. `_cmd_clear --dry-run: name-match suppresses (branch) suffix in protected list`
4. `_cmd_clear --dry-run: blank line after to-delete list before protected section`
5. `_cmd_clear --dry-run: blank line after protected section before summary`
6. `_cmd_clear --dry-run protected-only: blank line before protected section header`

**Test Results:** 323/323 passing (6 new + 317 existing)

**shellcheck:** Clean — no warnings on modified files

**Decisions Made:**
- Added `_wt_format_entry` to `lib/utils.sh` alongside `_wt_display_name` (as suggested in technical notes)
- The `echo ""` separator in the "protected-only" path (to_delete_count == 0) is placed before the protected section header (between "[dry-run] No worktrees would be removed" and "[dry-run] Protected worktrees (skipped):") because this is more reliably testable; BATS strips trailing blank lines from `$output`, making an end-of-output blank line unreliable to assert
- Non-dry-run confirmation output (lines 358-365 in commands.sh) was intentionally left unchanged per scope definition

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## QA Review

### Files Reviewed

| File | Status | Notes |
|------|--------|-------|
| `lib/utils.sh` | Pass | `_wt_format_entry` added correctly alongside `_wt_display_name`; POSIX-compatible; proper local variable declaration |
| `lib/commands.sh` | Pass | All three dry-run display paths updated to `_wt_format_entry`; `echo ""` separators placed correctly; non-dry-run path (lines 363-365) intentionally unchanged |
| `test/cmd_clear.bats` | Pass | 6 new tests added; cover all required scenarios; use correct BATS assertions; line-by-line blank-line detection logic is sound |

### Issues Found

None

### AC Verification

- [x] AC 1 — When `basename(wt_path) == branch`, entry displayed without `(branch)` suffix: `_wt_format_entry` in `lib/utils.sh:133-140`; test: `_cmd_clear --dry-run: name-match suppresses (branch) suffix in to-delete list`
- [x] AC 2 — When `basename(wt_path) != branch`, `(branch)` suffix retained: same helper, else branch; test: `_cmd_clear --dry-run: name-mismatch retains (branch) suffix in to-delete list`
- [x] AC 3 — Blank line after "would be removed" list: `echo ""` at `lib/commands.sh:337`; test: `_cmd_clear --dry-run: blank line after to-delete list before protected section`
- [x] AC 4 — Blank line after "protected (skipped)" list: `echo ""` at `lib/commands.sh:348`; test: `_cmd_clear --dry-run: blank line after protected section before summary`
- [x] AC 5 — Name-deduplication in protected section: `_wt_format_entry` used at `lib/commands.sh:288` (protected-only path) and `lib/commands.sh:344` (mixed path); test: `_cmd_clear --dry-run: name-match suppresses (branch) suffix in protected list`
- [x] AC 6 — Non-dry-run confirmation output unchanged: `lib/commands.sh:363-365` still uses `_wt_display_name "$wt_path") ($br)` (original pattern); no new test needed (pre-existing tests cover this path)
- [x] AC 7 — All existing `cmd_clear` BATS tests pass: 323/323 passed, 0 failed
- [x] AC 8 — New tests cover name-match suppression, name-mismatch retention, section spacing: 6 new tests in `test/cmd_clear.bats` (tests 35-40)

### Test Results

- Total: 323 / Passed: 323 / Failed: 0

### Shellcheck

- Clean: yes

## Manual Testing

All scenarios tested by sourcing `lib/utils.sh`, `lib/config.sh`, `lib/worktree.sh`, and `lib/commands.sh` into a temporary isolated git repo with a `.worktrees/config.json` pointing to `origin/main` as `mainBranch`. Worktrees were backdated via `touch -t 202001010000` to appear old. The automated BATS suite (`npm test`) was also run in full.

**Automated suite:** 323 / 323 passed, 0 failed.

### Test Scenarios

| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | Name-match: `feat-login` worktree with branch `feat-login` — `--dry-run` to-delete list | Entry shown as `feat-login - N days ago` (no `(feat-login)` suffix) | `feat-login - 2244 days ago` | Pass |
| 2 | Name-mismatch: `NO_TASK-feat-api` worktree with branch `feat-api` — `--dry-run` to-delete list | Entry shown as `NO_TASK-feat-api (feat-api) - N days ago` | `NO_TASK-feat-api (feat-api) - 2244 days ago` | Pass |
| 3 | Both sections present: old `old-feat` + protected `master` worktree — `--dry-run` | Blank line after to-delete list; blank line after protected section; summary follows | Correct blank lines observed at both positions | Pass |
| 4 | Protected-only: only `develop` worktree (protected, no to-delete candidates) | `[dry-run] No worktrees would be removed`, blank line, `[dry-run] Protected worktrees (skipped):`, `develop [protected — skipped]` (no parentheses), trailing blank line | Output matches exactly | Pass |
| 5 | To-delete-only: `feat-xyz` old worktree, no protected | To-delete list, blank line, summary — no extra blank line at end | Output matches; no spurious extra blank line | Pass |
| 6 | Both absent: no worktrees at all | `[dry-run] No worktrees would be removed` only | Output matches; no extra sections or blank lines | Pass |
| 7 | Non-dry-run confirmation output unchanged | List still shows `name (branch)` format (out of scope) | `feat-nodrrun (feat-nodrrun) - N days ago` — original format preserved | Pass |
| 8 | User Flow "After" reproduction: `CORE-667-fix-login` (name-match), `test-ai-mlm-assistant` dir with `NO_TASK-test-ai-mlm-assistant` branch (mismatch), `develop` (protected, name-match) | Matches the "After" example in STORY-039 description | Output matches expected format exactly | Pass |

### Issues Found

None
