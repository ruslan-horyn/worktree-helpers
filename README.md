# worktree-helpers

[![CI](https://github.com/ruslan-horyn/worktree-helpers/actions/workflows/ci.yml/badge.svg)](https://github.com/ruslan-horyn/worktree-helpers/actions/workflows/ci.yml)

A POSIX-compatible shell CLI tool (`wt`) for managing git worktrees. One command, simple flags, zero friction.

> **Documentation:** [Hooks reference](docs/hooks.md)

## Why?

Every time you switch branches the traditional way (`git stash` + `git checkout`), you risk
stash conflicts, forgotten stashes, and lost work. Git worktrees solve this by giving each
branch its own directory — but native `git worktree` commands are verbose and offer no
automation.

**The real pain:** even with worktrees, every new branch means manually running `npm install`,
copying `.env` files, opening your editor, starting services. Every. Single. Time.

**worktree-helpers** wraps git worktrees into a single `wt` command with:

- **Automated hooks** — define your setup once in `created.sh`, and it runs automatically on
  every `wt -n` / `wt -o`. Dependencies installed, editor opened, services started — hands-free.
- **One-command switching** — `wt -s` fires your `switched.sh` hook to restore context
  (reinstall if lockfile changed, reopen editor, etc.)
- **Zero-friction cleanup** — `wt -c 14` removes all worktrees older than 14 days along with
  their branches.

The time saved compounds across every branch switch. No more manual setup, no more forgotten
stashes, no more broken context.

## Features

- Single `wt` command with intuitive flags
- Create worktrees from main or dev branches
- Automated hooks on create and switch (install deps, open editor, copy env files)
- Hook symlinking — all worktrees share the same hook scripts
- Interactive selection with fzf integration
- Flexible worktree cleanup with filters (`--merged`, `--pattern`, `--dry-run`, `--dev-only`, `--main-only`) — main/dev branches are always protected
- Verbose step-by-step output for `wt -c` (per-worktree decision + summary) and `wt --init` (progress + created files list, colorized with green Done and yellow warnings)
- Hooks preservation prompt — `wt --init` detects existing hooks and asks to keep, back up, or overwrite; `--force` skips the prompt and preserves hooks
- Auto `.gitignore` update — `wt --init` appends `.worktrees/` to the repo-root `.gitignore` (creating it if absent) so worktree directories are never accidentally committed
- Lock/unlock worktree protection
- Branch rename without recreating worktree (`--rename`)
- Shell completions for bash and zsh (flags, branch names, context-sensitive arguments)
- Shell-aware prompts — `wt --init` supports tab completion in bash and zsh
- Per-command help — `wt <cmd> --help` shows focused help for any command
- Project-specific configuration per repository

## Requirements

- **git** (required)
- **jq** (required) — JSON config parsing
- **fzf** (optional) — interactive worktree/branch selection

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ruslan-horyn/worktree-helpers/main/install.sh | bash
```

### Manual installation

1. Clone the repository:

   ```bash
   git clone https://github.com/ruslan-horyn/worktree-helpers.git ~/.worktree-helpers
   ```

2. Add to your shell config (`~/.zshrc` or `~/.bashrc`):

   ```bash
   source "$HOME/.worktree-helpers/wt.sh"
   ```

3. Restart your terminal or source the config file.

### Binary installation (`~/.local/bin/wt`)

`install.sh` also creates `~/.local/bin/wt` as a symlink to `wt.sh`, so `wt` is available in non-interactive shells (CI scripts, Claude Code subprocesses, `bash -c "..."`) without needing to source `~/.zshrc` first. If `~/.local/bin` is not already in your `PATH`, the installer prints an `export PATH` instruction.

## Quick Start

1. Navigate to a git repository:

   ```bash
   cd ~/projects/my-repo
   ```

2. Initialize worktree-helpers for this project:

   ```bash
   wt --init
   ```

3. Create your first worktree:

   ```bash
   wt -n feature-branch
   ```

## Commands

| Command | Description |
|---------|-------------|
| `wt -n <branch>` | Create worktree from main branch |
| `wt -n <branch> --from <ref>` | Create worktree from custom ref (branch, tag, or commit) |
| `wt -n -d [name]` | Create worktree from dev branch |
| `wt -s [branch]` | Switch to worktree (fzf picker if no arg) |
| `wt -r [branch]` | Remove worktree and delete branch (prompts unless `-f`) |
| `wt -o [branch]` | Open existing branch as worktree (fzf picker if no arg) |
| `wt -l` | List all worktrees with dirty/clean and lock status |
| `wt -c <days>` | Clear worktrees older than `<days>` days |
| `wt -c --merged` | Clear worktrees whose branches are merged into main |
| `wt -c --pattern <glob>` | Clear worktrees matching a branch name glob pattern |
| `wt -c <days> --dry-run` | Preview what would be cleared without deleting |
| `wt -L [<worktree>]` | Lock worktree (fzf picker if no arg) |
| `wt -U [<worktree>]` | Unlock worktree (fzf picker if no arg) |
| `wt --init` | Initialize project configuration; auto-updates `.gitignore`; colorized output; prompts to keep, back up, or overwrite existing hooks |
| `wt --log [branch]` | Show commits vs main branch |
| `wt --rename <new-branch>` | Rename current worktree's branch and directory |
| `wt --update` | Update to latest version |
| `wt --update --check` | Check for updates without installing |
| `wt --uninstall` | Uninstall worktree-helpers |
| `wt -v` / `wt --version` | Show version |
| `wt -h` | Show full help |
| `wt <cmd> --help` | Show help for a specific command |

### Examples

```bash
# Create a new feature worktree from main
wt -n my-feature

# Create a worktree from a specific branch/ref
wt -n hotfix/2.0.1 --from release/2.0
wt -n my-fix -b origin/staging

# Create a worktree from dev branch (with suffix)
wt -n -d my-feature    # creates my-feature_RN

# Switch between worktrees (interactive)
wt -s

# Switch to specific worktree
wt -s my-feature

# Open an existing remote branch as worktree
wt -o feature/login

# List all worktrees
wt -l

# Remove a worktree
wt -r my-feature

# Remove with force (no confirmation)
wt -r -f my-feature

# Clear worktrees older than 14 days
# (main, master, dev, develop and configured main/dev branches are always skipped)
wt -c 14

# Clear old worktrees (force, no confirmation)
wt -c 14 -f

# Clear only dev-based worktrees older than 30 days
wt -c 30 --dev-only

# Clear worktrees whose branches are merged into main
wt -c --merged

# Clear worktrees matching a branch name pattern
wt -c --pattern "fix-*"

# Preview what would be cleared (dry-run)
wt -c 14 --dry-run

# Combine filters: merged + pattern + dry-run
wt -c --merged --pattern "fix-*" --dry-run

# Lock important worktree
wt -L production-fix

# View commits on current branch vs main
wt --log

# View commits with filters
wt --log feature-branch --since="2 weeks ago"

# Check if an update is available without installing
wt --update --check
```

## Configuration

Configuration is stored in `.worktrees/config.json` in your repository root. Run `wt --init` to create it interactively.

### Config Options

| Field | Type | Description |
|-------|------|-------------|
| `projectName` | string | Project identifier (used for worktree directory naming) |
| `mainBranch` | string | Main branch reference (e.g., `origin/main`) |
| `devBranch` | string | Dev branch reference for `-d` flag |
| `devSuffix` | string | Suffix added to dev worktree branches |
| `openCmd` | string | Hook script run after creating worktree |
| `switchCmd` | string | Hook script run after switching worktree |
| `worktreeWarningThreshold` | number | Warn when worktree count exceeds this |

Worktrees are created in `<parent>/<projectName>_worktrees` automatically (derived from the repository location and project name).

### Example Configuration

```json
{
  "projectName": "my-app",
  "mainBranch": "origin/main",
  "devBranch": "origin/develop",
  "devSuffix": "_DEV",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh",
  "worktreeWarningThreshold": 20
}
```

## Hooks

Hooks are bash scripts that run automatically after worktree operations:

| Hook | Trigger | Config key |
|------|---------|------------|
| `created` | After `wt -n`, `wt -o` (new worktree) | `openCmd` |
| `switched` | After `wt -s`, `wt -o` (existing worktree) | `switchCmd` |

Both hooks receive these arguments:

| Argument | Description |
|----------|-------------|
| `$1` | Worktree path |
| `$2` | Branch name |
| `$3` | Base ref (empty for `switched`) |
| `$4` | Main repository root |

### Example (created.sh)

```bash
#!/usr/bin/env bash
cd "$1" || exit 1
npm install
code .
```

For advanced usage, custom examples, and troubleshooting see [docs/hooks.md](docs/hooks.md).

## Shell Completions

Tab completion is automatically enabled for both **bash** and **zsh** when you source `wt.sh`. No manual setup is needed.

### What gets completed

| Context | Completion |
|---------|------------|
| `wt <Tab>` | All flags (short and long forms) |
| `wt -s <Tab>` | Existing worktree branch names |
| `wt -r <Tab>` | Existing worktree branch names |
| `wt -L <Tab>` / `wt -U <Tab>` | Existing worktree branch names |
| `wt -o <Tab>` | Git branches (local + remote) |
| `wt -b <Tab>` / `wt --from <Tab>` | Git branches (base ref selection) |
| `wt --log <Tab>` | Local branch names |
| `wt -n <Tab>` | No completion (new name expected) |
| `wt --rename <Tab>` | No completion (new name expected) |
| `wt -c 14 --<Tab>` | Modifier flags (`--merged`, `--pattern`, `--dry-run`, etc.) |

### How it works

- **Zsh**: Completions use `compdef`/`_describe` via `completions/_wt`, loaded through `fpath` and `autoload`.
- **Bash**: Completions use `complete`/`COMPREPLY` via `completions/wt.bash`, sourced directly. A fallback is provided when `bash-completion` is not installed.

### Manual setup (if auto-registration fails)

If completions are not working after sourcing `wt.sh`, add the following to your shell config:

**Zsh** (`~/.zshrc`):

```zsh
fpath=("$HOME/.worktree-helpers/completions" $fpath)
autoload -Uz _wt
compdef _wt wt
```

**Bash** (`~/.bashrc`):

```bash
source "$HOME/.worktree-helpers/completions/wt.bash"
```

### Known Limitations

**Windows (native):** `wt` requires a POSIX-compatible shell (bash or zsh). It works on macOS, Linux, and Windows via WSL — but not in native Windows environments (PowerShell, cmd.exe, Git Bash without a POSIX layer).

**Warp terminal (primary shell):** Tab completion does not work when Warp is the primary
zsh shell. Warp intercepts the Tab key at the terminal UI level before zsh's `compdef`/
`compsys` dispatch is consulted — this is an officially documented Warp incompatibility
with `compdef` and `compinit`.

**Workaround:** Start an inner `zsh` subprocess inside Warp:

```bash
zsh
```

Once inside the inner shell, source `wt.sh` (or it will be sourced automatically via
`.zshrc`) and Tab completion will work normally. Standard terminals (iTerm2, Terminal.app,
Kitty, Alacritty) are unaffected.

## Troubleshooting

### "Run 'wt --init' first"

You need to initialize worktree-helpers for this repository:

```bash
wt --init
```

### "jq is required"

Install jq:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Fedora
sudo dnf install jq
```

### "Install fzf or pass branch"

Either install fzf for interactive selection or provide the branch name directly:

```bash
# Install fzf
brew install fzf  # macOS
apt install fzf   # Ubuntu

# Or pass branch name
wt -s my-feature
```

### Worktree creation fails

1. Ensure the branch name doesn't already exist:

   ```bash
   git branch -a | grep my-branch
   ```

2. Check if worktree directory already exists:

   ```bash
   ls -la /path/to/worktrees/
   ```

3. Verify you have write permissions to the worktrees directory.

### Hook not running

1. Ensure the hook is executable:

   ```bash
   chmod +x .worktrees/hooks/created.sh
   ```

2. Check the hook path in config matches the actual file.

### "package.json not found"

This tool expects to be run in a Node.js project directory. Ensure you're in the correct directory with a `package.json` file.

## Uninstalling

### Automatic (recommended)

```bash
wt --uninstall
```

This removes the installation directory and source lines from your shell config. Add `-f` to skip the confirmation prompt.

You can also run the script directly:

```bash
~/.worktree-helpers/uninstall.sh
```

### Manual

1. Remove the source line from your shell config (`~/.zshrc` or `~/.bashrc`):

   ```bash
   # Remove these lines:
   # worktree-helpers
   source "$HOME/.worktree-helpers/wt.sh"
   ```

2. Remove the installation directory:

   ```bash
   rm -rf ~/.worktree-helpers
   ```

Project-specific configs (`.worktrees/` in your repos) are not removed automatically. Delete them manually if needed.

## Releasing

This project uses [commit-and-tag-version](https://github.com/absolute-version/commit-and-tag-version) for automated releases. Version bumps are determined from [Conventional Commits](https://www.conventionalcommits.org/):

| Commit type | Version bump | Example |
|-------------|-------------|---------|
| `fix:` | Patch (1.0.0 → 1.0.1) | `fix: resolve branch detection` |
| `feat:` | Minor (1.0.0 → 1.1.0) | `feat: add wt --status command` |
| `feat!:` / `BREAKING CHANGE` | Major (1.0.0 → 2.0.0) | `feat!: redesign config format` |

### Creating a release

```bash
# Preview changes (dry run)
npm run release:dry

# Create release (bumps version, updates CHANGELOG.md, creates git tag)
npm run release

# Push — GitHub Action automatically creates a GitHub Release
git push --follow-tags origin main
```

### Release scripts

| Script | Description |
|--------|-------------|
| `npm run release` | Auto-detect version bump from commits |
| `npm run release:minor` | Force minor version bump |
| `npm run release:major` | Force major version bump |
| `npm run release:dry` | Preview without making changes |

## Roadmap

This project is actively developed. Upcoming features:

- [x] **Shell completions** — tab completion for bash and zsh (flags, branch names, worktree paths)
- [x] **Self-update** — `wt --update` with non-blocking version check
- [x] **Granular clear** — `wt -c --merged`, `--pattern <glob>`, `--dry-run`
- [x] **Dirty/clean status** — `wt -l` shows uncommitted changes per worktree
- [ ] **Worktree metadata** — annotate worktrees with notes and see creation dates
- [ ] **Homebrew formula** — `brew install worktree-helpers`
- [ ] **oh-my-zsh / zinit plugin** — one-liner plugin installation

See [sprint plan](docs/sprint-plan-worktree-helpers-2026-02-08.md) for details and timeline.

## License

MIT
