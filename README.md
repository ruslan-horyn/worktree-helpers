# worktree-helpers

A POSIX-compatible shell CLI tool (`wt`) for managing git worktrees with a unified interface, project-specific configuration, and customizable hooks. Works with bash, zsh, and other POSIX-compliant shells.

## Features

- Single `wt` command with intuitive flags
- Create worktrees from main or dev branches
- Interactive selection with fzf integration
- Project-specific configuration per repository
- Customizable hooks (on create/switch)
- Hook symlinking from main repo to worktrees
- Age-based worktree cleanup
- Lock/unlock worktree protection
- Colored output with status indicators

## Requirements

- **git** (required)
- **jq** (required) - for JSON config parsing
- **fzf** (optional) - for interactive worktree/branch selection

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
| `wt -n -d [name]` | Create worktree from dev branch |
| `wt -s [branch]` | Switch to worktree (fzf picker if no arg) |
| `wt -r [branch]` | Remove worktree and delete branch |
| `wt -o [branch]` | Open existing branch as worktree |
| `wt -l` | List all worktrees |
| `wt -c <unit> <n>` | Clear worktrees older than n units |
| `wt -L [branch]` | Lock worktree |
| `wt -U [branch]` | Unlock worktree |
| `wt --init` | Initialize project configuration |
| `wt --log [branch]` | Show commits vs main branch |
| `wt -h` | Show help |

### Examples

```bash
# Create a new feature worktree from main
wt -n my-feature

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

# Clear worktrees older than 2 weeks
wt -c week 2

# Clear old worktrees (force, no confirmation)
wt -c week 2 -f

# Clear only dev-based worktrees older than 1 month
wt -c month 1 --dev-only

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
| `worktreesDir` | string | Directory where worktrees are created |
| `mainBranch` | string | Main branch reference (e.g., `origin/main`) |
| `devBranch` | string | Dev branch reference for `-d` flag |
| `devSuffix` | string | Suffix added to dev worktree branches |
| `openCmd` | string | Hook script run after creating worktree |
| `switchCmd` | string | Hook script run after switching worktree |
| `worktreeWarningThreshold` | number | Warn when worktree count exceeds this |

### Example Configuration

```json
{
  "projectName": "my-app",
  "worktreesDir": "/Users/me/projects/my-app_worktrees",
  "mainBranch": "origin/main",
  "devBranch": "origin/develop",
  "devSuffix": "_DEV",
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh",
  "worktreeWarningThreshold": 20
}
```

## Hooks

Hooks are bash scripts that run after worktree operations. They receive these arguments:

| Argument | Description |
|----------|-------------|
| `$1` | Worktree path |
| `$2` | Branch name |
| `$3` | Base branch (for created hook) |
| `$4` | Main repository root |

### Hook Locations

```
.worktrees/
  config.json
  hooks/
    created.sh    # Runs after creating worktree
    switched.sh   # Runs after switching worktree
```

### Example Hook (created.sh)

```bash
#!/usr/bin/env bash
cd "$1" || exit 1

# Install dependencies
npm install

# Open in editor
code .
```

### Hook Symlinking

When you create a new worktree, hooks are automatically symlinked from the main repository. This ensures all worktrees use the same hook scripts without duplication.

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

3. Optionally, remove project configurations:
   ```bash
   rm -rf /path/to/repo/.worktrees
   ```

## License

MIT
