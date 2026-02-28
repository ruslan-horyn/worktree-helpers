#!/usr/bin/env bash
#
# worktree-helpers uninstaller
# https://github.com/ruslan-horyn/worktree-helpers
#
# Usage:
#   wt --uninstall
#   ./uninstall.sh
#   ./uninstall.sh --force   (skip confirmation)
#
set -euo pipefail

# Configuration
INSTALL_DIR="${HOME}/.worktree-helpers"
MARKER="# worktree-helpers"

# Colors (if terminal supports them)
RED=""
GREEN=""
YELLOW=""
DIM=""
RESET=""
if [ -t 1 ]; then
  RED=$(printf '\033[31m')
  GREEN=$(printf '\033[32m')
  YELLOW=$(printf '\033[33m')
  DIM=$(printf '\033[90m')
  RESET=$(printf '\033[0m')
fi

info() { echo "${GREEN}[✓]${RESET} $*"; }
warn() { echo "${YELLOW}[!]${RESET} $*"; }
error() { echo "${RED}[✗]${RESET} $*" >&2; exit 1; }

# Parse arguments
FORCE=0
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    -h|--help)
      echo "Usage: $0 [--force]"
      echo ""
      echo "Options:"
      echo "  -f, --force  Skip confirmation prompt"
      echo "  -h, --help   Show this help message"
      exit 0
      ;;
    *) error "Unknown option: $arg" ;;
  esac
done

echo ""
echo "${RED}╭─────────────────────────────────────────╮${RESET}"
echo "${RED}│     worktree-helpers uninstaller        │${RESET}"
echo "${RED}╰─────────────────────────────────────────╯${RESET}"
echo ""

# Check if anything is installed
FOUND_INSTALL=0
FOUND_RC=0
FOUND_SYMLINK=0
RC_FILE=""

# Detect shell rc file
SHELL_NAME="$(basename "$SHELL")"
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash)
    if [ -f "$HOME/.bashrc" ]; then
      RC_FILE="$HOME/.bashrc"
    else
      RC_FILE="$HOME/.bash_profile"
    fi
    ;;
esac

[ -d "$INSTALL_DIR" ] && FOUND_INSTALL=1
[ -L "$HOME/.local/bin/wt" ] && FOUND_SYMLINK=1
if [ -n "$RC_FILE" ] && [ -f "$RC_FILE" ] && grep -qF "$MARKER" "$RC_FILE"; then
  FOUND_RC=1
fi

if [ "$FOUND_INSTALL" -eq 0 ] && [ "$FOUND_RC" -eq 0 ] && [ "$FOUND_SYMLINK" -eq 0 ]; then
  info "worktree-helpers is not installed"
  exit 0
fi

# Show what will be removed
echo "The following will be removed:"
echo ""
if [ "$FOUND_INSTALL" -eq 1 ]; then
  echo "  ${RED}•${RESET} Installation directory: ${DIM}$INSTALL_DIR${RESET}"
fi
if [ "$FOUND_SYMLINK" -eq 1 ]; then
  echo "  ${RED}•${RESET} Binary symlink: ${DIM}$HOME/.local/bin/wt${RESET}"
fi
if [ "$FOUND_RC" -eq 1 ]; then
  echo "  ${RED}•${RESET} Source lines from: ${DIM}$RC_FILE${RESET}"
fi
echo ""

# Confirmation prompt (unless --force)
if [ "$FORCE" -ne 1 ]; then
  printf "Proceed with uninstall? [y/N] " >&2
  read -r r
  case "$r" in
    y|Y) ;;
    *) info "Aborted"; exit 0 ;;
  esac
  echo ""
fi

# Step 1: Remove source lines from shell config
if [ "$FOUND_RC" -eq 1 ]; then
  # Create temp file without the marker and source line
  local_tmp="${RC_FILE}.wt_uninstall_tmp"
  skip_next=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$skip_next" -eq 1 ]; then
      # Skip source line that follows marker
      case "$line" in
        source*worktree-helpers*|source*wt.sh*) skip_next=0; continue ;;
        *) skip_next=0 ;;
      esac
    fi
    case "$line" in
      "$MARKER"|"$MARKER "*)
        skip_next=1
        continue
        ;;
    esac
    printf '%s\n' "$line"
  done < "$RC_FILE" > "$local_tmp"

  # Remove trailing blank lines left by removal
  mv "$local_tmp" "$RC_FILE"
  info "Removed source lines from $RC_FILE"
fi

# Step 2: Remove binary symlink
if [ -L "$HOME/.local/bin/wt" ]; then
  rm "$HOME/.local/bin/wt"
  info "Removed binary symlink: $HOME/.local/bin/wt"
fi

# Step 3: Remove installation directory
if [ "$FOUND_INSTALL" -eq 1 ]; then
  rm -rf "$INSTALL_DIR"
  info "Removed $INSTALL_DIR"
fi

# Done
echo ""
echo "${GREEN}╭─────────────────────────────────────────╮${RESET}"
echo "${GREEN}│       Uninstall complete!               │${RESET}"
echo "${GREEN}╰─────────────────────────────────────────╯${RESET}"
echo ""
echo "Restart your terminal to complete the process."
echo ""
echo "${DIM}Note: Project-specific configs (.worktrees/) in your repos"
echo "were not removed. Delete them manually if needed.${RESET}"
echo ""
