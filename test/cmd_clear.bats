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

@test "_cmd_clear removal message shows worktree name not full path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  local wt_path="$GWT_WORKTREES_DIR/name-display-branch"
  git worktree add -b name-display-branch "$wt_path" HEAD >/dev/null 2>&1

  # Backdate the .git file to make it "old"
  touch -t 202001010000 "$wt_path/.git"

  run _cmd_clear "1" "1" "0" "0"
  assert_success
  assert_output --partial "Removed name-display-branch"
  refute_output --partial "Removed $wt_path"
}

@test "_cmd_clear listing shows worktree name not full path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  local wt_path="$GWT_WORKTREES_DIR/listed-name-branch"
  git worktree add -b listed-name-branch "$wt_path" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_path/.git"

  # dry-run to see the listing without deleting
  run _cmd_clear "1" "1" "0" "0" "0" "" "1"
  assert_success
  assert_output --partial "listed-name-branch"
  refute_output --partial "$wt_path"
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

# --- --merged flag tests ---

@test "_cmd_clear --merged removes worktrees with merged branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a branch, add a commit, merge it into main, push to origin
  git checkout -b merged-feat >/dev/null 2>&1
  echo "feat" > feat.txt
  git add feat.txt
  git commit -m "feat" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git merge merged-feat >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  # Create worktree for the merged branch
  local wt_path="$GWT_WORKTREES_DIR/merged-feat"
  git worktree add "$wt_path" merged-feat >/dev/null 2>&1

  # days="" merged=1 pattern="" dry_run=0
  run _cmd_clear "" "1" "0" "0" "1" "" "0"
  assert_success
  assert_output --partial "Removed"
  assert [ ! -d "$wt_path" ]
}

@test "_cmd_clear --merged skips unmerged worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create worktree with unmerged branch (diverges from main)
  local wt_path="$GWT_WORKTREES_DIR/unmerged-feat"
  git worktree add -b unmerged-feat "$wt_path" HEAD >/dev/null 2>&1
  git -C "$wt_path" commit --allow-empty -m "unmerged work" >/dev/null 2>&1

  # days="" merged=1 pattern="" dry_run=0
  run _cmd_clear "" "1" "0" "0" "1" "" "0"
  assert_success
  assert_output --partial "No worktrees to clear"
  assert [ -d "$wt_path" ]
}

@test "_cmd_clear --merged skips detached HEAD worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a detached HEAD worktree
  local commit_hash
  commit_hash=$(git rev-parse HEAD)
  local wt_path="$GWT_WORKTREES_DIR/detached-wt"
  git worktree add --detach "$wt_path" "$commit_hash" >/dev/null 2>&1

  # days="" merged=1 pattern="" dry_run=0
  run _cmd_clear "" "1" "0" "0" "1" "" "0"
  assert_success
  # Should not remove the detached worktree
  assert [ -d "$wt_path" ]
}

# --- --pattern flag tests ---

@test "_cmd_clear --pattern filters by branch name glob" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create worktrees matching and not matching the pattern
  local fix_wt="$GWT_WORKTREES_DIR/fix-login"
  git worktree add -b "fix-login" "$fix_wt" HEAD >/dev/null 2>&1

  local feat_wt="$GWT_WORKTREES_DIR/feat-api"
  git worktree add -b "feat-api" "$feat_wt" HEAD >/dev/null 2>&1

  # days="" merged=0 pattern="fix-*" dry_run=0, force=1
  run _cmd_clear "" "1" "0" "0" "0" "fix-*" "0"
  assert_success
  assert_output --partial "Removed"

  # fix-login should be removed, feat-api should remain
  assert [ ! -d "$fix_wt" ]
  assert [ -d "$feat_wt" ]
}

@test "_cmd_clear --pattern with no matches shows no worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a worktree that doesn't match
  local wt_path="$GWT_WORKTREES_DIR/feat-something"
  git worktree add -b "feat-something" "$wt_path" HEAD >/dev/null 2>&1

  # days="" merged=0 pattern="nonexistent-*" dry_run=0
  run _cmd_clear "" "1" "0" "0" "0" "nonexistent-*" "0"
  assert_success
  assert_output --partial "No worktrees to clear"
  assert [ -d "$wt_path" ]
}

# --- --dry-run flag tests ---

@test "_cmd_clear --dry-run does not delete anything" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_path="$GWT_WORKTREES_DIR/dry-run-test"
  git worktree add -b "dry-run-test" "$wt_path" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_path/.git"

  # days=1 force=1 dev_only=0 main_only=0 merged=0 pattern="" dry_run=1
  run _cmd_clear "1" "1" "0" "0" "0" "" "1"
  assert_success
  # Worktree should still exist
  assert [ -d "$wt_path" ]
}

@test "_cmd_clear --dry-run output contains [dry-run] prefix" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_path="$GWT_WORKTREES_DIR/dry-run-prefix"
  git worktree add -b "dry-run-prefix" "$wt_path" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_path/.git"

  run _cmd_clear "1" "1" "0" "0" "0" "" "1"
  assert_success
  assert_output --partial "[dry-run]"
}

@test "_cmd_clear --dry-run shows count of worktrees that would be removed" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create two old worktrees
  local wt1="$GWT_WORKTREES_DIR/dry-count-1"
  git worktree add -b "dry-count-1" "$wt1" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt1/.git"

  local wt2="$GWT_WORKTREES_DIR/dry-count-2"
  git worktree add -b "dry-count-2" "$wt2" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt2/.git"

  run _cmd_clear "1" "1" "0" "0" "0" "" "1"
  assert_success
  assert_output --partial "[dry-run] 2 worktree(s) would be removed"
}

@test "_cmd_clear --dry-run with no matches shows dry-run no worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # No worktrees created, nothing to match
  run _cmd_clear "1" "1" "0" "0" "0" "" "1"
  assert_success
  assert_output --partial "[dry-run] No worktrees would be removed"
}

# --- Combined flags tests ---

@test "_cmd_clear --merged --pattern combined: both filters must match" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a merged branch matching pattern
  git checkout -b fix-merged >/dev/null 2>&1
  echo "fix" > fix.txt
  git add fix.txt
  git commit -m "fix" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git merge fix-merged >/dev/null 2>&1

  # Create a merged branch NOT matching pattern
  git checkout -b feat-merged >/dev/null 2>&1
  echo "feat" > feat.txt
  git add feat.txt
  git commit -m "feat" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git merge feat-merged >/dev/null 2>&1

  # Push merged state to origin so GWT_MAIN_REF (origin/main) is up to date
  git push origin main >/dev/null 2>&1

  local fix_merged_wt="$GWT_WORKTREES_DIR/fix-merged"
  git worktree add "$fix_merged_wt" fix-merged >/dev/null 2>&1

  local feat_merged_wt="$GWT_WORKTREES_DIR/feat-merged"
  git worktree add "$feat_merged_wt" feat-merged >/dev/null 2>&1

  # Create an unmerged branch matching pattern
  local fix_unmerged_wt="$GWT_WORKTREES_DIR/fix-unmerged"
  git worktree add -b fix-unmerged "$fix_unmerged_wt" HEAD >/dev/null 2>&1
  git -C "$fix_unmerged_wt" commit --allow-empty -m "unmerged" >/dev/null 2>&1

  # days="" merged=1 pattern="fix-*" dry_run=0 force=1
  run _cmd_clear "" "1" "0" "0" "1" "fix-*" "0"
  assert_success

  # Only fix-merged should be removed (matches both pattern and merged)
  assert [ ! -d "$fix_merged_wt" ]
  assert [ -d "$feat_merged_wt" ]
  assert [ -d "$fix_unmerged_wt" ]
}

@test "_cmd_clear --merged --dry-run previews merged without deleting" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a merged branch and push to origin
  git checkout -b merged-preview >/dev/null 2>&1
  echo "preview" > preview.txt
  git add preview.txt
  git commit -m "preview" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git merge merged-preview >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  local wt_path="$GWT_WORKTREES_DIR/merged-preview"
  git worktree add "$wt_path" merged-preview >/dev/null 2>&1

  # days="" merged=1 pattern="" dry_run=1
  run _cmd_clear "" "1" "0" "0" "1" "" "1"
  assert_success
  assert_output --partial "[dry-run]"
  assert_output --partial "merged-preview"
  assert_output --partial "1 worktree(s) would be removed"
  # Worktree should still exist
  assert [ -d "$wt_path" ]
}

# --- Days optional tests ---

@test "_cmd_clear days optional when --merged provided" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Should not error (days="" but merged=1)
  run _cmd_clear "" "1" "0" "0" "1" "" "0"
  assert_success
}

@test "_cmd_clear days optional when --pattern provided" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  # Should not error (days="" but pattern set)
  run _cmd_clear "" "1" "0" "0" "0" "fix-*" "0"
  assert_success
}

@test "_cmd_clear errors when no days and no --merged/--pattern" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # days="" merged=0 pattern="" — should error
  run _cmd_clear "" "1" "0" "0" "0" "" "0"
  assert_failure
  assert_output --partial "Usage"
}

# --- Age + new flags combined ---

@test "_cmd_clear days + --merged only removes old merged worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a merged branch with old worktree
  git checkout -b old-merged >/dev/null 2>&1
  echo "old" > old.txt
  git add old.txt
  git commit -m "old" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git merge old-merged >/dev/null 2>&1

  # Create a merged branch with recent worktree
  git checkout -b new-merged >/dev/null 2>&1
  echo "new" > new.txt
  git add new.txt
  git commit -m "new" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git merge new-merged >/dev/null 2>&1

  # Push merged state to origin
  git push origin main >/dev/null 2>&1

  local old_wt="$GWT_WORKTREES_DIR/old-merged"
  git worktree add "$old_wt" old-merged >/dev/null 2>&1
  touch -t 202001010000 "$old_wt/.git"

  local new_wt="$GWT_WORKTREES_DIR/new-merged"
  git worktree add "$new_wt" new-merged >/dev/null 2>&1
  # Don't backdate — this is recent

  # days=30 merged=1 — should only remove old-merged (old + merged)
  run _cmd_clear "30" "1" "0" "0" "1" "" "0"
  assert_success

  assert [ ! -d "$old_wt" ]
  assert [ -d "$new_wt" ]
}

# --- Locked worktrees with new flags ---

@test "_cmd_clear --merged still skips locked worktrees" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a merged branch and push to origin
  git checkout -b locked-merged >/dev/null 2>&1
  echo "locked" > locked.txt
  git add locked.txt
  git commit -m "locked" >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  git merge locked-merged >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  local wt_path="$GWT_WORKTREES_DIR/locked-merged"
  git worktree add "$wt_path" locked-merged >/dev/null 2>&1
  git worktree lock "$wt_path" >/dev/null 2>&1

  # days="" merged=1
  run _cmd_clear "" "1" "0" "0" "1" "" "0"
  assert_success
  # Locked worktree should still exist
  assert [ -d "$wt_path" ]
}

# --- Combined with existing flags ---

@test "_cmd_clear --pattern --dev-only combined" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # Create a dev worktree matching pattern
  local dev_match="$GWT_WORKTREES_DIR/fix-login_RN"
  git worktree add -b "fix-login_RN" "$dev_match" HEAD >/dev/null 2>&1

  # Create a non-dev worktree matching pattern
  local main_match="$GWT_WORKTREES_DIR/fix-header"
  git worktree add -b "fix-header" "$main_match" HEAD >/dev/null 2>&1

  # days="" dev_only=1 pattern="fix-*" force=1
  run _cmd_clear "" "1" "1" "0" "0" "fix-*" "0"
  assert_success

  # Only dev worktree matching pattern should be removed
  assert [ ! -d "$dev_match" ]
  assert [ -d "$main_match" ]
}
