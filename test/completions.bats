#!/usr/bin/env bats
# Tests for bash completion function in completions/wt.bash

setup() {
  load 'test_helper'
  setup
  # Source the bash completion file
  source "$PROJECT_ROOT/completions/wt.bash"
}

teardown() {
  teardown
}

# Helper: simulate bash completion at a given cursor position
# Usage: _simulate_completion "wt" "-s" ""
# The last argument is what the user is currently typing (cur)
_simulate_completion() {
  COMP_WORDS=("$@")
  COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
  COMPREPLY=()
  _wt_bash_complete
}

# --- Flag completion ---

@test "completion: 'wt <Tab>' suggests flags" {
  _simulate_completion "wt" ""
  # Should include command flags
  [[ " ${COMPREPLY[*]} " == *" -n "* ]]
  [[ " ${COMPREPLY[*]} " == *" --new "* ]]
  [[ " ${COMPREPLY[*]} " == *" -s "* ]]
  [[ " ${COMPREPLY[*]} " == *" --switch "* ]]
  [[ " ${COMPREPLY[*]} " == *" -r "* ]]
  [[ " ${COMPREPLY[*]} " == *" -o "* ]]
  [[ " ${COMPREPLY[*]} " == *" -l "* ]]
  [[ " ${COMPREPLY[*]} " == *" -c "* ]]
  [[ " ${COMPREPLY[*]} " == *" -L "* ]]
  [[ " ${COMPREPLY[*]} " == *" -U "* ]]
  [[ " ${COMPREPLY[*]} " == *" -h "* ]]
  [[ " ${COMPREPLY[*]} " == *" -v "* ]]
}

@test "completion: 'wt --' suggests long flags" {
  _simulate_completion "wt" "--"
  [[ " ${COMPREPLY[*]} " == *" --new "* ]]
  [[ " ${COMPREPLY[*]} " == *" --switch "* ]]
  [[ " ${COMPREPLY[*]} " == *" --remove "* ]]
  [[ " ${COMPREPLY[*]} " == *" --list "* ]]
  [[ " ${COMPREPLY[*]} " == *" --clear "* ]]
  [[ " ${COMPREPLY[*]} " == *" --init "* ]]
  [[ " ${COMPREPLY[*]} " == *" --log "* ]]
  [[ " ${COMPREPLY[*]} " == *" --rename "* ]]
  [[ " ${COMPREPLY[*]} " == *" --help "* ]]
  [[ " ${COMPREPLY[*]} " == *" --version "* ]]
  [[ " ${COMPREPLY[*]} " == *" --force "* ]]
  [[ " ${COMPREPLY[*]} " == *" --from "* ]]
  [[ " ${COMPREPLY[*]} " == *" --merged "* ]]
  [[ " ${COMPREPLY[*]} " == *" --pattern "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dry-run "* ]]
}

@test "completion: modifier flags included in default completion" {
  _simulate_completion "wt" ""
  [[ " ${COMPREPLY[*]} " == *" -f "* ]]
  [[ " ${COMPREPLY[*]} " == *" --force "* ]]
  [[ " ${COMPREPLY[*]} " == *" -d "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dev "* ]]
  [[ " ${COMPREPLY[*]} " == *" -b "* ]]
  [[ " ${COMPREPLY[*]} " == *" --from "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dev-only "* ]]
  [[ " ${COMPREPLY[*]} " == *" --main-only "* ]]
  [[ " ${COMPREPLY[*]} " == *" --reflog "* ]]
  [[ " ${COMPREPLY[*]} " == *" --merged "* ]]
  [[ " ${COMPREPLY[*]} " == *" --pattern "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dry-run "* ]]
}

# --- Worktree branch completion ---

@test "completion: 'wt -s <Tab>' completes with worktree branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"

  # Create a worktree so there is a branch to complete
  git worktree add "$TEST_TEMP_DIR/test-project_worktrees/feat-test" -b feat-test >/dev/null 2>&1

  _simulate_completion "wt" "-s" ""
  [[ " ${COMPREPLY[*]} " == *"feat-test"* ]]
}

@test "completion: 'wt -r <Tab>' completes with worktree branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git worktree add "$TEST_TEMP_DIR/test-project_worktrees/to-remove" -b to-remove >/dev/null 2>&1

  _simulate_completion "wt" "-r" ""
  [[ " ${COMPREPLY[*]} " == *"to-remove"* ]]
}

@test "completion: 'wt --switch <Tab>' completes with worktree branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git worktree add "$TEST_TEMP_DIR/test-project_worktrees/wt-branch" -b wt-branch >/dev/null 2>&1

  _simulate_completion "wt" "--switch" ""
  [[ " ${COMPREPLY[*]} " == *"wt-branch"* ]]
}

@test "completion: 'wt -L <Tab>' completes with worktree branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git worktree add "$TEST_TEMP_DIR/test-project_worktrees/lock-me" -b lock-me >/dev/null 2>&1

  _simulate_completion "wt" "-L" ""
  [[ " ${COMPREPLY[*]} " == *"lock-me"* ]]
}

@test "completion: 'wt -U <Tab>' completes with worktree branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git worktree add "$TEST_TEMP_DIR/test-project_worktrees/unlock-me" -b unlock-me >/dev/null 2>&1

  _simulate_completion "wt" "-U" ""
  [[ " ${COMPREPLY[*]} " == *"unlock-me"* ]]
}

# --- Git branch completion ---

@test "completion: 'wt -o <Tab>' completes with git branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Create a local branch
  git branch feature-open >/dev/null 2>&1

  _simulate_completion "wt" "-o" ""
  [[ " ${COMPREPLY[*]} " == *"feature-open"* ]]
}

@test "completion: 'wt -n mybranch -b <Tab>' completes with git branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch base-branch >/dev/null 2>&1

  _simulate_completion "wt" "-n" "mybranch" "-b" ""
  [[ " ${COMPREPLY[*]} " == *"base-branch"* ]]
}

@test "completion: 'wt --open <Tab>' completes with git branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch open-branch >/dev/null 2>&1

  _simulate_completion "wt" "--open" ""
  [[ " ${COMPREPLY[*]} " == *"open-branch"* ]]
}

# --- Local branch completion ---

@test "completion: 'wt --log <Tab>' completes with local branches" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch log-branch >/dev/null 2>&1

  _simulate_completion "wt" "--log" ""
  [[ " ${COMPREPLY[*]} " == *"log-branch"* ]]
}

# --- No completion ---

@test "completion: 'wt -n <Tab>' does NOT complete branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch existing-branch >/dev/null 2>&1

  _simulate_completion "wt" "-n" ""
  [ ${#COMPREPLY[@]} -eq 0 ]
}

@test "completion: 'wt --rename <Tab>' does NOT complete branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch existing-branch >/dev/null 2>&1

  _simulate_completion "wt" "--rename" ""
  [ ${#COMPREPLY[@]} -eq 0 ]
}

@test "completion: 'wt --pattern <Tab>' does NOT complete" {
  _simulate_completion "wt" "-c" "14" "--pattern" ""
  [ ${#COMPREPLY[@]} -eq 0 ]
}

@test "completion: 'wt --since <Tab>' does NOT complete" {
  _simulate_completion "wt" "--log" "main" "--since" ""
  [ ${#COMPREPLY[@]} -eq 0 ]
}

@test "completion: 'wt --author <Tab>' does NOT complete" {
  _simulate_completion "wt" "--log" "main" "--author" ""
  [ ${#COMPREPLY[@]} -eq 0 ]
}

# --- Clear context ---

@test "completion: 'wt -c 14 --<Tab>' completes with modifier flags" {
  _simulate_completion "wt" "-c" "14" "--"
  [[ " ${COMPREPLY[*]} " == *" --merged "* ]]
  [[ " ${COMPREPLY[*]} " == *" --pattern "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dry-run "* ]]
  [[ " ${COMPREPLY[*]} " == *" --force "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dev-only "* ]]
  [[ " ${COMPREPLY[*]} " == *" --main-only "* ]]
}

@test "completion: 'wt --clear --<Tab>' completes with modifier flags" {
  _simulate_completion "wt" "--clear" "--"
  [[ " ${COMPREPLY[*]} " == *" --merged "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dry-run "* ]]
}

# --- Non-git directory ---

@test "completion: no errors outside a git repo" {
  cd "$TEST_TEMP_DIR"

  # Should not fail, just return no branch completions
  run bash -c '
    source "'"$PROJECT_ROOT"'/completions/wt.bash"
    COMP_WORDS=(wt -s "")
    COMP_CWORD=2
    COMPREPLY=()
    _wt_bash_complete
    echo "ok"
  '
  assert_success
  assert_output "ok"
}

@test "completion: flag completion works outside a git repo" {
  cd "$TEST_TEMP_DIR"

  _simulate_completion "wt" "--"
  # Should still complete flags even outside a git repo
  [[ " ${COMPREPLY[*]} " == *" --help "* ]]
  [[ " ${COMPREPLY[*]} " == *" --version "* ]]
}

# --- Partial match ---

@test "completion: partial flag match filters correctly" {
  _simulate_completion "wt" "--sw"
  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "--switch" ]
}

@test "completion: partial flag --re matches --remove and --rename and --reflog" {
  _simulate_completion "wt" "--re"
  [[ " ${COMPREPLY[*]} " == *"--remove"* ]]
  [[ " ${COMPREPLY[*]} " == *"--rename"* ]]
  [[ " ${COMPREPLY[*]} " == *"--reflog"* ]]
}
