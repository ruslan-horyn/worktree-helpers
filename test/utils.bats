#!/usr/bin/env bats
# Tests for lib/utils.sh

setup() {
  load 'test_helper'
  setup
  load_wt
}

teardown() {
  teardown
}

# --- _err ---

@test "_err writes to stderr" {
  run --separate-stderr _err "something went wrong"
  assert_output ""
  assert [ -n "$stderr" ]
  assert [ "$stderr" = "something went wrong" ]
}

# --- _info ---

@test "_info writes to stdout" {
  run _info "hello world"
  assert_success
  assert_output "hello world"
}

# --- _debug ---

@test "_debug outputs nothing when GWT_DEBUG=0" {
  GWT_DEBUG=0
  run _debug "debug message"
  assert_success
  assert_output ""
}

@test "_debug outputs when GWT_DEBUG=1" {
  GWT_DEBUG=1
  run _debug "debug message"
  assert_success
  assert_output "[gwt] debug message"
}

@test "_debug outputs when GWT_DEBUG=true" {
  GWT_DEBUG=true
  run _debug "debug message"
  assert_success
  assert_output "[gwt] debug message"
}

@test "_debug outputs when GWT_DEBUG=yes" {
  GWT_DEBUG=yes
  run _debug "debug message"
  assert_success
  assert_output "[gwt] debug message"
}

# --- _require ---

@test "_require passes for installed command (git)" {
  run _require git
  assert_success
}

@test "_require fails for missing command" {
  run _require nonexistent_command_xyz
  assert_failure
}

# --- _repo_root ---

@test "_repo_root returns correct path inside a git repo" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _repo_root
  assert_success
  assert_output "$repo_dir"
}

@test "_repo_root errors outside a git repo" {
  cd "$TEST_TEMP_DIR"
  mkdir -p not_a_repo
  cd not_a_repo

  run _repo_root
  assert_failure
}

# --- _main_repo_root ---

@test "_main_repo_root returns correct path from main repo" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _main_repo_root
  assert_success
  assert_output "$repo_dir"
}

@test "_main_repo_root returns main repo path from worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  _config_load

  mkdir -p "$GWT_WORKTREES_DIR"
  git worktree add -b test-wt "$GWT_WORKTREES_DIR/test-wt" HEAD 2>/dev/null

  cd "$GWT_WORKTREES_DIR/test-wt"
  run _main_repo_root
  assert_success
  assert_output "$repo_dir"
}

@test "_main_repo_root is not contaminated by cd output (chpwd hook simulation)" {
  local repo_dir
  repo_dir=$(create_test_repo)

  # Create a wrapper script that simulates a chpwd hook by overriding cd
  # to print extra output, then calls _main_repo_root.
  # The initial cd to repo_dir is suppressed; then the cd override is set
  # so _main_repo_root's internal cd invocation would be contaminated
  # without the >/dev/null 2>&1 fix.
  run bash -c '
    source "'"$PROJECT_ROOT"'/lib/utils.sh"
    builtin cd "'"$repo_dir"'"
    cd() { echo "chpwd: now in $1" >&1; echo "chpwd-stderr: $1" >&2; builtin cd "$@"; }
    export -f cd
    _main_repo_root
  '
  assert_success
  # Output must be exactly the repo path — no chpwd contamination
  assert_output "$repo_dir"
}

@test "_main_repo_root output is a single line with no extra content" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _main_repo_root
  assert_success
  # Verify output is exactly one line (no trailing newline contamination)
  local line_count
  line_count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
  assert [ "$line_count" -eq 1 ]
  # Verify output starts with / (absolute path)
  assert [ "${output#/}" != "$output" ]
}

# --- _branch_exists ---

@test "_branch_exists detects existing branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _branch_exists main
  assert_success
}

@test "_branch_exists fails for missing branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _branch_exists nonexistent-branch
  assert_failure
}

# --- _current_branch ---

@test "_current_branch returns the checked-out branch name" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _current_branch
  assert_success
  assert_output "main"
}

# --- _main_branch ---

@test "_main_branch detects origin/main" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _main_branch
  assert_success
  assert_output "origin/main"
}

@test "_main_branch detects origin/master when main does not exist" {
  local origin_dir="$TEST_TEMP_DIR/origin-master.git"
  local repo_dir="$TEST_TEMP_DIR/repo-master"
  git init --bare "$origin_dir" 2>/dev/null
  git clone "$origin_dir" "$repo_dir" 2>/dev/null
  cd "$repo_dir"
  git config user.email "test@test.com"
  git config user.name "Test User"
  echo "init" > README.md
  git add README.md
  git commit -m "initial" 2>/dev/null
  # Rename to master
  git branch -m master 2>/dev/null
  git push -u origin master 2>/dev/null

  run _main_branch
  assert_success
  assert_output "origin/master"
}

# --- _normalize_ref ---

@test "_normalize_ref adds origin/ prefix to plain branch" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _normalize_ref "main"
  assert_success
  assert_output "origin/main"
}

@test "_normalize_ref keeps origin/ prefix when already present" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _normalize_ref "origin/main"
  assert_success
  assert_output "origin/main"
}

@test "_normalize_ref returns empty for empty input" {
  run _normalize_ref ""
  assert_success
  assert_output ""
}

# --- _project_name ---

@test "_project_name reads from package.json" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _project_name
  assert_success
  assert_output "test-project"
}

@test "_project_name falls back to dirname when no package.json" {
  mkdir -p "$TEST_TEMP_DIR/my-dir"
  cd "$TEST_TEMP_DIR/my-dir"

  run _project_name
  assert_success
  assert_output "my-dir"
}

@test "_project_name strips scope from scoped npm packages" {
  mkdir -p "$TEST_TEMP_DIR/scoped"
  cd "$TEST_TEMP_DIR/scoped"
  echo '{"name":"@scope/my-pkg"}' > package.json

  run _project_name
  assert_success
  assert_output "my-pkg"
}

# --- _calc_cutoff ---

@test "_calc_cutoff returns a timestamp" {
  run _calc_cutoff 7
  assert_success
  # Should be a number
  assert [ "$output" -gt 0 ]
}

@test "_calc_cutoff for 0 days returns close to now" {
  local now
  now=$(date +%s)
  run _calc_cutoff 0
  assert_success
  # Cutoff should be within 2 seconds of now
  local diff=$(( output - now ))
  [ "$diff" -ge -2 ] && [ "$diff" -le 2 ]
}

# --- _age_display ---

@test "_age_display returns 'today' for current timestamp" {
  local now
  now=$(date +%s)
  run _age_display "$now"
  assert_success
  assert_output "today"
}

@test "_age_display returns '1 day ago' for yesterday" {
  local yesterday
  yesterday=$(( $(date +%s) - 86400 ))
  run _age_display "$yesterday"
  assert_success
  assert_output "1 day ago"
}

@test "_age_display returns 'N days ago' for older timestamps" {
  local five_days_ago
  five_days_ago=$(( $(date +%s) - 86400 * 5 ))
  run _age_display "$five_days_ago"
  assert_success
  assert_output "5 days ago"
}

# --- _wt_count ---

@test "_wt_count returns correct worktree count" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _wt_count
  assert_success
  # At least 1 (the main worktree)
  assert [ "$output" -ge 1 ]
}

@test "_wt_count increases after adding worktree" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  local before
  before=$(_wt_count)

  git worktree add -b test-count "$TEST_TEMP_DIR/wt-count" HEAD 2>/dev/null

  local after
  after=$(_wt_count)
  assert [ "$after" -eq $((before + 1)) ]
}

# --- _wt_warn_count ---

@test "_wt_warn_count warns only above threshold" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Set very high threshold so no warning
  GWT_WORKTREE_WARN_THRESHOLD=100
  run _wt_warn_count
  assert_success
  assert_output ""
}

@test "_wt_warn_count warns when count exceeds threshold" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Set threshold to 0 so warning triggers
  GWT_WORKTREE_WARN_THRESHOLD=0
  run --separate-stderr _wt_warn_count
  assert_success
  assert [ -n "$stderr" ]
}

# --- _require_pkg ---

@test "_require_pkg passes when package.json exists" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  run _require_pkg
  assert_success
}

@test "_require_pkg fails when package.json missing" {
  cd "$TEST_TEMP_DIR"

  run _require_pkg
  assert_failure
}

# --- _read_input ---

@test "_read_input returns default when user presses Enter (bash)" {
  run bash -c '
    source "'"$PROJECT_ROOT"'/lib/utils.sh"
    echo "" | _read_input "Project [myproj]: " "myproj"
  '
  assert_success
  assert_output "myproj"
}

@test "_read_input returns custom value when user types input (bash)" {
  run bash -c '
    source "'"$PROJECT_ROOT"'/lib/utils.sh"
    echo "custom-name" | _read_input "Project [myproj]: " "myproj"
  '
  assert_success
  assert_output "custom-name"
}

@test "_read_input returns default for POSIX fallback when user presses Enter" {
  run bash -c '
    unset BASH_VERSION
    unset ZSH_VERSION
    source "'"$PROJECT_ROOT"'/lib/utils.sh"
    echo "" | _read_input "Project [myproj]: " "myproj" 2>/dev/null
  '
  assert_success
  assert_output "myproj"
}

@test "_read_input returns custom value for POSIX fallback" {
  run bash -c '
    unset BASH_VERSION
    unset ZSH_VERSION
    source "'"$PROJECT_ROOT"'/lib/utils.sh"
    echo "other-val" | _read_input "Project [myproj]: " "myproj" 2>/dev/null
  '
  assert_success
  assert_output "other-val"
}

@test "_read_input handles special characters in default (spaces, hyphens)" {
  run bash -c '
    source "'"$PROJECT_ROOT"'/lib/utils.sh"
    echo "" | _read_input "Project [my project-name]: " "my project-name"
  '
  assert_success
  assert_output "my project-name"
}

@test "_read_input handles special characters in user input" {
  run bash -c '
    source "'"$PROJECT_ROOT"'/lib/utils.sh"
    echo "my spaced-project" | _read_input "Project [def]: " "def"
  '
  assert_success
  assert_output "my spaced-project"
}
