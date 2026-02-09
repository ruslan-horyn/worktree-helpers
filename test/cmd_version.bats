#!/usr/bin/env bats
# Tests for _cmd_version and -v/--version flag

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

@test "_cmd_version prints version from VERSION file" {
  # Create a fake _WT_DIR with a VERSION file
  mkdir -p "$TEST_TEMP_DIR/wt_install"
  echo "1.2.3" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  run _cmd_version
  assert_success
  assert_output "wt version 1.2.3"
}

@test "_cmd_version prints unknown when VERSION file is missing" {
  _WT_DIR="$TEST_TEMP_DIR/nonexistent"

  run _cmd_version
  assert_success
  assert_output "wt version unknown"
}

@test "_cmd_version prints unknown when VERSION file is empty" {
  mkdir -p "$TEST_TEMP_DIR/wt_install"
  : > "$TEST_TEMP_DIR/wt_install/VERSION"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  run _cmd_version
  assert_success
  assert_output "wt version unknown"
}

@test "_cmd_version trims whitespace and reads only first line" {
  mkdir -p "$TEST_TEMP_DIR/wt_install"
  printf '  2.0.0  \nsecond line\n' > "$TEST_TEMP_DIR/wt_install/VERSION"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  run _cmd_version
  assert_success
  assert_output "wt version 2.0.0"
}

@test "_cmd_version reads from real project VERSION file" {
  _WT_DIR="$PROJECT_ROOT"

  run _cmd_version
  assert_success
  assert_output --partial "wt version"
  # Should not say unknown since VERSION file exists at project root
  refute_output --partial "unknown"
}

@test "wt -v prints version" {
  load_wt_full

  run wt -v
  assert_success
  assert_output --partial "wt version"
  refute_output --partial "unknown"
}

@test "wt --version prints version" {
  load_wt_full

  run wt --version
  assert_success
  assert_output --partial "wt version"
  refute_output --partial "unknown"
}

@test "wt -v and wt --version produce same output" {
  load_wt_full

  run wt -v
  local v_output="$output"

  run wt --version
  assert_output "$v_output"
}

@test "_cmd_help includes --version flag" {
  run _cmd_help
  assert_success
  assert_output --partial "--version"
}
