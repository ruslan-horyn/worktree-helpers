# STORY-024: Fix race condition in concurrent worktree creation

**Epic:** Core Reliability
**Priority:** Must Have
**Story Points:** 3
**Status:** Completed
**Assigned To:** Developer
**Created:** 2026-02-12
**Sprint:** 4

---

## User Story

As a developer
I want to create two worktrees concurrently (`wt -n ... & wt -n -d ...`)
So that I can quickly set up both main and dev worktrees without waiting

---

## Description

### Background

Running two `wt -n` commands in parallel (e.g., with `&`) causes a race condition. Both commands call `_wt_create` which performs multiple writes to the shared `.git/config` file:

1. `git worktree add -b "$branch" ...` — writes to `.git/config`
2. `git -C "$wt_path" config "branch.$branch.remote" ...` — writes to `.git/config`
3. `git -C "$wt_path" config "branch.$branch.merge" ...` — writes to `.git/config`

Git uses a `.git/config.lock` file for atomic writes. When both processes try to write simultaneously, one fails with:

```
error: could not lock config file .git/config: File exists
error: unable to write upstream branch configuration
```

**Root cause:** `lib/worktree.sh:89-91` — no serialization around shared `.git/config` writes.

This is a real-world scenario: users commonly run `wt -n TICKET-123 & wt -n -d TICKET-123` to set up both main-based and dev-based worktrees in one go.

### Scope

**In scope:**
- Retry logic for `git config` writes that fail due to lock contention
- Bounded retry with exponential backoff to avoid infinite loops
- BATS test verifying concurrent worktree creation succeeds
- POSIX-compatible implementation

**Out of scope:**
- File-level locking / mutex between wt processes (too complex, git already handles locking)
- Changing `git worktree add` itself (that's git internals)
- Retry logic for `_wt_open` (uses `git worktree add` without `-b`, different config writes)

---

## User Flow

1. Developer wants to set up two worktrees for the same ticket
2. Developer runs: `wt -n CORE-654-trim-username & wt -n -d CORE-654-trim-username`
3. Both commands start in parallel
4. First process runs `git worktree add` and `git config` — succeeds
5. Second process runs `git worktree add` — succeeds (different worktree path/branch)
6. Second process runs `git config` — hits lock contention
7. Retry logic waits briefly and retries the config write
8. Second attempt succeeds (lock released by first process)
9. Both worktrees are created successfully

**Error case — persistent lock (e.g., stale lock file):**
1. All retry attempts exhausted
2. Final attempt runs with errors visible
3. User sees the git error message and can resolve manually

---

## Acceptance Criteria

- [ ] `wt -n <branch> & wt -n -d <branch>` both succeed without config lock errors
- [ ] Config retry logic handles transient lock contention (retry with backoff)
- [ ] Retry is bounded (max attempts) to avoid infinite loops
- [ ] Single `wt -n` invocations are not slowed down (no unnecessary delays)
- [ ] BATS test covers concurrent worktree creation scenario
- [ ] POSIX-compatible implementation (no bash-specific features)
- [ ] Retry helper function follows project conventions (`_` prefix, placed in appropriate module)
- [ ] Existing tests continue to pass (no regressions)

---

## Technical Notes

### Components

- **`lib/worktree.sh`**: Add `_git_config_retry` helper; update `_wt_create` to use it
- **`test/worktree.bats`** (or new test file): Add concurrent creation test

### Implementation Details

#### Retry helper (`lib/worktree.sh`)

Add a retry wrapper that catches lock contention failures and retries with exponential backoff:

```sh
# Retry a git command on lock contention (config.lock)
# Usage: _git_config_retry git -C "$path" config key value
_git_config_retry() {
  local max_attempts=5 attempt=0 delay=0
  while [ "$attempt" -lt "$max_attempts" ]; do
    if "$@" 2>/dev/null; then
      return 0
    fi
    attempt=$((attempt + 1))
    # Exponential backoff: 0.1, 0.2, 0.4, 0.8, 1.6 seconds
    delay=$(awk "BEGIN{printf \"%.1f\", 0.1 * (2 ^ ($attempt - 1))}")
    sleep "$delay"
  done
  # Final attempt — let error propagate to user
  "$@"
}
```

**Backoff schedule:** 0.1s → 0.2s → 0.4s → 0.8s → 1.6s (total max wait: ~3.1s)

#### Update `_wt_create` (`lib/worktree.sh:89-91`)

Replace direct `git config` calls with the retry wrapper:

```sh
_wt_create() {
  local branch="$1" ref="$2" dir="$3"
  local wt_path="$dir/$branch"
  [ -e "$wt_path" ] && { _err "Path exists: $wt_path"; return 1; }

  _info "Creating worktree '$branch' from '$ref'"
  git worktree add -b "$branch" "$wt_path" "$ref" || { _err "Failed"; return 1; }
  _git_config_retry git -C "$wt_path" config "branch.$branch.remote" "origin"
  _git_config_retry git -C "$wt_path" config "branch.$branch.merge" "refs/heads/$branch"
  _symlink_hooks "$wt_path"
  _fetch "$ref"
  _run_hook created "$wt_path" "$branch" "$ref" "$(_main_repo_root)"
  _wt_warn_count
}
```

#### Alternative: reduce config writes entirely

Consider whether `git worktree add --track -b "$branch" "$wt_path" "$ref"` can set upstream tracking in a single atomic operation, removing the need for the two separate `git config` calls. If so, the retry wrapper becomes a safety net rather than the primary fix.

Investigation needed: check if `--track` sets both `branch.<name>.remote` and `branch.<name>.merge` correctly for our use case where we want `origin` as remote and `refs/heads/$branch` as merge target.

#### BATS test for concurrent creation

```sh
@test "_wt_create: concurrent creation succeeds" {
  # Create two branches concurrently from the same ref
  run bash -c '
    source lib/worktree.sh
    _wt_create "branch-a" "main" "'$TEST_WORKTREES_DIR'" &
    _wt_create "branch-b" "main" "'$TEST_WORKTREES_DIR'" &
    wait
  '
  # Both worktrees should exist
  [ -d "$TEST_WORKTREES_DIR/branch-a" ]
  [ -d "$TEST_WORKTREES_DIR/branch-b" ]
}
```

Note: The exact test setup will depend on the existing BATS test helpers. The test must create a repo with commits so that `git worktree add` has something to branch from.

### Edge Cases

- **Stale `.git/config.lock`**: If a previous git process crashed and left a stale lock, retries will all fail. The final attempt will show the git error, which is the correct behavior — the user needs to manually remove the stale lock.
- **`awk` availability**: `awk` is required for the backoff calculation. It's a POSIX utility and available on all target platforms.
- **`sleep` with fractional seconds**: POSIX `sleep` supports integer seconds only. However, GNU coreutils and macOS both support fractional seconds. If strict POSIX is needed, round up to whole seconds (1s per retry). Given our target platforms (macOS + Linux), fractional sleep is safe.
- **`git worktree add` itself hitting the lock**: The `git worktree add` command also writes to `.git/config`. If this fails due to lock contention, the entire creation fails before reaching our config writes. Consider wrapping the full creation in a retry, or accept that this window is very small and unlikely.

### Security Considerations

- No new user input is introduced — the retry wrapper only re-runs the same git commands.
- The `2>/dev/null` on retry attempts suppresses transient errors, but the final attempt lets errors propagate.

---

## Dependencies

**Prerequisite Stories:**
- None (independent bug fix)

**Blocked Stories:**
- None

**External Dependencies:**
- None

---

## Definition of Done

- [ ] `_git_config_retry` helper implemented in `lib/worktree.sh`
- [ ] `_wt_create` updated to use retry wrapper for `git config` calls
- [ ] BATS test for concurrent worktree creation passes
- [ ] All existing tests pass (no regressions)
- [ ] Shellcheck passes
- [ ] CI passes
- [ ] Manual verification: `wt -n <branch> & wt -n -d <branch>` succeeds
- [ ] POSIX-compatible implementation (no bash-specific features)
- [ ] Code follows project conventions (`_` prefix, `GWT_*` globals)

---

## Story Points Breakdown

- **Retry helper function**: 1 point
- **Update `_wt_create`**: 0.5 points
- **BATS concurrent test**: 1 point
- **Edge case handling + manual testing**: 0.5 points
- **Total:** 3 points

**Rationale:** The core fix is straightforward (retry wrapper + 2 line changes in `_wt_create`). The complexity comes from the BATS test for concurrent execution (background processes, race condition timing) and ensuring the backoff logic is POSIX-compatible. Comparable to STORY-019 (--rename, 3pts) in scope.

---

## Additional Notes

- **Why retry instead of a mutex/lock file:** Git already uses `.git/config.lock` for serialization. Adding our own lock would duplicate this and create potential for deadlocks. Retrying is simpler, idempotent, and handles the transient nature of the contention.
- **`--track` investigation**: If `git worktree add --track` can replace the two `git config` calls, that's the cleaner fix. The retry wrapper should still be added as a safety net, but the primary fix would be reducing the number of config writes.
- **Impact on `_wt_open`**: The `_wt_open` function (line 98-117) uses `git worktree add` without `-b` and doesn't do manual config writes, so it's less susceptible to this race. However, if two `_wt_open` calls happen concurrently, git's own locking in `git worktree add` could still collide. This is out of scope for this story but worth noting for future work.

---

## Progress Tracking

**Status History:**
- 2026-02-12: Created
- 2026-02-13: Implemented and tested

**Actual Effort:** 3 points (matched estimate)

**Implementation Notes:**
- `--track` flag investigated but doesn't work: sets merge to base branch (main), not the new branch name
- `git worktree add -b` with config.lock creates the branch but not the directory; recovery uses `git worktree add` (without `-b`) for existing branches
- Retry with exponential backoff: 0.1s, 0.2s, 0.4s, 0.8s, 1.6s (max ~3.1s total wait)
- Both `git worktree add` and `git config` calls are protected against lock contention
- 4 new tests: 3 unit tests for `_git_config_retry` + 1 integration test for concurrent creation
- All 146 existing tests pass, shellcheck clean

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
