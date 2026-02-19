# STORY-028: Fix zsh tab completions silently failing when wt.sh sourced before compinit

**Epic:** Developer Experience
**Priority:** Must Have
**Story Points:** 2
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-19
**Sprint:** 5

---

## User Story

As a developer using `wt` in zsh
I want tab completions to work after sourcing `wt.sh`
So that I can discover flags and branch names without memorizing them

---

## Description

### Background

Tab completions were shipped in STORY-014 (v1.3.0). However, users report that pressing Tab after `wt` or `wt -` produces nothing.

**Root cause:** `wt.sh` line 120:
```sh
compdef _wt wt 2>/dev/null
```

`compdef` is a zsh built-in that requires `compinit` to have been called first. If the user sources `wt.sh` before `compinit` runs in their `.zshrc`, the `compdef` call silently fails — `2>/dev/null` hides the error and completions are never registered.

**Typical `.zshrc` order that breaks completions:**
```zsh
source ~/projects/worktree-helpers/wt.sh   # compdef fails — compinit not yet called
# ... other stuff ...
autoload -Uz compinit && compinit           # too late — compdef already missed
```

### Scope

**In scope:**
- Fix zsh completion registration to work regardless of source order in `.zshrc`
- Use deferred `compdef` via `precmd_functions` hook when `compdef` is not yet available
- Bash completions are unaffected (they use `complete` which has no ordering requirement)

**Out of scope:**
- Fish shell completions
- Changing install instructions / `.zshrc` ordering guidance (fix should be transparent)

### User Flow

1. User has `source ~/path/to/wt.sh` in their `.zshrc` (anywhere — before or after `compinit`)
2. User opens a new terminal
3. User types `wt ` and presses Tab → sees all flags and commands
4. User types `wt -s ` and presses Tab → sees worktree branch names
5. Completions work identically to STORY-014 spec

---

## Acceptance Criteria

- [ ] `wt <Tab>` shows completions when `wt.sh` is sourced **before** `compinit` in `.zshrc`
- [ ] `wt <Tab>` shows completions when `wt.sh` is sourced **after** `compinit` in `.zshrc`
- [ ] `wt -<Tab>` shows flags in both ordering scenarios
- [ ] `wt -s <Tab>` shows worktree branch names in both ordering scenarios
- [ ] No errors or warnings printed to the terminal when sourcing `wt.sh`
- [ ] No regressions in bash completions
- [ ] All existing completion tests still pass
- [ ] `wt.sh` passes shellcheck

---

## Technical Notes

### Root Cause

`compdef` is provided by the zsh completion system and is only available after `compinit` has run. The current code calls it unconditionally:

```sh
compdef _wt wt 2>/dev/null   # silently fails if compinit hasn't run
```

### Fix

Detect whether `compdef` is available. If not, defer registration via `precmd_functions` (called before each prompt — guaranteed to run after `compinit`):

```sh
if [ -n "${ZSH_VERSION:-}" ]; then
  fpath=("$_WT_DIR/completions" $fpath)
  autoload -Uz _wt
  if (( $+functions[compdef] )); then
    compdef _wt wt 2>/dev/null
  else
    # compinit hasn't run yet — defer until first prompt
    _wt_register_compdef() {
      compdef _wt wt 2>/dev/null
      precmd_functions=(${precmd_functions:#_wt_register_compdef})
    }
    typeset -ag precmd_functions
    precmd_functions+=(_wt_register_compdef)
  fi
fi
```

**How it works:**
- `(( $+functions[compdef] ))` checks if `compdef` is defined as a function (it is, once compinit runs)
- If not available, we push `_wt_register_compdef` into `precmd_functions` — zsh calls this before each prompt
- On first prompt, `compdef _wt wt` runs (compinit has run by then), then the hook removes itself
- If `compdef` IS available at source time (user sources after compinit), the fast path runs directly — no hook needed

### Components

- **`wt.sh`**: Lines 115–125 (completion registration block)

### Edge Cases

- **Non-interactive zsh** (scripts): `precmd_functions` may not be set; `typeset -ag` initialises it safely
- **compdef still unavailable at first prompt**: Unlikely (would mean compinit never ran), but `2>/dev/null` ensures silence
- **Multiple sources of `wt.sh`**: Hook de-registers itself after first run, so re-sourcing is safe

---

## Dependencies

**Prerequisite Stories:**
- STORY-014: Add shell completions (bash + zsh) — this is a bug fix for that story

**Blocked Stories:**
- None

---

## Definition of Done

- [ ] `wt.sh` completion block updated with deferred `compdef` pattern
- [ ] Manual verification: completions work with `wt.sh` sourced before `compinit`
- [ ] Manual verification: completions work with `wt.sh` sourced after `compinit`
- [ ] All 203+ existing BATS tests pass (no regressions)
- [ ] `wt.sh` passes shellcheck
- [ ] No errors when sourcing in non-interactive zsh

---

## Story Points Breakdown

- **Fix in `wt.sh`**: 0.5 points
- **Testing + edge cases**: 1 point
- **Manual verification in both `.zshrc` orderings**: 0.5 points
- **Total:** 2 points

**Rationale:** Targeted single-file fix with a well-understood pattern. Small but important — silently broken completions undermine STORY-014's value.

---

## Additional Notes

The `[2] 28120` background job notification seen during bug reproduction is unrelated — it's a separate backgrounded shell process that printed its completion status at the same time.

---

## Progress Tracking

**Status History:**
- 2026-02-19: Created — bug reported by user (wt 1.3.0, zsh, completions not working)
- 2026-02-19: Completed — deferred compdef pattern applied to wt.sh; all 248 BATS tests pass; shellcheck clean

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
