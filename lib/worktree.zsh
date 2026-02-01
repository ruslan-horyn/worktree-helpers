# Worktree operations

_wt_path() {
  local b="$1"
  git worktree list --porcelain | awk -v br="$b" '
    /^worktree / { p=$2 }
    /^branch / { gsub("refs/heads/","",$2); if ($2==br) print p }
  '
}

_wt_branch() {
  local p="$1"
  git worktree list --porcelain | awk -v tp="$p" '
    /^worktree / { path=$2; b="" }
    /^branch / { gsub("refs/heads/","",$2); b=$2 }
    /^$/ { if (path==tp && b!="") print b; path=""; b="" }
    END { if (path==tp && b!="") print b }
  '
}

_wt_select() {
  command -v fzf >/dev/null 2>&1 || { _err "Install fzf or pass branch"; return 1; }
  git worktree list --porcelain | awk '/^worktree /{print $2}' | fzf --prompt="${1:-wt> }"
}

_branch_select() {
  command -v fzf >/dev/null 2>&1 || { _err "Install fzf or pass branch"; return 1; }
  # List branches: remote branches (strip origin/), excluding HEAD
  git branch -r --format='%(refname:short)' 2>/dev/null | \
    grep -v 'HEAD' | \
    sed 's|^origin/||' | \
    sort -u | \
    fzf --prompt="${1:-branch> }"
}

_wt_resolve() {
  local input="$1" prompt="$2"
  if [ -n "$input" ]; then
    [ -d "$input" ] && { echo "$input"; return; }
    local p; p=$(_wt_path "$input")
    [ -n "$p" ] && { echo "$p"; return; }
    _err "No worktree for '$input'"; return 1
  fi
  _wt_select "$prompt"
}

_run_hook() {
  local event="$1" path="$2" branch="$3" base="${4:-}" root="${5:-}"
  [ -z "$root" ] && return 1
  local hook=""
  case "$event" in created) hook="$GWT_CREATE_HOOK" ;; switched) hook="$GWT_SWITCH_HOOK" ;; esac
  [ -z "$hook" ] || [ ! -x "$hook" ] && return 0

  local bash_path="/bin/bash"
  [ ! -x "$bash_path" ] && bash_path="/usr/bin/bash"
  [ ! -x "$bash_path" ] && bash_path=$(command -v bash)
  [ -z "$bash_path" ] && { _err "bash not found"; return 1; }

  PATH="/usr/local/bin:/usr/bin:/bin:$PATH" "$bash_path" "$hook" "$path" "$branch" "$base" "$root" 2>&1 | sed 's/^/  /'
}

_fetch() {
  local ref="$1"
  if [ -n "$ref" ]; then
    case "$ref" in */*) git fetch "${ref%%/*}" "${ref#*/}" --prune 2>/dev/null || true; return ;; esac
  fi
  git fetch origin --prune 2>/dev/null || true
}

_wt_create() {
  local branch="$1" ref="$2" dir="$3"
  local path="$dir/$branch"
  [ -e "$path" ] && { _err "Path exists: $path"; return 1; }

  _info "Creating worktree '$branch' from '$ref'"
  git worktree add -b "$branch" "$path" "$ref" || { _err "Failed"; return 1; }
  git -C "$path" config "branch.$branch.remote" "origin"
  git -C "$path" config "branch.$branch.merge" "refs/heads/$branch"
  _fetch "$ref"
  _run_hook created "$path" "$branch" "$ref" "$(_main_repo_root)"
}

_wt_open() {
  local branch="$1" dir="$2"
  local existing; existing=$(_wt_path "$branch")
  if [ -n "$existing" ]; then
    _info "Switching to '$branch': $existing"
    _run_hook switched "$existing" "$branch" "" "$(_main_repo_root)"
    return
  fi

  # Fetch from origin to ensure we have the latest refs
  _info "Fetching from origin..."
  git fetch origin --prune 2>/dev/null || true

  local path="$dir/$branch"
  _info "Opening worktree for '$branch'"
  git worktree add "$path" "$branch" || { _err "Failed to create worktree for '$branch'"; return 1; }
  _run_hook created "$path" "$branch" "$branch" "$(_main_repo_root)"
}
