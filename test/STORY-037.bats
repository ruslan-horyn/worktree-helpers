#!/usr/bin/env bats
# STORY-037: Completions — show example usage hint when nothing to suggest
#
# These tests verify that bash completions show a descriptive placeholder hint
# (e.g. '<branch>', '<ref>') instead of returning nothing for free-form arguments.
#
# Tests MUST fail before implementation — no implementation exists yet. Expected.

setup() {
  load 'test_helper'
  setup
  source "$PROJECT_ROOT/completions/wt.bash"
}

teardown() {
  teardown
}

# Helper: simulate bash completion at a given cursor position
# Usage: _simulate_completion "wt" "-n" ""
# The last argument is what the user is currently typing (cur)
_simulate_completion() {
  COMP_WORDS=("$@")
  COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
  COMPREPLY=()
  _wt_bash_complete
}

# =============================================================================
# AC-1: wt -n <TAB> → COMPREPLY=('<branch>') exactly
# =============================================================================

@test "STORY-037 AC-1: 'wt -n <Tab>' returns empty COMPREPLY (no hint, no branch names)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Ensure there are real branches that must NOT appear
  git branch existing-branch >/dev/null 2>&1

  _simulate_completion "wt" "-n" ""

  # Must return no completions — user types branch name freely
  [ ${#COMPREPLY[@]} -eq 0 ]
}

# =============================================================================
# AC-2: wt --new <TAB> → COMPREPLY=('<branch>') exactly
# =============================================================================

@test "STORY-037 AC-2: 'wt --new <Tab>' returns empty COMPREPLY (no hint, no branch names)" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch some-branch >/dev/null 2>&1

  _simulate_completion "wt" "--new" ""

  [ ${#COMPREPLY[@]} -eq 0 ]
}

# =============================================================================
# AC-3: wt --from <TAB> → COMPREPLY=('<ref>') exactly
# =============================================================================

@test "STORY-037 AC-3: 'wt --from <Tab>' sets COMPREPLY to exactly ('<ref>')" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch base-branch >/dev/null 2>&1

  _simulate_completion "wt" "-n" "my-feat" "--from" ""

  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "<ref>" ]
}

# =============================================================================
# AC-4: wt -b <TAB> → COMPREPLY=('<ref>') exactly
# =============================================================================

@test "STORY-037 AC-4: 'wt -b <Tab>' sets COMPREPLY to exactly ('<ref>')" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch another-base >/dev/null 2>&1

  _simulate_completion "wt" "-n" "my-feat" "-b" ""

  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "<ref>" ]
}

# =============================================================================
# AC-5: wt --rename <TAB> → COMPREPLY=('<new-branch>') exactly
# =============================================================================

@test "STORY-037 AC-5: 'wt --rename <Tab>' sets COMPREPLY to exactly ('<new-branch>')" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch rename-candidate >/dev/null 2>&1

  _simulate_completion "wt" "--rename" ""

  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "<new-branch>" ]
}

# =============================================================================
# AC-6: wt --pattern <TAB> → COMPREPLY=('<pattern>') exactly
# =============================================================================

@test "STORY-037 AC-6: 'wt --pattern <Tab>' sets COMPREPLY to exactly ('<pattern>')" {
  _simulate_completion "wt" "-c" "14" "--pattern" ""

  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "<pattern>" ]
}

# =============================================================================
# AC-7: wt --since <TAB> → COMPREPLY=('<date>') exactly
# =============================================================================

@test "STORY-037 AC-7: 'wt --since <Tab>' sets COMPREPLY to exactly ('<date>')" {
  _simulate_completion "wt" "--log" "main" "--since" ""

  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "<date>" ]
}

# =============================================================================
# AC-8: wt --author <TAB> → COMPREPLY=('<author>') exactly
# =============================================================================

@test "STORY-037 AC-8: 'wt --author <Tab>' sets COMPREPLY to exactly ('<author>')" {
  _simulate_completion "wt" "--log" "main" "--author" ""

  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "<author>" ]
}

# =============================================================================
# AC-9: Dynamic completions for -s/--switch unaffected
# =============================================================================

@test "STORY-037 AC-9: 'wt -s <Tab>' still completes with real worktree branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  # Create a worktree so there is a branch to complete
  git worktree add "$TEST_TEMP_DIR/test-project_worktrees/feat-ac9" -b feat-ac9 >/dev/null 2>&1

  _simulate_completion "wt" "-s" ""

  # Should include the real worktree branch — NOT a placeholder
  [[ " ${COMPREPLY[*]} " == *"feat-ac9"* ]]
  # Must NOT contain placeholder
  [[ " ${COMPREPLY[*]} " != *"<branch>"* ]]
}

@test "STORY-037 AC-9b: 'wt --switch <Tab>' still completes with real worktree branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git worktree add "$TEST_TEMP_DIR/test-project_worktrees/feat-ac9b" -b feat-ac9b >/dev/null 2>&1

  _simulate_completion "wt" "--switch" ""

  [[ " ${COMPREPLY[*]} " == *"feat-ac9b"* ]]
  [[ " ${COMPREPLY[*]} " != *"<branch>"* ]]
}

# =============================================================================
# AC-10: Dynamic completions for -o/--open unaffected
# =============================================================================

@test "STORY-037 AC-10: 'wt -o <Tab>' still completes with real git branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch feature-ac10 >/dev/null 2>&1

  _simulate_completion "wt" "-o" ""

  [[ " ${COMPREPLY[*]} " == *"feature-ac10"* ]]
  # Must NOT contain placeholder
  [[ " ${COMPREPLY[*]} " != *"<ref>"* ]]
}

@test "STORY-037 AC-10b: 'wt --open <Tab>' still completes with real git branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch feature-ac10b >/dev/null 2>&1

  _simulate_completion "wt" "--open" ""

  [[ " ${COMPREPLY[*]} " == *"feature-ac10b"* ]]
  [[ " ${COMPREPLY[*]} " != *"<ref>"* ]]
}

# =============================================================================
# AC-11: Default flag completion (wt <TAB>) has no regression
# =============================================================================

@test "STORY-037 AC-11: 'wt <Tab>' still suggests the full set of command flags" {
  _simulate_completion "wt" ""

  [[ " ${COMPREPLY[*]} " == *" -n "* ]]
  [[ " ${COMPREPLY[*]} " == *" --new "* ]]
  [[ " ${COMPREPLY[*]} " == *" -s "* ]]
  [[ " ${COMPREPLY[*]} " == *" --switch "* ]]
  [[ " ${COMPREPLY[*]} " == *" -r "* ]]
  [[ " ${COMPREPLY[*]} " == *" --remove "* ]]
  [[ " ${COMPREPLY[*]} " == *" -l "* ]]
  [[ " ${COMPREPLY[*]} " == *" --list "* ]]
  [[ " ${COMPREPLY[*]} " == *" --rename "* ]]
  [[ " ${COMPREPLY[*]} " == *" --from "* ]]
  [[ " ${COMPREPLY[*]} " == *" -h "* ]]
  [[ " ${COMPREPLY[*]} " == *" --help "* ]]
}

# =============================================================================
# AC-12: zsh completion file contains _message calls for free-form args
# =============================================================================

@test "STORY-037 AC-12: completions/_wt contains _describe for -n/--new context" {
  run grep -c '_describe' "$PROJECT_ROOT/completions/_wt"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "STORY-037 AC-12b: completions/_wt hint_branch case returns no completions (no auto-insert)" {
  run grep -A1 'hint_branch' "$PROJECT_ROOT/completions/_wt"
  [ "$status" -eq 0 ]
  # hint_branch case must NOT call _describe, compadd, or set any completion
  [[ "$output" != *"_describe"* ]]
  [[ "$output" != *"compadd"* ]]
}

@test "STORY-037 AC-12c: completions/_wt contains _describe hint for ref context" {
  run grep '_describe' "$PROJECT_ROOT/completions/_wt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ref"* ]]
}

# =============================================================================
# AC-13: shellcheck passes on completions/_wt
# =============================================================================

@test "STORY-037 AC-13: shellcheck passes on completions/_wt" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  run shellcheck "$PROJECT_ROOT/completions/_wt"
  [ "$status" -eq 0 ]
}

# =============================================================================
# AC-14: shellcheck passes on completions/wt.bash
# =============================================================================

@test "STORY-037 AC-14: shellcheck passes on completions/wt.bash" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  run shellcheck "$PROJECT_ROOT/completions/wt.bash"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Edge cases
# =============================================================================

@test "STORY-037 edge: 'wt -n <Tab>' returns nothing even when git branches exist" {
  # Real git branches must NOT appear — user is naming a NEW branch
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch edge-branch-1 >/dev/null 2>&1
  git branch edge-branch-2 >/dev/null 2>&1

  _simulate_completion "wt" "-n" ""

  # No completions at all — no branches, no placeholders
  [ ${#COMPREPLY[@]} -eq 0 ]
}

@test "STORY-037 edge: partial typing after -n returns nothing" {
  # User typed 'wt -n feat' and pressed TAB — no completions offered
  _simulate_completion "wt" "-n" "feat"

  # No real branch names, no placeholders
  [[ " ${COMPREPLY[*]} " != *"main"* ]]
  [ ${#COMPREPLY[@]} -eq 0 ]
}

@test "STORY-037 edge: 'wt --rename' placeholder does not include real branch names" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch rename-source >/dev/null 2>&1

  _simulate_completion "wt" "--rename" ""

  # Real branch 'rename-source' must NOT appear
  [[ " ${COMPREPLY[*]} " != *"rename-source"* ]]
  # Placeholder must be present
  [ ${#COMPREPLY[@]} -eq 1 ]
  [ "${COMPREPLY[0]}" = "<new-branch>" ]
}

@test "STORY-037 edge: 'wt -n <Tab>' works outside a git repo (no crash, no completions)" {
  cd "$TEST_TEMP_DIR"

  run bash -c '
    source "'"$PROJECT_ROOT"'/completions/wt.bash"
    COMP_WORDS=(wt -n "")
    COMP_CWORD=2
    COMPREPLY=()
    _wt_bash_complete
    echo "count:${#COMPREPLY[@]}"
  '
  assert_success
  [[ "$output" == *"count:0"* ]]
}

@test "STORY-037 edge: hint works outside a git repo for --from flag (no crash)" {
  cd "$TEST_TEMP_DIR"

  run bash -c '
    source "'"$PROJECT_ROOT"'/completions/wt.bash"
    COMP_WORDS=(wt --from "")
    COMP_CWORD=2
    COMPREPLY=()
    _wt_bash_complete
    echo "count:${#COMPREPLY[@]}"
    echo "value:${COMPREPLY[0]}"
  '
  assert_success
  [[ "$output" == *"count:1"* ]]
  [[ "$output" == *"value:<ref>"* ]]
}

@test "STORY-037 edge: --log dynamic completion still works after hint changes" {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"

  git branch log-topic >/dev/null 2>&1

  _simulate_completion "wt" "--log" ""

  [[ " ${COMPREPLY[*]} " == *"log-topic"* ]]
}

@test "STORY-037 edge: clear context modifier flags unaffected by hint changes" {
  _simulate_completion "wt" "-c" "14" "--"

  [[ " ${COMPREPLY[*]} " == *" --merged "* ]]
  [[ " ${COMPREPLY[*]} " == *" --pattern "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dry-run "* ]]
}
