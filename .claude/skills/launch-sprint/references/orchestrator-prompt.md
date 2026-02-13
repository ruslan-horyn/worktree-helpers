# Multi-Agent Sprint Story: $ARGUMENTS

> `{{STORY_ID}}` = `$ARGUMENTS` throughout this document.

## Orchestrator Instructions

You are a **thin orchestrator**. You delegate all work to subagents via the `Task` tool. You do NOT read files, run commands, analyze code, or summarize anything. Your only job is to spawn agents in sequence, detect DONE/CONTINUE signals, and re-spawn fresh agents when context runs low.

### Signal Protocol

Every agent returns exactly one of two signals:

- `DONE. Report: <path>` — phase complete, proceed to next phase
- `CONTINUE. Checkpoint: <path>` — agent needs fresh context, re-spawn with checkpoint

If an agent crashes (no signal returned), check for checkpoint files on disk and resume from the latest one.

### Flow

```
1. Phase 0 — Prerequisite check (orchestrator)
2. Phase 1 — Developer loop (max 5 continuations)
3. Phase 2 — QA Reviewer loop (max 5 continuations)
4. Phase 3 — Finalize: commit, update status (orchestrator, no agent)
5. Phase 4 — Report completion
```

### Execution Mode

Default: **autonomous** — all phases run without user input.

If the orchestrator prompt includes `{{INTERACTIVE_MODE}}=true`:

- After each phase completes (Dev DONE, QA DONE), pause and ask the user:
  `"<Phase> complete. Report: <path>. Proceed to next phase?"`
- User can review the report before continuing
- If user says no → report current status and STOP

When running without `{{INTERACTIVE_MODE}}` (or when it is `false`), phases proceed automatically.

### Phase 0: Prerequisite Check & Safety

Before spawning any agent:

```
1. Branch verification:
   current_branch = `git branch --show-current`
   expected_branch = look up {{STORY_ID}} in Sprint Story Map below
   IF current_branch != expected_branch:
     → WARN user: "Expected branch <expected_branch> for {{STORY_ID}}, but on <current_branch>"
     → STOP. Do NOT auto-switch branches.

2. Stale report cleanup:
   stale_files = Glob(".ai/reports/{{STORY_ID}}-*.md")
   IF any found → delete all matches.
   This prevents stale data from a previous run from contaminating this one.

3. Story doc check:
   Glob("docs/stories/{{STORY_ID}}.md")
   - If missing → run /create-story {{STORY_ID}} to generate it, then proceed
   - If exists → proceed to Phase 1
```

### Phase 1: Developer Loop

```
continuation_num = 0
checkpoint_path = ""
dev_continuations = 0

LOOP (max 5 iterations):
  continuation_num += 1
  dev_continuations += 1

  IF checkpoint_path is empty:
    # First pass — use initial prompt
    result = Task(
      description="Dev {{STORY_ID}} pass #<continuation_num>",
      subagent_type="general-purpose",
      prompt=<<DEVELOPER_PROMPT with {{STORY_ID}}, {{CONTINUATION_NUM}}=continuation_num substituted>>
    )
  ELSE:
    # Continuation — use resume prompt
    result = Task(
      description="Dev {{STORY_ID}} pass #<continuation_num>",
      subagent_type="general-purpose",
      prompt=<<DEVELOPER_RESUME_PROMPT with {{STORY_ID}}, {{CHECKPOINT_PATH}}, {{CONTINUATION_NUM}}=continuation_num substituted>>
    )

  Parse result:
    IF result contains "DONE. Report:":
      → extract report path
      → Report to user: "Phase 1 Dev pass #<continuation_num>: DONE — <report_path>"
      → IF INTERACTIVE_MODE: ask user "Dev phase complete. Report: <path>. Proceed to QA?"
        IF no → STOP
      → BREAK loop, proceed to Phase 2
    IF result contains "CONTINUE. Checkpoint:":
      → extract checkpoint_path
      → Report to user: "Phase 1 Dev pass #<continuation_num>: CONTINUE — <checkpoint_path>"
      → CONTINUE loop

  On crash (no signal returned):
    → Glob(".ai/reports/{{STORY_ID}}-dev-checkpoint-*.md")
    → IF found: checkpoint_path = latest numbered checkpoint, CONTINUE loop
    → IF not found:
        Report BLOCKED with summary:
        "{{STORY_ID}} BLOCKED at Dev phase (crash, no checkpoint found).
         No checkpoint on disk — Dev agent may not have started or crashed before first save."
        → STOP

After 5 iterations without DONE:
  → Read last checkpoint file at checkpoint_path
  → Report BLOCKED with summary:
    "{{STORY_ID}} BLOCKED at Dev phase after 5 continuations.
     Last checkpoint: <checkpoint_path>
     Remaining work: <summary from checkpoint's Remaining Work section>"
  → STOP
```

### Phase 2: QA Reviewer Loop

```
continuation_num = 0
checkpoint_path = ""
qa_continuations = 0

LOOP (max 5 iterations):
  continuation_num += 1
  qa_continuations += 1

  IF checkpoint_path is empty:
    # First pass — use initial prompt
    result = Task(
      description="QA {{STORY_ID}} pass #<continuation_num>",
      subagent_type="general-purpose",
      prompt=<<QA_REVIEWER_PROMPT with {{STORY_ID}}, {{CONTINUATION_NUM}}=continuation_num substituted>>
    )
  ELSE:
    # Continuation — use resume prompt
    result = Task(
      description="QA {{STORY_ID}} pass #<continuation_num>",
      subagent_type="general-purpose",
      prompt=<<QA_RESUME_PROMPT with {{STORY_ID}}, {{CHECKPOINT_PATH}}, {{CONTINUATION_NUM}}=continuation_num substituted>>
    )

  Parse result:
    IF result contains "DONE. Report:":
      → extract report path
      → Report to user: "Phase 2 QA pass #<continuation_num>: DONE — <report_path>"
      → IF INTERACTIVE_MODE: ask user "QA phase complete. Report: <path>. Proceed to finalize?"
        IF no → STOP
      → BREAK loop, proceed to Phase 3
    IF result contains "CONTINUE. Checkpoint:":
      → extract checkpoint_path
      → Report to user: "Phase 2 QA pass #<continuation_num>: CONTINUE — <checkpoint_path>"
      → CONTINUE loop

  On crash (no signal returned):
    → Glob(".ai/reports/{{STORY_ID}}-qa-checkpoint-*.md")
    → IF found: checkpoint_path = latest numbered checkpoint, CONTINUE loop
    → IF not found:
        Report BLOCKED with summary:
        "{{STORY_ID}} BLOCKED at QA phase (crash, no checkpoint found).
         No checkpoint on disk — QA agent may not have started or crashed before first save."
        → STOP

After 5 iterations without DONE:
  → Read last checkpoint file at checkpoint_path
  → Report BLOCKED with summary:
    "{{STORY_ID}} BLOCKED at QA phase after 5 continuations.
     Last checkpoint: <checkpoint_path>
     Remaining work: <summary from checkpoint's Remaining Work section>"
  → STOP
```

### Phase 3: Finalize (Orchestrator — no agent)

After QA DONE:

```
1. Read QA report (.ai/reports/{{STORY_ID}}-qa.md)
   - If "Issues Found and NOT Fixed" has entries → STOP, report BLOCKED

2. Stage & Commit:
   - git diff --name-only to review changed files
   - Stage specific files (NOT git add . or git add -A)
   - Commit with conventional format per CLAUDE.md
   - No Co-Authored-By, no push

3. Update sprint status (.bmad/sprint-status.yaml):
   - Set story status: "completed"
   - Set completion_date: today (YYYY-MM-DD)
   - Recalculate sprint completed_points

4. Update story doc (docs/stories/{{STORY_ID}}.md):
   - Set Status field to "Completed"
   - Update Progress Tracking: add completion date
```

### Phase 4: Report to User

Tell the user:

```
{{STORY_ID}} complete.

- QA report: .ai/reports/{{STORY_ID}}-qa.md
- Commit: <short hash> — <commit message>
- Sprint status updated: .bmad/sprint-status.yaml
- Story doc updated: docs/stories/{{STORY_ID}}.md

Continuations used: Dev={{dev_continuations}}, QA={{qa_continuations}} (total: {{dev_continuations + qa_continuations}} agent sessions)
```

Do NOT read or summarize reports — just point the user to the files and the continuation summary.

---

## Agent Role Definitions

### <<DEVELOPER_PROMPT>>

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

OVERRIDES (these contradict specific skill instructions — follow these instead):
  1. No commits (contradicts skill Part 10) — orchestrator handles commit in Phase 3
  2. No sprint-status update (contradicts skill Part 10) — orchestrator handles in Phase 3
  3. No Co-Authored-By lines (CLAUDE.md project convention)
  4. POSIX-compatible shell only in wt.sh and lib/*.sh (project convention)
  5. Scope discipline: only modify files that {{STORY_ID}} owns (parallel branch safety)
  6. Use `npm test` to run tests (not raw bats command)
  7. Do NOT create documentation files unless story AC explicitly requires it

CONTEXT MANAGEMENT
==================
You are continuation #{{CONTINUATION_NUM}} for the Dev phase of this story.

PROACTIVE SAVES (crash recovery):
After each major step (finishing one component, writing tests for one module), write/update
your checkpoint file at .ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md.
Overwrite the same file each time — this is a save point, NOT a signal to stop.
This ensures crash recovery always has a recent checkpoint on disk.

CONTINUE SIGNAL (fresh context):
Return CONTINUE (instead of DONE) when ANY of these occur:
- System compression messages appear in the conversation
- You have made 40+ tool calls in this session
- You have gone through 3+ test-fix cycles
- You find yourself re-reading files you already read earlier
- You feel uncertain about details from earlier in the conversation

When returning CONTINUE:
1. Finish your current logical step
2. Write final checkpoint update
3. Return: CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md

REPORT
======
When finished, write a dev report to .ai/reports/{{STORY_ID}}-dev.md with this format:

## {{STORY_ID}} Dev Report

### Files Changed
| File | Change Type | Description |
|------|-------------|-------------|
| ... | modified/new | ... |

### Tests Added
| Test File | Test Name | What It Covers |
|-----------|-----------|----------------|
| ... | ... | ... |

### Test Results
- Total tests: X
- Passed: X
- Failed: 0

### Shellcheck
- Clean: yes/no
- Issues fixed: (list any issues found and fixed)

### Notes
- Any implementation decisions that deviated from the story doc
- Any ambiguities encountered

RETURN TO ORCHESTRATOR
======================
Return EXACTLY ONE of these signals:

If phase is COMPLETE (all implementation done, tests pass, shellcheck clean):
  DONE. Report: .ai/reports/{{STORY_ID}}-dev.md

If you need a FRESH CONTEXT to continue (see CONTEXT MANAGEMENT triggers):
  CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md
```

---

### <<QA_REVIEWER_PROMPT>>

```
STEP 1: Read the dev report: .ai/reports/{{STORY_ID}}-dev.md
STEP 2: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 3: Invoke the Skill tool:
  Skill(skill: "qa-engineer")
  This is your PRIMARY guide. It defines the full QA workflow.

STEP 4: Follow the skill's workflow for:
  - AC audit against docs/stories/{{STORY_ID}}.md
  - Code quality review of all files listed in the dev report
  - Test coverage analysis
  Project-specific tools:
  - Test suite: npm test
  - Linter: shellcheck -x wt.sh lib/*.sh

FIX SCOPE
=========
Fix directly: style issues, missing quotes, POSIX violations, test gaps, minor logic bugs,
  missing edge case tests.
Report as "NOT Fixed" (requires Dev re-run): architectural changes, major logic rewrites,
  changes that contradict the dev checkpoint's "Key Decisions Made", adding/removing
  whole functions.

OVERRIDES (same as Developer — these contradict specific skill instructions):
  1. No commits — orchestrator handles commit in Phase 3
  2. No sprint-status update — orchestrator handles in Phase 3
  3. No Co-Authored-By lines (CLAUDE.md project convention)
  4. POSIX-compatible shell only in wt.sh and lib/*.sh (project convention)
  5. Scope discipline: only modify files that {{STORY_ID}} owns (parallel branch safety)
  6. Use `npm test` to run tests (not raw bats command)
  7. Do NOT create documentation files unless story AC explicitly requires it

CONTEXT MANAGEMENT
==================
You are continuation #{{CONTINUATION_NUM}} for the QA phase of this story.

PROACTIVE SAVES (crash recovery):
After each major step (finishing AC audit, completing code quality review), write/update
your checkpoint file at .ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md.
Overwrite the same file each time — this is a save point, NOT a signal to stop.
This ensures crash recovery always has a recent checkpoint on disk.

CONTINUE SIGNAL (fresh context):
Return CONTINUE (instead of DONE) when ANY of these occur:
- System compression messages appear in the conversation
- You have made 40+ tool calls in this session
- You have gone through 3+ test-fix cycles while fixing issues
- You find yourself re-reading files you already read earlier
- You feel uncertain about details from earlier in the conversation

When returning CONTINUE:
1. Finish your current logical step
2. Write final checkpoint update
3. Return: CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md

REPORT
======
When finished, write a QA report to .ai/reports/{{STORY_ID}}-qa.md with this format:

## {{STORY_ID}} QA Report

### Acceptance Criteria Checklist
- [x] AC 1 — code: <location>, test: <test name>
- [x] AC 2 — code: <location>, test: <test name>
- ...

### Issues Found and Fixed
| # | Severity | Description | Fix Applied |
|---|----------|-------------|-------------|
| 1 | ... | ... | ... |

(Write "None" if no issues found)

### Issues Found and NOT Fixed
| # | Severity | Description | Reason |
|---|----------|-------------|--------|
| 1 | ... | ... | ... |

(Write "None" if all issues were fixed)

### Code Quality
- POSIX compliance: pass/fail
- Style consistency: pass/fail
- Variable quoting: pass/fail
- Scope discipline: pass/fail (only story-relevant files changed)

### Final Test Results
- Total tests: X
- Passed: X
- Failed: 0

### Final Shellcheck
- Clean: yes/no

RETURN TO ORCHESTRATOR
======================
Return EXACTLY ONE of these signals:

If phase is COMPLETE (all AC verified, issues fixed, tests pass, shellcheck clean):
  DONE. Report: .ai/reports/{{STORY_ID}}-qa.md

If you need a FRESH CONTEXT to continue (see CONTEXT MANAGEMENT triggers):
  CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md
```

---

### <<DEVELOPER_RESUME_PROMPT>>

```
STEP 1: Read the checkpoint file: {{CHECKPOINT_PATH}}
  This is your primary source of truth for what has been done and what remains.

STEP 2: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 3: Invoke the Skill tool:
  Skill(skill: "bmad:dev-story", args: "{{STORY_ID}}")
  This is your PRIMARY guide. Same SKIP list and OVERRIDES as the initial Dev prompt apply:
  SKIP: Parts 3, 4-5, 8 (branch creation, web-app examples, browser testing)
  OVERRIDES: no commits, no sprint-status update, no Co-Authored-By, POSIX only,
    scope discipline, `npm test`, no unnecessary docs

STEP 4: Continue implementation from the checkpoint.
  - Read all files listed in the checkpoint's "Files Modified So Far" table. VERIFY they match.
  - Do NOT redo completed work.
  - Respect all "Key Decisions Made" from the checkpoint — do not contradict them.
  - Pay attention to "Warnings / Context for Next Agent".
  - Continue from the checkpoint's "Current Step" and "Remaining Work".

CONTEXT MANAGEMENT
==================
You are continuation #{{CONTINUATION_NUM}} for the Dev phase of this story.

PROACTIVE SAVES (crash recovery):
After each major step, write/update your checkpoint file at
.ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md.
Overwrite the same file each time — this is a save point, NOT a signal to stop.

CONTINUE SIGNAL (fresh context):
Return CONTINUE (instead of DONE) when ANY of these occur:
- System compression messages appear in the conversation
- You have made 40+ tool calls in this session
- You have gone through 3+ test-fix cycles
- You find yourself re-reading files you already read earlier
- You feel uncertain about details from earlier in the conversation

When returning CONTINUE:
1. Finish your current logical step
2. Write final checkpoint update
3. Return: CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md

REPORT
======
When ALL implementation is complete, write a FINAL dev report to
.ai/reports/{{STORY_ID}}-dev.md covering ALL work across ALL continuations.
Use the same format as the initial dev prompt's report template.

RETURN TO ORCHESTRATOR
======================
Return EXACTLY ONE of these signals:

If phase is COMPLETE (all implementation done, tests pass, shellcheck clean):
  DONE. Report: .ai/reports/{{STORY_ID}}-dev.md

If you need a FRESH CONTEXT to continue:
  CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-dev-checkpoint-{{CONTINUATION_NUM}}.md
```

---

### <<QA_RESUME_PROMPT>>

```
STEP 1: Read the QA checkpoint file: {{CHECKPOINT_PATH}}
  This tells you what has already been reviewed and what remains.

STEP 2: Read the dev report: .ai/reports/{{STORY_ID}}-dev.md

STEP 3: Read the story doc: docs/stories/{{STORY_ID}}.md

STEP 4: Invoke the Skill tool:
  Skill(skill: "qa-engineer")
  This is your PRIMARY guide. Same OVERRIDES as the initial QA prompt apply:
  OVERRIDES: no commits, no sprint-status update, no Co-Authored-By, POSIX only,
    scope discipline, `npm test`, no unnecessary docs

STEP 5: Continue QA review from the checkpoint.
  - Skip ACs already verified (check "AC Verification Progress" table).
  - Track issues already found (check "Issues Found So Far" table).
  - Continue from where the previous agent stopped.
  - Fix issues directly where appropriate (apply FIX SCOPE rules).

FIX SCOPE
=========
Fix directly: style issues, missing quotes, POSIX violations, test gaps, minor logic bugs,
  missing edge case tests.
Report as "NOT Fixed" (requires Dev re-run): architectural changes, major logic rewrites,
  changes that contradict the dev checkpoint's "Key Decisions Made", adding/removing
  whole functions.

CONTEXT MANAGEMENT
==================
You are continuation #{{CONTINUATION_NUM}} for the QA phase of this story.

PROACTIVE SAVES (crash recovery):
After each major step, write/update your checkpoint file at
.ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md.
Overwrite the same file each time — this is a save point, NOT a signal to stop.

CONTINUE SIGNAL (fresh context):
Return CONTINUE (instead of DONE) when ANY of these occur:
- System compression messages appear in the conversation
- You have made 40+ tool calls in this session
- You have gone through 3+ test-fix cycles while fixing issues
- You find yourself re-reading files you already read earlier

When returning CONTINUE:
1. Finish your current logical step
2. Write final checkpoint update
3. Return: CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md

REPORT
======
When ALL QA review is complete, write a FINAL QA report to
.ai/reports/{{STORY_ID}}-qa.md covering ALL work across ALL continuations.
Use the same format as the initial QA prompt's report template.

RETURN TO ORCHESTRATOR
======================
Return EXACTLY ONE of these signals:

If phase is COMPLETE (all AC verified, issues fixed, tests pass, shellcheck clean):
  DONE. Report: .ai/reports/{{STORY_ID}}-qa.md

If you need a FRESH CONTEXT to continue:
  CONTINUE. Checkpoint: .ai/reports/{{STORY_ID}}-qa-checkpoint-{{CONTINUATION_NUM}}.md
```

---

## Inter-Agent Communication

Agents communicate through report and checkpoint files on disk. The orchestrator only reads checkpoint paths from agent signals — it never reads file contents (except in Phase 3 to check for unfixed QA issues).

```
.ai/reports/{{STORY_ID}}-dev-checkpoint-N.md  ← Dev incremental progress (N = 1, 2, ...)
.ai/reports/{{STORY_ID}}-dev.md               ← Dev final report (covers ALL continuations)
.ai/reports/{{STORY_ID}}-qa-checkpoint-N.md   ← QA incremental progress (N = 1, 2, ...)
.ai/reports/{{STORY_ID}}-qa.md                ← QA final report (covers ALL continuations)
```

Each agent reads the previous agent's report file **directly from disk**. Resume agents read the checkpoint file from the previous continuation. The orchestrator only parses DONE/CONTINUE signals and passes checkpoint paths.

---

## Checkpoint File Format

### Developer Checkpoint

```markdown
## {{STORY_ID}} Dev Checkpoint #N

### Story Summary
<1-2 sentences describing what this story implements>

### Completed Steps
- [x] Step 1: Read story doc and source files
- [x] Step 2: Implemented _func_name in lib/commands.sh
- [x] Step 3: ...
- [ ] Step 4: (in progress or not started)

### Current Step
<Step currently in progress + partial progress notes, e.g.:
"Step 4: Writing BATS tests — completed happy path tests, need error case tests">

### Files Modified So Far
| File | Change Type | Description |
|------|-------------|-------------|
| lib/commands.sh | modified | Added _cmd_clear with --all/--stale flags |
| lib/utils.sh | modified | Added _is_stale helper |

### Files Still To Modify
| File | Change Needed |
|------|---------------|
| wt.sh | Add --clear routing to router |
| test/cmd_clear.bats | Write remaining test cases |

### Test Results So Far
- Tests written: 5
- Tests passing: 4
- Tests failing: 1 (describe which)

### Remaining Work
- Write error case tests for _cmd_clear
- Add --clear to wt.sh router
- Run full test suite
- Run shellcheck

### Key Decisions Made
<Architectural choices that continuation agent MUST NOT contradict, e.g.:
- Used _is_stale with 30-day threshold (matches story doc AC-3)
- Put clear logic in commands.sh, not a separate module>

### Warnings / Context for Next Agent
<Non-obvious patterns, gotchas, or important context, e.g.:
- The _wt_resolve function returns full paths — must strip GWT_WORKTREES_DIR prefix for display
- test_helper.bash setup_test_repo creates a bare remote — tests need to account for this>
```

### QA Checkpoint

Same structure as Developer Checkpoint, plus these additional sections:

```markdown
### AC Verification Progress
| AC | Status | Code Location | Test Name | Notes |
|----|--------|---------------|-----------|-------|
| AC-1 | verified | lib/commands.sh:45 | "clear removes all" | OK |
| AC-2 | verified | lib/commands.sh:60 | "clear --stale" | OK |
| AC-3 | not yet reviewed | | | |

### Issues Found So Far
| # | Severity | Description | Fix Applied | Status |
|---|----------|-------------|-------------|--------|
| 1 | medium | Missing quote on line 45 | Added quotes | fixed |
| 2 | low | Test name inconsistent | | pending |

### Code Files Reviewed
- [x] lib/commands.sh — reviewed through line 120
- [x] lib/utils.sh — fully reviewed
- [ ] wt.sh — not yet reviewed
- [ ] test/cmd_clear.bats — not yet reviewed
```

---

## Success Criteria

- 100% of acceptance criteria from `docs/stories/{{STORY_ID}}.md` are implemented and tested
- `npm test` passes with 0 failures (including all pre-existing tests)
- `shellcheck -x wt.sh lib/*.sh` passes with 0 warnings/errors
- Exactly one conventional commit with only {{STORY_ID}}-relevant files staged
- Sprint status and story doc updated by orchestrator
- No regressions in existing functionality

---

## Constraints

- Only the orchestrator (Phase 3) modifies `.bmad/sprint-status.yaml` — agents must not touch it
- Do NOT run `git push` — manual push after review
- Do NOT use `git add .` or `git add -A` — stage specific files only
- Do NOT add Co-Authored-By lines to commits
- Do NOT modify files that other stories own (see conflict zones below)
- Do NOT create documentation files (README updates, etc.) unless the story AC explicitly requires it
- Do NOT use bash/zsh-specific features in `wt.sh` or `lib/*.sh` (POSIX only)
- If blocked on a dependency or unclear requirement, stop and report the blocker — do not guess

---

## Sprint 4 Story Map

### Branch Mapping

| Story | Branch | Points | Title |
|-------|--------|--------|-------|
| STORY-013 | `story-013/self-update` | 5 | Add self-update mechanism (`wt --update`) |
| STORY-014 | `story-014/completions` | 5 | Add shell completions (bash + zsh) |
| STORY-015 | `story-015/granular-clear` | 3 | Add granular clear options |
| STORY-021 | `story-021/init-ux` | 3 | Improve `wt --init` UX |
| STORY-022 | `story-022/init-path-prompt` | 2 | Improve `wt --init` worktrees path prompt |
| STORY-023 | `story-023/from-flag` | 2 | Add `--from`/`-b` flag to `wt -n` |

### Conflict Zones — Files Modified by Multiple Stories

| File | Stories |
|------|---------|
| `wt.sh` (router) | 013, 014, 015, 023 |
| `lib/commands.sh` | 013, 015, 022, 023 |
| `lib/utils.sh` | 022 |
| New files only | 013 (`lib/update.sh`), 014 (`completions/`) |

Awareness of conflict zones helps you keep changes minimal and focused. Only modify the parts of shared files that your story requires.

### Post-Sprint Merge Order

After all stories are complete, branches merge into `main` in this order (smallest/least-conflict first):

1. **STORY-023** (2pts) — `--from` flag, minimal router change
2. **STORY-022** (2pts) — init path prompt, touches `utils.sh` + `commands.sh`
3. **STORY-015** (3pts) — granular clear, extends `commands.sh` + router
4. **STORY-021** (3pts) — init UX, may touch `commands.sh`
5. **STORY-014** (5pts) — completions, adds new files + router registration
6. **STORY-013** (5pts) — self-update, new module + router + commands

Each merge may require resolving conflicts with previously merged stories. The developer handling the merge should rebase onto `main` and resolve conflicts before merging.
