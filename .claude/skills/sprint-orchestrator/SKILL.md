---
name: sprint-orchestrator
description: >
  This skill should be used when the user asks to "run sprint", "execute stories",
  "orchestrate sprint", "run stories sequentially", "execute sprint plan",
  "uruchom sprint", "wykonaj stories sekwencyjnie", or wants sequential automated
  execution of sprint stories with Dev and QA sub-agents.
  Accepts optional story IDs as arguments (e.g., "24 25 26").
version: 2.0.0
---

# Sprint Orchestrator

Sequential story executor. Run stories one-by-one using Dev and QA sub-agents via
the Task tool. All progress is tracked directly in the story doc — no separate
report files. The orchestrator acts as a message relay between agents and the user.

Always operates in **WORKTREE_MODE** — every story runs in its own git worktree.
Never creates bare branches. Never chains commands with `&&`.

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
3. **Proceed without confirmation** — present the plan and start immediately:

```
Sprint N — Executing:
  1. STORY-024 (3pts) — Fix race condition
  2. STORY-025 (5pts) — Improve UX
Total: X stories, Y points
```

## Phase 1: Story Loop

For each pending story in order:

### Step 1: Worktree Setup

WORKTREE_MODE is always active. Every story must run in a dedicated linked worktree.

**Check current context:**

```
git worktree list --porcelain
```

- If current directory **is already** the correct linked worktree for this story
  (branch matches `story-XXX-*`): proceed to Step 2.
- If current directory **is the main working tree or a different worktree**:
  create a new worktree:

```
WORKTREES_DIR=$(jq -r '.worktreesDir' .worktrees/config.json)
git worktree add "${WORKTREES_DIR}/story-XXX" -b story-XXX-<kebab-title>
```

Store the worktree path as `WORKTREE_PATH` — pass it to all agent prompts.

If worktree creation fails:
- Append blocker to `docs/retrospectives/blockers.md` (see Blocker Format)
- Use AskUserQuestion with Option B (see Error Handling)
- Do NOT proceed until resolved

**Branch naming:** `story-XXX-<kebab-title>` — NO slashes.

### Step 2: Story Doc

Verify `docs/stories/STORY-XXX.md` exists. If missing, spawn a Story Creator agent:

```
Task(
  description="Create story doc STORY-XXX",
  subagent_type="general-purpose",
  prompt="Invoke the Skill tool FIRST: Skill(skill: \"bmad:create-story\", args: \"STORY-XXX\"). Follow the skill's workflow to create the story document."
)
```

After confirming the story doc exists, verify it contains:
- Numbered, specific, testable **Acceptance Criteria (AC)**
- **Definition of Done (DoD)** checklist

If AC or DoD are missing or vague — update the story doc directly before
proceeding. QA Pre-Dev cannot write good tests without clear criteria.

### Step 3: QA Pre-Dev Agent

Spawn QA **before** development starts. QA writes acceptance tests and pattern
guidelines that Dev will use as their implementation target.

```
result = Task(
  description="QA pre-dev STORY-XXX",
  subagent_type="general-purpose",
  prompt=<<QA_PRE_DEV_PROMPT>>
)
```

Parse result:
- `DONE` → proceed to Step 4
- `BLOCKED: <reason>` → append to blockers.md, use AskUserQuestion (Option B)

### Step 4: Dev Agent

Spawn Dev. The goal is to make the pre-written tests pass.

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
- `DONE` → proceed to Step 5
- `BLOCKED: <reason>` → append to blockers.md, use AskUserQuestion (Option B)

### Step 5: QA Code Review Agent

Spawn QA for final code review against the pre-written tests.

```
result = Task(
  description="QA review STORY-XXX",
  subagent_type="general-purpose",
  prompt=<<QA_REVIEW_PROMPT>>
)
```

Parse result:
- `DONE. No issues.` → proceed to Step 6
- `DONE. Issues found.` → read updated story doc, spawn a **Dev Fix Agent**:
  ```
  Task(
    description="Dev fix STORY-XXX",
    subagent_type="general-purpose",
    prompt=<<DEV_FIX_PROMPT>>
  )
  ```
  After fix agent completes, re-run QA (max 2 QA-fix cycles).
  If issues persist after 2 cycles:
  - Append to `docs/retrospectives/blockers.md`
  - Use AskUserQuestion (Option B)

### Step 6: Finalize

1. **Stage & Commit** (from within the worktree at `WORKTREE_PATH`):
   - Run `git diff --name-only` to review changed files
   - Stage specific files (NOT `git add .`)
   - Commit with conventional format per CLAUDE.md (no Co-Authored-By)
2. **Do NOT merge to main** — user handles merges via PR/worktree workflow
3. **Update sprint-status.yaml** (always mandatory):
   - Set story status → `completed`, `completion_date` → today
   - Recalculate `completed_points`
4. **Update story doc**: Set Status → `Completed`, tick off DoD checklist

### Step 7: Story Report

```
STORY-XXX complete.
- Worktree: <WORKTREE_PATH>
- Commit: <short-hash> — <message>
- Tests: X passed (including test/STORY-XXX.bats)
- Merge: deferred — open PR when ready
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
   Use AskUserQuestion to get the answer.
2. **No separate reports**: All progress written to the story doc by agents.
3. **Auto-proceed**: Do not ask user for confirmation to start execution.
   Just present the plan and go.
4. **Branch naming**: NO slashes — `story-XXX-<kebab-title>`.
5. **No `&&` chains**: Never chain commands with `&&`. Use separate commands.
6. **WORKTREE_MODE always active**: Never create branches without worktrees.
7. **Blockers → retrospective first**: Always append to `docs/retrospectives/blockers.md`
   before asking the user. Then present options.

## Error Handling

| Scenario | Action |
|----------|--------|
| Worktree creation fails | Append to blockers.md → AskUserQuestion (Option B) |
| QA pre-dev cannot write tests | Append to blockers.md → AskUserQuestion (Option B) |
| Dev blocked (cannot implement) | Append to blockers.md → AskUserQuestion (Option B) |
| QA issues persist after 2 fix cycles | Append to blockers.md → AskUserQuestion (Option B) |
| Agent crash | Append to blockers.md → AskUserQuestion (Option B) |
| Story doc missing | Spawn Story Creator with `Skill(skill: "bmad:create-story")` |

### Option B: AskUserQuestion Template

```
AskUserQuestion(
  question: "STORY-XXX blocked at <step>: <reason>. How to proceed?",
  options: [
    {
      label: "Retry",
      description: "Spawn a new agent to attempt this step again"
    },
    {
      label: "Skip story",
      description: "Mark as skipped, continue to next story in sprint"
    },
    {
      label: "Stop sprint",
      description: "Halt execution — I will investigate manually"
    }
  ]
)
```

### Blocker Format

Append to `docs/retrospectives/blockers.md` (create file if missing):

```markdown
## STORY-XXX — <date>

- **Stage:** <which step failed, e.g. "Step 3: QA Pre-Dev">
- **Reason:** <error or failure description>
- **Resolution:** <what the user chose — fill in after AskUserQuestion>
```

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
  8. Do NOT chain commands with && — use separate commands on separate lines
  9. Working directory: {{WORKTREE_PATH}}
```

### <<QA_PRE_DEV_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "qa-engineer")

STEP 2: Read docs/stories/{{STORY_ID}}.md
  Understand the full scope: AC, Technical Notes, DoD.

STEP 3: Validate and update AC and DoD in docs/stories/{{STORY_ID}}.md.
  AC must be: numbered, specific, and testable (not vague)
  DoD must be: a checklist of concrete verifiable items
  If either is incomplete or vague — rewrite them in the story doc now.
  Do not proceed to test writing until AC and DoD are solid.

STEP 4: Write comprehensive BATS acceptance tests.
  Create test/{{STORY_ID}}.bats with full coverage:

  - Happy paths: one test per AC item
  - Edge cases: empty input, missing arguments, wrong argument types
  - Error handling: invalid input, missing dependencies, permission errors
  - Interactive functions using fzf: mock fzf in test setup
    Create a fake fzf binary in a temp PATH that returns a deterministic value
    Example mock setup:
      MOCK_FZF_DIR="$(mktemp -d)"
      printf '#!/bin/sh\necho "mocked-value"\n' > "${MOCK_FZF_DIR}/fzf"
      chmod +x "${MOCK_FZF_DIR}/fzf"
      export PATH="${MOCK_FZF_DIR}:${PATH}"

  Tests MUST fail at this stage — no implementation exists yet. That is expected.
  If tests somehow pass already: add a comment flagging this for Dev to investigate.

STEP 5: Run npm test to confirm new tests are failing (expected).
  If tests pass before implementation: flag as "WARNING: tests may not be testing
  correctly" in the story doc.

STEP 6: Append a "## Pattern Guidelines" section to docs/stories/{{STORY_ID}}.md.
  Analyze the story scope and fill in ONLY sections relevant to what Dev will touch.
  These are guidelines for Dev, not blockers.

  ## Pattern Guidelines

  ### Guard Clauses
  Validate at the top of every function, return early on failure.
  Never nest happy-path logic inside `if` blocks.
  Good:
    _cmd_foo() {
      [ -z "$arg" ] && { _err "Usage: wt foo <arg>"; return 1; }
      _repo_root >/dev/null && _config_load || return 1
      # happy path here — no extra nesting
    }
  Bad:
    _cmd_foo() {
      if [ -n "$arg" ]; then
        if _repo_root >/dev/null; then
          # deeply nested happy path
        fi
      fi
    }
  Check: does this story add new functions? Verify each uses guard clauses.

  ### Single Responsibility
  Each function does exactly one thing. If a function name contains "and", split it.
  Target ~20 lines per function — if longer, extract a named helper.
  Check: list each new/modified function and its single responsibility.

  ### Command Router Pattern
  New commands follow the `_cmd_<name>()` convention in lib/commands.sh.
  The flag router in wt.sh dispatches to them — new flags must be registered there.
  Never add routing or dispatch logic inside a `_cmd_*` function itself.
  Check: does this story add a command? Verify it follows the router pattern.

  ### Utility Reuse (DRY)
  Before writing new logic, check these existing utilities:
  - lib/utils.sh:    _err, _info, _debug, _require, _repo_root,
                     _branch_exists, _read_input, _current_branch
  - lib/worktree.sh: _wt_create, _wt_open, _wt_resolve, _run_hook, _wt_branch
  - lib/config.sh:   _config_load (sets all GWT_* globals)
  Check: list any new utility functions and confirm they don't duplicate existing ones.

  ### Output Streams
  Errors and user prompts → stderr (`>&2`). Data/output → stdout.
  Use `_err` for errors, `_info` for informational messages.
  Never mix error text into stdout — breaks callers using command substitution `$()`.
  Check: does every new `echo`/`printf` go to the correct stream?

  ### Hook / Extension Pattern
  User-facing lifecycle events must call `_run_hook <event> ...` (lib/worktree.sh).
  Never hardcode side effects that belong in hooks.
  Check: does this story introduce a new lifecycle event? Should it expose a hook?

  ### Config as Data
  All project config flows from `.worktrees/config.json` via `_config_load`.
  Access config through `GWT_*` globals — never read the JSON file directly in commands.
  Check: does this story need new config values? Add them to config.sh, not inline.

<< Project-Specific Overrides >>

RETURN TO ORCHESTRATOR:
  DONE — test/{{STORY_ID}}.bats created, story doc updated with AC/DoD/Pattern Guidelines.
  BLOCKED: <reason> — if you cannot write tests.
```

### <<DEV_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "bmad:dev-story", args: "{{STORY_ID}}")
  This is your PRIMARY workflow guide.

STEP 2: Read docs/stories/{{STORY_ID}}.md
  Pay special attention to:
  - Acceptance Criteria — defines what you must implement
  - Definition of Done — checklist you must complete before returning DONE
  - Pattern Guidelines — follow these in your implementation

STEP 3: Run npm test to see the current failing tests:
  Focus on test/{{STORY_ID}}.bats — these are your acceptance tests.
  Your goal is to make ALL of them pass.

STEP 4: Implement the feature.
  SKIP: branch creation (handled by orchestrator), web-app examples, browser testing.

  After each significant change: run npm test
  Do not mark DONE until test/{{STORY_ID}}.bats is fully green.

STEP 5: Run linter:
  shellcheck -x wt.sh lib/*.sh
  Fix all warnings before returning.

STEP 6: Tick off the DoD checklist in docs/stories/{{STORY_ID}}.md.

PROGRESS TRACKING:
  Update the "## Progress Tracking" section in docs/stories/{{STORY_ID}}.md:
  - Files changed (with change type and description)
  - Test results after each cycle
  - Decisions made (especially deviations from Pattern Guidelines)

<< Project-Specific Overrides >>

RETURN TO ORCHESTRATOR:
  DONE — all tests pass, shellcheck clean, DoD checklist complete.
  BLOCKED: <reason> — when you cannot proceed.
```

### <<DEV_FIX_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "bmad:dev-story", args: "{{STORY_ID}}")

STEP 2: Read docs/stories/{{STORY_ID}}.md — focus on the "## QA Review" section.
  It contains issues found by QA with severity, description, and file locations.

STEP 3: Fix each issue listed.
  Do NOT fix items marked as "won't fix" or "architectural" — those require user decision.

  While fixing, apply pattern checks from the story's "## Pattern Guidelines" section:

  Guard Clauses:
    - Do your fixes introduce any new nesting? Refactor to early returns if so.

  Single Responsibility:
    - Did you add logic to an existing function that now does two things? Extract it.

  Command Router Pattern (if applicable):
    - Is the fix in the right layer? Handler logic stays in _cmd_*, routing stays in wt.sh.

  Utility Reuse (DRY):
    - Does the fix duplicate anything from lib/utils.sh or lib/worktree.sh?

  Output Streams:
    - Do any new/changed echo/printf calls go to the correct stream?

  Hook/Extension Pattern (if applicable):
    - Does the fix bypass a hook that should be called?

  Config as Data (if applicable):
    - Does the fix read config.json directly instead of via GWT_* globals?

STEP 4: Run npm test.
  Run linter: shellcheck -x wt.sh lib/*.sh

STEP 5: Update the story doc — mark fixed issues as resolved in the QA Review section.
  For each pattern violation you fixed, note it in the QA Review section.

<< Project-Specific Overrides >>

RETURN: DONE
```

### <<QA_REVIEW_PROMPT>>

```
STEP 1: Invoke the Skill tool FIRST:
  Skill(skill: "qa-engineer")
  This is your PRIMARY workflow guide.

STEP 2: Read docs/stories/{{STORY_ID}}.md — understand AC, implementation, and Pattern Guidelines.

STEP 3: Review all changed files (check git diff or the Progress Tracking section).
  For each file check:
  - POSIX compliance, style, variable quoting
  - AC coverage

  Then answer each pattern Check from the story's "## Pattern Guidelines" section:

  Guard Clauses:
    - Do new functions validate at the top and return early on failure?
    - Is the happy path free of unnecessary nesting?

  Single Responsibility:
    - Does each new/modified function do exactly one thing?
    - Are functions longer than ~20 lines? If so, should they be split?

  Command Router Pattern (if story adds a command):
    - Is the handler named `_cmd_<name>()` in lib/commands.sh?
    - Is the new flag registered in the router in wt.sh?
    - Does the handler contain any routing/dispatch logic? (it should not)

  Utility Reuse (DRY):
    - Does any new code duplicate logic from lib/utils.sh or lib/worktree.sh?
    - List: _err, _info, _require, _repo_root, _branch_exists, _read_input,
            _wt_create, _wt_open, _wt_resolve, _run_hook, _config_load

  Output Streams:
    - Do error messages and prompts use stderr (`>&2`) or `_err`?
    - Does stdout contain only data/output (no error text)?

  Hook/Extension Pattern (if story adds a lifecycle event):
    - Does it call `_run_hook <event> ...`?
    - Is the hook documented?

  Config as Data (if story adds config values):
    - Are new values read via `_config_load` and accessed through `GWT_*` globals?
    - Is the JSON file read directly anywhere? (it should not be)

  Also verify test/{{STORY_ID}}.bats covers all AC, edge cases, and error paths.

STEP 4: Run npm test.
  Run linter: shellcheck -x wt.sh lib/*.sh

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

  ### Pattern Guidelines Compliance
  Answer each Check from the story's "## Pattern Guidelines" section:

  | Pattern | Status | Issues |
  |---------|--------|--------|
  | Guard Clauses | compliant / issues | <description or "—"> |
  | Single Responsibility | compliant / issues | <description or "—"> |
  | Command Router | n/a / compliant / issues | <description or "—"> |
  | Utility Reuse (DRY) | compliant / issues | <description or "—"> |
  | Output Streams | compliant / issues | <description or "—"> |
  | Hook/Extension Pattern | n/a / compliant / issues | <description or "—"> |
  | Config as Data | n/a / compliant / issues | <description or "—"> |

  Mark "n/a" for patterns not touched by this story.

  ### Test Results
  - Total: X / Passed: X / Failed: 0

  ### Shellcheck
  - Clean: yes/no

<< Project-Specific Overrides >>

RETURN:
  DONE. No issues. — when everything passes.
  DONE. Issues found. — when issues are written to the story doc.
```

## References

- `.bmad/sprint-status.yaml` — Live sprint tracking data
- `docs/stories/STORY-XXX.md` — Single source of truth for each story
- `docs/retrospectives/blockers.md` — Blocker log across all sprints
- `test/STORY-XXX.bats` — Acceptance tests written by QA Pre-Dev
