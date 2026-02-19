# STORY-038: Descriptive usage with placeholders in command output

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Sprint:** 7

---

## User Story

As a developer reading `wt` command output or help text
I want to see concrete usage examples with real placeholders alongside flag descriptions
So that I immediately understand how to use each command without guessing

---

## Description

### Problem

The current `wt -h` output shows flags abstractly:

```
-n, --new        Create a new worktree
-s, --switch     Switch to a worktree
```

This forces the user to guess the argument types. Best-in-class CLIs (git, docker, gh)
show the argument name inline and follow with concrete examples:

```
-n, --new <branch>              Create worktree from main branch
    wt -n feature-foo           Create worktree from main
    wt -n feature-foo --from <ref>  Create worktree from specific branch
```

---

## Acceptance Criteria

- [ ] `wt -h` output shows `<argument>` placeholder next to each flag that takes an argument
- [ ] Each flag entry includes 1-2 concrete example lines below it
- [ ] Examples use realistic placeholder names (e.g., `feature-foo`, `<ref>`, `<branch>`)
- [ ] Multi-argument flags show all arguments (e.g., `-n <branch> --from <ref>`)
- [ ] Output is formatted with consistent alignment
- [ ] Per-command help (STORY-036) uses the same placeholder style
- [ ] `shellcheck` passes

---

## Technical Notes

- Update `_cmd_help` (or wherever help text is stored) to include placeholder and example lines
- Format:
  ```
  -n, --new <branch>
      Create new worktree from main branch (or --from ref)
      Example: wt -n feature-foo
               wt -n feature-foo --from develop
  ```
- Align examples with 6-space indent under the flag description
- Use the same placeholder names consistently across help text, per-command help, and completion hints

### Placeholder naming convention
| Argument type | Placeholder |
|--------------|-------------|
| New branch name | `<branch>` |
| Existing worktree | `<worktree>` |
| Git ref | `<ref>` |
| Age in days | `<days>` |
| Pattern | `<pattern>` |
| Text note | `<note>` |

---

## Dependencies

- STORY-036: Per-command help (share placeholder style)
- STORY-037: Completion hints (share placeholder names)

---

## Definition of Done

- [ ] `wt -h` updated with placeholders and examples for all commands
- [ ] Placeholder naming convention documented in code comments
- [ ] Consistent style across `wt -h`, `wt <cmd> --help`, and completion hints
- [ ] `shellcheck` passes

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
