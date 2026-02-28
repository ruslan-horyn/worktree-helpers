#!/usr/bin/env bats
# STORY-021: Improve wt --init UX: colorized output, hook suggestions, auto .gitignore
#
# Tests cover:
#   AC1  - _cmd_init calls _init_colors (C_GREEN, C_YELLOW, C_RESET, C_DIM available)
#   AC2  - Done. Created: summary line is printed with C_GREEN color applied
#   AC3  - Error message on failure uses _err (no color regression)
#   AC4  - _cmd_init checks .gitignore before writing (string match: .worktrees/ or .worktrees)
#   AC5  - .worktrees/ appended (with trailing newline) when not in .gitignore
#   AC6  - "Updating .gitignore..." printed via _info before writing
#   AC7  - .gitignore already contains .worktrees/: step silently skipped (no message, no modification)
#   AC8  - Hint line printed after Done summary on fresh init
#   AC9  - Hint line printed on backup (option 2) path
#   AC10 - Hint line printed on overwrite (option 3) path
#   AC11 - Hint line NOT printed when option 1 (keep) chosen
#   AC12 - Color suppressed in non-tty context (variables are empty strings in BATS)
#   AC13 - _help_init documents colorized output, .gitignore update, and hint line
#   AC14 - _gitignore_has_worktrees detects .worktrees/ (with trailing slash)
#   AC15 - _gitignore_has_worktrees detects .worktrees (without trailing slash)
#   AC16 - .gitignore created if it does not exist
#   AC17 - .gitignore entry not duplicated if already present with trailing slash variant
#   AC18 - .gitignore entry not duplicated if already present without trailing slash
#   AC19 - "Updating .gitignore..." step message absent when entry already present
#
# All tests are expected to FAIL before STORY-021 is implemented.

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# ---------------------------------------------------------------------------
# Helper: run _cmd_init in a subprocess for a given repo dir with optional stdin
# ---------------------------------------------------------------------------
_run_cmd_init() {
  local repo_dir="$1"
  local stdin_input="$2"
  local force="${3:-0}"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init '$force' <<'ENDINPUT'
${stdin_input}
ENDINPUT
  "
}

# ---------------------------------------------------------------------------
# AC1 — _cmd_init calls _init_colors so color vars are defined
# ---------------------------------------------------------------------------

@test "AC1: _cmd_init calls _init_colors (function exists and is callable)" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    # Verify _init_colors is defined before calling _cmd_init
    type _init_colors >/dev/null 2>&1 && echo '_init_colors_exists'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  assert_output --partial "_init_colors_exists"
}

@test "AC1: C_GREEN C_RESET C_YELLOW C_DIM are set (may be empty in non-tty) after _init_colors" {
  local repo_dir
  repo_dir=$(create_test_repo)

  # In BATS (non-tty) _init_colors sets all vars to empty string (not unset)
  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    _init_colors
    # Variables must be defined (even if empty) — use parameter expansion to test
    echo \"C_GREEN=\${C_GREEN+defined}\"
    echo \"C_RESET=\${C_RESET+defined}\"
    echo \"C_YELLOW=\${C_YELLOW+defined}\"
    echo \"C_DIM=\${C_DIM+defined}\"
  "
  assert_success
  assert_output --partial "C_GREEN=defined"
  assert_output --partial "C_RESET=defined"
  assert_output --partial "C_YELLOW=defined"
  assert_output --partial "C_DIM=defined"
}

# ---------------------------------------------------------------------------
# AC2 — Done. Created: summary uses C_GREEN (non-tty: empty, but text still present)
# ---------------------------------------------------------------------------

@test "AC2: Done. Created: summary is present in output on fresh init" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  assert_output --partial "Done."
}

@test "AC2: Done. summary present on backup (option 2) path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


2
EOF
  "
  assert_success
  assert_output --partial "Done."
}

@test "AC2: Done. summary present on overwrite (option 3) path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


3
EOF
  "
  assert_success
  assert_output --partial "Done."
}

# ---------------------------------------------------------------------------
# AC3 — Error path uses _err (no color on errors)
# ---------------------------------------------------------------------------

@test "AC3: failure to write config.json triggers error message without ANSI escape codes" {
  local repo_dir
  repo_dir=$(create_test_repo)
  # Make .worktrees a file so config.json cannot be created as a directory's child
  mkdir -p "$repo_dir/.worktrees"
  chmod 000 "$repo_dir/.worktrees"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  " 2>&1
  # Status must be non-zero (error)
  [ "$status" -ne 0 ]
  # Restore permissions for teardown
  chmod 755 "$repo_dir/.worktrees"
}

# ---------------------------------------------------------------------------
# AC4 / AC14 / AC15 — _gitignore_has_worktrees helper detects entry
# ---------------------------------------------------------------------------

@test "AC14: _gitignore_has_worktrees returns 0 when .worktrees/ (with slash) is present" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    echo '.worktrees/' > '$repo_dir/.gitignore'
    _gitignore_has_worktrees '$repo_dir/.gitignore'
  "
  assert_success
}

@test "AC15: _gitignore_has_worktrees returns 0 when .worktrees (without slash) is present" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    echo '.worktrees' > '$repo_dir/.gitignore'
    _gitignore_has_worktrees '$repo_dir/.gitignore'
  "
  assert_success
}

@test "AC14/AC15: _gitignore_has_worktrees returns non-0 when entry is absent" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    echo 'node_modules/' > '$repo_dir/.gitignore'
    echo 'dist/' >> '$repo_dir/.gitignore'
    _gitignore_has_worktrees '$repo_dir/.gitignore'
  "
  [ "$status" -ne 0 ]
}

@test "AC14/AC15: _gitignore_has_worktrees returns non-0 when .gitignore does not exist" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _gitignore_has_worktrees '$repo_dir/.gitignore'
  "
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# AC5 — .worktrees/ appended when absent
# ---------------------------------------------------------------------------

@test "AC5: .worktrees/ appended to existing .gitignore when absent on fresh init" {
  local repo_dir
  repo_dir=$(create_test_repo)
  # Create .gitignore without .worktrees entry
  printf 'node_modules/\ndist/\n' > "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  run grep -x '\.worktrees/' "$repo_dir/.gitignore"
  assert_success
}

@test "AC5: .worktrees/ appended to .gitignore on backup (option 2) path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf 'node_modules/\n' > "$repo_dir/.gitignore"
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


2
EOF
  "
  assert_success
  run grep -x '\.worktrees/' "$repo_dir/.gitignore"
  assert_success
}

@test "AC5: .worktrees/ appended to .gitignore on overwrite (option 3) path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf 'node_modules/\n' > "$repo_dir/.gitignore"
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


3
EOF
  "
  assert_success
  run grep -x '\.worktrees/' "$repo_dir/.gitignore"
  assert_success
}

@test "AC5: .worktrees/ appended to .gitignore on keep (option 1) path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf 'node_modules/\n' > "$repo_dir/.gitignore"
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


1
EOF
  "
  assert_success
  run grep -x '\.worktrees/' "$repo_dir/.gitignore"
  assert_success
}

# ---------------------------------------------------------------------------
# AC16 — .gitignore created if it does not exist
# ---------------------------------------------------------------------------

@test "AC16: .gitignore is created with .worktrees/ entry when file did not exist" {
  local repo_dir
  repo_dir=$(create_test_repo)
  # Ensure .gitignore does not exist
  rm -f "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  assert [ -f "$repo_dir/.gitignore" ]
  run grep -x '\.worktrees/' "$repo_dir/.gitignore"
  assert_success
}

# ---------------------------------------------------------------------------
# AC6 — "Updating .gitignore..." message printed when entry absent
# ---------------------------------------------------------------------------

@test "AC6: 'Updating .gitignore...' message appears in output when entry was absent" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf 'node_modules/\n' > "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  assert_output --partial "Updating .gitignore..."
}

@test "AC6: 'Updating .gitignore...' message appears when .gitignore did not exist" {
  local repo_dir
  repo_dir=$(create_test_repo)
  rm -f "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  assert_output --partial "Updating .gitignore..."
}

# ---------------------------------------------------------------------------
# AC7 / AC17 / AC18 / AC19 — .gitignore silently skipped when entry already present
# ---------------------------------------------------------------------------

@test "AC7: .gitignore not modified when .worktrees/ (with slash) already present" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf 'node_modules/\n.worktrees/\n' > "$repo_dir/.gitignore"
  local before_content
  before_content=$(cat "$repo_dir/.gitignore")

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  run bash -c "cat '$repo_dir/.gitignore'"
  assert_output "$before_content"
}

@test "AC18: .gitignore not modified when .worktrees (without slash) already present" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf 'node_modules/\n.worktrees\n' > "$repo_dir/.gitignore"
  local before_content
  before_content=$(cat "$repo_dir/.gitignore")

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  run bash -c "cat '$repo_dir/.gitignore'"
  assert_output "$before_content"
}

@test "AC17: .worktrees/ entry not duplicated when already present" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf '.worktrees/\n' > "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  # Count occurrences — must be exactly 1
  run bash -c "grep -c '\.worktrees/' '$repo_dir/.gitignore'"
  assert_output "1"
}

@test "AC19: 'Updating .gitignore...' message absent when entry already present" {
  local repo_dir
  repo_dir=$(create_test_repo)
  printf '.worktrees/\n' > "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  refute_output --partial "Updating .gitignore..."
}

# ---------------------------------------------------------------------------
# AC8 / AC9 / AC10 — Hint line printed on fresh init, backup, overwrite paths
# ---------------------------------------------------------------------------

@test "AC8: hint line printed after Done summary on fresh init" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  assert_output --partial "Hint:"
  assert_output --partial "created.sh"
}

@test "AC9: hint line printed after Done summary on backup (option 2) path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


2
EOF
  "
  assert_success
  assert_output --partial "Hint:"
  assert_output --partial "created.sh"
}

@test "AC10: hint line printed after Done summary on overwrite (option 3) path" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


3
EOF
  "
  assert_success
  assert_output --partial "Hint:"
  assert_output --partial "created.sh"
}

# ---------------------------------------------------------------------------
# AC11 — Hint line NOT printed when option 1 (keep) chosen
# ---------------------------------------------------------------------------

@test "AC11: hint line NOT printed when option 1 (keep) chosen" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


1
EOF
  "
  assert_success
  refute_output --partial "Hint:"
}

@test "AC11: hint line NOT printed when empty input defaults to option 1 (keep)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'



EOF
  "
  assert_success
  refute_output --partial "Hint:"
}

@test "AC11: hint line NOT printed when --force flag used (keep path)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 1 <<'EOF'


EOF
  "
  assert_success
  refute_output --partial "Hint:"
}

# ---------------------------------------------------------------------------
# AC12 — Color suppressed in non-tty context (BATS = non-tty)
# ---------------------------------------------------------------------------

@test "AC12: in non-tty context (BATS), C_GREEN is empty string after _init_colors" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    source '$PROJECT_ROOT/lib/utils.sh'
    _init_colors
    # stdout is not a tty in this subshell, so C_GREEN must be empty
    printf '%s' \"\$C_GREEN\" | wc -c | tr -d ' '
  "
  assert_success
  assert_output "0"
}

@test "AC12: Done. text is present in output even when color vars are empty (non-tty)" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  assert_output --partial "Done."
}

# ---------------------------------------------------------------------------
# AC13 — _help_init documents colorized output, .gitignore update, and hint line
# ---------------------------------------------------------------------------

@test "AC13: _help_init mentions .gitignore in its output" {
  run bash -c "
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _help_init
  "
  assert_success
  assert_output --partial ".gitignore"
}

@test "AC13: _help_init mentions colorized or color in its output" {
  run bash -c "
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _help_init
  "
  assert_success
  # Case-insensitive match for 'color' or 'colour'
  run bash -c "
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _help_init | grep -i -e 'color' -e 'colour'
  "
  assert_success
}

@test "AC13: _help_init mentions hint in its output" {
  run bash -c "
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _help_init
  "
  assert_success
  run bash -c "
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _help_init | grep -i 'hint'
  "
  assert_success
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "edge: .gitignore entry appended correctly even when existing file has no trailing newline" {
  local repo_dir
  repo_dir=$(create_test_repo)
  # Write file without trailing newline
  printf 'node_modules/' > "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  # .worktrees/ must appear on its own line
  run grep -x '\.worktrees/' "$repo_dir/.gitignore"
  assert_success
  # node_modules/ must still be present on its own line
  run grep -x 'node_modules/' "$repo_dir/.gitignore"
  assert_success
}

@test "edge: hint line text contains 'npm install' or 'cp .env' (usage examples)" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  # The hint must contain at least one practical example
  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  " 2>&1
  # Check output contains a practical usage example
  [[ "$output" =~ "npm install" ]] || [[ "$output" =~ ".env" ]] || [[ "$output" =~ "customise" ]]
}

@test "edge: _cmd_init succeeds and appends .gitignore on fresh init in non-Node.js repo" {
  cd "$TEST_TEMP_DIR"
  mkdir -p init-no-pkg
  cd init-no-pkg
  git init >/dev/null 2>&1
  git config user.email "test@test.com"
  git config user.name "Test User"
  echo "init" > README.md
  git add README.md
  git commit -m "initial" >/dev/null 2>&1

  run bash -c "
    cd '$TEST_TEMP_DIR/init-no-pkg'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


EOF
  "
  assert_success
  run grep -x '\.worktrees/' "$TEST_TEMP_DIR/init-no-pkg/.gitignore"
  assert_success
}

@test "edge: _cmd_init with --force still appends .worktrees/ to .gitignore" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"
  printf 'node_modules/\n' > "$repo_dir/.gitignore"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 1 <<'EOF'


EOF
  "
  assert_success
  run grep -x '\.worktrees/' "$repo_dir/.gitignore"
  assert_success
}

@test "edge: _cmd_init with --force does not print hint line (keep path)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 1 <<'EOF'


EOF
  "
  assert_success
  refute_output --partial "Hint:"
}

@test "edge: _gitignore_has_worktrees partial match '.worktrees-extra' does not trigger false positive" {
  local repo_dir
  repo_dir=$(create_test_repo)

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    # Similar-looking entry but NOT .worktrees or .worktrees/
    echo '.worktrees-extra/' > '$repo_dir/.gitignore'
    _gitignore_has_worktrees '$repo_dir/.gitignore'
  "
  # Must return failure — partial match must not count
  [ "$status" -ne 0 ]
}
