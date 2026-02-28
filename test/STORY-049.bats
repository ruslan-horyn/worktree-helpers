#!/usr/bin/env bats
# STORY-049: Install wt as executable binary for non-interactive shell support
#
# Tests cover all 13 AC items:
#   AC-1   - wt.sh executable invocation works (bash wt.sh -v)
#   AC-2   - install.sh creates ~/.local/bin/wt symlink and sets chmod +x
#   AC-3   - symlink binary is invocable directly
#   AC-4   - install.sh warns when ~/.local/bin is absent from PATH
#   AC-5   - install.sh does NOT warn when ~/.local/bin is already in PATH
#   AC-6   - uninstall.sh removes the symlink
#   AC-7   - uninstall.sh is a no-op when symlink is absent
#   AC-8   - sourcing wt.sh does NOT invoke wt "$@" (no regression)
#   AC-9   - _cmd_remove errors when $PWD equals worktree path
#   AC-10  - _cmd_remove errors when $PWD is inside a worktree subdirectory
#   AC-11  - _cmd_clear skips with error when $PWD equals worktree path, continues others
#   AC-12  - _cmd_clear skips with error when $PWD is inside a worktree subdirectory
#   AC-13  - _cmd_remove outside worktree succeeds normally (no regression)
#
# All tests MUST FAIL before STORY-049 is implemented (except where noted).

setup() {
  load 'test_helper'
  setup
  # Note: load_wt is NOT called here globally because many tests run wt.sh
  # inside subprocesses.  Tests that call _cmd_* directly call setup_test_repo
  # (which calls load_wt) or source libs inline in their subprocess.
}

teardown() {
  teardown
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Run install.sh --local with a fake HOME pointing to a temp dir,
# so we never touch the real user home.  Returns the fake HOME.
_run_install_local() {
  local fake_home="$1"
  local path_value="${2:-}"

  bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${path_value}'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
}

# Run uninstall.sh --force with a fake HOME.
_run_uninstall_force() {
  local fake_home="$1"
  bash -c "
    HOME='${fake_home}'
    export HOME
    bash '${PROJECT_ROOT}/uninstall.sh' --force 2>&1
  "
}

# ---------------------------------------------------------------------------
# AC-1 — wt.sh direct executable invocation
# ---------------------------------------------------------------------------

@test "AC-1: bash wt.sh -v exits 0 and prints non-empty version output" {
  # WT_INSTALL_DIR lets wt.sh find its lib files when run directly.
  # Without dual-mode detection, wt() is defined but never called, so output
  # would be empty.  After the fix, output must contain the version string.
  run bash -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    bash '${PROJECT_ROOT}/wt.sh' -v 2>&1
  "
  assert_success
  # Output must be non-empty (version string printed by _cmd_version)
  [ -n "$output" ]
  refute_output --partial "command not found"
}

@test "AC-1: bash wt.sh -v output contains a version number" {
  run bash -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    bash '${PROJECT_ROOT}/wt.sh' -v 2>&1
  "
  assert_success
  # Version output must match a semantic version pattern (e.g. "1.4.0")
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "AC-1: bash wt.sh -h exits 0 and shows help content" {
  run bash -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    bash '${PROJECT_ROOT}/wt.sh' -h 2>&1
  "
  assert_success
  # Help output must contain usage content
  assert_output --partial "wt"
  [ -n "$output" ]
  refute_output --partial "command not found"
}

# ---------------------------------------------------------------------------
# AC-2 — install.sh creates ~/.local/bin/wt symlink and sets executable bit
# ---------------------------------------------------------------------------

@test "AC-2: install.sh --local creates ~/.local/bin/wt symlink" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  # Provide a PATH that contains ~/.local/bin so no warning clutters output
  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success

  local symlink="${fake_home}/.local/bin/wt"
  assert [ -L "$symlink" ]

  rm -rf "$fake_home"
}

@test "AC-2: ~/.local/bin/wt symlink points to wt.sh in install dir" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success

  local symlink="${fake_home}/.local/bin/wt"
  local target
  target=$(readlink "$symlink")
  # Target must end with wt.sh
  [[ "$target" == *"/wt.sh" ]]

  rm -rf "$fake_home"
}

@test "AC-2: wt.sh has executable bit set after install.sh --local" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success

  # The actual wt.sh inside the install dir must be executable
  local install_dir="${fake_home}/.worktree-helpers"
  assert [ -x "${install_dir}/wt.sh" ]

  rm -rf "$fake_home"
}

@test "AC-2: install.sh --local is idempotent (re-run recreates symlink without error)" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  # First install
  bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local >/dev/null 2>&1
  "

  # Second install (symlink already exists — should be removed and recreated)
  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success

  local symlink="${fake_home}/.local/bin/wt"
  assert [ -L "$symlink" ]

  rm -rf "$fake_home"
}

# ---------------------------------------------------------------------------
# AC-3 — Symlink binary is directly invocable
# ---------------------------------------------------------------------------

@test "AC-3: invoking the ~/.local/bin/wt symlink with -v exits 0" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  # Install first
  bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local >/dev/null 2>&1
  "

  local symlink="${fake_home}/.local/bin/wt"

  run bash -c "
    WT_INSTALL_DIR='${fake_home}/.worktree-helpers'
    export WT_INSTALL_DIR
    '${symlink}' -v
  "
  assert_success
  refute_output --partial "command not found"

  rm -rf "$fake_home"
}

@test "AC-3: invoking the symlink with -h shows help text" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local >/dev/null 2>&1
  "

  local symlink="${fake_home}/.local/bin/wt"

  run bash -c "
    WT_INSTALL_DIR='${fake_home}/.worktree-helpers'
    export WT_INSTALL_DIR
    '${symlink}' -h
  "
  assert_success
  # Help output should contain usage-related content
  assert_output --partial "wt"

  rm -rf "$fake_home"
}

# ---------------------------------------------------------------------------
# AC-4 — install.sh warns when ~/.local/bin is absent from PATH
# ---------------------------------------------------------------------------

@test "AC-4: install.sh warns when ~/.local/bin is not in PATH" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  # PATH explicitly without ~/.local/bin
  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success
  # Warning must mention the PATH issue
  assert_output --partial "~/.local/bin"
  assert_output --partial "PATH"

  rm -rf "$fake_home"
}

@test "AC-4: install.sh warning includes export PATH instruction" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success
  assert_output --partial "export PATH"

  rm -rf "$fake_home"
}

# ---------------------------------------------------------------------------
# AC-5 — install.sh does NOT warn when ~/.local/bin is already in PATH
# ---------------------------------------------------------------------------

@test "AC-5: install.sh does not print PATH warning when ~/.local/bin is in PATH" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"
  local local_bin="${fake_home}/.local/bin"
  mkdir -p "$local_bin"

  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${local_bin}:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success
  # Must NOT print the PATH warning
  refute_output --partial "is not in your PATH"

  rm -rf "$fake_home"
}

# ---------------------------------------------------------------------------
# AC-6 — uninstall.sh removes the symlink
# ---------------------------------------------------------------------------

@test "AC-6: uninstall.sh --force removes ~/.local/bin/wt symlink" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  # Install first (sets up the symlink)
  bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local >/dev/null 2>&1
  "

  local symlink="${fake_home}/.local/bin/wt"
  assert [ -L "$symlink" ]  # Verify setup worked

  # Now uninstall
  run bash -c "
    HOME='${fake_home}'
    export HOME
    bash '${PROJECT_ROOT}/uninstall.sh' --force 2>&1
  "
  assert_success

  # Symlink must be gone
  assert [ ! -e "$symlink" ]
  assert [ ! -L "$symlink" ]

  rm -rf "$fake_home"
}

@test "AC-6: uninstall.sh prints confirmation message about removed symlink" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='${fake_home}/.local/bin:/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local >/dev/null 2>&1
  "

  run bash -c "
    HOME='${fake_home}'
    export HOME
    bash '${PROJECT_ROOT}/uninstall.sh' --force 2>&1
  "
  assert_success
  # Output must mention symlink removal
  assert_output --partial "wt"

  rm -rf "$fake_home"
}

# ---------------------------------------------------------------------------
# AC-7 — uninstall.sh is a no-op when symlink is absent
# ---------------------------------------------------------------------------

@test "AC-7: uninstall.sh --force exits 0 when ~/.local/bin/wt does not exist" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  # No install — symlink never created
  run bash -c "
    HOME='${fake_home}'
    export HOME
    bash '${PROJECT_ROOT}/uninstall.sh' --force 2>&1
  "
  assert_success

  rm -rf "$fake_home"
}

@test "AC-7: uninstall.sh --force does not error when symlink absent" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  run bash -c "
    HOME='${fake_home}'
    export HOME
    bash '${PROJECT_ROOT}/uninstall.sh' --force 2>&1
  "
  # Must not contain error text about the symlink
  refute_output --partial "No such file"

  rm -rf "$fake_home"
}

# ---------------------------------------------------------------------------
# AC-8 — Sourcing wt.sh does NOT invoke wt "$@" (no regression)
# ---------------------------------------------------------------------------

@test "AC-8: sourcing wt.sh in bash defines wt() without calling it" {
  # If wt() were called during source, it would try to parse "" as an action
  # and either print help or error.  We verify that sourcing produces no
  # side-effects (no unexpected output, no exit failure).
  run bash -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    source '${PROJECT_ROOT}/wt.sh'
    # After sourcing, wt() must be defined
    type wt >/dev/null 2>&1 && echo 'wt_defined'
  "
  assert_success
  assert_output "wt_defined"
}

@test "AC-8: sourcing wt.sh in bash produces no spurious output from wt router" {
  # This is a regression guard: even BEFORE the dual-mode fix, sourcing must
  # not produce output.  The fix must not break this behaviour.
  # Capture stdout+stderr of sourcing. Only our sentinel echo should appear.
  run bash --norc --noprofile -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    source '${PROJECT_ROOT}/wt.sh' 2>/dev/null
    echo 'source_done'
  "
  assert_success
  # The ONLY output line after sourcing must be our own sentinel
  assert_output "source_done"
}

@test "AC-8: sourcing wt.sh and then calling wt -v works (function is available)" {
  run bash -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    source '${PROJECT_ROOT}/wt.sh'
    wt -v
  "
  assert_success
  refute_output --partial "command not found"
}

# ---------------------------------------------------------------------------
# AC-9 — _cmd_remove errors when $PWD equals the worktree path
# ---------------------------------------------------------------------------

@test "AC-9: _cmd_remove prints error when inside the target worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/rm-inside"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-inside "$wt_path" HEAD >/dev/null 2>&1

  # Run _cmd_remove from INSIDE the worktree
  run bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_path}'
    _cmd_remove 'rm-inside' 1 2>&1
  "
  assert_failure
  assert_output --partial "Cannot remove"
  assert_output --partial "cd out"
}

@test "AC-9: _cmd_remove exits non-zero when inside the target worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/rm-inside-exit"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-inside-exit "$wt_path" HEAD >/dev/null 2>&1

  run bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_path}'
    _cmd_remove 'rm-inside-exit' 1 2>&1
  "
  assert_failure
}

@test "AC-9: _cmd_remove does NOT remove the worktree when called from inside it" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/rm-no-delete"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-no-delete "$wt_path" HEAD >/dev/null 2>&1

  bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_path}'
    _cmd_remove 'rm-no-delete' 1 >/dev/null 2>&1
  " || true

  # The worktree directory must still exist
  assert [ -d "$wt_path" ]
}

# ---------------------------------------------------------------------------
# AC-10 — _cmd_remove errors when $PWD is inside a worktree subdirectory
# ---------------------------------------------------------------------------

@test "AC-10: _cmd_remove errors when PWD is a subdirectory of the target worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/rm-subdir"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-subdir "$wt_path" HEAD >/dev/null 2>&1

  # Create a subdirectory inside the worktree
  mkdir -p "${wt_path}/src/deep"

  run bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_path}/src/deep'
    _cmd_remove 'rm-subdir' 1 2>&1
  "
  assert_failure
  assert_output --partial "Cannot remove"
}

@test "AC-10: _cmd_remove does not remove worktree when called from subdirectory" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/rm-subdir-keep"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-subdir-keep "$wt_path" HEAD >/dev/null 2>&1

  mkdir -p "${wt_path}/subdir"

  bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_path}/subdir'
    _cmd_remove 'rm-subdir-keep' 1 >/dev/null 2>&1
  " || true

  assert [ -d "$wt_path" ]
}

# ---------------------------------------------------------------------------
# AC-11 — _cmd_clear skips with error when $PWD equals worktree path, continues others
# ---------------------------------------------------------------------------

@test "AC-11: _cmd_clear prints 'Cannot clear' when inside a worktree being cleared" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Source libs to access GWT_WORKTREES_DIR
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_inside
  wt_inside="$GWT_WORKTREES_DIR/clear-inside"
  git worktree add -b clear-inside "$wt_inside" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_inside/.git"

  run bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_inside}'
    _cmd_clear '1' '1' '0' '0' 2>&1
  "
  # Must exit 0 (continues despite skip)
  assert_success
  assert_output --partial "Cannot clear"
}

@test "AC-11: _cmd_clear does NOT remove worktree when PWD is inside it" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_inside
  wt_inside="$GWT_WORKTREES_DIR/clear-no-delete"
  git worktree add -b clear-no-delete "$wt_inside" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_inside/.git"

  bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_inside}'
    _cmd_clear '1' '1' '0' '0' >/dev/null 2>&1
  "

  # Worktree must still exist because we were inside it
  assert [ -d "$wt_inside" ]
}

@test "AC-11: _cmd_clear continues removing other worktrees when one is skipped due to PWD" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  # The worktree we will be "inside"
  local wt_inside
  wt_inside="$GWT_WORKTREES_DIR/clear-skip-me"
  git worktree add -b clear-skip-me "$wt_inside" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_inside/.git"

  # Another old worktree that SHOULD be removed
  local wt_other
  wt_other="$GWT_WORKTREES_DIR/clear-remove-me"
  git worktree add -b clear-remove-me "$wt_other" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_other/.git"

  bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_inside}'
    _cmd_clear '1' '1' '0' '0' >/dev/null 2>&1
  "

  # wt_inside must still exist (we were inside it)
  assert [ -d "$wt_inside" ]
  # wt_other must have been removed (was not protected by PWD)
  assert [ ! -d "$wt_other" ]
}

@test "AC-11: _cmd_clear skip message includes the worktree name" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_inside
  wt_inside="$GWT_WORKTREES_DIR/clear-name-check"
  git worktree add -b clear-name-check "$wt_inside" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_inside/.git"

  run bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_inside}'
    _cmd_clear '1' '1' '0' '0' 2>&1
  "
  assert_success
  assert_output --partial "clear-name-check"
}

# ---------------------------------------------------------------------------
# AC-12 — _cmd_clear skips when $PWD is inside a subdirectory of the worktree
# ---------------------------------------------------------------------------

@test "AC-12: _cmd_clear prints 'Cannot clear' when inside a subdirectory of a worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/clear-subdir-test"
  git worktree add -b clear-subdir-test "$wt_path" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_path/.git"

  mkdir -p "${wt_path}/lib/nested"

  run bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_path}/lib/nested'
    _cmd_clear '1' '1' '0' '0' 2>&1
  "
  assert_success
  assert_output --partial "Cannot clear"
}

@test "AC-12: _cmd_clear does NOT remove worktree when PWD is a subdirectory of it" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/clear-subdir-keep"
  git worktree add -b clear-subdir-keep "$wt_path" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_path/.git"

  mkdir -p "${wt_path}/src"

  bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_path}/src'
    _cmd_clear '1' '1' '0' '0' >/dev/null 2>&1
  "

  assert [ -d "$wt_path" ]
}

# ---------------------------------------------------------------------------
# AC-13 — _cmd_remove outside the worktree succeeds normally (no regression)
# ---------------------------------------------------------------------------

@test "AC-13: _cmd_remove removes worktree normally when called from repo root" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/rm-normal"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-normal "$wt_path" HEAD >/dev/null 2>&1

  # Call from repo root (not inside the worktree)
  run _cmd_remove "rm-normal" 1
  assert_success

  # Worktree directory must be gone
  assert [ ! -d "$wt_path" ]
}

@test "AC-13: _cmd_remove removes branch after removing worktree (no regression)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_path
  wt_path="$GWT_WORKTREES_DIR/rm-branch-clean"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b rm-branch-clean "$wt_path" HEAD >/dev/null 2>&1

  run _cmd_remove "rm-branch-clean" 1
  assert_success

  # Branch must also be deleted
  run _branch_exists "rm-branch-clean"
  assert_failure
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "edge: _cmd_remove called from a completely different worktree is allowed" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  local wt_a wt_b
  wt_a="$GWT_WORKTREES_DIR/edge-wt-a"
  wt_b="$GWT_WORKTREES_DIR/edge-wt-b"
  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b edge-wt-a "$wt_a" HEAD >/dev/null 2>&1
  git worktree add -b edge-wt-b "$wt_b" HEAD >/dev/null 2>&1

  # Stand inside wt_a and remove wt_b — should succeed
  run bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_a}'
    _cmd_remove 'edge-wt-b' 1 2>&1
  "
  assert_success
  assert [ ! -d "$wt_b" ]
  # wt_a should still be intact
  assert [ -d "$wt_a" ]
}

@test "edge: wt.sh executed directly with no arguments exits non-zero or shows help" {
  run bash -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    bash '${PROJECT_ROOT}/wt.sh'
  "
  # Either exits 0 with help, or non-zero — but must NOT say "command not found"
  refute_output --partial "command not found"
}

@test "edge: wt.sh executed directly with unknown flag exits non-zero" {
  run bash -c "
    WT_INSTALL_DIR='${PROJECT_ROOT}'
    export WT_INSTALL_DIR
    bash '${PROJECT_ROOT}/wt.sh' --totally-unknown-flag-xyz 2>&1
  "
  assert_failure
}

@test "edge: install.sh creates ~/.local/bin dir if it does not exist" {
  local fake_home
  fake_home="$(cd "$(mktemp -d)" && pwd -P)"

  # Ensure ~/.local/bin does NOT exist in the fake home
  assert [ ! -d "${fake_home}/.local/bin" ]

  run bash -c "
    HOME='${fake_home}'
    export HOME
    PATH='/usr/bin:/bin'
    export PATH
    bash '${PROJECT_ROOT}/install.sh' --local 2>&1
  "
  assert_success

  # The directory must have been created
  assert [ -d "${fake_home}/.local/bin" ]

  rm -rf "$fake_home"
}

@test "edge: _cmd_clear with PWD inside worktree does not affect other clear operations" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
  source "$PROJECT_ROOT/lib/update.sh"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"

  local wt_inside wt_other wt_third
  wt_inside="$GWT_WORKTREES_DIR/edge-inside"
  wt_other="$GWT_WORKTREES_DIR/edge-other"
  wt_third="$GWT_WORKTREES_DIR/edge-third"

  git worktree add -b edge-inside "$wt_inside" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_inside/.git"

  git worktree add -b edge-other "$wt_other" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_other/.git"

  git worktree add -b edge-third "$wt_third" HEAD >/dev/null 2>&1
  touch -t 202001010000 "$wt_third/.git"

  bash -c "
    source '${PROJECT_ROOT}/lib/utils.sh'
    source '${PROJECT_ROOT}/lib/config.sh'
    source '${PROJECT_ROOT}/lib/worktree.sh'
    source '${PROJECT_ROOT}/lib/commands.sh'
    cd '${repo_dir}'
    _config_load
    cd '${wt_inside}'
    _cmd_clear '1' '1' '0' '0' >/dev/null 2>&1
  "

  # The one we were inside stays
  assert [ -d "$wt_inside" ]
  # The other two should be gone
  assert [ ! -d "$wt_other" ]
  assert [ ! -d "$wt_third" ]
}
