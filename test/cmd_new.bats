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

# --- _cmd_new --from ---

@test "_cmd_new creates worktree from custom base ref via --from" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create a feature branch to use as base
  git branch feature/base >/dev/null 2>&1

  run _cmd_new "feature/child" "feature/base"
  assert_success
  assert_output --partial "Creating worktree 'feature/child' from 'feature/base'"

  # Worktree should exist
  assert [ -d "$TEST_TEMP_DIR/test-project_worktrees/feature/child" ]

  # Branch should exist
  run _branch_exists "feature/child"
  assert_success
}

@test "_cmd_new defaults to GWT_MAIN_REF when no from_ref given" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_new "feat-default" ""
  assert_success
  assert_output --partial "Creating worktree 'feat-default' from 'origin/main'"
}

@test "_cmd_new errors when --from ref is invalid" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_new "feat-bad" "nonexistent-ref-xyz"
  assert_failure
}

@test "_cmd_new usage message includes --from" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_new ""
  assert_failure
  assert_output --partial "--from"
}

# --- Router tests for --from / -b ---

@test "wt -n branch --from ref creates worktree from custom ref (router)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  # Create a branch to use as base
  git branch release/2.0 >/dev/null 2>&1

  run wt -n hotfix/2.0.1 --from release/2.0
  assert_success
  assert_output --partial "Creating worktree 'hotfix/2.0.1' from 'release/2.0'"
}

@test "wt -n branch -b ref creates worktree from custom ref (short form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  # Create a branch to use as base
  git branch release/3.0 >/dev/null 2>&1

  run wt -n hotfix/3.0.1 -b release/3.0
  assert_success
  assert_output --partial "Creating worktree 'hotfix/3.0.1' from 'release/3.0'"
}

@test "wt -n branch -d --from ref errors with mutual exclusivity" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -n mybranch -d --from some-ref
  assert_failure
  assert_output --partial "--from and --dev are mutually exclusive"
}

@test "wt -n branch --from ref -d errors with mutual exclusivity" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -n mybranch --from some-ref -d
  assert_failure
  assert_output --partial "--from and --dev are mutually exclusive"
}

@test "wt -n branch without --from uses main ref (default behavior)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -n feat-no-from
  assert_success
  assert_output --partial "Creating worktree 'feat-no-from' from 'origin/main'"
}
