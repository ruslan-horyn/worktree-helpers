# Sprint 5 Retrospective

**Date:** 2026-02-19
**Sprint Goal:** Fix config detection bug, enhance developer experience with update mechanism and completions
**Period:** 2026-02-23 — 2026-02-19 (completed early)

## Metrics

| Metric | Value |
|--------|-------|
| Velocity | 18 pts |
| Commitment accuracy | 100% (18/18 pts) |
| Completion rate | 100% (5/5 stories) |
| Avg points/story | 3.6 |
| Rolling velocity | 18 pts (previous avg: 16.5) |

## Stories Delivered

| Story | Title | Points | Completed |
|-------|-------|--------|-----------|
| STORY-027 | Fix config detection fails when chpwd hooks output text | 3 | 2026-02-16 |
| STORY-013 | Add self-update mechanism (wt --update) | 5 | 2026-02-17 |
| STORY-014 | Add shell completions (bash + zsh) | 5 | 2026-02-17 |
| STORY-011 | Show dirty/clean status in wt -l | 3 | 2026-02-17 |
| STORY-028 | Fix zsh tab completions silently failing when wt.sh sourced before compinit | 2 | 2026-02-19 |

## What Went Well

- **Fast execution** — Sprint delivered ahead of schedule
- **STORY-028 resolved quickly** — Follow-up completions bug caught and fixed same sprint

## What to Improve

- **Follow-up bugs discovered post-merge** — STORY-028 was a regression from STORY-014;
  completions still don't work in Warp + zsh even though git completions work fine there
- **Insufficient real-world testing** — Bugs only surface when using the tool in real
  projects (imine-dashboard) with complex shell configurations
- **CI/CD reliability** — CI pipeline has issues that slow down the feedback loop

## Bugs & Improvements Discovered (Backlog for Sprint 6)

The following issues were discovered while using `wt` in a real project during Sprint 5:

### Critical
- **`wt -c` deleted main dev branch (`release-next`)** — clear should never delete
  protected branches (main, dev, mainRef, devRef from config)

### High Priority
- **Completions broken in Warp + zsh** — Tab completions don't work in Warp even though
  git completions work fine. Completions should match git's behaviour: branch names offered
  for `wt -s <TAB>` / `wt -o <TAB>`, worktree names for `wt -r <TAB>`, flags after `wt <TAB>`
- **Branch names with slashes create subdirectories** — `bugfix/CORE-615-foo` creates
  `worktrees/bugfix/CORE-615-foo/` instead of `worktrees/bugfix-CORE-615-foo/`.
  Slashes in branch names should be replaced with `-` in the directory name.
- **`wt -l` shows full absolute path** — Should display only the worktree name (last
  path segment), not `/Users/ruslanhoryn/Projects/imine-dashboard_worktrees/feature-foo`

### Medium Priority
- **`wt --update` requires terminal restart** — After self-update, new version is not
  active until the shell is restarted. Should prompt the user to re-source `wt.sh`.
- **`wt -c` gives no feedback** — Clear command doesn't explain what it's doing or why
  it fails; needs verbose output/logging
- **`wt --init` lacks verbose feedback** — Init command should print step-by-step
  progress (creating config, setting up hooks, etc.)
- **`wt --init` should offer to copy existing hooks** — If a hooks directory already
  exists in the repo, init should ask the user whether to copy/back them up rather
  than silently overwriting or skipping
- **Completions: show example usage when nothing to suggest** — For arguments where
  dynamic completion isn't possible (e.g., `wt -n <TAB>`), instead of showing nothing,
  display an example value as a hint, e.g., `wt -n feature-foo`
- **Per-command help** — Each command should support `wt -n --help` (or `wt help -n`)
  showing: description of the command, full usage syntax, and concrete usage examples
- **Descriptive usage with placeholders in command output** — When a command runs or
  shows usage, display concrete examples with real placeholders, not just flag names:
  ```
  -n, --new <branch>              Create worktree from main (or --from ref)
  wt -n feature-foo               Create worktree from main
  wt -n feature-foo --from <ref>  Create worktree from specific branch
  ```

## Action Items

- [ ] Create story: protect main/dev branches from `wt -c` deletion (critical safety bug)
- [ ] Create story: fix completions in Warp + zsh to work like git (branch/worktree name completion)
- [ ] Create story: completions — show example usage hint when no dynamic suggestions available
- [ ] Create story: per-command help (`wt <cmd> --help`) with description, usage, and examples
- [ ] Create story: improve usage output — show concrete examples with placeholders alongside flag descriptions
- [ ] Create story: replace slashes with dashes in worktree directory names
- [ ] Create story: show only worktree name in `wt -l` path display
- [ ] Create story: prompt to re-source after `wt --update`
- [ ] Create story: add verbose feedback to `wt -c` and `wt --init`
- [ ] Create story: `wt --init` — offer to copy/backup existing hooks
- [ ] Add completions integration tests to prevent regressions
- [ ] Investigate CI/CD reliability issues before Sprint 6
