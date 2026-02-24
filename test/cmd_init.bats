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

@test "_cmd_init creates config.json and hook files with defaults" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Provide empty answers (accept all defaults) via heredoc
  # 3 prompts: Project name, Main branch, Warning threshold
  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF



EOF
  "
  assert_success

  # Config should exist
  assert [ -f "$repo_dir/.worktrees/config.json" ]

  # Hooks should exist and be executable
  assert [ -x "$repo_dir/.worktrees/hooks/created.sh" ]
  assert [ -x "$repo_dir/.worktrees/hooks/switched.sh" ]
}

@test "_cmd_init creates config.json with custom values" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Provide custom answers to all 3 prompts
  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF
my-custom-project
origin/main
15
EOF
  "
  assert_success

  # Config should exist and contain custom project name
  assert [ -f "$repo_dir/.worktrees/config.json" ]
  run jq -r '.projectName' "$repo_dir/.worktrees/config.json"
  assert_output "my-custom-project"

  # Threshold should be custom value
  run jq -r '.worktreeWarningThreshold' "$repo_dir/.worktrees/config.json"
  assert_output "15"
}

@test "_cmd_init works in non-Node.js repo (no package.json)" {
  cd "$TEST_TEMP_DIR"
  mkdir -p init-no-pkg
  cd init-no-pkg
  git init >/dev/null 2>&1
  git config user.email "test@test.com"
  git config user.name "Test User"
  echo "init" > README.md
  git add README.md
  git commit -m "initial" >/dev/null 2>&1

  # _cmd_init should work without package.json; project name falls back to dirname
  run bash -c "
    cd '$TEST_TEMP_DIR/init-no-pkg'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF



EOF
  "
  assert_success
  assert [ -f "$TEST_TEMP_DIR/init-no-pkg/.worktrees/config.json" ]
}

# --- STORY-034: verbose feedback tests ---

@test "_cmd_init prints 'Setting up hooks directory...' step message" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF


EOF
  "
  assert_success
  assert_output --partial "Setting up hooks directory..."
}

@test "_cmd_init prints 'Writing hook scripts...' step message" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF


EOF
  "
  assert_success
  assert_output --partial "Writing hook scripts..."
}

@test "_cmd_init prints 'Creating .worktrees/config.json...' step message" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF


EOF
  "
  assert_success
  assert_output --partial "Creating .worktrees/config.json..."
}

@test "_cmd_init prints 'Done.' summary at completion" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF


EOF
  "
  assert_success
  assert_output --partial "Done."
}

@test "_cmd_init summary lists config.json and hook files" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init <<EOF


EOF
  "
  assert_success
  assert_output --partial "config.json"
  assert_output --partial "created.sh"
  assert_output --partial "switched.sh"
}
