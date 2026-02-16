---
name: retrospective
description: >
  This skill should be used when the user asks to "run retrospective", "sprint retro",
  "close sprint", "review sprint", "what went well", "sprint review", "finish sprint",
  or wants to analyze a completed sprint's metrics, capture learnings, and formally
  close it. Accepts an optional sprint number as argument (e.g., "4").
version: 1.0.0
---

# Sprint Retrospective

Analyze sprint metrics, capture learnings (what went well / what to improve), define
action items, generate a retrospective document, and close the sprint.

## Usage

```
/retrospective 4
/retrospective          # auto-detect active or most recently completed sprint
```

## Argument Parsing

Optional sprint number from skill arguments. Accepted formats:

- Bare number: `4`
- With prefix: `Sprint 4`, `sprint-4`

If no argument: use the sprint with `status: "active"`. If no active sprint, use the
most recent `status: "completed"` sprint.

## Workflow

### Step 1: Load Sprint Data

1. Read `.bmad/sprint-status.yaml`
2. Identify target sprint (from argument or auto-detect)
3. Extract all stories, points, dates, and velocity data
4. Verify the sprint has work to review (at least 1 completed story)

Present summary:

```
Sprint N Retrospective — "{sprint_goal}"
Period: {start_date} to {end_date}
Stories: {completed}/{total} completed
Points: {completed_points}/{committed_points} delivered
```

### Step 2: Compute Metrics

Calculate and present:

| Metric | Value |
|--------|-------|
| **Velocity** | {completed_points} pts |
| **Commitment accuracy** | {completed_points}/{committed_points} = X% |
| **Completion rate** | {stories_completed}/{stories_total} = X% |
| **Avg points/story** | {completed_points}/{stories_completed} |
| **Rolling velocity** | Compare to previous sprints from `velocity` section |

**Velocity trend:** Compare current sprint velocity to the rolling average.
Flag if it deviates by more than 20% in either direction.

**Estimation analysis:** For each completed story, compare points to actual
complexity (based on story count, blocked-by chains, completion order).

### Step 3: Facilitate Retrospective

Use AskUserQuestion to gather input on each category:

**Question 1 — What went well?**
Offer 3-4 options based on sprint data analysis (e.g., "All stories completed",
"Good velocity", "No blockers"), plus free text via "Other".

**Question 2 — What to improve?**
Offer 3-4 options based on patterns spotted (e.g., "Estimation accuracy",
"Story dependencies", "Scope creep"), plus free text.

**Question 3 — Action items for next sprint?**
Offer 2-3 concrete suggestions based on the "improve" answers, plus free text.

### Step 4: Generate Retrospective Document

Save to: `docs/retrospectives/sprint-{N}-retro.md`

Template:

```markdown
# Sprint {N} Retrospective

**Date:** {today}
**Sprint Goal:** {sprint_goal}
**Period:** {start_date} — {end_date}

## Metrics

| Metric | Value |
|--------|-------|
| Velocity | {X} pts |
| Commitment accuracy | {X}% ({completed}/{committed} pts) |
| Completion rate | {X}% ({completed_stories}/{total_stories} stories) |
| Avg points/story | {X} |
| Rolling velocity | {X} pts (previous: {prev_avg}) |

## Stories Delivered

| Story | Title | Points | Completed |
|-------|-------|--------|-----------|
{for each completed story}
| {story_id} | {title} | {points} | {completion_date} |
{end for}

{if incomplete stories}
## Stories Not Completed

| Story | Title | Points | Status | Reason |
|-------|-------|--------|--------|--------|
{for each incomplete story}
{end for}
{end if}

## What Went Well

{user answers from Step 3}

## What to Improve

{user answers from Step 3}

## Action Items

{user answers from Step 3, formatted as checklist}
- [ ] {action item 1}
- [ ] {action item 2}
```

### Step 5: Close Sprint

1. **Update `.bmad/sprint-status.yaml`:**
   - Set sprint `status` → `"completed"`
   - Set `end_date` → today (if different from planned)
   - Recalculate `completed_points` to match actual story totals
   - Update `velocity.sprint_{N}` with actual velocity
   - Recalculate `rolling_average` from all completed sprints

2. **Update sprint plan doc** (path from `sprint_plan_path`):
   - Mark sprint as completed in the plan document if it has a status section

3. Present the updates:

```
Sprint {N} closed.
  Status: completed
  Velocity: {X} pts (rolling avg: {Y})
  Retro doc: docs/retrospectives/sprint-{N}-retro.md

  Next sprint: Sprint {N+1} — {goal}
  To start: /launch-sprint
```

## Key Details

- **Single data source:** `.bmad/sprint-status.yaml` — all metrics derived from here
- **Retrospective docs:** `docs/retrospectives/sprint-{N}-retro.md`
- **Velocity tracking:** Update both `velocity.sprint_{N}` and `rolling_average`
- **Sprint closure:** Setting `status: "completed"` is the formal close action
- **Incomplete stories:** If stories remain, note them but still close the sprint.
  Incomplete stories should be moved to the next sprint during `/sprint-planning`.

## Error Handling

| Scenario | Action |
|----------|--------|
| No active sprint found | Check for most recent completed sprint, or ask user for sprint number |
| Sprint has 0 completed stories | Warn user, offer to close anyway or abort |
| Retrospective doc already exists | Ask user: overwrite or create versioned copy |
| sprint-status.yaml missing | Direct user to run `/sprint-planning` first |
