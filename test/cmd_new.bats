#!/usr/bin/env bats
# Tests for _cmd_new and _cmd_dev in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# --- _cmd_new ---

@test "_cmd_new creates worktree and branch from main ref" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_new "feat-test"
  assert_success

  # Worktree should exist
  assert [ -d "$TEST_TEMP_DIR/test-project_worktrees/feat-test" ]

  # Branch should exist
  run _branch_exists "feat-test"
  assert_success
}

@test "_cmd_new rejects duplicate branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create a branch first
  git branch feat-dup >/dev/null 2>&1

  run _cmd_new "feat-dup"
  assert_failure
  assert_output --partial "Branch exists"
}

@test "_cmd_new errors without branch argument" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_new ""
  assert_failure
  assert_output --partial "Usage"
}

# --- _cmd_dev ---

@test "_cmd_dev creates branch with dev suffix" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_dev "feat-base"
  assert_success

  # Branch with suffix should exist
  run _branch_exists "feat-base_RN"
  assert_success

  # Worktree should exist
  assert [ -d "$TEST_TEMP_DIR/test-project_worktrees/feat-base_RN" ]
}

@test "_cmd_dev uses current branch when no argument given" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Current branch is main
  run _cmd_dev ""
  assert_success

  # Branch should be main_RN
  run _branch_exists "main_RN"
  assert_success
}

@test "_cmd_dev rejects existing branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  git branch "exists_RN" >/dev/null 2>&1

  run _cmd_dev "exists"
  assert_failure
  assert_output --partial "Branch exists"
}
