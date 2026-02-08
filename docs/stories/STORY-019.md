# STORY-019: Add `wt --rename` command

**Epic:** Developer Experience
**Priority:** Could Have
**Story Points:** 3
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-08
**Sprint:** 3

---

## User Story

As a developer
I want to rename my current worktree's branch
So that I can fix typos or update branch names without recreating the worktree

---

## Description

### Background

When working with git worktrees, it's common to realize a branch was named incorrectly — a typo, an outdated naming convention, or a shifted purpose. Currently, the only way to fix a branch name is to:

1. Remove the worktree (`wt -r <branch>`)
2. Create a new worktree with the correct name (`wt -n <new-branch>`)
3. Cherry-pick or re-apply any uncommitted work

This is tedious and error-prone. A single `wt --rename <new-branch>` command should handle the full rename: branch, worktree directory, and remote tracking — all in one step.

### Scope

**In scope:**
- `wt --rename <new-branch>` renames the current worktree's branch
- Worktree directory moved to match the new branch name
- Remote tracking branch updated if a remote branch exists
- Confirmation prompt before rename (bypass with `-f`)
- Error handling for: not in a worktree, new branch name already exists, main/dev branch protection

**Out of scope:**
- Renaming a worktree other than the current one (could be added later)
- Renaming the remote branch on the server (only local tracking is updated)
- Batch renaming multiple worktrees
- Metadata update (STORY-016 dependency — if metadata exists, update it; otherwise skip)

---

## User Flow

1. Developer is inside a worktree (`cd ~/projects/myapp_worktrees/fix-lgoin-bug`)
2. Developer realizes the branch name has a typo
3. Developer runs `wt --rename fix-login-bug`
4. Tool detects current branch (`fix-lgoin-bug`) and confirms:
   ```
   Rename 'fix-lgoin-bug' → 'fix-login-bug'? [y/N]
   ```
5. User confirms with `y`
6. Tool renames the branch: `git branch -m fix-lgoin-bug fix-login-bug`
7. Tool moves the worktree directory: `git worktree move <old-path> <new-path>`
8. Tool updates remote tracking if `origin/fix-lgoin-bug` exists
9. Tool changes the shell's working directory to the new worktree path
10. Tool displays success:
    ```
    Renamed 'fix-lgoin-bug' → 'fix-login-bug'
    Worktree: ~/projects/myapp_worktrees/fix-login-bug
    ```

**Force mode:** `wt --rename fix-login-bug -f` skips the confirmation prompt.

---

## Acceptance Criteria

- [ ] `wt --rename <new-branch>` renames the current worktree's branch
- [ ] Worktree directory renamed to match new branch name (under same parent directory)
- [ ] Remote tracking branch updated if `origin/<old-branch>` exists (`git branch -u origin/<new> <new>`)
- [ ] Error if not inside a worktree (running from main repo root)
- [ ] Error if `<new-branch>` already exists as a local branch
- [ ] Error if no `<new-branch>` argument provided (shows usage)
- [ ] Confirmation prompt before rename: `Rename '<old>' → '<new>'? [y/N]`
- [ ] `-f` / `--force` bypasses confirmation prompt
- [ ] After rename, shell working directory is updated to the new worktree path
- [ ] Success message shows old name, new name, and new worktree path
- [ ] Protected branches cannot be renamed (current branch matching `GWT_MAIN_REF` local part)
- [ ] Works correctly when current branch name contains special characters (slashes like `feature/login`)

---

## Technical Notes

### Components

- **`lib/commands.sh`**: New `_cmd_rename` function — the main command handler
- **`wt.sh`**: Router update — add `--rename` flag parsing and dispatch to `_cmd_rename`
- **`lib/commands.sh`**: Update `_cmd_help` with `--rename` usage

### Implementation Details

#### Router changes (`wt.sh`)

Add to the `while` loop in `wt()`:

```sh
--rename)  action="rename"; shift
           case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
```

Add to the `case` dispatch:

```sh
rename) _cmd_rename "$arg" "$force" ;;
```

#### Command handler (`lib/commands.sh`)

```sh
_cmd_rename() {
  local new_branch="$1" force="$2"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1

  # Validate: new branch name required
  [ -z "$new_branch" ] && { _err "Usage: wt --rename <new-branch>"; return 1; }

  # Detect current branch
  local old_branch
  old_branch=$(_current_branch) || { _err "Cannot detect current branch"; return 1; }

  # Validate: must be in a worktree (not main repo)
  local main_root
  main_root=$(_main_repo_root)
  [ "$PWD" = "$main_root" ] && { _err "Cannot rename from main repo — switch to a worktree first"; return 1; }

  # Validate: new branch doesn't already exist
  _branch_exists "$new_branch" && { _err "Branch '$new_branch' already exists"; return 1; }

  # Validate: not renaming a protected branch
  local main_local="${GWT_MAIN_REF#*/}"
  [ "$old_branch" = "$main_local" ] && { _err "Cannot rename the main branch"; return 1; }

  # Same name check
  [ "$old_branch" = "$new_branch" ] && { _err "New name is the same as current name"; return 1; }

  # Confirmation prompt (unless -f)
  if [ "$force" -ne 1 ]; then
    printf "Rename '%s' → '%s'? [y/N] " "$old_branch" "$new_branch" >&2
    read -r r
    case "$r" in y|Y) ;; *) _info "Aborted"; return 1 ;; esac
  fi

  # 1. Rename the branch
  git branch -m "$old_branch" "$new_branch" || { _err "Failed to rename branch"; return 1; }

  # 2. Move the worktree directory
  local old_path="$PWD"
  local parent_dir="${old_path%/*}"
  local new_path="$parent_dir/$new_branch"

  if [ "$old_path" != "$new_path" ]; then
    git worktree move "$old_path" "$new_path" || {
      # Rollback branch rename on failure
      git branch -m "$new_branch" "$old_branch"
      _err "Failed to move worktree"
      return 1
    }
    cd "$new_path" || return 1
  fi

  # 3. Update remote tracking (if remote branch exists)
  if git show-ref --verify --quiet "refs/remotes/origin/$old_branch"; then
    git branch -u "origin/$old_branch" "$new_branch" 2>/dev/null
  fi

  # 4. Update branch remote/merge config
  git config "branch.$new_branch.remote" "origin" 2>/dev/null
  git config "branch.$new_branch.merge" "refs/heads/$new_branch" 2>/dev/null

  _info "Renamed '$old_branch' → '$new_branch'"
  _info "Worktree: $new_path"
}
```

#### Help text update (`_cmd_help`)

Add to Commands section:

```
  --rename <new-branch>  Rename current worktree's branch
```

### Edge Cases

- **Branch names with slashes** (e.g., `feature/login`): `git branch -m` handles these natively. The worktree directory uses the full branch name, so `git worktree move` handles the path correctly.
- **Worktree move fails**: Roll back the branch rename to keep state consistent.
- **Remote branch doesn't exist yet**: Skip the tracking update silently — the developer may not have pushed yet.
- **Same name**: Error early with a clear message.
- **Running from main repo**: Detect via comparing `$PWD` with `_main_repo_root` and error.
- **Detached HEAD**: `_current_branch` returns `HEAD` — detect and error.

### Security Considerations

- Branch names are passed to `git branch -m` which validates them (rejects invalid characters)
- No user input is passed to `eval` or unquoted shell expansion
- Worktree paths are constructed from the parent directory + new branch name (no path traversal risk)

---

## Dependencies

**Prerequisite Stories:**
- None (independent feature)

**Blocked Stories:**
- None

**External Dependencies:**
- Git 2.17+ (for `git worktree move` support)

---

## Definition of Done

- [ ] `_cmd_rename` implemented in `lib/commands.sh`
- [ ] Router updated in `wt.sh` to handle `--rename` flag
- [ ] Help text updated in `_cmd_help`
- [ ] Works in both zsh and bash
- [ ] Works on both macOS and Linux
- [ ] Branch rename works correctly (`git branch -m`)
- [ ] Worktree directory moves correctly (`git worktree move`)
- [ ] Remote tracking updated when applicable
- [ ] Confirmation prompt works (and `-f` bypasses it)
- [ ] Error cases handled: no arg, not in worktree, branch exists, same name, main branch
- [ ] Rollback on failure (branch rename reverted if worktree move fails)
- [ ] Manual testing completed with real worktrees
- [ ] No regressions in existing functionality
- [ ] Code follows existing patterns (`_` prefix, `GWT_*` globals, POSIX-compatible)

---

## Story Points Breakdown

- **Router + flag parsing**: 0.5 points
- **`_cmd_rename` implementation**: 1.5 points
- **Edge cases + error handling + rollback**: 0.5 points
- **Testing + help text**: 0.5 points
- **Total:** 3 points

**Rationale:** The 3-point estimate reflects moderate complexity. The core logic is straightforward (3 git commands), but edge case handling (rollback, directory change, remote tracking), confirmation prompts, and the `cd` side-effect add implementation and testing effort. Comparable to STORY-015 (granular clear options) in scope.

---

## Additional Notes

- **Shell `cd` behavior**: Since `wt` is a shell function (not a script), `cd "$new_path"` inside `_cmd_rename` will change the user's working directory — this is the desired behavior and matches how `_cmd_switch` works via hooks.
- **Future enhancement**: Once STORY-016 (metadata tracking) is implemented, `_cmd_rename` should update the metadata entry key from old branch to new branch. This can be added as a follow-up or included if STORY-016 ships first.
- **`git worktree move` requirement**: This command was added in Git 2.17 (April 2018). The project already implicitly requires a modern git version for worktree features, so this is not a concern.
- **Remote branch rename**: This story deliberately does NOT rename the remote branch (`git push origin :old-branch && git push -u origin new-branch`). That's a destructive operation affecting shared state and should be a separate, explicit action by the user.

---

## Progress Tracking

**Status History:**
- 2026-02-08: Created

**Actual Effort:** TBD (will be filled during/after implementation)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
