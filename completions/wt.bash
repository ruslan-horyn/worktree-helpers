#!/usr/bin/env bash
# Bash completion for wt (worktree-helpers)
# shellcheck disable=SC2207

_wt_bash_complete() {
  local cur prev words cword

  # Use _init_completion if available (bash-completion package),
  # otherwise set variables manually
  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion || return
  else
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  fi

  local all_flags="-n --new -s --switch -r --remove -o --open \
    -l --list -c --clear -L --lock -U --unlock --init --log \
    --rename --uninstall -v --version -h --help \
    -f --force -d --dev -b --from --dev-only --main-only \
    --reflog --since --author --merged --pattern --dry-run"

  # Find the action flag in previous words
  local action=""
  local i
  for ((i = 1; i < cword; i++)); do
    case "${words[i]}" in
      -s|--switch|-r|--remove|-L|--lock|-U|--unlock)
        action="worktree_branch" ;;
      -o|--open)
        action="git_branch" ;;
      -b|--from)
        action="hint_ref" ;;
      --log)
        action="local_branch" ;;
      -n|--new)
        action="hint_branch" ;;
      --rename)
        action="hint_new_branch" ;;
      -c|--clear)
        action="clear_context" ;;
      --pattern)
        action="hint_pattern" ;;
      --since)
        action="hint_date" ;;
      --author)
        action="hint_author" ;;
    esac
  done

  # The immediately previous word takes priority for value arguments
  case "$prev" in
    -s|--switch|-r|--remove|-L|--lock|-U|--unlock)
      action="worktree_branch" ;;
    -o|--open)
      action="git_branch" ;;
    -b|--from)
      action="hint_ref" ;;
    --log)
      action="local_branch" ;;
    -n|--new)
      action="hint_branch" ;;
    --rename)
      action="hint_new_branch" ;;
    --pattern)
      action="hint_pattern" ;;
    --since)
      action="hint_date" ;;
    --author)
      action="hint_author" ;;
  esac

  case "$action" in
    worktree_branch)
      local wt_branches
      wt_branches=$(git worktree list --porcelain 2>/dev/null | \
        sed -n 's/^branch refs\/heads\///p')
      COMPREPLY=($(compgen -W "$wt_branches" -- "$cur"))
      ;;
    git_branch)
      local branches
      branches=$(git for-each-ref --format='%(refname:short)' \
        refs/heads refs/remotes/origin 2>/dev/null | \
        sed 's|^origin/||' | sort -u)
      COMPREPLY=($(compgen -W "$branches" -- "$cur"))
      ;;
    local_branch)
      local branches
      branches=$(git for-each-ref --format='%(refname:short)' \
        refs/heads 2>/dev/null)
      COMPREPLY=($(compgen -W "$branches" -- "$cur"))
      ;;
    clear_context)
      COMPREPLY=($(compgen -W "$all_flags" -- "$cur"))
      ;;
    hint_branch)
      COMPREPLY=()
      ;;
    hint_ref)
      COMPREPLY=( '<ref>' )
      ;;
    hint_new_branch)
      COMPREPLY=( '<new-branch>' )
      ;;
    hint_pattern)
      COMPREPLY=( '<pattern>' )
      ;;
    hint_date)
      COMPREPLY=( '<date>' )
      ;;
    hint_author)
      COMPREPLY=( '<author>' )
      ;;
    *)
      COMPREPLY=($(compgen -W "$all_flags" -- "$cur"))
      ;;
  esac
}

complete -F _wt_bash_complete wt
