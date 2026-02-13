---
name: Sprint Orchestrator
description: >
  This skill should be used when the user asks to "run sprint", "execute stories",
  "orchestrate sprint", "run stories sequentially", "execute sprint plan",
  "uruchom sprint", "wykonaj stories sekwencyjnie", or wants sequential automated
  execution of sprint stories with Dev and QA sub-agents.
  Accepts optional story IDs as arguments (e.g., "24 25 26").
version: 0.1.0
---

# Sprint Orchestrator

Sequential sprint orchestrator. Complement to `launch-sprint` (parallel). Executes
stories one-by-one within a single Claude session using Dev and QA sub-agents via the
Task tool. Each story merges to main after completion so the next story branches from
an updated codebase.

## Arguments

Optional story IDs from skill arguments. Accepted formats:

- Space-separated: `24 25 26`
- Comma-separated: `24, 25, 26`
- With prefix: `STORY-024 STORY-025`
- Mixed: `24, STORY-025, 26`

Normalize all to `STORY-XXX` format (zero-padded to 3 digits).

**Without arguments:** execute all pending stories from the active sprint in
implementation order.

## Phase 0: Sprint Assessment

1. Read `.bmad/sprint-status.yaml` to find the active sprint and its stories
2. Read `references/sprint-plan.md` (bundled with this skill) to get:
   - Implementation order for the active sprint
   - Branch names from the Sprint Story Map / Branch Mapping table
   - Story details and dependency chains
3. Build execution list:
   - If arguments provided: filter to only those stories
   - If no arguments: all stories with status != `completed`
   - Order by implementation order from the sprint plan
   - Skip completed stories
   - Check dependency chains (blocked stories cannot execute before their blockers)
4. **Worktree detection**:
   - Run: `git rev-parse --show-toplevel` and `git worktree list --porcelain`
   - If the current directory is a linked worktree (not the main working tree):
     - Set `WORKTREE_MODE=true`
     - Skip Step 1 (Branch Setup) — already on the correct branch in the worktree
     - In Step 6 (Finalize): commit but do NOT merge to main
       (user handles merges after all parallel stories complete)
5. Present execution plan to user and confirm before proceeding:

```
Sprint N — Execution Plan

Stories to execute (in order):
  1. STORY-024 (3pts) — Fix race condition in concurrent worktree creation
  2. STORY-025 (5pts) — Improve UX when opening worktree from existing branch
  ...

Total: X stories, Y points

Proceed? [confirm with user]
```

## Phase 1: Story Loop

For each pending story in implementation order:

### Step 1: Branch Setup

**Skip this step if `WORKTREE_MODE=true`** — the worktree is already on the correct branch.

```
git checkout main
git pull origin main
git checkout -b <branch-name>
```

Branch name: look up the story in the sprint plan's Branch Mapping table.
If not found, derive as `story-XXX/<kebab-title>`.

### Step 2: Cleanup

Delete stale reports from previous runs:

```
Glob(".ai/reports/STORY-XXX-*.md") → delete all matches
```

### Step 3: Story Doc

Verify `docs/stories/STORY-XXX.md` exists. If missing, invoke:

```
Skill(skill: "bmad:create-story", args: "STORY-XXX")
```

### Step 4: Dev Agent

Spawn a Dev sub-agent via the Task tool using the Developer Prompt Template
(see Agent Prompt Templates below).

```
continuation_num = 0
checkpoint_path = ""

LOOP (max 5 iterations):
  continuation_num += 1

  IF checkpoint_path is empty:
    prompt = DEVELOPER_PROMPT with {{STORY_ID}}, {{CONTINUATION_NUM}}
  ELSE:
    prompt = DEVELOPER_RESUME_PROMPT with {{STORY_ID}}, {{CHECKPOINT_PATH}}, {{CONTINUATION_NUM}}

  result = Task(
    description="Dev STORY-XXX pass #N",
    subagent_type="general-purpose",
    prompt=<constructed prompt>
  )

  Parse result:
    "DONE. Report:" → extract path, BREAK to Step 5
    "CONTINUE. Checkpoint:" → extract checkpoint_path, CONTINUE loop

  On crash (no signal):
    Glob(".ai/reports/STORY-XXX-dev-checkpoint-*.md")
    IF found → checkpoint_path = latest, CONTINUE
    IF not found → report BLOCKED, STOP entire orchestration

After 5 iterations without DONE:
  → Read last checkpoint, report BLOCKED with remaining work, STOP
```

### Step 5: QA Agent

Same loop pattern as Step 4, but using QA Prompt Templates.

```
continuation_num = 0
checkpoint_path = ""

LOOP (max 5 iterations):
  continuation_num += 1

  IF checkpoint_path is empty:
    prompt = QA_REVIEWER_PROMPT with {{STORY_ID}}, {{CONTINUATION_NUM}}
  ELSE:
    prompt = QA_RESUME_PROMPT with {{STORY_ID}}, {{CHECKPOINT_PATH}}, {{CONTINUATION_NUM}}

  result = Task(
    description="QA STORY-XXX pass #N",
    subagent_type="general-purpose",
    prompt=<constructed prompt>
  )

  Parse result:
    "DONE. Report:" → extract path, BREAK to Step 6
    "CONTINUE. Checkpoint:" → extract checkpoint_path, CONTINUE loop

  On crash / 5 iterations → same BLOCKED handling as Dev
```

### Step 6: Finalize

1. **Check QA report**: Read `.ai/reports/STORY-XXX-qa.md`
   - If "Issues Found and NOT Fixed" has entries (not "None") → STOP, report to user
2. **Stage & Commit**:
   - `git diff --name-only` to review changed files
   - Stage specific files (NOT `git add .` or `git add -A`)
   - Commit with conventional format per CLAUDE.md (no Co-Authored-By)
3. **Merge to main** — **skip if `WORKTREE_MODE=true`**:
   - `git checkout main`
   - `git merge <story-branch> --no-ff`
   - If merge conflict → STOP, report to user
   - `git branch -d <story-branch>`
4. **Update sprint-status.yaml** — **skip if `WORKTREE_MODE=true`**:
   - Set story status → `completed`
   - Set `completion_date` → today (YYYY-MM-DD)
   - Recalculate `completed_points` for the sprint
5. **Update story doc** (`docs/stories/STORY-XXX.md`):
   - Set Status field → `Completed`

### Step 7: Story Report

Print per-story completion summary:

```
STORY-XXX complete.
- Branch: <branch> → merged to main  (or "→ committed, merge deferred" in worktree mode)
- QA report: .ai/reports/STORY-XXX-qa.md
- Commit: <short-hash> — <message>
- Continuations: Dev=N, QA=M
```

Then proceed to the next story in the execution list.

## Phase 2: Sprint Report

After all stories are processed, print a summary table:

```
Sprint N — Execution Complete

| Story | Points | Result | Dev Passes | QA Passes |
|-------|--------|--------|------------|-----------|
| STORY-024 | 3 | completed | 1 | 1 |
| STORY-025 | 5 | completed | 2 | 1 |

Total: X/Y stories completed, Z points delivered
Sprint status: .bmad/sprint-status.yaml updated
```

## Error Handling

| Scenario | Action |
|----------|--------|
| QA report has unfixed issues | STOP, report to user |
| Merge conflict | STOP, report to user |
| Agent crash, no checkpoint | STOP, report BLOCKED |
| 5 continuations exhausted | STOP, report BLOCKED with remaining work |
| Story doc missing | Auto-create via `bmad:create-story` |
| Story not in branch mapping | Derive branch as `story-XXX/<kebab-title>` |

---

## Agent Prompt Templates

### Project-Specific Overrides

Include these overrides in ALL agent prompts (Dev and QA). They take precedence
over any conflicting instructions from the skills the agent invokes:

```
OVERRIDES (follow these instead of conflicting skill instructions):
  1. No commits — orchestrator handles commit after QA
  2. No sprint-status update — orchestrator handles after QA
  3. No Co-Authored-By lines (CLAUDE.md project convention)
  4. POSIX-compatible shell only in wt.sh and lib/*.sh (project convention)
  5. Scope discipline: only modify files that {{STORY_ID}} owns
  6. Use `npm test` to run tests (not raw bats command)
  7. Do NOT create documentation files unless story AC explicitly requires it
```

### Context Management Block

Include in ALL agent prompts:

```
CONTEXT MANAGEMENT
==================
You are continuation #{{CONTINUATION_NUM}} for this phase.

PROACTIVE SAVES (crash recovery):
After each major step, write/update your checkpoint file at
.ai/reports/{{STORY_ID}}-<phase>-checkpoint-{{CONTINUATION_NUM}}.md.
Overwrite the same file each time — save point, NOT a signal to stop.

CONTINUE SIGNAL (fresh context needed):
Return CONTINUE instead of DONE when ANY of these occur:
- System compression messages appear in the conversation
- You have made 40+ tool calls in this session
- You have gone through 3+ test-fix cycles
- You find yourself re-reading files you already read earlier

When returning CONTINUE:
1. Finish your current logical step
2. Write final checkpoint update
3. Return: CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-<phase>-checkpoint-{{CONTINUATION_NUM}}.md
```

### <<DEVELOPER_PROMPT>>

Construct this prompt for the first Dev agent pass:

```
STEP 1: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 2: Invoke the Skill tool:
  Skill(skill: "bmad:dev-story", args: "{{STORY_ID}}")
  This is your PRIMARY guide. It defines the full developer workflow.

STEP 3: Follow the skill's complete workflow (Parts 1-9).
  SKIP these parts (handled by the orchestrator or not applicable):
  - Part 3: branch creation (branch already exists)
  - Parts 4-5: web-app specific examples (this is a shell CLI project)
  - Part 8: browser testing (not applicable)

<< Insert Project-Specific Overrides block >>
<< Insert Context Management block (phase=dev) >>

REPORT
======
When finished, write a dev report to .ai/reports/{{STORY_ID}}-dev.md:

## {{STORY_ID}} Dev Report

### Files Changed
| File | Change Type | Description |
|------|-------------|-------------|

### Tests Added
| Test File | Test Name | What It Covers |
|-----------|-----------|----------------|

### Test Results
- Total tests: X / Passed: X / Failed: 0

### Shellcheck
- Clean: yes/no
- Issues fixed: (list)

### Notes
- Implementation decisions that deviated from story doc
- Ambiguities encountered

RETURN TO ORCHESTRATOR
======================
Return EXACTLY ONE signal:

If COMPLETE (all implementation done, tests pass, shellcheck clean):
  DONE. Report: .ai/reports/{{STORY_ID}}-dev.md

If you need FRESH CONTEXT:
  CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md
```

### <<DEVELOPER_RESUME_PROMPT>>

Construct this prompt when resuming Dev from a checkpoint:

```
STEP 1: Read the checkpoint file: {{CHECKPOINT_PATH}}
  This is your primary source of truth for what has been done and what remains.

STEP 2: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 3: Invoke the Skill tool:
  Skill(skill: "bmad:dev-story", args: "{{STORY_ID}}")
  Same SKIP list and OVERRIDES as initial Dev prompt apply.

STEP 4: Continue implementation from the checkpoint.
  - Read all files listed in checkpoint's "Files Modified So Far". VERIFY they match.
  - Do NOT redo completed work.
  - Respect all "Key Decisions Made" — do not contradict them.
  - Pay attention to "Warnings / Context for Next Agent".
  - Continue from "Current Step" and "Remaining Work".

<< Insert Project-Specific Overrides block >>
<< Insert Context Management block (phase=dev) >>

REPORT: Same format as initial Dev prompt. Cover ALL work across ALL continuations.

RETURN TO ORCHESTRATOR
======================
DONE. Report: .ai/reports/{{STORY_ID}}-dev.md
  — or —
CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md
```

### <<QA_REVIEWER_PROMPT>>

Construct this prompt for the first QA agent pass:

```
STEP 1: Read the dev report: .ai/reports/{{STORY_ID}}-dev.md
STEP 2: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 3: Invoke the Skill tool:
  Skill(skill: "qa-engineer")
  This is your PRIMARY guide for the QA workflow.

STEP 4: Follow the skill's workflow for:
  - AC audit against docs/stories/{{STORY_ID}}.md
  - Code quality review of all files in the dev report
  - Test coverage analysis
  Project-specific tools:
  - Test suite: npm test
  - Linter: shellcheck -x wt.sh lib/*.sh

FIX SCOPE
=========
Fix directly: style issues, missing quotes, POSIX violations, test gaps, minor bugs,
  missing edge case tests.
Report as "NOT Fixed": architectural changes, major logic rewrites, changes that
  contradict dev checkpoint "Key Decisions Made", adding/removing whole functions.

<< Insert Project-Specific Overrides block >>
<< Insert Context Management block (phase=qa) >>

REPORT
======
When finished, write a QA report to .ai/reports/{{STORY_ID}}-qa.md:

## {{STORY_ID}} QA Report

### Acceptance Criteria Checklist
- [x] AC 1 — code: <location>, test: <test name>

### Issues Found and Fixed
| # | Severity | Description | Fix Applied |
(Write "None" if no issues)

### Issues Found and NOT Fixed
| # | Severity | Description | Reason |
(Write "None" if all fixed)

### Code Quality
- POSIX compliance: pass/fail
- Style consistency: pass/fail
- Variable quoting: pass/fail
- Scope discipline: pass/fail

### Final Test Results
- Total tests: X / Passed: X / Failed: 0

### Final Shellcheck
- Clean: yes/no

RETURN TO ORCHESTRATOR
======================
DONE. Report: .ai/reports/{{STORY_ID}}-qa.md
  — or —
CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md
```

### <<QA_RESUME_PROMPT>>

Construct this prompt when resuming QA from a checkpoint:

```
STEP 1: Read the QA checkpoint file: {{CHECKPOINT_PATH}}
STEP 2: Read the dev report: .ai/reports/{{STORY_ID}}-dev.md
STEP 3: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 4: Invoke the Skill tool:
  Skill(skill: "qa-engineer")
  Same OVERRIDES and FIX SCOPE as initial QA prompt apply.

STEP 5: Continue QA review from the checkpoint.
  - Skip ACs already verified (check "AC Verification Progress").
  - Track issues already found (check "Issues Found So Far").
  - Continue from where the previous agent stopped.

<< Insert Project-Specific Overrides block >>
<< Insert Context Management block (phase=qa) >>

REPORT: Same format as initial QA prompt. Cover ALL work across ALL continuations.

DONE. Report: .ai/reports/{{STORY_ID}}-qa.md
  — or —
CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md
```

### Checkpoint File Format

Dev and QA checkpoints share this structure:

```markdown
## {{STORY_ID}} <Phase> Checkpoint #N

### Story Summary
<1-2 sentences>

### Completed Steps
- [x] Step 1: ...
- [ ] Step 4: (not started)

### Current Step
<In progress + partial notes>

### Files Modified So Far
| File | Change Type | Description |

### Remaining Work
- ...

### Key Decisions Made
<Choices that continuation agent MUST NOT contradict>

### Warnings / Context for Next Agent
<Gotchas, non-obvious patterns>
```

QA checkpoints add:

```markdown
### AC Verification Progress
| AC | Status | Code Location | Test Name |

### Issues Found So Far
| # | Severity | Description | Fix Applied | Status |

### Code Files Reviewed
- [x] lib/commands.sh — fully reviewed
- [ ] wt.sh — not yet reviewed
```

## References

- `references/sprint-plan.md` — Sprint allocations, implementation order, story details, dependency graph, branch mapping
- `.bmad/sprint-status.yaml` — Live sprint tracking data
