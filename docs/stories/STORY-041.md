# STORY-041: Repair corrupted worktree refs (`wt --repair`, `wt --prune`)

**Epic:** Core Reliability
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** Backlog

---

## User Story

As a developer who manually moved or deleted a worktree directory
I want `wt` to fix orphaned or corrupted `.git/worktrees` entries
So that `git worktree list` stays clean without manual intervention

---

## Description

### Background

When worktrees are managed outside of `wt` — via `rm -rf`, `mv`, or direct filesystem operations — git's internal `.git/worktrees/` registry can become stale. This produces phantom entries in `git worktree list` and potentially confusing errors. Two native git commands exist to recover from this, but users must know to run them directly. This story surfaces both as first-class `wt` flags.

### Scope

**In scope:**
- `wt --prune` — thin wrapper over `git worktree prune`, removes orphaned `.git/worktrees/` entries for worktree directories that no longer exist on disk
- `wt --prune --dry-run` — show what would be pruned without making changes (delegates to `git worktree prune --dry-run`)
- `wt --repair` — thin wrapper over `git worktree repair`, fixes broken `.git` file links in worktrees whose directories were moved manually
- `wt --repair [<path>]` — optionally repair a specific worktree path (delegates path arg to `git worktree repair`)
- Both commands must work whether invoked from the main repo or from within a worktree
- Per-command `--help` support (`wt --prune --help`, `wt --repair --help`)
- Both commands added to `_cmd_help` (the main help listing) and README

**Out of scope:**
- Interactive selection of which entries to prune (git does not expose this granularity)
- Repairing entries for worktrees not already registered (use `wt -o` for that)

### User Flow

**Prune flow (orphaned entry from accidental `rm -rf`):**

1. Developer accidentally runs `rm -rf ../my-project_worktrees/old-feature`
2. `git worktree list` still shows a stale entry for that path
3. Developer runs `wt --prune`
4. `git worktree prune` removes the orphaned `.git/worktrees/old-feature` entry
5. `wt --prune` reports what was cleaned (mirrors git output or confirms "nothing to prune")
6. `git worktree list` is clean

**Dry-run prune flow:**

1. Developer runs `wt --prune --dry-run`
2. Output shows what entries would be pruned without touching anything
3. Developer can inspect before committing to the action

**Repair flow (worktree moved with `mv`):**

1. Developer runs `mv ../my-project_worktrees/feature-x ../other/feature-x`
2. The `.git` file inside the moved directory now has a broken backlink to `.git/worktrees/feature-x`
3. Developer runs `wt --repair ../other/feature-x` (or `wt --repair` to fix all broken links)
4. `git worktree repair` updates the `.git` file in the worktree directory
5. `wt --repair` reports the result

---

## Acceptance Criteria

- [ ] `wt --prune` runs `git worktree prune` and reports what was cleaned (passes through git output)
- [ ] `wt --prune --dry-run` shows what would be pruned without modifying any state
- [ ] `wt --repair` runs `git worktree repair` with no path argument (repairs all detectable broken links)
- [ ] `wt --repair [<path>]` passes the optional path argument through to `git worktree repair`
- [ ] Both commands work when invoked from the main repo root
- [ ] Both commands work when invoked from within a worktree directory
- [ ] Clear output messages on success; git's own error text is passed through on failure
- [ ] Exit code from the underlying git command is propagated (non-zero on failure)
- [ ] `wt --prune --help` and `wt --repair --help` print per-command help text
- [ ] Both commands appear in the main `wt --help` / `_cmd_help` listing
- [ ] README updated with 1–3 lines describing `--prune` and `--repair`

---

## Technical Notes

### Components

- **`lib/commands.sh`** — add `_cmd_prune` and `_cmd_repair` handler functions, and `_help_prune` / `_help_repair` help functions; update `_cmd_help` listing
- **`wt.sh`** — add `--prune` and `--repair` to the flag router (`wt()`) including `--help` dispatch; `--repair` must capture the optional path argument
- **`test/cmd_repair.bats`** — new BATS test file (consistent with per-command test file convention)
- **`README.md`** — add entries under the Commands section

### Implementation

Both commands are intentionally thin wrappers. The implementation should follow the same pattern as `_cmd_lock` / `_cmd_unlock`:

```sh
_cmd_prune() {
  local dry_run="$1"
  _repo_root >/dev/null || return 1
  if [ "$dry_run" -eq 1 ]; then
    git worktree prune --dry-run
  else
    git worktree prune
  fi
}

_cmd_repair() {
  local path="$1"
  _repo_root >/dev/null || return 1
  if [ -n "$path" ]; then
    git worktree repair "$path"
  else
    git worktree repair
  fi
}
```

Router additions in `wt()`:

```sh
--prune)   action="prune"; shift ;;
--repair)  action="repair"; shift
           case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
```

Dispatch additions in the `case "${action:-help}"` block:

```sh
prune)  if [ "$help" -eq 1 ]; then _help_prune; return 0; fi
        _cmd_prune "$dry_run" ;;
repair) if [ "$help" -eq 1 ]; then _help_repair; return 0; fi
        _cmd_repair "$arg" ;;
```

### Edge Cases

- Running `wt --prune` when there is nothing to prune: git outputs nothing or a summary; either is acceptable — no extra wrapping needed
- Running `wt --repair` when all links are intact: git exits 0 silently; that is the correct behaviour
- Running `wt --repair <path>` with a non-existent path: git returns a non-zero exit; propagate it
- The `--dry-run` flag is already parsed in the router — reuse it for `--prune --dry-run` without adding new parser state

### POSIX Compatibility

Both commands call git directly with no shell-specific syntax. The optional path argument for `--repair` uses the same `case "${1:-}" in -*|"") ;; *) ...` pattern already used by `--new`, `--switch`, `--log`, and `--repair` in the existing router.

---

## Dependencies

- None (thin wrappers over native git commands; requires git ≥ 2.17 which introduced `git worktree repair`)

---

## Definition of Done

- [ ] `_cmd_prune` and `_cmd_repair` implemented in `lib/commands.sh`
- [ ] `_help_prune` and `_help_repair` added to `lib/commands.sh`
- [ ] `_cmd_help` listing updated with `--prune` and `--repair` entries
- [ ] `--prune` and `--repair` routing added to `wt()` in `wt.sh`
- [ ] `test/cmd_repair.bats` written with tests covering:
  - `wt --prune` succeeds and passes through git output
  - `wt --prune --dry-run` runs without modifying state
  - `wt --repair` succeeds with no path arg
  - `wt --repair <path>` succeeds with a valid path
  - Exit code propagation on failure
- [ ] All existing tests still pass (`npm test`)
- [ ] README updated (1–3 lines under Commands section)
- [ ] Acceptance criteria above all checked

---

## Story Points Breakdown

- **Command handlers (`_cmd_prune`, `_cmd_repair`):** 0.5 points — trivial delegation
- **Router wiring + help functions + `_cmd_help` update:** 0.5 points
- **Tests (`test/cmd_repair.bats`):** 0.5 points
- **README update:** 0.5 points
- **Total:** 2 points

**Rationale:** Both commands are pure pass-throughs to git with no business logic. The work is almost entirely boilerplate wiring matching existing command patterns. 2 points accounts for the test scaffolding and ensuring the `--dry-run` flag reuse works correctly.

---

## Additional Notes

- `git worktree repair` was added in git 2.17 (April 2018). This is a safe baseline for the project — no minimum version guard is needed.
- The `--dry-run` flag is already parsed by the router and passed as a variable; `_cmd_prune` just needs to receive it. No new parser state required.
- Consider adding a note in the help text pointing users toward `wt --prune` when they see ghost entries in `wt -l`.

---

## Progress Tracking

**Status History:**
- 2026-02-21: Draft created
- 2026-02-22: Formalized by Scrum Master (BMAD Method v6)

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
