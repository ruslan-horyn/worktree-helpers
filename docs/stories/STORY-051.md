# STORY-051: Fix fzf ESC cancellation silently ignored across all selection commands

**Epic:** CLI Polish & Reliability
**Priority:** Must Have
**Story Points:** 3
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-27
**Sprint:** Backlog

---

## User Story

As a `wt` CLI user
I want pressing ESC in any fzf selection menu to cancel the command
So that I can safely back out of an interactive selection without triggering unintended actions

---

## Description

### Background

When `wt -s`, `wt -r`, `wt -L`, or `wt -U` is invoked without arguments, an fzf picker appears.
Pressing ESC should abort the command — instead the command continues executing with an empty
worktree path, producing confusing errors or silently doing nothing.

The root cause is a shell pipeline in `_wt_select()` (lib/worktree.sh:40-48):

```sh
# BROKEN — fzf exits 130 on ESC, but cut succeeds with empty input → returns 0
git worktree list --porcelain \
  | awk '...' \
  | fzf --prompt="..." --with-nth=1 --delimiter='\t' \
  | cut -f2
```

In a POSIX pipeline the exit code of the **last** command wins. `cut` reads empty input,
outputs nothing, and returns 0 — so the caller never sees fzf's exit code 130.

The same problem exists in `_branch_select()` (lib/worktree.sh:50-58) used by `wt -o`.

### Scope

**In scope:**
- Fix `_wt_select()` to preserve and propagate fzf exit code
- Fix `_branch_select()` to preserve and propagate fzf exit code
- Extract a shared `_fzf_select` primitive that handles fzf invocation + ESC consistently,
  so future commands get correct behaviour for free (analogous to passing options to a `select`
  function in JavaScript)
- Verify all callers (`_cmd_switch`, `_cmd_remove`, `_cmd_open`, `_cmd_lock`, `_cmd_unlock`)
  correctly abort when the helper returns non-zero

**Out of scope:**
- Adding keyboard shortcuts other than ESC
- Changing the visual appearance of the fzf UI
- Adding multi-select support (that's STORY-045)

### User Flow

1. User runs `wt -s` (no argument)
2. fzf picker opens showing worktree names
3. User presses **ESC** (or Ctrl-C)
4. Command exits cleanly — no error message, no side effects
5. User's shell prompt returns normally

---

## Acceptance Criteria

- [ ] Pressing ESC in `wt -s` fzf picker exits with code 1 and prints nothing (no error message needed)
- [ ] Pressing ESC in `wt -r` fzf picker exits cleanly without attempting removal
- [ ] Pressing ESC in `wt -L` fzf picker exits cleanly without locking anything
- [ ] Pressing ESC in `wt -U` fzf picker exits cleanly without unlocking anything
- [ ] Pressing ESC in `wt -o` fzf picker exits cleanly without opening anything
- [ ] A shared `_fzf_select` function exists in `lib/worktree.sh` that:
  - Accepts a prompt string and reads candidate lines from stdin
  - Returns 1 (and outputs nothing) when fzf returns exit code 130 (ESC/Ctrl-C)
  - Outputs the selected line to stdout when a valid selection is made
- [ ] `_wt_select` and `_branch_select` are refactored to use `_fzf_select` (or are replaced by it)
- [ ] All existing BATS tests still pass
- [ ] New BATS tests cover ESC-cancellation for at least `_cmd_switch` and `_cmd_remove`

---

## Technical Notes

### Root Cause

```sh
# _wt_select — lib/worktree.sh:44-47
git worktree list --porcelain \
  | awk '/^worktree /{p=substr($0,10); n=p; sub(/.*\//, "", n); print n "\t" p}' \
  | fzf --prompt="${1:-wt> }" --with-nth=1 --delimiter='\t' \
  | cut -f2   # ← swallows fzf's exit 130; cut returns 0 on empty input
```

### Proposed Fix — shared `_fzf_select` helper

```sh
# Reads options from stdin, shows fzf picker, echoes selected line to stdout.
# Returns 1 (silently) when ESC/Ctrl-C is pressed (fzf exit 130).
_fzf_select() {
  local prompt="${1:-select> }" selected fzf_exit
  selected=$(cat | fzf --prompt="$prompt")
  fzf_exit=$?
  [ "$fzf_exit" -eq 130 ] && return 1   # ESC / Ctrl-C
  [ "$fzf_exit" -ne 0 ]  && return 1   # other fzf error
  printf '%s\n' "$selected"
}
```

Callers build their candidate list and pipe into `_fzf_select`:

```sh
_wt_select() {
  command -v fzf >/dev/null 2>&1 || { _err "Install fzf or pass branch"; return 1; }
  local selected raw_path
  selected=$(git worktree list --porcelain \
    | awk '/^worktree /{p=substr($0,10); n=p; sub(/.*\//, "", n); print n "\t" p}' \
    | _fzf_select "${1:-wt> } --with-nth=1 --delimiter='\\t'") || return 1
  printf '%s\n' "$selected" | cut -f2
}
```

> Note: `_fzf_select` must support forwarding extra fzf flags (e.g. `--with-nth`, `--delimiter`)
> OR we keep two thin wrappers (`_wt_select`, `_branch_select`) that build the candidate list
> and call fzf directly, but break the pipeline before any postprocessing (`cut`).

Simpler alternative that doesn't need a generic helper:

```sh
_wt_select() {
  command -v fzf >/dev/null 2>&1 || { _err "Install fzf or pass branch"; return 1; }
  local selected
  selected=$(git worktree list --porcelain \
    | awk '/^worktree /{p=substr($0,10); n=p; sub(/.*\//, "", n); print n "\t" p}' \
    | fzf --prompt="${1:-wt> }" --with-nth=1 --delimiter="$(printf '\t')")
  [ $? -ne 0 ] && return 1
  printf '%s\n' "$selected" | cut -f2
}

_branch_select() {
  command -v fzf >/dev/null 2>&1 || { _err "Install fzf or pass branch"; return 1; }
  local selected
  selected=$(git branch -r --format='%(refname:short)' 2>/dev/null \
    | grep -v 'HEAD' | sed 's|^origin/||' | sort -u \
    | fzf --prompt="${1:-branch> }")
  [ $? -ne 0 ] && return 1
  printf '%s\n' "$selected"
}
```

Either approach is acceptable; developer chooses the cleanest implementation.

### Affected Files

| File | Location | Change |
|------|----------|--------|
| `lib/worktree.sh` | `_wt_select()` line 40-48 | Break pipeline before `cut`, check exit code |
| `lib/worktree.sh` | `_branch_select()` line 50-58 | Break pipeline, check exit code |
| `lib/worktree.sh` | (optional) | Add `_fzf_select` reusable helper |
| `lib/commands.sh` | `_cmd_open()` line 52-73 | Remove now-redundant `[ -z "$branch" ]` guard |
| `test/cmd_switch.bats` | — | Add ESC-cancellation test |
| `test/cmd_remove.bats` | — | Add ESC-cancellation test |

### Testing ESC in BATS

To simulate ESC (fzf exit 130) in tests, stub `fzf` with a function/script that exits 130:

```bash
# In test helper or individual test
fzf() { return 130; }
export -f fzf
```

---

## Dependencies

**Prerequisite Stories:** None

**Blocked Stories:** None

**External Dependencies:** None (fzf exit code 130 is documented and stable)

---

## Definition of Done

- [ ] Code implemented and committed to feature branch
- [ ] `_wt_select` and `_branch_select` do not swallow fzf exit code
- [ ] ESC returns exit code 1 from every interactive command (`-s`, `-r`, `-L`, `-U`, `-o`)
- [ ] Existing BATS tests pass: `npm test`
- [ ] New BATS tests added for ESC cancellation
- [ ] `_help_switch`, `_help_remove`, `_help_lock`, `_help_unlock`, `_help_open` unchanged (no user-visible help change needed)
- [ ] README unchanged (internal fix, no user-facing feature)
- [ ] Conventional commit with lowercase subject, no Co-Authored-By

---

## Story Points Breakdown

- **`_wt_select` fix:** 1 point
- **`_branch_select` fix:** 0.5 points
- **Shared helper (if pursued):** 0.5 points
- **BATS tests:** 1 point
- **Total:** 3 points

**Rationale:** The fix itself is a handful of lines; the bulk of effort is writing reliable BATS tests that stub fzf's ESC exit code.

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
