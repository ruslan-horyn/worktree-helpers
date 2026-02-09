#!/usr/bin/env bats
# Tests for lib/worktree.sh helpers

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# --- _wt_path ---

@test "_wt_path returns path for existing worktree branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b feature-1 "$TEST_TEMP_DIR/test-project_worktrees/feature-1" HEAD >/dev/null 2>&1

  run _wt_path "feature-1"
  assert_success
  assert_output "$TEST_TEMP_DIR/test-project_worktrees/feature-1"
}

@test "_wt_path returns empty for nonexistent branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _wt_path "nonexistent"
  assert_success
  assert_output ""
}

# --- _wt_branch ---

@test "_wt_branch returns branch name for worktree path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/feature-2"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b feature-2 "$wt_path" HEAD >/dev/null 2>&1

  run _wt_branch "$wt_path"
  assert_success
  assert_output "feature-2"
}

@test "_wt_branch returns empty for unknown path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _wt_branch "/nonexistent/path"
  assert_success
  assert_output ""
}

# --- _wt_resolve ---

@test "_wt_resolve returns path for directory input" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Pass a directory that exists
  run _wt_resolve "$repo_dir"
  assert_success
  assert_output "$repo_dir"
}

@test "_wt_resolve resolves branch name to worktree path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/feature-3"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b feature-3 "$wt_path" HEAD >/dev/null 2>&1

  run _wt_resolve "feature-3"
  assert_success
  assert_output "$wt_path"
}

@test "_wt_resolve errors for nonexistent branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _wt_resolve "nonexistent-branch"
  assert_failure
  assert_output --partial "No worktree for"
}

# --- _wt_create ---

@test "_wt_create creates worktree with correct branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_create "new-feature" "origin/main" "$GWT_WORKTREES_DIR"
  assert_success

  # Worktree should exist
  assert [ -d "$GWT_WORKTREES_DIR/new-feature" ]

  # Branch should exist
  run _branch_exists "new-feature"
  assert_success
}

@test "_wt_create fails if path already exists" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR/existing-branch"

  run _wt_create "existing-branch" "origin/main" "$GWT_WORKTREES_DIR"
  assert_failure
  assert_output --partial "Path exists"
}

# --- _wt_open ---

@test "_wt_open opens existing remote branch as worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a branch and push it to origin
  git checkout -b remote-feature >/dev/null 2>&1
  echo "content" > feature.txt
  git add feature.txt
  git commit -m "feature commit" >/dev/null 2>&1
  git push origin remote-feature >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git branch -D remote-feature >/dev/null 2>&1

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_open "remote-feature" "$GWT_WORKTREES_DIR"
  assert_success

  assert [ -d "$GWT_WORKTREES_DIR/remote-feature" ]
}

@test "_wt_open switches to existing worktree if already open" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b already-open "$GWT_WORKTREES_DIR/already-open" HEAD >/dev/null 2>&1

  run _wt_open "already-open" "$GWT_WORKTREES_DIR"
  assert_success
  assert_output --partial "Switching to"
}

# --- _symlink_hooks ---

@test "_symlink_hooks creates symlink from main repo to worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/hook-test"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b hook-test "$wt_path" HEAD >/dev/null 2>&1

  _symlink_hooks "$wt_path"

  # Should have created a symlink
  assert [ -L "$wt_path/.worktrees/hooks" ] || [ -d "$wt_path/.worktrees/hooks" ]
}

@test "_symlink_hooks skips when source hooks dir does not exist" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Remove hooks directory
  rm -rf "$repo_dir/.worktrees"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/no-hooks"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b no-hooks "$wt_path" HEAD >/dev/null 2>&1

  run _symlink_hooks "$wt_path"
  assert_success

  # No symlink should have been created
  assert [ ! -L "$wt_path/.worktrees/hooks" ]
}
