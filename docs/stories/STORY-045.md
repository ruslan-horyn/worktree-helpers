# STORY-045: Multi-select for `wt -r` and other commands

**Epic:** Developer Experience
**Priority:** Could Have
**Story Points:** 3
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** Backlog

---

## User Story

As a developer who wants to remove or act on multiple worktrees at once,
I want fzf multi-select in `wt -r`, `wt -L`, and `wt -U` (when no argument is given),
So that I can handle batch operations without repeating the same command multiple times.

---

## Description

### Background

Currently `wt -r` (remove), `wt -L` (lock), and `wt -U` (unlock) open an fzf picker
but allow selecting only **one** worktree. Removing 5 old worktrees requires 5 separate
`wt -r` invocations. This is friction for cleanup workflows.

fzf natively supports multi-select with the `--multi` flag: Tab selects/deselects items,
Enter confirms the full selection. Output is newline-separated, making it straightforward
to loop over results.

### Scope

**In scope:**
- `wt -r` (no args): fzf multi-select, confirmation shows count, sequential removal
- `wt -L` (no args): fzf multi-select, lock all selected worktrees
- `wt -U` (no args): fzf multi-select, unlock all selected worktrees
- `wt -r -f` (no args, force): multi-select via fzf, skip confirmation
- Graceful handling of empty selection (user pressed Esc)
- `_wt_select` in `lib/worktree.sh` gains a `multi` parameter

**Out of scope:**
- `wt -s` (switch): multi-select is nonsensical for switching
- `wt -o` (open): possible future enhancement; excluded from this story
- Any changes to the explicit-argument code path (`wt -r <name>` still works as before)

### User Flow

```
wt -r        # fzf opens with Tab for multi-select, Enter to confirm
# User selects: feature-old-1, feature-old-2, hotfix-done
# [wt] Remove 3 worktrees? [y/N]: y
# [wt] Removing feature-old-1 ...
# [wt] Removing feature-old-2 ...
# [wt] Removing hotfix-done ...
# [wt] Removed 3 worktree(s)
```

---

## Acceptance Criteria

- [ ] `wt -r` (no args) opens fzf with `--multi` enabled (Tab to select multiple, Enter to confirm)
- [ ] Confirmation prompt shows count: `Remove N worktrees? [y/N]`
- [ ] Each removed worktree prints a progress line: `Removing <name> ...`
- [ ] Summary line at end: `Removed N worktree(s)`
- [ ] `wt -r -f` (no args, force): multi-select from fzf, removes all selected without confirmation
- [ ] `wt -r <single-name>` still works exactly as before (no regression on explicit-arg path)
- [ ] `wt -L` (no args) opens fzf with `--multi`, locks all selected worktrees
- [ ] `wt -U` (no args) opens fzf with `--multi`, unlocks all selected worktrees
- [ ] Empty selection (Esc in fzf) exits cleanly with no error
- [ ] fzf not installed: behavior unchanged — existing error message applies (no regression)

---

## Technical Notes

### Components

- **`lib/worktree.sh`**: Modify `_wt_select` to accept a `multi` parameter
- **`lib/commands.sh`**: Update `_cmd_remove`, `_cmd_lock`, `_cmd_unlock` to loop over multi-select results

### `_wt_select` Change

Current signature:
```sh
_wt_select() {
  ...
  | fzf --prompt="${1:-wt> }" --with-nth=1 --delimiter='\t' \
  | cut -f2
}
```

Proposed change — add optional second parameter `$2` for multi mode:
```sh
_wt_select() {
  local prompt="${1:-wt> }" multi="${2:-0}"
  local fzf_flags="--prompt=$prompt --with-nth=1 --delimiter=\t"
  [ "$multi" = "1" ] && fzf_flags="$fzf_flags --multi"
  git worktree list --porcelain \
    | awk '/^worktree /{p=substr($0,10); n=p; sub(/.*\//, "", n); print n "\t" p}' \
    | fzf $fzf_flags \
    | cut -f2
}
```

Output when `--multi`: multiple lines, one full path per line.

### `_cmd_remove` Change

When `input` is empty (fzf path), call `_wt_select "remove> " 1` to get newline-separated
paths, then loop:
```sh
paths=$(_wt_select "remove> " 1) || return 1
[ -z "$paths" ] && return 0

count=$(printf '%s\n' "$paths" | grep -c .)

if [ "$force" -ne 1 ]; then
  printf "Remove %d worktrees? [y/N] " "$count" >&2
  read -r r
  case "$r" in y|Y) ;; *) return 1 ;; esac
fi

removed=0
while IFS= read -r wt_path; do
  [ -z "$wt_path" ] && continue
  [ "$PWD" = "$wt_path" ] && cd "$(_repo_root)" || true
  local branch; branch=$(_wt_branch "$wt_path")
  if [ "$force" -eq 1 ]; then
    git worktree remove --force "$wt_path"
  else
    git worktree remove "$wt_path"
  fi
  [ -n "$branch" ] && _branch_exists "$branch" && git branch -D "$branch" 2>/dev/null
  removed=$((removed + 1))
done <<EOF
$paths
EOF
_info "Removed $removed worktree(s)"
```

### `_cmd_lock` / `_cmd_unlock` Change

Same pattern: when no `input` arg, call `_wt_select "lock> " 1` (or `"unlock> " 1`) and
loop over results.

### `_wt_resolve` Compatibility

`_wt_resolve` is used by `_cmd_switch` and passes through to `_wt_select` without multi.
No change needed there — single-select behavior preserved.

### Edge Cases

- User selects only 1 item in multi-select: behaves like current single-select (no UX regression)
- fzf output includes trailing newline: `[ -z "$wt_path" ] && continue` guard handles it
- User is in one of the selected worktrees: `cd` back to repo root before removal (already handled)

---

## Dependencies

- None

---

## Definition of Done

- [ ] Code implemented and committed to feature branch
- [ ] `_wt_select` updated with `multi` parameter in `lib/worktree.sh`
- [ ] `_cmd_remove` updated to use multi-select and loop in `lib/commands.sh`
- [ ] `_cmd_lock` updated to use multi-select in `lib/commands.sh`
- [ ] `_cmd_unlock` updated to use multi-select in `lib/commands.sh`
- [ ] `_help_remove` updated to document multi-select behavior
- [ ] BATS tests added:
  - [ ] `test/cmd_remove.bats`: multi-select path (mocked fzf returning multiple lines)
  - [ ] `test/cmd_remove.bats`: force flag skips confirmation with multi-select
  - [ ] `test/cmd_remove.bats`: empty selection exits cleanly
  - [ ] `test/cmd_lock.bats` / `test/cmd_unlock.bats`: multi-select path
- [ ] All existing tests pass (`npm test`)
- [ ] README updated (1-3 lines under remove/lock/unlock commands)
- [ ] Acceptance criteria all checked off

---

## Story Points Breakdown

- **`_wt_select` multi parameter:** 0.5 points
- **`_cmd_remove` loop + confirmation:** 1 point
- **`_cmd_lock` + `_cmd_unlock` loop:** 0.5 points
- **Tests (3 commands):** 1 point
- **Total:** 3 points

**Rationale:** The fzf `--multi` flag is a single-line addition. The bulk of the work is
refactoring the three command handlers to loop over results and updating tests.

---

## Additional Notes

- fzf `--multi`: Tab selects, Shift-Tab deselects, Enter confirms. Output is newline-separated.
- POSIX shell: use `while IFS= read -r line; do ... done <<EOF` for iterating newline output.
- Do NOT use arrays or `mapfile` — keep POSIX-compatible shell syntax throughout.
- `_wt_resolve` currently returns a single path. Do not change its signature — callers that
  want single-select still go through `_wt_resolve`; multi-select callers call `_wt_select` directly.

---

## Progress Tracking

**Status History:**
- 2026-02-21: Draft created
- 2026-02-22: Formalized by Scrum Master (BMAD Method v6)

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
