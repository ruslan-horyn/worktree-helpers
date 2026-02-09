#!/usr/bin/env bats
# Tests for hook execution in lib/worktree.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# --- _run_hook ---

@test "_run_hook executes hook with correct arguments" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a marker hook
  local marker="$TEST_TEMP_DIR/hook_marker"
  create_marker_hook "$GWT_CREATE_HOOK" "$marker"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/hook-test"
  mkdir -p "$wt_path"

  _run_hook "created" "$wt_path" "my-branch" "origin/main" "$repo_dir"

  # Marker file should exist and contain the args
  assert [ -f "$marker" ]
  run cat "$marker"
  assert_output --partial "called:$wt_path:my-branch:origin/main:$repo_dir"
}

@test "_run_hook executes switched hook" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  local marker="$TEST_TEMP_DIR/hook_marker"
  create_marker_hook "$GWT_SWITCH_HOOK" "$marker"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/switch-test"
  mkdir -p "$wt_path"

  _run_hook "switched" "$wt_path" "my-branch" "" "$repo_dir"

  assert [ -f "$marker" ]
  run cat "$marker"
  assert_output --partial "called:$wt_path:my-branch:"
}

@test "_run_hook skips non-executable hooks silently" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Make hook non-executable
  chmod -x "$GWT_CREATE_HOOK"

  run _run_hook "created" "/some/path" "branch" "ref" "$repo_dir"
  assert_success
  assert_output ""
}

@test "_run_hook skips missing hooks silently" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Remove hook file
  rm -f "$GWT_CREATE_HOOK"

  run _run_hook "created" "/some/path" "branch" "ref" "$repo_dir"
  assert_success
  assert_output ""
}

@test "_run_hook returns 1 when root is empty" {
  run _run_hook "created" "/some/path" "branch" "ref" ""
  assert_failure
}
