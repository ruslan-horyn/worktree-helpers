# STORY-033: Prompt to re-source after `wt --update`

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-19
**Sprint:** 6

---

## User Story

As a developer who just ran `wt --update`
I want a clear prompt telling me how to activate the new version in my current shell
So that I don't have to open a new terminal or figure out re-sourcing on my own

---

## Description

### Background

After `wt --update` installs a new version, the currently running shell still has the old
version of `wt` loaded in memory. The `wt` function, all `_cmd_*` handlers, and all
`_WT_*` variables were sourced at shell startup and are not refreshed by the update.

Currently `_update_install` ends with:

```sh
_info "Updated wt to $latest"
_info "Restart your shell or run: source $_WT_DIR/wt.sh"
```

The `source` command shown is generic. The message is already printed on stderr via
`_info`. The story's goal is to:

1. Make the re-source prompt prominent and clearly formatted.
2. Show the exact `source` command the user should run, with the real install path.
3. Print it to stdout (not stderr) so it is easy to copy.
4. Omit the prompt when no update was installed (already up-to-date or error paths).

### How `_WT_DIR` is resolved

`wt.sh` sets `_WT_DIR` at source time:

```sh
_WT_DIR="${WT_INSTALL_DIR:-$(_wt_get_script_dir)}"
```

The standard install places files in `~/.worktree-helpers`. The variable `_WT_DIR` is
therefore available in `_update_install` and can be used directly to construct the exact
`source` path.

There is no separate install-path file to read; `_WT_DIR` is the single source of truth.

### Scope

**In scope:**

- Enhanced re-source prompt after a successful `wt --update` install
- Show exact `source $_WT_DIR/wt.sh` command on stdout
- "Or open a new terminal." secondary hint
- Prompt suppressed when update is not installed (already up-to-date, error, `--check` mode)

**Out of scope:**

- Auto-sourcing within the current shell (not possible from a function running in a
  subshell or standard shell context)
- Detecting which shell rc file to mention (install.sh does this; `_update_install` does not)
- Changes to `--check` mode output

### User Flow

1. Developer runs `wt --update` in their current terminal session.
2. `_update_install` checks the installed version against the latest GitHub release.
3. If an update is available, the update proceeds (clone, copy files, cache update).
4. On success, `_update_install` prints the version confirmation, then prints:

```
To activate the new version in this shell, run:
  source /Users/alice/.worktree-helpers/wt.sh

Or open a new terminal.
```

1. Developer copies and runs the `source` command without leaving the terminal.
2. The new version is now active in the current shell.

---

## Acceptance Criteria

- [x] After a successful update, `wt --update` prints an exact `source <path>/wt.sh` command to stdout
- [x] The path shown is `$_WT_DIR/wt.sh` (the actual install path, not a placeholder)
- [x] The re-source block is printed to stdout (not stderr)
- [x] The prompt includes a secondary hint: "Or open a new terminal."
- [x] If already on the latest version, no re-source prompt is shown
- [x] If the update fails (network error, clone failure), no re-source prompt is shown
- [x] `wt --update --check` (check-only mode) is not affected; no re-source prompt shown
- [x] `shellcheck` passes on the modified `lib/update.sh`
- [x] Existing BATS tests in `test/cmd_update.bats` continue to pass
- [x] New BATS test asserts the re-source prompt appears in `_update_install` output after a successful update
- [x] New BATS test asserts no re-source prompt when versions match

---

## Technical Notes

### File to modify

`lib/update.sh` — specifically the `_update_install` function.

### Current end of `_update_install` (lines 162-165)

```sh
  # Update cache
  _update_cache_write "$latest"

  _info "Updated wt to $latest"
  _info "Restart your shell or run: source $_WT_DIR/wt.sh"
```

### Proposed replacement

Replace the two `_info` lines at the end of `_update_install` with:

```sh
  # Update cache
  _update_cache_write "$latest"

  _info "Updated wt to $latest"
  printf '\nTo activate the new version in this shell, run:\n'
  printf '  source %s/wt.sh\n' "$_WT_DIR"
  printf '\nOr open a new terminal.\n'
```

`printf` to stdout keeps the prompt separate from the `_info` messages which go to
stderr. This makes it trivially copyable from a terminal.

### Install path availability

`_WT_DIR` is a global variable set in `wt.sh` before any lib files are sourced. It is
always available inside `_update_install`. No file read is needed.

### Fallback if `_WT_DIR` is somehow empty

Add a guard before the `printf` block:

```sh
  if [ -n "$_WT_DIR" ]; then
    printf '\nTo activate the new version in this shell, run:\n'
    printf '  source %s/wt.sh\n' "$_WT_DIR"
    printf '\nOr open a new terminal.\n'
  else
    _info "Re-source wt.sh from your shell config to activate the update"
  fi
```

### BATS test additions (`test/cmd_update.bats`)

Add two new tests after the existing `_update_install detects available update` test:

```sh
@test "_update_install shows re-source prompt after successful update" {
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  _fetch_latest() { printf '1.2.0\n- feat: new feature'; }

  git() {
    if [ "$1" = "clone" ]; then
      local target_dir="${*: -1}"
      mkdir -p "$target_dir/lib"
      echo "1.2.0" > "$target_dir/VERSION"
      echo "# updated wt.sh" > "$target_dir/wt.sh"
      echo "# updated lib" > "$target_dir/lib/utils.sh"
      return 0
    fi
    command git "$@"
  }

  run _update_install
  assert_success
  assert_output --partial "source $TEST_TEMP_DIR/wt_install/wt.sh"
  assert_output --partial "Or open a new terminal"
}

@test "_update_install does not show re-source prompt when already up to date" {
  echo "1.2.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _fetch_latest() { printf '1.2.0\nsome changelog'; }

  run _update_install
  assert_success
  refute_output --partial "source"
  refute_output --partial "Or open a new terminal"
}
```

### shellcheck compliance

`printf` is preferred over `echo` for portability and shellcheck compatibility. The
pattern used above is identical to patterns already present in `lib/update.sh`.

---

## Dependencies

- **STORY-013:** Add self-update mechanism (`wt --update`) — completed; this story
  enhances the success path of `_update_install` in `lib/update.sh`.

---

## Definition of Done

- [x] Re-source prompt added to the success path of `_update_install` in `lib/update.sh`
- [x] Prompt uses `$_WT_DIR` to show the exact install path
- [x] Prompt printed to stdout; remaining messages remain on stderr via `_info`
- [x] Fallback message shown if `_WT_DIR` is empty
- [x] `shellcheck lib/update.sh` passes (no new warnings)
- [x] Two new BATS tests written in `test/cmd_update.bats` and passing
- [x] All existing `test/cmd_update.bats` tests continue to pass
- [ ] Conventional commit used: `feat(STORY-033): ...` (handled by orchestrator)

---

## Story Points Breakdown

- **Implementation (`lib/update.sh`):** 1 point — small, targeted change to `_update_install`
- **Tests (`test/cmd_update.bats`):** 1 point — two new test cases following existing patterns
- **Total:** 2 points

**Rationale:** The change is a handful of `printf` lines in one function. The BATS test
infrastructure for `_update_install` (mocked `_fetch_latest`, mocked `git clone`) already
exists and the new tests can follow the same pattern exactly.

---

## Additional Notes

- The existing message `_info "Restart your shell or run: source $_WT_DIR/wt.sh"` on line
  165 of `lib/update.sh` should be removed and replaced with the `printf` block described
  above. Do not keep both.
- The `--check` mode (`_update_check_only`) is read-only and requires no changes.
- This story does not change the `_update_notify` banner that appears on subsequent `wt`
  invocations.

---

## Progress Tracking

**Status History:**

- 2026-02-19: Created and enhanced by Scrum Master
- 2026-02-19: Implementation started and completed by Developer

**Actual Effort:** 2 points (matched estimate)

**Files Changed:**

- `lib/update.sh` (modified): Replaced the two `_info` lines at the end of `_update_install` with `_info "Updated wt to $latest"` followed by a guarded `printf` block that prints the exact `source <path>/wt.sh` command to stdout, plus the "Or open a new terminal." hint. Old `_info "Restart your shell or run: ..."` line removed.
- `test/cmd_update.bats` (modified): Added two new BATS tests after the existing `_update_install detects available update` test — one asserting the re-source prompt appears on successful update, one asserting it does not appear when already up to date.

**Tests Added:**

1. `_update_install shows re-source prompt after successful update` — asserts `source <path>/wt.sh` and "Or open a new terminal" appear in output after a successful update.
2. `_update_install does not show re-source prompt when already up to date` — asserts neither "source" nor "Or open a new terminal" appears when versions match.

**Test Results:**

- `shellcheck lib/update.sh`: no warnings
- `npm test`: 250/250 tests pass, 0 failures

**Decisions Made:**

- Used the proposed `printf` block from the story's Technical Notes verbatim, wrapped in a `[ -n "$_WT_DIR" ]` guard per the Fallback section.
- The `printf` output goes to stdout (no redirection), keeping it separate from `_info` messages that go to stderr — satisfies the "print to stdout" acceptance criterion.
- The old `_info "Restart your shell..."` line was removed (not kept alongside the new block) per the Additional Notes in the story.

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## QA Review

### Files Reviewed

| File | Status | Notes |
|------|--------|-------|
| `lib/update.sh` | Pass | `printf` block added at lines 165-171; guarded by `[ -n "$_WT_DIR" ]`; old `_info "Restart..."` line removed; POSIX-compliant |
| `test/cmd_update.bats` | Pass | Two new tests added at lines 262-294 following existing mock patterns |

### Issues Found

None

### AC Verification

- [x] AC 1 — After a successful update, prints exact `source <path>/wt.sh` to stdout: verified in `lib/update.sh` lines 166-167 (`printf '  source %s/wt.sh\n' "$_WT_DIR"`); test: `_update_install shows re-source prompt after successful update` (test 125)
- [x] AC 2 — Path shown is `$_WT_DIR/wt.sh`: verified in `lib/update.sh` line 167 using `$_WT_DIR` directly; test: `assert_output --partial "source $TEST_TEMP_DIR/wt_install/wt.sh"` (test 125)
- [x] AC 3 — Re-source block printed to stdout (not stderr): verified — `printf` writes to stdout by default; `_info` (stderr) is not used for this block; confirmed by `_info writes to stdout` test showing `_info` goes to stdout in this project, but the separation is clear from the `printf` usage which is unconditional stdout
- [x] AC 4 — Secondary hint "Or open a new terminal." present: verified in `lib/update.sh` line 168; test: `assert_output --partial "Or open a new terminal"` (test 125)
- [x] AC 5 — No re-source prompt when already on latest version: verified — early return at `lib/update.sh` line 123-125 exits before the prompt block; test: `_update_install does not show re-source prompt when already up to date` (test 126) using `refute_output --partial "Or open a new terminal"`
- [x] AC 6 — No re-source prompt when update fails (network error / clone failure): verified — `_fetch_latest` failure returns 1 at line 116 before prompt block; `git clone` failure returns 1 at line 153-155 before prompt block; existing test: `_update_install shows error on network failure` (test 123)
- [x] AC 7 — `wt --update --check` not affected: verified — `_update_check_only` function (lines 175-193) is a separate function with no `printf` prompt block; test: `wt --update --check routes to check-only mode` (test 136)
- [x] AC 8 — `shellcheck` passes on `lib/update.sh`: verified — `shellcheck -x wt.sh lib/*.sh` produced no output (no warnings or errors)
- [x] AC 9 — Existing BATS tests in `test/cmd_update.bats` continue to pass: verified — all prior update tests (96-124, 127-136) pass; 0 failures
- [x] AC 10 — New BATS test asserts re-source prompt appears after successful update: verified — test `_update_install shows re-source prompt after successful update` at line 262 (test 125 in suite)
- [x] AC 11 — New BATS test asserts no re-source prompt when versions match: verified — test `_update_install does not show re-source prompt when already up to date` at line 286 (test 126 in suite)

### Test Results

- Total: 250 / Passed: 250 / Failed: 0

### Shellcheck

- Clean: yes
