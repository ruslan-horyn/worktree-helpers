#!/usr/bin/env bats
# Edge case tests

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# --- Not in a git repo ---

@test "commands error gracefully when not in a git repo" {
  cd "$TEST_TEMP_DIR"
  mkdir -p not-a-repo
  cd not-a-repo

  run _cmd_new "test-branch"
  assert_failure

  run _cmd_list
  assert_failure

  run _cmd_lock "test"
  assert_failure
}

# --- No package.json (non-Node.js repo) ---

@test "commands work in non-Node.js repo without package.json" {
  cd "$TEST_TEMP_DIR"
  local origin_dir="$TEST_TEMP_DIR/origin-no-pkg.git"
  git init --bare "$origin_dir" >/dev/null 2>&1
  git clone "$origin_dir" "$TEST_TEMP_DIR/repo-no-pkg" >/dev/null 2>&1
  cd "$TEST_TEMP_DIR/repo-no-pkg"
  git config user.email "t@t"
  git config user.name "T"
  echo "x" > f.txt
  git add f.txt
  git commit -m "init" >/dev/null 2>&1
  # Rename branch to main if needed
  local cur; cur=$(git rev-parse --abbrev-ref HEAD)
  [ "$cur" != "main" ] && git branch -m "$cur" main >/dev/null 2>&1
  git push -u origin main >/dev/null 2>&1
  create_test_config "$TEST_TEMP_DIR/repo-no-pkg"

  # _cmd_new should work without package.json
  run _cmd_new "test-branch"
  assert_success
}

# --- Missing jq ---

@test "commands error gracefully when jq is not available" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Hide jq by overriding PATH
  local orig_path="$PATH"
  PATH="/usr/bin:/bin"
  # Make sure jq is not in path
  if ! command -v jq >/dev/null 2>&1; then
    run _config_load
    assert_failure
    assert_output --partial "jq is required"
  else
    # jq is in /usr/bin, skip this test
    skip "jq found in restricted PATH"
  fi
  PATH="$orig_path"
}

# --- Empty worktree list ---

@test "_cmd_list handles empty worktree list (only main)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _cmd_list
  assert_success
  # Should show at least the main worktree
  assert_output --partial "main"
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

# --- _wt_resolve returns path for directory input ---

@test "_wt_resolve returns path when given a directory" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local dir_path="$TEST_TEMP_DIR/some-dir"
  mkdir -p "$dir_path"

  run _wt_resolve "$dir_path"
  assert_success
  assert_output "$dir_path"
}
