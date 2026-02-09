#!/usr/bin/env bats
# Tests for _cmd_init in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_init creates config.json and hook files" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Provide answers to interactive prompts via stdin
  run bash -c "
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    echo '' | _cmd_init <<EOF
test-proj
$TEST_TEMP_DIR/test-proj_wt
origin/main
20
EOF
  "
  assert_success

  # Config should exist
  assert [ -f "$repo_dir/.worktrees/config.json" ]

  # Hooks should exist and be executable
  assert [ -x "$repo_dir/.worktrees/hooks/created.sh" ]
  assert [ -x "$repo_dir/.worktrees/hooks/switched.sh" ]
}

@test "_cmd_init errors when package.json missing" {
  cd "$TEST_TEMP_DIR"
  mkdir -p init-no-pkg
  cd init-no-pkg
  git init >/dev/null 2>&1

  run _cmd_init
  assert_failure
  assert_output --partial "package.json"
}
