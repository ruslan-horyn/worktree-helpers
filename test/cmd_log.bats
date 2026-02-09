#!/usr/bin/env bats
# Tests for _cmd_log in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_log shows commits between main and feature branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create a feature branch with commits
  git checkout -b log-feature >/dev/null 2>&1
  echo "feature code" > feature.txt
  git add feature.txt
  git commit -m "add feature code" >/dev/null 2>&1

  run _cmd_log "log-feature" "0" "" ""
  assert_success
  assert_output --partial "add feature code"
}

@test "_cmd_log uses current branch when no branch given" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  git checkout -b log-current >/dev/null 2>&1
  echo "current" > current.txt
  git add current.txt
  git commit -m "current branch commit" >/dev/null 2>&1

  run _cmd_log "" "0" "" ""
  assert_success
  assert_output --partial "current branch commit"
}
