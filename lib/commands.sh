# Command handlers

_cmd_new() {
  local branch="$1"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" || return 1
  [ -z "$branch" ] && { _err "Usage: wt -n <branch>"; return 1; }
  _branch_exists "$branch" && { _err "Branch exists"; return 1; }
  _wt_create "$branch" "$GWT_MAIN_REF" "$GWT_WORKTREES_DIR"
}

_cmd_dev() {
  local base="$1"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" || return 1
  [ -z "$base" ] && base=$(_current_branch)
  [ -z "$base" ] && { _err "No branch"; return 1; }
  local branch="${base}${GWT_DEV_SUFFIX}"
  _branch_exists "$branch" && { _err "Branch exists"; return 1; }
  _wt_create "$branch" "$GWT_DEV_REF" "$GWT_WORKTREES_DIR"
}

_cmd_switch() {
  local input="$1"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1
  local path; path=$(_wt_resolve "$input" "switch> ") || return 1
  _run_hook switched "$path" "$(_wt_branch "$path")" "" "$(_main_repo_root)"
}

_cmd_remove() {
  local input="$1" force="$2"
  _require_pkg && _repo_root >/dev/null || return 1
  local path; path=$(_wt_resolve "$input" "remove> ") || return 1
  [ "$PWD" = "$path" ] && cd "$(_repo_root)"

  if [ "$force" -ne 1 ]; then
    printf "Remove '%s'? [y/N] " "$path" >&2; read -r r
    case "$r" in y|Y) ;; *) return 1 ;; esac
  fi

  local branch; branch=$(_wt_branch "$path")
  git worktree remove ${force:+--force} "$path"
  [ -n "$branch" ] && _branch_exists "$branch" && git branch -D "$branch" 2>/dev/null && _info "Deleted $branch"
}

_cmd_open() {
  local branch="$1"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" || return 1

  # If no branch provided, show fzf picker
  if [ -z "$branch" ]; then
    branch=$(_branch_select "open> ") || return 1
    [ -z "$branch" ] && { _err "No branch selected"; return 1; }
  fi

  # Strip origin/ prefix if present
  branch="${branch#origin/}"

  # Check if branch exists (local or remote)
  if ! _branch_exists "$branch" && ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    _err "Branch '$branch' not found (checked local and origin)"
    return 1
  fi

  _wt_open "$branch" "$GWT_WORKTREES_DIR"
}

_cmd_lock() {
  local input="$1"
  _require_pkg && _repo_root >/dev/null || return 1
  local path; path=$(_wt_resolve "$input" "lock> ") || return 1
  git worktree lock "$path" && _info "Locked $path"
}

_cmd_unlock() {
  local input="$1"
  _require_pkg && _repo_root >/dev/null || return 1
  local path; path=$(_wt_resolve "$input" "unlock> ") || return 1
  git worktree unlock "$path" && _info "Unlocked $path"
}

_cmd_clear() {
  local unit="$1" num="$2" force="$3" dev_only="$4" main_only="$5"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1

  # Validate arguments
  if [ -z "$unit" ] || [ -z "$num" ]; then
    _err "Usage: wt -c <day|week|month> <number>"
    return 1
  fi

  case "$unit" in
    day|week|month) ;;
    *) _err "Invalid unit: $unit (use day, week, or month)"; return 1 ;;
  esac

  if ! [ "$num" -gt 0 ] 2>/dev/null; then
    _err "Invalid number: $num (must be positive integer)"
    return 1
  fi

  # Check for mutually exclusive flags
  if [ "$dev_only" -eq 1 ] && [ "$main_only" -eq 1 ]; then
    _err "--dev-only and --main-only are mutually exclusive"
    return 1
  fi

  # Calculate cutoff timestamp
  local cutoff
  cutoff=$(_calc_cutoff "$unit" "$num")
  if [ -z "$cutoff" ]; then
    _err "Failed to calculate cutoff date"
    return 1
  fi

  local main_root
  main_root=$(_main_repo_root) || return 1

  _init_colors

  # Collect worktrees to delete (newline-delimited strings)
  local output worktree branch locked wt_age
  local to_delete="" locked_skipped="" to_delete_count=0
  output=$(git worktree list --porcelain)

  worktree="" branch="" locked=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      worktree\ *)
        worktree="${line#worktree }"
        branch=""
        locked=""
        ;;
      branch\ *)
        branch="${line#branch refs/heads/}"
        ;;
      detached)
        branch="(detached)"
        ;;
      locked*)
        locked="1"
        ;;
      "")
        if [ -n "$worktree" ]; then
          # Skip main repository
          if [ "$worktree" = "$main_root" ]; then
            worktree=""
            continue
          fi

          # Apply dev/main filter
          if [ "$dev_only" -eq 1 ]; then
            case "$branch" in
              *"$GWT_DEV_SUFFIX") ;;
              *) worktree=""; continue ;;
            esac
          elif [ "$main_only" -eq 1 ]; then
            case "$branch" in
              *"$GWT_DEV_SUFFIX") worktree=""; continue ;;
            esac
          fi

          # Check age
          wt_age=$(_wt_age "$worktree")
          if [ -n "$wt_age" ] && [ "$wt_age" -lt "$cutoff" ]; then
            if [ -n "$locked" ]; then
              locked_skipped="${locked_skipped}${worktree}|${branch}
"
            else
              to_delete="${to_delete}${worktree}|${branch}|${wt_age}
"
              to_delete_count=$((to_delete_count + 1))
            fi
          fi

          worktree=""
        fi
        ;;
    esac
  done <<EOF
$output

EOF

  # Warn about locked worktrees
  if [ -n "$locked_skipped" ]; then
    echo "${C_YELLOW}Skipping locked worktrees:${C_RESET}" >&2
    echo "$locked_skipped" | while IFS= read -r item; do
      [ -z "$item" ] && continue
      local path="${item%%|*}"
      local br="${item#*|}"
      echo "  ${C_DIM}$path${C_RESET} ($br) ${C_RED}[locked]${C_RESET}" >&2
    done
    echo "" >&2
  fi

  # Check if anything to delete
  if [ "$to_delete_count" -eq 0 ]; then
    _info "No worktrees to clear"
    return 0
  fi

  # Show list of worktrees to delete
  echo "Worktrees to remove (older than $num $unit(s)):"
  echo "$to_delete" | while IFS= read -r item; do
    [ -z "$item" ] && continue
    local path="${item%%|*}"
    local rest="${item#*|}"
    local br="${rest%%|*}"
    local ts="${rest#*|}"
    echo "  $path ($br) - $(_age_display "$ts")"
  done
  echo ""

  # Confirmation prompt (unless -f)
  if [ "$force" -ne 1 ]; then
    printf "Remove %d worktree(s)? [y/N] " "$to_delete_count" >&2
    read -r r
    case "$r" in
      y|Y) ;;
      *) _info "Aborted"; return 1 ;;
    esac
  fi

  # Delete worktrees
  local deleted=0
  echo "$to_delete" | while IFS= read -r item; do
    [ -z "$item" ] && continue
    local path="${item%%|*}"
    local rest="${item#*|}"
    local br="${rest%%|*}"

    # Change directory if we're in the worktree being removed
    [ "$PWD" = "$path" ] && cd "$main_root"

    if git worktree remove "$path" 2>/dev/null; then
      _info "Removed $path"
      if [ -n "$br" ] && [ "$br" != "(detached)" ] && _branch_exists "$br"; then
        git branch -D "$br" 2>/dev/null && _info "Deleted branch $br"
      fi
    else
      _err "Failed to remove $path"
    fi
  done

  _info "Cleared worktrees"
}

_cmd_list() {
  local main_root
  main_root=$(_main_repo_root) || return 1

  _init_colors

  local worktree="" branch="" locked="" is_main=""
  local count=0
  local output=""
  output=$(git worktree list --porcelain)

  # Parse porcelain output line by line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      worktree\ *)
        worktree="${line#worktree }"
        branch=""
        locked=""
        is_main=""
        ;;
      branch\ *)
        branch="${line#branch refs/heads/}"
        ;;
      detached)
        branch="(detached)"
        ;;
      locked*)
        locked="${line#locked}"
        [ -z "$locked" ] && locked="yes"
        ;;
      "")
        # End of record, print it
        if [ -n "$worktree" ]; then
          count=$((count + 1))

          # Check if this is the main worktree
          [ "$worktree" = "$main_root" ] && is_main="1"

          # Format lock indicator
          local lock_indicator=""
          if [ -n "$locked" ]; then
            lock_indicator="${C_RED}[locked]${C_RESET}"
          else
            lock_indicator="${C_GREEN}[active]${C_RESET}"
          fi

          # Format branch name
          local branch_display="$branch"
          if [ -n "$is_main" ]; then
            branch_display="${C_YELLOW}${branch}${C_RESET} ${C_DIM}(main)${C_RESET}"
          fi

          # Print formatted line
          printf "%-50s %s %s\n" "$worktree" "$branch_display" "$lock_indicator"

          worktree=""
        fi
        ;;
    esac
  done <<EOF
$output

EOF

  # Handle case with no worktrees (only main)
  if [ "$count" -eq 0 ]; then
    _info "No worktrees found"
  fi
}

_cmd_log() {
  local feature="$1" reflog="$2" since="$3" author="$4"
  _require_pkg && _repo_root >/dev/null && _config_load || return 1
  [ -z "$feature" ] && feature=$(_current_branch)
  [ "$reflog" -eq 1 ] && { git reflog --date=relative | head -50; return; }
  local args=""; [ -n "$since" ] && args="--since=$since"; [ -n "$author" ] && args="$args --author=$author"
  git log --oneline --graph --cherry --no-merges $args "${GWT_MAIN_REF}..${feature}"
}

# Backup hook if exists and differs from new content
# Usage: _backup_hook <hook_path> <new_content>
# Returns: 0 if backup was made, 1 if no backup needed
_backup_hook() {
  local hook_path="$1" new_content="$2"
  [ ! -f "$hook_path" ] && return 1

  local existing_content
  existing_content=$(cat "$hook_path")
  [ "$existing_content" = "$new_content" ] && return 1

  local backup_path="${hook_path}_old"
  mv "$hook_path" "$backup_path"
  _info "Backed up existing hook: ${hook_path##*/} -> ${backup_path##*/}"
  return 0
}

_cmd_init() {
  _require_pkg && _repo_root >/dev/null && _require jq || return 1
  local root; root=$(_main_repo_root) || return 1
  local cfg="$root/.worktrees/config.json"

  local name main_ref warn_threshold
  name=$(_project_name); main_ref=$(_main_branch)
  local wt_dir="${root%/*}/${name}_worktrees"
  warn_threshold=20

  printf "Project [%s]: " "$name" >&2; read -r r; [ -n "$r" ] && name="$r"
  printf "Worktrees dir [%s]: " "$wt_dir" >&2; read -r r; [ -n "$r" ] && wt_dir="$r"
  printf "Main branch [%s]: " "$main_ref" >&2; read -r r; [ -n "$r" ] && main_ref="$r"
  printf "Worktree warning threshold [%s]: " "$warn_threshold" >&2; read -r r; [ -n "$r" ] && warn_threshold="$r"

  main_ref=$(_normalize_ref "$main_ref")

  mkdir -p "$root/.worktrees/hooks"

  # Default hook contents
  local created_hook='#!/usr/bin/env bash
cd "$1" || exit 1'
  local switched_hook='#!/usr/bin/env bash
cd "$1" || exit 1'

  # Backup existing hooks if they differ
  _backup_hook "$root/.worktrees/hooks/created.sh" "$created_hook"
  _backup_hook "$root/.worktrees/hooks/switched.sh" "$switched_hook"

  # Write new hooks
  echo "$created_hook" > "$root/.worktrees/hooks/created.sh"
  echo "$switched_hook" > "$root/.worktrees/hooks/switched.sh"
  chmod +x "$root/.worktrees/hooks"/*.sh

  cat > "$cfg" <<JSON
{
  "projectName": "$name",
  "worktreesDir": "$wt_dir",
  "mainBranch": "$main_ref",
  "devBranch": "origin/release-next",
  "devSuffix": "_RN",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh",
  "worktreeWarningThreshold": $warn_threshold
}
JSON
  _info "Created $cfg"
}

_cmd_help() {
  cat <<'HELP'
wt - Git Worktree Helpers

Usage: wt [flags] [args]

Commands:
  -n, --new <branch>     Create worktree from main
  -n -d [name]           Create worktree from dev branch
  -s, --switch [branch]  Switch worktree (fzf if no arg)
  -r, --remove [branch]  Remove worktree and branch
  -o, --open [branch]    Open existing branch as worktree (fzf if no arg)
  -l, --list             List worktrees
  -c, --clear <unit> <n> Clear worktrees older than n units (day/week/month)
  -L, --lock [branch]    Lock worktree
  -U, --unlock [branch]  Unlock worktree
  --init                 Initialize config
  --log [branch]         Show commits vs main
  -h, --help             This help

Flags:
  -f, --force            Force operation
  -d, --dev              Use dev branch as base
  --dev-only             Filter to dev-based worktrees only (with -c)
  --main-only            Filter to main-based worktrees only (with -c)
  --reflog               Show reflog (with --log)
HELP
}
