#!/usr/bin/env bats
# Tests for _cmd_list in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_list displays worktrees with branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/list-branch"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b list-branch "$wt_path" HEAD >/dev/null 2>&1

  run _cmd_list
  assert_success
  assert_output --partial "main"
  assert_output --partial "list-branch"
}

@test "_cmd_list shows lock status" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/locked-list"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b locked-list "$wt_path" HEAD >/dev/null 2>&1
  git worktree lock "$wt_path" >/dev/null 2>&1

  run _cmd_list
  assert_success
  assert_output --partial "locked"
}

@test "_cmd_list handles no worktrees (only main)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _cmd_list
  assert_success
  assert_output --partial "main"
}
