# STORY-035: `wt --init` — offer to copy/backup existing hooks

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Sprint:** 7

---

## User Story

As a developer re-initialising `wt` in a repo that already has hooks
I want to be asked whether to preserve my existing hooks before init overwrites them
So that I don't accidentally lose custom hook scripts

---

## Description

### Problem

If `.worktrees/hooks/` (or the configured hooks directory) already exists, `wt --init`
either silently overwrites or skips it with no explanation. Existing hook scripts
(post-checkout, post-merge, etc.) can be lost without warning.

### Expected Behaviour

If hooks already exist during `wt --init`:

```
Hooks directory already exists: .worktrees/hooks/
  - post-checkout.sh
  - post-merge.sh

Would you like to:
  [1] Keep existing hooks (skip)
  [2] Back up existing hooks to .worktrees/hooks.bak/
  [3] Overwrite with defaults

Choice [1]:
```

---

## Acceptance Criteria

- [ ] `wt --init` detects if hooks directory already contains files
- [ ] If hooks exist: prompt user with 3 options (keep / backup / overwrite)
- [ ] Option 1 (keep): hooks directory untouched, config still created/updated
- [ ] Option 2 (backup): existing hooks moved to `<hooksDir>.bak/` before init proceeds
- [ ] Option 3 (overwrite): existing hooks replaced with defaults (current behaviour)
- [ ] Default choice is option 1 (keep) — press Enter to keep existing hooks
- [ ] Non-interactive mode (`wt --init --force` or piped input): defaults to keep
- [ ] `shellcheck` passes

---

## Technical Notes

- Check if hooks dir is non-empty: `[ "$(ls -A "$hooks_dir")" ]`
- List existing hook files for the user to see before choosing
- Use `_read_input` (existing utility) for the prompt
- Backup: `mv "$hooks_dir" "${hooks_dir}.bak"`
- Non-interactive detection: `[ -t 0 ]` (stdin is a terminal)

---

## Dependencies

- STORY-034: Verbose feedback to `wt --init` (related sprint, complementary)

---

## Definition of Done

- [ ] Hooks detection logic added to `_cmd_init`
- [ ] 3-option prompt implemented with correct default
- [ ] Backup moves hooks to `.bak` directory
- [ ] Non-interactive fallback defaults to keep
- [ ] BATS tests for all 3 choices
- [ ] `shellcheck` passes

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
