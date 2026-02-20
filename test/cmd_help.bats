#!/usr/bin/env bats
# Tests for _cmd_help in lib/commands.sh and per-command help (STORY-036)

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_help outputs usage text" {
  run _cmd_help
  assert_success
  assert_output --partial "wt - Git Worktree Helpers"
  assert_output --partial "Usage:"
  assert_output --partial "--new"
  assert_output --partial "--switch"
  assert_output --partial "--remove"
  assert_output --partial "--list"
  assert_output --partial "--clear"
  assert_output --partial "--open"
  assert_output --partial "--lock"
  assert_output --partial "--unlock"
  assert_output --partial "--init"
  assert_output --partial "--log"
  assert_output --partial "--help"
  assert_output --partial "--from"
}

# --- _help_new ---

@test "_help_new outputs description for new command" {
  run _help_new
  assert_success
  assert_output --partial "Create a new worktree"
}

@test "_help_new outputs usage with placeholders" {
  run _help_new
  assert_success
  assert_output --partial "wt -n"
  assert_output --partial "<branch>"
  assert_output --partial "<ref>"
}

@test "_help_new outputs examples" {
  run _help_new
  assert_success
  assert_output --partial "wt -n feature-login"
}

@test "_help_new outputs --from option" {
  run _help_new
  assert_success
  assert_output --partial "--from"
}

# --- _help_switch ---

@test "_help_switch outputs description for switch command" {
  run _help_switch
  assert_success
  assert_output --partial "Switch"
}

@test "_help_switch outputs usage with placeholders" {
  run _help_switch
  assert_success
  assert_output --partial "wt -s"
  assert_output --partial "<worktree>"
}

@test "_help_switch outputs examples" {
  run _help_switch
  assert_success
  assert_output --partial "wt -s"
}

# --- _help_open ---

@test "_help_open outputs description for open command" {
  run _help_open
  assert_success
  assert_output --partial "Open"
}

@test "_help_open outputs usage with placeholders" {
  run _help_open
  assert_success
  assert_output --partial "wt -o"
  assert_output --partial "<branch>"
}

@test "_help_open outputs examples" {
  run _help_open
  assert_success
  assert_output --partial "wt -o"
}

# --- _help_remove ---

@test "_help_remove outputs description for remove command" {
  run _help_remove
  assert_success
  assert_output --partial "Remove"
}

@test "_help_remove outputs usage with placeholders" {
  run _help_remove
  assert_success
  assert_output --partial "wt -r"
  assert_output --partial "<worktree>"
}

@test "_help_remove outputs examples" {
  run _help_remove
  assert_success
  assert_output --partial "wt -r feature-login"
}

@test "_help_remove outputs --force option" {
  run _help_remove
  assert_success
  assert_output --partial "--force"
}

# --- _help_list ---

@test "_help_list outputs description for list command" {
  run _help_list
  assert_success
  assert_output --partial "List"
}

@test "_help_list outputs usage" {
  run _help_list
  assert_success
  assert_output --partial "wt -l"
}

@test "_help_list outputs examples" {
  run _help_list
  assert_success
  assert_output --partial "wt -l"
}

# --- _help_clear ---

@test "_help_clear outputs description for clear command" {
  run _help_clear
  assert_success
  assert_output --partial "Remove"
}

@test "_help_clear outputs usage with placeholders" {
  run _help_clear
  assert_success
  assert_output --partial "wt -c"
  assert_output --partial "<days>"
}

@test "_help_clear outputs examples" {
  run _help_clear
  assert_success
  assert_output --partial "wt -c 30"
}

@test "_help_clear outputs --merged option" {
  run _help_clear
  assert_success
  assert_output --partial "--merged"
}

@test "_help_clear outputs --pattern option with placeholder" {
  run _help_clear
  assert_success
  assert_output --partial "--pattern"
  assert_output --partial "<pattern>"
}

# --- _help_init ---

@test "_help_init outputs description for init command" {
  run _help_init
  assert_success
  assert_output --partial "Initialize"
}

@test "_help_init outputs usage" {
  run _help_init
  assert_success
  assert_output --partial "wt --init"
}

@test "_help_init outputs examples" {
  run _help_init
  assert_success
  assert_output --partial "wt --init"
}

# --- _help_update ---

@test "_help_update outputs description for update command" {
  run _help_update
  assert_success
  assert_output --partial "Update"
}

@test "_help_update outputs usage" {
  run _help_update
  assert_success
  assert_output --partial "wt --update"
}

@test "_help_update outputs examples" {
  run _help_update
  assert_success
  assert_output --partial "wt --update"
}

@test "_help_update outputs --check option" {
  run _help_update
  assert_success
  assert_output --partial "--check"
}

# --- Router tests: wt <cmd> --help ---

@test "wt -n --help shows new command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -n --help
  assert_success
  assert_output --partial "Create a new worktree"
  assert_output --partial "<branch>"
  assert_output --partial "wt -n feature-login"
  # No worktree created (no side effects)
  refute_output --partial "Creating worktree"
}

@test "wt --new --help shows new command help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --new --help
  assert_success
  assert_output --partial "Create a new worktree"
  assert_output --partial "<branch>"
}

@test "wt -s --help shows switch command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -s --help
  assert_success
  assert_output --partial "Switch"
  assert_output --partial "<worktree>"
  refute_output --partial "switch>"
}

@test "wt --switch --help shows switch command help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --switch --help
  assert_success
  assert_output --partial "Switch"
}

@test "wt -o --help shows open command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -o --help
  assert_success
  assert_output --partial "Open"
  assert_output --partial "<branch>"
  refute_output --partial "open>"
}

@test "wt --open --help shows open command help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --open --help
  assert_success
  assert_output --partial "Open"
}

@test "wt -r --help shows remove command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -r --help
  assert_success
  assert_output --partial "Remove"
  assert_output --partial "<worktree>"
  refute_output --partial "remove>"
}

@test "wt --remove --help shows remove command help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --remove --help
  assert_success
  assert_output --partial "Remove"
}

@test "wt -l --help shows list command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -l --help
  assert_success
  assert_output --partial "List"
  assert_output --partial "wt -l"
}

@test "wt --list --help shows list command help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --list --help
  assert_success
  assert_output --partial "List"
}

@test "wt -c --help shows clear command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -c --help
  assert_success
  assert_output --partial "<days>"
  assert_output --partial "--merged"
  refute_output --partial "Usage: wt -c <days>"
}

@test "wt --clear --help shows clear command help (long form)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --clear --help
  assert_success
  assert_output --partial "<days>"
}

@test "wt --init --help shows init command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  load_wt_full

  run wt --init --help
  assert_success
  assert_output --partial "Initialize"
  assert_output --partial "wt --init"
  # Should not prompt for input
  refute_output --partial "Project ["
}

@test "wt --update --help shows update command help without executing" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  load_wt_full

  run wt --update --help
  assert_success
  assert_output --partial "Update"
  assert_output --partial "--check"
  # Should not attempt to update
  refute_output --partial "Updating"
}

# --- Edge cases ---

@test "wt --help alone shows full help (existing behaviour preserved)" {
  load_wt_full

  run wt --help
  assert_success
  assert_output --partial "wt - Git Worktree Helpers"
  assert_output --partial "Usage:"
  assert_output --partial "--new"
}

@test "wt --help -n shows new command help (reversed flag order)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt --help -n
  assert_success
  assert_output --partial "Create a new worktree"
  refute_output --partial "Creating worktree"
}

@test "wt -n --help extra-arg shows help and does not create worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt_full

  run wt -n --help extra-arg
  assert_success
  assert_output --partial "Create a new worktree"
  refute_output --partial "Creating worktree"
}
