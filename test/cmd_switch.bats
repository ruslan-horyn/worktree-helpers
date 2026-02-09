#!/usr/bin/env bats
# Tests for _cmd_switch in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_switch resolves worktree by branch name" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a worktree
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b sw-branch "$GWT_WORKTREES_DIR/sw-branch" HEAD >/dev/null 2>&1

  run _cmd_switch "sw-branch"
  assert_success
}

@test "_cmd_switch errors for nonexistent branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_switch "nonexistent-sw"
  assert_failure
  assert_output --partial "No worktree for"
}
