# Shared test helper for worktree-helpers BATS tests
bats_require_minimum_version 1.5.0

# Project root (where wt.sh lives)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Load BATS libraries
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# Create isolated temp directory per test
setup() {
  # Resolve symlinks so paths match what git returns (macOS /var -> /private/var)
  TEST_TEMP_DIR="$(cd "$(mktemp -d)" && pwd -P)"
  # Save original HOME to restore in teardown
  ORIG_HOME="$HOME"
  ORIG_PATH="$PATH"
}

# Cleanup after each test
teardown() {
  cd /
  rm -rf "$TEST_TEMP_DIR"
  HOME="$ORIG_HOME"
  PATH="$ORIG_PATH"
}

# Initialize a bare git repo (acts as "origin")
create_origin_repo() {
  local origin_dir="$TEST_TEMP_DIR/origin.git"
  git init --bare "$origin_dir" >/dev/null 2>&1
  echo "$origin_dir"
}

# Initialize a working git repo with origin remote and initial commit
# Sets up: origin remote, main branch, initial commit, package.json
create_test_repo() {
  local repo_dir="$TEST_TEMP_DIR/repo"
  local origin_dir
  origin_dir=$(create_origin_repo)

  # Clone from bare origin (suppress all output)
  git clone "$origin_dir" "$repo_dir" >/dev/null 2>&1

  cd "$repo_dir"

  # Configure git user for commits
  git config user.email "test@test.com"
  git config user.name "Test User"

  # Create initial commit on main
  echo "init" > README.md
  git add README.md
  git commit -m "initial commit" >/dev/null 2>&1

  # Rename branch to main if needed (some git versions default to master)
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [ "$current_branch" != "main" ]; then
    git branch -m "$current_branch" main >/dev/null 2>&1
  fi

  git push -u origin main >/dev/null 2>&1

  # Create package.json
  echo '{"name":"test-project"}' > package.json
  git add package.json
  git commit -m "add package.json" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  echo "$repo_dir"
}

# Create .worktrees/config.json with test defaults
# Usage: create_test_config [repo_dir]
create_test_config() {
  local repo_dir="${1:-$PWD}"
  mkdir -p "$repo_dir/.worktrees/hooks"
  cat > "$repo_dir/.worktrees/config.json" <<JSON
{
  "projectName": "test-project",
  "worktreesDir": "$TEST_TEMP_DIR/test-project_worktrees",
  "mainBranch": "origin/main",
  "devBranch": "origin/main",
  "devSuffix": "_RN",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh",
  "worktreeWarningThreshold": 20
}
JSON

  # Create executable hook scripts
  cat > "$repo_dir/.worktrees/hooks/created.sh" <<'SH'
#!/usr/bin/env bash
cd "$1" || exit 1
SH
  cat > "$repo_dir/.worktrees/hooks/switched.sh" <<'SH'
#!/usr/bin/env bash
cd "$1" || exit 1
SH
  chmod +x "$repo_dir/.worktrees/hooks"/*.sh
}

# Create a mock hook that records its invocation to a marker file
# Usage: create_marker_hook <hook_path> <marker_file>
create_marker_hook() {
  local hook_path="$1" marker_file="$2"
  cat > "$hook_path" <<SH
#!/usr/bin/env bash
echo "called:\$1:\$2:\$3:\$4" >> "$marker_file"
SH
  chmod +x "$hook_path"
}

# Source all wt library files (without the wt() router)
load_wt() {
  source "$PROJECT_ROOT/lib/utils.sh"
  source "$PROJECT_ROOT/lib/config.sh"
  source "$PROJECT_ROOT/lib/worktree.sh"
  source "$PROJECT_ROOT/lib/commands.sh"
}

# Source wt.sh (includes router)
load_wt_full() {
  source "$PROJECT_ROOT/wt.sh"
}

# Create a test repo and configure it (convenience combo)
# Sets PWD to the repo dir
setup_test_repo() {
  local repo_dir
  repo_dir=$(create_test_repo)
  cd "$repo_dir"
  create_test_config "$repo_dir"
  load_wt
  echo "$repo_dir"
}
