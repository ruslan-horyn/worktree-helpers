# STORY-014: Add shell completions (bash + zsh)

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 5
**Status:** Completed
**Assigned To:** —
**Created:** 2026-02-09
**Sprint:** 5

---

## User Story

As a developer using `wt`
I want tab-completion for commands, flags, and branch names
So that I can work faster and discover available options without consulting help

---

## Description

### Background

The `wt` CLI currently has no shell completion support. Users must remember all flags (`-n`, `-s`, `-r`, `-o`, `-l`, `-c`, `-L`, `-U`, `--init`, `--log`, `--rename`, `--uninstall`, `-v`, `-h`, `-b`/`--from`, `-f`, `-d`, `--merged`, `--pattern`, `--dry-run`) and type branch names manually. Tab completion is a standard developer expectation for CLI tools and dramatically improves discoverability and speed.

Since `wt` is a shell function (not an executable), completions must be registered differently than typical CLI tools — they attach to the function name `wt` directly.

### Scope

**In scope:**

- Zsh completion function (`_wt`) with full flag and argument completion
- Bash completion function (`_wt_bash_complete`) with equivalent coverage
- Flag/command completion: all flags from the router (`-n`, `--new`, `-s`, `--switch`, etc.)
- Context-sensitive argument completion:
  - After `-s`/`--switch`, `-r`/`--remove`, `-L`/`--lock`, `-U`/`--unlock`: complete with existing worktree branch names
  - After `-o`/`--open`: complete with git branches (local + remote, excluding those already checked out)
  - After `-n`/`--new`, `--rename`: no branch completion (user provides a new name)
  - After `-b`/`--from`: complete with git branches (local + remote, used as base ref)
  - After `-c`/`--clear`: no completion for the days argument (user provides a number)
  - After `--log`: complete with local branch names
  - After `--pattern`: no completion (user provides a glob pattern)
- Modifier flag completion: `-f`, `-d`, `--dev-only`, `--main-only`, `--reflog`, `--since`, `--author`, `-b`/`--from`, `--merged`, `--pattern`, `--dry-run`
- Completions installed automatically when `wt.sh` is sourced
- Completion files: `completions/_wt` (zsh) and `completions/wt.bash` (bash)

**Out of scope:**

- Fish shell completions (can be added in a future story)
- Completing config.json keys or hook paths
- Completing remote branch names for `--rename` (it's always a new name)

---

## User Flow

1. User sources `wt.sh` in their shell config (as they already do)
2. Completions are automatically registered for the `wt` function
3. User types `wt -` and presses Tab → sees all available flags
4. User types `wt --` and presses Tab → sees long-form flags
5. User types `wt -s` and presses Tab → sees worktree branch names
6. User types `wt -o` and presses Tab → sees available git branches
7. User types `wt -c 14 --` and presses Tab → sees `--force`, `--dev-only`, `--main-only`, `--merged`, `--pattern`, `--dry-run`
8. User types `wt -n feat -b` and presses Tab → sees git branch names for base ref

---

## Acceptance Criteria

- [x] `wt <Tab>` completes flags (both short and long forms) -- test #99
- [x] `wt -s <Tab>` completes with existing worktree branch names -- test #102
- [x] `wt -r <Tab>` completes with existing worktree branch names -- test #103
- [x] `wt -o <Tab>` completes with git branch names (local + remote) -- test #107
- [x] `wt -L <Tab>` completes with worktree branch names -- test #105
- [x] `wt -U <Tab>` completes with worktree branch names -- test #106
- [x] `wt --log <Tab>` completes with local branch names -- test #110
- [x] `wt -n <Tab>` does NOT complete branch names (new name expected) -- test #111
- [x] `wt --rename <Tab>` does NOT complete branch names (new name expected) -- test #112
- [x] `wt -n <branch> -b <Tab>` completes with git branches (base ref for new worktree) -- test #108
- [x] `wt -c --<Tab>` completes with `--merged`, `--pattern`, `--dry-run`, `--force`, `--dev-only`, `--main-only` -- test #116
- [x] Modifier flags (`-f`, `-d`, `--dev-only`, `--main-only`, `--reflog`, `-b`/`--from`, `--merged`, `--pattern`, `--dry-run`) are completed in appropriate contexts -- test #101
- [x] Works in zsh -- `completions/_wt` implements zsh-native completion via `compdef`/`_describe`
- [x] Works in bash -- `completions/wt.bash` implements bash completion via `complete`/`COMPREPLY`, verified by 23 BATS tests
- [x] Completions auto-register when `wt.sh` is sourced (no manual setup needed) -- shell detection block added at end of `wt.sh`
- [x] No errors or warnings when completions are loaded in a non-git directory -- tests #118, #119
- [x] Completion files pass shellcheck -- verified for both `_wt` and `wt.bash`
- [x] README updated with shell completion usage and setup instructions -- Shell Completions section added

---

## Technical Notes

### Components

- **`completions/_wt`** (new): Zsh completion function using `compdef`/`_arguments`
- **`completions/wt.bash`** (new): Bash completion function using `complete`/`COMPREPLY`
- **`wt.sh`**: Updated to auto-source completions based on detected shell

### Implementation Details

#### File structure

```
completions/
  _wt           # Zsh completion function
  wt.bash       # Bash completion function
```

#### Auto-registration in `wt.sh`

Add at the end of `wt.sh` (after function definition):

```sh
# Load completions
if [ -n "${ZSH_VERSION:-}" ]; then
  # Zsh: add completions dir to fpath, autoload
  fpath=("$_WT_DIR/completions" $fpath)
  autoload -Uz _wt
  compdef _wt wt
elif [ -n "${BASH_VERSION:-}" ]; then
  # Bash: source completion file
  if [ -f "$_WT_DIR/completions/wt.bash" ]; then
    . "$_WT_DIR/completions/wt.bash"
  fi
fi
```

#### Zsh completion (`completions/_wt`)

```sh
#compdef wt

_wt() {
  local -a commands flags

  commands=(
    '-n:Create worktree from main'
    '--new:Create worktree from main'
    '-s:Switch worktree'
    '--switch:Switch worktree'
    '-r:Remove worktree and branch'
    '--remove:Remove worktree and branch'
    '-o:Open existing branch as worktree'
    '--open:Open existing branch as worktree'
    '-l:List worktrees'
    '--list:List worktrees'
    '-c:Clear old worktrees'
    '--clear:Clear old worktrees'
    '-L:Lock worktree'
    '--lock:Lock worktree'
    '-U:Unlock worktree'
    '--unlock:Unlock worktree'
    '--init:Initialize config'
    '--log:Show commits vs main'
    '--rename:Rename current worktree branch'
    '--uninstall:Uninstall worktree-helpers'
    '-v:Show version'
    '--version:Show version'
    '-h:Show help'
    '--help:Show help'
  )

  flags=(
    '-f:Force operation'
    '--force:Force operation'
    '-d:Use dev branch as base'
    '--dev:Use dev branch as base'
    '-b:Use custom base branch'
    '--from:Use custom base branch'
    '--dev-only:Filter to dev worktrees only'
    '--main-only:Filter to main worktrees only'
    '--reflog:Show reflog'
    '--since:Filter by date'
    '--author:Filter by author'
    '--merged:Clear merged worktrees only'
    '--pattern:Clear worktrees matching pattern'
    '--dry-run:Show what would be cleared'
  )

  # Determine what we're completing based on previous words
  local prev_action=""
  local i
  for ((i = 1; i < CURRENT; i++)); do
    case "${words[i]}" in
      -s|--switch|-r|--remove|-L|--lock|-U|--unlock)
        prev_action="worktree_branch" ;;
      -o|--open|-b|--from)
        prev_action="git_branch" ;;
      --log)
        prev_action="local_branch" ;;
      -n|--new|--rename)
        prev_action="no_complete" ;;
      -c|--clear)
        prev_action="clear_context" ;;
      --pattern|--since|--author)
        prev_action="no_complete" ;;
    esac
  done

  case "$prev_action" in
    worktree_branch)
      local -a wt_branches
      wt_branches=(${(f)"$(git worktree list --porcelain 2>/dev/null | \
        sed -n 's/^branch refs\/heads\///p')"})
      _describe 'worktree branch' wt_branches
      ;;
    git_branch)
      local -a branches
      branches=(${(f)"$(git for-each-ref --format='%(refname:short)' \
        refs/heads refs/remotes/origin 2>/dev/null | \
        sed 's|^origin/||' | sort -u)"})
      _describe 'branch' branches
      ;;
    local_branch)
      local -a branches
      branches=(${(f)"$(git for-each-ref --format='%(refname:short)' \
        refs/heads 2>/dev/null)"})
      _describe 'branch' branches
      ;;
    clear_context)
      # After -c/--clear, complete with modifier flags (not branch names)
      _describe 'flag' flags
      ;;
    no_complete)
      return
      ;;
    *)
      _describe 'command' commands
      _describe 'flag' flags
      ;;
  esac
}

_wt "$@"
```

#### Bash completion (`completions/wt.bash`)

```sh
_wt_bash_complete() {
  local cur prev words cword
  _init_completion || return

  local all_flags="-n --new -s --switch -r --remove -o --open
    -l --list -c --clear -L --lock -U --unlock --init --log
    --rename --uninstall -v --version -h --help
    -f --force -d --dev -b --from --dev-only --main-only
    --reflog --since --author --merged --pattern --dry-run"

  # Find the action flag in previous words
  local action=""
  local i
  for ((i = 1; i < cword; i++)); do
    case "${words[i]}" in
      -s|--switch|-r|--remove|-L|--lock|-U|--unlock)
        action="worktree_branch" ;;
      -o|--open|-b|--from)
        action="git_branch" ;;
      --log)
        action="local_branch" ;;
      -n|--new|--rename)
        action="no_complete" ;;
      -c|--clear)
        action="clear_context" ;;
      --pattern|--since|--author)
        action="no_complete" ;;
    esac
  done

  case "$action" in
    worktree_branch)
      local wt_branches
      wt_branches=$(git worktree list --porcelain 2>/dev/null | \
        sed -n 's/^branch refs\/heads\///p')
      COMPREPLY=($(compgen -W "$wt_branches" -- "$cur"))
      ;;
    git_branch)
      local branches
      branches=$(git for-each-ref --format='%(refname:short)' \
        refs/heads refs/remotes/origin 2>/dev/null | \
        sed 's|^origin/||' | sort -u)
      COMPREPLY=($(compgen -W "$branches" -- "$cur"))
      ;;
    local_branch)
      local branches
      branches=$(git for-each-ref --format='%(refname:short)' \
        refs/heads 2>/dev/null)
      COMPREPLY=($(compgen -W "$branches" -- "$cur"))
      ;;
    clear_context)
      # After -c/--clear, complete with modifier flags (not branch names)
      COMPREPLY=($(compgen -W "$all_flags" -- "$cur"))
      ;;
    no_complete)
      return
      ;;
    *)
      COMPREPLY=($(compgen -W "$all_flags" -- "$cur"))
      ;;
  esac
}

complete -F _wt_bash_complete wt
```

### Helper functions for branch listing

The completions use `git worktree list --porcelain` and `git for-each-ref` directly rather than calling internal `_wt_*` helpers. This keeps completion files self-contained and avoids depending on the wt environment being fully loaded at completion time.

### Edge Cases

- **Not in a git repo**: `git worktree list` and `git for-each-ref` fail silently with `2>/dev/null`, resulting in no completions (acceptable UX)
- **Large number of branches**: `git for-each-ref` is efficient even with thousands of branches; no pagination needed
- **Branch names with spaces**: Not valid in git, so word splitting in completions is safe
- **Branch names with slashes** (e.g., `feature/login`): Both zsh and bash completions handle these natively
- **Multiple flags**: After the first command flag, additional flags are still completable (e.g., `wt -c 14 --dev-only`)
- **`--since`, `--author`, and `--pattern`**: These take arbitrary values, so no completion after them
- **`-b`/`--from` after `-n`**: Completes with git branches for base ref selection

### Security Considerations

- Branch names come from local git data only (no remote fetching during completion)
- No user input is passed to `eval` or unquoted expansion
- `sed` patterns use fixed strings, not user-controlled regex

---

## Dependencies

**Prerequisite Stories:**

- None (independent feature)

**Blocked Stories:**

- None

**External Dependencies:**

- Bash 4.0+ for bash completions (`_init_completion` from bash-completion package)
- Zsh with `compdef` support (standard in modern zsh)

---

## Definition of Done

- [x] `completions/_wt` created with zsh completion logic
- [x] `completions/wt.bash` created with bash completion logic
- [x] `wt.sh` updated to auto-register completions on source
- [x] Flag completion works for all flags (short + long)
- [x] Branch completion works for `-s`, `-r`, `-o`, `-L`, `-U`, `--log`, `-b`/`--from`
- [x] No completion for `-n`, `--rename`, `--pattern` (user provides new values)
- [x] `-c`/`--clear` context completes with modifier flags (`--merged`, `--dry-run`, etc.)
- [x] Works in zsh (tested manually)
- [x] Works in bash (tested manually)
- [x] Completions pass shellcheck
- [x] No errors when sourced outside a git repo
- [x] BATS tests for completion helper behavior (optional — integration testing for completions is inherently manual)
- [x] `install.sh` updated to include `completions/` directory
- [x] No regressions in existing functionality
- [x] Code follows project conventions (POSIX-compatible where possible)

---

## Story Points Breakdown

- **Zsh completion function**: 1.5 points
- **Bash completion function**: 1.5 points
- **Auto-registration in wt.sh**: 0.5 points
- **Testing + edge cases + install.sh update**: 1.5 points
- **Total:** 5 points

**Rationale:** The 5-point estimate reflects the need to support two different completion systems (zsh and bash) with context-sensitive argument completion. Each shell has its own completion API and quirks. The branch-listing logic must handle worktree branches vs all branches depending on the command. Testing requires manual verification in both shells.

---

## Additional Notes

- **Zsh `fpath` approach**: Rather than inlining the completion in `wt.sh`, we use zsh's `fpath` + `autoload` convention. This is the standard zsh way and allows lazy-loading of the completion function.
- **Bash `_init_completion`**: This helper from the `bash-completion` package handles `cur`/`prev`/`words`/`cword` setup. If `bash-completion` is not installed, we should provide a fallback that manually sets these variables.
- **Install script**: `install.sh` should copy the `completions/` directory alongside `lib/`. The zsh fpath is set relative to `$_WT_DIR`, so it works regardless of install location.
- **Future**: Fish completions could be added in a separate story. The completion patterns are similar but use `complete -c wt -f -a ...` syntax.

---

## Progress Tracking

**Status History:**

- 2026-02-09: Created and defined
- 2026-02-16: Updated to include flags from STORY-023 (-b/--from) and STORY-015 (--merged, --pattern, --dry-run)
- 2026-02-17: Implementation complete

**Files Changed:**

| File | Change Type | Description |
|------|-------------|-------------|
| `completions/_wt` | Created | Zsh completion function with context-sensitive argument completion |
| `completions/wt.bash` | Created | Bash completion function with `_init_completion` fallback |
| `wt.sh` | Modified | Added auto-registration of completions for zsh and bash |
| `install.sh` | Modified | Added `completions/` directory to local install copy |
| `test/completions.bats` | Created | 23 BATS tests for bash completion function |
| `README.md` | Modified | Added Shell Completions section, updated Features list and Roadmap |
| `docs/stories/STORY-014.md` | Modified | Updated progress tracking |

**Tests Added:**

- 23 new tests in `test/completions.bats` covering:
  - Flag completion (short and long forms)
  - Worktree branch completion (`-s`, `-r`, `--switch`, `-L`, `-U`)
  - Git branch completion (`-o`, `--open`, `-b`/`--from`)
  - Local branch completion (`--log`)
  - No-completion contexts (`-n`, `--rename`, `--pattern`, `--since`, `--author`)
  - Clear context modifier flag completion (`-c 14 --<Tab>`)
  - Non-git directory safety (no errors)
  - Partial flag matching
  - Flag completion outside git repos

**Test Results:**

- All 203 tests pass (180 existing + 23 new)
- No regressions in existing functionality
- shellcheck passes on all files (completions/_wt, completions/wt.bash, wt.sh, install.sh)

**Decisions Made:**

- Used `shellcheck disable` directives for zsh-specific syntax in `_wt` (SC2296, SC2206, SC2154) since shellcheck does not understand zsh natively
- Added `_init_completion` fallback in bash completion for environments without the `bash-completion` package installed
- Completion files are self-contained (use `git worktree list --porcelain` and `git for-each-ref` directly, not internal `_wt_*` helpers)
- The immediately previous word takes priority over action context for value-argument completion (e.g., `wt -n mybranch -b <Tab>` correctly completes with git branches even though `-n` sets `no_complete`)

---

## QA Review

**Reviewer:** QA Engineer (automated)
**Date:** 2026-02-17

### Files Reviewed

| File | Status | Notes |
|------|--------|-------|
| `completions/_wt` | Pass | Zsh completion function; uses `_describe` for context-sensitive completion; shellcheck directives correctly suppress zsh-specific syntax warnings (SC2296, SC2206, SC2154, SC2207, SC2148, SC2034); `local context state` declared but unused (conventional in zsh completions, harmless) |
| `completions/wt.bash` | Pass | Bash completion function; `_init_completion` fallback for environments without bash-completion package; SC2207 correctly suppressed for `COMPREPLY` word-splitting pattern; proper quoting throughout |
| `wt.sh` | Pass | Auto-registration block appended after `wt()` function; zsh path uses `fpath`+`autoload`+`compdef` (standard pattern); bash path sources file with existence check; `compdef` stderr suppressed with `2>/dev/null` to handle edge cases; SC2206 suppressed for zsh `fpath` array syntax |
| `install.sh` | Pass | Single-line change adds `$SCRIPT_DIR/completions` to `cp -R` for local install; remote install uses `git clone` which includes all files automatically |
| `test/completions.bats` | Pass | 23 well-structured tests; covers flag completion, worktree branch completion, git branch completion, local branch completion, no-completion contexts, clear context modifiers, non-git directory safety, and partial flag matching; uses `_simulate_completion` helper to mock bash completion environment |
| `README.md` | Pass | Shell Completions section added with completion context table, mechanism explanation, and manual setup fallback instructions; Features list updated; Roadmap checkbox marked |
| `docs/stories/STORY-014.md` | Pass | Progress tracking updated with files changed, tests added, decisions made |

### Issues Found

None

### AC Verification

- [x] AC 1 -- `wt <Tab>` completes flags: verified in `completions/wt.bash` (line 19-23, all flags listed) and `completions/_wt` (line 11-53, commands + flags arrays); test: `completion: 'wt <Tab>' suggests flags` (#99)
- [x] AC 2 -- `wt -s <Tab>` completes worktree branches: verified in `completions/wt.bash` (line 30, case match) and `completions/_wt` (line 60, case match); test: `completion: 'wt -s <Tab>' completes with worktree branches` (#102)
- [x] AC 3 -- `wt -r <Tab>` completes worktree branches: verified in both completion files (same case group as `-s`); test: `completion: 'wt -r <Tab>' completes with worktree branches` (#103)
- [x] AC 4 -- `wt -o <Tab>` completes git branches: verified in `completions/wt.bash` (line 49) and `completions/_wt` (line 82-83); test: `completion: 'wt -o <Tab>' completes with git branches` (#107)
- [x] AC 5 -- `wt -L <Tab>` completes worktree branches: verified in both files (same case group); test: `completion: 'wt -L <Tab>' completes with worktree branches` (#105)
- [x] AC 6 -- `wt -U <Tab>` completes worktree branches: verified in both files; test: `completion: 'wt -U <Tab>' completes with worktree branches` (#106)
- [x] AC 7 -- `wt --log <Tab>` completes local branches: verified in `completions/wt.bash` (line 51) and `completions/_wt` (line 87); test: `completion: 'wt --log <Tab>' completes with local branches` (#110)
- [x] AC 8 -- `wt -n <Tab>` does NOT complete: verified in both files (`no_complete` action); test: `completion: 'wt -n <Tab>' does NOT complete branch names` (#111)
- [x] AC 9 -- `wt --rename <Tab>` does NOT complete: verified in both files; test: `completion: 'wt --rename <Tab>' does NOT complete branch names` (#112)
- [x] AC 10 -- `wt -n <branch> -b <Tab>` completes git branches: verified via `prev` override in `completions/wt.bash` (line 49) and `words[CURRENT-1]` override in `completions/_wt` (line 84); test: `completion: 'wt -n mybranch -b <Tab>' completes with git branches` (#108)
- [x] AC 11 -- `wt -c --<Tab>` completes modifier flags: verified in both files (`clear_context` action); test: `completion: 'wt -c 14 --<Tab>' completes with modifier flags` (#116)
- [x] AC 12 -- Modifier flags completed in appropriate contexts: verified in `completions/wt.bash` (line 19-23, all modifier flags in `all_flags`) and `completions/_wt` (line 38-53, `flags` array); test: `completion: modifier flags included in default completion` (#101)
- [x] AC 13 -- Works in zsh: `completions/_wt` implements zsh-native completion via `compdef`/`_describe`; auto-registered in `wt.sh` (line 103-108)
- [x] AC 14 -- Works in bash: `completions/wt.bash` implements bash completion via `complete`/`COMPREPLY`; verified by 23 BATS tests
- [x] AC 15 -- Completions auto-register: `wt.sh` (line 102-115) detects shell via `ZSH_VERSION`/`BASH_VERSION` and loads appropriate completion file
- [x] AC 16 -- No errors outside git repo: verified in `completions/wt.bash` (all git commands use `2>/dev/null`); tests: `completion: no errors outside a git repo` (#118), `completion: flag completion works outside a git repo` (#119)
- [x] AC 17 -- Completion files pass shellcheck: verified -- `shellcheck -x completions/wt.bash` and `shellcheck -x completions/_wt` both clean
- [x] AC 18 -- README updated: Shell Completions section added with context table, mechanism details, and manual setup fallback

### Test Results

- Total: 203 / Passed: 203 / Failed: 0
- New tests: 23 (in `test/completions.bats`)
- Existing tests: 180 (no regressions)

### Shellcheck

- `wt.sh`: Clean
- `lib/*.sh`: Clean
- `completions/wt.bash`: Clean
- `completions/_wt`: Clean (with justified SC directives for zsh syntax)
- Overall: Clean

---

## Manual Testing

**Tester:** QA Engineer (Claude Code)
**Date:** 2026-02-17
**Environment:** macOS Darwin 24.6.0, zsh 5.9+, bash (via BATS), shellcheck

### Test Scenarios

| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | Source `wt.sh` in interactive zsh | No errors, exit code 0 | No errors, exit code 0 | Pass |
| 2 | `_wt` completion function loaded in zsh | `_wt is an autoload shell function` | `_wt is an autoload shell function` | Pass |
| 3 | `wt` function loaded in zsh after sourcing | `wt is a shell function` | `wt is a shell function from wt.sh` | Pass |
| 4 | Source `wt.sh` in interactive zsh outside git repo (`cd /tmp`) | No errors, exit code 0 | No errors, exit code 0 | Pass |
| 5 | Source `completions/wt.bash` in bash | No errors, exit code 0 | No errors, exit code 0 | Pass |
| 6 | Source `wt.sh` in bash | `_wt_bash_complete` and `wt` functions loaded, exit 0 | Both functions loaded, exit 0 | Pass |
| 7 | `git worktree list --porcelain` branch extraction | Lists active worktree branch names | Correctly lists 9 active worktree branches | Pass |
| 8 | `git for-each-ref` local+remote branches | Lists deduplicated branches (local + origin) | Correctly lists 13 unique branches | Pass |
| 9 | `git for-each-ref` local branches only | Lists local branch names | Correctly lists 11 local branches | Pass |
| 10 | Git commands outside git repo (`/tmp`) | Silent failure, no output, no errors on stderr | No output, stderr suppressed by `2>/dev/null` | Pass |
| 11 | Bash completion: partial branch match (`wt -s story`) | Worktree branches starting with "story" | 6 matching branches including slash-containing names | Pass |
| 12 | Bash completion: clear context (`wt -c 14 --mer`) | `--merged` | `--merged` | Pass |
| 13 | Bash completion: `-b` overrides `-n` context (`wt -n mybranch -b ""`) | Git branch list | 13 git branches listed correctly | Pass |
| 14 | Branch names with slashes (e.g., `story-025/open-existing-branch-ux`) | Handled correctly in completions | Completed correctly, no truncation | Pass |
| 15 | `install.sh` includes `completions/` in local install `cp -R` | `completions` in cp command | Present on line 95 | Pass |
| 16 | `completions/` directory contains expected files | `_wt` and `wt.bash` | Both present | Pass |
| 17 | shellcheck on `completions/wt.bash` | Clean (exit 0) | Clean (exit 0) | Pass |
| 18 | shellcheck on `completions/_wt` | Clean with justified SC directives (exit 0) | Clean (exit 0) | Pass |
| 19 | shellcheck on `wt.sh` | Clean (exit 0) | Clean (exit 0) | Pass |
| 20 | BATS test suite (`npm test`) | All 203 tests pass | 203/203 pass, 0 failures | Pass |
| 21 | Non-interactive zsh sourcing (compdef unavailable) | compdef fails silently (stderr suppressed) | stderr suppressed, exit code 127 from compdef (expected -- compdef requires interactive zsh) | Pass |

### Issues Found

None

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
