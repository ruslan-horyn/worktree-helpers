# Configuration loading

_config_load() {
  local root cfg
  root=$(_main_repo_root) || return 1
  cfg="$root/.worktrees/config.json"
  [ ! -f "$cfg" ] && { _err "Run 'wt --init' first"; return 1; }
  _require jq || return 1

  GWT_PROJECT_NAME=$(jq -r '.projectName // empty' "$cfg")
  GWT_WORKTREES_DIR=$(jq -r '.worktreesDir // empty' "$cfg")
  GWT_MAIN_REF=$(jq -r '.mainBranch // empty' "$cfg")
  GWT_DEV_REF=$(jq -r '.devBranch // empty' "$cfg")
  GWT_DEV_SUFFIX=$(jq -r '.devSuffix // empty' "$cfg")
  GWT_CREATE_HOOK=$(jq -r '.openCmd // empty' "$cfg")
  GWT_SWITCH_HOOK=$(jq -r '.switchCmd // empty' "$cfg")

  # Defaults
  [ -z "$GWT_PROJECT_NAME" ] && GWT_PROJECT_NAME=$(_project_name)
  [ -z "$GWT_MAIN_REF" ] && GWT_MAIN_REF=$(_main_branch)
  [ -z "$GWT_DEV_REF" ] && GWT_DEV_REF="origin/release-next"
  [ -z "$GWT_DEV_SUFFIX" ] && GWT_DEV_SUFFIX="_RN"
  [ -z "$GWT_CREATE_HOOK" ] && GWT_CREATE_HOOK=".worktrees/hooks/created.sh"
  [ -z "$GWT_SWITCH_HOOK" ] && GWT_SWITCH_HOOK=".worktrees/hooks/switched.sh"

  # Resolve paths
  case "$GWT_CREATE_HOOK" in /*) ;; *) GWT_CREATE_HOOK="$root/$GWT_CREATE_HOOK" ;; esac
  case "$GWT_SWITCH_HOOK" in /*) ;; *) GWT_SWITCH_HOOK="$root/$GWT_SWITCH_HOOK" ;; esac

  if [ -z "$GWT_WORKTREES_DIR" ]; then
    local repo_root="${$(_repo_root)%/*}"
    GWT_WORKTREES_DIR="$repo_root/${GWT_PROJECT_NAME}_worktrees"
  fi
}
