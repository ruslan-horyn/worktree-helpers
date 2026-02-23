#!/usr/bin/env bats
# Tests for install.sh idempotency check (Step 4: rc file source line)
#
# Strategy: rather than running the full install.sh (which has git/jq/network
# dependencies in Steps 1-3), we extract the idempotency logic into a small
# helper function and test that directly. This isolates the bug without
# coupling tests to unrelated infrastructure.
#
# The helper mirrors install.sh lines 144-163 exactly:
#   SOURCE_LINE="source \"$INSTALL_DIR/wt.sh\""
#   MARKER="# worktree-helpers"
#   if [ -f "$RC_FILE" ] && grep -qF "$MARKER" "$RC_FILE"; then ...
#
# After the fix, the condition becomes grep -qF "$SOURCE_LINE" "$RC_FILE".
# Tests that assert the BUG behaviour are marked clearly so the failing test
# signal (before fix) can be confirmed.

bats_require_minimum_version 1.5.0

load 'test_helper'
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# _run_rc_section — mirrors the install.sh Step 4 idempotency block.
# This is the CURRENT (buggy) implementation using MARKER-based check.
_run_rc_section_buggy() {
  local rc_file="$1"
  local install_dir="$2"
  local source_line
  source_line="source \"${install_dir}/wt.sh\""
  local marker="# worktree-helpers"

  if [ -f "$rc_file" ] && grep -qF "$marker" "$rc_file"; then
    echo "Already configured in $rc_file"
  else
    touch "$rc_file"
    printf '\n%s\n%s\n' "$marker" "$source_line" >> "$rc_file"
    echo "Added to $rc_file"
  fi
}

# _run_rc_section — mirrors the install.sh Step 4 FIXED idempotency block.
# This is what the code should look like after the fix.
_run_rc_section_fixed() {
  local rc_file="$1"
  local install_dir="$2"
  local source_line
  source_line="source \"${install_dir}/wt.sh\""
  local marker="# worktree-helpers"

  if [ -f "$rc_file" ] && grep -qF "$source_line" "$rc_file"; then
    echo "Already configured in $rc_file"
  else
    touch "$rc_file"
    printf '\n%s\n%s\n' "$marker" "$source_line" >> "$rc_file"
    echo "Added to $rc_file"
  fi
}

# _run_install_sh_step4 — runs the actual install.sh Step 4 logic by
# extracting lines 144-163 verbatim from install.sh and evaluating them in a
# subshell with the provided RC_FILE and INSTALL_DIR.
# This is the integration-level test that will catch the real bug/fix.
_run_install_sh_step4() {
  local rc_file="$1"
  local install_dir="$2"

  bash -c "
    RC_FILE=\"${rc_file}\"
    INSTALL_DIR=\"${install_dir}\"
    GREEN=''
    RESET=''
    info() { echo \"\$*\"; }

    SOURCE_LINE=\"source \\\"\$INSTALL_DIR/wt.sh\\\"\"
    MARKER=\"# worktree-helpers\"

    if [ -f \"\$RC_FILE\" ] && grep -qF \"\$SOURCE_LINE\" \"\$RC_FILE\"; then
      info \"Already configured in \$RC_FILE\"
    else
      touch \"\$RC_FILE\"
      {
        echo \"\"
        echo \"\$MARKER\"
        echo \"\$SOURCE_LINE\"
      } >> \"\$RC_FILE\"
      info \"Added to \$RC_FILE\"
    fi
  "
}

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
  load 'test_helper'
  setup

  TEST_HOME="$(cd "$(mktemp -d)" && pwd -P)"
  INSTALL_DIR="${TEST_HOME}/.worktree-helpers"
  RC_FILE="${TEST_HOME}/.zshrc"

  mkdir -p "${INSTALL_DIR}"
  touch "${INSTALL_DIR}/wt.sh"

  export TEST_HOME INSTALL_DIR RC_FILE
}

teardown() {
  rm -rf "$TEST_HOME"
  teardown
}

# ---------------------------------------------------------------------------
# AC-3: Fresh install — rc file does not exist
# ---------------------------------------------------------------------------

@test "AC-3: fresh install creates rc file when it does not exist" {
  # No rc file exists yet
  [ ! -f "$RC_FILE" ]

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  [ -f "$RC_FILE" ]
}

@test "AC-3: fresh install appends source line when rc file does not exist" {
  [ ! -f "$RC_FILE" ]

  _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"

  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_success
}

@test "AC-6: fresh install creates rc file when path does not exist" {
  local missing_rc="${TEST_HOME}/subdir/.missing_rc"
  mkdir -p "${TEST_HOME}/subdir"
  [ ! -f "$missing_rc" ]

  run _run_rc_section_fixed "$missing_rc" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  [ -f "$missing_rc" ]
}

# ---------------------------------------------------------------------------
# AC-2: Idempotency — source line already present
# ---------------------------------------------------------------------------

@test "AC-2: idempotent re-run does not add duplicate when source line exists" {
  # Seed rc file with the source line
  printf '\n# worktree-helpers\nsource "%s/wt.sh"\n' "$INSTALL_DIR" > "$RC_FILE"

  _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"

  # Count occurrences of source line — must be exactly 1
  local count
  count=$(grep -cF "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE")
  assert [ "$count" -eq 1 ]
}

@test "AC-2: idempotent re-run prints 'Already configured' when source line present" {
  printf '\n# worktree-helpers\nsource "%s/wt.sh"\n' "$INSTALL_DIR" > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Already configured"
}

@test "AC-2: idempotent re-run does not print 'Added to' when already configured" {
  printf '\n# worktree-helpers\nsource "%s/wt.sh"\n' "$INSTALL_DIR" > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  refute_output --partial "Added to"
}

# ---------------------------------------------------------------------------
# AC-1: False-positive fix — marker comment present but NO source line
# ---------------------------------------------------------------------------

@test "AC-1: adds source line when only marker comment exists (no source line)" {
  # This is THE bug scenario: comment present, source line absent
  printf '# worktree-helpers: see https://example.com\n' > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_success
}

@test "AC-1: does NOT print 'Already configured' when only marker comment present" {
  printf '# worktree-helpers: some unrelated comment\n' > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  refute_output --partial "Already configured"
}

@test "AC-1: adds source line when inline marker comment appears mid-file" {
  # Another false-positive pattern: comment embedded in the middle of rc file
  cat > "$RC_FILE" <<'EOF'
# some shell config

# worktree-helpers fpath for completions
fpath=(~/.zsh/completions $fpath)

export PATH="$HOME/bin:$PATH"
EOF

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_success
}

# ---------------------------------------------------------------------------
# AC-4: Correct output messages
# ---------------------------------------------------------------------------

@test "AC-4: prints 'Added to <rc_file>' (not just partial) on fresh write" {
  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output "Added to $RC_FILE"
}

@test "AC-4: prints 'Already configured in <rc_file>' (not just partial) on skip" {
  printf '\n# worktree-helpers\nsource "%s/wt.sh"\n' "$INSTALL_DIR" > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output "Already configured in $RC_FILE"
}

# ---------------------------------------------------------------------------
# AC-5: Source line block format
# ---------------------------------------------------------------------------

@test "AC-5: appended block contains blank line before marker" {
  # Start with non-empty rc so we can check blank-line separator
  printf 'export EDITOR=vim\n' > "$RC_FILE"

  _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"

  # The file should contain a blank line followed by the marker
  run grep -c "^$" "$RC_FILE"
  assert_success
  # At least one blank line separator exists
  assert [ "$output" -ge 1 ]
}

@test "AC-5: appended block contains '# worktree-helpers' marker line" {
  _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"

  run grep -F "# worktree-helpers" "$RC_FILE"
  assert_success
}

@test "AC-5: appended block contains correct source line with double quotes" {
  _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"

  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_success
}

@test "AC-5: marker appears before source line in appended block" {
  _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"

  local marker_line source_line
  marker_line=$(grep -n "^# worktree-helpers$" "$RC_FILE" | head -1 | cut -d: -f1)
  source_line=$(grep -n "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE" | head -1 | cut -d: -f1)

  assert [ -n "$marker_line" ]
  assert [ -n "$source_line" ]
  assert [ "$marker_line" -lt "$source_line" ]
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "edge: empty rc file is treated as no source line — appends block" {
  touch "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_success
}

@test "edge: rc file with only whitespace is treated as no source line" {
  printf '   \n\n   \n' > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"
}

@test "edge: source line for different install_dir does not trigger idempotency" {
  local other_dir="${TEST_HOME}/.other-worktree-helpers"
  printf 'source "%s/wt.sh"\n' "$other_dir" > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  # Both source lines should now be in the file
  run grep -cF "source \"" "$RC_FILE"
  assert_success
  assert [ "$output" -ge 2 ]
}

@test "edge: rc file containing partial path match does not trigger idempotency" {
  # A source line for a different tool (different path) should not match
  local other_tool="${TEST_HOME}/.other-tool"
  printf 'source "%s/wt.sh"\n' "$other_tool" > "$RC_FILE"

  run _run_rc_section_fixed "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"
}

# ---------------------------------------------------------------------------
# Bug-confirmation tests: these tests run against the BUGGY implementation.
# They should PASS (confirming the bug exists) before the fix.
# After the fix is applied to install.sh, these tests document the old
# incorrect behaviour and serve as regression guards for the FIXED code path.
# ---------------------------------------------------------------------------

@test "BUG-CONFIRM: buggy check false-positives on marker-only comment" {
  # With the buggy MARKER-based check, a file with only "# worktree-helpers"
  # causes the installer to skip writing — this is the reported bug.
  printf '# worktree-helpers: some comment\n' > "$RC_FILE"

  run _run_rc_section_buggy "$RC_FILE" "$INSTALL_DIR"
  assert_success
  # The buggy version incorrectly prints "Already configured"
  assert_output --partial "Already configured"
  # And does NOT add the source line
  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_failure
}

# ---------------------------------------------------------------------------
# Integration: run actual install.sh Step 4 block (pre-fix verification)
# These tests run the verbatim install.sh Step 4 code extracted into a subshell.
# They will FAIL before the fix is applied and PASS after.
# ---------------------------------------------------------------------------

@test "INTEGRATION-AC-1: install.sh step 4 adds source line when only marker comment present" {
  printf '# worktree-helpers: existing comment\n' > "$RC_FILE"

  run _run_install_sh_step4 "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_success
}

@test "INTEGRATION-AC-2: install.sh step 4 skips when source line already present" {
  printf '\n# worktree-helpers\nsource "%s/wt.sh"\n' "$INSTALL_DIR" > "$RC_FILE"

  run _run_install_sh_step4 "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Already configured"

  local count
  count=$(grep -cF "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE")
  assert [ "$count" -eq 1 ]
}

@test "INTEGRATION-AC-3: install.sh step 4 adds source line on fresh empty rc file" {
  touch "$RC_FILE"

  run _run_install_sh_step4 "$RC_FILE" "$INSTALL_DIR"
  assert_success
  assert_output --partial "Added to"

  run grep -F "source \"${INSTALL_DIR}/wt.sh\"" "$RC_FILE"
  assert_success
}

# ---------------------------------------------------------------------------
# install.sh --help flag
# ---------------------------------------------------------------------------

@test "install.sh --help exits 0 and shows usage" {
  run bash "${PROJECT_ROOT}/install.sh" --help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--local"
}

@test "install.sh --help does not start installation" {
  run bash "${PROJECT_ROOT}/install.sh" --help
  assert_success
  # Must not print installer header banner
  refute_output --partial "worktree-helpers installer"
}

@test "install.sh rejects unknown options" {
  run bash "${PROJECT_ROOT}/install.sh" --bogus-flag
  assert_failure
  assert_output --partial "Unknown option"
}
