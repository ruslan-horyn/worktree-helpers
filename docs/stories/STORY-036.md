# STORY-036: Per-command help (`wt <cmd> --help`)

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 3
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-19
**Sprint:** 6

---

## User Story

As a developer who can't remember exact flag syntax
I want to run `wt -n --help` and see detailed help for just that command
So that I get focused, actionable information without reading the full help screen

---

## Description

### Background

`wt -h` shows all commands at once, which is overwhelming when the developer only needs
the syntax for a single command. Per-command help (e.g. `git commit --help`,
`docker run --help`, `npm install --help`) is an industry-standard pattern that makes
CLI tools more discoverable and reduces the need to consult external documentation.

Currently there is no way to ask `wt` about a specific command — the only option is the
full help screen (`wt -h`), which is ~30 lines and requires the user to scan for the
relevant section. Per-command help solves this by showing a focused 10–15 line block that
includes a description, usage with argument placeholders, and concrete examples.

### Scope

**In scope:**

- `--help` flag detection for all 8 main user-facing commands:
  `-n`/`--new`, `-s`/`--switch`, `-o`/`--open`, `-r`/`--remove`,
  `-l`/`--list`, `-c`/`--clear`, `--init`, `--update`
- Each per-command help block includes: description, usage syntax with placeholders,
  2–3 concrete examples, and relevant options/flags
- `--help` intercepts before the command executes (no side effects)
- Consistent placeholder style: `<branch>`, `<worktree>`, `<ref>`, `<days>`, `<pattern>`
  (aligns with STORY-038 placeholder conventions)
- BATS tests verifying `--help` output content for each command

**Out of scope:**

- Man-page generation or `--help` output piped to a pager
- Per-command help for internal/less-used commands: `--log`, `--rename`, `--lock`,
  `--unlock`, `--uninstall` (covered by `wt -h`)
- Online documentation or HTML output
- Interactive help or guided prompts

---

## User Flow

1. Developer forgets the syntax for creating a worktree from a specific ref
2. Developer types `wt -n --help` (or `wt --new --help`)
3. Shell router detects `--help` flag following the command flag
4. Router calls the per-command help function instead of executing the command
5. Terminal prints a focused 10–15 line help block for `-n`/`--new`
6. Developer reads the usage and examples, then runs the correct command

---

## Acceptance Criteria

- [ ] `wt -n --help` prints help for the `-n` / `--new` command
- [ ] `wt -s --help` prints help for the `-s` / `--switch` command
- [ ] `wt -o --help` prints help for the `-o` / `--open` command
- [ ] `wt -r --help` prints help for the `-r` / `--remove` command
- [ ] `wt -l --help` prints help for the `-l` / `--list` command
- [ ] `wt -c --help` prints help for the `-c` / `--clear` command
- [ ] `wt --init --help` prints help for the `--init` command
- [ ] `wt --update --help` prints help for the `--update` command
- [ ] Each help block includes: description, usage syntax with placeholders, 2–3 examples
- [ ] `--help` after a command flag takes priority over running the command (no side effects)
- [ ] Long forms also work: `wt --new --help`, `wt --switch --help`, etc.
- [ ] `shellcheck` passes on all modified files

---

## Expected Output (Example)

```
$ wt -n --help

  wt -n, --new <branch>

  Create a new worktree from the main branch (or a custom ref).

  Usage:
    wt -n <branch>                 Create worktree from main branch
    wt -n <branch> --from <ref>    Create worktree from specific branch/tag/commit
    wt -n <branch> -d              Create worktree from dev branch

  Examples:
    wt -n feature-login
    wt -n bugfix-CORE-615 --from develop
    wt -n hotfix-v2 --from v2.0.0

  Options:
    --from, -b <ref>    Base branch or ref to create from (default: mainRef)
    -d, --dev           Use dev branch as base instead of main
```

---

## Technical Notes

### Router Change (wt.sh)

The router (`wt()` in `wt.sh`) must detect `--help` in the argument list before
dispatching to a `_cmd_*` handler. The cleanest approach is to set a `help=0` flag
and check it alongside `action` in the dispatch block:

```sh
# In the while/case arg-parsing loop:
--help) help=1; shift ;;

# In the dispatch case:
case "${action:-help}" in
  new)
    if [ "$help" -eq 1 ]; then _help_new; return 0; fi
    ...
  ;;
  switch)
    if [ "$help" -eq 1 ]; then _help_switch; return 0; fi
    ...
  ;;
  # etc.
esac
```

This approach:

- Requires no changes to how other flags are parsed
- Works regardless of flag order (`wt --help -n` and `wt -n --help` both work)
- Keeps help interception close to the existing `action` dispatch
- Does not execute the command (no side effects, no config load)

### Help Functions (lib/commands.sh)

Add one `_help_<action>` function per command in `lib/commands.sh`, immediately after
the corresponding `_cmd_<action>` function. Use heredoc (`cat <<'HELP' ... HELP`) to
match the existing `_cmd_help` pattern.

Each function follows this template:

```sh
_help_new() {
  cat <<'HELP'

  wt -n, --new <branch>

  Create a new worktree from the main branch (or a custom ref).

  Usage:
    wt -n <branch>                 Create worktree from main branch
    wt -n <branch> --from <ref>    Create worktree from specific branch/tag/commit
    wt -n <branch> -d              Create worktree from dev branch

  Examples:
    wt -n feature-login
    wt -n bugfix-CORE-615 --from develop
    wt -n hotfix-v2 --from v2.0.0

  Options:
    --from, -b <ref>    Base branch or ref to create from (default: mainRef)
    -d, --dev           Use dev branch as base instead of main
HELP
}
```

Commands requiring per-command help functions:

- `_help_new` — for `-n`/`--new`
- `_help_switch` — for `-s`/`--switch`
- `_help_open` — for `-o`/`--open`
- `_help_remove` — for `-r`/`--remove`
- `_help_list` — for `-l`/`--list`
- `_help_clear` — for `-c`/`--clear`
- `_help_init` — for `--init`
- `_help_update` — for `--update`

### Placeholder Style

Use consistent placeholder naming aligned with STORY-038:

- `<branch>` — new or existing branch name
- `<worktree>` — name of an existing worktree
- `<ref>` — git branch, tag, or commit SHA
- `<days>` — positive integer (age filter for `wt -c`)
- `<pattern>` — glob pattern (branch name filter for `wt -c`)

### POSIX Compliance

- `local help=0` in router function scope (no subshell needed)
- All `_help_*` functions use heredoc; no bash-specific constructs
- `shellcheck` must pass with no new suppressions

### Edge Cases

- `wt --help` with no command flag: falls through to existing `_cmd_help` (full help)
- `wt -n --help additional-arg`: `--help` detected, additional args ignored, no command runs
- Flag order: `wt --help -n` should also show `-n` help (help flag + action both parsed
  before dispatch)

---

## Dependencies

- **STORY-038** — Descriptive usage with placeholders (related — share placeholder naming
  style). STORY-036 ships first; STORY-038 extends the full help and completion hints with
  the same conventions.

---

## Definition of Done

- [ ] Per-command `--help` implemented for all 8 main commands
- [ ] Each shows: description, usage with placeholders, 2–3 examples, relevant options
- [ ] Router correctly intercepts `--help` before command execution (no side effects)
- [ ] Long-form aliases (`--new --help`, `--switch --help`, etc.) also work
- [ ] BATS tests in `test/cmd_help.bats` verify `--help` output for each command:
  - [ ] Output contains command description
  - [ ] Output contains usage line with correct placeholders
  - [ ] Output contains at least one example
  - [ ] Command is NOT executed when `--help` is present
- [ ] `shellcheck` passes on `wt.sh` and `lib/commands.sh`
- [ ] No regressions in existing `wt -h` output
- [ ] Works in both zsh and bash

---

## Story Points Breakdown

- **Router change (wt.sh):** 0.5 points — add `help` flag, dispatch to `_help_*`
- **Help functions x8 (commands.sh):** 1.5 points — write content for 8 commands
- **BATS tests:** 1 point — one test per command + edge cases
- **Total:** 3 points

**Rationale:** The implementation pattern is clear and mechanical — the same change
repeated 8 times. The main effort is authoring accurate, well-structured help text for
each command and writing the corresponding BATS assertions.

---

## Additional Notes

- The `--help` flag currently falls through to `_cmd_help` (full help). This story keeps
  that behaviour when `--help` is used standalone (no preceding command flag).
- Help text should be kept to 10–15 lines maximum per command to remain readable in
  standard terminal widths (80 columns).
- This story unlocks STORY-038 (placeholder style consistency across `wt -h` and
  per-command help) and STORY-037 (completion hints use the same placeholder vocabulary).

---

## Progress Tracking

**Status History:**

- 2026-02-19: Created by Scrum Master (BMAD workflow)
- 2026-02-20: Implementation started
- 2026-02-20: All implementation complete, tests passing, shellcheck clean

**Actual Effort:** 3 points (matched estimate)

**Files Changed:**

- `wt.sh` (modified) — Added `local help=0` variable; separated `-h` from `--help` in arg-parsing case; added `--help)` case that sets `help=1`; added standalone `--help` pre-dispatch check to call `_cmd_help`; added `if [ "$help" -eq 1 ]` guards before each of the 8 main commands to call the corresponding `_help_*` function.
- `lib/commands.sh` (modified) — Added 8 `_help_*` functions (`_help_new`, `_help_switch`, `_help_open`, `_help_remove`, `_help_list`, `_help_clear`, `_help_init`, `_help_update`) after `_cmd_help`, each using heredoc with description, usage with placeholders, 2–3 examples, and relevant options.
- `test/cmd_help.bats` (modified) — Replaced stub file with 47 tests covering: all 8 `_help_*` functions individually (description, usage, examples, options), 8 short-form router tests (`wt -n/s/o/r/l/c --help`), 8 long-form router tests (`wt --new/switch/open/remove/list/clear/init/update --help`), and 3 edge-case tests (standalone `--help`, reversed order `wt --help -n`, extra args ignored).

**Tests Added:**

- 46 new tests in `test/cmd_help.bats` (file grew from 1 test to 47 tests)

**Test Results:**

- `test/cmd_help.bats`: 47/47 pass
- Full suite: 310/310 pass (no regressions)

**Decisions Made:**

- Split `-h|--help` case into `-h)` (sets `action="help"` for full help) and `--help)` (sets `help=1` for per-command help). This ensures `wt -n --help` correctly shows per-command help while `wt -h` still shows full help.
- Added a pre-dispatch guard: `if [ "$help" -eq 1 ] && [ -z "$action" ]; then _cmd_help; return 0; fi` to handle `wt --help` standalone (no preceding command) showing full help.
- Flag order is commutative: `wt --help -n` and `wt -n --help` both work because both `action` and `help` are parsed before dispatch.
- `lib/commands.sh` is the canonical home for `_help_*` functions (immediately after `_cmd_help`), keeping all help-related code together.
- Shellcheck: only pre-existing SC1091 info warnings (dynamic `source` paths), no new warnings introduced.

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## QA Review

### Files Reviewed

| File | Status | Notes |
|------|--------|-------|
| `wt.sh` | Pass | `local help=0` added; `-h` and `--help` cases correctly split; standalone `--help` pre-dispatch guard present; all 8 command branches include `if [ "$help" -eq 1 ]` guard; POSIX-compliant `[ ... -eq ... ]` arithmetic throughout |
| `lib/commands.sh` | Pass | 8 `_help_*` functions added after `_cmd_help`; all use `cat <<'HELP' ... HELP` heredoc; description, usage with placeholders, 2-3 examples, and options/flags present in each; placeholder style (`<branch>`, `<worktree>`, `<ref>`, `<days>`, `<pattern>`) matches STORY-036 spec |
| `test/cmd_help.bats` | Pass | 47 tests (1 pre-existing + 46 new); covers all 8 `_help_*` functions (description, usage, examples, options), 8 short-form router tests, 8 long-form router tests, and 3 edge cases (standalone `--help`, reversed flag order `wt --help -n`, extra args ignored) |

### Issues Found

None

### AC Verification

- [x] AC 1 — `wt -n --help` prints help for `-n`/`--new` — verified: `wt.sh` line 90 (`if [ "$help" -eq 1 ]; then _help_new; return 0; fi`), test: `wt -n --help shows new command help without executing`
- [x] AC 2 — `wt -s --help` prints help for `-s`/`--switch` — verified: `wt.sh` line 97, test: `wt -s --help shows switch command help without executing`
- [x] AC 3 — `wt -o --help` prints help for `-o`/`--open` — verified: `wt.sh` line 101, test: `wt -o --help shows open command help without executing`
- [x] AC 4 — `wt -r --help` prints help for `-r`/`--remove` — verified: `wt.sh` line 99, test: `wt -r --help shows remove command help without executing`
- [x] AC 5 — `wt -l --help` prints help for `-l`/`--list` — verified: `wt.sh` line 105, test: `wt -l --help shows list command help without executing`
- [x] AC 6 — `wt -c --help` prints help for `-c`/`--clear` — verified: `wt.sh` line 107, test: `wt -c --help shows clear command help without executing`
- [x] AC 7 — `wt --init --help` prints help for `--init` — verified: `wt.sh` line 109, test: `wt --init --help shows init command help without executing`
- [x] AC 8 — `wt --update --help` prints help for `--update` — verified: `wt.sh` line 114, test: `wt --update --help shows update command help without executing`
- [x] AC 9 — Each help block includes description, usage with placeholders, 2-3 examples — verified: all 8 `_help_*` functions in `lib/commands.sh` lines 663-829; tests assert `--partial` for each element
- [x] AC 10 — `--help` after a command flag takes priority, no side effects — verified: guards return before `_cmd_*` calls; router tests assert `refute_output --partial "Creating worktree"` etc.
- [x] AC 11 — Long forms also work (`wt --new --help`, etc.) — verified: long-form aliases share the same `action` variable; 8 long-form router tests pass
- [x] AC 12 — `shellcheck` passes on all modified files — verified: `shellcheck -x wt.sh lib/*.sh` exits 0 with no output

### Test Results

- Total: 310 / Passed: 310 / Failed: 0

### Shellcheck

- Clean: yes

---

## Manual Testing

### Test Scenarios

| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | `bash -c 'source wt.sh; wt -n --help'` | Shows `_help_new` output with description, usage, examples | Output contains "Create a new worktree", `<branch>`, `<ref>`, `wt -n feature-login` | Pass |
| 2 | `bash -c 'source wt.sh; wt --new --help'` | Long-form alias shows same `_help_new` output | Output identical to short-form — "Create a new worktree", `<branch>`, `<ref>` | Pass |
| 3 | `bash -c 'source wt.sh; wt -s --help'` | Shows `_help_switch` output | Output contains "Switch", `<worktree>`, `wt -s feature-login` | Pass |
| 4 | `bash -c 'source wt.sh; wt --switch --help'` | Long-form shows same switch help | Correct per-command help output | Pass |
| 5 | `bash -c 'source wt.sh; wt -o --help'` | Shows `_help_open` output | Output contains "Open", `<branch>`, `wt -o feature-login` | Pass |
| 6 | `bash -c 'source wt.sh; wt --open --help'` | Long-form shows same open help | Correct per-command help output | Pass |
| 7 | `bash -c 'source wt.sh; wt -r --help'` | Shows `_help_remove` output | Output contains "Remove", `<worktree>`, `--force` | Pass |
| 8 | `bash -c 'source wt.sh; wt --remove --help'` | Long-form shows same remove help | Correct per-command help output | Pass |
| 9 | `bash -c 'source wt.sh; wt -l --help'` | Shows `_help_list` output | Output contains "List", `wt -l` | Pass |
| 10 | `bash -c 'source wt.sh; wt --list --help'` | Long-form shows same list help | Correct per-command help output | Pass |
| 11 | `bash -c 'source wt.sh; wt -c --help'` | Shows `_help_clear` output | Output contains `<days>`, `--merged`, `--pattern`, `wt -c 30` | Pass |
| 12 | `bash -c 'source wt.sh; wt --clear --help'` | Long-form shows same clear help | Correct per-command help output | Pass |
| 13 | `bash -c 'source wt.sh; wt --init --help'` | Shows `_help_init` output, no interactive prompts | Output contains "Initialize", `wt --init`; no "Project [" prompt | Pass |
| 14 | `bash -c 'source wt.sh; wt --update --help'` | Shows `_help_update` output, no update attempt | Output contains "Update", `--check`; no "Updating" output | Pass |
| 15 | `bash -c 'source wt.sh; wt --help'` (standalone) | Shows full `_cmd_help` output (existing behavior preserved) | Output contains "wt - Git Worktree Helpers", full command list | Pass |
| 16 | `bash -c 'source wt.sh; wt --help -n'` (reversed order) | Flag order is commutative — shows `_help_new` | Output contains "Create a new worktree" | Pass |
| 17 | `bash -c 'source wt.sh; wt -n --help extra-arg'` (extra args) | `--help` takes priority, extra arg ignored, no worktree created | Shows new help, no "Creating worktree" output | Pass |
| 18 | `bash -c 'source wt.sh; wt -h'` (full help regression) | `wt -h` still shows full help (not per-command) | Output contains "wt - Git Worktree Helpers", unchanged | Pass |
| 19 | `shellcheck -x wt.sh lib/*.sh` | No errors or warnings | No output, exit 0 | Pass |
| 20 | `npm test` (full BATS suite) | 310/310 tests pass | 310/310 passed, 0 failed | Pass |

### Issues Found

None
