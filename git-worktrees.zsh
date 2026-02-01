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
# ERROR HANDLING MODULE
# =============================================================================

gwt_error_handler() {
  echo "$*" >&2
}

gwt_info_handler() {
  echo "$*"
}

gwt_debug_handler() {
  local debug_enabled="${GWT_DEBUG:-0}"
  case "${debug_enabled}" in
    1|true|TRUE|yes|YES) echo "[gwt][debug] $*" ;; 
  esac
}

export GWT_DEBUG=0

# =============================================================================
# PLATFORM DETECTION MODULE
# =============================================================================

gwt_platform_detector() {
  [[ "$OSTYPE" == darwin* ]] && echo "macos" || echo "other"
}

# =============================================================================
# STRING UTILITIES MODULE
# =============================================================================

gwt_string_trimmer() {
  local s="$*"
  s="${s#${s%%[![:space:]]*}}"   # trim leading
  s="${s%${s##*[![:space:]]}}"   # trim trailing
  echo "$s"
}

# =============================================================================
# DEPENDENCY CHECKING MODULE
# =============================================================================

gwt_dependency_checker() {
  local dependency="$1"
  if ! command -v "$dependency" >/dev/null 2>&1; then
    gwt_error_handler "$dependency is required. Install $dependency and retry."
    return 1
  fi
}

# =============================================================================
# REPOSITORY OPERATIONS MODULE
# =============================================================================

gwt_repo_finder() {
  git rev-parse --show-toplevel 2>/dev/null
}

# Returns the main repository root (parent of the shared git common dir),
# which is consistent across all linked worktrees.
gwt_main_repo_root_finder() {
  local common_dir
  common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
  (
    cd "$common_dir/.." 2>/dev/null && pwd -P
  )
}

gwt_repo_validator() {
  local repo_root
  repo_root=$(gwt_repo_finder) || { gwt_error_handler "Not a git repo"; return 1; }
  echo "$repo_root"
}

gwt_node_project_validator() {
  if [ ! -f package.json ]; then
    gwt_error_handler "package.json not found in current directory."
    return 1
  fi
}

# =============================================================================
# CONFIGURATION MANAGEMENT MODULE
# =============================================================================

gwt_config_path_resolver() {
  local main_repo_root
  main_repo_root=$(gwt_main_repo_root_finder) || return 1
  echo "$main_repo_root/.worktrees/config.json"
}

gwt_project_name_detector() {
  # derive from package.json name; sanitize scope and spaces
  if command -v jq >/dev/null 2>&1 && [ -f package.json ]; then
    local name
    name=$(jq -r '.name // empty' package.json)
    if [ -n "$name" ] && [ "$name" != "null" ]; then
      case "$name" in
        @*/*) name="${name#@*/}" ;;
      esac
      name=${name##*/}
      name=${name//\tk/} # Corrected escape for tab
      name=${name// /-}
      echo "$name"
      return 0
    fi
  fi
  basename "$PWD"
}

gwt_main_branch_detector() {
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    echo "origin/main"; return 0
  fi
  if git show-ref --verify --quiet refs/remotes/origin/master; then
    echo "origin/master"; return 0
  fi
  # fallback: current upstream
  local upstream_ref
  upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || true
  [ -n "$upstream_ref" ] && echo "$upstream_ref"
}

# =============================================================================
# BRANCH REFERENCE UTILITIES MODULE
# =============================================================================

gwt_branch_ref_qualifier() {
  local ref="$1"
  local remote
  for remote in $(git remote 2>/dev/null); do
    case "$ref" in
      ${remote}/*) return 0 ;;
    esac
  done
  return 1
}

gwt_branch_ref_normalizer() {
  local ref="$1"
  if [ -z "$ref" ]; then echo ""; return 0; fi
  if gwt_branch_ref_qualifier "$ref"; then
    echo "$ref"
  else
    echo "origin/$ref"
  fi
}


# =============================================================================
# CONFIGURATION LOADING AND VALIDATION MODULE
# =============================================================================

gwt_config_file_validator() {
  local config_file="$1"
  if [ ! -f "$config_file" ]; then
    gwt_error_handler ".worktrees/config.json not found. Run 'wt --init' to create it."
    return 1
  fi
}

gwt_config_parser() {
  local config_file="$1"
  gwt_dependency_checker jq || return 1

  local project_name worktrees_dir main_ref dev_ref dev_suffix create_hook switch_hook

  project_name=$(jq -r '.projectName // empty' "$config_file")
  worktrees_dir=$(jq -r '.worktreesDir // empty' "$config_file")
  main_ref=$(jq -r '.mainBranch // empty' "$config_file")
  dev_ref=$(jq -r '.devBranch // empty' "$config_file")
  dev_suffix=$(jq -r '.devSuffix // empty' "$config_file")
  create_hook=$(jq -r '.openCmd // empty' "$config_file")
  switch_hook=$(jq -r '.switchCmd // empty' "$config_file")

  echo "$project_name|$worktrees_dir|$main_ref|$dev_ref|$dev_suffix|$create_hook|$switch_hook"
}

gwt_config_defaults_applier() {
  local project_name="$1" worktrees_dir="$2" main_ref="$3" dev_ref="$4" dev_suffix="$5" create_hook="$6" switch_hook="$7"

  # Apply defaults for missing values
  if [ -z "$project_name" ]; then project_name=$(gwt_project_name_detector); fi
  if [ -z "$main_ref" ]; then main_ref=$(gwt_main_branch_detector); fi
  if [ -z "$dev_ref" ]; then dev_ref="origin/release-next"; fi
  if [ -z "$dev_suffix" ]; then dev_suffix="_RN"; fi
  if [ -z "$create_hook" ]; then create_hook=".worktrees/hooks/created.sh"; fi
  if [ -z "$switch_hook" ]; then switch_hook=".worktrees/hooks/switched.sh"; fi

  echo "$project_name|$worktrees_dir|$main_ref|$dev_ref|$dev_suffix|$create_hook|$switch_hook"
}

gwt_config_hook_resolver() {
  local create_hook="$1" switch_hook="$2"
  local main_repo_root
  
  # Resolve relative paths to absolute paths based on main repo root
  main_repo_root=$(gwt_main_repo_root_finder) || return 1
  
  # If create_hook is relative, make it absolute
  case "$create_hook" in
    /*) ;; # already absolute
    *) create_hook="$main_repo_root/$create_hook" ;; 
  esac
  
  # If switch_hook is provided, use it; otherwise derive from create hook (sibling file)
  if [ -n "$switch_hook" ]; then
    # If switch_hook is relative, make it absolute
    case "$switch_hook" in
      /*) ;; # already absolute
      *) switch_hook="$main_repo_root/$switch_hook" ;; 
    esac
  else
    # Derive switch hook path from create hook (sibling file)
    local hooks_dir
    hooks_dir="${create_hook%/*}"
    switch_hook="$hooks_dir/switched.sh"
  fi
  
  echo "$create_hook|$switch_hook"
}

gwt_config_worktrees_dir_resolver() {
  local worktrees_dir="$1" project_name="$2"

  # Worktrees dir default: <repoParent>/<projectName>_worktrees
  if [ -z "$worktrees_dir" ]; then
    local repo_root repo_parent
    repo_root=$(gwt_repo_finder) || return 1
    repo_parent="${repo_root%/*}"
    worktrees_dir="$repo_parent/${project_name}_worktrees"
  fi

  echo "$worktrees_dir"
}

gwt_config_loader() {
  # sets globals: GWT_PROJECT_NAME, GWT_WORKTREES_DIR, GWT_MAIN_REF, GWT_DEV_REF, GWT_DEV_SUFFIX, GWT_CREATE_HOOK, GWT_SWITCH_HOOK
  local config_file
  config_file=$(gwt_config_path_resolver) || return 1
  gwt_config_file_validator "$config_file" || return 1

  local parsed_config defaults_applied hooks_resolved worktrees_dir_resolved
  local project_name worktrees_dir main_ref dev_ref dev_suffix create_hook switch_hook

  parsed_config=$(gwt_config_parser "$config_file")
  IFS='|' read -r project_name worktrees_dir main_ref dev_ref dev_suffix create_hook switch_hook <<< "$parsed_config"

  defaults_applied=$(gwt_config_defaults_applier "$project_name" "$worktrees_dir" "$main_ref" "$dev_ref" "$dev_suffix" "$create_hook" "$switch_hook")
  IFS='|' read -r project_name worktrees_dir main_ref dev_ref dev_suffix create_hook switch_hook <<< "$defaults_applied"

  hooks_resolved=$(gwt_config_hook_resolver "$create_hook" "$switch_hook")
  IFS='|' read -r create_hook switch_hook <<< "$hooks_resolved"

  worktrees_dir_resolved=$(gwt_config_worktrees_dir_resolver "$worktrees_dir" "$project_name")

  # Set global variables
  GWT_PROJECT_NAME="$project_name"
  GWT_WORKTREES_DIR="$worktrees_dir_resolved"
  GWT_MAIN_REF="$main_ref"
  GWT_DEV_REF="$dev_ref"
  GWT_DEV_SUFFIX="$dev_suffix"
  GWT_CREATE_HOOK="$create_hook"
  GWT_SWITCH_HOOK="$switch_hook"
}

# =============================================================================
# WORKTREE DIRECTORY MANAGEMENT MODULE
# =============================================================================

gwt_worktrees_dir_creator() {
  local worktrees_dir="$1"
  mkdir -p "$worktrees_dir" 2>/dev/null || { gwt_error_handler "Cannot create worktrees dir: $worktrees_dir"; return 1; }
}

# =============================================================================
# HOOK RUNNER MODULE
# =============================================================================

gwt_hook_file_runner() {
  local event="$1" path="$2" branch="$3" base_ref="${4:-}" main_repo_root="${5:-}"
  local hook="" bash_path=""

  if [ -z "$main_repo_root" ]; then
    gwt_error_handler "Main repo root not provided to hook runner"
    return 1
  fi

  case "$event" in
    created) hook="$GWT_CREATE_HOOK" ;; 
    switched) hook="$GWT_SWITCH_HOOK" ;; 
    *) return 0 ;; 
  esac

  # Exit if hook is not defined, not a file, or not executable
  if [ -z "$hook" ] || [ ! -f "$hook" ]; then
    return 0
  fi
  if [ ! -x "$hook" ]; then
    gwt_debug_handler "Hook '$hook' is not executable. Skipping."
    return 0
  fi

  gwt_debug_handler "Running $event hook: $hook $path $branch $base_ref $main_repo_root"

  # Find bash executable, checking common paths first to avoid PATH issues.
  bash_path=""
  if [ -x "/bin/bash" ]; then
    bash_path="/bin/bash"
  elif [ -x "/usr/bin/bash" ]; then
    bash_path="/usr/bin/bash"
  elif command -v bash >/dev/null 2>&1; then
    bash_path=$(command -v bash)
  fi

  if [ -z "$bash_path" ]; then
    gwt_error_handler "bash not found. Cannot execute hook: $hook"
    return 1
  fi

  # Run the hook synchronously, setting a reliable PATH for its environment
  # by prefixing the command. This is more robust than relying on `env`.
  PATH="/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:$PATH" \
    "$bash_path" "$hook" "$path" "$branch" "$base_ref" "$main_repo_root" 2>&1 | while IFS= read -r line; do
    echo "  $line"
  done
}

# =============================================================================
# GIT OPERATIONS MODULE
# =============================================================================

gwt_git_fetcher() {
  # Fetches updates from a specific ref or all remotes
  # If base_ref provided (e.g., origin/main), parse and fetch that remote/branch
  local base_ref="$1"
  local remote="" branch=""
  
  if [ -n "$base_ref" ]; then
    case "$base_ref" in
      */*) 
        remote="${base_ref%%/*}"
        branch="${base_ref#*/}"
        ;;
    esac
  fi
  
  if [ -n "$remote" ] && [ -n "$branch" ]; then
    gwt_debug_handler "Fetching $remote $branch --prune"
    git fetch "$remote" "$branch" --prune >/dev/null 2>&1 || true
  else
    gwt_debug_handler "Fetching origin --prune (fallback)"
    git fetch origin --prune >/dev/null 2>&1 || true
  fi
}

gwt_current_branch_getter() {
  # Outputs the name of the current local branch
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

gwt_branch_existence_checker() {
  # Returns true (exit code 0) if the specified local branch exists; false otherwise
  local branch="$1"
  git show-ref --verify --quiet "refs/heads/$branch"
}

# =============================================================================
# WORKTREE OPERATIONS MODULE
# =============================================================================

gwt_worktree_path_calculator() {
  # Returns the expected worktree filesystem path (under worktrees_dir) for a given branch name.
  local worktrees_dir="$1" branch="$2"
  echo "$worktrees_dir/$branch"
}

gwt_worktree_path_finder() {
  # Finds the actual worktree path currently linked to the given local branch, if any.
  # Outputs the path if a worktree exists for that branch (parses from `git worktree list --porcelain`), nothing otherwise.
  local branch="$1"
  git worktree list --porcelain | awk -v br="$branch" ' 
    /^worktree / { path=$2 }
    /^branch / { gsub("refs/heads/", "", $2); b=$2; if (b==br) print path }
  '
}

gwt_branch_finder_for_path() {
  # Resolves the branch name checked out at the given worktree path, if any
  local target_path="$1"
  git worktree list --porcelain | awk -v tp="$target_path" ' 
    /^worktree / { path=$2; branch="" }
    /^branch / { gsub("refs/heads/", "", $2); branch=$2 }
    /^$/ { if (path==tp && branch!="") print branch; path=""; branch="" }
    END { if (path==tp && branch!="") print branch }
  '
}

# =============================================================================
# INTERACTIVE SELECTION MODULE
# =============================================================================

gwt_interactive_worktree_selector() {
  # Select a worktree path via fzf; prints selected path. Returns 1 if fzf missing or selection empty.
  local prompt="$1"
  if command -v fzf >/dev/null 2>&1; then
    git worktree list --porcelain | awk '/^worktree /{print $2}' | fzf --prompt="${prompt:-worktrees> }"
    return $?
  else
    gwt_error_handler "Install fzf or pass a path|branch"
    return 1
  fi
}

gwt_worktree_path_resolver() {
  # Resolve a worktree path from an input (path or branch) or interactively via fzf.
  local input="$1" prompt="$2"
  local selected_path=""

  if [ -n "$input" ]; then
    if [ -d "$input" ]; then
      echo "$input"
      return 0
    else
      selected_path=$(gwt_worktree_path_finder "$input")
      if [ -n "$selected_path" ]; then
        echo "$selected_path"
        return 0
      fi
      gwt_error_handler "No worktree found for branch '$input'"
      return 1
    fi
  else
    selected_path=$(gwt_interactive_worktree_selector "$prompt") || return 1
    if [ -n "$selected_path" ]; then
      echo "$selected_path"
      return 0
    fi
    gwt_error_handler "No worktree selected"
    return 1
  fi
}

# =============================================================================
# WORKTREE CREATION AND MANAGEMENT MODULE
# =============================================================================

gwt_worktree_creator_from_ref() {
  # Creates a new worktree for a given ref and new branch.
  # - new_branch: name of new branch to create
  # - ref: existing branch, tag, or commit to base the new branch on
  local new_branch="$1" ref="$2" worktrees_dir="$3"

  local wt_path
  # Determine filesystem path for the new worktree for this branch
  wt_path=$(gwt_worktree_path_calculator "$worktrees_dir" "$new_branch")

  # Error if the target path already exists
  if [ -e "$wt_path" ]; then
    gwt_error_handler "Path already exists: $wt_path"
    return 1
  fi

  gwt_info_handler "Adding worktree: branch '$new_branch' at '$wt_path' from '$ref'"

  # Add new worktree, creating new branch from ref
  if ! git worktree add -b "$new_branch" "$wt_path" "$ref"; then
    gwt_error_handler "Failed to create worktree for '$new_branch' from $ref"
    return 1
  fi

  # Set upstream tracking for the new branch to origin/<new_branch>
  # This doesn't require the remote branch to exist yet.
  local remote="origin" # Assuming origin, which is standard.
  gwt_info_handler "Setting upstream for '$new_branch' to '$remote/$new_branch'"
  if ! git -C "$wt_path" config "branch.$new_branch.remote" "$remote" || ! git -C "$wt_path" config "branch.$new_branch.merge" "refs/heads/$new_branch"; then
      gwt_error_handler "Failed to configure upstream tracking for '$new_branch'."
  fi

  # Fetch updates from the base ref after worktree creation
  gwt_git_fetcher "$ref"
  
  # Run the created hook
  local main_repo_root
  main_repo_root=$(gwt_main_repo_root_finder) || return 1
  gwt_hook_file_runner created "$wt_path" "$new_branch" "$ref" "$main_repo_root"
}

gwt_worktree_preparer() {
  # Ensures a worktree exists for a given local branch, creating it if necessary.
  # If the worktree already exists, just calls the switched hook.
  # Directory changes are delegated to hooks.
  # - branch: the name of the branch to prepare a worktree for
  local branch="$1" worktrees_dir="$2"

  local wt_path existing
  # Find existing worktree for this branch, if any
  existing=$(gwt_worktree_path_finder "$branch")
  if [ -n "$existing" ]; then
    # If exists, run switched hook (hook can handle cd if needed)
    gwt_info_handler "Switching to existing worktree for '$branch': $existing"
    local main_repo_root
    main_repo_root=$(gwt_main_repo_root_finder) || return 1
    gwt_hook_file_runner switched "$existing" "$branch" "" "$main_repo_root"
    return 0
  fi

  # Otherwise, determine desired path and create new worktree for branch
  wt_path=$(gwt_worktree_path_calculator "$worktrees_dir" "$branch")
  gwt_info_handler "Creating worktree for existing branch '$branch' at '$wt_path'"
  if ! git worktree add "$wt_path" "$branch"; then
    gwt_error_handler "Failed to create worktree for '$branch'"
    return 1
  fi

  # Run created hook (hook can handle cd if needed)
  local main_repo_root
  main_repo_root=$(gwt_main_repo_root_finder) || return 1
  gwt_hook_file_runner created "$wt_path" "$branch" "$branch" "$main_repo_root"
}

# =============================================================================
# MAIN COMMAND ROUTER
# =============================================================================

# wt — unified worktree command with flag-based interface
wt() {
  local action="" arg="" force=0 dev=0
  local reflog=0 since_arg="" author_arg=""

  # Parse flags
  while [ "$#" -gt 0 ]; do
    case "$1" in
      # Main operation flags
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

      # Modifier flags
      -f|--force)    force=1; shift ;;
      -d|--dev)      dev=1; shift ;;

      # Log-specific flags
      --reflog)      reflog=1; shift ;;
      --since)       shift; [ -n "$1" ] && { since_arg="$1"; shift; } ;;
      --author)      shift; [ -n "$1" ] && { author_arg="$1"; shift; } ;;

      # Unknown flag or positional argument
      -*)
        gwt_error_handler "Unknown flag: $1"
        gwt_error_handler "Run 'wt -h' for usage"
        return 1
        ;;
      *)
        # Positional argument (branch name, path, etc.)
        if [ -z "$arg" ]; then
          arg="$1"
        fi
        shift
        ;;
    esac
  done

  # Default to help if no action specified
  if [ -z "$action" ]; then
    action="help"
  fi

  # Route to appropriate handler
  case "$action" in
    new)
      if [ "$dev" -eq 1 ]; then
        wt_do_dev "$arg"
      else
        wt_do_new "$arg"
      fi
      ;;
    switch)   wt_do_switch "$arg" ;;
    remove)   wt_do_remove "$arg" "$force" ;;
    open)     wt_do_open "$arg" ;;
    lock)     wt_do_lock "$arg" ;;
    unlock)   wt_do_unlock "$arg" ;;
    list)     wt_do_list ;;
    init)     wt_do_init ;;
    log)      wt_do_log "$arg" "$reflog" "$since_arg" "$author_arg" ;;
    help)     wt_do_help ;;
    *)
      gwt_error_handler "Unknown action: $action"
      return 1
      ;;
  esac
}

# =============================================================================
# COMMAND HANDLERS (called by wt router)
# =============================================================================

wt_do_new() {
  local new_branch="$1"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1
  gwt_config_loader || return 1
  gwt_worktrees_dir_creator "$GWT_WORKTREES_DIR" || return 1

  if [ -z "$new_branch" ]; then
    gwt_error_handler "Usage: wt -n <new-branch>"
    return 1
  fi
  if gwt_branch_existence_checker "$new_branch"; then
    gwt_error_handler "Branch '$new_branch' already exists locally"
    return 1
  fi
  gwt_debug_handler "wt -n: creating '$new_branch' from '$GWT_MAIN_REF'"
  gwt_worktree_creator_from_ref "$new_branch" "$GWT_MAIN_REF" "$GWT_WORKTREES_DIR"
}

wt_do_dev() {
  local base_name="$1"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1
  gwt_config_loader || return 1
  gwt_worktrees_dir_creator "$GWT_WORKTREES_DIR" || return 1

  if [ -z "$base_name" ]; then
    base_name=$(gwt_current_branch_getter)
  fi
  if [ -z "$base_name" ] || [ "$base_name" = "HEAD" ]; then
    gwt_error_handler "Cannot resolve base name. Usage: wt -n -d [baseName]"
    return 1
  fi

  local new_branch="${base_name}${GWT_DEV_SUFFIX}"
  if gwt_branch_existence_checker "$new_branch"; then
    gwt_error_handler "Branch '$new_branch' already exists locally"
    return 1
  fi
  gwt_worktree_creator_from_ref "$new_branch" "$GWT_DEV_REF" "$GWT_WORKTREES_DIR"
}

wt_do_switch() {
  local input="$1"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1
  gwt_config_loader || return 1

  local selected_path branch main_repo_root
  selected_path=$(gwt_worktree_path_resolver "$input" "worktrees> ") || return 1
  branch=$(gwt_branch_finder_for_path "$selected_path")
  main_repo_root=$(gwt_main_repo_root_finder) || return 1
  gwt_hook_file_runner switched "$selected_path" "$branch" "" "$main_repo_root"
}

wt_do_remove() {
  local input="$1" force="$2"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1

  local target_path target_branch
  target_path=$(gwt_worktree_path_resolver "$input" "remove worktree> ") || return 1

  if [ -z "$target_path" ]; then
    gwt_error_handler "Worktree not found"
    return 1
  fi
  if [ "$PWD" = "$target_path" ]; then
    cd "$(gwt_repo_finder)" || return 1
  fi

  if [ "$force" -ne 1 ]; then
    printf "Remove worktree '%s'? [y/N] " "$target_path" >&2
    read -r reply
    case "$reply" in
      y|Y|yes|YES) ;;
      *) echo "Aborted"; return 1 ;;
    esac
  fi

  target_branch=$(gwt_branch_finder_for_path "$target_path")

  if [ "$force" -eq 1 ]; then
    git worktree remove --force "$target_path"
  else
    git worktree remove "$target_path"
  fi

  # Delete local branch if it exists
  if [ -n "$target_branch" ] && gwt_branch_existence_checker "$target_branch"; then
    if git branch -D "$target_branch" >/dev/null 2>&1; then
      gwt_info_handler "Deleted local branch '$target_branch'"
    else
      gwt_error_handler "Failed to delete local branch '$target_branch'"
    fi
  fi
}

wt_do_open() {
  local branch="$1"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1
  gwt_config_loader || return 1
  gwt_worktrees_dir_creator "$GWT_WORKTREES_DIR" || return 1

  if [ -z "$branch" ]; then
    branch=$(gwt_current_branch_getter)
  fi
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    gwt_error_handler "Cannot resolve branch. Usage: wt -o [branch]"
    return 1
  fi
  if ! gwt_branch_existence_checker "$branch"; then
    gwt_error_handler "Branch '$branch' does not exist locally"
    return 1
  fi
  gwt_worktree_preparer "$branch" "$GWT_WORKTREES_DIR"
}

wt_do_lock() {
  local input="$1"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1

  local target_path
  target_path=$(gwt_worktree_path_resolver "$input" "lock worktree> ") || return 1
  if git worktree lock "$target_path"; then
    gwt_info_handler "Locked '$target_path'"
  else
    gwt_error_handler "Failed to lock '$target_path'"
    return 1
  fi
}

wt_do_unlock() {
  local input="$1"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1

  local target_path
  target_path=$(gwt_worktree_path_resolver "$input" "unlock worktree> ") || return 1
  if git worktree unlock "$target_path"; then
    gwt_info_handler "Unlocked '$target_path'"
  else
    gwt_error_handler "Failed to unlock '$target_path'"
    return 1
  fi
}

wt_do_list() {
  # Placeholder for STORY-003
  gwt_error_handler "wt -l/--list not yet implemented. Coming in STORY-003."
  return 1
}

wt_do_init() {
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1
  gwt_dependency_checker jq || return 1

  local repo_root config_file project_name worktrees_dir main_ref dev_ref dev_suffix create_hook switch_hook
  repo_root=$(gwt_main_repo_root_finder) || return 1
  config_file="$repo_root/.worktrees/config.json"

  project_name=$(gwt_project_name_detector 2>/dev/null)
  main_ref=$(gwt_main_branch_detector 2>/dev/null)
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

  main_ref=$(gwt_branch_ref_normalizer "$main_ref")
  dev_ref=$(gwt_branch_ref_normalizer "$dev_ref")

  local hooks_dir="$repo_root/.worktrees/hooks"
  mkdir -p "$hooks_dir" 2>/dev/null || { gwt_error_handler "Cannot create hooks dir: $hooks_dir"; return 1; }

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

  gwt_info_handler "Saved $config_file"
  gwt_info_handler "Created hook files:"
  gwt_info_handler "  - $hooks_dir/created.sh"
  gwt_info_handler "  - $hooks_dir/switched.sh"
  gwt_info_handler "Edit these files to customize post-action behavior"
}

wt_do_log() {
  local feature="$1" use_reflog="$2" since_arg="$3" author_arg="$4"
  gwt_node_project_validator || return 1
  gwt_repo_validator >/dev/null || return 1
  gwt_config_loader || return 1

  if [ -z "$feature" ]; then
    feature=$(gwt_current_branch_getter)
  fi
  if [ -z "$feature" ] || [ "$feature" = "HEAD" ]; then
    gwt_error_handler "Cannot resolve feature branch. Usage: wt --log [branch]"
    return 1
  fi

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
  local have_cfg="no" cfg_path=""
  if gwt_repo_validator >/dev/null 2>&1; then
    cfg_path=$(gwt_config_path_resolver 2>/dev/null)
    if [ -n "$cfg_path" ] && [ -f "$cfg_path" ]; then
      gwt_config_loader >/dev/null 2>&1 && have_cfg="yes"
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
# BACKWARD-COMPATIBLE ALIASES (temporary)
# =============================================================================

wt-init()   { wt --init "$@"; }
wt-new()    { wt -n "$@"; }
wt-dev()    { wt -n -d "$@"; }
wt-open()   { wt -o "$@"; }
wt-switch() { wt -s "$@"; }
wt-remove() { wt -r "$@"; }
wt-lock()   { wt -L "$@"; }
wt-unlock() { wt -U "$@"; }
wt-log()    { wt --log "$@"; }
wt-help()   { wt -h "$@"; }
