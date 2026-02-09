#!/usr/bin/env bats
# Tests for _cmd_rename in lib/commands.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# Helper: create a worktree from test repo and cd into it
# Usage: create_worktree_and_cd <branch>
create_worktree_and_cd() {
  local branch="$1"
  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/$branch"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add -b "$branch" "$wt_path" HEAD >/dev/null 2>&1
  cd "$wt_path"
}

# --- Validation errors ---

@test "_cmd_rename errors without new branch argument" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "old-branch"

  run _cmd_rename "" 1
  assert_failure
  assert_output --partial "Usage: wt --rename"
}

@test "_cmd_rename errors when not in a worktree (main repo)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  run _cmd_rename "new-name" 1
  assert_failure
  assert_output --partial "Cannot rename from main repo"
}

@test "_cmd_rename errors when new branch already exists" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create the target branch first
  git branch "existing-branch" >/dev/null 2>&1

  create_worktree_and_cd "old-branch"

  run _cmd_rename "existing-branch" 1
  assert_failure
  assert_output --partial "already exists"
}

@test "_cmd_rename errors when new name is the same as current name" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "same-branch"

  run _cmd_rename "same-branch" 1
  assert_failure
  assert_output --partial "same as current name"
}

@test "_cmd_rename errors when trying to rename main branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Create worktree on a custom branch
  create_worktree_and_cd "protected-branch"

  # Write config with mainBranch pointing to our branch
  local cfg_repo="$TEST_TEMP_DIR/repo"
  mkdir -p "$cfg_repo/.worktrees/hooks"
  cat > "$cfg_repo/.worktrees/config.json" <<JSON
{
  "projectName": "test-project",
  "worktreesDir": "$TEST_TEMP_DIR/test-project_worktrees",
  "mainBranch": "origin/protected-branch",
  "devBranch": "origin/main",
  "devSuffix": "_RN",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh",
  "worktreeWarningThreshold": 20
}
JSON
  cat > "$cfg_repo/.worktrees/hooks/created.sh" <<'SH'
#!/usr/bin/env bash
cd "$1" || exit 1
SH
  cat > "$cfg_repo/.worktrees/hooks/switched.sh" <<'SH'
#!/usr/bin/env bash
cd "$1" || exit 1
SH
  chmod +x "$cfg_repo/.worktrees/hooks"/*.sh

  run _cmd_rename "new-main" 1
  assert_failure
  assert_output --partial "Cannot rename the main branch"
}

# --- Happy path ---

@test "_cmd_rename renames branch with force flag" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "old-name"

  run _cmd_rename "new-name" 1
  assert_success
  assert_output --partial "Renamed 'old-name' → 'new-name'"
  assert_output --partial "Worktree:"

  # Old branch should not exist, new branch should
  cd "$repo_dir"
  run _branch_exists "old-name"
  assert_failure
  run _branch_exists "new-name"
  assert_success
}

@test "_cmd_rename moves worktree directory" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "old-dir"

  local old_path="$TEST_TEMP_DIR/test-project_worktrees/old-dir"
  local new_path="$TEST_TEMP_DIR/test-project_worktrees/new-dir"

  run _cmd_rename "new-dir" 1
  assert_success

  # Old dir should be gone, new dir should exist
  assert [ ! -d "$old_path" ]
  assert [ -d "$new_path" ]
}

@test "_cmd_rename updates remote tracking when remote branch exists" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create and push the branch to origin
  git checkout -b "push-me" >/dev/null 2>&1
  git push -u origin "push-me" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1

  # Create worktree for the pushed branch
  local wt_path="$TEST_TEMP_DIR/test-project_worktrees/push-me"
  mkdir -p "$TEST_TEMP_DIR/test-project_worktrees"
  git worktree add "$wt_path" "push-me" >/dev/null 2>&1
  cd "$wt_path"

  run _cmd_rename "renamed-push" 1
  assert_success

  # Check that merge config is updated
  cd "$TEST_TEMP_DIR/test-project_worktrees/renamed-push"
  local merge_ref
  merge_ref=$(git config "branch.renamed-push.merge")
  assert [ "$merge_ref" = "refs/heads/renamed-push" ]
}

# --- Confirmation prompt ---

@test "_cmd_rename aborts when user says no" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "keep-me"

  run _cmd_rename "changed" 0 <<< "n"
  assert_failure
  assert_output --partial "Aborted"

  # Branch should still exist unchanged
  cd "$repo_dir"
  run _branch_exists "keep-me"
  assert_success
}

@test "_cmd_rename proceeds when user says yes" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "ask-me"

  run _cmd_rename "confirmed" 0 <<< "y"
  assert_success
  assert_output --partial "Renamed 'ask-me' → 'confirmed'"
}

# --- Router integration ---

@test "wt --rename routes to _cmd_rename" {
  load_wt_full

  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "route-old"

  run wt --rename "route-new" -f
  assert_success
  assert_output --partial "Renamed 'route-old' → 'route-new'"
}

@test "wt --rename shows usage with no argument" {
  load_wt_full

  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  create_worktree_and_cd "no-arg"

  run wt --rename -f
  assert_failure
  assert_output --partial "Usage: wt --rename"
}

# --- Help text ---

@test "_cmd_help includes --rename" {
  run _cmd_help
  assert_success
  assert_output --partial "--rename"
  assert_output --partial "Rename current worktree"
}
