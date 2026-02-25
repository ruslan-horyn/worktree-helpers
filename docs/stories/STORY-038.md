# STORY-038: Descriptive usage with placeholders in command output

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Completed
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

1. `wt -h` output shows `<branch>` next to `-n, --new` in the Commands section
2. `wt -h` output shows `<worktree>` next to `-s, --switch`, `-r, --remove`, `-L, --lock`, `-U, --unlock` in the Commands section
3. `wt -h` output shows `<days>` next to `-c, --clear` in the Commands section
4. `wt -h` output shows `<ref>` next to `-b, --from` in the Flags section
5. `wt -h` output shows `<pattern>` next to `--pattern` in the Flags section
6. `wt -h` output shows `<date>` next to `--since` in the Flags section
7. `wt -h` output shows `<pattern>` next to `--author` in the Flags section
8. `wt -h` includes at least 1 concrete example line for `-n` (e.g., `wt -n feature-foo`)
9. `wt -h` includes at least 1 concrete example line for `-c` (e.g., `wt -c 30`)
10. Per-command help functions exist for ALL commands: `_help_lock`, `_help_unlock`, `_help_log`, `_help_rename` (currently missing)
11. `wt -L --help` dispatches to `_help_lock` and shows `<worktree>` placeholder and at least 1 example
12. `wt -U --help` dispatches to `_help_unlock` and shows `<worktree>` placeholder and at least 1 example
13. `wt --log --help` dispatches to `_help_log` and shows `<branch>` placeholder and at least 1 example
14. `wt --rename --help` dispatches to `_help_rename` and shows `<new-branch>` placeholder and at least 1 example
15. Placeholder names are consistent across `_cmd_help` and all `_help_*` functions: `<branch>`, `<worktree>`, `<ref>`, `<days>`, `<pattern>`
16. `shellcheck lib/commands.sh` exits 0

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
- Add `_help_lock`, `_help_unlock`, `_help_log`, `_help_rename` functions to `lib/commands.sh`
- Add `--help` routing for `lock`, `unlock`, `log`, and `rename` actions in `wt.sh`

### Placeholder naming convention
| Argument type | Placeholder |
|--------------|-------------|
| New branch name | `<branch>` |
| Existing worktree | `<worktree>` |
| Git ref | `<ref>` |
| Age in days | `<days>` |
| Pattern | `<pattern>` |
| Text note | `<note>` |
| Date string | `<date>` |
| Author pattern | `<pattern>` |
| New branch for rename | `<new-branch>` |

---

## Dependencies

- STORY-036: Per-command help (share placeholder style)
- STORY-037: Completion hints (share placeholder names)

---

## Definition of Done

- [x] AC 1-9: `_cmd_help` in `lib/commands.sh` updated — every flag that takes an argument shows its `<placeholder>` and the Commands section includes at least 1 example line per command that takes an argument
- [x] AC 10: `_help_lock`, `_help_unlock`, `_help_log`, `_help_rename` functions added to `lib/commands.sh`
- [x] AC 11-14: `wt.sh` router updated — `lock`, `unlock`, `log`, and `rename` dispatch to their `_help_*` function when `--help` is present
- [x] AC 15: Placeholder naming convention comment added near the top of the `_cmd_help` / `_help_*` block in `lib/commands.sh`
- [x] AC 16: `shellcheck lib/commands.sh` passes with exit code 0
- [x] `test/STORY-038.bats` passes (all tests green — 51/51)
- [x] README Commands section updated to reflect any new `--help` routing added

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## Pattern Guidelines

### Guard Clauses
Validate at the top of every function, return early on failure.
Never nest happy-path logic inside `if` blocks.

Good:
```sh
_help_lock() {
  cat <<'HELP'
  ...
HELP
}
```

The `_help_*` functions in this story are pure output functions (heredoc), so guard clauses are not applicable — they have no inputs to validate. The guard clause pattern applies to `_cmd_*` functions only.

Check: this story does NOT add new `_cmd_*` functions, so no guard clause changes are needed.

### Single Responsibility
Each function does exactly one thing.

Functions added by this story and their single responsibility:
- `_help_lock` — print lock command help text
- `_help_unlock` — print unlock command help text
- `_help_log` — print log command help text
- `_help_rename` — print rename command help text

All four are pure output functions. Each is under 20 lines. No splitting required.

Check: `_cmd_help` is modified (not a new function). It remains a single responsibility: print the top-level help text.

### Command Router Pattern
New commands follow the `_cmd_<name>()` convention; dispatched in `wt.sh`.
This story adds `_help_*` functions only, not new `_cmd_*` functions.
However, `wt.sh` router must be updated for `lock`, `unlock`, `log`, and `rename` to check
`if [ "$help" -eq 1 ]; then _help_<cmd>; return 0; fi` — exactly matching the pattern used
by `new`, `switch`, `remove`, `open`, `list`, `clear`, `init`, and `update`.

Check: confirm `lock`, `unlock`, `log`, `rename` cases in `wt.sh` are updated to dispatch to `_help_*`.

### Utility Reuse (DRY)
Before writing new logic, check existing utilities.

This story only adds `cat <<'HELP' ... HELP` heredoc functions. No utility functions are duplicated.
The consistent placeholder names (`<branch>`, `<worktree>`, `<ref>`, `<days>`, `<pattern>`) are
defined by convention (see the Placeholder naming convention table above), not in a shared variable.

Check: no new utility functions are introduced. No duplication of existing utilities.

### Output Streams
Errors and user prompts go to stderr. Data/output goes to stdout.

All `_help_*` and `_cmd_help` output goes to stdout via heredoc. This is correct — help text
is data output, not an error. No `>&2` needed in these functions.

Check: verify that the new `_help_lock`, `_help_unlock`, `_help_log`, `_help_rename` heredocs
do NOT redirect to stderr.

### Hook / Extension Pattern
This story does not introduce any new lifecycle events. No hooks required.

### Config as Data
This story does not read or add any config values. `_help_*` functions are static text only.

---

## Progress Tracking

**Status:** Completed — 2026-02-25

**Files changed:**
- `lib/commands.sh` — modified: updated `_cmd_help` with placeholders and example lines; added `_help_lock`, `_help_unlock`, `_help_log`, `_help_rename` functions; added placeholder naming convention comment
- `wt.sh` — modified: added `--help` dispatch for `lock`, `unlock`, `log`, and `rename` actions
- `README.md` — modified: updated `-L` and `-U` entries in Commands table to use `<worktree>` placeholder

**Test results:**
- `test/STORY-038.bats`: 51/51 passed
- Full suite (`npm test`): all tests passing, 0 failures

**Decisions:**
- Kept `_help_*` functions as pure `cat <<'HELP' ... HELP` heredocs (no guard clauses needed — no inputs to validate)
- Used `<worktree>` for lock/unlock/switch/remove consistently in both `_cmd_help` and per-command `_help_*` functions
- Added placeholder naming convention comment block inside `_cmd_help` to satisfy AC 15
- No deviations from Pattern Guidelines

---

## QA Review

### Files Reviewed
| File | Status | Notes |
|------|--------|-------|
| `lib/commands.sh` | Reviewed | `_cmd_help` updated with placeholders and example lines; `_help_lock`, `_help_unlock`, `_help_log`, `_help_rename` added |
| `wt.sh` | Reviewed | `lock`, `unlock`, `log`, `rename` cases updated to dispatch `_help_*` when `--help` is set |
| `README.md` | Reviewed | `-L` and `-U` table entries updated to use `<worktree>` placeholder |
| `test/STORY-038.bats` | Reviewed | 51 tests covering all 16 ACs, 4 edge cases, and 6 regressions |

### Issues Found
None

### AC Verification
- [x] AC 1 — `_cmd_help` line `-n, --new <branch>`: verified in `lib/commands.sh` line 716, test: `ok 293 AC1: _cmd_help shows <branch> placeholder next to -n/--new`
- [x] AC 2 — `<worktree>` next to `--switch`, `--remove`, `--lock`, `--unlock`: verified in `lib/commands.sh` lines 720-728, tests: `ok 294-297 AC2a-d`
- [x] AC 3 — `<days>` next to `--clear`: verified in `lib/commands.sh` line 724, test: `ok 298 AC3`
- [x] AC 4 — `<ref>` next to `--from` in Flags section: verified in `lib/commands.sh` line 741, test: `ok 299 AC4`
- [x] AC 5 — `<pattern>` next to `--pattern` in Flags section: verified in `lib/commands.sh` line 745, test: `ok 300 AC5`
- [x] AC 6 — `<date>` next to `--since` in Flags section: verified in `lib/commands.sh` line 748, test: `ok 301 AC6`
- [x] AC 7 — `<pattern>` next to `--author` in Flags section: verified in `lib/commands.sh` line 749, test: `ok 302 AC7`
- [x] AC 8 — at least 1 concrete example for `-n` (`wt -n feature-foo`): verified in `lib/commands.sh` line 717, test: `ok 303 AC8`
- [x] AC 9 — at least 1 concrete example for `-c` (`wt -c 30`): verified in `lib/commands.sh` line 725, test: `ok 304 AC9`
- [x] AC 10 — `_help_lock`, `_help_unlock`, `_help_log`, `_help_rename` exist in `lib/commands.sh`: tests `ok 305-308 AC10a-d`
- [x] AC 11 — `wt -L --help` dispatches to `_help_lock`, shows `<worktree>` and example: verified in `wt.sh` and `lib/commands.sh`, tests `ok 309-311 AC11a-c`, `ok 322-323 AC11-router`
- [x] AC 12 — `wt -U --help` dispatches to `_help_unlock`, shows `<worktree>` and example: tests `ok 312-314 AC12a-c`, `ok 324-325 AC12-router`
- [x] AC 13 — `wt --log --help` dispatches to `_help_log`, shows `<branch>` and example: tests `ok 315-318 AC13a-d`, `ok 326 AC13-router`
- [x] AC 14 — `wt --rename --help` dispatches to `_help_rename`, shows `<new-branch>` and example: tests `ok 319-321 AC14a-c`, `ok 327 AC14-router`
- [x] AC 15 — placeholder names consistent across `_cmd_help` and all `_help_*`: tests `ok 328-332 AC15a-e`
- [x] AC 16 — `shellcheck lib/commands.sh` exits 0: test `ok 333 AC16`, confirmed locally

### Pattern Guidelines Compliance

| Pattern | Status | Issues |
|---------|--------|--------|
| Guard Clauses | n/a | Story adds `_help_*` (pure output functions, no inputs to validate); no new `_cmd_*` functions added |
| Single Responsibility | compliant | Each of the 4 new functions does exactly one thing: print help text. All are under 20 lines |
| Command Router | compliant | `lock`, `unlock`, `log`, `rename` cases in `wt.sh` now dispatch to `_help_*` when `help=1`, matching the established pattern used by all other commands |
| Utility Reuse (DRY) | compliant | No new utility functions introduced; no duplication of `_err`, `_info`, or other utilities |
| Output Streams | compliant | All 4 new `_help_*` heredocs write to stdout only; no `>&2` redirections present |
| Hook/Extension Pattern | n/a | No new lifecycle events introduced |
| Config as Data | n/a | No config values read or added; all `_help_*` functions are static text |

### Test Results
- Total: 413 / Passed: 413 / Failed: 0
- STORY-038.bats: 51 / Passed: 51 / Failed: 0 (tests 293-343)

### Shellcheck
- Clean: yes (`shellcheck -x lib/commands.sh` exits 0; `shellcheck -x wt.sh` exits 0)
