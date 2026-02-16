---
name: sprint-orchestrator
description: >
  This skill should be used when the user asks to "run sprint", "execute stories",
  "orchestrate sprint", "run stories sequentially", "execute sprint plan",
  "uruchom sprint", "wykonaj stories sekwencyjnie", or wants sequential automated
  execution of sprint stories with Dev and QA sub-agents.
  Accepts optional story IDs as arguments (e.g., "24 25 26").
version: 1.0.0
---

# Sprint Orchestrator

Sequential story executor. Run stories one-by-one using Dev and QA sub-agents via
the Task tool. All progress is tracked directly in the story doc — no separate
report files. The orchestrator acts as a message relay between agents and the user.

## Arguments

Optional story IDs from skill arguments. Accepted formats:

- Space-separated: `24 25 26`
- Comma-separated: `24, 25, 26`
- With prefix: `STORY-024 STORY-025`
- Mixed: `24, STORY-025, 26`

Normalize all to `STORY-XXX` format (zero-padded to 3 digits).

**Without arguments:** execute all pending stories from the active sprint.

## Phase 0: Sprint Assessment

1. Read `.bmad/sprint-status.yaml` to find the active sprint and its stories
2. Build execution list:
   - If arguments provided: filter to only those stories
   - If no arguments: all stories with status != `completed`
   - Skip completed stories
   - Check dependency chains (blocked stories cannot execute before their blockers)
3. **Worktree detection**:
   - Run: `git rev-parse --show-toplevel` and `git worktree list --porcelain`
   - If current directory is a linked worktree (not the main working tree):
     - Set `WORKTREE_MODE=true`
     - Skip branch creation in Step 1 — already on the correct branch
     - In Finalize: commit but do NOT merge to main (user handles merges)
     - sprint-status.yaml update is STILL mandatory
4. **Proceed without confirmation** — present the plan and start immediately:

```
Sprint N — Executing:
  1. STORY-024 (3pts) — Fix race condition
  2. STORY-025 (5pts) — Improve UX
Total: X stories, Y points
```

## Phase 1: Story Loop

For each pending story in order:

### Step 1: Branch Setup

**Skip if `WORKTREE_MODE=true`.**

```
git checkout main && git pull origin main
git checkout -b story-XXX-<kebab-title>
```

Branch naming: `story-XXX-<kebab-title>` — NO slashes.

### Step 2: Story Doc

Verify `docs/stories/STORY-XXX.md` exists. If missing, spawn a Story Creator agent:

```
Task(
  description="Create story doc STORY-XXX",
  subagent_type="general-purpose",
  prompt="Invoke the Skill tool FIRST: Skill(skill: \"bmad:create-story\", args: \"STORY-XXX\"). Follow the skill's workflow to create the story document."
)
```

### Step 3: Dev Agent

Spawn a Dev sub-agent via the Task tool.

```
result = Task(
  description="Dev STORY-XXX",
  subagent_type="general-purpose",
  prompt=<<DEV_PROMPT>>
)
```

**Message relay:** If the agent result contains a question or request for
confirmation, forward it to the user via AskUserQuestion, then resume the agent
with the user's answer.

Parse result:
- `DONE` → proceed to Step 4
- `BLOCKED: <reason>` → report to user, STOP

### Step 4: QA Code Review Agent

Spawn a QA sub-agent for code review.

```
result = Task(
  description="QA review STORY-XXX",
  subagent_type="general-purpose",
  prompt=<<QA_REVIEW_PROMPT>>
)
```

Parse result:
- `DONE. No issues.` → proceed to Step 5
- `DONE. Issues found.` → read updated story doc, spawn a **Dev Fix Agent**:
  ```
  Task(
    description="Dev fix STORY-XXX",
    subagent_type="general-purpose",
    prompt=<<DEV_FIX_PROMPT>>
  )
  ```
  After fix agent completes, re-run QA (max 2 QA-fix cycles). If issues persist
  after 2 cycles → report to user, STOP.

### Step 5: QA Manual Testing Agent (conditional)

If the story introduces **new user-facing functionality** (check AC in story doc):

```
result = Task(
  description="QA manual test STORY-XXX",
  subagent_type="general-purpose",
  prompt=<<QA_MANUAL_PROMPT>>
)
```

If no new user-facing functionality → skip this step.

### Step 6: Finalize

1. **Stage & Commit**:
   - `git diff --name-only` to review changed files
   - Stage specific files (NOT `git add .`)
   - Commit with conventional format per CLAUDE.md (no Co-Authored-By)
2. **Merge to main** — **skip if `WORKTREE_MODE=true`**:
   - `git checkout main && git merge <branch> --no-ff`
   - If merge conflict → STOP, report to user
   - `git branch -d <branch>`
3. **Update sprint-status.yaml** (ALWAYS — including worktree mode):
   - Set story status → `completed`, `completion_date` → today
   - Recalculate `completed_points`
4. **Update story doc**: Set Status → `Completed`

### Step 7: Story Report

```
STORY-XXX complete.
- Branch: <branch> → merged to main (or "merge deferred" in worktree mode)
- Commit: <short-hash> — <message>
```

## Phase 2: Sprint Report

```
Sprint N — Complete
| Story | Points | Result |
|-------|--------|--------|
| STORY-024 | 3 | completed |
Total: X/Y stories, Z points
```

## Orchestrator Rules

1. **Message relay**: Always forward agent questions/confirmations to the user.
   If an agent asks something, use AskUserQuestion to get the answer.
2. **No separate reports**: All progress written to the story doc by agents.
3. **Auto-proceed**: Do not ask user for confirmation to start execution.
   Just present the plan and go.
4. **Branch naming**: NO slashes — `story-XXX-<kebab-title>`.

## Error Handling

| Scenario | Action |
|----------|--------|
| QA issues persist after 2 fix cycles | STOP, report to user |
| Merge conflict | STOP, report to user |
| Agent crash | Report BLOCKED, STOP |
| Story doc missing | Spawn Story Creator agent with `Skill(skill: "bmad:create-story")` |

---

## Agent Prompt Templates

### Project-Specific Overrides

Include in ALL agent prompts:

```
OVERRIDES:
  1. No commits — orchestrator handles commit after QA
  2. No sprint-status update — orchestrator handles
  3. No Co-Authored-By lines (CLAUDE.md convention)
  4. POSIX-compatible shell only in wt.sh and lib/*.sh
  5. Scope discipline: only modify files that {{STORY_ID}} owns
  6. Use `npm test` to run tests
  7. Do NOT create separate report files — write all progress to docs/stories/{{STORY_ID}}.md
```

### <<DEV_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "bmad:dev-story", args: "{{STORY_ID}}")
  This is your PRIMARY workflow guide.

STEP 2: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 3: Follow the skill's workflow.
  SKIP: branch creation (handled by orchestrator), web-app examples, browser testing.

PROGRESS TRACKING:
  Update the "## Progress Tracking" section in docs/stories/{{STORY_ID}}.md as
  you work. After each major step, add/update entries:
  - Files changed (with change type and description)
  - Tests added
  - Test results
  - Decisions made

<< Project-Specific Overrides >>

RETURN TO ORCHESTRATOR:
  DONE — when all implementation done, tests pass, shellcheck clean.
  BLOCKED: <reason> — when you cannot proceed.
```

### <<DEV_FIX_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "bmad:dev-story", args: "{{STORY_ID}}")

STEP 2: Read docs/stories/{{STORY_ID}}.md — focus on the "## QA Review" section.
  It contains issues found by QA with severity, description, and file locations.

STEP 3: Fix each issue listed. Do NOT fix items marked as "won't fix" or
  "architectural" — those require user decision.

STEP 4: Run tests: `npm test`. Run linter: `shellcheck -x wt.sh lib/*.sh`.

STEP 5: Update the story doc — mark fixed issues in the QA Review section.

<< Project-Specific Overrides >>

RETURN: DONE
```

### <<QA_REVIEW_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "qa-engineer")
  This is your PRIMARY workflow guide.

STEP 2: Read docs/stories/{{STORY_ID}}.md — understand AC and implementation.

STEP 3: Review all changed files (check git diff or the Progress Tracking section).
  For each file:
  - Check POSIX compliance, style, variable quoting
  - Verify AC coverage
  - Check test coverage

STEP 4: Run tests: `npm test`. Run linter: `shellcheck -x wt.sh lib/*.sh`.

STEP 5: Write findings to docs/stories/{{STORY_ID}}.md in a new "## QA Review"
  section (append, do not overwrite existing content):

  ## QA Review

  ### Files Reviewed
  | File | Status | Notes |
  |------|--------|-------|

  ### Issues Found
  | # | Severity (critical/major/minor) | File | Description | Status |
  (Write "None" if no issues)

  ### AC Verification
  - [x] AC 1 — verified: <location>, test: <test name>

  ### Test Results
  - Total: X / Passed: X / Failed: 0

  ### Shellcheck
  - Clean: yes/no

<< Project-Specific Overrides >>

RETURN:
  DONE. No issues. — when everything passes.
  DONE. Issues found. — when issues are written to the story doc.
```

### <<QA_MANUAL_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "qa-engineer")

STEP 2: Read docs/stories/{{STORY_ID}}.md — focus on AC and user-facing behavior.

STEP 3: Perform manual testing:
  - Source `wt.sh` and exercise the new/changed commands
  - Test happy paths from AC
  - Test edge cases mentioned in Technical Notes
  - Test error handling (invalid input, missing deps)

STEP 4: Append results to docs/stories/{{STORY_ID}}.md in a "## Manual Testing"
  section:

  ## Manual Testing

  ### Test Scenarios
  | # | Scenario | Expected | Actual | Pass/Fail |
  |---|----------|----------|--------|-----------|

  ### Issues Found
  | # | Severity | Description | Steps to Reproduce |
  (Write "None" if no issues)

<< Project-Specific Overrides >>

RETURN:
  DONE. No issues. — all manual tests pass.
  DONE. Issues found. — issues written to story doc.
```

## References

- `.bmad/sprint-status.yaml` — Live sprint tracking data
- `docs/stories/STORY-XXX.md` — Single source of truth for each story
