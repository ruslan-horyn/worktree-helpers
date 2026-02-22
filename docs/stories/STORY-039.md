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

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
