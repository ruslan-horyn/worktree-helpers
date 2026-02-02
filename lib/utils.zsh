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
  (cd "$d/.." && pwd -P)
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
  git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true
}

_normalize_ref() {
  local ref="$1"; [ -z "$ref" ] && return
  for r in $(git remote 2>/dev/null); do
    case "$ref" in ${r}/*) echo "$ref"; return ;; esac
  done
  echo "origin/$ref"
}

_current_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null; }
_branch_exists() { git show-ref --verify --quiet "refs/heads/$1"; }

# Calculate cutoff timestamp for age-based filtering
# Usage: _calc_cutoff <day|week|month> <number>
_calc_cutoff() {
  local unit="$1" num="$2"
  case "$unit" in
    day)   date -v-${num}d +%s 2>/dev/null || date -d "-$num days" +%s ;;
    week)  date -v-${num}w +%s 2>/dev/null || date -d "-$num weeks" +%s ;;
    month) date -v-${num}m +%s 2>/dev/null || date -d "-$num months" +%s ;;
  esac
}

# Get worktree age (modification time of .git directory)
# Usage: _wt_age <worktree_path>
_wt_age() {
  local path="$1"
  stat -f %m "$path/.git" 2>/dev/null || stat -c %Y "$path/.git" 2>/dev/null
}

# Initialize color variables (only if terminal supports them)
_init_colors() {
  C_RESET="" C_GREEN="" C_RED="" C_YELLOW="" C_DIM=""
  if [ -t 1 ]; then
    C_RESET=$'\033[0m'
    C_GREEN=$'\033[32m'
    C_RED=$'\033[31m'
    C_YELLOW=$'\033[33m'
    C_DIM=$'\033[90m'
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

# Backup existing hook file if content differs from new content
# Usage: _backup_hook <hook_path> <new_content>
# Returns: 0 if backup created or not needed, sets HOOK_BACKED_UP=1 if backup was created
_backup_hook() {
  local hook_path="$1" new_content="$2"
  HOOK_BACKED_UP=0

  # No backup needed if file doesn't exist
  [ ! -f "$hook_path" ] && return 0

  # Compare existing content with new content
  local existing_content
  existing_content=$(cat "$hook_path")

  # No backup needed if content is identical
  [ "$existing_content" = "$new_content" ] && return 0

  # Backup by renaming with _old suffix
  local backup_path="${hook_path}_old"
  if mv "$hook_path" "$backup_path"; then
    HOOK_BACKED_UP=1
    return 0
  else
    _err "Failed to backup $hook_path"
    return 1
  fi
}
