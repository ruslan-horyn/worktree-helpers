# STORY-040: Run command in another worktree without switching (`wt --run`)

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 4
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** Backlog

---

## User Story

As a developer working in one worktree
I want to run a command in a different worktree without switching to it
So that I can execute quick tasks (tests, linting, builds) without losing my current context

---

## Description

### Background

Running `npm test` or `npm run lint` in a different worktree currently requires a three-step process: `wt -s <branch>` to switch, execute the command, then `wt -s <back>` to return. This context-switching overhead is disruptive when the intent is only to inspect or verify something in another worktree — not to work in it.

`wt --run <worktree> <cmd>` addresses this by executing the command directly in the target worktree's directory via a subshell, printing output inline, then returning the shell to the current directory with the original exit code preserved.

### Scope

**In scope:**
- `wt --run <worktree> <cmd>` executes `<cmd>` in the named worktree's directory
- fzf picker if worktree name is omitted (then prompt for command)
- stdout and stderr passed through transparently to the caller
- Exit code of `<cmd>` is propagated to the caller
- Hooks are NOT triggered (this is an execution shortcut, not a worktree switch)
- Works in both bash and zsh
- Per-command `--help` via `wt --run --help`
- README updated with 1-3 lines describing the feature

**Out of scope:**
- `wt --run-all <cmd>` to execute across all worktrees in parallel (separate story)
- `wt --run <worktree>` with no command opening an interactive shell in that dir (potential future enhancement; noted below)
- Storing or logging run history

### User Flow

1. Developer is in worktree `feature-login`, wants to check tests in `feature-auth`
2. Developer runs: `wt --run feature-auth "npm test"`
3. `wt` resolves the worktree path for `feature-auth`
4. `wt` runs `sh -c "npm test"` inside `(cd <feature-auth-path> && ...)` subshell
5. stdout and stderr stream to the terminal inline
6. Shell returns to `feature-login` directory; exit code from `npm test` is returned

---

## Acceptance Criteria

- [ ] `wt --run <worktree> <cmd>` runs `<cmd>` in the target worktree's directory
- [ ] If `<worktree>` is not found: clear error message printed to stderr, non-zero exit code returned
- [ ] stdout and stderr from `<cmd>` are passed through to the caller without buffering
- [ ] Exit code of `<cmd>` is preserved and returned to the caller (non-zero propagated)
- [ ] If no arguments given: fzf picker selects worktree, then user is prompted for a command string
- [ ] Hooks (`created`, `switched`) are NOT triggered
- [ ] Works in bash and zsh (POSIX-compatible subshell invocation)
- [ ] `wt --run --help` prints usage and examples
- [ ] README includes 1-3 lines describing `wt --run`

---

## Technical Notes

### Components Affected

- **`lib/commands.sh`** — add `_cmd_run` function and `_help_run` function
- **`wt.sh`** (router) — add `--run` flag parsing and dispatch to `_cmd_run`; add `--help` dispatch for `run` action
- **`_cmd_help`** in `lib/commands.sh` — add `--run` line to the commands table
- **`completions/`** — add `--run` to both zsh (`completions/_wt`) and bash (`completions/wt.bash`) completions
- **README** — add 1-3 lines to the Commands section

### Implementation Approach

```sh
_cmd_run() {
  local input="$1" cmd="$2"
  _repo_root >/dev/null && _config_load || return 1

  # fzf picker if no worktree specified
  if [ -z "$input" ]; then
    input=$(_wt_select "run> ") || return 1
    [ -z "$input" ] && { _err "No worktree selected"; return 1; }
  fi

  # Resolve worktree name -> path (reuses existing _wt_resolve)
  local wt_path
  wt_path=$(_wt_resolve "$input" "run> ") || return 1

  # Prompt for command if none given
  if [ -z "$cmd" ]; then
    printf "Command to run in %s: " "$(_wt_display_name "$wt_path")" >&2
    read -r cmd
    [ -z "$cmd" ] && { _err "No command provided"; return 1; }
  fi

  # Execute in subshell; exit code propagates
  (cd "$wt_path" && sh -c "$cmd")
}
```

Key implementation notes:
- Use `(cd "$wt_path" && sh -c "$cmd")` — the subshell ensures the caller's `$PWD` is not affected
- `_wt_resolve` already handles both direct path and branch-name lookup; reuse it
- Do NOT call `_run_hook` — this is an execution shortcut, not a worktree switch
- Exit code is naturally propagated because the subshell's exit code becomes `_cmd_run`'s exit code
- For multi-word commands, the user passes them quoted: `wt --run feature-auth "npm test -- --watch"`
- The router must capture the rest of the positional args as the command string; a `run_cmd` variable (separate from `arg`) is needed in `wt()` to hold the full command string

### Router Changes (wt.sh)

Add `run_cmd` local variable. Parsing:

```sh
--run) action="run"; shift
       case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac
       case "${1:-}" in -*|"") ;; *) run_cmd="$1"; shift ;; esac ;;
```

Dispatch:

```sh
run) if [ "$help" -eq 1 ]; then _help_run; return 0; fi
     _cmd_run "$arg" "$run_cmd" ;;
```

### `_help_run` Function

```sh
_help_run() {
  cat <<'HELP'

  wt --run [<worktree>] [<cmd>]

  Run a shell command in a target worktree's directory without switching to it.
  Hooks are not triggered. Exit code of <cmd> is preserved.

  Usage:
    wt --run <worktree> <cmd>   Run command in named worktree
    wt --run                    Pick worktree with fzf, then prompt for command

  Examples:
    wt --run feature-auth "npm test"
    wt --run hotfix-v2 "npm run lint"
    wt --run develop "make build"

HELP
}
```

### Completions

- Add `--run` to both `completions/_wt` (zsh) and `completions/wt.bash` (bash)
- After `--run`, complete with worktree names (same logic as `--switch`)

### Edge Cases

- Worktree name not found: delegate to existing `_wt_resolve` error handling
- Command is empty string after fzf: error and non-zero exit
- Command fails with non-zero: propagate exit code; do not print extra error text (let the command's own stderr speak)
- No fzf available and no worktree arg: `_wt_select` already emits "Install fzf or pass branch" error

---

## Dependencies

- None. `_wt_resolve` and `_wt_select` are already implemented and can be reused directly.

---

## Definition of Done

- [ ] `_cmd_run` implemented in `lib/commands.sh`
- [ ] `_help_run` added to `lib/commands.sh`
- [ ] `--run` flag added to `wt()` router in `wt.sh` with correct parsing and dispatch
- [ ] `--run` line added to `_cmd_help` commands table
- [ ] `--run` added to zsh completions (`completions/_wt`)
- [ ] `--run` added to bash completions (`completions/wt.bash`)
- [ ] BATS tests written in `test/cmd_run.bats`:
  - [ ] Runs command in target worktree directory
  - [ ] Exit code is preserved (both 0 and non-zero)
  - [ ] Error when worktree not found
  - [ ] Hooks are NOT invoked
  - [ ] Caller's `$PWD` is unchanged after the run
- [ ] All existing tests pass (`npm test`)
- [ ] shellcheck passes with no new warnings
- [ ] README updated with 1-3 lines about `wt --run`
- [ ] `wt --run --help` prints expected output
- [ ] Acceptance criteria all checked off

---

## Story Points Breakdown

- **Core `_cmd_run` + `_help_run`:** 1 point
- **Router integration + completions:** 1 point
- **BATS test suite (`test/cmd_run.bats`):** 2 points
- **Total:** 4 points

**Rationale:** The command logic is straightforward (subshell + existing `_wt_resolve`). Most effort goes into the test suite which must cover exit code propagation, hook suppression, and directory isolation.

---

## Additional Notes

- Future consideration: `wt --run <worktree>` with no `<cmd>` could drop the user into an interactive shell in that directory. Deferred — interactive subshells have tricky UX implications and are not needed for the core use case.
- Future story: `wt --run-all <cmd>` to fan out a command across all worktrees (e.g., `git fetch --all`).

---

## Progress Tracking

**Status History:**
- 2026-02-21: Draft created
- 2026-02-22: Formalized by Scrum Master

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
