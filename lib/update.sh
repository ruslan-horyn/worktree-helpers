# Update mechanism

# Cache file location
_WT_UPDATE_CACHE="${HOME}/.wt_update_check"

# GitHub API endpoint
_WT_REPO="ruslan-horyn/worktree-helpers"
_WT_API_URL="https://api.github.com/repos/${_WT_REPO}/releases/latest"

# Compare two semver strings: returns 0 if $1 < $2
# Usage: _version_lt "1.1.0" "1.2.0" && echo "older"
_version_lt() {
  local v1="$1" v2="$2"
  # If equal, not less than
  [ "$v1" = "$v2" ] && return 1

  # Split on dots using IFS+read (works in both bash and zsh;
  # set -- $var does not word-split in zsh without SH_WORD_SPLIT)
  local v1_major v1_minor v1_patch v2_major v2_minor v2_patch
  IFS='.' read -r v1_major v1_minor v1_patch <<EOF
$v1
EOF
  IFS='.' read -r v2_major v2_minor v2_patch <<EOF
$v2
EOF
  v1_major="${v1_major:-0}"; v1_minor="${v1_minor:-0}"; v1_patch="${v1_patch:-0}"
  v2_major="${v2_major:-0}"; v2_minor="${v2_minor:-0}"; v2_patch="${v2_patch:-0}"

  [ "$v1_major" -lt "$v2_major" ] 2>/dev/null && return 0
  [ "$v1_major" -gt "$v2_major" ] 2>/dev/null && return 1
  [ "$v1_minor" -lt "$v2_minor" ] 2>/dev/null && return 0
  [ "$v1_minor" -gt "$v2_minor" ] 2>/dev/null && return 1
  [ "$v1_patch" -lt "$v2_patch" ] 2>/dev/null && return 0
  return 1
}

# Check if cached result is still fresh (< 24 hours old)
_update_cache_fresh() {
  [ ! -f "$_WT_UPDATE_CACHE" ] && return 1
  local now cached_ts
  now=$(date +%s)
  cached_ts=$(head -1 "$_WT_UPDATE_CACHE" 2>/dev/null) || return 1
  [ -z "$cached_ts" ] && return 1
  local age=$((now - cached_ts))
  [ "$age" -lt 86400 ]
}

# Fetch latest version from GitHub API (requires curl)
# Prints: version\nchangelog
_fetch_latest() {
  command -v curl >/dev/null 2>&1 || return 1
  local response
  response=$(curl -sS --max-time 10 \
    -H "Accept: application/vnd.github.v3+json" \
    "$_WT_API_URL" 2>/dev/null) || return 1
  [ -z "$response" ] && return 1

  local tag_name body
  tag_name=$(printf '%s' "$response" | jq -r '.tag_name // empty' 2>/dev/null) || return 1
  body=$(printf '%s' "$response" | jq -r '.body // empty' 2>/dev/null)

  # Strip leading 'v' from tag if present
  local version="${tag_name#v}"
  [ -z "$version" ] && return 1

  printf '%s\n%s' "$version" "$body"
}

# Write check result to cache
# Usage: _update_cache_write <latest_version>
_update_cache_write() {
  local latest="$1"
  local now
  now=$(date +%s)
  printf '%s\n%s\n' "$now" "$latest" > "$_WT_UPDATE_CACHE" 2>/dev/null
}

# Show update notification if cached result indicates an update
_update_notify() {
  [ ! -f "$_WT_UPDATE_CACHE" ] && return 0
  local cached_ver
  cached_ver=$(sed -n '2p' "$_WT_UPDATE_CACHE" 2>/dev/null)
  [ -z "$cached_ver" ] && return 0

  local installed=""
  [ -f "$_WT_DIR/VERSION" ] && read -r installed < "$_WT_DIR/VERSION"
  [ -z "$installed" ] && return 0

  if _version_lt "$installed" "$cached_ver"; then
    _info "Update available: $installed -> $cached_ver. Run 'wt --update' to install."
  fi
}

# Background check -- runs in a subshell, non-blocking
_bg_update_check() {
  _update_cache_fresh && return 0
  (
    (
      result=$(_fetch_latest) || exit 0
      latest=$(printf '%s\n' "$result" | head -1)
      _update_cache_write "$latest"
    ) &
  )
}

# Perform the update
_update_install() {
  local installed=""
  [ -f "$_WT_DIR/VERSION" ] && read -r installed < "$_WT_DIR/VERSION"
  [ -z "$installed" ] && installed="unknown"

  _info "Checking for updates..."

  local result
  result=$(_fetch_latest) || { _err "Failed to check for updates (network error)"; return 1; }

  local latest changelog
  latest=$(printf '%s\n' "$result" | head -1)
  changelog=$(printf '%s\n' "$result" | tail -n +2)

  if [ "$installed" = "$latest" ] || ! _version_lt "$installed" "$latest"; then
    _info "wt is already at the latest version ($installed)"
    return 0
  fi

  _info "Update available: $installed -> $latest"
  echo ""

  # Show changelog if available
  if [ -n "$changelog" ]; then
    echo "Changes:"
    printf '%s\n' "$changelog" | head -20
    echo ""
  fi

  _info "Updating..."

  # Backup current installation
  local backup_dir="${_WT_DIR}.bak"
  if [ -d "$_WT_DIR" ]; then
    rm -rf "$backup_dir"
    cp -R "$_WT_DIR" "$backup_dir"
    _info "Backed up current installation to $backup_dir"
  fi

  # Clone latest to a temp dir, then copy files
  local tmp_dir
  tmp_dir=$(mktemp -d) || { _err "Failed to create temp directory"; return 1; }

  if ! git clone --depth 1 -b main "https://github.com/${_WT_REPO}.git" "$tmp_dir" 2>/dev/null; then
    _err "Failed to download update"
    rm -rf "$tmp_dir"
    return 1
  fi

  # Copy updated files
  cp -R "$tmp_dir/wt.sh" "$tmp_dir/lib" "$tmp_dir/VERSION" "$_WT_DIR/"
  rm -rf "$tmp_dir"

  # Update cache
  _update_cache_write "$latest"

  _info "Updated wt to $latest"
  if [ -n "$_WT_DIR" ]; then
    printf '\nTo activate the new version in this shell, run:\n'
    printf '  source %s/wt.sh\n' "$_WT_DIR"
    printf '\nOr open a new terminal.\n'
  else
    _info "Re-source wt.sh from your shell config to activate the update"
  fi
}

# Check-only mode
_update_check_only() {
  local installed=""
  [ -f "$_WT_DIR/VERSION" ] && read -r installed < "$_WT_DIR/VERSION"
  [ -z "$installed" ] && installed="unknown"

  local result
  result=$(_fetch_latest) || { _err "Failed to check for updates (network error)"; return 1; }

  local latest
  latest=$(printf '%s\n' "$result" | head -1)

  _update_cache_write "$latest"

  if [ "$installed" = "$latest" ] || ! _version_lt "$installed" "$latest"; then
    _info "wt is up to date ($installed)"
  else
    _info "Update available: $installed -> $latest. Run 'wt --update' to install."
  fi
}
