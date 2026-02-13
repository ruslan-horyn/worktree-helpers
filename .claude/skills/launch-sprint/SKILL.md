---
name: Launch Sprint Stories
description: >
  This skill should be used when the user asks to "launch stories", "start sprint",
  "run stories in parallel", "launch sprint stories", "uruchom stories",
  or wants to create worktrees and start Claude Code orchestrator sessions
  for multiple sprint stories simultaneously. Accepts story numbers as arguments
  (e.g., "23 22 15").
version: 0.2.0
---

# Launch Sprint Stories

Orchestrate parallel sprint story development by creating git worktrees and opening
Warp terminal tabs — one per story — each running the `sprint-orchestrator` skill.

## Usage

```
/launch-sprint 23 22 15
```

Creates worktrees for STORY-023, STORY-022, STORY-015 and opens Warp tabs with
`/sprint-orchestrator` for each.

## Argument Parsing

Parse story numbers from skill arguments. Accepted formats:

- Space-separated: `23 22 15`
- Comma-separated: `23, 22, 15`
- With prefix: `STORY-023 STORY-022`
- Mixed: `23, STORY-022, 15`

Normalize all to `STORY-XXX` format (zero-padded to 3 digits).

## Workflow

### Step 1 — Parse & Validate

1. Parse story numbers from arguments into a list of `STORY-XXX` IDs
2. Read `references/sprint-plan.md` (bundled in this skill) and locate the `### Branch Mapping` table
3. For each requested story, extract the branch name from the table
4. If a story is not in the map, report error and skip it
5. Read `.worktrees/config.json` to get `worktreesDir` path

### Step 2 — Preflight

1. **Hook check**: Read `.worktrees/hooks/created.sh`. Verify it contains `.ai/` symlink
   logic (look for `ln -s` and `.ai`). If missing, update the hook using this template:

   ```bash
   #!/usr/bin/env bash
   cd "$1" || exit 1

   # Symlink untracked dirs/files from main repo into worktree
   main_root="${4:-}"
   [ -z "$main_root" ] && exit 0

   if [ -d "$main_root/.ai" ] && [ ! -e "$1/.ai" ]; then
     ln -s "$main_root/.ai" "$1/.ai"
   fi

   if [ -f "$main_root/.claude/settings.local.json" ]; then
     mkdir -p "$1/.claude"
     ln -sf "$main_root/.claude/settings.local.json" "$1/.claude/settings.local.json"
   fi
   ```

   Hook args (from `_run_hook` in `lib/worktree.sh`):
   `$1`=worktree_path, `$2`=branch, `$3`=base_ref, `$4`=main_repo_root

2. Run `git fetch origin --prune`

### Step 3 — Create Worktrees

For each story (in order):

1. Check if worktree exists: run `git worktree list --porcelain` and search for the branch
2. If exists: log `EXISTS: STORY-XXX (branch)` and note the worktree path
3. If not: create via `wt -n <branch>` by running:
   ```bash
   source <repo_root>/wt.sh && wt -n <branch>
   ```
   where `<repo_root>` is the git toplevel directory. This triggers the `created.sh` hook
   which sets up symlinks.
4. Determine worktree path: `<worktreesDir>/<branch>`

### Step 4 — Launch Warp Tabs

Run the launcher script passing `STORY-ID:worktree_path` pairs:

```bash
bash .claude/skills/launch-sprint/scripts/launch-sessions.sh \
  STORY-023:/path/to/wt1 STORY-022:/path/to/wt2 ...
```

The script opens a **Warp terminal tab** per story via AppleScript. In each tab it runs:
```
claude -p "/sprint-orchestrator STORY-XXX"
```

The `sprint-orchestrator` skill detects it is in a linked worktree and enters
**worktree mode** — it skips branch creation (Step 1) and defers merge to main (Step 6).

### Step 5 — Report

After launch, report to the user:

```
Launched X stories in Warp tabs:
  STORY-023 → /path/to/wt
  STORY-022 → /path/to/wt
  ...

Each tab runs /sprint-orchestrator in worktree mode (merge deferred).
Monitor progress:
  ls .ai/reports/STORY-*-qa.md
```

## Key Details

- **Worktrees directory**: read from `.worktrees/config.json` field `worktreesDir`
- **Sprint plan**: `references/sprint-plan.md` — sprint allocations, story details, dependency graph
- **Reports**: `.ai/reports/` is shared across all worktrees via symlink; no conflicts
  because files are `STORY-XXX-` prefixed
- **Parallelism control**: pass fewer story numbers to limit concurrent sessions
  (e.g., `/launch-sprint 23 22` for a wave of 2)
- **Permissions**: each worktree inherits `.claude/settings.local.json` via symlink —
  ensure it grants needed tool permissions for autonomous orchestrator mode.
  Some Bash permissions use absolute paths to the main repo; worktree-specific
  commands (`npm test`, `shellcheck`) use relative paths and work fine.
- **Missing story docs**: the orchestrator's Phase 0 auto-creates missing story docs
  via `/create-story`, so stories without a doc file are safe to launch
- **`.worktrees/` is gitignored** — hook changes will not appear in `git status`

## Caveats

- **Accessibility permissions**: macOS must grant Accessibility access to Warp (or the
  terminal running this script) for AppleScript `System Events` keystroke simulation.
  Check: System Settings → Privacy & Security → Accessibility
- **Worktree mode**: sprint-orchestrator commits changes but does NOT merge to main.
  After all parallel stories complete, the user handles merges manually or sequentially.
- **Warp-specific**: the launcher script uses AppleScript targeting Warp. It will not
  work with other terminal emulators without modification.

## Verification

After launching, verify sessions are running:

1. **Warp tabs open**: each story should have its own Warp tab with `claude` running
2. **Worktree mode detected**: sprint-orchestrator should log that it detected a linked
   worktree and is skipping branch creation
3. **Symlinks**: check a worktree has `.ai/` symlink and `.claude/settings.local.json`:
   `ls -la <worktree>/.ai <worktree>/.claude/settings.local.json`
4. **Checkpoints appearing**: `ls .ai/reports/STORY-*-dev-checkpoint-*.md`
   (indicates Dev agents are working)
5. **Completion**: `ls .ai/reports/STORY-*-qa.md` — QA report means story is done
