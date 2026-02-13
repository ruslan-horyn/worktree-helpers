#!/usr/bin/env bash
# Launch Claude Code sprint-orchestrator sessions in Warp terminal tabs.
#
# Usage:
#   launch-sessions.sh STORY-023:/path/to/wt STORY-022:/path/to/wt2 ...
#
# Environment:
#   LAUNCH_DELAY — seconds between tab launches (default: 3)

set -euo pipefail

LAUNCH_DELAY="${LAUNCH_DELAY:-3}"

if [ $# -eq 0 ]; then
  echo "Usage: $0 STORY-ID:/worktree/path [STORY-ID:/worktree/path ...]"
  exit 1
fi

echo "Launching $# story session(s) in Warp tabs..."
echo ""

for entry in "$@"; do
  story_id="${entry%%:*}"
  wt_path="${entry#*:}"

  if [ ! -d "$wt_path" ]; then
    echo "SKIP: $story_id — worktree not found: $wt_path"
    continue
  fi

  # Open new Warp tab at worktree path via URI scheme
  open -u "warp://action/new_tab?path=${wt_path}"
  sleep 1.5

  # Type the claude command in the new tab
  osascript <<APPLE
tell application "System Events"
  tell process "Warp"
    keystroke "claude -p \"/sprint-orchestrator ${story_id}\""
    delay 0.3
    key code 36
  end tell
end tell
APPLE

  echo "LAUNCHED: $story_id → $wt_path"
  sleep "$LAUNCH_DELAY"
done

echo ""
echo "All sessions launched in Warp tabs."
