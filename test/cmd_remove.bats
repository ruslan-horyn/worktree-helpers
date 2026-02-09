#!/usr/bin/env bats
# Tests for _cmd_remove in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_remove removes worktree and deletes branch with force" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create a worktree
  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/rm-branch"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b rm-branch "$wt_path" HEAD >/dev/null 2>&1

  run _cmd_remove "rm-branch" 1
  assert_success

  # Worktree directory should be gone
  assert [ ! -d "$wt_path" ]

  # Branch should be deleted
  run _branch_exists "rm-branch"
  assert_failure
}

@test "_cmd_remove errors for nonexistent worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _cmd_remove "nonexistent" 1
  assert_failure
  assert_output --partial "No worktree for"
}
