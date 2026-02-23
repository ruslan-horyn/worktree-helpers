#!/usr/bin/env bash
#
# worktree-helpers installer
# https://github.com/ruslan-horyn/worktree-helpers
#
# Usage:
#   Remote install: curl -fsSL https://raw.githubusercontent.com/ruslan-horyn/worktree-helpers/main/install.sh | bash
#   Local install:  ./install.sh --local
#
set -euo pipefail

# Configuration
INSTALL_DIR="${HOME}/.worktree-helpers"
REPO_URL="https://github.com/ruslan-horyn/worktree-helpers.git"

# Colors (if terminal supports them)
RED=""
GREEN=""
YELLOW=""
RESET=""
if [ -t 1 ]; then
  RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m')
  YELLOW=$(printf '\033[33m')
  RESET=$(printf '\033[0m')
fi

info() { echo "${GREEN}[✓]${RESET} $*"; }
warn() { echo "${YELLOW}[!]${RESET} $*"; }
error() { echo "${RED}[✗]${RESET} $*" >&2; exit 1; }

# Parse arguments
LOCAL_INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_INSTALL=1 ;;
    -h|--help)
      echo "Usage: $0 [--local]"
      echo ""
      echo "Options:"
      echo "  --local    Install from current directory (for testing)"
      echo "  -h, --help Show this help message"
      exit 0
      ;;
    *) error "Unknown option: $arg" ;;
  esac
done

echo ""
echo "╭─────────────────────────────────────────╮"
echo "│     worktree-helpers installer          │"
echo "╰─────────────────────────────────────────╯"
echo ""

# Step 1: Check required dependencies
info "Checking dependencies..."

if ! command -v git >/dev/null 2>&1; then
  error "git is required but not installed. Please install git first."
fi

if ! command -v jq >/dev/null 2>&1; then
  error "jq is required but not installed. Please install jq first:
  macOS:  brew install jq
  Ubuntu: sudo apt-get install jq
  Fedora: sudo dnf install jq"
fi

# Optional: fzf
if command -v fzf >/dev/null 2>&1; then
  info "fzf detected (enables interactive selection)"
else
  warn "fzf not found (optional, but enables interactive selection)"
fi

# Step 2: Determine install location and method
if [ "$LOCAL_INSTALL" -eq 1 ]; then
  # Local install: copy from current directory
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ ! -f "$SCRIPT_DIR/wt.sh" ]; then
    error "wt.sh not found in current directory. Run from worktree-helpers directory."
  fi

  info "Installing from local directory: $SCRIPT_DIR"

  # Remove existing installation if present
  if [ -d "$INSTALL_DIR" ]; then
    warn "Removing existing installation at $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
  fi

  # Copy files to install directory
  mkdir -p "$INSTALL_DIR"
  cp -R "$SCRIPT_DIR/wt.sh" "$SCRIPT_DIR/lib" "$SCRIPT_DIR/completions" "$SCRIPT_DIR/VERSION" "$INSTALL_DIR/"

else
  # Remote install: clone from GitHub
  info "Installing from GitHub..."

  if [ -d "$INSTALL_DIR" ]; then
    warn "Removing existing installation at $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
  fi

  if ! git clone --depth 1 -b main "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then
    error "Failed to clone repository. Check your internet connection and try again."
  fi
fi

# Verify installation succeeded
if [ ! -f "$INSTALL_DIR/wt.sh" ]; then
  error "Installation failed: wt.sh not found in $INSTALL_DIR"
fi

info "Installed to $INSTALL_DIR"

# Step 3: Detect shell and rc file
SHELL_NAME="$(basename "$SHELL")"
RC_FILE=""

case "$SHELL_NAME" in
  zsh)
    RC_FILE="$HOME/.zshrc"
    ;;
  bash)
    # Prefer .bashrc, fall back to .bash_profile
    if [ -f "$HOME/.bashrc" ]; then
      RC_FILE="$HOME/.bashrc"
    else
      RC_FILE="$HOME/.bash_profile"
    fi
    ;;
  *)
    warn "Unsupported shell: $SHELL_NAME"
    warn "Please manually add this line to your shell config:"
    warn "  source \"$INSTALL_DIR/wt.sh\""
    exit 0
    ;;
esac

info "Detected shell: $SHELL_NAME"

# Step 4: Add source line to rc file (idempotent)
SOURCE_LINE="source \"$INSTALL_DIR/wt.sh\""
MARKER="# worktree-helpers"

# Check if already installed
if [ -f "$RC_FILE" ] && grep -qF "$SOURCE_LINE" "$RC_FILE"; then
  info "Already configured in $RC_FILE"
else
  # Create rc file if it doesn't exist
  touch "$RC_FILE"

  # Add source line with marker
  {
    echo ""
    echo "$MARKER"
    echo "$SOURCE_LINE"
  } >> "$RC_FILE"

  info "Added to $RC_FILE"
fi

# Step 5: Success message
echo ""
echo "╭─────────────────────────────────────────╮"
echo "│         Installation complete!          │"
echo "╰─────────────────────────────────────────╯"
echo ""
echo "Next steps:"
echo ""
echo "  1. Restart your terminal or run:"
echo "     ${GREEN}source $RC_FILE${RESET}"
echo ""
echo "  2. Navigate to a git repository and initialize:"
echo "     ${GREEN}wt --init${RESET}"
echo ""
echo "  3. Create your first worktree:"
echo "     ${GREEN}wt -n my-feature${RESET}"
echo ""
echo "Run ${GREEN}wt -h${RESET} for all available commands."
echo ""
