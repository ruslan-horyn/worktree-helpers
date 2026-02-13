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
- Age-based worktree cleanup with filters (`--dev-only`, `--main-only`)
- Lock/unlock worktree protection
- Branch rename without recreating worktree (`--rename`)
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
| `wt -n <branch> --from <ref>` | Create worktree from custom ref |
| `wt -n -d [name]` | Create worktree from dev branch |
| `wt -s [branch]` | Switch to worktree (fzf picker if no arg) |
| `wt -r [branch]` | Remove worktree and delete branch |
| `wt -o [branch]` | Open existing branch as worktree |
| `wt -l` | List all worktrees |
| `wt -c <days>` | Clear worktrees older than n days |
| `wt -L [branch]` | Lock worktree |
| `wt -U [branch]` | Unlock worktree |
| `wt --init` | Initialize project configuration |
| `wt --log [branch]` | Show commits vs main branch |
| `wt --rename <new-branch>` | Rename current worktree's branch |
| `wt --uninstall` | Uninstall worktree-helpers |
| `wt -v` / `wt --version` | Show version |
| `wt -h` | Show help |

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
wt -c 14

# Clear old worktrees (force, no confirmation)
wt -c 14 -f

# Clear only dev-based worktrees older than 30 days
wt -c 30 --dev-only

# Lock important worktree
wt -L production-fix

# View commits on current branch vs main
wt --log

# View commits with filters
wt --log feature-branch --since="2 weeks ago"
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

- [ ] **Shell completions** — tab completion for bash and zsh (flags, branch names, worktree paths)
- [ ] **Self-update** — `wt --update` with non-blocking version check
- [ ] **Granular clear** — `wt -c --merged`, `--pattern <glob>`, `--dry-run`
- [ ] **Dirty/clean status** — `wt -l` shows uncommitted changes per worktree
- [ ] **Worktree metadata** — annotate worktrees with notes and see creation dates
- [ ] **Homebrew formula** — `brew install worktree-helpers`
- [ ] **oh-my-zsh / zinit plugin** — one-liner plugin installation

See [sprint plan](docs/sprint-plan-worktree-helpers-2026-02-08.md) for details and timeline.

## License

MIT
