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

# --- _git_config_retry ---

@test "_git_config_retry succeeds on first attempt for valid command" {
  run _git_config_retry true
  assert_success
}

@test "_git_config_retry fails after max attempts for invalid command" {
  run _git_config_retry false
  assert_failure
}

@test "_git_config_retry retries and succeeds when command passes on later attempt" {
  # Create a script that fails twice then succeeds
  local script="$TEST_TEMP_DIR/flaky_cmd.sh"
  local counter="$TEST_TEMP_DIR/attempt_counter"
  echo "0" > "$counter"
  cat > "$script" <<'SH'
#!/bin/sh
counter_file="$1"
count=$(cat "$counter_file")
count=$((count + 1))
echo "$count" > "$counter_file"
if [ "$count" -lt 3 ]; then
  exit 1
fi
exit 0
SH
  chmod +x "$script"

  run _git_config_retry "$script" "$counter"
  assert_success

  # Should have taken 3 attempts (2 failures + 1 success)
  local final_count
  final_count=$(cat "$counter")
  assert [ "$final_count" -ge 3 ]
}

# --- _wt_create concurrent ---

@test "_wt_create: concurrent creation succeeds" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Export functions and variables needed by subshells
  local project_root="$PROJECT_ROOT"
  local worktrees_dir="$GWT_WORKTREES_DIR"

  # Run two worktree creations concurrently
  # Each runs in a subshell that sources the library
  bash -c "
    source '$project_root/lib/utils.sh'
    source '$project_root/lib/config.sh'
    source '$project_root/lib/worktree.sh'
    cd '$repo_dir'
    _config_load
    _wt_create 'concurrent-a' 'origin/main' '$worktrees_dir'
  " &
  local pid1=$!

  bash -c "
    source '$project_root/lib/utils.sh'
    source '$project_root/lib/config.sh'
    source '$project_root/lib/worktree.sh'
    cd '$repo_dir'
    _config_load
    _wt_create 'concurrent-b' 'origin/main' '$worktrees_dir'
  " &
  local pid2=$!

  # Wait for both and capture exit codes
  local exit1=0 exit2=0
  wait "$pid1" || exit1=$?
  wait "$pid2" || exit2=$?

  # Both should succeed
  assert [ "$exit1" -eq 0 ]
  assert [ "$exit2" -eq 0 ]

  # Both worktrees should exist
  assert [ -d "$worktrees_dir/concurrent-a" ]
  assert [ -d "$worktrees_dir/concurrent-b" ]

  # Both branches should have correct config
  cd "$repo_dir"
  local remote_a remote_b merge_a merge_b
  remote_a=$(git config "branch.concurrent-a.remote")
  remote_b=$(git config "branch.concurrent-b.remote")
  merge_a=$(git config "branch.concurrent-a.merge")
  merge_b=$(git config "branch.concurrent-b.merge")

  assert [ "$remote_a" = "origin" ]
  assert [ "$remote_b" = "origin" ]
  assert [ "$merge_a" = "refs/heads/concurrent-a" ]
  assert [ "$merge_b" = "refs/heads/concurrent-b" ]
}

# --- STORY-025: _wt_open hook receives origin/<branch> as base ref ---

@test "_wt_open passes origin/<branch> as base ref to created hook" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a branch and push to origin
  git checkout -b hook-ref-test >/dev/null 2>&1
  echo "data" > hookref.txt
  git add hookref.txt
  git commit -m "hook ref commit" >/dev/null 2>&1
  git push origin hook-ref-test >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git branch -D hook-ref-test >/dev/null 2>&1

  # Set up marker hook to capture args
  local marker="$TEST_TEMP_DIR/hook_marker"
  create_marker_hook "$GWT_CREATE_HOOK" "$marker"

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_open "hook-ref-test" "$GWT_WORKTREES_DIR"
  assert_success

  # Hook marker should contain origin/hook-ref-test as $3
  assert [ -f "$marker" ]
  run cat "$marker"
  assert_output --partial ":origin/hook-ref-test:"
}

# --- STORY-025: _wt_open fast-forward behavior ---

@test "_wt_open fast-forwards local branch to origin when behind" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a branch, push to origin
  git checkout -b ff-test >/dev/null 2>&1
  echo "v1" > ff.txt
  git add ff.txt
  git commit -m "ff v1" >/dev/null 2>&1
  git push origin ff-test >/dev/null 2>&1

  # Add another commit on origin (simulate remote progress)
  echo "v2" > ff.txt
  git add ff.txt
  git commit -m "ff v2" >/dev/null 2>&1
  git push origin ff-test >/dev/null 2>&1

  # Go back to main and delete local branch (keep remote)
  git checkout main >/dev/null 2>&1
  git branch -D ff-test >/dev/null 2>&1

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_open "ff-test" "$GWT_WORKTREES_DIR"
  assert_success

  # Worktree should have the latest content
  local content
  content=$(cat "$GWT_WORKTREES_DIR/ff-test/ff.txt")
  assert [ "$content" = "v2" ]
}

@test "_wt_open skips fast-forward when no remote tracking branch exists" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a local-only branch (not pushed to origin)
  git branch local-only >/dev/null 2>&1

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_open "local-only" "$GWT_WORKTREES_DIR"
  assert_success

  # Should succeed without any FF warning
  refute_output --partial "could not fast-forward"
}

@test "_wt_open warns but succeeds when fast-forward fails (diverged)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a branch with a commit and push to origin
  git checkout -b diverge-test >/dev/null 2>&1
  echo "shared-base" > diverge.txt
  git add diverge.txt
  git commit -m "diverge base" >/dev/null 2>&1
  git push origin diverge-test >/dev/null 2>&1

  # Save the base commit
  local base_commit
  base_commit=$(git rev-parse HEAD)

  # Add a LOCAL-only commit (do NOT push)
  echo "local-only" > local.txt
  git add local.txt
  git commit -m "local diverge" >/dev/null 2>&1
  local local_tip
  local_tip=$(git rev-parse HEAD)

  # Go back to base and create a different commit on origin
  git checkout main >/dev/null 2>&1
  git checkout -b diverge-tmp "$base_commit" >/dev/null 2>&1
  echo "origin-only" > remote.txt
  git add remote.txt
  git commit -m "remote diverge" >/dev/null 2>&1
  git push --force origin diverge-tmp:diverge-test >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git branch -D diverge-tmp >/dev/null 2>&1

  # Delete the local diverge-test branch and re-create it at local_tip
  # This creates a state where local diverge-test and origin/diverge-test have diverged
  git branch -D diverge-test >/dev/null 2>&1
  git branch diverge-test "$local_tip" >/dev/null 2>&1

  # Fetch so we have the updated origin/diverge-test
  git fetch origin --prune >/dev/null 2>&1

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_open "diverge-test" "$GWT_WORKTREES_DIR"
  assert_success

  # Should print warning about failed FF
  assert_output --partial "could not fast-forward"
}

# --- STORY-031: _wt_dir_name ---

@test "_wt_dir_name replaces slash with dash" {
  run _wt_dir_name "bugfix/CORE-615-foo"
  assert_success
  assert_output "bugfix-CORE-615-foo"
}

@test "_wt_dir_name replaces slash in feature prefix" {
  run _wt_dir_name "feature/my-feature"
  assert_success
  assert_output "feature-my-feature"
}

@test "_wt_dir_name is identity for branch with no slash" {
  run _wt_dir_name "no-slash"
  assert_success
  assert_output "no-slash"
}

@test "_wt_dir_name replaces multiple consecutive slashes individually" {
  run _wt_dir_name "a//b"
  assert_success
  assert_output "a--b"
}

# --- STORY-031: _wt_create with slash branch name ---

@test "_wt_create creates flat directory for slash branch name" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_create "bugfix/CORE-615-foo" "origin/main" "$GWT_WORKTREES_DIR"
  assert_success

  # Flat directory should exist
  assert [ -d "$GWT_WORKTREES_DIR/bugfix-CORE-615-foo" ]

  # Nested directory must NOT exist
  assert [ ! -d "$GWT_WORKTREES_DIR/bugfix" ]
}

@test "_wt_create preserves git branch name with slash" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_create "feature/my-feature" "origin/main" "$GWT_WORKTREES_DIR"
  assert_success

  # Git branch should have original slash name
  run _branch_exists "feature/my-feature"
  assert_success

  # Directory is flat
  assert [ -d "$GWT_WORKTREES_DIR/feature-my-feature" ]
}

# --- STORY-031: _wt_open with slash branch name ---

@test "_wt_open creates flat directory for slash branch name" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Create a slash-named branch and push it to origin
  git checkout -b "bugfix/CORE-615-foo" >/dev/null 2>&1
  echo "content" > bugfix.txt
  git add bugfix.txt
  git commit -m "bugfix commit" >/dev/null 2>&1
  git push origin "bugfix/CORE-615-foo" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git branch -D "bugfix/CORE-615-foo" >/dev/null 2>&1

  mkdir -p "$GWT_WORKTREES_DIR"
  run _wt_open "bugfix/CORE-615-foo" "$GWT_WORKTREES_DIR"
  assert_success

  # Flat directory should exist
  assert [ -d "$GWT_WORKTREES_DIR/bugfix-CORE-615-foo" ]

  # Nested directory must NOT exist
  assert [ ! -d "$GWT_WORKTREES_DIR/bugfix" ]
}
