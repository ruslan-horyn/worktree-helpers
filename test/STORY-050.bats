#!/usr/bin/env bats
# STORY-050: Fix wt --check showing help instead of update status
#
# Tests cover:
#   AC1 - wt --check routes to _update_check_only and exits 0
#   AC2 - wt --check does NOT output help screen text
#   AC3 - wt --update --check continues to route to _update_check_only (no regression)
#   AC4 - wt --check --update (flags reversed) also routes to _update_check_only
#   AC5 - wt --check --help shows _help_update output, not full help screen
#   AC6 - _cmd_help --check description does not include "(with --update)" qualifier
#   AC7 - no regressions: existing wt --update (install mode) still routes correctly
#
# All tests are expected to FAIL before STORY-050 is implemented.
# If a test passes before implementation, it is flagged with a WARNING comment.

setup() {
  load 'test_helper'
  setup
  load_wt

  # Set up a fake _WT_DIR with VERSION file so update functions are satisfied
  mkdir -p "$TEST_TEMP_DIR/wt_install/lib"
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"
  _WT_UPDATE_CACHE="$TEST_TEMP_DIR/.wt_update_check"
}

teardown() {
  teardown
}

# ---------------------------------------------------------------------------
# AC1: wt --check alone routes to _update_check_only and exits 0
# ---------------------------------------------------------------------------

@test "AC1: wt --check alone calls _update_check_only and exits 0" {
  load_wt_full

  _update_check_only() { echo "check_only_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check
  assert_success
  assert_output "check_only_called"
}

# ---------------------------------------------------------------------------
# AC2: wt --check alone does NOT output the help screen
# ---------------------------------------------------------------------------

@test "AC2: wt --check alone does not print help screen text" {
  load_wt_full

  _update_check_only() { echo "check_only_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check
  assert_success
  # _cmd_help always begins with "wt - Git Worktree Helpers"
  refute_output --partial "wt - Git Worktree Helpers"
  # _cmd_help also prints "Usage: wt [flags]"
  refute_output --partial "Usage: wt [flags]"
}

# ---------------------------------------------------------------------------
# AC3: wt --update --check (existing form) continues to work — no regression
# ---------------------------------------------------------------------------

# NOTE: This test passes BEFORE the STORY-050 fix because --update sets action="update"
# explicitly, so the router already routes correctly. This test guards against regression
# after the fix is applied.
@test "AC3: wt --update --check still routes to _update_check_only (no regression)" {
  load_wt_full

  _update_check_only() { echo "check_only_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --update --check
  assert_success
  assert_output "check_only_called"
}

# ---------------------------------------------------------------------------
# AC4: wt --check --update (reversed flag order) also routes to _update_check_only
# ---------------------------------------------------------------------------

# NOTE: This test passes BEFORE the STORY-050 fix because even when --check comes first,
# the subsequent --update sets action="update", which is already correct routing.
# This test guards against regression after the fix is applied.
@test "AC4: wt --check --update (flags reversed) routes to _update_check_only" {
  load_wt_full

  _update_check_only() { echo "check_only_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check --update
  assert_success
  assert_output "check_only_called"
}

# ---------------------------------------------------------------------------
# AC5: wt --check --help shows _help_update, not the full help screen
# ---------------------------------------------------------------------------

@test "AC5: wt --check --help shows _help_update output (wt --update section)" {
  load_wt_full

  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check --help
  assert_success
  # _help_update contains "wt --update"
  assert_output --partial "wt --update"
  # Full help screen begins with "wt - Git Worktree Helpers"; must not be shown
  refute_output --partial "wt - Git Worktree Helpers"
}

# ---------------------------------------------------------------------------
# AC6: _cmd_help --check description must NOT include "(with --update)"
# ---------------------------------------------------------------------------

@test "AC6: _cmd_help --check description does not contain '(with --update)'" {
  run _cmd_help
  assert_success
  # The --check line must not contain "(with --update)" qualifier
  # We check that the specific old phrasing is absent
  refute_output --partial "--check                   Check for update without installing (with --update)"
}

@test "AC6: _cmd_help --check description reflects standalone usage" {
  run _cmd_help
  assert_success
  # The --check entry must exist and must mention it works as a standalone alias
  assert_output --partial "--check"
  # Must not gate it behind "(with --update)"
  # The new description should say something like "alias for --update --check"
  assert_output --partial "alias for --update --check"
}

# ---------------------------------------------------------------------------
# AC7: wt --update (install mode) continues to route correctly — no regression
# ---------------------------------------------------------------------------

@test "AC7: wt --update (no --check) still routes to _update_install" {
  load_wt_full

  _update_install() { echo "install_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --update
  assert_success
  assert_output "install_called"
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "edge: wt --check exits 0 even when check_only function outputs to stderr" {
  load_wt_full

  # NOTE: Before the fix this test passes for the WRONG reason — _cmd_help exits 0 too.
  # After the fix, this test is valid: _update_check_only is called and exits 0.
  # The assert_output on stderr guards that _cmd_help is not what ran.
  _update_check_only() { echo "check_only_called" >&2; return 0; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check
  assert_success
  # _cmd_help would produce stdout output; no stdout here means _update_check_only ran
  refute_output --partial "wt - Git Worktree Helpers"
}

@test "edge: wt --check propagates non-zero exit from _update_check_only" {
  load_wt_full

  _update_check_only() { return 1; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check
  assert_failure
}

@test "edge: wt with no args shows help (sanity check that default routing still works)" {
  load_wt_full

  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt
  assert_success
  assert_output --partial "wt - Git Worktree Helpers"
}
