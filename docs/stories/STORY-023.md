# STORY-023: Add `--from`/`-b` flag to `wt -n` for custom base branch

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Done
**Assigned To:** Unassigned
**Created:** 2026-02-10
**Sprint:** 4

---

## User Story

As a developer
I want to create a new worktree from any branch (not just main or dev)
So that I can branch off feature branches, release branches, or specific commits without manual git commands

---

## Description

### Background

Currently, `wt -n <branch>` always creates from the configured main branch (`GWT_MAIN_REF`), and `wt -n -d <branch>` creates from the dev branch (`GWT_DEV_REF`). There is no way to specify an arbitrary base branch.

This is limiting when:

- Branching off an existing feature branch (e.g., `feature/auth` → `feature/auth-fix`)
- Creating a hotfix from a release branch (e.g., `release/2.0` → `hotfix/2.0.1`)
- Starting work from a specific tag or commit

The `--from <ref>` flag (short: `-b <ref>`) allows the user to override the base branch for worktree creation.

### Scope

**In scope:**

- `wt -n <branch> --from <ref>` creates a new worktree branching from `<ref>`
- `wt -n <branch> -b <ref>` short form
- `--from` accepts any valid git ref: branch name, tag, commit SHA, `origin/branch`
- Fetches the ref before creating (same behavior as existing `_wt_create`)
- `--from` is mutually exclusive with `-d`/`--dev`
- Help text and error messages updated

**Out of scope:**

- Changing the default base branch behavior (still uses `GWT_MAIN_REF`)
- Tab completion for `--from` refs (STORY-014 covers completions)
- Using `--from` with `wt -o` (open uses existing branches, not creation)

---

## User Flow

1. Developer wants to create a hotfix branch from a release branch
2. Developer runs `wt -n hotfix/2.0.1 --from release/2.0`
3. Tool validates `hotfix/2.0.1` doesn't already exist
4. Tool validates `release/2.0` is a valid ref (local or remote)
5. Tool fetches the ref to ensure it's up to date
6. Tool creates worktree: `git worktree add -b hotfix/2.0.1 <worktrees-dir>/hotfix/2.0.1 release/2.0`
7. Tool configures remote tracking and symlinks hooks (existing behavior)
8. Tool runs the created hook
9. Output:

   ```
   Creating worktree 'hotfix/2.0.1' from 'release/2.0'
   ```

**With short flag:** `wt -n hotfix/2.0.1 -b release/2.0` — same behavior.

**Error case — conflicting flags:** `wt -n branch -d --from release/2.0`

```
Error: --from and --dev are mutually exclusive
```

---

## Acceptance Criteria

- [x] `wt -n <branch> --from <ref>` creates worktree from the specified ref
- [x] `wt -n <branch> -b <ref>` works as short form of `--from`
- [x] `--from` accepts local branches, remote branches (e.g., `origin/release`), tags, and commit SHAs
- [x] `--from` is mutually exclusive with `-d`/`--dev` — error if both specified
- [x] Error message if `--from` ref does not exist (checked after fetch)
- [x] Without `--from`, behavior unchanged — still uses `GWT_MAIN_REF`
- [x] With `-d` (no `--from`), behavior unchanged — still uses `GWT_DEV_REF`
- [x] Help text updated to show `--from`/`-b` flag
- [x] BATS tests cover: basic usage, short flag, invalid ref, conflict with `-d`
- [x] Works in both zsh and bash
- [x] POSIX-compatible implementation (no bash-specific features)

---

## Technical Notes

### Components

- **`wt.sh`**: Router update — add `--from`/`-b` flag parsing, pass `from_ref` to `_cmd_new`
- **`lib/commands.sh`**: Update `_cmd_new` to accept and use custom base ref
- **`lib/commands.sh`**: Update `_cmd_help` with `--from`/`-b` documentation

### Implementation Details

#### Router changes (`wt.sh`)

Add a new variable and flag parsing:

```sh
local from_ref=""
```

In the `while` loop:

```sh
-b|--from) shift; from_ref="$1"; shift ;;
```

Update the dispatch:

```sh
new) if [ "$dev" -eq 1 ]; then _cmd_dev "$arg"; else _cmd_new "$arg" "$from_ref"; fi ;;
```

#### Command handler changes (`lib/commands.sh`)

Update `_cmd_new` to accept a second parameter:

```sh
_cmd_new() {
  local branch="$1" from_ref="$2"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" || return 1
  [ -z "$branch" ] && { _err "Usage: wt -n <branch> [--from <ref>]"; return 1; }
  _branch_exists "$branch" && { _err "Branch exists"; return 1; }

  local base_ref="${from_ref:-$GWT_MAIN_REF}"
  _wt_create "$branch" "$base_ref" "$GWT_WORKTREES_DIR"
}
```

#### Mutual exclusivity check (in router)

Before dispatching, validate that `--from` and `-d` are not both set:

```sh
new)
  if [ "$dev" -eq 1 ] && [ -n "$from_ref" ]; then
    _err "--from and --dev are mutually exclusive"; return 1
  fi
  if [ "$dev" -eq 1 ]; then _cmd_dev "$arg"
  else _cmd_new "$arg" "$from_ref"; fi
  ;;
```

#### Help text update (`_cmd_help`)

Update the Commands section:

```
  -n, --new <branch>     Create worktree from main (or --from ref)
```

Add to Flags section:

```
  -b, --from <ref>       Base branch/ref for -n (default: main branch)
```

### Edge Cases

- **Remote-only ref** (e.g., `origin/release/2.0`): `_wt_create` already passes the ref directly to `git worktree add`, which handles remote refs natively.
- **Tag or SHA**: Git worktree add with `-b` supports creating a branch from any commit-ish, so tags and SHAs work out of the box.
- **Invalid ref**: `git worktree add` will fail with a clear error, and `_wt_create` already handles this with `|| { _err "Failed"; return 1; }`.
- **`--from` without `-n`**: The `from_ref` variable is only used in the `new` action dispatch — if the user provides `--from` with another command (e.g., `wt -l --from main`), it's harmlessly ignored.

### Security Considerations

- The ref string is passed directly to `git worktree add`, which validates it. No shell injection risk as the value is always quoted.
- No user input is passed to `eval` or unquoted expansion.

---

## Dependencies

**Prerequisite Stories:**

- None (independent feature)

**Blocked Stories:**

- None

**External Dependencies:**

- None (uses existing git worktree capabilities)

---

## Definition of Done

- [x] `_cmd_new` updated to accept optional `from_ref` parameter
- [x] Router updated in `wt.sh` to parse `--from`/`-b` flag
- [x] Mutual exclusivity check for `--from` and `--dev`
- [x] Help text updated in `_cmd_help`
- [x] BATS tests written and passing:
  - [x] Create worktree with `--from <branch>`
  - [x] Create worktree with `-b <branch>` (short form)
  - [x] Error when `--from` and `-d` used together
  - [x] Error when `--from` ref is invalid
  - [x] Default behavior unchanged (no `--from` → uses main branch)
- [x] Shellcheck passes
- [x] CI passes
- [x] Works in both zsh and bash
- [x] Works on both macOS and Linux
- [x] No regressions in existing `wt -n` and `wt -n -d` functionality
- [x] Code follows existing patterns (`_` prefix, `GWT_*` globals, POSIX-compatible)

---

## Story Points Breakdown

- **Router + flag parsing**: 0.5 points
- **`_cmd_new` update**: 0.5 points
- **Tests**: 0.5 points
- **Edge cases + help text**: 0.5 points
- **Total:** 2 points

**Rationale:** The 2-point estimate reflects low complexity. The core change is minimal — adding a flag to the router and passing an optional parameter to `_cmd_new`. Most of the existing `_wt_create` logic handles the ref transparently. The mutual exclusivity check and tests add a small amount of effort. Comparable to STORY-012 (--version, 1pt) plus testing overhead.

---

## Additional Notes

- **Flag naming**: `--from` was chosen to be descriptive ("create from this ref"). `-b` is the short form, matching `git checkout -b` and `git switch -c` convention of specifying the starting point.
- **No validation of ref beforehand**: We rely on `git worktree add` to validate the ref. This keeps the implementation simple and avoids duplicating git's ref resolution logic. The `_fetch` call in `_wt_create` ensures remote refs are available.
- **Future enhancement**: If STORY-014 (completions) ships, the completion script should offer branch/tag names for the `--from` argument.

---

## Progress Tracking

**Status History:**

- 2026-02-10: Created

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
