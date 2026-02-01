# Git Worktree Helpers - wt
#
# Usage: wt [flags] [arguments]
#
# Operations:
#   wt -n, --new <branch>        Create worktree from main branch
#   wt -n -d, --new --dev [name] Create worktree from dev branch (with suffix)
#   wt -s, --switch [branch]     Switch to worktree (fzf picker if no arg)
#   wt -r, --remove [branch]     Remove worktree and delete local branch
#   wt -o, --open [branch]       Open existing branch as worktree
#   wt -L, --lock [branch]       Lock worktree (prevents pruning)
#   wt -U, --unlock [branch]     Unlock worktree
#   wt -l, --list                List all worktrees
#   wt --init                    Initialize .worktrees/config.json
#   wt --log [branch]            Show feature log vs main
#   wt -h, --help                Show this help
#
# Modifiers:
#   -f, --force                  Force operation (skip confirmation)
#   -d, --dev                    Use dev branch as base (with -n)
#   --reflog                     Show reflog instead (with --log)
#
# Config: .worktrees/config.json
# Hooks: .worktrees/hooks/created.sh, .worktrees/hooks/switched.sh

# =============================================================================
# UTILITIES
# =============================================================================

_err() { echo "$*" >&2; }
_info() { echo "$*"; }
_debug() {
  case "${GWT_DEBUG:-0}" in
    1|true|TRUE|yes|YES) echo "[gwt][debug] $*" ;;
  esac
}

export GWT_DEBUG=0

_require() {
  command -v "$1" >/dev/null 2>&1 || { _err "$1 is required. Install $1 and retry."; return 1; }
}

_main_repo_root() {
  local common_dir
  common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
  (cd "$common_dir/.." 2>/dev/null && pwd -P)
}

_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || { _err "Not a git repo"; return 1; }
}

_require_node_project() {
  [ -f package.json ] || { _err "package.json not found in current directory."; return 1; }
}

_project_name() {
  if command -v jq >/dev/null 2>&1 && [ -f package.json ]; then
    local name
    name=$(jq -r '.name // empty' package.json)
    if [ -n "$name" ] && [ "$name" != "null" ]; then
      case "$name" in @*/*) name="${name#@*/}" ;; esac
      name=${name##*/}
      name=${name//\tk/}
      name=${name// /-}
      echo "$name"
      return 0
    fi
  fi
  basename "$PWD"
}

_main_branch() {
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    echo "origin/main"; return 0
  fi
  if git show-ref --verify --quiet refs/remotes/origin/master; then
    echo "origin/master"; return 0
  fi
  local upstream_ref
  upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || true
  [ -n "$upstream_ref" ] && echo "$upstream_ref"
}

_normalize_ref() {
  local ref="$1"
  [ -z "$ref" ] && return 0
  local remote
  for remote in $(git remote 2>/dev/null); do
    case "$ref" in ${remote}/*) echo "$ref"; return 0 ;; esac
  done
  echo "origin/$ref"
}

_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null; }
_branch_exists() { git show-ref --verify --quiet "refs/heads/$1"; }

# =============================================================================
# CONFIGURATION
# =============================================================================

_config_load() {
  local main_repo_root config_file
  main_repo_root=$(_main_repo_root) || return 1
  config_file="$main_repo_root/.worktrees/config.json"

  if [ ! -f "$config_file" ]; then
    _err ".worktrees/config.json not found. Run 'wt --init' to create it."
    return 1
  fi

  _require jq || return 1

  # Parse config
  local project_name worktrees_dir main_ref dev_ref dev_suffix create_hook switch_hook
  project_name=$(jq -r '.projectName // empty' "$config_file")
  worktrees_dir=$(jq -r '.worktreesDir // empty' "$config_file")
  main_ref=$(jq -r '.mainBranch // empty' "$config_file")
  dev_ref=$(jq -r '.devBranch // empty' "$config_file")
  dev_suffix=$(jq -r '.devSuffix // empty' "$config_file")
  create_hook=$(jq -r '.openCmd // empty' "$config_file")
  switch_hook=$(jq -r '.switchCmd // empty' "$config_file")

  # Apply defaults
  [ -z "$project_name" ] && project_name=$(_project_name)
  [ -z "$main_ref" ] && main_ref=$(_main_branch)
  [ -z "$dev_ref" ] && dev_ref="origin/release-next"
  [ -z "$dev_suffix" ] && dev_suffix="_RN"
  [ -z "$create_hook" ] && create_hook=".worktrees/hooks/created.sh"
  [ -z "$switch_hook" ] && switch_hook=".worktrees/hooks/switched.sh"

  # Resolve hook paths
  case "$create_hook" in /*) ;; *) create_hook="$main_repo_root/$create_hook" ;; esac
  case "$switch_hook" in /*) ;; *) switch_hook="$main_repo_root/$switch_hook" ;; esac

  # Resolve worktrees dir
  if [ -z "$worktrees_dir" ]; then
    local repo_root repo_parent
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    repo_parent="${repo_root%/*}"
    worktrees_dir="$repo_parent/${project_name}_worktrees"
  fi

  # Set globals
  GWT_PROJECT_NAME="$project_name"
  GWT_WORKTREES_DIR="$worktrees_dir"
  GWT_MAIN_REF="$main_ref"
  GWT_DEV_REF="$dev_ref"
  GWT_DEV_SUFFIX="$dev_suffix"
  GWT_CREATE_HOOK="$create_hook"
  GWT_SWITCH_HOOK="$switch_hook"
}

# =============================================================================
# WORKTREE OPERATIONS
# =============================================================================

_wt_path_for_branch() {
  local branch="$1"
  git worktree list --porcelain | awk -v br="$branch" '
    /^worktree / { path=$2 }
    /^branch / { gsub("refs/heads/", "", $2); b=$2; if (b==br) print path }
  '
}

_branch_for_wt_path() {
  local target_path="$1"
  git worktree list --porcelain | awk -v tp="$target_path" '
    /^worktree / { path=$2; branch="" }
    /^branch / { gsub("refs/heads/", "", $2); branch=$2 }
    /^$/ { if (path==tp && branch!="") print branch; path=""; branch="" }
    END { if (path==tp && branch!="") print branch }
  '
}

_wt_select_interactive() {
  local prompt="$1"
  if command -v fzf >/dev/null 2>&1; then
    git worktree list --porcelain | awk '/^worktree /{print $2}' | fzf --prompt="${prompt:-worktrees> }"
  else
    _err "Install fzf or pass a path|branch"
    return 1
  fi
}

_wt_resolve_path() {
  local input="$1" prompt="$2"

  if [ -n "$input" ]; then
    if [ -d "$input" ]; then
      echo "$input"
      return 0
    fi
    local path
    path=$(_wt_path_for_branch "$input")
    if [ -n "$path" ]; then
      echo "$path"
      return 0
    fi
    _err "No worktree found for branch '$input'"
    return 1
  fi

  local selected
  selected=$(_wt_select_interactive "$prompt") || return 1
  if [ -n "$selected" ]; then
    echo "$selected"
    return 0
  fi
  _err "No worktree selected"
  return 1
}

_run_hook() {
  local event="$1" path="$2" branch="$3" base_ref="${4:-}" main_repo_root="${5:-}"

  [ -z "$main_repo_root" ] && { _err "Main repo root not provided to hook runner"; return 1; }

  local hook=""
  case "$event" in
    created) hook="$GWT_CREATE_HOOK" ;;
    switched) hook="$GWT_SWITCH_HOOK" ;;
    *) return 0 ;;
  esac

  [ -z "$hook" ] || [ ! -f "$hook" ] && return 0
  [ ! -x "$hook" ] && { _debug "Hook '$hook' is not executable. Skipping."; return 0; }

  _debug "Running $event hook: $hook $path $branch $base_ref $main_repo_root"

  local bash_path=""
  if [ -x "/bin/bash" ]; then
    bash_path="/bin/bash"
  elif [ -x "/usr/bin/bash" ]; then
    bash_path="/usr/bin/bash"
  elif command -v bash >/dev/null 2>&1; then
    bash_path=$(command -v bash)
  fi

  [ -z "$bash_path" ] && { _err "bash not found. Cannot execute hook: $hook"; return 1; }

  PATH="/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:$PATH" \
    "$bash_path" "$hook" "$path" "$branch" "$base_ref" "$main_repo_root" 2>&1 | while IFS= read -r line; do
    echo "  $line"
  done
}

_fetch_ref() {
  local base_ref="$1" remote="" branch=""

  if [ -n "$base_ref" ]; then
    case "$base_ref" in
      */*) remote="${base_ref%%/*}"; branch="${base_ref#*/}" ;;
    esac
  fi

  if [ -n "$remote" ] && [ -n "$branch" ]; then
    _debug "Fetching $remote $branch --prune"
    git fetch "$remote" "$branch" --prune >/dev/null 2>&1 || true
  else
    _debug "Fetching origin --prune (fallback)"
    git fetch origin --prune >/dev/null 2>&1 || true
  fi
}

_create_worktree() {
  local new_branch="$1" ref="$2" worktrees_dir="$3"
  local wt_path="$worktrees_dir/$new_branch"

  [ -e "$wt_path" ] && { _err "Path already exists: $wt_path"; return 1; }

  _info "Adding worktree: branch '$new_branch' at '$wt_path' from '$ref'"

  if ! git worktree add -b "$new_branch" "$wt_path" "$ref"; then
    _err "Failed to create worktree for '$new_branch' from $ref"
    return 1
  fi

  local remote="origin"
  _info "Setting upstream for '$new_branch' to '$remote/$new_branch'"
  git -C "$wt_path" config "branch.$new_branch.remote" "$remote" || true
  git -C "$wt_path" config "branch.$new_branch.merge" "refs/heads/$new_branch" || true

  _fetch_ref "$ref"

  local main_repo_root
  main_repo_root=$(_main_repo_root) || return 1
  _run_hook created "$wt_path" "$new_branch" "$ref" "$main_repo_root"
}

_prepare_worktree() {
  local branch="$1" worktrees_dir="$2"

  local existing
  existing=$(_wt_path_for_branch "$branch")
  if [ -n "$existing" ]; then
    _info "Switching to existing worktree for '$branch': $existing"
    local main_repo_root
    main_repo_root=$(_main_repo_root) || return 1
    _run_hook switched "$existing" "$branch" "" "$main_repo_root"
    return 0
  fi

  local wt_path="$worktrees_dir/$branch"
  _info "Creating worktree for existing branch '$branch' at '$wt_path'"
  if ! git worktree add "$wt_path" "$branch"; then
    _err "Failed to create worktree for '$branch'"
    return 1
  fi

  local main_repo_root
  main_repo_root=$(_main_repo_root) || return 1
  _run_hook created "$wt_path" "$branch" "$branch" "$main_repo_root"
}

# =============================================================================
# COMMAND HANDLERS
# =============================================================================

wt_do_new() {
  local new_branch="$1"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1
  _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" 2>/dev/null || { _err "Cannot create worktrees dir: $GWT_WORKTREES_DIR"; return 1; }

  [ -z "$new_branch" ] && { _err "Usage: wt -n <new-branch>"; return 1; }
  _branch_exists "$new_branch" && { _err "Branch '$new_branch' already exists locally"; return 1; }

  _debug "wt -n: creating '$new_branch' from '$GWT_MAIN_REF'"
  _create_worktree "$new_branch" "$GWT_MAIN_REF" "$GWT_WORKTREES_DIR"
}

wt_do_dev() {
  local base_name="$1"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1
  _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" 2>/dev/null || { _err "Cannot create worktrees dir: $GWT_WORKTREES_DIR"; return 1; }

  [ -z "$base_name" ] && base_name=$(_current_branch)
  [ -z "$base_name" ] || [ "$base_name" = "HEAD" ] && { _err "Cannot resolve base name. Usage: wt -n -d [baseName]"; return 1; }

  local new_branch="${base_name}${GWT_DEV_SUFFIX}"
  _branch_exists "$new_branch" && { _err "Branch '$new_branch' already exists locally"; return 1; }

  _create_worktree "$new_branch" "$GWT_DEV_REF" "$GWT_WORKTREES_DIR"
}

wt_do_switch() {
  local input="$1"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1
  _config_load || return 1

  local selected_path branch main_repo_root
  selected_path=$(_wt_resolve_path "$input" "worktrees> ") || return 1
  branch=$(_branch_for_wt_path "$selected_path")
  main_repo_root=$(_main_repo_root) || return 1
  _run_hook switched "$selected_path" "$branch" "" "$main_repo_root"
}

wt_do_remove() {
  local input="$1" force="$2"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1

  local target_path
  target_path=$(_wt_resolve_path "$input" "remove worktree> ") || return 1
  [ -z "$target_path" ] && { _err "Worktree not found"; return 1; }

  [ "$PWD" = "$target_path" ] && cd "$(git rev-parse --show-toplevel 2>/dev/null)" || return 1

  if [ "$force" -ne 1 ]; then
    printf "Remove worktree '%s'? [y/N] " "$target_path" >&2
    read -r reply
    case "$reply" in y|Y|yes|YES) ;; *) echo "Aborted"; return 1 ;; esac
  fi

  local target_branch
  target_branch=$(_branch_for_wt_path "$target_path")

  if [ "$force" -eq 1 ]; then
    git worktree remove --force "$target_path"
  else
    git worktree remove "$target_path"
  fi

  if [ -n "$target_branch" ] && _branch_exists "$target_branch"; then
    if git branch -D "$target_branch" >/dev/null 2>&1; then
      _info "Deleted local branch '$target_branch'"
    else
      _err "Failed to delete local branch '$target_branch'"
    fi
  fi
}

wt_do_open() {
  local branch="$1"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1
  _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" 2>/dev/null || { _err "Cannot create worktrees dir: $GWT_WORKTREES_DIR"; return 1; }

  [ -z "$branch" ] && branch=$(_current_branch)
  [ -z "$branch" ] || [ "$branch" = "HEAD" ] && { _err "Cannot resolve branch. Usage: wt -o [branch]"; return 1; }
  _branch_exists "$branch" || { _err "Branch '$branch' does not exist locally"; return 1; }

  _prepare_worktree "$branch" "$GWT_WORKTREES_DIR"
}

wt_do_lock() {
  local input="$1"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1

  local target_path
  target_path=$(_wt_resolve_path "$input" "lock worktree> ") || return 1
  if git worktree lock "$target_path"; then
    _info "Locked '$target_path'"
  else
    _err "Failed to lock '$target_path'"
    return 1
  fi
}

wt_do_unlock() {
  local input="$1"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1

  local target_path
  target_path=$(_wt_resolve_path "$input" "unlock worktree> ") || return 1
  if git worktree unlock "$target_path"; then
    _info "Unlocked '$target_path'"
  else
    _err "Failed to unlock '$target_path'"
    return 1
  fi
}

wt_do_list() {
  _err "wt -l/--list not yet implemented. Coming in STORY-003."
  return 1
}

wt_do_init() {
  _require_node_project || return 1
  _repo_root >/dev/null || return 1
  _require jq || return 1

  local repo_root config_file project_name worktrees_dir main_ref dev_ref dev_suffix create_hook switch_hook
  repo_root=$(_main_repo_root) || return 1
  config_file="$repo_root/.worktrees/config.json"

  project_name=$(_project_name 2>/dev/null)
  main_ref=$(_main_branch 2>/dev/null)
  dev_ref="origin/release-next"
  dev_suffix="_RN"
  create_hook=".worktrees/hooks/created.sh"
  switch_hook=".worktrees/hooks/switched.sh"

  printf "Project name (default: %s): " "$project_name" >&2; read -r REPLY; [ -n "$REPLY" ] && project_name="$REPLY"
  worktrees_dir="${repo_root%/*}/${project_name}_worktrees"
  printf "Worktrees dir (default: %s): " "$worktrees_dir" >&2; read -r REPLY; [ -n "$REPLY" ] && worktrees_dir="$REPLY"
  printf "Main branch ref (default: %s): " "$main_ref" >&2; read -r REPLY; [ -n "$REPLY" ] && main_ref="$REPLY"
  printf "Dev branch ref (default: %s): " "$dev_ref" >&2; read -r REPLY; [ -n "$REPLY" ] && dev_ref="$REPLY"
  printf "Dev suffix (default: %s): " "$dev_suffix" >&2; read -r REPLY; [ -n "$REPLY" ] && dev_suffix="$REPLY"
  printf "Create hook (default: %s): " "$create_hook" >&2; read -r REPLY; [ -n "$REPLY" ] && create_hook="$REPLY"
  printf "Switch hook (default: %s): " "$switch_hook" >&2; read -r REPLY; [ -n "$REPLY" ] && switch_hook="$REPLY"

  main_ref=$(_normalize_ref "$main_ref")
  dev_ref=$(_normalize_ref "$dev_ref")

  local hooks_dir="$repo_root/.worktrees/hooks"
  mkdir -p "$hooks_dir" 2>/dev/null || { _err "Cannot create hooks dir: $hooks_dir"; return 1; }

  cat > "$hooks_dir/created.sh" <<'HOOK_CREATED'
#!/usr/bin/env bash
set -euo pipefail
# Hook called after creating a new worktree
# Args: $1=path, $2=branch, $3=base_ref, $4=main_repo_root
cd "$1" || exit 1
# Add your automation here (e.g., cursor ., npm install)
HOOK_CREATED

  cat > "$hooks_dir/switched.sh" <<'HOOK_SWITCHED'
#!/usr/bin/env bash
set -euo pipefail
# Hook called after switching to an existing worktree
# Args: $1=path, $2=branch, $3=base_ref, $4=main_repo_root
cd "$1" || exit 1
# Add your automation here (e.g., cursor ., npm install)
HOOK_SWITCHED

  chmod +x "$hooks_dir/created.sh" "$hooks_dir/switched.sh"

  mkdir -p "$(dirname "$config_file")" 2>/dev/null
  cat > "$config_file" <<JSON
{
  "projectName": "${project_name}",
  "worktreesDir": "${worktrees_dir}",
  "mainBranch": "${main_ref}",
  "devBranch": "${dev_ref}",
  "devSuffix": "${dev_suffix}",
  "openCmd": "${create_hook}",
  "switchCmd": "${switch_hook}"
}
JSON

  _info "Saved $config_file"
  _info "Created hook files:"
  _info "  - $hooks_dir/created.sh"
  _info "  - $hooks_dir/switched.sh"
  _info "Edit these files to customize post-action behavior"
}

wt_do_log() {
  local feature="$1" use_reflog="$2" since_arg="$3" author_arg="$4"
  _require_node_project || return 1
  _repo_root >/dev/null || return 1
  _config_load || return 1

  [ -z "$feature" ] && feature=$(_current_branch)
  [ -z "$feature" ] || [ "$feature" = "HEAD" ] && { _err "Cannot resolve feature branch. Usage: wt --log [branch]"; return 1; }

  if [ "$use_reflog" -eq 1 ]; then
    git reflog --date=relative --color=always | head -n 50
    return $?
  fi

  local log_args=""
  [ -n "$since_arg" ] && log_args="$log_args --since=$since_arg"
  [ -n "$author_arg" ] && log_args="$log_args --author=$author_arg"

  git log --oneline --decorate --graph --cherry --no-merges $log_args --color=always -- "${GWT_MAIN_REF}..${feature}"
}

wt_do_help() {
  local have_cfg="no"
  if _repo_root >/dev/null 2>&1; then
    local main_repo_root config_file
    main_repo_root=$(_main_repo_root 2>/dev/null)
    config_file="$main_repo_root/.worktrees/config.json"
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
      _config_load >/dev/null 2>&1 && have_cfg="yes"
    fi
  fi

  echo "Git Worktree Helpers - wt"
  echo ""
  echo "Usage: wt [flags] [arguments]"
  echo ""
  echo "Operations:"
  echo "  -n, --new <branch>        Create worktree from main branch"
  echo "  -n -d, --new --dev [name] Create worktree from dev branch (with suffix)"
  echo "  -s, --switch [branch]     Switch to worktree (fzf picker if no arg)"
  echo "  -r, --remove [branch]     Remove worktree and delete local branch"
  echo "  -o, --open [branch]       Open existing branch as worktree"
  echo "  -L, --lock [branch]       Lock worktree (prevents pruning)"
  echo "  -U, --unlock [branch]     Unlock worktree"
  echo "  -l, --list                List all worktrees"
  echo "      --init                Initialize .worktrees/config.json"
  echo "      --log [branch]        Show feature log vs main"
  echo "  -h, --help                Show this help"
  echo ""
  echo "Modifiers:"
  echo "  -f, --force               Force operation (skip confirmation)"
  echo "  -d, --dev                 Use dev branch as base (with -n)"
  echo "      --reflog              Show reflog instead (with --log)"
  echo "      --since <date>        Filter by date (with --log)"
  echo "      --author <name>       Filter by author (with --log)"
  echo ""
  echo "Examples:"
  echo "  wt -n feature/new-thing   Create worktree for new branch"
  echo "  wt -n -d                  Create dev worktree from current branch"
  echo "  wt -s                     Switch worktree (fzf picker)"
  echo "  wt -r -f my-branch        Force remove worktree"
  echo "  wt --log --since='1 week' Show recent commits"
  echo ""
  if [ "$have_cfg" = "yes" ]; then
    echo "Config (.worktrees/config.json):"
    echo "  projectName : ${GWT_PROJECT_NAME}"
    echo "  worktreesDir: ${GWT_WORKTREES_DIR}"
    echo "  mainBranch  : ${GWT_MAIN_REF}"
    echo "  devBranch   : ${GWT_DEV_REF}"
    echo "  devSuffix   : ${GWT_DEV_SUFFIX}"
  else
    echo "No config found. Run: wt --init"
  fi
}

# =============================================================================
# MAIN COMMAND ROUTER
# =============================================================================

wt() {
  local action="" arg="" force=0 dev=0
  local reflog=0 since_arg="" author_arg=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--new)      action="new"; shift; [ "$#" -gt 0 ] && [[ "$1" != -* ]] && { arg="$1"; shift; } ;;
      -s|--switch)   action="switch"; shift; [ "$#" -gt 0 ] && [[ "$1" != -* ]] && { arg="$1"; shift; } ;;
      -r|--remove)   action="remove"; shift; [ "$#" -gt 0 ] && [[ "$1" != -* ]] && { arg="$1"; shift; } ;;
      -o|--open)     action="open"; shift; [ "$#" -gt 0 ] && [[ "$1" != -* ]] && { arg="$1"; shift; } ;;
      -L|--lock)     action="lock"; shift; [ "$#" -gt 0 ] && [[ "$1" != -* ]] && { arg="$1"; shift; } ;;
      -U|--unlock)   action="unlock"; shift; [ "$#" -gt 0 ] && [[ "$1" != -* ]] && { arg="$1"; shift; } ;;
      -l|--list)     action="list"; shift ;;
      --init)        action="init"; shift ;;
      --log)         action="log"; shift; [ "$#" -gt 0 ] && [[ "$1" != -* ]] && { arg="$1"; shift; } ;;
      -h|--help)     action="help"; shift ;;
      -f|--force)    force=1; shift ;;
      -d|--dev)      dev=1; shift ;;
      --reflog)      reflog=1; shift ;;
      --since)       shift; [ -n "$1" ] && { since_arg="$1"; shift; } ;;
      --author)      shift; [ -n "$1" ] && { author_arg="$1"; shift; } ;;
      -*)            _err "Unknown flag: $1"; _err "Run 'wt -h' for usage"; return 1 ;;
      *)             [ -z "$arg" ] && arg="$1"; shift ;;
    esac
  done

  [ -z "$action" ] && action="help"

  case "$action" in
    new)    [ "$dev" -eq 1 ] && wt_do_dev "$arg" || wt_do_new "$arg" ;;
    switch) wt_do_switch "$arg" ;;
    remove) wt_do_remove "$arg" "$force" ;;
    open)   wt_do_open "$arg" ;;
    lock)   wt_do_lock "$arg" ;;
    unlock) wt_do_unlock "$arg" ;;
    list)   wt_do_list ;;
    init)   wt_do_init ;;
    log)    wt_do_log "$arg" "$reflog" "$since_arg" "$author_arg" ;;
    help)   wt_do_help ;;
    *)      _err "Unknown action: $action"; return 1 ;;
  esac
}
