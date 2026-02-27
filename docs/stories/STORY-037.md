# STORY-037: Completions — show example usage hint when nothing to suggest

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Sprint:** 7

---

## User Story

As a developer pressing `<TAB>` after a command that takes a free-form argument
I want to see an example placeholder rather than nothing
So that I know what to type without consulting the docs

---

## Description

### Problem

For commands like `wt -n <branch>` where the argument is a free-form string,
pressing `<TAB>` currently shows nothing. This is confusing — the user doesn't know
if completions are broken or if there's simply nothing to suggest.

### Expected Behaviour

When there are no dynamic completions to offer, show a descriptive placeholder hint:

```
$ wt -n <TAB>
<branch>   -- new branch name
```

```
$ wt --from <TAB>
<ref>   -- branch, tag, or commit to base from
```

This matches the style of tools like `docker`, `kubectl`, and `gh` which show
argument descriptions when no values are available.

---

## Acceptance Criteria

- [ ] `wt -n <TAB>` shows `<branch>` with description `new branch name`
- [ ] `wt --from <TAB>` shows `<ref>` with description `branch, tag, or commit`
- [ ] `wt --rename <TAB>` shows `<new-branch>` with description `new branch name`
- [ ] Hints only shown when no dynamic completions are available
- [ ] Works in both zsh and bash
- [ ] Existing dynamic completions (branch names, worktree names) unaffected
- [ ] `shellcheck` passes

---

## Technical Notes

- In zsh completions (`completions/_wt`): use `_message` for placeholder hints
  ```zsh
  (( CURRENT == 2 )) && _message 'new branch name' && return
  ```
- In bash completions: add a comment-style hint using `COMPREPLY=( '<branch>' )` only
  if `$COMP_CWORD` indicates no prior completion was offered
- Coordinate with STORY-036 (per-command help) for consistent placeholder naming

---

## Dependencies

- STORY-030: Completions overhaul (same sprint or prerequisite)

---

## Definition of Done

- [ ] Placeholder hints added to zsh completions for free-form arguments
- [ ] Placeholder hints added to bash completions
- [ ] Does not interfere with dynamic completions
- [ ] Manually verified in zsh and bash
- [ ] `shellcheck` passes

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
