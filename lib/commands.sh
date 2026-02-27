# Command handlers

_cmd_new() {
  local branch="$1" from_ref="$2"
  _repo_root >/dev/null && _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" || return 1
  [ -z "$branch" ] && { _err "Usage: wt -n <branch> [--from <ref>]"; return 1; }
  _branch_exists "$branch" && { _err "Branch '$branch' already exists. Use 'wt -o $branch' to open it as a worktree."; return 1; }

  local base_ref="${from_ref:-$GWT_MAIN_REF}"
  _wt_create "$branch" "$base_ref" "$GWT_WORKTREES_DIR"
}

_cmd_dev() {
  local base="$1"
  _repo_root >/dev/null && _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" || return 1
  [ -z "$base" ] && base=$(_current_branch)
  [ -z "$base" ] && { _err "No branch"; return 1; }
  local branch="${base}${GWT_DEV_SUFFIX}"
  _branch_exists "$branch" && { _err "Branch '$branch' already exists. Use 'wt -o $branch' to open it as a worktree."; return 1; }
  _wt_create "$branch" "$GWT_DEV_REF" "$GWT_WORKTREES_DIR"
}

_cmd_switch() {
  local input="$1"
  _repo_root >/dev/null && _config_load || return 1
  local wt_path; wt_path=$(_wt_resolve "$input" "switch> ") || return 1
  _run_hook switched "$wt_path" "$(_wt_branch "$wt_path")" "" "$(_main_repo_root)"
}

_cmd_remove() {
  local input="$1" force="$2"
  _repo_root >/dev/null || return 1
  local wt_path; wt_path=$(_wt_resolve "$input" "remove> ") || return 1
  if [ "$PWD" = "$wt_path" ]; then cd "$(_repo_root)" || true; fi

  if [ "$force" -ne 1 ]; then
    printf "Remove '%s'? [y/N] " "$(_wt_display_name "$wt_path")" >&2; read -r r
    case "$r" in y|Y) ;; *) return 1 ;; esac
  fi

  local branch; branch=$(_wt_branch "$wt_path")
  if [ "$force" -eq 1 ]; then
    git worktree remove --force "$wt_path"
  else
    git worktree remove "$wt_path"
  fi
  [ -n "$branch" ] && _branch_exists "$branch" && git branch -D "$branch" 2>/dev/null && _info "Deleted $branch"
}

_cmd_open() {
  local branch="$1"
  _repo_root >/dev/null && _config_load || return 1
  mkdir -p "$GWT_WORKTREES_DIR" || return 1

  # If no branch provided, show fzf picker
  if [ -z "$branch" ]; then
    branch=$(_branch_select "open> ") || return 1
    [ -z "$branch" ] && { _err "No branch selected"; return 1; }
  fi

  # Strip origin/ prefix if present
  branch="${branch#origin/}"

  # Check if branch exists (local or remote)
  if ! _branch_exists "$branch" && ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    _err "Branch '$branch' not found (checked local and origin)"
    return 1
  fi

  _wt_open "$branch" "$GWT_WORKTREES_DIR"
}

_cmd_lock() {
  local input="$1"
  _repo_root >/dev/null || return 1
  local wt_path; wt_path=$(_wt_resolve "$input" "lock> ") || return 1
  git worktree lock "$wt_path" && _info "Locked $(_wt_display_name "$wt_path")"
}

_cmd_unlock() {
  local input="$1"
  _repo_root >/dev/null || return 1
  local wt_path; wt_path=$(_wt_resolve "$input" "unlock> ") || return 1
  git worktree unlock "$wt_path" && _info "Unlocked $(_wt_display_name "$wt_path")"
}

_cmd_clear() {
  local days="$1" force="$2" dev_only="$3" main_only="$4"
  local merged="${5:-0}" pattern="${6:-}" dry_run="${7:-0}"
  _repo_root >/dev/null && _config_load || return 1

  # Validate arguments: days required unless --merged or --pattern provided
  if [ -z "$days" ] && [ "$merged" -eq 0 ] && [ -z "$pattern" ]; then
    _err "Usage: wt -c <days> [--merged] [--pattern <glob>] [--dry-run]"
    return 1
  fi

  # Validate days if provided
  if [ -n "$days" ]; then
    if ! [ "$days" -gt 0 ] 2>/dev/null; then
      _err "Invalid number: $days (must be positive integer)"
      return 1
    fi
  fi

  # Check for mutually exclusive flags
  if [ "$dev_only" -eq 1 ] && [ "$main_only" -eq 1 ]; then
    _err "--dev-only and --main-only are mutually exclusive"
    return 1
  fi

  # Calculate cutoff timestamp (only when days is provided)
  local cutoff=""
  if [ -n "$days" ]; then
    cutoff=$(_calc_cutoff "$days")
    if [ -z "$cutoff" ]; then
      _err "Failed to calculate cutoff date"
      return 1
    fi
  fi

  # Build merged branch list (only when --merged flag is set)
  local merged_branches=""
  if [ "$merged" -eq 1 ]; then
    merged_branches=$(git branch --merged "$GWT_MAIN_REF" 2>/dev/null | sed 's/^[*+ ]*//')
  fi

  local main_root
  main_root=$(_main_repo_root) || return 1

  _init_colors

  # Collect worktrees to delete (newline-delimited strings)
  local output worktree branch locked wt_age
  local to_delete="" locked_skipped="" protected_skipped="" to_delete_count=0
  output=$(git worktree list --porcelain)

  worktree="" branch="" locked=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      worktree\ *)
        worktree="${line#worktree }"
        branch=""
        locked=""
        ;;
      branch\ *)
        branch="${line#branch refs/heads/}"
        ;;
      detached)
        branch="(detached)"
        ;;
      locked*)
        locked="1"
        ;;
      "")
        if [ -n "$worktree" ]; then
          # 1. Skip main repository
          if [ "$worktree" = "$main_root" ]; then
            worktree=""
            continue
          fi

          # 2. Apply dev/main filter
          if [ "$dev_only" -eq 1 ]; then
            case "$branch" in
              *"$GWT_DEV_SUFFIX") ;;
              *) worktree=""; continue ;;
            esac
          elif [ "$main_only" -eq 1 ]; then
            case "$branch" in
              *"$GWT_DEV_SUFFIX") worktree=""; continue ;;
            esac
          fi

          # 3. Apply pattern filter
          if [ -n "$pattern" ]; then
            # eval is needed because zsh does not expand globs in case
            # pattern variables; eval inlines the glob as a literal pattern
            if ! eval "case \"\$branch\" in $pattern) true ;; *) false ;; esac"; then
              worktree=""
              continue
            fi
          fi

          # 4. Apply age filter (only when days is provided)
          if [ -n "$cutoff" ]; then
            wt_age=$(_wt_age "$worktree")
            if [ -z "$wt_age" ] || [ "$wt_age" -ge "$cutoff" ]; then
              if [ "$dry_run" -eq 1 ]; then
                _info "[dry-run]   $(_wt_display_name "$worktree"): skipping: too recent"
              else
                _info "  $(_wt_display_name "$worktree"): skipping: too recent"
              fi
              worktree=""
              continue
            fi
          else
            wt_age=$(_wt_age "$worktree")
          fi

          # 5. Apply merged filter
          if [ "$merged" -eq 1 ]; then
            # Skip detached HEAD worktrees for merged check
            if [ "$branch" = "(detached)" ]; then
              worktree=""
              continue
            fi
            # Check if branch is in the merged list
            local _is_merged=0
            local _mb=""
            while IFS= read -r _mb; do
              [ -z "$_mb" ] && continue
              if [ "$_mb" = "$branch" ]; then
                _is_merged=1
                break
              fi
            done <<MERGED
$merged_branches
MERGED
            if [ "$_is_merged" -eq 0 ]; then
              worktree=""
              continue
            fi
          fi

          # 6. Check protected branch status
          if _is_protected_branch "$branch"; then
            if [ "$dry_run" -eq 1 ]; then
              _info "[dry-run]   $(_wt_display_name "$worktree"): skipping: protected"
            else
              _info "  $(_wt_display_name "$worktree"): skipping: protected"
            fi
            protected_skipped="${protected_skipped}${worktree}|${branch}
"
            worktree=""
            continue
          fi

          # 7. Check locked status
          if [ -n "$locked" ]; then
            if [ "$dry_run" -eq 1 ]; then
              _info "[dry-run]   $(_wt_display_name "$worktree"): skipping: locked"
            else
              _info "  $(_wt_display_name "$worktree"): skipping: locked"
            fi
            locked_skipped="${locked_skipped}${worktree}|${branch}
"
          else
            to_delete="${to_delete}${worktree}|${branch}|${wt_age:-0}
"
            to_delete_count=$((to_delete_count + 1))
          fi

          worktree=""
        fi
        ;;
    esac
  done <<EOF
$output

EOF

  # Warn about protected worktrees
  if [ -n "$protected_skipped" ]; then
    while IFS= read -r item; do
      [ -z "$item" ] && continue
      local wt_path="${item%%|*}"
      local br="${item#*|}"
      echo "${C_YELLOW}Skipping $br: protected branch${C_RESET}" >&2
    done <<EOF
$protected_skipped
EOF
    echo "" >&2
  fi

  # Warn about locked worktrees
  if [ -n "$locked_skipped" ]; then
    echo "${C_YELLOW}Skipping locked worktrees:${C_RESET}" >&2
    while IFS= read -r item; do
      [ -z "$item" ] && continue
      local wt_path="${item%%|*}"
      local br="${item#*|}"
      echo "  ${C_DIM}$(_wt_display_name "$wt_path")${C_RESET} ($br) ${C_RED}[locked]${C_RESET}" >&2
    done <<EOF
$locked_skipped
EOF
    echo "" >&2
  fi

  # Check if anything to delete
  if [ "$to_delete_count" -eq 0 ]; then
    if [ "$dry_run" -eq 1 ]; then
      echo "[dry-run] No worktrees would be removed"
      if [ -n "$protected_skipped" ]; then
        echo ""
        echo "[dry-run] Protected worktrees (skipped):"
        while IFS= read -r item; do
          [ -z "$item" ] && continue
          local wt_path="${item%%|*}"
          local br="${item#*|}"
          echo "  $(_wt_format_entry "$wt_path" "$br") [protected — skipped]"
        done <<EOF
$protected_skipped
EOF
        echo ""
      fi
    else
      _info "No worktrees to clear"
    fi
    return 0
  fi

  # Build description of filters applied
  local filter_desc=""
  if [ -n "$days" ]; then
    filter_desc="older than $days day(s)"
  fi
  if [ "$merged" -eq 1 ]; then
    if [ -n "$filter_desc" ]; then
      filter_desc="$filter_desc, branches merged into ${GWT_MAIN_REF}"
    else
      filter_desc="branches merged into ${GWT_MAIN_REF}"
    fi
  fi
  if [ -n "$pattern" ]; then
    if [ -n "$filter_desc" ]; then
      filter_desc="$filter_desc, matching pattern: $pattern"
    else
      filter_desc="matching pattern: $pattern"
    fi
  fi

  # Dry-run mode: show what would be deleted and exit
  if [ "$dry_run" -eq 1 ]; then
    echo "[dry-run] Worktrees that would be removed ($filter_desc):"
    while IFS= read -r item; do
      [ -z "$item" ] && continue
      local wt_path="${item%%|*}"
      local rest="${item#*|}"
      local br="${rest%%|*}"
      local ts="${rest#*|}"
      if [ -n "$ts" ] && [ "$ts" != "0" ]; then
        echo "  $(_wt_format_entry "$wt_path" "$br") - $(_age_display "$ts")"
      else
        echo "  $(_wt_format_entry "$wt_path" "$br")"
      fi
    done <<EOF
$to_delete
EOF
    echo ""
    if [ -n "$protected_skipped" ]; then
      echo "[dry-run] Protected worktrees (skipped):"
      while IFS= read -r item; do
        [ -z "$item" ] && continue
        local wt_path="${item%%|*}"
        local br="${item#*|}"
        echo "  $(_wt_format_entry "$wt_path" "$br") [protected — skipped]"
      done <<EOF
$protected_skipped
EOF
      echo ""
    fi
    echo "[dry-run] $to_delete_count worktree(s) would be removed"
    return 0
  fi

  # Show list of worktrees to delete
  echo "Worktrees to remove ($filter_desc):"
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    local wt_path="${item%%|*}"
    local rest="${item#*|}"
    local br="${rest%%|*}"
    local ts="${rest#*|}"
    if [ -n "$ts" ] && [ "$ts" != "0" ]; then
      echo "  $(_wt_display_name "$wt_path") ($br) - $(_age_display "$ts")"
    else
      echo "  $(_wt_display_name "$wt_path") ($br)"
    fi
  done <<EOF
$to_delete
EOF
  echo ""

  local rm_force_flag=""
  [ "$force" -eq 1 ] && rm_force_flag="--force"

  # Confirmation prompt (unless -f)
  if [ "$force" -ne 1 ]; then
    printf "Remove %d worktree(s)? [y/N] " "$to_delete_count" >&2
    read -r r
    case "$r" in
      y|Y) ;;
      *) _info "Aborted"; return 1 ;;
    esac
  fi

  # Delete worktrees
  local deleted_count=0
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    local wt_path="${item%%|*}"
    local rest="${item#*|}"
    local br="${rest%%|*}"

    # Change directory if we're in the worktree being removed
    if [ "$PWD" = "$wt_path" ]; then cd "$main_root" || true; fi

    _info "  $(_wt_display_name "$wt_path"): deleting..."
    # shellcheck disable=SC2086
    if git worktree remove $rm_force_flag "$wt_path" 2>/dev/null; then
      _info "Removed $(_wt_display_name "$wt_path")"
      deleted_count=$((deleted_count + 1))
      if [ -n "$br" ] && [ "$br" != "(detached)" ] && _branch_exists "$br"; then
        git branch -D "$br" 2>/dev/null && _info "Deleted branch $br"
      fi
    else
      _err "Failed to remove $wt_path"
    fi
  done <<EOF
$to_delete
EOF

  _info "Cleared ${deleted_count} worktree(s)"
}

_cmd_list() {
  local main_root
  main_root=$(_main_repo_root) || return 1

  _init_colors

  local worktree="" branch="" locked="" is_main=""
  local count=0
  local output=""
  output=$(git worktree list --porcelain)

  # Show worktrees directory header if config is available
  if _config_load 2>/dev/null && [ -n "${GWT_WORKTREES_DIR:-}" ]; then
    echo "${C_DIM}Worktrees in: $GWT_WORKTREES_DIR${C_RESET}" >&2
  fi

  # Parse porcelain output line by line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      worktree\ *)
        worktree="${line#worktree }"
        branch=""
        locked=""
        is_main=""
        ;;
      branch\ *)
        branch="${line#branch refs/heads/}"
        ;;
      detached)
        branch="(detached)"
        ;;
      locked*)
        locked="${line#locked}"
        [ -z "$locked" ] && locked="yes"
        ;;
      "")
        # End of record, print it
        if [ -n "$worktree" ]; then
          count=$((count + 1))

          # Check if this is the main worktree
          [ "$worktree" = "$main_root" ] && is_main="1"

          # Determine display name
          local display_name=""
          if [ -n "$is_main" ]; then
            display_name="[root]"
          else
            display_name=$(_wt_display_name "$worktree")
          fi

          # Format lock indicator
          local lock_indicator=""
          if [ -n "$locked" ]; then
            lock_indicator="${C_RED}[locked]${C_RESET}"
          else
            lock_indicator="${C_GREEN}[active]${C_RESET}"
          fi

          # Format dirty/clean indicator
          local dirty_indicator=""
          _wt_is_dirty "$worktree"
          case $? in
            0) dirty_indicator="${C_YELLOW}[dirty]${C_RESET}" ;;
            1) dirty_indicator="${C_DIM}[clean]${C_RESET}" ;;
            *) dirty_indicator="${C_DIM}[?]${C_RESET}" ;;
          esac

          # Format branch name
          local branch_display="$branch"
          if [ -n "$is_main" ]; then
            branch_display="${C_YELLOW}${branch}${C_RESET} ${C_DIM}(main)${C_RESET}"
          fi

          # Print formatted line
          printf "%-30s %s %s %s\n" "$display_name" "$branch_display" "$lock_indicator" "$dirty_indicator"

          worktree=""
        fi
        ;;
    esac
  done <<EOF
$output

EOF

  # Handle case with no worktrees (only main)
  if [ "$count" -eq 0 ]; then
    _info "No worktrees found"
  fi
}

_cmd_log() {
  local feature="$1" reflog="$2" since="$3" author="$4"
  _repo_root >/dev/null && _config_load || return 1
  [ -z "$feature" ] && feature=$(_current_branch)
  [ "$reflog" -eq 1 ] && { git reflog --date=relative | head -50; return; }
  local since_arg="" author_arg=""
  [ -n "$since" ] && since_arg="--since=$since"
  [ -n "$author" ] && author_arg="--author=$author"
  git log --oneline --graph --cherry --no-merges ${since_arg:+"$since_arg"} ${author_arg:+"$author_arg"} "${GWT_MAIN_REF}..${feature}"
}

# Print the hooks-directory detection prompt and return user's choice (1, 2, or 3)
# Usage: _init_hooks_prompt <hooks_dir>
# Outputs: 1 (keep), 2 (backup), or 3 (overwrite) to stdout
# All menu output goes to stderr (user prompts, not data)
_init_hooks_prompt() {
  local hooks_dir="$1"

  printf "Hooks directory already exists: %s\n" "$hooks_dir" >&2
  local f
  for f in "$hooks_dir"/*; do
    [ -e "$f" ] || continue
    printf "  - %s\n" "$(basename "$f")" >&2
  done
  printf "\nWould you like to:\n" >&2
  printf "  [1] Keep existing hooks (skip) [default]\n" >&2
  printf "  [2] Back up existing hooks to %s.bak/\n" "$hooks_dir" >&2
  printf "  [3] Overwrite with defaults\n\n" >&2

  printf "Choice [1]: " >&2
  local choice
  choice=$(_read_input "" "1")
  case "$choice" in
    2) echo "2" ;;
    3) echo "3" ;;
    *) echo "1" ;;
  esac
}

# Write default hook scripts to the hooks directory
# Usage: _init_write_hooks <hooks_dir> <created_hook_content> <switched_hook_content>
_init_write_hooks() {
  local hooks_dir="$1" created_hook="$2" switched_hook="$3"
  _info "Writing hook scripts..."
  echo "$created_hook" > "$hooks_dir/created.sh" || { _err "Failed to write created.sh hook"; return 1; }
  echo "$switched_hook" > "$hooks_dir/switched.sh" || { _err "Failed to write switched.sh hook"; return 1; }
  chmod +x "$hooks_dir"/*.sh
}

# Write config.json with supplied values and print what was created
# Usage: _init_write_config <cfg> <name> <main_ref> <warn_threshold> <hooks_dir> [show_hooks]
# show_hooks: if non-empty, also prints hooks file lines in the Done output
_init_write_config() {
  local cfg="$1" name="$2" main_ref="$3" warn_threshold="$4" hooks_dir="$5" show_hooks="${6:-}"
  _info "Creating .worktrees/config.json..."
  cat > "$cfg" <<JSON || { _err "Failed to create config: $cfg"; return 1; }
{
  "projectName": "$name",
  "mainBranch": "$main_ref",
  "devBranch": "origin/release-next",
  "devSuffix": "_RN",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh",
  "worktreeWarningThreshold": $warn_threshold
}
JSON
  _info "Done. Created:"
  _info "  $cfg"
  if [ "$show_hooks" = "keep" ]; then
    _info "  $hooks_dir/ (kept as-is)"
  elif [ -n "$show_hooks" ]; then
    _info "  $hooks_dir/created.sh"
    _info "  $hooks_dir/switched.sh"
  fi
  return 0
}

_cmd_init() {
  local force="${1:-0}"
  _repo_root >/dev/null && _require jq || return 1
  local root; root=$(_main_repo_root) || return 1
  local cfg="$root/.worktrees/config.json"
  local hooks_dir="$root/.worktrees/hooks"

  local name main_ref warn_threshold
  name=$(_project_name); main_ref=$(_main_branch)
  warn_threshold=20

  local r
  r=$(_read_input "Project [$name]: " "$name"); [ -n "$r" ] && name="$r"
  r=$(_read_input "Main branch [$main_ref]: " "$main_ref"); [ -n "$r" ] && main_ref="$r"

  main_ref=$(_normalize_ref "$main_ref")

  # Default hook contents
  # shellcheck disable=SC2016
  local created_hook='#!/usr/bin/env bash
cd "$1" || exit 1'
  # shellcheck disable=SC2016
  local switched_hook='#!/usr/bin/env bash
cd "$1" || exit 1'

  _info "Setting up hooks directory..."

  # Fresh path: hooks directory absent or empty — create and write defaults
  if ! { [ -d "$hooks_dir" ] && [ "$(ls -A "$hooks_dir")" ]; }; then
    mkdir -p "$hooks_dir" || { _err "Failed to create hooks directory: $hooks_dir"; return 1; }
    _init_write_hooks "$hooks_dir" "$created_hook" "$switched_hook" || return 1
    _init_write_config "$cfg" "$name" "$main_ref" "$warn_threshold" "$hooks_dir" "1"
    return
  fi

  # Non-interactive: --force flag — keep existing hooks silently
  if [ "$force" = "1" ]; then
    _init_write_config "$cfg" "$name" "$main_ref" "$warn_threshold" "$hooks_dir"
    return
  fi

  # Interactive: show prompt and act on user's choice (empty/EOF defaults to keep)
  local choice
  choice=$(_init_hooks_prompt "$hooks_dir")

  case "$choice" in
    2)
      # Backup: move hooks dir to hooks.bak (handle pre-existing .bak)
      [ -d "${hooks_dir}.bak" ] && rm -rf "${hooks_dir}.bak"
      mv "$hooks_dir" "${hooks_dir}.bak"
      mkdir -p "$hooks_dir" || { _err "Failed to create hooks directory: $hooks_dir"; return 1; }
      _init_write_hooks "$hooks_dir" "$created_hook" "$switched_hook" || return 1
      ;;
    3)
      # Overwrite: replace hooks with defaults
      _init_write_hooks "$hooks_dir" "$created_hook" "$switched_hook" || return 1
      ;;
    *)
      # Option 1 (keep): leave hooks directory untouched
      _init_write_config "$cfg" "$name" "$main_ref" "$warn_threshold" "$hooks_dir" "keep"
      return
      ;;
  esac

  _init_write_config "$cfg" "$name" "$main_ref" "$warn_threshold" "$hooks_dir" "1"
}

_cmd_rename() {
  local new_branch="$1" force="$2"
  _repo_root >/dev/null && _config_load || return 1

  # Validate: new branch name required
  [ -z "$new_branch" ] && { _err "Usage: wt --rename <new-branch>"; return 1; }

  # Detect current branch
  local old_branch
  old_branch=$(_current_branch) || { _err "Cannot detect current branch"; return 1; }
  [ "$old_branch" = "HEAD" ] && { _err "Cannot rename a detached HEAD"; return 1; }

  # Validate: must be in a worktree (not main repo)
  local main_root
  main_root=$(_main_repo_root)
  [ "$PWD" = "$main_root" ] && { _err "Cannot rename from main repo — switch to a worktree first"; return 1; }

  # Validate: not renaming a protected branch
  local main_local="${GWT_MAIN_REF#*/}"
  [ "$old_branch" = "$main_local" ] && { _err "Cannot rename the main branch"; return 1; }

  # Same name check
  [ "$old_branch" = "$new_branch" ] && { _err "New name is the same as current name"; return 1; }

  # Validate: new branch doesn't already exist
  _branch_exists "$new_branch" && { _err "Branch '$new_branch' already exists"; return 1; }

  # Confirmation prompt (unless -f)
  if [ "$force" -ne 1 ]; then
    printf "Rename '%s' → '%s'? [y/N] " "$old_branch" "$new_branch" >&2
    read -r r
    case "$r" in y|Y) ;; *) _info "Aborted"; return 1 ;; esac
  fi

  # 1. Rename the branch
  git branch -m "$old_branch" "$new_branch" || { _err "Failed to rename branch"; return 1; }

  # 2. Move the worktree directory
  local old_path="$PWD"
  local parent_dir="${old_path%/*}"
  local new_path="$parent_dir/$new_branch"

  if [ "$old_path" != "$new_path" ]; then
    if ! git worktree move "$old_path" "$new_path"; then
      # Rollback branch rename on failure
      git branch -m "$new_branch" "$old_branch"
      _err "Failed to move worktree"
      return 1
    fi
    cd "$new_path" || return 1
  fi

  # 3. Update remote tracking (if remote branch exists)
  if git show-ref --verify --quiet "refs/remotes/origin/$old_branch"; then
    git branch -u "origin/$old_branch" "$new_branch" 2>/dev/null
  fi

  # 4. Update branch remote/merge config
  git config "branch.$new_branch.remote" "origin" 2>/dev/null
  git config "branch.$new_branch.merge" "refs/heads/$new_branch" 2>/dev/null

  _info "Renamed '$old_branch' → '$new_branch'"
  _info "Worktree: $new_path"
}

_cmd_uninstall() {
  local force="$1"
  local script="$_WT_DIR/uninstall.sh"
  if [ ! -f "$script" ]; then
    _err "uninstall.sh not found in $_WT_DIR"
    return 1
  fi
  if [ "$force" -eq 1 ]; then
    bash "$script" --force
  else
    bash "$script"
  fi
}

_cmd_update() {
  local check_only="${1:-0}"
  if [ "$check_only" -eq 1 ]; then
    _update_check_only
  else
    _update_install
  fi
}

_cmd_version() {
  local ver=""
  if [ -f "$_WT_DIR/VERSION" ]; then
    read -r ver < "$_WT_DIR/VERSION"
  fi
  echo "wt version ${ver:-unknown}"
}

_cmd_help() {
  # Placeholder naming convention:
  #   <branch>    new branch name
  #   <worktree>  existing worktree (by name)
  #   <ref>       git ref (branch, tag, or commit)
  #   <days>      age in days
  #   <pattern>   glob pattern
  #   <note>      text note
  #   <date>      date string
  #   <new-branch> new branch name for rename
  cat <<'HELP'
wt - Git Worktree Helpers

Usage: wt [flags] [args]

Commands:
  -n, --new <branch>          Create worktree from main (or --from <ref>)
      wt -n feature-foo       Create worktree from main
      wt -n feature-foo --from develop  Create worktree from specific branch
  -n -d [name]                Create worktree from dev branch
  -s, --switch [<worktree>]   Switch worktree (fzf if no arg)
  -r, --remove [<worktree>]   Remove worktree and branch
  -o, --open [branch]         Open existing branch as worktree (fzf if no arg)
  -l, --list                  List worktrees
  -c, --clear [<days>]        Clear worktrees (days optional with --merged/--pattern)
      wt -c 30                Remove worktrees older than 30 days
      wt -c --merged          Remove worktrees with merged branches
  -L, --lock [<worktree>]     Lock worktree
  -U, --unlock [<worktree>]   Unlock worktree
  --init                      Initialize config
  --log [branch]              Show commits vs main
  --rename <new-branch>       Rename current worktree's branch
  --uninstall                 Uninstall worktree-helpers
  --update                    Update to latest version
  --update --check            Check for updates without installing
  -v, --version               Show version
  -h, --help                  This help

Flags:
  -f, --force               Force operation
  -d, --dev                 Use dev branch as base
  -b, --from <ref>          Base branch/ref for -n (default: main branch)
  --dev-only                Filter to dev-based worktrees only (with -c)
  --main-only               Filter to main-based worktrees only (with -c)
  --merged                  Filter to worktrees with branches merged into main (with -c)
  --pattern <pattern>       Filter to worktrees matching branch name glob (with -c)
  --dry-run                 Preview what would be cleared without deleting (with -c)
  --reflog                  Show reflog (with --log)
  --since <date>            Limit log to commits after date (with --log)
  --author <pattern>        Limit log to commits by author (with --log)
  --check                   Check for update without installing (with --update)
HELP
}

_help_new() {
  cat <<'HELP'

  wt -n, --new <branch>

  Create a new worktree from the main branch (or a custom ref).

  Usage:
    wt -n <branch>                 Create worktree from main branch
    wt -n <branch> --from <ref>    Create worktree from specific branch/tag/commit
    wt -n <branch> -d              Create worktree from dev branch

  Examples:
    wt -n feature-login
    wt -n bugfix-CORE-615 --from develop
    wt -n hotfix-v2 --from v2.0.0

  Options:
    --from, -b <ref>    Base branch or ref to create from (default: main branch)
    -d, --dev           Use dev branch as base instead of main
HELP
}

_help_switch() {
  cat <<'HELP'

  wt -s, --switch [<worktree>]

  Switch to a different worktree (opens fzf picker if no argument given).

  Usage:
    wt -s                  Pick worktree interactively with fzf
    wt -s <worktree>       Switch directly to named worktree

  Examples:
    wt -s
    wt -s feature-login
    wt -s bugfix-CORE-615

HELP
}

_help_open() {
  cat <<'HELP'

  wt -o, --open [<branch>]

  Open an existing branch as a worktree (creates the worktree directory if needed).
  Opens fzf picker if no argument is given.

  Usage:
    wt -o                  Pick branch interactively with fzf
    wt -o <branch>         Open specific existing branch as a worktree

  Examples:
    wt -o
    wt -o feature-login
    wt -o origin/release-2.0

HELP
}

_help_remove() {
  cat <<'HELP'

  wt -r, --remove [<worktree>]

  Remove a worktree and delete its branch. Prompts for confirmation unless
  --force is given.

  Usage:
    wt -r                  Pick worktree to remove with fzf
    wt -r <worktree>       Remove named worktree and its branch
    wt -r <worktree> -f    Remove without confirmation prompt

  Examples:
    wt -r feature-login
    wt -r bugfix-CORE-615 --force

  Options:
    -f, --force    Skip confirmation prompt

  Note:
    Main and dev branches are always protected — they cannot be removed.
HELP
}

_help_list() {
  cat <<'HELP'

  wt -l, --list

  List all worktrees with their branch name, lock status, and dirty state.
  The main (root) worktree is shown as [root] with its branch name.

  Usage:
    wt -l

  Examples:
    wt -l
    wt --list

HELP
}

_help_clear() {
  cat <<'HELP'

  wt -c, --clear [<days>]

  Remove multiple worktrees at once. At least one filter must be specified:
  age in days, --merged, or --pattern.

  For each worktree evaluated, prints the decision (deleting... / skipping: protected /
  skipping: locked / skipping: too recent). Prints a summary "Cleared N worktree(s)" on
  completion, or "No worktrees to clear" when nothing matches. With --dry-run each line
  is prefixed with [dry-run].

  Usage:
    wt -c <days>                        Remove worktrees older than <days> days
    wt -c <days> --merged               Also filter by merged-into-main branches
    wt -c --merged                      Remove worktrees with branches merged into main
    wt -c --pattern <pattern>           Remove worktrees matching branch glob pattern
    wt -c <days> --dry-run              Preview what would be removed

  Examples:
    wt -c 30
    wt -c 14 --merged
    wt -c --pattern "feat-*"
    wt -c --merged --pattern "fix-*" --dry-run

  Options:
    --merged              Filter to branches merged into main
    --pattern <pattern>   Filter by branch name glob pattern
    --dry-run             Preview removals without deleting
    --dev-only            Limit to dev-based worktrees
    --main-only           Limit to main-based worktrees
    -f, --force           Skip confirmation prompt

  Note:
    Main and dev branches are always protected — they are never removed
    regardless of filters.
HELP
}

_help_init() {
  cat <<'HELP'

  wt --init

  Initialize worktree-helpers configuration for the current repository.
  Creates .worktrees/config.json and default hook scripts.

  Prints step-by-step progress: "Setting up hooks directory...", "Writing hook scripts...",
  "Creating .worktrees/config.json...". On success prints "Done. Created:" with a list of
  all created files. On failure prints which step failed and why.

  If the hooks directory already exists and is non-empty, you will be asked:
    [1] Keep existing hooks (skip)   — default, leaves hooks untouched
    [2] Back up existing hooks       — moves hooks to .worktrees/hooks.bak/ before writing defaults
    [3] Overwrite with defaults      — replaces all hooks with defaults immediately

  In non-interactive mode (--force or piped stdin) the prompt is skipped and
  existing hooks are preserved (option 1 behaviour).

  Usage:
    wt --init
    wt --init --force

  Examples:
    wt --init
    wt --init --force

  Options:
    -f, --force    Skip hooks prompt; keep existing hooks and create config.json

HELP
}

_help_update() {
  cat <<'HELP'

  wt --update

  Update worktree-helpers to the latest version.

  Usage:
    wt --update              Install the latest version
    wt --update --check      Check for updates without installing

  Examples:
    wt --update
    wt --update --check

  Options:
    --check    Check for a new version without installing it
HELP
}

_help_lock() {
  cat <<'HELP'

  wt -L, --lock [<worktree>]

  Lock a worktree to prevent it from being removed by wt -c or wt -r.
  Opens fzf picker if no argument is given.

  Usage:
    wt -L                  Pick worktree to lock with fzf
    wt -L <worktree>       Lock the named worktree

  Examples:
    wt -L feature-login
    wt -L bugfix-CORE-615

HELP
}

_help_unlock() {
  cat <<'HELP'

  wt -U, --unlock [<worktree>]

  Unlock a previously locked worktree so it can be removed again.
  Opens fzf picker if no argument is given.

  Usage:
    wt -U                  Pick worktree to unlock with fzf
    wt -U <worktree>       Unlock the named worktree

  Examples:
    wt -U feature-login
    wt -U bugfix-CORE-615

HELP
}

_help_log() {
  cat <<'HELP'

  wt --log [<branch>]

  Show commits on the current branch (or <branch>) that are not in main.
  Displays a compact one-line graph. Uses current branch if no argument given.

  Usage:
    wt --log                    Show log for current branch vs main
    wt --log <branch>           Show log for <branch> vs main
    wt --log --reflog           Show recent reflog (last 50 entries)
    wt --log --since <date>     Limit to commits after <date>
    wt --log --author <pattern> Limit to commits by matching author

  Examples:
    wt --log
    wt --log feature-login
    wt --log --since "2 weeks ago"
    wt --log --author alice

  Options:
    --reflog              Show reflog instead of branch log
    --since <date>        Limit to commits after this date
    --author <pattern>    Limit to commits by this author

HELP
}

_help_rename() {
  cat <<'HELP'

  wt --rename <new-branch>

  Rename the current worktree's branch and move its directory to match.
  Must be run from inside a worktree (not the main repo).
  Prompts for confirmation unless --force is given.

  Usage:
    wt --rename <new-branch>        Rename with confirmation
    wt --rename <new-branch> -f     Rename without confirmation

  Examples:
    wt --rename feature-login-v2
    wt --rename bugfix-CORE-999 --force

  Options:
    -f, --force    Skip confirmation prompt

  Note:
    Protected branches (main, dev) cannot be renamed.
    The new branch name must not already exist.
HELP
}
