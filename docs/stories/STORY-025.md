# STORY-025: Improve UX when opening worktree from existing branch

**Epic:** Developer Experience
**Priority:** Must Have
**Story Points:** 5
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-12
**Sprint:** Backlog

---

## User Story

As a developer using `wt`
I want clear guidance and correct behavior when working with existing branches
So that I don't waste time debugging cryptic errors and can quickly open worktrees from branches that already exist

---

## Description

### Background

When a developer tries `wt -n <branch>` (or `wt -n -d`) and the branch already exists locally, the tool prints a bare "Branch exists" error with no guidance on what to do instead. The developer has to figure out on their own that `wt -o <branch>` is the correct command.

Additionally, when `wt -o` opens a worktree from an existing branch, the `created` hook receives the branch name as the "base ref" parameter (`$3`). Hooks that try to fetch latest changes using `$3` run `git fetch <branch-name>` instead of `git fetch origin <branch-name>`, causing a fatal error because git interprets the branch name as a remote repository.

Finally, `_wt_open` does not attempt to fast-forward the local branch to match `origin/<branch>` after creating the worktree, so the checked-out code may be stale even when newer commits exist on the remote.

### Scope

**In scope:**
- Improve error message in `_cmd_new` when branch exists — suggest `wt -o <branch>`
- Improve error message in `_cmd_dev` when branch exists — suggest `wt -o <branch>`
- Fix `_wt_open` to pass `origin/<branch>` (not bare `<branch>`) as base ref to hook
- Add post-creation fast-forward in `_wt_open` (pull latest from `origin/<branch>`)

**Out of scope:**
- Auto-fallback from `wt -n` to `wt -o` (changes semantics of `-n`, can be a future enhancement)
- Changes to user-defined hooks (they should work correctly with the fixed base ref)
- Interactive prompts ("Branch exists, open as worktree? y/n")

### User Flow

**Current (broken):**
1. Developer runs `wt -n -d` (or `wt -n some-branch`)
2. Gets: `"Branch exists"` — no hint what to do
3. Developer guesses to use `wt -o <branch>`
4. Worktree is created, but hook fails with: `fatal: '<branch>' does not appear to be a git repository`
5. Developer has stale code, no idea fetch failed

**Improved:**
1. Developer runs `wt -n -d` (or `wt -n some-branch`)
2. Gets: `"Branch '<branch>' already exists. Use 'wt -o <branch>' to open it as a worktree."`
3. Developer runs `wt -o <branch>`
4. Worktree is created, hook receives `origin/<branch>` as base ref, fetch succeeds
5. Local branch is fast-forwarded to latest origin, code is up to date

---

## Acceptance Criteria

- [ ] `wt -n <existing-branch>` prints error with suggestion: `"Branch '<name>' already exists. Use 'wt -o <name>' to open it as a worktree."`
- [ ] `wt -n -d` (when dev branch exists) prints error with same suggestion format, including the derived branch name
- [ ] `_wt_open` passes `origin/<branch>` as the base ref (`$3`) to the `created` hook instead of bare `<branch>`
- [ ] After worktree creation, `_wt_open` fast-forwards the local branch to `origin/<branch>` if remote tracking branch exists
- [ ] Fast-forward is non-fatal: if `origin/<branch>` doesn't exist or FF fails, worktree still opens successfully with a warning
- [ ] Existing behavior of `_wt_create` (new branches) is not affected
- [ ] All existing BATS tests continue to pass
- [ ] New tests cover:
  - Error message text when branch exists in `_cmd_new`
  - Error message text when branch exists in `_cmd_dev`
  - `_wt_open` hook receives `origin/<branch>` as `$3`
  - Fast-forward after worktree creation

---

## Technical Notes

### Components

- `lib/commands.sh` — `_cmd_new` (line 8), `_cmd_dev` (line 21): improve error messages
- `lib/worktree.sh` — `_wt_open` (lines 113-115): fix base ref for hook, add FF step
- `test/commands.bats` — new test cases for error messages
- `test/worktree.bats` — new test cases for hook args and FF behavior

### Changes Detail

**1. `_cmd_new` (commands.sh:8)**
```sh
# Before:
_branch_exists "$branch" && { _err "Branch exists"; return 1; }

# After:
_branch_exists "$branch" && { _err "Branch '$branch' already exists. Use 'wt -o $branch' to open it as a worktree."; return 1; }
```

**2. `_cmd_dev` (commands.sh:21)**
```sh
# Before:
_branch_exists "$branch" && { _err "Branch exists"; return 1; }

# After:
_branch_exists "$branch" && { _err "Branch '$branch' already exists. Use 'wt -o $branch' to open it as a worktree."; return 1; }
```

**3. `_wt_open` hook base ref (worktree.sh:115)**
```sh
# Before:
_run_hook created "$wt_path" "$branch" "$branch" "$(_main_repo_root)"

# After:
_run_hook created "$wt_path" "$branch" "origin/$branch" "$(_main_repo_root)"
```

**4. `_wt_open` post-creation fast-forward (worktree.sh, after line 113)**
```sh
# After git worktree add succeeds, try FF:
if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  git -C "$wt_path" merge --ff-only "origin/$branch" 2>/dev/null \
    || _info "Note: could not fast-forward '$branch' to origin (diverged or conflict)"
fi
```

### Edge Cases

- Branch exists locally but NOT on remote → FF step is skipped (no warning needed)
- Branch exists on remote but local is ahead → FF fails, warning printed, worktree still works
- Branch has diverged from origin → FF fails, warning printed, user resolves manually
- Hook doesn't use `$3` at all → no impact, backward compatible

---

## Dependencies

**Prerequisite Stories:**
- None (standalone improvement)

**Blocked Stories:**
- None

**External Dependencies:**
- None

---

## Definition of Done

- [ ] Code changes implemented in `lib/commands.sh` and `lib/worktree.sh`
- [ ] BATS tests added and passing for all acceptance criteria
- [ ] `shellcheck` passes on modified files
- [ ] All existing tests continue to pass
- [ ] CI pipeline green
- [ ] Manual testing: verified improved error messages and FF behavior

---

## Story Points Breakdown

- **Error messages:** 1 point (straightforward string changes in 2 functions)
- **Hook base ref fix:** 1 point (one-line change + test)
- **Fast-forward logic:** 2 points (new logic with edge case handling + tests)
- **Testing:** 1 point (new BATS tests for all scenarios)
- **Total:** 5 points

**Rationale:** The code changes are small and well-scoped, but testing the FF behavior across multiple scenarios (no remote, diverged, FF-able) adds moderate complexity.

---

## Additional Notes

The root cause of the hook fetch error is that `_wt_open` treats the branch name as the "base ref" (passed as `$3` to hook), but for opened branches there's no separate base — the branch IS the target. Passing `origin/$branch` aligns with the convention that `$3` should be a fetchable ref, matching how `_wt_create` passes refs like `origin/main`.

---

## Progress Tracking

**Status History:**
- 2026-02-12: Created
- 2026-02-13: Completed

**Actual Effort:** 5 points (matched estimate)
