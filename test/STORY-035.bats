#!/usr/bin/env bats
# STORY-035: wt --init — offer to copy/backup existing hooks
#
# Tests cover:
#   AC1  - detect non-empty hooks dir
#   AC2  - print hooks directory path and list existing files
#   AC3  - display 3-option prompt with "Choice [1]:"
#   AC4  - option 1 (keep): hooks untouched, config.json still written
#   AC5  - option 2 (backup): hooks moved to <dir>.bak, new defaults written
#   AC6  - option 3 (overwrite): hooks replaced with defaults
#   AC7  - default choice is 1 (Enter with no input keeps existing hooks)
#   AC8  - non-interactive / --force: skips prompt, keeps hooks
#   AC9  - empty or absent hooks dir: no prompt, original behaviour
#   AC10 - shellcheck passes (run separately via npm test or shellcheck)
#
# All tests are expected to FAIL before STORY-035 is implemented.

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# ---------------------------------------------------------------------------
# Helper: source lib files inside a subprocess pointing at a given repo dir
# ---------------------------------------------------------------------------
_run_cmd_init() {
  local repo_dir="$1"
  local stdin_input="$2"   # text piped to _cmd_init
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
# AC9 — No prompt when hooks dir does not exist (fresh init)
# ---------------------------------------------------------------------------

@test "AC9: fresh init (no hooks dir) creates config.json and hooks without prompting" {
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
  assert [ -f "$repo_dir/.worktrees/config.json" ]
  assert [ -x "$repo_dir/.worktrees/hooks/created.sh" ]
  assert [ -x "$repo_dir/.worktrees/hooks/switched.sh" ]
  # No mention of "already exists" in fresh init
  refute_output --partial "already exists"
}

@test "AC9: fresh init (empty hooks dir) proceeds without prompting" {
  local repo_dir
  repo_dir=$(create_test_repo)

  # Create an empty hooks directory
  mkdir -p "$repo_dir/.worktrees/hooks"

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
  assert [ -f "$repo_dir/.worktrees/config.json" ]
  # No mention of "already exists" when hooks dir is empty
  refute_output --partial "already exists"
}

# ---------------------------------------------------------------------------
# AC1 — Detection of non-empty hooks directory
# ---------------------------------------------------------------------------

@test "AC1: detects non-empty hooks dir when hooks exist" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"
  chmod +x "$repo_dir/.worktrees/hooks/custom.sh"

  # User chooses option 1 (keep)
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
  # Output must mention that hooks dir already exists
  assert_output --partial "already exists"
}

# ---------------------------------------------------------------------------
# AC2 — Listing of existing hook files
# ---------------------------------------------------------------------------

@test "AC2: lists existing hook filenames when hooks dir is non-empty" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/post-checkout.sh"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/post-merge.sh"

  # User chooses option 1 (keep)
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
  assert_output --partial "post-checkout.sh"
  assert_output --partial "post-merge.sh"
}

@test "AC2: lists hook filenames with '  - ' prefix" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/created.sh"

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
  assert_output --partial "  - created.sh"
}

# ---------------------------------------------------------------------------
# AC3 — 3-option prompt
# ---------------------------------------------------------------------------

@test "AC3: shows 3-option menu when hooks dir is non-empty" {
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
  assert_output --partial "[1]"
  assert_output --partial "[2]"
  assert_output --partial "[3]"
}

@test "AC3: prompt shows 'Choice [1]:' indicating default is 1" {
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
  assert_output --partial "Choice [1]"
}

# ---------------------------------------------------------------------------
# AC4 — Option 1: keep existing hooks, config.json still written
# ---------------------------------------------------------------------------

@test "AC4: option 1 (keep) leaves existing hook files untouched" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho custom" > "$repo_dir/.worktrees/hooks/created.sh"
  local original_content
  original_content=$(cat "$repo_dir/.worktrees/hooks/created.sh")

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
  # Hook content must be unchanged
  run bash -c "cat '$repo_dir/.worktrees/hooks/created.sh'"
  assert_output "$original_content"
}

@test "AC4: option 1 (keep) still creates config.json" {
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
  assert [ -f "$repo_dir/.worktrees/config.json" ]
}

@test "AC4: option 1 exits with status 0" {
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
}

# ---------------------------------------------------------------------------
# AC5 — Option 2: backup existing hooks to <dir>.bak, write new defaults
# ---------------------------------------------------------------------------

@test "AC5: option 2 (backup) moves hooks dir to <dir>.bak" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho custom" > "$repo_dir/.worktrees/hooks/custom.sh"

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
  assert [ -d "$repo_dir/.worktrees/hooks.bak" ]
  assert [ -f "$repo_dir/.worktrees/hooks.bak/custom.sh" ]
}

@test "AC5: option 2 (backup) writes new default hook files after backup" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho custom" > "$repo_dir/.worktrees/hooks/custom.sh"

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
  assert [ -x "$repo_dir/.worktrees/hooks/created.sh" ]
  assert [ -x "$repo_dir/.worktrees/hooks/switched.sh" ]
}

@test "AC5: option 2 (backup) still creates config.json" {
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
  assert [ -f "$repo_dir/.worktrees/config.json" ]
}

@test "AC5: option 2 exits with status 0" {
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
}

# ---------------------------------------------------------------------------
# AC6 — Option 3: overwrite with defaults
# ---------------------------------------------------------------------------

@test "AC6: option 3 (overwrite) replaces hooks with defaults" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho totally-custom" > "$repo_dir/.worktrees/hooks/created.sh"
  chmod +x "$repo_dir/.worktrees/hooks/created.sh"

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
  assert [ -x "$repo_dir/.worktrees/hooks/created.sh" ]
  assert [ -x "$repo_dir/.worktrees/hooks/switched.sh" ]
  # Custom content must be gone — default hook does NOT contain "totally-custom"
  run bash -c "grep 'totally-custom' '$repo_dir/.worktrees/hooks/created.sh'"
  [ "$status" -ne 0 ]
}

@test "AC6: option 3 (overwrite) still creates config.json" {
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
  assert [ -f "$repo_dir/.worktrees/config.json" ]
}

@test "AC6: option 3 exits with status 0" {
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
}

# ---------------------------------------------------------------------------
# AC7 — Default choice is 1 (Enter / empty input = keep)
# ---------------------------------------------------------------------------

@test "AC7: pressing Enter (empty input) keeps existing hooks (default=1)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho custom" > "$repo_dir/.worktrees/hooks/created.sh"
  chmod +x "$repo_dir/.worktrees/hooks/created.sh"
  local original_content
  original_content=$(cat "$repo_dir/.worktrees/hooks/created.sh")

  # Provide blank line for project name, main branch, and then blank for the choice prompt
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
  # Hook file must remain unchanged
  run bash -c "cat '$repo_dir/.worktrees/hooks/created.sh'"
  assert_output "$original_content"
}

@test "AC7: default choice does not create a .bak directory" {
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
  # No backup directory created
  assert [ ! -d "$repo_dir/.worktrees/hooks.bak" ]
}

# ---------------------------------------------------------------------------
# AC8 — Non-interactive mode: --force flag skips prompt, keeps hooks
# ---------------------------------------------------------------------------

@test "AC8: --force flag skips the hooks prompt and keeps existing hooks" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho custom-forced" > "$repo_dir/.worktrees/hooks/created.sh"
  chmod +x "$repo_dir/.worktrees/hooks/created.sh"
  local original_content
  original_content=$(cat "$repo_dir/.worktrees/hooks/created.sh")

  # Pass force=1 to _cmd_init; no interactive prompts at all
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
  # Hook must be unchanged
  run bash -c "cat '$repo_dir/.worktrees/hooks/created.sh'"
  assert_output "$original_content"
}

@test "AC8: --force flag still creates config.json without prompting" {
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
  assert [ -f "$repo_dir/.worktrees/config.json" ]
}

@test "AC8: --force flag does not show '3-option' prompt output" {
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
  # The 3-option menu must not appear
  refute_output --partial "Choice [1]"
}

@test "AC8: piped (non-interactive) stdin skips prompt and keeps hooks" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho piped-custom" > "$repo_dir/.worktrees/hooks/created.sh"
  chmod +x "$repo_dir/.worktrees/hooks/created.sh"
  local original_content
  original_content=$(cat "$repo_dir/.worktrees/hooks/created.sh")

  # Pipe empty responses for project/branch prompts; stdin is not a tty
  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    printf '\n\n' | _cmd_init 0
  "
  assert_success
  # Hook must be unchanged
  run bash -c "cat '$repo_dir/.worktrees/hooks/created.sh'"
  assert_output "$original_content"
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "edge: invalid choice (e.g. '5') falls back to keep (option 1)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh\necho original" > "$repo_dir/.worktrees/hooks/created.sh"
  chmod +x "$repo_dir/.worktrees/hooks/created.sh"
  local original_content
  original_content=$(cat "$repo_dir/.worktrees/hooks/created.sh")

  run bash -c "
    cd '$repo_dir'
    source '$PROJECT_ROOT/lib/utils.sh'
    source '$PROJECT_ROOT/lib/config.sh'
    source '$PROJECT_ROOT/lib/worktree.sh'
    source '$PROJECT_ROOT/lib/commands.sh'
    _cmd_init 0 <<'EOF'


5
EOF
  "
  assert_success
  # Invalid choice: hooks must remain untouched (fallback to keep)
  run bash -c "cat '$repo_dir/.worktrees/hooks/created.sh'"
  assert_output "$original_content"
}

@test "edge: option 2 backup does not fail when .bak already exists (overwrites or merges)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/custom.sh"
  # Pre-create a stale .bak dir
  mkdir -p "$repo_dir/.worktrees/hooks.bak"
  echo "#!/bin/sh\necho stale" > "$repo_dir/.worktrees/hooks.bak/old.sh"

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
  # Must not crash; exit 0 or at minimum a non-fatal warning
  assert_success
}

@test "edge: multiple hooks listed (3 files) are all shown in the prompt output" {
  local repo_dir
  repo_dir=$(create_test_repo)
  mkdir -p "$repo_dir/.worktrees/hooks"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/alpha.sh"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/beta.sh"
  echo "#!/bin/sh" > "$repo_dir/.worktrees/hooks/gamma.sh"

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
  assert_output --partial "alpha.sh"
  assert_output --partial "beta.sh"
  assert_output --partial "gamma.sh"
}
