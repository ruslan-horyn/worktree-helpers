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
