---
name: launch-sprint
description: >
  This skill should be used when the user asks to "launch stories", "start sprint",
  "run stories in parallel", "launch sprint stories", "create worktrees for sprint",
  "uruchom stories", or wants to create git worktrees for multiple sprint stories
  simultaneously. Accepts optional story numbers as arguments (e.g., "23 22 15").
version: 1.0.0
---

# Launch Sprint Stories

Analyze the active sprint, determine which stories can run in parallel, and create
git worktrees for each using `wt -n`. The user handles launching Claude Code sessions
in the created worktrees manually.

## Usage

```
/launch-sprint 23 22 15
/launch-sprint              # auto-detect all parallelizable stories
```

## Argument Parsing

Parse story numbers from skill arguments. Accepted formats:

- Space-separated: `23 22 15`
- Comma-separated: `23, 22, 15`
- With prefix: `STORY-023 STORY-022`
- Mixed: `23, STORY-022, 15`

Normalize all to `STORY-XXX` format (zero-padded to 3 digits).

## Workflow

### Step 1 — Load Sprint Status

1. Read `.bmad/sprint-status.yaml`
2. Find the sprint with `status: "active"`
3. Extract all stories from that sprint

### Step 2 — Determine Parallelizable Stories

1. Filter stories: exclude `status: "completed"`
2. Resolve dependencies: a story is **parallelizable** when all entries in its
   `blocked_by` list have `status: "completed"`
3. If arguments were provided, further filter to only those story IDs
4. If no arguments: select all parallelizable stories automatically

Present the execution plan:

```
Sprint N — Parallel Launch Plan

Stories to launch:
  STORY-022 (2pts) — Improve wt --init worktrees path prompt
  STORY-015 (3pts) — Add more granular clear options

Total: 2 stories, 5 points
Blocked (skipped): STORY-XXX (blocked by STORY-YYY)

Proceed? [confirm with user]
```

### Step 3 — Preflight

1. Run `git fetch origin --prune`
2. Verify the main repo is on a clean state (warn if uncommitted changes)

### Step 4 — Create Worktrees

For each story (in order):

1. Derive branch name from story: `story-XXX-<kebab-case-title>`
   - Example: STORY-022 "Improve wt --init worktrees path prompt" → `story-022-improve-wt-init-worktrees-path-prompt`
   - Strip special characters, lowercase, replace spaces with hyphens
   - **No slashes in branch names** — slashes create nested directories in worktreesDir
2. Check if worktree already exists: run `git worktree list --porcelain` and search
   for the branch
3. If exists: log `EXISTS: STORY-XXX → <path>` and note the path
4. If not: create via `wt -n <branch>` by running:
   ```bash
   source <repo_root>/wt.sh && wt -n <branch>
   ```
   where `<repo_root>` is the git toplevel directory.
5. The `created` hook (`.worktrees/hooks/created.sh`) automatically runs
   `pnpm install` in the new worktree

### Step 5 — Report

After all worktrees are created, report to the user:

```
Launched N worktrees for Sprint X:
  STORY-022 → /path/to/worktrees/story-022-improve-wt-init-worktrees-path-prompt
  STORY-015 → /path/to/worktrees/story-015-add-more-granular-clear-options

Next steps:
  cd <worktree-path> && claude "/sprint-orchestrator STORY-XXX"
```

## Key Details

- **Sprint status**: `.bmad/sprint-status.yaml` — sole source of truth for stories, statuses, and dependencies
- **Branch naming**: `story-XXX-<kebab-title>` — NO slashes (slashes create nested directories)
- **Hook setup**: the `created` hook runs `pnpm install` in the new worktree
- **Hooks directory**: `.worktrees/hooks` is auto-symlinked by `_symlink_hooks` in `wt.sh`
- **Parallelism control**: pass fewer story numbers to limit concurrent sessions
- **Permissions**: `.claude/settings.json` is git-tracked — all worktrees inherit
  tool permissions automatically
- **`.worktrees/` is gitignored** — hook changes do not appear in `git status`
