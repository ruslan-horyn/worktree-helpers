# STORY-049: Install `wt` as executable binary for non-interactive shell support

**Epic:** Distribution & Installation
**Priority:** Should Have
**Story Points:** 3
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-24
**Sprint:** Backlog

---

## User Story

As a developer using non-interactive shells (Claude Code, CI scripts, subprocesses),
I want `wt` to be available as an executable binary on my PATH,
So that I can invoke `wt` commands without needing to source `~/.zshrc` first.

---

## Description

### Background

Currently, `wt` is a shell function defined by `source ~/.worktree-helpers/wt.sh` in `~/.zshrc` or `~/.bashrc`. This works for interactive terminal sessions, but non-interactive shells — such as Claude Code subprocesses, CI scripts, `bash -c "..."` invocations, and tool runners — do not source `~/.zshrc`. As a result, `wt` is not found (`command not found`) in these contexts.

The root cause is that `wt.sh` defines the `wt()` function but does not invoke it when executed directly as a script. The file exits after defining the function without calling it.

### Scope

**In scope:**
- Make `wt.sh` dual-mode: sourceable (current behaviour) and directly executable as a binary
- `install.sh`: create `~/.local/bin/wt` symlink pointing to `~/.worktree-helpers/wt.sh`, set executable bit, warn if `~/.local/bin` is not in PATH
- `uninstall.sh`: remove the `~/.local/bin/wt` symlink on uninstall
- `_cmd_remove` (`lib/commands.sh`): replace silent `cd` fallback with an explicit error when user is inside the worktree being removed
- `_cmd_clear` (`lib/commands.sh`): same fix — error and skip worktrees the user is currently inside
- BATS tests: verify `wt.sh` works when invoked as an executable
- Update `_help_*` function(s) and README per Definition of Done

**Out of scope:**
- Changing the `wt -o`/`wt -s` `cd` behaviour in a subprocess context (a subprocess `cd` cannot change the parent shell's directory; this is a known shell limitation, not a bug in this story)
- Homebrew formula or system-wide installation paths
- Changing the shell completions mechanism

### User Flow

**Executable binary path:**
1. User installs worktree-helpers with `install.sh`
2. Installer creates `~/.local/bin/wt` → `~/.worktree-helpers/wt.sh` and sets `chmod +x`
3. If `~/.local/bin` is not in PATH, installer prints a warning with instructions
4. User opens a new terminal (or non-interactive shell) and runs `wt -l`
5. `wt.sh` detects it is being executed (not sourced), calls `wt "$@"` with the passed arguments
6. Command runs and exits normally

**Removal path:**
1. User runs `wt --uninstall` or `./uninstall.sh`
2. Uninstaller removes `~/.local/bin/wt` in addition to existing cleanup

---

## Acceptance Criteria

1. [x] **AC-1 — Executable invocation works:** `bash <path>/wt.sh -v` exits 0 and prints the version string without `command not found` or any other error.
2. [x] **AC-2 — Symlink created by install.sh:** After running `install.sh --local`, `~/.local/bin/wt` exists as a symlink pointing to `~/.worktree-helpers/wt.sh`, and `wt.sh` has its executable bit set (`-x`).
3. [x] **AC-3 — Symlink binary is invocable:** Invoking the symlink directly (`~/.local/bin/wt -v`) exits 0 and prints the version string.
4. [x] **AC-4 — install.sh warns when `~/.local/bin` is absent from PATH:** When `$PATH` does not contain `~/.local/bin`, `install.sh` prints a warning message containing the text `~/.local/bin is not in your PATH` (or equivalent) and an `export PATH` instruction.
5. [x] **AC-5 — install.sh does NOT warn when `~/.local/bin` is in PATH:** When `$PATH` already contains `~/.local/bin`, no PATH warning is printed.
6. [x] **AC-6 — uninstall.sh removes the symlink:** After install, running `uninstall.sh --force` removes `~/.local/bin/wt`; the path no longer exists.
7. [x] **AC-7 — uninstall.sh is a no-op when symlink is absent:** Running `uninstall.sh --force` when `~/.local/bin/wt` does not exist exits 0 without error.
8. [x] **AC-8 — Sourcing wt.sh does NOT invoke `wt "$@"`:** When `wt.sh` is sourced in bash, the `wt()` function is defined but not called; sourcing exits 0 with no output (no regression).
9. [x] **AC-9 — `_cmd_remove` inside-worktree error:** Calling `_cmd_remove <branch> 1` (force) while `$PWD` equals the worktree path prints `"Cannot remove: you are inside this worktree. Please cd out first."` to stderr and returns non-zero.
10. [x] **AC-10 — `_cmd_remove` inside-subdirectory error:** Calling `_cmd_remove <branch> 1` while `$PWD` is a subdirectory of the worktree (e.g. `<wt_path>/src`) also errors with the same message and returns non-zero.
11. [x] **AC-11 — `_cmd_clear` inside-worktree skips with error:** When `$PWD` equals a worktree being cleared, that worktree is skipped with a message containing `"Cannot clear: you are inside worktree"` and the command continues to remove other qualifying worktrees (exit 0).
12. [x] **AC-12 — `_cmd_clear` inside-subdirectory skips with error:** When `$PWD` is inside a subdirectory of the worktree being cleared, the same skip-with-error behaviour applies.
13. [x] **AC-13 — `_cmd_remove` outside worktree succeeds:** Calling `_cmd_remove <branch> 1` while `$PWD` is the repo root (not inside the target worktree) removes the worktree and exits 0 (no regression).

---

## Technical Notes

### Components

- **`wt.sh`** — add dual-mode detection at the end of the file (after `wt()` definition and completions)
- **`install.sh`** — add Step 3b: create symlink and check PATH
- **`uninstall.sh`** — add symlink removal step
- **`lib/commands.sh`** — fix `_cmd_remove` (line 36) and `_cmd_clear` (line 390)
- **`test/cmd_remove.bats`** or new `test/executable.bats` — BATS tests

### Dual-Mode Detection (`wt.sh`)

Add at the end of `wt.sh`, after all definitions:

```sh
_wt_is_sourced() {
  [ -n "${ZSH_VERSION:-}" ] && case "${ZSH_EVAL_CONTEXT:-}" in *:file*) return 0;; esac
  [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ] && return 0
  return 1
}
_wt_is_sourced || wt "$@"
```

This pattern is safe:
- When sourced in zsh: `ZSH_EVAL_CONTEXT` contains `file`, so `_wt_is_sourced` returns 0 (truthy), the `||` short-circuits, `wt "$@"` is NOT called
- When sourced in bash: `BASH_SOURCE[0]` differs from `$0`, same result
- When executed directly: neither condition is true, `_wt_is_sourced` returns 1, `wt "$@"` IS called

### Symlink Creation (`install.sh`)

Add after current Step 3 (shell/rc detection), before Step 5 (success message):

```sh
# Step 4b: Create binary symlink in ~/.local/bin
LOCAL_BIN="$HOME/.local/bin"
SYMLINK="$LOCAL_BIN/wt"

chmod +x "$INSTALL_DIR/wt.sh"
mkdir -p "$LOCAL_BIN"

# Remove stale symlink if present
[ -L "$SYMLINK" ] && rm "$SYMLINK"

ln -s "$INSTALL_DIR/wt.sh" "$SYMLINK"
info "Created binary: $SYMLINK -> $INSTALL_DIR/wt.sh"

# Warn if ~/.local/bin is not in PATH
case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    warn "~/.local/bin is not in your PATH."
    warn "Add this to your shell config to use 'wt' as a binary:"
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac
```

### Symlink Removal (`uninstall.sh`)

Add to the removal steps:

```sh
SYMLINK="$HOME/.local/bin/wt"
if [ -L "$SYMLINK" ]; then
  rm "$SYMLINK"
  info "Removed binary symlink: $SYMLINK"
fi
```

Also update detection at the top to set `FOUND_SYMLINK`:

```sh
FOUND_SYMLINK=0
[ -L "$HOME/.local/bin/wt" ] && FOUND_SYMLINK=1
```

### `_cmd_remove` Fix (`lib/commands.sh`, line 36)

Replace the silent `cd` fallback:

```sh
# Before (line 36):
if [ "$PWD" = "$wt_path" ]; then cd "$(_repo_root)" || true; fi

# After:
case "$PWD" in
  "$wt_path"|"$wt_path"/*)
    _err "Cannot remove: you are inside this worktree. Please cd out first."
    return 1 ;;
esac
```

### `_cmd_clear` Fix (`lib/commands.sh`, line 390)

Replace the silent `cd` fallback in the `while` loop:

```sh
# Before (line 390):
if [ "$PWD" = "$wt_path" ]; then cd "$main_root" || true; fi

# After:
case "$PWD" in
  "$wt_path"|"$wt_path"/*) _err "Cannot clear: you are inside worktree '$br'. Please cd out first."; continue ;;
esac
```

### POSIX Compatibility

- `_wt_is_sourced` uses only `case` and POSIX `[ ]` — no bash/zsh-specific syntax inside the function body
- The `${ZSH_VERSION:-}` and `${BASH_VERSION:-}` checks are POSIX-safe (default expansion)
- `ZSH_EVAL_CONTEXT` is a zsh variable, only checked inside the zsh branch

### Edge Cases

- Symlink already exists from a previous install: remove and recreate
- `~/.local/bin` does not exist: `mkdir -p` creates it
- User is inside a subdirectory of the worktree (not just its root): `case "$PWD" in "$wt_path"/*)` covers this

---

## Dependencies

**Prerequisite Stories:** None

**Blocked Stories:** None

**External Dependencies:** None

---

## Definition of Done

- [x] `wt.sh`: `_wt_is_sourced` function added at end of file (after completions block); `_wt_is_sourced || wt "$@"` line present
- [x] `wt.sh`: sourcing in bash still defines `wt()` without calling it (no regression verified by AC-8 test)
- [x] `wt.sh`: direct execution with `bash wt.sh -v` exits 0 (verified by AC-1 test)
- [x] `install.sh`: `chmod +x "$INSTALL_DIR/wt.sh"` called before symlink creation
- [x] `install.sh`: `mkdir -p "$HOME/.local/bin"` and `ln -s` symlink creation step present
- [x] `install.sh`: stale symlink detection (`[ -L "$SYMLINK" ] && rm "$SYMLINK"`) present before `ln -s`
- [x] `install.sh`: PATH check using `case ":$PATH:" in *":$LOCAL_BIN:"*)` present with `warn` on miss
- [x] `uninstall.sh`: symlink removal block (`[ -L "$SYMLINK" ] && rm "$SYMLINK"`) present
- [x] `lib/commands.sh` `_cmd_remove`: `if [ "$PWD" = "$wt_path" ]; then cd ...` replaced by `case "$PWD" in "$wt_path"|"$wt_path"/*) _err ...` guard
- [x] `lib/commands.sh` `_cmd_clear`: same replacement in the `while` loop deletion block
- [x] `test/STORY-049.bats` created with tests for all 13 AC items
- [x] `npm test` green (all new tests pass, no existing tests broken)
- [x] `shellcheck -x wt.sh` passes with no new errors
- [x] `shellcheck -x install.sh` passes with no new errors
- [x] `shellcheck -x uninstall.sh` passes with no new errors
- [x] `wt --help` output updated to mention the binary/symlink installation path
- [x] README updated: 1-3 lines added to the Installation section describing `~/.local/bin/wt` availability

---

## Story Points Breakdown

- **`wt.sh` dual-mode:** 0.5 points
- **`install.sh` symlink + PATH check:** 0.5 points
- **`uninstall.sh` symlink removal:** 0.5 points
- **`_cmd_remove` / `_cmd_clear` fix:** 0.5 points
- **BATS tests:** 1 point
- **Total:** 3 points

**Rationale:** Each individual change is small; the story is 3 points because of the breadth across 5 files and the need for thorough test coverage including executable invocation tests.

---

## Additional Notes

Commands that work correctly as binary invocations (no interactive shell needed): `wt -n <branch>`, `wt -l`, `wt -r <branch>`, `wt --update`, `wt -v`, `wt --help`.

Commands that involve directory change (`wt -o`, `wt -s`) will run but the resulting `cd` (via hook) will not affect the parent process's working directory — this is an inherent shell limitation, not a bug to fix in this story.

---

## Pattern Guidelines

Guidelines for Dev when implementing this story. Relevant sections only.

### Guard Clauses

Validate at the top of every function, return early on failure. Never nest happy-path logic inside `if` blocks.

For `_cmd_remove`, the inside-worktree check must come **before** any git operations:

```sh
# Guard: must come before git worktree remove
case "$PWD" in
  "$wt_path"|"$wt_path"/*)
    _err "Cannot remove: you are inside this worktree. Please cd out first."
    return 1 ;;
esac
```

For `_cmd_clear`, the guard goes inside the deletion loop with `continue` (not `return`) so other worktrees are still processed:

```sh
case "$PWD" in
  "$wt_path"|"$wt_path"/*) _err "Cannot clear: you are inside worktree '$br'. Please cd out first."; continue ;;
esac
```

### POSIX Compatibility

All changes to `wt.sh`, `lib/commands.sh`, `install.sh`, and `uninstall.sh` must be POSIX-compatible sh syntax. No bash arrays, no `[[ ]]`, no `(( ))`. Use `case` instead of `if [[ ]]` for pattern matching. The `_wt_is_sourced` function is the only place that uses `${ZSH_VERSION:-}` and `${BASH_VERSION:-}` — both are POSIX-safe default expansions.

### Single Responsibility

`_wt_is_sourced` does one thing: returns 0 if being sourced, 1 if executed. It must not have side effects. The dispatcher line `_wt_is_sourced || wt "$@"` is placed after all definitions (after the completions block at the end of `wt.sh`).

### Utility Reuse (DRY)

- Use `_err` (from `lib/utils.sh`) for all error messages in `_cmd_remove` and `_cmd_clear`.
- Use `_info` for informational messages in `install.sh`/`uninstall.sh`.
- Do not re-implement path prefix checking — use `case "$PWD" in "$wt_path"|"$wt_path"/*)`.

### Output Streams

- Errors in `_cmd_remove` and `_cmd_clear` go to stderr via `_err`.
- Informational messages in `install.sh` and `uninstall.sh` go to stdout via `info`.
- Warnings in `install.sh` go to stdout via `warn`.

### Config as Data

`$GWT_WORKTREES_DIR` is available after `_config_load` is called (which happens inside `_cmd_clear` at the start via `_config_load || return 1`). The `wt_path` variable used in the guard is resolved via `_wt_resolve`, which is also called at the start of `_cmd_remove`.

### Install/Uninstall Script Pattern

Both `install.sh` and `uninstall.sh` use `set -euo pipefail`. The symlink creation step must handle the stale-symlink case before `ln -s`:

```sh
[ -L "$SYMLINK" ] && rm "$SYMLINK"
ln -s "$INSTALL_DIR/wt.sh" "$SYMLINK"
```

`uninstall.sh` uses a conditional check (not `set -e` safe `rm -f`) to avoid errors when the symlink is absent:

```sh
if [ -L "$SYMLINK" ]; then
  rm "$SYMLINK"
  info "Removed binary symlink: $SYMLINK"
fi
```

---

## Progress Tracking

**Status History:**
- 2026-02-24: Created by Scrum Master
- 2026-02-27: AC and DoD reviewed and hardened by QA; BATS tests written (test/STORY-049.bats)
- 2026-02-27: Implementation complete by Developer

**Actual Effort:** 3 points (matched estimate)

**Files Changed:**
- `wt.sh` — added `_wt_is_sourced` function and `_wt_is_sourced || wt "$@"` dual-mode dispatcher at end of file (after completions block)
- `install.sh` — added Step 4b: `chmod +x`, `mkdir -p ~/.local/bin`, symlink creation with stale-symlink removal, and PATH warning
- `uninstall.sh` — added `FOUND_SYMLINK` detection, symlink display in removal list, and symlink removal step (Step 2)
- `lib/commands.sh` — replaced silent `cd` fallback in `_cmd_remove` and `_cmd_clear` with explicit `case`-based guard returning error messages
- `lib/commands.sh` — added "Installation" section to `_cmd_help` output describing `~/.local/bin/wt` binary
- `README.md` — added "Binary installation" subsection under Installation describing `~/.local/bin/wt` availability

**Test Results:**
- `test/STORY-049.bats`: 37/37 tests pass (all 13 AC items covered + edge cases)
- Full suite: 476/476 tests pass (no regressions)
- `shellcheck -x wt.sh lib/commands.sh install.sh uninstall.sh`: clean

**Decisions Made:**
- Used `# shellcheck disable=SC2088` on the `~/.local/bin is not in your PATH.` warn line because the tilde is intentional display text (not a path expansion), and the AC-4 test explicitly checks for the `~/.local/bin` literal string in output
- Uninstall Step 2 uses `if [ -L "$SYMLINK" ]` (not `set -e`-breaking `rm -f`) per Pattern Guidelines
- `_wt_is_sourced` placed after completions block as required by Pattern Guidelines (Single Responsibility)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## QA Review

### Files Reviewed
| File | Status | Notes |
|------|--------|-------|
| `wt.sh` | Pass | `_wt_is_sourced` added correctly after completions block; `_wt_is_sourced \|\| wt "$@"` dispatcher present |
| `install.sh` | Pass | Step 4b complete: `chmod +x`, `mkdir -p`, stale-symlink removal, `ln -s`, PATH check with `case` |
| `uninstall.sh` | Pass | `FOUND_SYMLINK` detection, display in removal list, `if [ -L ... ]` removal block present |
| `lib/commands.sh` | Pass | `_cmd_remove` and `_cmd_clear` guards replaced with `case`; Installation section added to `_cmd_help` |
| `README.md` | Pass | Binary installation subsection added under Installation |
| `test/STORY-049.bats` | Pass | 37 tests covering all 13 AC items plus 5 edge cases |

### Issues Found
None

### AC Verification
- [x] AC-1 — verified: `wt.sh` lines 151-156; test: `AC-1: bash wt.sh -v exits 0 and prints non-empty version output` (and 2 further AC-1 tests)
- [x] AC-2 — verified: `install.sh` lines 165-176; test: `AC-2: install.sh --local creates ~/.local/bin/wt symlink` (and 3 further AC-2 tests)
- [x] AC-3 — verified: `install.sh` symlink creation; test: `AC-3: invoking the ~/.local/bin/wt symlink with -v exits 0`
- [x] AC-4 — verified: `install.sh` lines 179-187; test: `AC-4: install.sh warns when ~/.local/bin is not in PATH`
- [x] AC-5 — verified: `install.sh` `case ":$PATH:"` check; test: `AC-5: install.sh does not print PATH warning when ~/.local/bin is in PATH`
- [x] AC-6 — verified: `uninstall.sh` lines 141-144; test: `AC-6: uninstall.sh --force removes ~/.local/bin/wt symlink`
- [x] AC-7 — verified: `uninstall.sh` `if [ -L ... ]` guard; test: `AC-7: uninstall.sh --force exits 0 when ~/.local/bin/wt does not exist`
- [x] AC-8 — verified: `wt.sh` line 156 `_wt_is_sourced || wt "$@"`; test: `AC-8: sourcing wt.sh in bash defines wt() without calling it` (and 2 further AC-8 tests)
- [x] AC-9 — verified: `lib/commands.sh` lines 36-40; test: `AC-9: _cmd_remove prints error when inside the target worktree` (and 2 further AC-9 tests)
- [x] AC-10 — verified: `lib/commands.sh` `"$wt_path"/*)` branch of `case`; test: `AC-10: _cmd_remove errors when PWD is a subdirectory of the target worktree`
- [x] AC-11 — verified: `lib/commands.sh` lines 412-416 with `continue`; test: `AC-11: _cmd_clear prints 'Cannot clear' when inside a worktree being cleared` (and 3 further AC-11 tests)
- [x] AC-12 — verified: same guard covers subdirectory via `"$wt_path"/*)` pattern; test: `AC-12: _cmd_clear prints 'Cannot clear' when inside a subdirectory of a worktree`
- [x] AC-13 — verified: no regression — guard only activates when `$PWD` matches or is under `$wt_path`; test: `AC-13: _cmd_remove removes worktree normally when called from repo root`

### Pattern Guidelines Compliance

| Pattern | Status | Issues |
|---------|--------|--------|
| Guard Clauses | compliant | `_cmd_remove` guard comes before git operations (line 36, after `_wt_resolve`). `_cmd_clear` guard is inside deletion loop with `continue` so other worktrees still process. Happy paths are not nested inside `if`. |
| Single Responsibility | compliant | `_wt_is_sourced` has no side effects; returns 0 or 1 only. Dispatcher is a single line after all definitions. Functions are not longer than ~20 lines for new additions. |
| Command Router | n/a | No new command flag was added; existing router and handlers unchanged. |
| Utility Reuse (DRY) | compliant | `_err` used for all error messages in `_cmd_remove` and `_cmd_clear`. `_info` used in `install.sh`/`uninstall.sh`. `case "$PWD" in "$wt_path"\|"$wt_path"/*)` is consistent with pattern guidelines, not duplicated. |
| Output Streams | compliant | `_err` routes to stderr; `_info` and `info`/`warn` in shell scripts route to stdout. No error text on stdout in new code. |
| Hook/Extension Pattern | n/a | No new lifecycle hooks introduced. |
| Config as Data | n/a | No new config values added. Existing `_config_load` / `GWT_*` globals used where needed. |

### Test Results
- Total: 476 / Passed: 476 / Failed: 0
- STORY-049.bats: 37 tests (all AC items + 5 edge cases)

### Shellcheck
- Clean: yes — `shellcheck -x wt.sh`, `shellcheck -x lib/commands.sh`, `shellcheck -x install.sh`, `shellcheck -x uninstall.sh` all pass with no errors (`SC2088` suppressed intentionally on tilde display string per developer decision note)
