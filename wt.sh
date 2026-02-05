# Git Worktree Helpers - wt
# Source this file in your .zshrc or .bashrc

# Portable script directory detection
_wt_get_script_dir() {
  _src="${BASH_SOURCE[0]:-$0}"
  while [ -L "$_src" ]; do
    _dir="$(cd -P "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    case "$_src" in /*) ;; *) _src="$_dir/$_src" ;; esac
  done
  cd -P "$(dirname "$_src")" && pwd
}
_WT_DIR="${WT_INSTALL_DIR:-$(_wt_get_script_dir)}"

source "$_WT_DIR/lib/utils.sh"
source "$_WT_DIR/lib/config.sh"
source "$_WT_DIR/lib/worktree.sh"
source "$_WT_DIR/lib/commands.sh"

wt() {
  local action="" arg="" force=0 dev=0 reflog=0 since="" author=""
  local dev_only=0 main_only=0 clear_unit="" clear_num=""

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
                   case "${1:-}" in -*|"") ;; *) clear_unit="$1"; shift ;; esac
                   case "${1:-}" in -*|"") ;; *) clear_num="$1"; shift ;; esac ;;
      --init)      action="init"; shift ;;
      --log)       action="log"; shift
                   case "${1:-}" in -*|"") ;; *) arg="$1"; shift ;; esac ;;
      -h|--help)   action="help"; shift ;;
      -f|--force)  force=1; shift ;;
      -d|--dev)    dev=1; shift ;;
      --dev-only)  dev_only=1; shift ;;
      --main-only) main_only=1; shift ;;
      --reflog)    reflog=1; shift ;;
      --since)     shift; since="$1"; shift ;;
      --author)    shift; author="$1"; shift ;;
      -*)          _err "Unknown: $1"; return 1 ;;
      *)           [ -z "$arg" ] && arg="$1"; shift ;;
    esac
  done

  case "${action:-help}" in
    new)    [ "$dev" -eq 1 ] && _cmd_dev "$arg" || _cmd_new "$arg" ;;
    switch) _cmd_switch "$arg" ;;
    remove) _cmd_remove "$arg" "$force" ;;
    open)   _cmd_open "$arg" ;;
    lock)   _cmd_lock "$arg" ;;
    unlock) _cmd_unlock "$arg" ;;
    list)   _cmd_list ;;
    clear)  _cmd_clear "$clear_unit" "$clear_num" "$force" "$dev_only" "$main_only" ;;
    init)   _cmd_init ;;
    log)    _cmd_log "$arg" "$reflog" "$since" "$author" ;;
    help)   _cmd_help ;;
  esac
}
