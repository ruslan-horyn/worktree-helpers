#!/usr/bin/env bats
# Tests for _cmd_uninstall, uninstall.sh, and wt --uninstall flag

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# --- uninstall.sh direct tests ---

@test "uninstall.sh --help shows usage" {
  run bash "$PROJECT_ROOT/uninstall.sh" --help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--force"
}

@test "uninstall.sh exits cleanly when nothing is installed" {
  # Point HOME to temp dir so no rc file has the marker
  HOME="$TEST_TEMP_DIR"
  # Ensure install dir doesn't exist
  rm -rf "$HOME/.worktree-helpers"

  run bash "$PROJECT_ROOT/uninstall.sh"
  assert_success
  assert_output --partial "not installed"
}

@test "uninstall.sh removes install directory" {
  HOME="$TEST_TEMP_DIR"
  local install_dir="$HOME/.worktree-helpers"
  mkdir -p "$install_dir"
  echo "dummy" > "$install_dir/wt.sh"

  # No rc file marker, so only install dir removal
  run bash "$PROJECT_ROOT/uninstall.sh" --force
  assert_success
  assert_output --partial "Removed"
  [ ! -d "$install_dir" ]
}

@test "uninstall.sh removes source lines from zshrc" {
  HOME="$TEST_TEMP_DIR"
  SHELL="/bin/zsh"
  export SHELL
  local rc="$HOME/.zshrc"

  # Create rc file with worktree-helpers source lines
  cat > "$rc" <<'EOF'
# some other config
alias ll='ls -la'

# worktree-helpers
source "$HOME/.worktree-helpers/wt.sh"

# more config
export PATH="/usr/local/bin:$PATH"
EOF

  # Create install dir so it's found
  mkdir -p "$HOME/.worktree-helpers"
  echo "dummy" > "$HOME/.worktree-helpers/wt.sh"

  run bash "$PROJECT_ROOT/uninstall.sh" --force
  assert_success
  assert_output --partial "Removed source lines"

  # Verify marker and source line are gone
  run grep -F "# worktree-helpers" "$rc"
  assert_failure

  run grep -F "worktree-helpers/wt.sh" "$rc"
  assert_failure

  # Verify other config is preserved
  run grep -F "alias ll" "$rc"
  assert_success

  run grep -F "export PATH" "$rc"
  assert_success
}

@test "uninstall.sh removes source lines from bashrc" {
  HOME="$TEST_TEMP_DIR"
  SHELL="/bin/bash"
  export SHELL
  local rc="$HOME/.bashrc"

  cat > "$rc" <<'EOF'
# bash config
alias ll='ls -la'

# worktree-helpers
source "$HOME/.worktree-helpers/wt.sh"

export EDITOR=vim
EOF

  mkdir -p "$HOME/.worktree-helpers"
  echo "dummy" > "$HOME/.worktree-helpers/wt.sh"

  run bash "$PROJECT_ROOT/uninstall.sh" --force
  assert_success
  assert_output --partial "Removed source lines"

  run grep -F "# worktree-helpers" "$rc"
  assert_failure

  run grep -F "worktree-helpers/wt.sh" "$rc"
  assert_failure

  run grep -F "EDITOR=vim" "$rc"
  assert_success
}

@test "uninstall.sh falls back to bash_profile when bashrc missing" {
  HOME="$TEST_TEMP_DIR"
  SHELL="/bin/bash"
  export SHELL
  local rc="$HOME/.bash_profile"

  # No .bashrc, only .bash_profile
  cat > "$rc" <<'EOF'
# profile
# worktree-helpers
source "$HOME/.worktree-helpers/wt.sh"
EOF

  mkdir -p "$HOME/.worktree-helpers"
  echo "dummy" > "$HOME/.worktree-helpers/wt.sh"

  run bash "$PROJECT_ROOT/uninstall.sh" --force
  assert_success
  assert_output --partial "Removed source lines"

  run grep -F "# worktree-helpers" "$rc"
  assert_failure
}

@test "uninstall.sh rejects unknown options" {
  run bash "$PROJECT_ROOT/uninstall.sh" --bogus
  assert_failure
  assert_output --partial "Unknown option"
}

# --- _cmd_uninstall tests ---

@test "_cmd_uninstall errors when uninstall.sh not found" {
  _WT_DIR="$TEST_TEMP_DIR/nonexistent"

  run _cmd_uninstall 0
  assert_failure
  assert_output --partial "uninstall.sh not found"
}

@test "_cmd_uninstall passes --force flag" {
  # Create a mock uninstall.sh that just prints its args
  mkdir -p "$TEST_TEMP_DIR/wt_install"
  cat > "$TEST_TEMP_DIR/wt_install/uninstall.sh" <<'SH'
#!/usr/bin/env bash
echo "args: $*"
SH
  chmod +x "$TEST_TEMP_DIR/wt_install/uninstall.sh"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  run _cmd_uninstall 1
  assert_success
  assert_output --partial "args: --force"
}

@test "_cmd_uninstall runs without --force by default" {
  mkdir -p "$TEST_TEMP_DIR/wt_install"
  cat > "$TEST_TEMP_DIR/wt_install/uninstall.sh" <<'SH'
#!/usr/bin/env bash
echo "args: $*"
SH
  chmod +x "$TEST_TEMP_DIR/wt_install/uninstall.sh"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  run _cmd_uninstall 0
  assert_success
  assert_output --partial "args:"
  refute_output --partial "--force"
}

# --- wt --uninstall router tests ---

@test "wt --uninstall is recognized by router" {
  load_wt_full

  # Use a mock uninstall.sh to avoid actually uninstalling
  mkdir -p "$TEST_TEMP_DIR/wt_install"
  cat > "$TEST_TEMP_DIR/wt_install/uninstall.sh" <<'SH'
#!/usr/bin/env bash
echo "uninstall called"
SH
  chmod +x "$TEST_TEMP_DIR/wt_install/uninstall.sh"
  _WT_DIR="$TEST_TEMP_DIR/wt_install"

  run wt --uninstall
  assert_success
  assert_output --partial "uninstall called"
}

@test "_cmd_help includes --uninstall" {
  run _cmd_help
  assert_success
  assert_output --partial "--uninstall"
}
