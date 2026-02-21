# Git Worktree Helpers - wt
# Source this file in your .zshrc or .bashrc

# Portable script directory detection
_wt_get_script_dir() {
  # zsh provides %x, bash provides BASH_SOURCE
  if [ -n "${ZSH_VERSION:-}" ]; then
    # shellcheck disable=SC2296
    _src="${(%):-%x}"
  else
    _src="${BASH_SOURCE[0]}"
  fi
  # Resolve symlinks
  while [ -L "$_src" ]; do
    _dir="$(dirname "$_src")"
    if [ "${_dir#/}" = "$_dir" ]; then
      _dir="$(cd "$_dir" >/dev/null 2>&1 || exit; pwd -P)"
    fi
    _src="$(readlink "$_src")"
    case "$_src" in /*) ;; *) _src="$_dir/$_src" ;; esac
  done
  # Get absolute directory path (subshell to avoid cd side effects, suppress hook output)
  _dir="$(dirname "$_src")"
  (cd "$_dir" >/dev/null 2>&1 || exit; pwd -P)
}
_WT_DIR="${WT_INSTALL_DIR:-$(_wt_get_script_dir)}"

source "$_WT_DIR/lib/utils.sh"
source "$_WT_DIR/lib/config.sh"
source "$_WT_DIR/lib/worktree.sh"
source "$_WT_DIR/lib/commands.sh"
source "$_WT_DIR/lib/update.sh"

wt() {
  local action="" arg="" force=0 dev=0 reflog=0 since="" author=""
  local dev_only=0 main_only=0 clear_days="" from_ref=""
  local merged=0 pattern="" dry_run=0 check_only=0 help=0

  _update_notify

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--new)    action="new"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      -s|--switch) action="switch"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      -r|--remove) action="remove"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      -o|--open)   action="open"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      -L|--lock)   action="lock"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      -U|--unlock) action="unlock"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      -l|--list)   action="list"; shift ;;
      -c|--clear)  action="clear"; shift
                   case "${1:-}" in -*|"") ;; *) clear_days="$1"; shift ;; esac ;;
      --init)      action="init"; shift ;;
      --log)       action="log"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      --rename)    action="rename"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      --uninstall) action="uninstall"; shift ;;
      --update)     action="update"; shift ;;
      --check)     check_only=1; shift ;;
      -v|--version) action="version"; shift ;;
      -h)          action="help"; shift ;;
      --help)      help=1; shift ;;
      -f|--force)  force=1; shift ;;
      -d|--dev)    dev=1; shift ;;
      --dev-only)  dev_only=1; shift ;;
      --main-only) main_only=1; shift ;;
      --reflog)    reflog=1; shift ;;
      --since)     shift; since="$1"; shift ;;
      --author)    shift; author="$1"; shift ;;
      -b|--from)   shift; from_ref="$1"; shift ;;
      --merged)    merged=1; shift ;;
      --pattern)   shift; pattern="$1"; shift ;;
      --dry-run)   dry_run=1; shift ;;
      -*)          _err "Unknown: $1"; return 1 ;;
      *)           [ -z "$arg" ] && arg="$1"; shift ;;
    esac
  done

  # Standalone --help with no command: show full help
  if [ "$help" -eq 1 ] && [ -z "$action" ]; then _cmd_help; return 0; fi

  local _wt_rc=0
  case "${action:-help}" in
    new)    if [ "$help" -eq 1 ]; then _help_new; return 0; fi
            if [ "$dev" -eq 1 ] && [ -n "$from_ref" ]; then
              _err "--from and --dev are mutually exclusive"; return 1
            fi
            if [ "$dev" -eq 1 ]; then _cmd_dev "$arg"
            else _cmd_new "$arg" "$from_ref"; fi
            ;;
    switch) if [ "$help" -eq 1 ]; then _help_switch; return 0; fi
            _cmd_switch "$arg" ;;
    remove) if [ "$help" -eq 1 ]; then _help_remove; return 0; fi
            _cmd_remove "$arg" "$force" ;;
    open)   if [ "$help" -eq 1 ]; then _help_open; return 0; fi
            _cmd_open "$arg" ;;
    lock)   _cmd_lock "$arg" ;;
    unlock) _cmd_unlock "$arg" ;;
    list)   if [ "$help" -eq 1 ]; then _help_list; return 0; fi
            _cmd_list ;;
    clear)  if [ "$help" -eq 1 ]; then _help_clear; return 0; fi
            _cmd_clear "$clear_days" "$force" "$dev_only" "$main_only" "$merged" "$pattern" "$dry_run" ;;
    init)   if [ "$help" -eq 1 ]; then _help_init; return 0; fi
            _cmd_init ;;
    log)    _cmd_log "$arg" "$reflog" "$since" "$author" ;;
    rename) _cmd_rename "$arg" "$force" ;;
    uninstall) _cmd_uninstall "$force" ;;
    update)  if [ "$help" -eq 1 ]; then _help_update; return 0; fi
             _cmd_update "$check_only" ;;
    version) _cmd_version ;;
    help)   _cmd_help ;;
  esac
  _wt_rc=$?

  _bg_update_check

  return "$_wt_rc"
}

# Load shell completions
if [ -n "${ZSH_VERSION:-}" ]; then
  # Zsh: add completions dir to fpath so compinit can discover _wt.
  # shellcheck disable=SC2206
  fpath=("$_WT_DIR/completions" $fpath)
  autoload -Uz _wt
  # shellcheck disable=SC2154
  if (( $+functions[compdef] )); then
    compdef _wt wt 2>/dev/null
  fi
elif [ -n "${BASH_VERSION:-}" ]; then
  # Bash: source completion file
  if [ -f "$_WT_DIR/completions/wt.bash" ]; then
    # shellcheck disable=SC1091
    . "$_WT_DIR/completions/wt.bash"
  fi
fi
