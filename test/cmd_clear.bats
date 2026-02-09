#!/usr/bin/env bats
# Tests for _cmd_clear in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_clear removes worktrees older than N days (force)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  local wt_path="$GWT_WORKTREES_DIR/old-branch"
  git worktree add -b old-branch "$wt_path" HEAD >/dev/null 2>&1

  # Backdate the .git file to make it "old"
  touch -t 202001010000 "$wt_path/.git"

  run _cmd_clear "1" "1" "0" "0"
  assert_success
  assert_output --partial "Removed"
}

@test "_cmd_clear skips locked worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  local wt_path="$GWT_WORKTREES_DIR/locked-old"
  git worktree add -b locked-old "$wt_path" HEAD >/dev/null 2>&1
  git worktree lock "$wt_path" >/dev/null 2>&1

  # Backdate
  touch -t 202001010000 "$wt_path/.git"

  run _cmd_clear "1" "1" "0" "0"
  assert_success
  # Locked worktree should still exist
  assert [ -d "$wt_path" ]
}

@test "_cmd_clear errors on invalid input (non-numeric)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_clear "abc" "1" "0" "0"
  assert_failure
  assert_output --partial "Invalid number"
}

@test "_cmd_clear errors when no days argument" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_clear "" "1" "0" "0"
  assert_failure
  assert_output --partial "Usage"
}

@test "_cmd_clear handles empty worktree list" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_clear "1" "1" "0" "0"
  assert_success
  assert_output --partial "No worktrees to clear"
}

@test "_cmd_clear respects --dev-only filter" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a dev worktree (has _RN suffix)
  local dev_wt="$GWT_WORKTREES_DIR/feat_RN"
  git worktree add -b "feat_RN" "$dev_wt" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$dev_wt/.git"

  # Create a main worktree (no _RN suffix)
  local main_wt="$GWT_WORKTREES_DIR/feat-main"
  git worktree add -b "feat-main" "$main_wt" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$main_wt/.git"

  # dev_only=1, main_only=0
  run _cmd_clear "1" "1" "1" "0"
  assert_success

  # Dev worktree should be removed, main should stay
  assert [ ! -d "$dev_wt" ]
  assert [ -d "$main_wt" ]
}

@test "_cmd_clear respects --main-only filter" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a dev worktree
  local dev_wt="$GWT_WORKTREES_DIR/feat2_RN"
  git worktree add -b "feat2_RN" "$dev_wt" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$dev_wt/.git"

  # Create a main worktree
  local main_wt="$GWT_WORKTREES_DIR/feat2-main"
  git worktree add -b "feat2-main" "$main_wt" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$main_wt/.git"

  # dev_only=0, main_only=1
  run _cmd_clear "1" "1" "0" "1"
  assert_success

  # Main worktree should be removed, dev should stay
  assert [ -d "$dev_wt" ]
  assert [ ! -d "$main_wt" ]
}

@test "_cmd_clear rejects mutually exclusive --dev-only --main-only" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_clear "1" "1" "1" "1"
  assert_failure
  assert_output --partial "mutually exclusive"
}
