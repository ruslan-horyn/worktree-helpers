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

**Actual Effort:** TBD (will be filled during/after implementation)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
