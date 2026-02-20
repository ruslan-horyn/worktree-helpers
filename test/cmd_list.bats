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

@test "_cmd_list shows [clean] for worktree with no changes" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/clean-branch"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b clean-branch "$wt_path" HEAD >/dev/null 2>&1

  run _cmd_list
  assert_success
  assert_output --partial "clean-branch"
  assert_output --partial "[clean]"
}

@test "_cmd_list shows [dirty] for worktree with unstaged changes" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/dirty-unstaged"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b dirty-unstaged "$wt_path" HEAD >/dev/null 2>&1

  # Create unstaged change in the worktree
  echo "modified" >> "$wt_path/README.md"

  run _cmd_list
  assert_success
  assert_output --partial "dirty-unstaged"
  assert_output --partial "[dirty]"
}

@test "_cmd_list shows [dirty] for worktree with untracked files" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/dirty-untracked"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b dirty-untracked "$wt_path" HEAD >/dev/null 2>&1

  # Create untracked file in the worktree
  echo "new file" > "$wt_path/newfile.txt"

  run _cmd_list
  assert_success
  assert_output --partial "dirty-untracked"
  assert_output --partial "[dirty]"
}

@test "_cmd_list shows dirty/clean indicator for main worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _cmd_list
  assert_success
  assert_output --partial "main"
  # Main worktree should show either [clean] or [dirty]
  # Since create_test_repo leaves a clean state, it should show [clean]
  assert_output --partial "[clean]"
}

@test "_cmd_list shows [dirty] for worktree with staged changes" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/dirty-staged"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b dirty-staged "$wt_path" HEAD >/dev/null 2>&1

  # Create staged change in the worktree
  echo "staged content" > "$wt_path/staged.txt"
  git -C "$wt_path" add staged.txt

  run _cmd_list
  assert_success
  assert_output --partial "dirty-staged"
  assert_output --partial "[dirty]"
}

@test "_cmd_list shows [?] for inaccessible worktree path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/missing-wt"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b missing-wt "$wt_path" HEAD >/dev/null 2>&1

  # Remove the worktree directory (but git still references it)
  rm -rf "$wt_path"

  run _cmd_list
  assert_success
  assert_output --partial "missing-wt"
  assert_output --partial "[?]"
}

@test "_cmd_list labels main worktree as [root] not full path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _cmd_list
  assert_success
  assert_output --partial "[root]"
  # Full path of repo should NOT appear as the worktree display column
  refute_output --partial "$repo_dir  "
}

@test "_cmd_list shows worktree name not full path for non-main worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/display-name-wt"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b display-name-wt "$wt_path" HEAD >/dev/null 2>&1

  run _cmd_list
  assert_success
  # Should show the name only
  assert_output --partial "display-name-wt"
  # Should NOT show the full path as the display column
  refute_output --partial "$wt_path  "
}
