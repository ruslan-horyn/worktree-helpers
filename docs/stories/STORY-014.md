# STORY-014: Add shell completions (bash + zsh)

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 5
**Status:** Defined
**Assigned To:** —
**Created:** 2026-02-09
**Sprint:** 4

---

## User Story

As a developer using `wt`
I want tab-completion for commands, flags, and branch names
So that I can work faster and discover available options without consulting help

---

## Description

### Background

The `wt` CLI currently has no shell completion support. Users must remember all flags (`-n`, `-s`, `-r`, `-o`, `-l`, `-c`, `-L`, `-U`, `--init`, `--log`, `--rename`, `--uninstall`, `-v`, `-h`) and type branch names manually. Tab completion is a standard developer expectation for CLI tools and dramatically improves discoverability and speed.

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
  - After `-c`/`--clear`: no completion (user provides a number)
  - After `--log`: complete with local branch names
- Modifier flag completion: `-f`, `-d`, `--dev-only`, `--main-only`, `--reflog`, `--since`, `--author`
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
7. User types `wt -c 14 --` and presses Tab → sees `--force`, `--dev-only`, `--main-only`

---

## Acceptance Criteria

- [ ] `wt <Tab>` completes flags (both short and long forms)
- [ ] `wt -s <Tab>` completes with existing worktree branch names
- [ ] `wt -r <Tab>` completes with existing worktree branch names
- [ ] `wt -o <Tab>` completes with git branch names (local + remote)
- [ ] `wt -L <Tab>` completes with worktree branch names
- [ ] `wt -U <Tab>` completes with worktree branch names
- [ ] `wt --log <Tab>` completes with local branch names
- [ ] `wt -n <Tab>` does NOT complete branch names (new name expected)
- [ ] `wt --rename <Tab>` does NOT complete branch names (new name expected)
- [ ] Modifier flags (`-f`, `-d`, `--dev-only`, `--main-only`, `--reflog`) are completed in appropriate contexts
- [ ] Works in zsh
- [ ] Works in bash
- [ ] Completions auto-register when `wt.sh` is sourced (no manual setup needed)
- [ ] No errors or warnings when completions are loaded in a non-git directory
- [ ] Completion files pass shellcheck
- [ ] README updated with shell completion usage and setup instructions

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
    '--dev-only:Filter to dev worktrees only'
    '--main-only:Filter to main worktrees only'
    '--reflog:Show reflog'
    '--since:Filter by date'
    '--author:Filter by author'
  )

  # Determine what we're completing based on previous words
  local prev_action=""
  local i
  for ((i = 1; i < CURRENT; i++)); do
    case "${words[i]}" in
      -s|--switch|-r|--remove|-L|--lock|-U|--unlock)
        prev_action="worktree_branch" ;;
      -o|--open)
        prev_action="git_branch" ;;
      --log)
        prev_action="local_branch" ;;
      -n|--new|--rename|-c|--clear)
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
    -f --force -d --dev --dev-only --main-only --reflog --since --author"

  # Find the action flag in previous words
  local action=""
  local i
  for ((i = 1; i < cword; i++)); do
    case "${words[i]}" in
      -s|--switch|-r|--remove|-L|--lock|-U|--unlock)
        action="worktree_branch" ;;
      -o|--open)
        action="git_branch" ;;
      --log)
        action="local_branch" ;;
      -n|--new|--rename|-c|--clear)
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
- **`--since` and `--author`**: These take arbitrary values, so no completion after them

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

- [ ] `completions/_wt` created with zsh completion logic
- [ ] `completions/wt.bash` created with bash completion logic
- [ ] `wt.sh` updated to auto-register completions on source
- [ ] Flag completion works for all flags (short + long)
- [ ] Branch completion works for `-s`, `-r`, `-o`, `-L`, `-U`, `--log`
- [ ] No completion for `-n`, `--rename`, `-c` (user provides new values)
- [ ] Works in zsh (tested manually)
- [ ] Works in bash (tested manually)
- [ ] Completions pass shellcheck
- [ ] No errors when sourced outside a git repo
- [ ] BATS tests for completion helper behavior (optional — integration testing for completions is inherently manual)
- [ ] `install.sh` updated to include `completions/` directory
- [ ] No regressions in existing functionality
- [ ] Code follows project conventions (POSIX-compatible where possible)

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

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
