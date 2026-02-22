# STORY-046: Code refactoring — SOLID, DRY, KISS, one file per command

**Epic:** Technical Debt
**Priority:** Should Have
**Story Points:** 8
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** Backlog

---

## User Story

As a developer maintaining and extending the `wt` codebase
I want the code organized with one file per command and no duplicated logic
So that each module is independently understandable, testable, and editable without triggering side effects in unrelated commands

---

## Description

### Background

The codebase has grown organically across six sprints. `lib/commands.sh` now contains 17+ functions — every `_cmd_*` handler plus all `_help_*` functions — totalling ~870 lines. `lib/worktree.sh` hosts both core worktree primitives and fzf selection logic. As STORY-040 through STORY-045 land, this will grow further.

Several DRY violations have accumulated:

- **Worktree path resolution** — the `_wt_resolve` call pattern (resolve input → fzf fallback → error) is copy-pasted into `_cmd_switch`, `_cmd_remove`, `_cmd_lock`, `_cmd_unlock`.
- **Confirmation prompt** — the `printf "... [y/N] " && read -r r && case "$r"` pattern appears in both `_cmd_remove` and `_cmd_rename`; a similar pattern lives inside `_cmd_clear`.
- **Force-flag check** — `if [ "$force" -ne 1 ]` before the confirmation prompt is repeated.
- **Protected branch check** — `_is_protected_branch` is defined in `utils.sh` and called only from `_cmd_clear`, but `_cmd_remove` does not use it (inconsistency).
- **Age/timestamp helpers** — `_wt_age` and `_calc_cutoff` are defined in `utils.sh` and called from `_cmd_clear`; no duplication yet, but the ownership is unclear now.

Beyond DRY, there is no single-responsibility separation: a developer fixing `wt -r` must open and scroll through a 870-line file that also contains `wt --init`, `wt --log`, `wt -c`, and every help function.

This story performs a structural-only refactor with no behavior changes.

### Scope

**In scope:**
- Restructure `lib/` into `lib/core/` (shared primitives) and `lib/cmd/` (one file per command)
- Extract and deduplicate the confirmation-prompt and force-flag-check pattern into a shared helper
- Ensure `_is_protected_branch` is used consistently in both `_cmd_clear` and `_cmd_remove`
- Update `wt.sh` to source the new file layout
- All existing BATS tests must pass unchanged

**Out of scope:**
- Any behavior changes, new features, or flag additions
- Changes to `wt.sh` router logic beyond the `source` lines
- Documentation changes beyond inline comments for contributors
- Performance optimizations

### Target File Structure

```
lib/
  core/
    utils.sh       # _err, _info, _debug, _require, colors, display helpers,
                   # _calc_cutoff, _wt_age, _age_display, _wt_count,
                   # _wt_is_dirty, _wt_warn_count, _read_input, _wt_display_name
    config.sh      # _config_load, GWT_* globals
    git.sh         # _repo_root, _main_repo_root, _branch_exists, _current_branch,
                   # _main_branch, _normalize_ref, _project_name, _fetch
    worktree.sh    # _wt_create, _wt_open, _wt_resolve, _wt_select, _branch_select,
                   # _wt_path, _wt_branch, _wt_dir_name, _symlink_hooks,
                   # _run_hook, _git_config_retry
    protect.sh     # _is_protected_branch (shared by clear + remove)
    update.sh      # (moved from lib/update.sh)
  cmd/
    new.sh         # _cmd_new, _cmd_dev, _help_new
    switch.sh      # _cmd_switch, _help_switch
    open.sh        # _cmd_open, _help_open
    remove.sh      # _cmd_remove, _help_remove
    list.sh        # _cmd_list, _help_list
    clear.sh       # _cmd_clear, _help_clear
    init.sh        # _cmd_init, _backup_hook, _help_init
    rename.sh      # _cmd_rename
    log.sh         # _cmd_log
    lock.sh        # _cmd_lock, _cmd_unlock
    update.sh      # _cmd_update, _help_update
    uninstall.sh   # _cmd_uninstall
    version.sh     # _cmd_version
    help.sh        # _cmd_help
```

### User Flow

This is a pure developer-facing refactor. There is no end-user flow change. The developer experience improvement is:

1. Developer wants to change `wt -r` behavior — opens `lib/cmd/remove.sh` (~50 lines), not a 870-line monolith.
2. Developer wants to add a new command — creates `lib/cmd/mycommand.sh`, adds one `source` line to `wt.sh`, adds the action to the router `case` statement.
3. Developer runs `npm test` — all existing tests pass because function names and behavior are unchanged.

---

## Acceptance Criteria

- [ ] `lib/` is restructured into `lib/core/` and `lib/cmd/` matching the target file structure above
- [ ] `wt.sh` sources all files via an explicit ordered list (core files first, then cmd files); no logic changes to the router
- [ ] All existing project BATS tests pass unchanged (`test/cmd_*.bats`, `test/worktree.bats`, `test/utils.bats`, `test/config.bats`, etc.)
- [ ] `shellcheck` passes on all files under `lib/` and `wt.sh` (CI gate must stay green)
- [ ] No function definition appears in more than one file (DRY: zero duplication)
- [ ] A shared `_confirm` helper (or equivalent) replaces the repeated confirmation-prompt pattern in `remove.sh`, `rename.sh`, and `clear.sh`
- [ ] `_is_protected_branch` is called consistently in both `_cmd_remove` and `_cmd_clear`
- [ ] Each `lib/cmd/*.sh` file contains only its own `_cmd_*` and `_help_*` function(s) plus any private sub-functions with a matching prefix
- [ ] Functions longer than 40 lines are broken into named sub-functions (applies to `_cmd_clear` which is ~310 lines)
- [ ] Inline comments at the top of each `lib/core/*.sh` file list the functions it exports (one line per function, `# _fn_name — brief description`)
- [ ] No behavior changes — the refactor is validated purely by the test suite passing

---

## Technical Notes

### Files Affected

| File | Action |
|---|---|
| `lib/utils.sh` | Split: move git helpers to `lib/core/git.sh`, keep utilities in `lib/core/utils.sh` |
| `lib/config.sh` | Move to `lib/core/config.sh` (no changes to content) |
| `lib/worktree.sh` | Split: core ops stay in `lib/core/worktree.sh`, command-specific fzf helpers stay there too |
| `lib/commands.sh` | Dissolved: each `_cmd_*` + `_help_*` pair moves to its own `lib/cmd/*.sh` |
| `lib/update.sh` | Move to `lib/core/update.sh` (no changes to content) |
| `wt.sh` | Replace five `source` lines with ~20 ordered `source` lines |

### DRY Violations to Fix

**Confirmation prompt pattern** (appears in `_cmd_remove` and `_cmd_rename`):

```sh
# Candidate shared helper to extract into lib/core/utils.sh or a new lib/core/prompt.sh
_confirm() {
  local msg="$1" force="${2:-0}"
  [ "$force" -eq 1 ] && return 0
  printf "%s [y/N] " "$msg" >&2
  read -r _confirm_r
  case "$_confirm_r" in y|Y) return 0 ;; *) return 1 ;; esac
}
```

**Protected branch inconsistency**: `_cmd_remove` checks for protected branches via an ad-hoc test on `GWT_MAIN_REF` but does not call `_is_protected_branch`. After the refactor both `_cmd_remove` and `_cmd_clear` must call `_is_protected_branch` from `lib/core/protect.sh`.

### `_cmd_clear` Decomposition

`_cmd_clear` is ~310 lines and violates single responsibility. Suggested sub-functions:

- `_clear_parse_args` — validate days/merged/pattern arguments
- `_clear_collect_worktrees` — iterate `git worktree list --porcelain`, return `to_delete` / `locked_skipped` / `protected_skipped`
- `_clear_print_plan` — display dry-run or confirmation listing
- `_clear_execute` — loop over `to_delete` and remove each worktree

### Source Order in `wt.sh`

Core files must be sourced before cmd files because cmd files call core functions:

```sh
source "$_WT_DIR/lib/core/utils.sh"
source "$_WT_DIR/lib/core/git.sh"
source "$_WT_DIR/lib/core/config.sh"
source "$_WT_DIR/lib/core/worktree.sh"
source "$_WT_DIR/lib/core/protect.sh"
source "$_WT_DIR/lib/core/update.sh"
source "$_WT_DIR/lib/cmd/new.sh"
source "$_WT_DIR/lib/cmd/switch.sh"
source "$_WT_DIR/lib/cmd/open.sh"
source "$_WT_DIR/lib/cmd/remove.sh"
source "$_WT_DIR/lib/cmd/list.sh"
source "$_WT_DIR/lib/cmd/clear.sh"
source "$_WT_DIR/lib/cmd/init.sh"
source "$_WT_DIR/lib/cmd/rename.sh"
source "$_WT_DIR/lib/cmd/log.sh"
source "$_WT_DIR/lib/cmd/lock.sh"
source "$_WT_DIR/lib/cmd/update.sh"
source "$_WT_DIR/lib/cmd/uninstall.sh"
source "$_WT_DIR/lib/cmd/version.sh"
source "$_WT_DIR/lib/cmd/help.sh"
```

### POSIX Compliance

- All new/moved files must remain POSIX-compatible (no bash/zsh-specific syntax)
- `shellcheck` must pass with no new suppressions
- No `local` arrays, no `[[`, no `(( ))` arithmetic (use `[ ]` and `$(( ))`)

### Self-update Compatibility

`_update_install` in `lib/update.sh` currently copies `wt.sh lib/ VERSION` from the downloaded clone. After the refactor, this copy command will still work because the entire `lib/` tree is copied. No change needed.

### Test Helper Compatibility

`test/test_helper.bash` sources `wt.sh` via `PROJECT_ROOT`. The test helper does not directly source individual `lib/` files. All test files should continue to work without modification.

---

## Dependencies

**Prerequisite Stories (recommended ordering):**
- STORY-040, STORY-041, STORY-042, STORY-043, STORY-044, STORY-045 — should ideally land before this refactor so the final structure is refactored rather than an intermediate one. However, this refactor can also go first and new commands slot into the new structure.

**Alternatively:**
- This story can be done before STORY-040–045. New commands then slot directly into `lib/cmd/` as new files.

**Blocked Stories:**
- None — this is a pure internal refactor with no API surface change.

**External Dependencies:**
- None

---

## Definition of Done

- [ ] All `lib/` files moved/split per the target structure
- [ ] `wt.sh` updated with new source list
- [ ] `_confirm` helper extracted and used in `remove.sh`, `rename.sh`, `clear.sh`
- [ ] `_is_protected_branch` moved to `lib/core/protect.sh` and called from both `remove.sh` and `clear.sh`
- [ ] `_cmd_clear` decomposed into sub-functions (no function longer than 40 lines in `clear.sh`)
- [ ] All existing BATS tests pass (`npm test`)
- [ ] `shellcheck` passes on all files (CI green)
- [ ] Zero function definitions duplicated across files
- [ ] Inline contributor comments added to each `lib/core/*.sh` file header
- [ ] Old `lib/utils.sh`, `lib/config.sh`, `lib/worktree.sh`, `lib/commands.sh`, `lib/update.sh` removed (no orphan files)
- [ ] Committed with one logical commit per major split (reviewable history), conventional commit format

---

## Story Points Breakdown

- **Mechanical file splitting (core/):** 2 points — move functions, adjust source paths, verify shellcheck
- **cmd/ extraction (one file per command):** 2 points — 14 files, mostly cut-and-paste with minor cleanup
- **DRY fixes (_confirm, _is_protected_branch consistency):** 2 points — shared helper extraction + test coverage
- **_cmd_clear decomposition:** 2 points — most complex single function, requires careful sub-function split + full test pass

**Total: 8 points**

**Rationale:** Pure refactor with a strong test safety net. The risk is low but the surface area is large — every `lib/` file is touched. The 8-point estimate reflects breadth rather than depth.

---

## Additional Notes

- Work in a dedicated worktree (`wt -n story-046-refactor`) to avoid disrupting main dev
- The BATS test suite is the complete safety net: run `npm test` before and after each file move
- Commit strategy: one commit per `lib/core/` file created, one commit per batch of `lib/cmd/` files, one final commit for `wt.sh` source list update and old-file removal
- If STORY-040–045 have not landed yet, stub their `lib/cmd/` files with a placeholder comment so the structure is ready
- The `git-worktrees.zsh` legacy file is explicitly out of scope (deprecated, not part of active `lib/`)

---

## Progress Tracking

**Status History:**
- 2026-02-21: Draft created (backlog)
- 2026-02-22: Formalized by Scrum Master (BMAD Method v6)

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
