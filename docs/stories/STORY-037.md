# STORY-037: Completions — show example usage hint when nothing to suggest

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Completed
**Sprint:** 7

---

## User Story

As a developer pressing `<TAB>` after a command that takes a free-form argument
I want to see an example placeholder rather than nothing
So that I know what to type without consulting the docs

---

## Description

### Problem

For commands like `wt -n <branch>` where the argument is a free-form string,
pressing `<TAB>` currently shows nothing. This is confusing — the user doesn't know
if completions are broken or if there's simply nothing to suggest.

### Expected Behaviour

When there are no dynamic completions to offer, show a descriptive placeholder hint:

```
$ wt -n <TAB>
<branch>   -- new branch name
```

```
$ wt --from <TAB>
<ref>   -- branch, tag, or commit to base from
```

This matches the style of tools like `docker`, `kubectl`, and `gh` which show
argument descriptions when no values are available.

---

## Acceptance Criteria

1. **[bash] `wt -n <TAB>` sets `COMPREPLY` to exactly `('<branch>')` and no other values.**
2. **[bash] `wt --new <TAB>` sets `COMPREPLY` to exactly `('<branch>')` and no other values.**
3. **[bash] `wt --from <TAB>` sets `COMPREPLY` to exactly `('<ref>')` and no other values.**
4. **[bash] `wt -b <TAB>` sets `COMPREPLY` to exactly `('<ref>')` and no other values.**
5. **[bash] `wt --rename <TAB>` sets `COMPREPLY` to exactly `('<new-branch>')` and no other values.**
6. **[bash] `wt --pattern <TAB>` sets `COMPREPLY` to exactly `('<pattern>')` and no other values.**
7. **[bash] `wt --since <TAB>` sets `COMPREPLY` to exactly `('<date>')` and no other values.**
8. **[bash] `wt --author <TAB>` sets `COMPREPLY` to exactly `('<author>')` and no other values.**
9. **[bash] `wt -s <TAB>` still completes with real worktree branch names (dynamic completions unaffected).**
10. **[bash] `wt -o <TAB>` still completes with real git branch names (dynamic completions unaffected).**
11. **[bash] `wt <TAB>` still suggests the full set of command flags (no regression).**
12. **[zsh] `completions/_wt` contains `_message` calls for `-n`/`--new`, `--from`/`-b`, `--rename`, `--pattern`, `--since`, and `--author` contexts.**
13. **[zsh] `shellcheck` exits 0 on `completions/_wt` (with existing SC suppressions).**
14. **[bash] `shellcheck` exits 0 on `completions/wt.bash` (with existing SC suppressions).**

---

## Technical Notes

- In zsh completions (`completions/_wt`): use `_message` for placeholder hints
  ```zsh
  (( CURRENT == 2 )) && _message 'new branch name' && return
  ```
- In bash completions: add a comment-style hint using `COMPREPLY=( '<branch>' )` only
  if `$COMP_CWORD` indicates no prior completion was offered
- Coordinate with STORY-036 (per-command help) for consistent placeholder naming

---

## Dependencies

- STORY-030: Completions overhaul (same sprint or prerequisite)

---

## Definition of Done

- [x] `completions/wt.bash`: `no_complete` branch replaced with COMPREPLY hint for each free-form argument (`-n`/`--new` → `<branch>`, `-b`/`--from` → `<ref>`, `--rename` → `<new-branch>`, `--pattern` → `<pattern>`, `--since` → `<date>`, `--author` → `<author>`)
- [x] `completions/_wt`: `no_complete` branch replaced with `_message` calls carrying matching hint text for each free-form argument
- [x] All 14 acceptance criteria pass as BATS tests in `test/STORY-037.bats`
- [x] Dynamic completions for `-s`/`--switch`, `-r`/`--remove`, `-o`/`--open`, `--log`, `-L`/`--lock`, `-U`/`--unlock` produce real branch names (no regressions). Note: `-b`/`--from` now shows `<ref>` placeholder per AC-3/AC-4 — `test/completions.bats` test #10 updated accordingly.
- [x] `npm test` exits 0 (full test suite green — 387 tests, 0 failures)
- [x] `shellcheck completions/wt.bash` exits 0
- [x] `shellcheck completions/_wt` exits 0

---

## QA Notes

**Test file:** `test/STORY-037.bats` (25 tests)

**Pre-implementation run results (2026-02-25):**
- 14 failing (new placeholder-hint behavior — expected, no implementation yet)
- 11 passing (regression guards for existing dynamic completions + shellcheck)

**Dev action required:** `test/completions.bats` tests 13–17 currently assert
`${#COMPREPLY[@]} -eq 0` for `-n`, `--rename`, `--pattern`, `--since`, `--author`.
After implementation those existing tests will start failing because COMPREPLY will
contain exactly one placeholder entry. Dev must update those 5 tests to assert
`[ ${#COMPREPLY[@]} -eq 1 ]` instead of `-eq 0`.

---

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
Check: this story does NOT add new `_cmd_*` functions — only modifies completion
scripts. Guard clauses are N/A for completion scripts, which use `case` dispatch.

### Single Responsibility
Each function does exactly one thing.
Check: No new functions are added by this story. The `no_complete` case branch in
both `_wt_bash_complete` (wt.bash) and `_wt` (completions/_wt) is the single
point of change. Each `case` arm should do one thing: return the appropriate
placeholder. Do not combine placeholder logic with flag-listing logic.

### Command Router Pattern
New commands follow the `_cmd_<name>()` convention in lib/commands.sh.
Check: this story adds NO new commands. Only completion files change. No router
update in wt.sh is required.

### Utility Reuse (DRY)
Before writing new logic, check existing utilities.
Check: completion files are self-contained and do not use lib/*.sh helpers.
The only construct needed is:
  - bash: `COMPREPLY=( '<placeholder>' )` inside the relevant `case` arm
  - zsh:  `_message 'hint text'` inside the relevant `case` arm
No new utility functions are needed or appropriate here.

### Output Streams
Errors and user prompts → stderr. Data/output → stdout.
Check: completion scripts write to `COMPREPLY` (bash) or call zsh builtins
(`_message`, `_describe`, `compadd`). No raw `echo`/`printf` to stdout.
This convention is already followed and must be preserved.

### Hook / Extension Pattern
Check: this story introduces no new lifecycle events and no hooks. N/A.

### Config as Data
Check: completion scripts run outside the wt command context and do not load
config. No GWT_* globals are accessed. N/A.

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**

---

## Progress Tracking

**Status History:**
- 2026-02-25: Created (not started)
- 2026-02-25: Implemented and completed

**Actual Effort:** 2 points (matched estimate)

**Files Changed:**

| File | Change Type | Description |
|------|-------------|-------------|
| `completions/wt.bash` | Modified | Replaced single `no_complete` action with 6 distinct `hint_*` actions; each sets `COMPREPLY=( '<placeholder>' )` for its specific flag |
| `completions/_wt` | Modified | Replaced single `no_complete` action with 6 distinct `hint_*` actions; each calls `_message 'hint text'` for its specific flag |
| `test/completions.bats` | Modified | Updated 6 tests: 5 tests that asserted `${#COMPREPLY[@]} -eq 0` now assert `-eq 1` + check placeholder value; test #10 (`-b` flag) updated from expecting real git branches to expecting `<ref>` placeholder (per AC-3/AC-4) |

**Test Results:**
- `test/STORY-037.bats`: 25/25 passing
- `test/completions.bats`: 23/23 passing
- Full suite (`npm test`): 387/387 passing

**Decisions Made:**
1. **`-b`/`--from` now returns `<ref>` placeholder**: AC-3 and AC-4 explicitly specify that `wt -b <TAB>` and `wt --from <TAB>` return `<ref>`. This conflicts with the DoD note about "no regressions in test/completions.bats" for `-b`/`--from`. The BATS acceptance tests (STORY-037.bats) take precedence — `completions.bats` test #10 was updated to reflect the new behavior. The `<ref>` placeholder is actually more accurate (these flags accept any git ref: commit SHA, tag, or branch name — not just branches).
2. **No `_message` in bash completions**: Bash completions use `COMPREPLY=( '<placeholder>' )` as specified. The `<angle-bracket>` format signals a placeholder to the user without the bash `_message` API (which doesn't exist in bash completions).
3. **Separate hint actions per flag**: Instead of a single `no_complete` action with no way to distinguish which placeholder to show, each flag gets its own `hint_*` action type. This keeps each `case` arm doing one thing (Single Responsibility per Pattern Guidelines).

---

## QA Review

### Files Reviewed
| File | Status | Notes |
|------|--------|-------|
| `completions/wt.bash` | Pass | Clean implementation; 6 distinct `hint_*` case arms; no regressions |
| `completions/_wt` | Pass | Clean implementation; 6 `_message` calls with descriptive text; no regressions |
| `test/STORY-037.bats` | Pass | 25 tests covering all 14 ACs plus 11 edge/regression cases |
| `test/completions.bats` | Pass | 6 existing tests updated to match new placeholder behavior; 23/23 pass |

### Issues Found
None

### AC Verification
- [x] AC-1 — verified: `completions/wt.bash` line 98–100 (`hint_branch` case arm sets `COMPREPLY=( '<branch>' )`); test: `STORY-037 AC-1`
- [x] AC-2 — verified: same `hint_branch` arm reached via `--new` in the `prev` case block (line 63); test: `STORY-037 AC-2`
- [x] AC-3 — verified: `completions/wt.bash` lines 101–103 (`hint_ref` case arm); test: `STORY-037 AC-3`
- [x] AC-4 — verified: same `hint_ref` arm reached via `-b` (line 59); test: `STORY-037 AC-4`
- [x] AC-5 — verified: `completions/wt.bash` lines 104–106 (`hint_new_branch` sets `COMPREPLY=( '<new-branch>' )`); test: `STORY-037 AC-5`
- [x] AC-6 — verified: `completions/wt.bash` lines 107–109 (`hint_pattern` sets `COMPREPLY=( '<pattern>' )`); test: `STORY-037 AC-6`
- [x] AC-7 — verified: `completions/wt.bash` lines 110–112 (`hint_date` sets `COMPREPLY=( '<date>' )`); test: `STORY-037 AC-7`
- [x] AC-8 — verified: `completions/wt.bash` lines 113–115 (`hint_author` sets `COMPREPLY=( '<author>' )`); test: `STORY-037 AC-8`
- [x] AC-9 — verified: `worktree_branch` case arm unchanged (lines 76–81); test: `STORY-037 AC-9` and `AC-9b`
- [x] AC-10 — verified: `git_branch` case arm unchanged (lines 82–88); test: `STORY-037 AC-10` and `AC-10b`
- [x] AC-11 — verified: default `*` arm unchanged (lines 116–118); test: `STORY-037 AC-11`
- [x] AC-12 — verified: `completions/_wt` lines 131–147 contain 6 `_message` calls for `-n`/`--new`, `--from`/`-b`, `--rename`, `--pattern`, `--since`, `--author`; tests: `STORY-037 AC-12`, `AC-12b`, `AC-12c`
- [x] AC-13 — verified: `shellcheck completions/_wt` exits 0; test: `STORY-037 AC-13`
- [x] AC-14 — verified: `shellcheck completions/wt.bash` exits 0; test: `STORY-037 AC-14`

### Pattern Guidelines Compliance

| Pattern | Status | Issues |
|---------|--------|--------|
| Guard Clauses | n/a | Story modifies completion scripts using `case` dispatch, not `_cmd_*` functions — guard clauses do not apply |
| Single Responsibility | compliant | Each `hint_*` case arm does exactly one thing: assigns its specific placeholder. No mixing of placeholder logic and flag-listing logic. |
| Command Router | n/a | No new commands added; no changes to `wt.sh` router or `lib/commands.sh` |
| Utility Reuse (DRY) | compliant | Completion scripts are self-contained per pattern guidelines. No lib/*.sh helpers accessed (none are appropriate here). No duplication introduced. |
| Output Streams | compliant | Bash completions write only to `COMPREPLY`; zsh completions use `_message`/`compadd`/`_describe` builtins. No raw `echo`/`printf` to stdout. |
| Hook/Extension Pattern | n/a | No lifecycle events or hooks involved |
| Config as Data | n/a | Completion scripts run outside the wt command context; no `GWT_*` globals accessed |

### Test Results
- Total: 387 / Passed: 387 / Failed: 0
- STORY-037.bats: 25 / Passed: 25 / Failed: 0
- completions.bats: 23 / Passed: 23 / Failed: 0

### Shellcheck
- `shellcheck -x wt.sh lib/*.sh`: clean (exit 0)
- `shellcheck completions/wt.bash`: clean (exit 0)
- `shellcheck completions/_wt`: clean (exit 0)
