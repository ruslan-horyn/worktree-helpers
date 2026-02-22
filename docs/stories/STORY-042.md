# STORY-042: Throwaway worktree without branch (`wt -n --detach`)

**Epic:** Developer Experience
**Priority:** Could Have
**Story Points:** 3
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** Backlog

---

## User Story

As a developer who wants to quickly test an older version or run a spike
I want to create a worktree in detached HEAD mode without creating a branch
So that I can experiment freely without polluting branch history

---

## Description

### Background

Native `git worktree add --detach <path> [<commit-ish>]` supports detached HEAD worktrees. `wt` currently always creates or checks out a branch — there is no way to create a throwaway worktree at an arbitrary ref without first creating a named branch.

The `--detach` flag fills this gap. A developer testing a tagged release, debugging a regression at a historical commit, or exploring a remote ref without creating a tracking branch can use `wt -n --detach <ref>` to get a clean isolated workspace that disappears with `wt -r` without leaving any branch behind.

### Scope

**In scope:**
- `wt -n --detach <ref>` creates a worktree with detached HEAD at `<ref>`
- `<ref>` can be any git commit-ish: tag, SHA, `HEAD~N`, `origin/branch-name`
- If `<ref>` is omitted, default to `HEAD` of the main branch (`GWT_MAIN_REF`)
- `wt -l` displays `[detached @ <short-sha>]` for detached worktrees instead of a branch name
- `wt -r` removes the detached worktree normally (no branch to delete)
- `wt -c` includes detached worktrees in cleanup (no branch to protect, no branch to delete after removal)
- Created hook still runs; receives the resolved commit SHA as `$2` and the original ref as `$3`
- `--detach` combined with `-d` (dev branch mode) is an error

**Out of scope:**
- Re-attaching a detached HEAD worktree to a branch (`git switch -c <branch>` inside the worktree is the escape hatch)
- Converting an existing worktree to detached HEAD
- `wt -o --detach` (open an existing branch in detached mode)
- Custom directory naming for the detached worktree (name is derived from the sanitised ref, same as today)

### User Flow

1. Developer runs `wt -n --detach v2.0.0`
2. `wt` calls `git worktree add --detach <path> v2.0.0` — no branch is created
3. Hooks symlink runs, then the `created` hook fires with `$1=<path>`, `$2=<sha>`, `$3=v2.0.0`
4. Developer works in the worktree
5. `wt -l` shows the worktree with `[detached @ abc1234]` instead of a branch name
6. Developer runs `wt -r` to remove the worktree — no branch deletion step is needed

---

## Acceptance Criteria

- [ ] `wt -n --detach <ref>` creates a worktree with detached HEAD at `<ref>`
- [ ] If `<ref>` is omitted, defaults to `HEAD` of main branch (`GWT_MAIN_REF`)
- [ ] `wt -l` shows `[detached @ <short-sha>]` for detached worktrees (replacing the branch name column)
- [ ] `wt -r` removes a detached worktree normally (no branch deletion attempted)
- [ ] `wt -c` includes detached worktrees in cleanup (no `(branch)` label shown; SHA shown instead)
- [ ] Created hook receives `$2=<sha>` (resolved commit SHA) and `$3=<ref>` (the ref passed by the user)
- [ ] `wt -n --detach -d` (or `wt -n -d --detach`) exits with an error: `--detach and --dev are mutually exclusive`
- [ ] `wt -n --help` documents the `--detach` option
- [ ] The `Commands` section of README is updated with 1-3 lines about `--detach`

---

## Technical Notes

### Components Involved

- **`wt.sh`** (router): parse `--detach` flag; add mutual-exclusivity check against `-d`; pass `detach` flag through to `_cmd_new`
- **`lib/commands.sh`** — `_cmd_new`: branch on `detach` flag to call a new `_wt_create_detach` helper instead of `_wt_create`; update `_help_new` to document `--detach`
- **`lib/worktree.sh`** — new `_wt_create_detach` function; update `_wt_branch` to handle detached HEAD (returns empty or `(detached)`)
- **`lib/commands.sh`** — `_cmd_list`: `[detached @ <short-sha>]` display already partially handled (the porcelain parser already captures `detached` keyword); ensure formatted output uses `[detached @ <sha>]` with the short SHA
- **`lib/commands.sh`** — `_cmd_remove`: skip `git branch -D` when `_wt_branch` returns empty (detached worktrees have no branch to delete) — this already works today per the guard `[ -n "$branch" ]`
- **`lib/commands.sh`** — `_cmd_clear`: detached worktrees already tracked with `branch="(detached)"` in the porcelain parser; display label must say `<sha>` not `(branch)` in dry-run and deletion output; `--merged` filter already skips detached worktrees

### Flag Parsing in `wt.sh`

Add a `detach=0` local variable. Parse `--detach` in the `while` loop:

```sh
--detach)  detach=1; shift ;;
```

In the `new` action block, add a mutual-exclusivity guard before dispatching:

```sh
if [ "$detach" -eq 1 ] && [ "$dev" -eq 1 ]; then
  _err "--detach and --dev are mutually exclusive"; return 1
fi
```

Pass `detach` to `_cmd_new` as a third argument (or as a separate dedicated variable via a wrapper).

### `_cmd_new` Changes

Current signature: `_cmd_new() { local branch="$1" from_ref="$2" ... }`

Add `detach="$3"`. When `detach=1`:
- Skip the `_branch_exists` duplicate-branch check (there is no branch to conflict)
- Call `_wt_create_detach "$ref" "$GWT_WORKTREES_DIR"` instead of `_wt_create`
- `ref` defaults to `GWT_MAIN_REF` if not provided via `--from`

### New `_wt_create_detach` in `lib/worktree.sh`

```sh
_wt_create_detach() {
  local ref="$1" dir="$2"
  local safe_name; safe_name=$(_wt_dir_name "$ref")
  local wt_path="$dir/$safe_name"
  [ -e "$wt_path" ] && { _err "Path exists: $wt_path"; return 1; }

  _info "Creating detached worktree at '$ref'"
  git worktree add --detach "$wt_path" "$ref" || { _err "Failed"; return 1; }

  local sha; sha=$(git -C "$wt_path" rev-parse --short HEAD)
  _symlink_hooks "$wt_path"
  _run_hook created "$wt_path" "$sha" "$ref" "$(_main_repo_root)"
  _wt_warn_count
}
```

Key points:
- No `git config branch.*` calls (no branch exists)
- No `_fetch` call (ref is resolved locally; caller passes an already-known ref)
- Hook receives `$2=<sha>` (short SHA) consistent with how detached HEAD is identified

### `_cmd_list` Display

The `_cmd_list` parser in `lib/commands.sh` already sets `branch="(detached)"` when it reads the `detached` keyword from `git worktree list --porcelain`. To show `[detached @ <sha>]` the list command needs the HEAD SHA for detached worktrees.

Get the SHA at display time:

```sh
detached)
  local _sha; _sha=$(git -C "$worktree" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  branch="[detached @ $_sha]"
  ;;
```

This replaces the bare `(detached)` assignment and produces the human-friendly label in the branch column.

### `_cmd_clear` Display

In both the dry-run and deletion loops, the branch label `br` will be `[detached @ <sha>]` (set during list parsing). The existing guard `[ "$br" != "(detached)" ]` in the deletion path must be updated to match the new format — or better, check with `git worktree list --porcelain` directly for `detached` keyword rather than string-comparing `br`.

Alternatively: keep the internal sentinel value as `(detached)` for logic, and only apply the `[detached @ <sha>]` format at display time (same as `_cmd_list`). This minimises changes to the clear logic.

### `_help_new` Update

Add a new usage line and option entry:

```
    wt -n --detach <ref>           Create detached HEAD worktree at <ref>

  Options:
    ...
    --detach            Create worktree with detached HEAD (no branch created)
```

### Tests (`test/cmd_new.bats` — new section)

- `_wt_create_detach` creates a worktree with detached HEAD
- `_wt_create_detach` defaults to `GWT_MAIN_REF` when no ref given
- `wt -n --detach <tag>` succeeds end-to-end (router test)
- `wt -n --detach -d` exits with error about mutual exclusivity
- `wt -l` shows `[detached @ <sha>]` for a detached worktree
- `wt -r` removes a detached worktree without attempting branch deletion

---

## Dependencies

- None

---

## Definition of Done

- [ ] `--detach` flag parsed in `wt.sh` router
- [ ] Mutual-exclusivity check for `--detach` + `-d` in router
- [ ] `_wt_create_detach` function implemented in `lib/worktree.sh`
- [ ] `_cmd_new` dispatches to `_wt_create_detach` when `detach=1`
- [ ] `_cmd_list` displays `[detached @ <short-sha>]` for detached worktrees
- [ ] `_cmd_clear` display output uses `<sha>` label (not `(branch)`) for detached worktrees
- [ ] `_cmd_remove` works without modification (existing `[ -n "$branch" ]` guard already handles missing branch)
- [ ] `_help_new` updated with `--detach` option and example
- [ ] `_cmd_help` (global help) updated with `--detach` in flags list
- [ ] README updated with 1-3 lines about `wt -n --detach`
- [ ] BATS tests written and passing for all acceptance criteria
- [ ] All existing tests continue to pass (`npm test`)
- [ ] shellcheck passes with no new warnings

---

## Story Points Breakdown

- **Router flag + mutual-exclusivity guard:** 0.5 points
- **`_wt_create_detach` helper:** 0.5 points
- **`_cmd_list` detached display:** 0.5 points
- **`_cmd_clear` display fix:** 0.5 points
- **Tests:** 1 point
- **Total:** 3 points

**Rationale:** The git primitive already exists (`git worktree add --detach`). The work is mostly plumbing: route the flag, write a thin helper, and adjust two display paths. The `_cmd_remove` and `_cmd_clear` deletion logic already handle detached worktrees correctly — only the display labels need updating.

---

## Additional Notes

- Directory name for the worktree is derived from the sanitised ref via `_wt_dir_name`. A ref like `v2.0.0` becomes directory `v2.0.0`; `HEAD~10` becomes `HEAD~10`; `origin/staging` becomes `origin-staging`. This may produce less friendly names than branch-based worktrees, but is consistent with existing behaviour.
- If two detached worktrees at the same ref are needed, the second will collide on directory name. Callers should use `--from` with a distinguishing path, or rely on git itself to error.
- The `created` hook contract changes slightly for detached worktrees: `$2` (branch) carries a short SHA instead of a branch name. This is a documented extension, not a breaking change — existing hooks that only use `$1` (the path) are unaffected.

---

## Progress Tracking

**Status History:**
- 2026-02-21: Created (BMAD Method v6 - Phase 4)
- 2026-02-22: Formalized by Scrum Master

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
