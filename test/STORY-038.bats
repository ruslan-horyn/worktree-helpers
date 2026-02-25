#!/usr/bin/env bats
# STORY-038: Descriptive usage with placeholders in command output
#
# Tests verify that:
#   - _cmd_help shows <placeholder> next to every flag that takes an argument
#   - _cmd_help contains concrete usage examples
#   - Per-command help functions exist for ALL commands (including lock/unlock/log/rename)
#   - wt.sh router dispatches --help for lock, unlock, log, rename
#   - Placeholder names are consistent across _cmd_help and all _help_* functions
#   - shellcheck passes on lib/commands.sh
#
# Tests MUST fail before implementation. If a test passes unexpectedly,
# a comment explains why it may be a false positive.

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# ---------------------------------------------------------------------------
# AC 1: _cmd_help shows <branch> next to -n, --new
# ---------------------------------------------------------------------------

@test "AC1: _cmd_help shows <branch> placeholder next to -n/--new" {
  run _cmd_help
  assert_success
  # The line must contain both '--new' and '<branch>' to satisfy the AC
  echo "$output" | grep -q -- '--new.*<branch>\|<branch>.*--new'
}

# ---------------------------------------------------------------------------
# AC 2: _cmd_help shows <worktree> next to switch/remove/lock/unlock
# ---------------------------------------------------------------------------

@test "AC2a: _cmd_help shows <worktree> placeholder next to -s/--switch" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--switch.*<worktree>\|<worktree>.*--switch'
}

@test "AC2b: _cmd_help shows <worktree> placeholder next to -r/--remove" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--remove.*<worktree>\|<worktree>.*--remove'
}

@test "AC2c: _cmd_help shows <worktree> placeholder next to -L/--lock" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--lock.*<worktree>\|<worktree>.*--lock'
}

@test "AC2d: _cmd_help shows <worktree> placeholder next to -U/--unlock" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--unlock.*<worktree>\|<worktree>.*--unlock'
}

# ---------------------------------------------------------------------------
# AC 3: _cmd_help shows <days> next to -c/--clear
# ---------------------------------------------------------------------------

@test "AC3: _cmd_help shows <days> placeholder next to -c/--clear" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--clear.*<days>\|<days>.*--clear'
}

# ---------------------------------------------------------------------------
# AC 4: _cmd_help shows <ref> next to -b/--from
# ---------------------------------------------------------------------------

@test "AC4: _cmd_help shows <ref> placeholder next to -b/--from" {
  run _cmd_help
  assert_success
  assert_output --partial "<ref>"
  echo "$output" | grep -q -- '--from.*<ref>\|<ref>.*--from'
}

# ---------------------------------------------------------------------------
# AC 5: _cmd_help shows <pattern> next to --pattern
# ---------------------------------------------------------------------------

@test "AC5: _cmd_help shows <pattern> placeholder next to --pattern" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--pattern.*<pattern>\|<pattern>.*--pattern'
}

# ---------------------------------------------------------------------------
# AC 6: _cmd_help shows <date> next to --since
# ---------------------------------------------------------------------------

@test "AC6: _cmd_help shows <date> placeholder next to --since" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--since.*<date>\|<date>.*--since'
}

# ---------------------------------------------------------------------------
# AC 7: _cmd_help shows <pattern> next to --author
# ---------------------------------------------------------------------------

@test "AC7: _cmd_help shows <pattern> placeholder next to --author" {
  run _cmd_help
  assert_success
  echo "$output" | grep -q -- '--author.*<pattern>\|<pattern>.*--author'
}

# ---------------------------------------------------------------------------
# AC 8: _cmd_help contains at least 1 concrete example line for -n
# ---------------------------------------------------------------------------

@test "AC8: _cmd_help contains concrete example line for -n (e.g. wt -n feature-foo)" {
  run _cmd_help
  assert_success
  # A concrete example uses a realistic name, not just a placeholder
  assert_output --partial "wt -n feature-"
}

# ---------------------------------------------------------------------------
# AC 9: _cmd_help contains at least 1 concrete example line for -c
# ---------------------------------------------------------------------------

@test "AC9: _cmd_help contains concrete example line for -c (e.g. wt -c 30)" {
  run _cmd_help
  assert_success
  assert_output --partial "wt -c 30"
}

# ---------------------------------------------------------------------------
# AC 10: _help_lock, _help_unlock, _help_log, _help_rename must exist
# ---------------------------------------------------------------------------

@test "AC10a: _help_lock function exists" {
  run declare -f _help_lock
  assert_success
}

@test "AC10b: _help_unlock function exists" {
  run declare -f _help_unlock
  assert_success
}

@test "AC10c: _help_log function exists" {
  run declare -f _help_log
  assert_success
}

@test "AC10d: _help_rename function exists" {
  run declare -f _help_rename
  assert_success
}

# ---------------------------------------------------------------------------
# AC 11: _help_lock shows <worktree> placeholder and at least 1 example
# ---------------------------------------------------------------------------

@test "AC11a: _help_lock outputs a description" {
  run _help_lock
  assert_success
  assert_output --partial "Lock"
}

@test "AC11b: _help_lock shows <worktree> placeholder" {
  run _help_lock
  assert_success
  assert_output --partial "<worktree>"
}

@test "AC11c: _help_lock shows at least 1 concrete example with wt -L" {
  run _help_lock
  assert_success
  assert_output --partial "wt -L"
}

# ---------------------------------------------------------------------------
# AC 12: _help_unlock shows <worktree> placeholder and at least 1 example
# ---------------------------------------------------------------------------

@test "AC12a: _help_unlock outputs a description" {
  run _help_unlock
  assert_success
  assert_output --partial "Unlock"
}

@test "AC12b: _help_unlock shows <worktree> placeholder" {
  run _help_unlock
  assert_success
  assert_output --partial "<worktree>"
}

@test "AC12c: _help_unlock shows at least 1 concrete example with wt -U" {
  run _help_unlock
  assert_success
  assert_output --partial "wt -U"
}

# ---------------------------------------------------------------------------
# AC 13: _help_log shows <branch> placeholder and at least 1 example
# ---------------------------------------------------------------------------

@test "AC13a: _help_log outputs a description" {
  run _help_log
  assert_success
  assert_output --partial "log"
}

@test "AC13b: _help_log shows <branch> placeholder" {
  run _help_log
  assert_success
  assert_output --partial "<branch>"
}

@test "AC13c: _help_log shows at least 1 concrete example with wt --log" {
  run _help_log
  assert_success
  assert_output --partial "wt --log"
}

@test "AC13d: _help_log shows --since and --author options" {
  run _help_log
  assert_success
  assert_output --partial "--since"
  assert_output --partial "--author"
}

# ---------------------------------------------------------------------------
# AC 14: _help_rename shows <new-branch> placeholder and at least 1 example
# ---------------------------------------------------------------------------

@test "AC14a: _help_rename outputs a description" {
  run _help_rename
  assert_success
  assert_output --partial "Rename"
}

@test "AC14b: _help_rename shows <new-branch> placeholder" {
  run _help_rename
  assert_success
  assert_output --partial "<new-branch>"
}

@test "AC14c: _help_rename shows at least 1 concrete example with wt --rename" {
  run _help_rename
  assert_success
  assert_output --partial "wt --rename"
}

# ---------------------------------------------------------------------------
# AC 11-14 router: wt <cmd> --help dispatches to _help_* (lock/unlock/log/rename)
# ---------------------------------------------------------------------------

@test "AC11-router: wt -L --help shows lock help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -L --help
  assert_success
  assert_output --partial "Lock"
  assert_output --partial "<worktree>"
  # Must not attempt actual lock operation (no prompt or git output)
  refute_output --partial "lock>"
}

@test "AC11-router: wt --lock --help shows lock help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --lock --help
  assert_success
  assert_output --partial "Lock"
}

@test "AC12-router: wt -U --help shows unlock help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -U --help
  assert_success
  assert_output --partial "Unlock"
  assert_output --partial "<worktree>"
  refute_output --partial "unlock>"
}

@test "AC12-router: wt --unlock --help shows unlock help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --unlock --help
  assert_success
  assert_output --partial "Unlock"
}

@test "AC13-router: wt --log --help shows log help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --log --help
  assert_success
  assert_output --partial "<branch>"
  # Must not run git log
  refute_output --partial "fatal:"
}

@test "AC14-router: wt --rename --help shows rename help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --rename --help
  assert_success
  assert_output --partial "Rename"
  assert_output --partial "<new-branch>"
  # Must not attempt rename
  refute_output --partial "Renamed"
}

# ---------------------------------------------------------------------------
# AC 15: Placeholder names consistent across _cmd_help and all _help_* functions
# ---------------------------------------------------------------------------

@test "AC15a: _cmd_help and _help_new both use <branch> (not <branchname> or other variants)" {
  run _cmd_help
  assert_success
  assert_output --partial "<branch>"

  run _help_new
  assert_success
  assert_output --partial "<branch>"
}

@test "AC15b: _cmd_help and _help_switch both use <worktree> (not <name> or other variants)" {
  run _cmd_help
  assert_success
  assert_output --partial "<worktree>"

  run _help_switch
  assert_success
  assert_output --partial "<worktree>"
}

@test "AC15c: _cmd_help and _help_clear both use <days> (not <n> or other variants)" {
  run _cmd_help
  assert_success
  assert_output --partial "<days>"

  run _help_clear
  assert_success
  assert_output --partial "<days>"
}

@test "AC15d: _cmd_help and _help_new both use <ref> (not <branch-or-commit> or other variants)" {
  run _cmd_help
  assert_success
  assert_output --partial "<ref>"

  run _help_new
  assert_success
  assert_output --partial "<ref>"
}

@test "AC15e: _cmd_help and _help_clear both use <pattern> (not <glob> or other variants)" {
  run _cmd_help
  assert_success
  assert_output --partial "<pattern>"

  run _help_clear
  assert_success
  assert_output --partial "<pattern>"
}

# ---------------------------------------------------------------------------
# AC 16: shellcheck passes on lib/commands.sh
# ---------------------------------------------------------------------------

@test "AC16: shellcheck passes on lib/commands.sh" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  run shellcheck "$PROJECT_ROOT/lib/commands.sh"
  assert_success
}

# ---------------------------------------------------------------------------
# Edge cases: help flags interact safely with no-op for commands that take
# arguments but --help is present (no partial execution)
# ---------------------------------------------------------------------------

@test "edge: wt -L <worktree> --help shows help, does not lock" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -L some-worktree --help
  assert_success
  assert_output --partial "Lock"
  refute_output --partial "Locked"
}

@test "edge: wt -U <worktree> --help shows help, does not unlock" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -U some-worktree --help
  assert_success
  assert_output --partial "Unlock"
  refute_output --partial "Unlocked"
}

@test "edge: wt --rename <new-branch> --help shows help, does not rename" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --rename some-new-branch --help
  assert_success
  assert_output --partial "Rename"
  refute_output --partial "Renamed"
}

@test "edge: wt --log --help with extra args shows help, does not run log" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --log feature-branch --help
  assert_success
  assert_output --partial "<branch>"
  refute_output --partial "fatal:"
}

# ---------------------------------------------------------------------------
# Regression: existing per-command --help still works after changes
# ---------------------------------------------------------------------------

@test "regression: wt -n --help still works" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -n --help
  assert_success
  assert_output --partial "Create a new worktree"
  assert_output --partial "<branch>"
}

@test "regression: wt -s --help still works" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -s --help
  assert_success
  assert_output --partial "Switch"
}

@test "regression: wt -r --help still works" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -r --help
  assert_success
  assert_output --partial "Remove"
}

@test "regression: wt -c --help still works" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -c --help
  assert_success
  assert_output --partial "<days>"
}

@test "regression: wt -h alone shows full help" {
  load_wt_full

  run wt -h
  assert_success
  assert_output --partial "wt - Git Worktree Helpers"
  assert_output --partial "Usage:"
}

@test "regression: wt --help alone shows full help" {
  load_wt_full

  run wt --help
  assert_success
  assert_output --partial "wt - Git Worktree Helpers"
}
