#!/usr/bin/env bats
# Tests for _cmd_open in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_open opens existing remote branch as worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create a branch on origin
  git checkout -b remote-open >/dev/null 2>&1
  echo "content" > open.txt
  git add open.txt
  git commit -m "open commit" >/dev/null 2>&1
  git push origin remote-open >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git branch -D remote-open >/dev/null 2>&1

  run _cmd_open "remote-open"
  assert_success
  assert [ -d "$TEST_TEMP_DIR/test-project_worktrees/remote-open" ]
}

@test "_cmd_open errors for nonexistent branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_open "totally-nonexistent"
  assert_failure
  assert_output --partial "not found"
}

@test "_cmd_open switches to already-open worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create worktree first
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b already-open "$GWT_WORKTREES_DIR/already-open" HEAD >/dev/null 2>&1

  # Push branch to origin so it exists remotely too
  git push origin already-open >/dev/null 2>&1

  run _cmd_open "already-open"
  assert_success
  assert_output --partial "Switching to"
}

@test "_cmd_open strips origin/ prefix from branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create a remote branch
  git checkout -b strip-prefix >/dev/null 2>&1
  echo "x" > sp.txt
  git add sp.txt
  git commit -m "sp" >/dev/null 2>&1
  git push origin strip-prefix >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git branch -D strip-prefix >/dev/null 2>&1

  run _cmd_open "origin/strip-prefix"
  assert_success
  assert [ -d "$TEST_TEMP_DIR/test-project_worktrees/strip-prefix" ]
}
