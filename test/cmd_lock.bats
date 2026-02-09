#!/usr/bin/env bats
# Tests for _cmd_lock and _cmd_unlock in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_lock locks a worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/lock-test"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b lock-test "$wt_path" HEAD >/dev/null 2>&1

  run _cmd_lock "lock-test"
  assert_success
  assert_output --partial "Locked"

  # Verify it's locked (git worktree list --porcelain shows "locked")
  run git worktree list --porcelain
  assert_output --partial "locked"
}

@test "_cmd_unlock unlocks a worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/unlock-test"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b unlock-test "$wt_path" HEAD >/dev/null 2>&1
  git worktree lock "$wt_path" >/dev/null 2>&1

  run _cmd_unlock "unlock-test"
  assert_success
  assert_output --partial "Unlocked"
}

@test "_cmd_lock errors for nonexistent worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _cmd_lock "nonexistent-lock"
  assert_failure
}

@test "_cmd_unlock errors for nonexistent worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _cmd_unlock "nonexistent-unlock"
  assert_failure
}
