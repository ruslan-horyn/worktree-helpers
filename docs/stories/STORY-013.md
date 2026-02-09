# STORY-013: Add self-update mechanism (`wt --update`)

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 5
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-09
**Sprint:** 4

---

## User Story

As a user
I want to update the tool with a single command
So that I can get bug fixes and new features without re-running the install script

---

## Description

### Background

Currently, updating `wt` requires manually re-running the install script or pulling the latest code from GitHub. This creates friction for users who want to stay up-to-date. A self-update mechanism would let users update with a single `wt --update` command, and proactively notify them when a new version is available.

STORY-012 (completed) added the `--version` flag and `VERSION` file, which provides the installed version string needed for comparison against the latest release.

### Scope

**In scope:**

- `wt --update` command to fetch and install the latest version from GitHub
- `wt --update --check` to check for updates without installing
- Non-blocking background version check after any `wt` action completes
- Update notification shown on the next `wt` invocation if a new version is available
- Check frequency capped at once per day (cached check result)
- Backup of current installation before updating
- Changelog summary display after update
- Graceful handling of network errors (no crash, just skip silently)

**Out of scope:**

- Auto-updating without user action (always requires explicit `wt --update`)
- Downgrade support (only upgrades to latest)
- Pre-release / beta channel support
- Update from a specific version or tag
- Updating to a non-main branch

### User Flow

**Explicit update:**

1. User runs `wt --update`
2. Tool checks GitHub API for latest release version
3. Tool compares installed version against latest
4. If already up-to-date: `wt is already at the latest version (1.1.0)`
5. If update available:

   ```
   Update available: 1.1.0 → 1.2.0

   Changes:
   - feat: add shell completions for bash and zsh
   - fix: resolve worktree path on Linux
   - docs: update configuration guide

   Updating...
   Backed up current installation to ~/.worktree-helpers.bak
   Updated wt to 1.2.0
   ```

**Check only:**

1. User runs `wt --update --check`
2. Tool checks GitHub API for latest release
3. If up-to-date: `wt is up to date (1.1.0)`
4. If update available: `Update available: 1.1.0 → 1.2.0. Run 'wt --update' to install.`

**Background check (passive notification):**

1. User runs any `wt` command (e.g., `wt -l`)
2. After the command completes, a background subshell checks for updates (non-blocking)
3. Result is cached to `~/.wt_update_check`
4. On the *next* `wt` invocation, if an update is available, a notification is shown before the command output:

   ```
   Update available: 1.1.0 → 1.2.0. Run 'wt --update' to install.
   ```

---

## Acceptance Criteria

- [ ] `wt --update` fetches the latest version from GitHub and installs it
- [ ] `wt --update --check` checks for updates without installing
- [ ] Background version check runs after `wt` actions (non-blocking, in background subshell)
- [ ] Notification shown on next `wt` invocation if new version available
- [ ] Check frequency: at most once per day (cached check result with timestamp)
- [ ] Shows changelog summary of what changed (from GitHub release body)
- [ ] Backs up current installation before updating (`~/.worktree-helpers.bak`)
- [ ] Handles network errors gracefully (no crash, no visible error — just skip)
- [ ] When already up-to-date, `--update` reports the current version
- [ ] Semver comparison is correct (1.2.0 > 1.1.0, 1.10.0 > 1.9.0)
- [ ] Works for both git-clone installs and local (`--local`) installs
- [ ] Update preserves the user's shell config (does not re-add source line)
- [ ] README and docs updated with `--update` usage

---

## Technical Notes

### Components

- **`lib/update.sh`** (new file): `_update_check`, `_update_install`, `_version_compare`, `_update_notify`, `_bg_update_check`
- **`wt.sh`**: Router update — add `--update` flag parsing, dispatch to `_cmd_update`, source `lib/update.sh`, call `_update_notify` at start of `wt()`
- **`lib/commands.sh`**: Add `_cmd_update` function, update `_cmd_help` with `--update` usage

### Implementation Details

#### New file: `lib/update.sh`

```sh
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

  # Split on dots and compare numerically
  local IFS='.'
  set -- $v1
  local v1_major="${1:-0}" v1_minor="${2:-0}" v1_patch="${3:-0}"
  set -- $v2
  local v2_major="${1:-0}" v2_minor="${2:-0}" v2_patch="${3:-0}"

  [ "$v1_major" -lt "$v2_major" ] && return 0
  [ "$v1_major" -gt "$v2_major" ] && return 1
  [ "$v1_minor" -lt "$v2_minor" ] && return 0
  [ "$v1_minor" -gt "$v2_minor" ] && return 1
  [ "$v1_patch" -lt "$v2_patch" ] && return 0
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
  local cached_ts cached_ver
  cached_ts=$(sed -n '1p' "$_WT_UPDATE_CACHE" 2>/dev/null)
  cached_ver=$(sed -n '2p' "$_WT_UPDATE_CACHE" 2>/dev/null)
  [ -z "$cached_ver" ] && return 0

  local installed=""
  [ -f "$_WT_DIR/VERSION" ] && read -r installed < "$_WT_DIR/VERSION"
  [ -z "$installed" ] && return 0

  if _version_lt "$installed" "$cached_ver"; then
    _info "Update available: $installed → $cached_ver. Run 'wt --update' to install."
  fi
}

# Background check — runs in a subshell, non-blocking
_bg_update_check() {
  _update_cache_fresh && return 0
  (
    local result
    result=$(_fetch_latest) || exit 0
    local latest
    latest=$(printf '%s' "$result" | head -1)
    _update_cache_write "$latest"
  ) &
  disown 2>/dev/null
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

  _info "Update available: $installed → $latest"
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
  _info "Restart your shell or run: source $_WT_DIR/wt.sh"
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
    _info "Update available: $installed → $latest. Run 'wt --update' to install."
  fi
}
```

#### Router changes (`wt.sh`)

Add to source block:

```sh
source "$_WT_DIR/lib/update.sh"
```

Add to the `while` loop:

```sh
--update) action="update"; shift ;;
```

Add to the `case` dispatch:

```sh
update) _cmd_update "$force" ;;
```

Add notification check near the top of `wt()`, before the `while` loop:

```sh
_update_notify
```

Add background check at the end, after the `case` dispatch:

```sh
_bg_update_check
```

#### Command handler (`lib/commands.sh`)

```sh
_cmd_update() {
  local check_only="$1"
  if [ "$check_only" -eq 1 ]; then
    _update_check_only
  else
    _update_install
  fi
}
```

Note: Reuse the `force` parameter slot — when `--update` is combined with `--check` (a new flag), it triggers check-only mode. Alternatively, repurpose a parameter. The exact flag design may be refined during implementation (e.g., `--update --check` vs `wt --update-check`).

#### Help text update (`_cmd_help`)

Add to Commands section:

```
  --update               Update to latest version
  --update --check       Check for updates without installing
```

### Cache file format (`~/.wt_update_check`)

```
1707494400       # Unix timestamp of last check
1.2.0            # Latest version found
```

Simple two-line file: line 1 is the check timestamp, line 2 is the latest version. Parsed with `sed -n '1p'` and `sed -n '2p'`.

### Semver comparison

The `_version_lt` function splits versions on `.` and compares major/minor/patch numerically. This correctly handles cases like `1.10.0 > 1.9.0` (which string comparison would get wrong).

### Update mechanism

The update uses `git clone --depth 1` to fetch the latest release, then copies `wt.sh`, `lib/`, and `VERSION` to the install directory. This matches the existing `install.sh` remote install flow. The git clone approach is preferred over tarball download because:

- No need to handle tarball extraction (portable across macOS/Linux)
- Consistent with the existing install mechanism
- Shallow clone is fast (only latest commit)

### Background check

The background check runs in a subshell with `&` after the main command completes. It:

1. Checks if the cache is fresh (< 24 hours) — if so, skips
2. Fetches the latest version from GitHub API
3. Writes the result to the cache file

The `disown` ensures the background process doesn't produce job control messages in interactive shells. The check uses `curl` with a 10-second timeout to avoid hanging.

### Backup strategy

Before updating, the entire `~/.worktree-helpers` directory is copied to `~/.worktree-helpers.bak`. If the update fails mid-way, the user can restore from the backup. The backup is overwritten on each update (only the most recent backup is kept).

### Edge Cases

- **No network connectivity**: `curl` fails → `_fetch_latest` returns 1 → update silently skipped (background check) or shows error message (explicit `--update`)
- **GitHub API rate limit**: Unauthenticated requests allow 60/hour — the once-per-day cache ensures this is never hit
- **curl not installed**: `_fetch_latest` checks for `curl` and returns 1 if missing — update feature is silently unavailable
- **Install directory is a git clone (remote install)**: Update works the same — new clone overwrites the files
- **Install directory is a local dev copy**: Update would overwrite dev changes — could warn, but out of scope for now
- **VERSION file missing or malformed**: Falls back to `"unknown"` — update still works (always considered older than remote)
- **Concurrent background checks**: Two `wt` commands in quick succession could race on the cache file — acceptable, the last writer wins and the result is the same
- **jq not available during background check**: `_fetch_latest` uses `jq` to parse the API response — if jq is missing, the check fails silently

### Security Considerations

- GitHub API is accessed over HTTPS only
- No user input is passed to `eval` or unquoted expansion
- Clone URL is hardcoded (not configurable) to prevent supply chain attacks
- The backup directory path is derived from `$_WT_DIR` (set at source time), not user input
- Temp directory is created with `mktemp -d` and cleaned up after use

### Files Changed

| File | Change |
|------|--------|
| `lib/update.sh` | New file — update check, install, notify, cache, semver compare |
| `wt.sh` | Source `lib/update.sh`, add `--update` flag, dispatch `_cmd_update`, call `_update_notify` and `_bg_update_check` |
| `lib/commands.sh` | Add `_cmd_update`, update `_cmd_help` |

---

## Dependencies

**Prerequisite Stories:**

- STORY-012: Add `--version` flag (completed) — provides the installed version string

**Blocked Stories:**

- None

**External Dependencies:**

- `curl` (for GitHub API calls — available on macOS and most Linux distros by default)
- `jq` (already a project dependency — used to parse GitHub API JSON response)
- GitHub API availability (public, no auth required for release checks)

---

## Definition of Done

- [ ] `lib/update.sh` created with all update functions
- [ ] `wt --update` downloads and installs the latest version
- [ ] `wt --update --check` checks without installing
- [ ] Background version check runs after `wt` commands
- [ ] Update notification displayed on next `wt` invocation when new version available
- [ ] Cache file (`~/.wt_update_check`) limits checks to once per day
- [ ] Current installation backed up before update
- [ ] Changelog summary shown during update
- [ ] Network errors handled gracefully (no crash)
- [ ] Semver comparison handles edge cases (1.10.0 > 1.9.0)
- [ ] `_cmd_help` updated with `--update` usage
- [ ] Router in `wt.sh` handles `--update` flag
- [ ] `lib/update.sh` sourced in `wt.sh`
- [ ] Works in both zsh and bash
- [ ] Works on both macOS and Linux
- [ ] POSIX-compatible shell syntax (no bashisms)
- [ ] Code follows existing patterns (`_` prefix, `GWT_*` globals)
- [ ] BATS tests for `_version_lt`, cache freshness, notification logic
- [ ] Manual testing: update from older version, check-only mode, network failure
- [ ] No regressions in existing functionality
- [ ] shellcheck passes

---

## Story Points Breakdown

- **`lib/update.sh` — version check + cache + notify**: 1.5 points
- **`lib/update.sh` — install + backup**: 1.5 points
- **Router + command handler + help**: 0.5 points
- **Background check integration**: 0.5 points
- **Testing (BATS + manual)**: 1 point
- **Total:** 5 points

**Rationale:** The 5-point estimate reflects significant complexity. The story introduces a new module (`lib/update.sh`) with multiple functions: GitHub API integration, semver comparison, file caching, backup/restore, and background process management. The non-blocking background check and cross-shell compatibility (zsh `disown` behavior) add testing effort. Comparable to STORY-009 (test framework setup, 8pts) in breadth but narrower in scope.

---

## Additional Notes

- **`disown` portability**: `disown` is available in bash and zsh but not in pure POSIX sh. Since the project targets bash/zsh (it's sourced into `.bashrc`/`.zshrc`), this is acceptable. The `2>/dev/null` suppresses errors if `disown` is unavailable.
- **Flag design for check-only**: The plan uses `--update --check` but this requires adding a new `--check` flag to the router. An alternative is to reuse the existing `--force` flag inversely or introduce a standalone `--update-check` flag. The exact design should be finalized during implementation.
- **Future enhancement**: Once the update mechanism is proven, a `--update --force` could skip the changelog display and update immediately. This is out of scope for the initial implementation.
- **GitHub release tagging**: This story assumes releases are tagged with semver tags (e.g., `v1.1.0`) and published as GitHub releases. The `commit-and-tag-version` tool already handles this via `npm run release`.
- **Install path detection**: `$_WT_DIR` is set when `wt.sh` is sourced and points to the install directory. This is used as the target for updates, matching the existing install mechanism.

---

## Progress Tracking

**Status History:**

- 2026-02-09: Created

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
