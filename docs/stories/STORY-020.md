# STORY-020: Add uninstall script

**ID:** STORY-020
**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2

## User Story

As a user
I want to cleanly uninstall worktree-helpers with a single command
So that I can remove the tool without leaving leftover files or shell config lines

## Acceptance Criteria

- [ ] `uninstall.sh` script removes `~/.worktree-helpers` directory
- [ ] Script removes the `# worktree-helpers` marker and `source` line from shell rc file (`.zshrc`, `.bashrc`, or `.bash_profile`)
- [ ] Script auto-detects the user's shell (same logic as `install.sh`)
- [ ] Confirmation prompt before deletion (user must confirm with `y`)
- [ ] `--force` flag to skip confirmation prompt
- [ ] Handles case where tool is not installed (exits cleanly with message)
- [ ] Does not touch project-level `.worktrees/` config directories
- [ ] Clear success/failure output with colored messages
- [ ] `wt --uninstall` flag in the router delegates to the uninstall script

## Technical Notes

- Mirror the install script structure: same `INSTALL_DIR`, `MARKER`, shell detection logic
- Remove the two lines added by installer: `# worktree-helpers` marker + `source "..."` line
- Use `sed` to remove lines from rc file (POSIX-compatible, handle both GNU and BSD `sed`)
- The `--uninstall` router flag should call the uninstall script from `$INSTALL_DIR/uninstall.sh`
- Ship `uninstall.sh` alongside `install.sh` in the repo root; copy it to `$INSTALL_DIR` during install

## Dependencies

- None

## Definition of Done

- [ ] `uninstall.sh` implemented and tested manually on macOS
- [ ] `wt --uninstall` flag works from the router
- [ ] BATS tests cover uninstall logic
- [ ] Shellcheck passes
- [ ] Help text updated (`wt -h`)
- [ ] Install script updated to also copy `uninstall.sh` to install dir
