# STORY-048: fix install.sh false-positive "Already configured" check

**Epic:** Distribution / Install
**Priority:** Must Have
**Story Points:** 2
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-23
**Sprint:** 7

---

## User Story

As a user running the curl installer to install or update worktree-helpers,
I want the installer to correctly detect whether `wt.sh` is already sourced in my shell config,
So that `wt` is always available in a new terminal after installation completes.

---

## Description

### Background

`install.sh` uses a marker-based check to avoid adding duplicate `source` lines to `.zshrc`/`.bashrc`. The check looks for `# worktree-helpers` anywhere in the rc file. However, this string is not unique — it appears in unrelated comments (e.g. a completions `fpath` comment added during development). When such a comment exists, the installer reports "Already configured" and skips adding the actual `source` line, leaving `wt` unavailable after restarting the terminal.

### Scope

**In scope:**
- Fix the idempotency check to match the actual `source` line, not a generic comment
- Add `test/install.bats` with tests for: fresh install, idempotent re-install, false-positive scenario

**Out of scope:**
- Changes to the install directory structure
- Changes to uninstall.sh behavior

### Reproduction

1. Have `# worktree-helpers: ...` as a comment in `.zshrc` (but NO source line)
2. Run `curl -fsSL .../install.sh | bash`
3. Installer prints "Already configured in ~/.zshrc" — false positive
4. Open new terminal → `wt` command not found

---

## Acceptance Criteria

- [ ] Running installer when only a `# worktree-helpers` comment exists (no source line) adds the source line correctly
- [ ] Running installer twice (source line already present) is idempotent — no duplicate source lines added
- [ ] Installer output accurately reflects what was done ("Added to" vs "Already configured")
- [ ] `wt` is available in a new terminal after curl install on a clean system
- [ ] `test/install.bats` passes: fresh install, idempotent re-run, false-positive comment scenario

---

## Technical Notes

### Root Cause

`install.sh` line 149:
```sh
MARKER="# worktree-helpers"
if [ -f "$RC_FILE" ] && grep -qF "$MARKER" "$RC_FILE"; then
  info "Already configured in $RC_FILE"
```

The `MARKER` matches any comment containing `# worktree-helpers`, not specifically the source line.

### Fix

Change the idempotency check to look for the `SOURCE_LINE` itself:

```sh
SOURCE_LINE="source \"$INSTALL_DIR/wt.sh\""
if [ -f "$RC_FILE" ] && grep -qF "$SOURCE_LINE" "$RC_FILE"; then
  info "Already configured in $RC_FILE"
else
  touch "$RC_FILE"
  {
    echo ""
    echo "# worktree-helpers"
    echo "$SOURCE_LINE"
  } >> "$RC_FILE"
  info "Added to $RC_FILE"
fi
```

### Tests (`test/install.bats`)

Test cases to cover:
1. **Fresh install** — source line added when rc file has no worktree-helpers content
2. **Idempotent re-run** — source line NOT duplicated when already present
3. **False-positive comment** — source line IS added when only `# worktree-helpers` comment exists (no source line)

Test approach: create a temp rc file, call the relevant logic (or the full script with `--local`), assert rc file contents.

---

## Dependencies

None

---

## Definition of Done

- [ ] `install.sh` check updated to match `SOURCE_LINE` instead of `MARKER`
- [ ] `test/install.bats` created with ≥3 test cases and all passing
- [ ] `./install.sh --local` correctly adds source line when only comment exists in rc file
- [ ] `npm test` passes (all tests green)
- [ ] `_help_update` or relevant `--help` output unchanged (no user-visible command change)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
