# Sprint 4 Retrospective

**Date:** 2026-02-16
**Sprint Goal:** Fix core reliability issues, improve existing branch UX, and polish init/clear workflows
**Period:** 2026-02-09 — 2026-02-22

## Metrics

| Metric | Value |
|--------|-------|
| Velocity | 18 pts |
| Commitment accuracy | 100% (18/18 pts) |
| Completion rate | 100% (6/6 stories) |
| Avg points/story | 3.0 |
| Rolling velocity | 16.5 pts (previous: 16.0) |

## Stories Delivered

| Story | Title | Points | Completed |
|-------|-------|--------|-----------|
| STORY-023 | Add --from/-b flag to wt -n for custom base branch | 2 | 2026-02-11 |
| STORY-024 | Fix race condition in concurrent worktree creation | 3 | 2026-02-13 |
| STORY-025 | Improve UX when opening worktree from existing branch | 5 | 2026-02-13 |
| STORY-026 | Remove worktreesDir from config, always auto-derive path | 3 | 2026-02-13 |
| STORY-022 | Improve wt --init worktrees path prompt | 2 | 2026-02-15 |
| STORY-015 | Add more granular clear options | 3 | 2026-02-15 |

## What Went Well

- **Fast turnaround** — All 6 stories completed by Feb 15, a full week before the Feb 22 sprint end. Two delivery clusters: Feb 11-13 (4 stories, 13 pts) and Feb 15 (2 stories, 5 pts).
- **Velocity increase** — 18 pts is the highest velocity across all sprints, up from the 16.0 rolling average. Steady upward trend: 14 → 17 → 17 → 18.
- **100% delivery** — Perfect commitment accuracy for the 4th consecutive sprint. All stories completed, no carryover.

## What to Improve

- **No automated retrospective** — Sprint closure was manual until now. The `/retrospective` workflow was created during this retro to formalize the process going forward.
- **Over-commitment gap** — `committed_points` was originally 20 but actual story points sum to 18, indicating a story was descoped or re-estimated mid-sprint. Should track scope changes explicitly.
- **Backlog grooming** — STORY-021 (Improve wt --init UX) has been sitting in the backlog since initial sprint planning and hasn't been prioritized into any sprint. Needs a decision: pull in, rewrite, or drop.

## Action Items

- [ ] Groom backlog before Sprint 5 — review STORY-021 and decide: pull into Sprint 5, rewrite scope, or drop
- [ ] Run `/retrospective` consistently at each sprint end to maintain the practice
