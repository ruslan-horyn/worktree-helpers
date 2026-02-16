# Core utilities

_err() { echo "$*" >&2; }
_info() { echo "$*"; }
_debug() {
  case "${GWT_DEBUG:-0}" in 1|true|yes) echo "[gwt] $*" ;; esac
}

export GWT_DEBUG=0

_require() {
  command -v "$1" >/dev/null 2>&1 || { _err "$1 is required"; return 1; }
}

_main_repo_root() {
  local d; d=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
  (cd "$d/.." >/dev/null 2>&1 && pwd -P)
}

_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || { _err "Not a git repo"; return 1; }
}

_require_pkg() {
  [ -f package.json ] || { _err "package.json not found"; return 1; }
}

_project_name() {
  if command -v jq >/dev/null 2>&1 && [ -f package.json ]; then
    local n; n=$(jq -r '.name // empty' package.json)
    [ -n "$n" ] && [ "$n" != "null" ] && { echo "${n##*[@/]}"; return 0; }
  fi
  basename "$PWD"
}

_main_branch() {
  git show-ref --verify --quiet refs/remotes/origin/main && { echo "origin/main"; return; }
  git show-ref --verify --quiet refs/remotes/origin/master && { echo "origin/master"; return; }
  # shellcheck disable=SC1083
  git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true
}

_normalize_ref() {
  local ref="$1"; [ -z "$ref" ] && return
  for r in $(git remote 2>/dev/null); do
    case "$ref" in ${r}/*) echo "$ref"; return ;; esac
  done
  case "$ref" in origin/*) echo "$ref" ;; *) echo "origin/$ref" ;; esac
}

_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null; }
_branch_exists() { git show-ref --verify --quiet "refs/heads/$1"; }

# Calculate cutoff timestamp for age-based filtering
# Usage: _calc_cutoff <days>
_calc_cutoff() {
  local days="$1"
  date -v-"${days}"d +%s 2>/dev/null || date -d "-$days days" +%s
}

# Get worktree age (modification time of .git directory)
# Usage: _wt_age <worktree_path>
_wt_age() {
  local wt_path="$1"
  stat -c %Y "$wt_path/.git" 2>/dev/null || stat -f %m "$wt_path/.git" 2>/dev/null
}

# Initialize color variables (only if terminal supports them)
_init_colors() {
  C_RESET="" C_GREEN="" C_RED="" C_YELLOW="" C_DIM=""
  if [ -t 1 ]; then
    C_RESET=$(printf '\033[0m')
    C_GREEN=$(printf '\033[32m')
    C_RED=$(printf '\033[31m')
    C_YELLOW=$(printf '\033[33m')
    C_DIM=$(printf '\033[90m')
  fi
}

# Display human-readable age from timestamp
# Usage: _age_display <timestamp>
_age_display() {
  local ts="$1" now diff
  now=$(date +%s)
  diff=$(( (now - ts) / 86400 ))
  case "$diff" in
    0) echo "today" ;;
    1) echo "1 day ago" ;;
    *) echo "$diff days ago" ;;
  esac
}

# Read user input with readline support (tab completion) when available
# Usage: _read_input <prompt> <default>
# Outputs the user's input (or default if empty) to stdout
# Shell-aware: bash uses read -e, zsh uses vared, POSIX uses plain read -r
_read_input() {
  local prompt="$1" default="$2" reply=""
  if [ -n "${ZSH_VERSION:-}" ]; then
    # zsh: use vared for readline/tab completion
    reply="$default"
    printf "%s" "$prompt" >&2
    # shellcheck disable=SC2296
    vared reply
  elif [ -n "${BASH_VERSION:-}" ]; then
    # bash: use read -e for readline/tab completion
    # bash 4.0+ supports -i (initial text); older bash falls back to -e only
    local major="${BASH_VERSION%%.*}"
    if [ "$major" -ge 4 ] 2>/dev/null; then
      # shellcheck disable=SC3045
      read -e -r -p "$prompt" -i "$default" reply
    else
      # shellcheck disable=SC3045
      read -e -r -p "$prompt" reply
    fi
  else
    # POSIX fallback: plain read
    printf "%s" "$prompt" >&2
    read -r reply
  fi
  printf '%s' "${reply:-$default}"
}

# Count total worktrees
# Usage: _wt_count
_wt_count() {
  git worktree list --porcelain 2>/dev/null | grep -c "^worktree " || echo 0
}

# Warn if worktree count exceeds threshold
# Usage: _wt_warn_count (call after worktree creation)
_wt_warn_count() {
  local count threshold
  count=$(_wt_count)
  threshold="${GWT_WORKTREE_WARN_THRESHOLD:-20}"

  if [ "$count" -gt "$threshold" ]; then
    _init_colors
    echo "" >&2
    echo "${C_YELLOW}Warning: You have $count worktrees (threshold: $threshold)${C_RESET}" >&2
    echo "${C_DIM}Consider running 'wt -c 14' to clean up old worktrees${C_RESET}" >&2
  fi
}
