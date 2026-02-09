#!/usr/bin/env bats
# Tests for lib/config.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# --- _config_load: parses all fields ---

@test "_config_load parses all fields from config.json" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  _config_load

  assert [ "$GWT_PROJECT_NAME" = "test-project" ]
  assert [ "$GWT_WORKTREES_DIR" = "$TEST_TEMP_DIR/test-project_worktrees" ]
  assert [ "$GWT_MAIN_REF" = "origin/main" ]
  assert [ "$GWT_DEV_REF" = "origin/main" ]
  assert [ "$GWT_DEV_SUFFIX" = "_RN" ]
  assert [ "$GWT_WORKTREE_WARN_THRESHOLD" = "20" ]
}

# --- _config_load: defaults ---

@test "_config_load applies defaults for missing fields" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Write minimal config with only projectName
  mkdir -p "$repo_dir/.worktrees/hooks"
  cat > "$repo_dir/.worktrees/config.json" <<'JSON'
{
  "projectName": "my-proj"
}
JSON

  _config_load

  assert [ "$GWT_PROJECT_NAME" = "my-proj" ]
  assert [ "$GWT_MAIN_REF" = "origin/main" ]
  assert [ "$GWT_DEV_REF" = "origin/release-next" ]
  assert [ "$GWT_DEV_SUFFIX" = "_RN" ]
  assert [ "$GWT_WORKTREE_WARN_THRESHOLD" = "20" ]
}

@test "_config_load uses _project_name when projectName empty" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  mkdir -p "$repo_dir/.worktrees/hooks"
  cat > "$repo_dir/.worktrees/config.json" <<'JSON'
{}
JSON

  _config_load

  # Falls back to _project_name which reads package.json name
  assert [ "$GWT_PROJECT_NAME" = "test-project" ]
}

# --- _config_load: missing config ---

@test "_config_load errors when config.json missing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # No .worktrees/config.json
  run _config_load
  assert_failure
  assert_output --partial "wt --init"
}

# --- _config_load: resolves relative hook paths ---

@test "_config_load resolves relative hook paths to absolute" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  _config_load

  # Hooks should be absolute paths
  assert [ "${GWT_CREATE_HOOK#/}" != "$GWT_CREATE_HOOK" ]
  assert [ "${GWT_SWITCH_HOOK#/}" != "$GWT_SWITCH_HOOK" ]

  # Should contain the repo path
  case "$GWT_CREATE_HOOK" in *"$repo_dir"*) ;; *) fail "CREATE_HOOK does not contain repo_dir" ;; esac
  case "$GWT_SWITCH_HOOK" in *"$repo_dir"*) ;; *) fail "SWITCH_HOOK does not contain repo_dir" ;; esac
}

@test "_config_load keeps absolute hook paths unchanged" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  mkdir -p "$repo_dir/.worktrees/hooks"
  cat > "$repo_dir/.worktrees/config.json" <<JSON
{
  "projectName": "test-project",
  "worktreesDir": "$TEST_TEMP_DIR/test-project_worktrees",
  "mainBranch": "origin/main",
  "openCmd": "/absolute/path/to/hook.sh",
  "switchCmd": "/absolute/path/to/switch.sh"
}
JSON

  _config_load

  assert [ "$GWT_CREATE_HOOK" = "/absolute/path/to/hook.sh" ]
  assert [ "$GWT_SWITCH_HOOK" = "/absolute/path/to/switch.sh" ]
}

@test "_config_load derives worktreesDir when not set" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  mkdir -p "$repo_dir/.worktrees/hooks"
  cat > "$repo_dir/.worktrees/config.json" <<'JSON'
{
  "projectName": "test-project"
}
JSON

  _config_load

  # Should be parent_of_repo/test-project_worktrees
  local expected="${repo_dir%/*}/test-project_worktrees"
  assert [ "$GWT_WORKTREES_DIR" = "$expected" ]
}
