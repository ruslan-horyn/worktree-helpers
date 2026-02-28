#!/usr/bin/env bats
# Tests for self-update mechanism (lib/update.sh, _cmd_update)

setup() {
  load 'test_helper'
  setup
  load_wt

  # Set up a fake _WT_DIR with VERSION file
  mkdir -p "$TEST_TEMP_DIR/wt_install/lib"
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  # Override cache file to use temp dir
  _WT_UPDATE_CACHE="$TEST_TEMP_DIR/.wt_update_check"
}

teardown() {
  teardown
}

# --- _version_lt tests ---

@test "_version_lt: 1.0.0 < 1.0.1 is true" {
  run _version_lt "1.0.0" "1.0.1"
  assert_success
}

@test "_version_lt: 1.0.0 < 1.1.0 is true" {
  run _version_lt "1.0.0" "1.1.0"
  assert_success
}

@test "_version_lt: 1.0.0 < 2.0.0 is true" {
  run _version_lt "1.0.0" "2.0.0"
  assert_success
}

@test "_version_lt: 1.9.0 < 1.10.0 is true (numeric comparison)" {
  run _version_lt "1.9.0" "1.10.0"
  assert_success
}

@test "_version_lt: 0.9.9 < 1.0.0 is true" {
  run _version_lt "0.9.9" "1.0.0"
  assert_success
}

@test "_version_lt: 1.1.0 < 1.1.0 is false (equal)" {
  run _version_lt "1.1.0" "1.1.0"
  assert_failure
}

@test "_version_lt: 1.2.0 < 1.1.0 is false (greater)" {
  run _version_lt "1.2.0" "1.1.0"
  assert_failure
}

@test "_version_lt: 2.0.0 < 1.9.9 is false" {
  run _version_lt "2.0.0" "1.9.9"
  assert_failure
}

@test "_version_lt: 1.10.0 < 1.9.0 is false (numeric comparison)" {
  run _version_lt "1.10.0" "1.9.0"
  assert_failure
}

@test "_version_lt: 1.0.0 < 1.0.0 is false (same)" {
  run _version_lt "1.0.0" "1.0.0"
  assert_failure
}

@test "_version_lt: handles two-segment versions (1.0 < 1.1)" {
  run _version_lt "1.0" "1.1"
  assert_success
}

@test "_version_lt: handles single-segment versions (1 < 2)" {
  run _version_lt "1" "2"
  assert_success
}

# --- _update_cache_write and _update_cache_fresh tests ---

@test "_update_cache_write creates cache file" {
  _update_cache_write "2.0.0"

  [ -f "$_WT_UPDATE_CACHE" ]
  local line2
  line2=$(sed -n '2p' "$_WT_UPDATE_CACHE")
  [ "$line2" = "2.0.0" ]
}

@test "_update_cache_write stores timestamp on first line" {
  local before
  before=$(date +%s)
  _update_cache_write "2.0.0"

  local ts
  ts=$(head -1 "$_WT_UPDATE_CACHE")
  # Timestamp should be >= before
  [ "$ts" -ge "$before" ]
}

@test "_update_cache_fresh returns false when no cache file" {
  rm -f "$_WT_UPDATE_CACHE"
  run _update_cache_fresh
  assert_failure
}

@test "_update_cache_fresh returns true for fresh cache" {
  _update_cache_write "2.0.0"
  run _update_cache_fresh
  assert_success
}

@test "_update_cache_fresh returns false for stale cache (>24h)" {
  # Write a cache file with an old timestamp (48 hours ago)
  local old_ts
  old_ts=$(($(date +%s) - 172800))
  printf '%s\n%s\n' "$old_ts" "2.0.0" > "$_WT_UPDATE_CACHE"

  run _update_cache_fresh
  assert_failure
}

@test "_update_cache_fresh returns false for empty cache file" {
  : > "$_WT_UPDATE_CACHE"
  run _update_cache_fresh
  assert_failure
}

# --- _update_notify tests ---

@test "_update_notify shows nothing when no cache file" {
  rm -f "$_WT_UPDATE_CACHE"
  run _update_notify
  assert_success
  assert_output ""
}

@test "_update_notify shows notification when update available" {
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _update_cache_write "1.2.0"

  run _update_notify
  assert_success
  assert_output --partial "Update available: 1.1.0 -> 1.2.0"
  assert_output --partial "wt --update"
}

@test "_update_notify shows nothing when up to date" {
  echo "1.2.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _update_cache_write "1.2.0"

  run _update_notify
  assert_success
  assert_output ""
}

@test "_update_notify shows nothing when installed is newer" {
  echo "1.3.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _update_cache_write "1.2.0"

  run _update_notify
  assert_success
  assert_output ""
}

@test "_update_notify shows nothing when VERSION file missing" {
  rm -f "$TEST_TEMP_DIR/wt_install/VERSION"
  _update_cache_write "1.2.0"

  run _update_notify
  assert_success
  assert_output ""
}

@test "_update_notify shows nothing when cache has empty version" {
  local now
  now=$(date +%s)
  printf '%s\n\n' "$now" > "$_WT_UPDATE_CACHE"

  run _update_notify
  assert_success
  assert_output ""
}

# --- _cmd_update dispatching tests ---

@test "_cmd_update with check_only=1 calls _update_check_only" {
  # Mock _update_check_only
  _update_check_only() { echo "check_only_called"; }
  _update_install() { echo "install_called"; }

  run _cmd_update 1
  assert_success
  assert_output "check_only_called"
}

@test "_cmd_update with check_only=0 calls _update_install" {
  # Mock _update_install
  _update_check_only() { echo "check_only_called"; }
  _update_install() { echo "install_called"; }

  run _cmd_update 0
  assert_success
  assert_output "install_called"
}

# --- _update_install tests (with mocked _fetch_latest) ---

@test "_update_install shows already up to date when versions match" {
  echo "1.2.0" > "$TEST_TEMP_DIR/wt_install/VERSION"

  # Mock _fetch_latest to return 1.2.0
  _fetch_latest() { printf '1.2.0\nsome changelog'; }

  run _update_install
  assert_success
  assert_output --partial "already at the latest version (1.2.0)"
}

@test "_update_install shows error on network failure" {
  # Mock _fetch_latest to fail
  _fetch_latest() { return 1; }

  run _update_install
  assert_failure
  assert_output --partial "network error"
}

@test "_update_install detects available update" {
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"

  # Mock _fetch_latest to return newer version
  _fetch_latest() { printf '1.2.0\n- feat: new feature\n- fix: bug fix'; }

  # Mock git clone to simulate successful download
  git() {
    if [ "$1" = "clone" ]; then
      local target_dir="${*: -1}"
      mkdir -p "$target_dir/lib"
      echo "1.2.0" > "$target_dir/VERSION"
      echo "# updated wt.sh" > "$target_dir/wt.sh"
      echo "# updated lib" > "$target_dir/lib/utils.sh"
      return 0
    fi
    command git "$@"
  }

  run _update_install
  assert_success
  assert_output --partial "Update available: 1.1.0 -> 1.2.0"
  assert_output --partial "Changes:"
  assert_output --partial "feat: new feature"
  assert_output --partial "Backed up current installation"
  assert_output --partial "Updated wt to 1.2.0"
}

@test "_update_install shows re-source prompt after successful update" {
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  _fetch_latest() { printf '1.2.0\n- feat: new feature'; }

  git() {
    if [ "$1" = "clone" ]; then
      local target_dir="${*: -1}"
      mkdir -p "$target_dir/lib"
      echo "1.2.0" > "$target_dir/VERSION"
      echo "# updated wt.sh" > "$target_dir/wt.sh"
      echo "# updated lib" > "$target_dir/lib/utils.sh"
      return 0
    fi
    command git "$@"
  }

  run _update_install
  assert_success
  assert_output --partial "source $TEST_TEMP_DIR/wt_install/wt.sh"
  assert_output --partial "Or open a new terminal"
}

@test "_update_install does not show re-source prompt when already up to date" {
  echo "1.2.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _fetch_latest() { printf '1.2.0\nsome changelog'; }

  run _update_install
  assert_success
  refute_output --partial "source"
  refute_output --partial "Or open a new terminal"
}

@test "_update_install creates backup before updating" {
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  echo "original" > "$TEST_TEMP_DIR/wt_install/wt.sh"

  _fetch_latest() { printf '1.2.0\nchanges'; }

  git() {
    if [ "$1" = "clone" ]; then
      local target_dir="${*: -1}"
      mkdir -p "$target_dir/lib"
      echo "1.2.0" > "$target_dir/VERSION"
      echo "# updated" > "$target_dir/wt.sh"
      echo "# lib" > "$target_dir/lib/utils.sh"
      return 0
    fi
    command git "$@"
  }

  run _update_install
  assert_success

  # Verify backup was created
  [ -d "$TEST_TEMP_DIR/wt_install.bak" ]
  # Backup should contain original VERSION
  local backup_ver
  backup_ver=$(cat "$TEST_TEMP_DIR/wt_install.bak/VERSION")
  [ "$backup_ver" = "1.1.0" ]
}

@test "_update_install handles unknown installed version" {
  rm -f "$TEST_TEMP_DIR/wt_install/VERSION"

  _fetch_latest() { printf '1.2.0\nchanges'; }

  git() {
    if [ "$1" = "clone" ]; then
      local target_dir="${*: -1}"
      mkdir -p "$target_dir/lib"
      echo "1.2.0" > "$target_dir/VERSION"
      echo "# updated" > "$target_dir/wt.sh"
      echo "# lib" > "$target_dir/lib/utils.sh"
      return 0
    fi
    command git "$@"
  }

  run _update_install
  assert_success
  assert_output --partial "Update available: unknown -> 1.2.0"
  assert_output --partial "Updated wt to 1.2.0"
}

# --- _update_check_only tests (with mocked _fetch_latest) ---

@test "_update_check_only shows up to date" {
  echo "1.2.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _fetch_latest() { printf '1.2.0\n'; }

  run _update_check_only
  assert_success
  assert_output --partial "wt is up to date (1.2.0)"
}

@test "_update_check_only shows update available" {
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _fetch_latest() { printf '1.2.0\n'; }

  run _update_check_only
  assert_success
  assert_output --partial "Update available: 1.1.0 -> 1.2.0"
  assert_output --partial "wt --update"
}

@test "_update_check_only shows error on network failure" {
  _fetch_latest() { return 1; }

  run _update_check_only
  assert_failure
  assert_output --partial "network error"
}

@test "_update_check_only updates cache" {
  echo "1.1.0" > "$TEST_TEMP_DIR/wt_install/VERSION"
  _fetch_latest() { printf '1.2.0\n'; }

  run _update_check_only
  assert_success

  # Cache should have been written
  [ -f "$_WT_UPDATE_CACHE" ]
  local cached_ver
  cached_ver=$(sed -n '2p' "$_WT_UPDATE_CACHE")
  [ "$cached_ver" = "1.2.0" ]
}

# --- _cmd_help includes --update ---

@test "_cmd_help includes --update flag" {
  run _cmd_help
  assert_success
  assert_output --partial "--update"
}

@test "_cmd_help includes --check flag for update" {
  run _cmd_help
  assert_success
  assert_output --partial "--update --check"
}

# --- Router integration tests ---

@test "wt --update routes to _cmd_update" {
  load_wt_full

  # Mock update functions to avoid real network calls
  _update_install() { echo "update_install_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --update
  assert_success
  assert_output "update_install_called"
}

@test "wt --update --check routes to check-only mode" {
  load_wt_full

  # Mock update functions
  _update_check_only() { echo "check_only_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --update --check
  assert_success
  assert_output "check_only_called"
}

@test "wt --check alone routes to check-only mode" {
  load_wt_full

  _update_check_only() { echo "check_only_called"; }
  _update_notify() { :; }
  _bg_update_check() { :; }

  run wt --check
  assert_success
  assert_output "check_only_called"
}
