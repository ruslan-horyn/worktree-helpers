# STORY-049: Install `wt` as executable binary for non-interactive shell support

**Epic:** Distribution & Installation
**Priority:** Should Have
**Story Points:** 3
**Status:** Backlog
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

- [ ] `bash ~/.worktree-helpers/wt.sh -l` lists worktrees (or shows appropriate error) without `command not found`
- [ ] `~/.local/bin/wt -l` works after a fresh install (symlink resolves to `wt.sh`, binary is executable)
- [ ] `install.sh` creates the `~/.local/bin/wt` symlink and sets `chmod +x ~/.worktree-helpers/wt.sh`
- [ ] `install.sh` prints a warning if `~/.local/bin` is not in `$PATH`
- [ ] `uninstall.sh` removes `~/.local/bin/wt` symlink if it exists
- [ ] Sourcing `wt.sh` in an interactive shell continues to work exactly as before (no regression)
- [ ] `wt -r <branch>` while inside that worktree prints `"Cannot remove: you are inside this worktree. Please cd out first."` and exits non-zero
- [ ] `wt -c` while inside a worktree being cleared prints `"Cannot clear: you are inside worktree '<name>'. Please cd out first."` and skips that worktree (continues clearing others)
- [ ] BATS tests cover: executable invocation (`bash wt.sh -v`), `_cmd_remove` inside-worktree error, `_cmd_clear` inside-worktree error
- [ ] `wt --help` and README updated to mention binary installation

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

- [ ] `wt.sh` dual-mode detection added (end of file, after completions)
- [ ] `install.sh` creates `~/.local/bin/wt` symlink and sets executable bit
- [ ] `install.sh` warns if `~/.local/bin` not in PATH
- [ ] `uninstall.sh` removes `~/.local/bin/wt` symlink
- [ ] `_cmd_remove`: inside-worktree check added, returns non-zero with clear error
- [ ] `_cmd_clear`: inside-worktree check added, skips with clear error, continues other worktrees
- [ ] BATS tests added (at minimum: executable invocation, `_cmd_remove` inside-worktree, `_cmd_clear` inside-worktree)
- [ ] All existing tests still pass (`npm test` green)
- [ ] `shellcheck -x wt.sh` and `shellcheck -x install.sh` clean
- [ ] `_help_install` or `wt --help` mentions binary availability
- [ ] README updated (1-3 lines in Installation or Commands section)

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

## Progress Tracking

**Status History:**
- 2026-02-24: Created by Scrum Master

**Actual Effort:** TBD (will be filled during/after implementation)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
