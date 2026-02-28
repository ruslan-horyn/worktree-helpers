#!/usr/bin/env bats
# STORY-051: Fix fzf ESC cancellation silently ignored across all selection commands
#
# Tests verify that pressing ESC (fzf exit 130) aborts interactive selection
# in _wt_select, _branch_select, and all commands that invoke them.
#
# fzf is mocked via a fake binary placed at the front of PATH.
#
# PRE-IMPLEMENTATION STATE (tests written before the fix):
#   FAILING (correctly exposing the bug — must pass after fix):
#     AC-1 tests for _wt_select exit code on ESC (test 1)
#     AC-3 tests for _cmd_switch exit code on ESC (test 5)
#     edge: _wt_select returns non-zero on fzf exit 1/2 (tests 23, 25)
#
#   PASSING before implementation — but NOTE WHY:
#     AC-2 (_branch_select): _branch_select has no `cut` appended; fzf IS
#       the last pipeline command so its exit code propagates already.
#       WARNING: these tests may not expose a real bug — Dev should verify
#       _branch_select is truly affected and whether these tests are still
#       meaningful after the fix.
#     AC-4..7 (_cmd_remove, _cmd_lock, _cmd_unlock, _cmd_open): these pass
#       because _wt_resolve / _cmd_open each do a `[ -z "$wt_path" ]` guard
#       after the substitution returns empty — so empty string triggers
#       "No worktree" error even when exit code was 0. After the fix the
#       abort will happen earlier (via exit code), which is the correct path.
#       The side-effect assertions (worktree not removed/locked/unlocked)
#       remain valid and important.
#     AC-8/9 (valid selection): expected to pass both before and after fix.
#     AC-10/11 (fzf not on PATH): expected to pass both before and after fix.

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# ---------------------------------------------------------------------------
# Helper: create a fake fzf that exits with a given code and optionally prints a line
# Usage: _mock_fzf_exit <exit_code> [output_line]
# ---------------------------------------------------------------------------
_setup_fzf_mock() {
  local exit_code="$1"
  local output_line="${2:-}"
  MOCK_FZF_DIR="$(mktemp -d)"
  if [ -n "$output_line" ]; then
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\nexit %s\n' "$output_line" "$exit_code" \
      > "${MOCK_FZF_DIR}/fzf"
  else
    printf '#!/bin/sh\nexit %s\n' "$exit_code" > "${MOCK_FZF_DIR}/fzf"
  fi
  chmod +x "${MOCK_FZF_DIR}/fzf"
  export PATH="${MOCK_FZF_DIR}:${PATH}"
}

# ---------------------------------------------------------------------------
# AC-1: _wt_select propagates ESC (fzf exit 130)
# ---------------------------------------------------------------------------

@test "AC-1: _wt_select returns 1 when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Add a real worktree so fzf has something to display
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b esc-test-wt "$GWT_WORKTREES_DIR/esc-test-wt" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  run _wt_select "wt> "
  assert_failure
}

@test "AC-1: _wt_select produces no stdout when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b esc-stdout-wt "$GWT_WORKTREES_DIR/esc-stdout-wt" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  run _wt_select "wt> "
  assert_output ""
}

# ---------------------------------------------------------------------------
# AC-2: _branch_select propagates ESC (fzf exit 130)
# ---------------------------------------------------------------------------

@test "AC-2: _branch_select returns 1 when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  _setup_fzf_mock 130

  run _branch_select "branch> "
  assert_failure
}

@test "AC-2: _branch_select produces no stdout when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  _setup_fzf_mock 130

  run _branch_select "branch> "
  assert_output ""
}

# ---------------------------------------------------------------------------
# AC-3: _cmd_switch aborts on ESC
# ---------------------------------------------------------------------------

@test "AC-3: _cmd_switch returns non-zero when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b sw-esc "$GWT_WORKTREES_DIR/sw-esc" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  run _cmd_switch
  assert_failure
}

@test "AC-3: _cmd_switch prints nothing when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b sw-esc-quiet "$GWT_WORKTREES_DIR/sw-esc-quiet" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  run _cmd_switch
  assert_output ""
}

# ---------------------------------------------------------------------------
# AC-4: _cmd_remove aborts on ESC — no removal occurs
# ---------------------------------------------------------------------------

@test "AC-4: _cmd_remove returns non-zero when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  local wt_path="$GWT_WORKTREES_DIR/rm-esc"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-esc "$wt_path" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  run _cmd_remove "" 1
  assert_failure
}

@test "AC-4: _cmd_remove does not remove the worktree when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  local wt_path="$GWT_WORKTREES_DIR/rm-esc-keep"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-esc-keep "$wt_path" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  _cmd_remove "" 1 2>/dev/null || true

  # Worktree directory must still exist
  assert [ -d "$wt_path" ]
}

# ---------------------------------------------------------------------------
# AC-5: _cmd_lock aborts on ESC — no lock occurs
# ---------------------------------------------------------------------------

@test "AC-5: _cmd_lock returns non-zero when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/lock-esc"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b lock-esc "$wt_path" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  run _cmd_lock ""
  assert_failure
}

@test "AC-5: _cmd_lock does not lock worktree when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/lock-esc-keep"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b lock-esc-keep "$wt_path" HEAD >/dev/null 2>&1

  _setup_fzf_mock 130

  _cmd_lock "" 2>/dev/null || true

  # Worktree should NOT be locked
  run git worktree list --porcelain
  refute_output --partial "locked"
}

# ---------------------------------------------------------------------------
# AC-6: _cmd_unlock aborts on ESC
# ---------------------------------------------------------------------------

@test "AC-6: _cmd_unlock returns non-zero when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/unlock-esc"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b unlock-esc "$wt_path" HEAD >/dev/null 2>&1
  git worktree lock "$wt_path" >/dev/null 2>&1

  _setup_fzf_mock 130

  run _cmd_unlock ""
  assert_failure
}

@test "AC-6: _cmd_unlock does not unlock worktree when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/unlock-esc-keep"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b unlock-esc-keep "$wt_path" HEAD >/dev/null 2>&1
  git worktree lock "$wt_path" >/dev/null 2>&1

  _setup_fzf_mock 130

  _cmd_unlock "" 2>/dev/null || true

  # Worktree should still be locked
  run git worktree list --porcelain
  assert_output --partial "locked"
}

# ---------------------------------------------------------------------------
# AC-7: _cmd_open aborts on ESC — no worktree created
# ---------------------------------------------------------------------------

@test "AC-7: _cmd_open returns non-zero when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  _setup_fzf_mock 130

  run _cmd_open ""
  assert_failure
}

@test "AC-7: _cmd_open creates no worktree when fzf exits 130 (ESC)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Ensure worktrees dir starts empty
  rm -rf "$GWT_WORKTREES_DIR"
  mkdir -p "$GWT_WORKTREES_DIR"

  _setup_fzf_mock 130

  _cmd_open "" 2>/dev/null || true

  # No new directories should exist in the worktrees dir
  local count
  count=$(find "$GWT_WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  assert [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AC-8: _wt_select normal selection (fzf exit 0) works correctly
# ---------------------------------------------------------------------------

@test "AC-8: _wt_select outputs the full path when fzf exits 0 with a valid selection" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  local wt_path="$GWT_WORKTREES_DIR/sel-ok"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b sel-ok "$wt_path" HEAD >/dev/null 2>&1

  # Mock fzf: emits "sel-ok<TAB><full_path>" as if the user picked that entry
  _setup_fzf_mock 0 "sel-ok	$wt_path"

  run _wt_select "wt> "
  assert_success
  assert_output "$wt_path"
}

@test "AC-8: _wt_select returns 0 on valid selection" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  local wt_path="$GWT_WORKTREES_DIR/sel-ok2"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b sel-ok2 "$wt_path" HEAD >/dev/null 2>&1

  _setup_fzf_mock 0 "sel-ok2	$wt_path"

  run _wt_select "wt> "
  assert_success
}

# ---------------------------------------------------------------------------
# AC-9: _branch_select normal selection (fzf exit 0) works correctly
# ---------------------------------------------------------------------------

@test "AC-9: _branch_select outputs the selected branch name when fzf exits 0" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  _setup_fzf_mock 0 "main"

  run _branch_select "branch> "
  assert_success
  assert_output "main"
}

@test "AC-9: _branch_select returns 0 on valid selection" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  _setup_fzf_mock 0 "main"

  run _branch_select "branch> "
  assert_success
}

# ---------------------------------------------------------------------------
# AC-10: _wt_select errors when fzf is not installed
# ---------------------------------------------------------------------------

@test "AC-10: _wt_select returns non-zero when fzf is not on PATH" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Remove fzf from PATH entirely
  local no_fzf_dir
  no_fzf_dir="$(mktemp -d)"
  export PATH="$no_fzf_dir"

  run _wt_select "wt> "
  assert_failure
}

@test "AC-10: _wt_select prints error to stderr when fzf is not on PATH" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local no_fzf_dir
  no_fzf_dir="$(mktemp -d)"
  export PATH="$no_fzf_dir"

  run _wt_select "wt> "
  assert_failure
  # Error message must go to stderr — captured by BATS as $output when combined
  assert_output --partial "fzf"
}

# ---------------------------------------------------------------------------
# AC-11: _branch_select errors when fzf is not installed
# ---------------------------------------------------------------------------

@test "AC-11: _branch_select returns non-zero when fzf is not on PATH" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local no_fzf_dir
  no_fzf_dir="$(mktemp -d)"
  export PATH="$no_fzf_dir"

  run _branch_select "branch> "
  assert_failure
}

@test "AC-11: _branch_select prints error to stderr when fzf is not on PATH" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local no_fzf_dir
  no_fzf_dir="$(mktemp -d)"
  export PATH="$no_fzf_dir"

  run _branch_select "branch> "
  assert_failure
  assert_output --partial "fzf"
}

# ---------------------------------------------------------------------------
# Edge cases: fzf exits with other non-zero, non-130 codes
# ---------------------------------------------------------------------------

@test "edge: _wt_select returns non-zero when fzf exits with code 1 (no match)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b edge-fzf1 "$GWT_WORKTREES_DIR/edge-fzf1" HEAD >/dev/null 2>&1

  _setup_fzf_mock 1

  run _wt_select "wt> "
  assert_failure
}

@test "edge: _branch_select returns non-zero when fzf exits with code 1 (no match)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  _setup_fzf_mock 1

  run _branch_select "branch> "
  assert_failure
}

@test "edge: _wt_select returns non-zero when fzf exits with code 2 (error)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b edge-fzf2 "$GWT_WORKTREES_DIR/edge-fzf2" HEAD >/dev/null 2>&1

  _setup_fzf_mock 2

  run _wt_select "wt> "
  assert_failure
}

# ---------------------------------------------------------------------------
# Edge case: empty input (no argument to commands that expect one normally,
# with fzf mocked to return a valid selection)
# ---------------------------------------------------------------------------

@test "edge: _cmd_switch with no argument falls through to fzf and succeeds when fzf selects valid worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  local wt_path="$GWT_WORKTREES_DIR/sw-ok"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b sw-ok "$wt_path" HEAD >/dev/null 2>&1

  _setup_fzf_mock 0 "sw-ok	$wt_path"

  run _cmd_switch ""
  assert_success
}

@test "edge: _cmd_remove with no argument falls through to fzf and removes when fzf selects valid worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  local wt_path="$GWT_WORKTREES_DIR/rm-ok"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-ok "$wt_path" HEAD >/dev/null 2>&1

  _setup_fzf_mock 0 "rm-ok	$wt_path"

  run _cmd_remove "" 1
  assert_success
  assert [ ! -d "$wt_path" ]
}
