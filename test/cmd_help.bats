#!/usr/bin/env bats
# Tests for _cmd_help in lib/commands.sh

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
}
