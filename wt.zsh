# Git Worktree Helpers - wt
# Source this file in your .zshrc

_WT_DIR="${0:A:h}"
source "$_WT_DIR/lib/utils.zsh"
source "$_WT_DIR/lib/config.zsh"
source "$_WT_DIR/lib/worktree.zsh"
source "$_WT_DIR/lib/commands.zsh"

wt() {
  local action="" arg="" force=0 dev=0 reflog=0 since="" author=""
  local dev_only=0 main_only=0 clear_unit="" clear_num=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n|--new)    action="new"; shift; [[ "${1:-}" != -* ]] && { arg="$1"; shift; } ;;
      -s|--switch) action="switch"; shift; [[ "${1:-}" != -* ]] && { arg="$1"; shift; } ;;
      -r|--remove) action="remove"; shift; [[ "${1:-}" != -* ]] && { arg="$1"; shift; } ;;
      -o|--open)   action="open"; shift; [[ "${1:-}" != -* ]] && { arg="$1"; shift; } ;;
      -L|--lock)   action="lock"; shift; [[ "${1:-}" != -* ]] && { arg="$1"; shift; } ;;
      -U|--unlock) action="unlock"; shift; [[ "${1:-}" != -* ]] && { arg="$1"; shift; } ;;
      -l|--list)   action="list"; shift ;;
      -c|--clear)  action="clear"; shift
                   [[ "${1:-}" != -* ]] && { clear_unit="$1"; shift; }
                   [[ "${1:-}" != -* ]] && { clear_num="$1"; shift; } ;;
      --init)      action="init"; shift ;;
      --log)       action="log"; shift; [[ "${1:-}" != -* ]] && { arg="$1"; shift; } ;;
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
