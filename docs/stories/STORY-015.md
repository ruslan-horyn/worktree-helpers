# STORY-015: Add more granular clear options

**Epic:** Developer Experience
**Priority:** Could Have
**Story Points:** 3
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-09
**Sprint:** 4

---

## User Story

As a developer
I want to clear worktrees using flexible filters (merged status, pattern, dry-run)
So that I have finer control over cleanup beyond just age

---

## Description

### Background

The current `wt -c <days>` command only supports age-based filtering with optional `--dev-only` / `--main-only` scope modifiers. While effective for time-based cleanup, developers often need more nuanced control — for example, removing all worktrees whose branches have already been merged into main, targeting worktrees matching a naming pattern (e.g., `fix-*`), or previewing what would be deleted before committing to the action. This story extends `_cmd_clear` with three new flags to address these needs.

### Scope

**In scope:**

- `--merged` flag: filter to worktrees whose branches are merged into the main branch
- `--pattern <glob>` flag: filter to worktrees whose branch names match a shell glob pattern
- `--dry-run` flag: preview what would be cleared without actually deleting anything
- All new flags combinable with each other and with existing flags (`<days>`, `--dev-only`, `--main-only`, `--force`)
- Make `<days>` argument optional when `--merged` or `--pattern` is provided (clear all matching, not just old ones)

**Out of scope:**

- Interactive selection (fzf-based picking of which worktrees to clear)
- Regex support for `--pattern` (shell glob is sufficient for branch names)
- Undo/restore of cleared worktrees

### User Flow

1. **Dry-run preview:**

   ```
   $ wt -c 30 --dry-run
   [dry-run] Worktrees that would be removed (older than 30 days):
     /path/to/worktrees/fix-login (fix-login) - 45 days ago
     /path/to/worktrees/feat-api (feat-api) - 32 days ago
   [dry-run] 2 worktree(s) would be removed
   ```

2. **Clear merged branches:**

   ```
   $ wt -c --merged
   Worktrees to remove (branches merged into main):
     /path/to/worktrees/fix-login (fix-login) - 45 days ago
     /path/to/worktrees/old-hotfix (old-hotfix) - 12 days ago

   Remove 2 worktree(s)? [y/N] y
   Removed /path/to/worktrees/fix-login
   Deleted branch fix-login
   ...
   ```

3. **Clear by pattern:**

   ```
   $ wt -c --pattern "fix-*" --dry-run
   [dry-run] Worktrees that would be removed (matching pattern: fix-*):
     /path/to/worktrees/fix-login (fix-login) - 45 days ago
     /path/to/worktrees/fix-header (fix-header) - 3 days ago
   [dry-run] 2 worktree(s) would be removed
   ```

4. **Combined filters:**

   ```
   wt -c 14 --merged --dev-only --dry-run
   ```

---

## Acceptance Criteria

- [x] `wt -c --merged` clears worktrees whose branches are merged into the main branch (from `GWT_MAIN_REF`)
- [x] `wt -c --pattern <glob>` clears worktrees whose branch names match the shell glob pattern
- [x] `wt -c --dry-run` shows what would be cleared without deleting anything
- [x] `--dry-run` output lines are prefixed with `[dry-run]` for clear visual distinction
- [x] `--dry-run` shows the count of worktrees that would be removed
- [x] `<days>` argument becomes optional when `--merged` or `--pattern` is provided
- [x] When `<days>` is omitted, all matching worktrees are candidates (no age filter)
- [x] All new flags are combinable with existing flags (`--dev-only`, `--main-only`, `--force`)
- [x] `--merged` + `--pattern` can be combined (both filters must match)
- [x] Locked worktrees are still skipped (existing behavior preserved)
- [x] Main repository worktree is never removed (existing behavior preserved)
- [x] Help text (`wt -h`) updated with new flags
- [x] Errors on `wt -c` with no flags and no days argument (must provide at least `<days>`, `--merged`, or `--pattern`)
- [x] README updated with new `--merged`, `--pattern`, and `--dry-run` flags in the clear command documentation

---

## Technical Notes

### Components

- **Router:** `wt.sh` — add parsing for `--merged`, `--pattern`, `--dry-run` flags
- **Commands:** `lib/commands.sh` — extend `_cmd_clear` function signature and logic
- **Help:** `_cmd_help` in `lib/commands.sh` — update clear section

### Router Changes (`wt.sh`)

Add new local variables and flag parsing:

```sh
local merged=0 pattern="" dry_run=0
# In the while loop:
--merged)   merged=1; shift ;;
--pattern)  shift; pattern="$1"; shift ;;
--dry-run)  dry_run=1; shift ;;
```

Update the clear dispatch:

```sh
clear) _cmd_clear "$clear_days" "$force" "$dev_only" "$main_only" "$merged" "$pattern" "$dry_run" ;;
```

### Command Changes (`lib/commands.sh`)

Extend `_cmd_clear` signature:

```sh
_cmd_clear() {
  local days="$1" force="$2" dev_only="$3" main_only="$4"
  local merged="$5" pattern="$6" dry_run="$7"
```

**Validation changes:**

- `days` is required ONLY if `merged=0` AND `pattern` is empty
- When `days` is empty but `--merged` or `--pattern` is set, skip age filtering

**Merged detection:**

- Use `git branch --merged "$GWT_MAIN_REF"` to get list of merged branch names
- Strip whitespace and `*` prefix from output
- Store as a lookup set (newline-delimited string) for O(n) matching
- Note: `GWT_MAIN_REF` is like `origin/main` — `git branch --merged` accepts remote refs

**Pattern matching:**

- Use shell `case` statement for POSIX-compatible glob matching:

  ```sh
  case "$branch" in $pattern) ;; *) continue ;; esac
  ```

**Dry-run mode:**

- When `dry_run=1`, skip the confirmation prompt and deletion loop
- Instead, print the list with `[dry-run]` prefix and a summary count

### Filter Application Order

Within the worktree iteration loop, filters apply in this order:

1. Skip main repository (existing)
2. Apply `--dev-only` / `--main-only` filter (existing)
3. Apply `--pattern` filter (new)
4. Apply age filter via `<days>` (existing, but now optional)
5. Apply `--merged` filter (new)
6. Check locked status (existing)

### Edge Cases

- `--merged` with detached HEAD worktrees: skip (detached has no branch to check)
- `--pattern` with special glob characters: pass through directly to `case` (shell handles it)
- `wt -c --merged` when no branches are merged: "No worktrees to clear"
- `wt -c --pattern "nonexistent-*"`: "No worktrees to clear"
- `wt -c --dry-run` alone (no other filter/days): error, same as `wt -c` alone

---

## Dependencies

**Prerequisite Stories:**

- None (extends existing `_cmd_clear` which is already implemented)

**Blocked Stories:**

- None

**External Dependencies:**

- None

---

## Definition of Done

- [x] Code implemented following existing patterns (`_` prefix, POSIX-compatible)
- [x] Router parses `--merged`, `--pattern`, `--dry-run` flags correctly
- [x] `_cmd_clear` extended with new parameters
- [x] BATS tests written covering:
  - [x] `--merged` removes only merged worktrees
  - [x] `--merged` skips unmerged worktrees
  - [x] `--pattern` filters by branch name glob
  - [x] `--pattern` with no matches shows "No worktrees to clear"
  - [x] `--dry-run` does not delete anything
  - [x] `--dry-run` output contains `[dry-run]` prefix
  - [x] Combined flags (`--merged --pattern`, `--merged --dry-run`, etc.)
  - [x] `<days>` optional when `--merged` or `--pattern` provided
  - [x] Error when no days and no `--merged`/`--pattern`
  - [x] Existing tests still pass (no regressions)
- [x] Shellcheck passes
- [x] CI passes (GitHub Actions)
- [x] Help text updated
- [x] Works in both bash and zsh
- [x] Works on macOS and Linux

---

## Story Points Breakdown

- **Router + command logic:** 1.5 points
- **Testing:** 1 point
- **Help text + edge cases:** 0.5 points
- **Total:** 3 points

**Rationale:** Moderate complexity — extends existing `_cmd_clear` function with additional filter layers. The merged detection and pattern matching are straightforward POSIX operations. Most effort is in testing the various flag combinations.

---

## Additional Notes

### Implementation Tips

- The `git branch --merged <ref>` command outputs branch names with leading whitespace and `*` for current. Use `sed 's/^[* ]*//'` to normalize.
- For pattern matching, ensure the `case` statement uses unquoted `$pattern` so glob expansion works correctly in the shell.
- The dry-run mode should reuse the same collection logic but diverge at the action step — consider structuring the code so the "collect candidates" phase is shared and only the "execute" phase differs.

### Compatibility Note

All new logic must be POSIX-compatible:

- Use `case` for pattern matching (no `[[ ]]` or `=~`)
- Use `$(...)` not backticks
- No arrays — use newline-delimited strings

---

## Progress Tracking

**Status History:**

- 2026-02-09: Created
- 2026-02-15: Completed

**Actual Effort:** 3 points (as estimated)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
