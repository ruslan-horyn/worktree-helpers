# STORY-031: Replace slashes with dashes in worktree directory names

**Epic:** Core Reliability
**Priority:** Must Have
**Story Points:** 2
**Status:** In Progress
**Assigned To:** Unassigned
**Created:** 2026-02-19
**Sprint:** 6

---

## User Story

As a developer working with Jira-style branch names like `bugfix/CORE-615-foo`
I want `wt -n bugfix/CORE-615-foo` to create a flat directory `bugfix-CORE-615-foo`
So that worktrees don't accidentally create nested subdirectories inside `worktreesDir`

---

## Description

### Background

Branch names containing slashes are common in team workflows — Jira prefixes
(`bugfix/CORE-615-foo`), GitHub Flow prefixes (`feature/my-feature`), and
release branches (`release/1.4.0`) are standard conventions. Git itself handles
slash-named branches without creating nested directories because it stores branch
refs in `.git/refs/heads/`, but `git worktree add <path>` uses the literal path
string provided to it.

When `_wt_create` constructs `wt_path` as `"$dir/$branch"`, a branch name like
`bugfix/CORE-615-foo` expands to `<worktreesDir>/bugfix/CORE-615-foo`, causing
git to silently create a nested directory structure:

```
worktrees/
  bugfix/
    CORE-615-foo/   ← unintended subdirectory
```

The intended layout is flat:

```
worktrees/
  bugfix-CORE-615-foo/   ← correct
```

This same issue affects `_wt_open`, which builds an identical `wt_path` using
`"$dir/$branch"` on line 150 of `lib/worktree.sh`.

This is a real-world regression reported from daily use with Jira ticket branches.
It also silently breaks `wt -l` output and `wt -r` / `wt -s` resolution because
the directory path no longer corresponds to what a user would type.

### Scope

**In scope:**

- A POSIX-compatible `_wt_dir_name` helper that sanitises slashes to dashes
- Apply sanitisation in `_wt_create` when constructing `wt_path`
- Apply sanitisation in `_wt_open` when constructing `wt_path`
- BATS tests covering the slash-to-dash mapping for both `-n` and `-o` paths

**Out of scope:**

- Sanitising other special characters (spaces, colons, etc.) — addressed if needed in a follow-up
- Changing the displayed branch name (the git branch itself keeps its original name with slashes)
- Modifying `wt -r` / `wt -s` resolution logic — these operate on `_wt_path`/`_wt_branch` which read git's porcelain output and are unaffected by this change

### User Flow

1. Developer runs `wt -n bugfix/CORE-615-foo`
2. `wt` derives the directory name by replacing `/` with `-`: `bugfix-CORE-615-foo`
3. Git worktree is created at `<worktreesDir>/bugfix-CORE-615-foo` with branch `bugfix/CORE-615-foo`
4. `wt -l` shows the flat directory path, with the correct branch name alongside it
5. Developer runs `wt -o feature/my-feature` for an existing remote branch
6. `wt` derives the directory `feature-my-feature` and creates the worktree there

---

## Scope

**In scope:**

- `_wt_dir_name` helper in `lib/worktree.sh`
- Patch `_wt_create` (line ~102): `local wt_path="$dir/$branch"` → `local wt_path="$dir/$(_wt_dir_name "$branch")"`
- Patch `_wt_open` (line ~150): same substitution
- BATS tests in `test/worktree.bats` for the helper and integration

**Out of scope:**

- Sanitising other characters beyond `/`
- `_cmd_rename` — renames use `git worktree move` with an explicit new path; caller controls the name

---

## Acceptance Criteria

- [ ] `wt -n bugfix/CORE-615-foo` creates directory `<worktreesDir>/bugfix-CORE-615-foo`
- [ ] `wt -n feature/my-feature` creates directory `<worktreesDir>/feature-my-feature`
- [ ] No subdirectory is created inside `worktreesDir`
- [ ] The git branch name is preserved exactly as `bugfix/CORE-615-foo` — only the **directory name** uses dashes
- [ ] `wt -o <branch>` with a slash-containing branch name also uses the dash form for the directory path
- [ ] Multiple consecutive slashes are each individually replaced (e.g. `a//b` → `a--b`)
- [ ] Existing BATS tests continue to pass
- [ ] New BATS tests cover: `_wt_dir_name` unit tests, `wt -n` with slash branch, `wt -o` with slash branch
- [ ] `shellcheck` passes on all modified files

---

## Technical Notes

### Components

- **`lib/worktree.sh`** — primary change site; contains `_wt_create` and `_wt_open`
- **`test/worktree.bats`** — BATS tests for worktree helpers

### Implementation

Add a new POSIX-compatible helper near the top of `lib/worktree.sh`:

```sh
# Sanitise a branch name for use as a filesystem directory name.
# Replaces every '/' with '-'.
_wt_dir_name() {
  printf '%s' "$1" | tr '/' '-'
}
```

Patch `_wt_create` (currently line 102):

```sh
# Before:
local wt_path="$dir/$branch"

# After:
local wt_path="$dir/$(_wt_dir_name "$branch")"
```

Patch `_wt_open` (currently line 150):

```sh
# Before:
local wt_path="$dir/$branch"

# After:
local wt_path="$dir/$(_wt_dir_name "$branch")"
```

### Key Invariant

The sanitisation must only apply to the **filesystem path**. The `branch` variable
itself must be passed unchanged to `git worktree add`, `git branch`, and all hook
invocations. Example from `_wt_create`:

```sh
git worktree add -b "$branch" "$wt_path" "$ref"   # branch unchanged, wt_path sanitised
```

### Edge Cases

- Branch with no slashes: `tr '/' '-'` is a no-op — existing behaviour unchanged
- Multiple slashes: `a//b` → `a--b` (acceptable; rare in practice)
- Branch already exists check in `_cmd_new` uses the original branch name — unaffected

### Files to Modify

| File | Change |
|------|--------|
| `lib/worktree.sh` | Add `_wt_dir_name`, patch `_wt_create` and `_wt_open` |
| `test/worktree.bats` | Add unit tests for `_wt_dir_name` and integration tests |

---

## Dependencies

- None — this story is fully independent

---

## Definition of Done

- [ ] `_wt_dir_name` (or equivalent inline `tr`) sanitises slashes to dashes
- [ ] Sanitisation applied consistently in both `_wt_create` and `_wt_open`
- [ ] Branch name passed unchanged to all git commands and hook invocations
- [ ] BATS tests added:
  - [ ] `_wt_dir_name "bugfix/CORE-615-foo"` → `bugfix-CORE-615-foo`
  - [ ] `_wt_dir_name "feature/my-feature"` → `feature-my-feature`
  - [ ] `_wt_dir_name "no-slash"` → `no-slash` (identity)
  - [ ] `wt -n` with slash branch creates flat directory, correct git branch
  - [ ] `wt -o` with slash branch creates flat directory
- [ ] All existing BATS tests pass
- [ ] `shellcheck` passes on `lib/worktree.sh`
- [ ] Manually tested: `wt -n bugfix/CORE-615-foo` creates flat directory
- [ ] No regressions in `wt -l`, `wt -s`, `wt -r` for non-slash branches

---

## Story Points Breakdown

- **`_wt_dir_name` helper + two-line patch:** 0.5 points
- **BATS tests (unit + integration):** 1 point
- **Manual verification + shellcheck:** 0.5 points
- **Total:** 2 points

**Rationale:** The code change is tiny (one helper, two one-line patches). Most
of the effort is in writing and verifying the BATS integration tests that create
actual git repos with slash-named branches.

---

## Additional Notes

- This bug was discovered during real-world usage with Jira-prefixed branches and
  is referenced in `MEMORY.md` under "Branch naming" as a known footgun.
- The `_cmd_rename` command builds `new_path` from `parent_dir/$new_branch` — if
  the user renames to a slash-containing name, the same problem would occur. That
  case is out of scope here but noted for a follow-up.
- `tr '/' '-'` is universally available on macOS (BSD) and Linux (GNU) and is
  fully POSIX-compliant, matching the project's shell compatibility requirement.

---

## Progress Tracking

**Status History:**

- 2026-02-19: Created and enhanced by Scrum Master
- 2026-02-19: Implementation complete by Developer

**Actual Effort:** 2 points (matched estimate)

**Files Changed:**

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/worktree.sh` | modified | Added `_wt_dir_name` helper; patched `_wt_create` and `_wt_open` to use it |
| `test/worktree.bats` | modified | Added 9 new BATS tests (unit + integration) for STORY-031 |
| `test/cmd_new.bats` | modified | Updated pre-existing test that asserted old buggy nested-dir behavior |

**Tests Added (test/worktree.bats):**
- `_wt_dir_name replaces slash with dash`
- `_wt_dir_name replaces slash in feature prefix`
- `_wt_dir_name is identity for branch with no slash`
- `_wt_dir_name replaces multiple consecutive slashes individually`
- `_wt_create creates flat directory for slash branch name`
- `_wt_create preserves git branch name with slash`
- `_wt_open creates flat directory for slash branch name`

**Test Results:** 255/255 passing, 0 failures

**Decisions Made:**
- Used `local wt_path; wt_path="$dir/$(_wt_dir_name "$branch")"` (separate declare/assign) to satisfy shellcheck SC2155
- Updated `test/cmd_new.bats` test 51 which was asserting the old buggy nested-directory path `feature/child` — updated to assert flat `feature-child` path
- `_wt_dir_name` placed at the top of `lib/worktree.sh` before other helpers for easy discoverability

**Acceptance Criteria Checklist:**
- [x] `wt -n bugfix/CORE-615-foo` creates directory `<worktreesDir>/bugfix-CORE-615-foo`
- [x] `wt -n feature/my-feature` creates directory `<worktreesDir>/feature-my-feature`
- [x] No subdirectory is created inside `worktreesDir`
- [x] The git branch name is preserved exactly as `bugfix/CORE-615-foo` — only the directory name uses dashes
- [x] `wt -o <branch>` with a slash-containing branch name also uses the dash form for the directory path
- [x] Multiple consecutive slashes are each individually replaced (e.g. `a//b` → `a--b`)
- [x] Existing BATS tests continue to pass (255/255)
- [x] New BATS tests cover: `_wt_dir_name` unit tests, `wt -n` with slash branch, `wt -o` with slash branch
- [x] `shellcheck` passes on all modified files

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## QA Review

### Files Reviewed
| File | Status | Notes |
|------|--------|-------|
| `lib/worktree.sh` | Pass | `_wt_dir_name` added at top of file; `_wt_create` and `_wt_open` both patched using separate declare/assign to satisfy SC2155; `branch` variable passed unchanged to all git commands and hooks |
| `test/worktree.bats` | Pass | 7 new STORY-031 tests added (4 unit for `_wt_dir_name`, 2 integration for `_wt_create`, 1 integration for `_wt_open`); all POSIX-compatible assertions |
| `test/cmd_new.bats` | Pass | Test 51 updated to assert flat `feature-child` directory instead of old nested `feature/child` path; both branch preservation and flat directory verified |

### Issues Found
None

### AC Verification
- [x] AC 1 — `wt -n bugfix/CORE-615-foo` creates directory `<worktreesDir>/bugfix-CORE-615-foo` — verified: `lib/worktree.sh` line 108, test: `_wt_create creates flat directory for slash branch name` (test 253)
- [x] AC 2 — `wt -n feature/my-feature` creates directory `<worktreesDir>/feature-my-feature` — verified: `lib/worktree.sh` line 108, test: `_wt_create preserves git branch name with slash` (test 254)
- [x] AC 3 — No subdirectory created inside `worktreesDir` — verified: tests 253 and 255 assert `[ ! -d "$GWT_WORKTREES_DIR/bugfix" ]`
- [x] AC 4 — Git branch name preserved exactly with slashes — verified: `lib/worktree.sh` lines 117-120 pass `$branch` unchanged to `git worktree add`; test: `_wt_create preserves git branch name with slash` (test 254)
- [x] AC 5 — `wt -o <branch>` with slash branch uses dash form for directory — verified: `lib/worktree.sh` line 156, test: `_wt_open creates flat directory for slash branch name` (test 255)
- [x] AC 6 — Multiple consecutive slashes each replaced (`a//b` → `a--b`) — verified: `_wt_dir_name` uses `tr '/' '-'` which replaces each `/` individually; test: `_wt_dir_name replaces multiple consecutive slashes individually` (test 252)
- [x] AC 7 — Existing BATS tests continue to pass — verified: 255/255 passing, 0 failures
- [x] AC 8 — New BATS tests cover `_wt_dir_name` unit tests, `wt -n` with slash branch, `wt -o` with slash branch — verified: tests 249-255 in `test/worktree.bats`
- [x] AC 9 — `shellcheck` passes on all modified files — verified: `shellcheck -x wt.sh lib/*.sh` produces no output

### Test Results
- Total: 255 / Passed: 255 / Failed: 0

### Shellcheck
- Clean: yes

---

## Manual Testing

### Test Scenarios

| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | `wt -n bugfix/CORE-615-foo` in a fresh clone | Creates `<worktreesDir>/bugfix-CORE-615-foo`; git branch listed as `bugfix/CORE-615-foo` | Directory `bugfix-CORE-615-foo` created; `git worktree list` shows `[bugfix/CORE-615-foo]`; no `bugfix/` subdirectory | Pass |
| 2 | `wt -n feature/my-feature` | Creates `<worktreesDir>/feature-my-feature`; git branch listed as `feature/my-feature` | Directory `feature-my-feature` created; `git worktree list` shows `[feature/my-feature]` | Pass |
| 3 | `wt -n no-slash-branch` (no slash in name) | Directory name unchanged: `<worktreesDir>/no-slash-branch` | Directory `no-slash-branch` created as expected; identical to pre-fix behavior | Pass |
| 4 | `wt -o release/1.4.0` (existing remote slash branch) | Creates `<worktreesDir>/release-1.4.0`; git branch listed as `release/1.4.0`; no `release/` subdirectory | Directory `release-1.4.0` created; `git worktree list` shows `[release/1.4.0]`; `ls` confirms no nested `release/` dir | Pass |
| 5 | `_wt_dir_name 'a//b'` (multiple consecutive slashes) | Returns `a--b` | Output `a--b` confirmed | Pass |
| 6 | `wt -l` with slash-branch worktrees open | Shows flat directory path alongside original slash branch name | All worktrees shown with flat paths (e.g., `bugfix-CORE-615-foo`) and correct branch names (e.g., `bugfix/CORE-615-foo`) | Pass |
| 7 | `wt -r no-slash-branch -f` (non-slash branch remove, regression check) | Worktree and branch removed cleanly; no regression | Branch deleted; directory removed; exit 0 | Pass |
| 8 | Git branch list after slash-branch worktrees created | Git stores branches with original slash names (`bugfix/CORE-615-foo`, `feature/my-feature`, `release/1.4.0`) | `git branch` output confirms all three slash-named branches intact | Pass |

### Issues Found

None
