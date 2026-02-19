# STORY-034: Add verbose feedback to `wt -c` and `wt --init`

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 3
**Status:** Not Started
**Sprint:** 7

---

## User Story

As a developer running `wt -c` or `wt --init`
I want to see step-by-step output of what the command is doing
So that I understand what happened and can diagnose failures

---

## Description

### Problem

`wt -c` (clear) and `wt --init` run silently or print minimal output, leaving the user
guessing whether anything happened and why failures occurred.

**`wt -c` issues:**
- Doesn't explain why a worktree was or wasn't deleted
- No output when 0 worktrees match the criteria
- No confirmation of what was deleted

**`wt --init` issues:**
- No step-by-step progress (creating config, setting up directories, etc.)
- Silent on success; cryptic on failure

---

## Acceptance Criteria

### `wt -c` verbose output

- [ ] For each worktree evaluated: print its name and the decision (`deleting...` / `skipping: protected` / `skipping: locked` / `skipping: too recent`)
- [ ] After completion: print summary `Cleared X worktree(s)`
- [ ] If 0 worktrees match: print `No worktrees to clear`
- [ ] `--dry-run` output prefixes each line with `[dry-run]`

### `wt --init` verbose output

- [ ] Print each step: `Creating .worktrees/config.json...`, `Setting up hooks directory...`, `Updating .gitignore...`
- [ ] Print `✓ Done` at completion with a summary of what was created
- [ ] On failure: print which step failed and why

### General

- [ ] Output goes to stdout (not suppressed)
- [ ] `shellcheck` passes
- [ ] BATS tests verify verbose output lines

---

## Technical Notes

- Use the existing `_info` helper for step messages
- `wt -c` already has a loop over worktrees — add `_info` calls at decision points
- `wt --init` is more sequential — add `_info` before each major operation

---

## Dependencies

- None

---

## Definition of Done

- [ ] `_cmd_clear` prints per-worktree decision + summary
- [ ] `_cmd_init` prints step-by-step progress
- [ ] BATS tests for verbose output
- [ ] `shellcheck` passes

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
