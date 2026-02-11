# Hooks

Every time you create a worktree or switch to one, there's repetitive setup: `npm install`,
copy `.env`, open your editor, start services. Hooks eliminate this entirely.

Hooks are bash scripts that `wt` runs automatically after worktree operations. Define your
setup once — it runs on every `wt -n`, `wt -o`, and `wt -s`. One-time config, zero repetition.

## Quick start

1. **Initialize** (creates hook templates):

   ```bash
   wt --init
   ```

2. **Edit the created hook** — add your setup commands:

   ```bash
   # .worktrees/hooks/created.sh
   #!/usr/bin/env bash
   cd "$1" || exit 1
   npm install
   code .
   ```

3. **Create a worktree** — the hook runs automatically:

   ```bash
   wt -n my-feature
   # -> creates worktree, then runs created.sh (npm install + code .)
   ```

That's it. Read on for the full reference.

## Hook types

| Hook | Trigger | Config key |
|------|---------|------------|
| **created** | After `wt -n` / `wt -n -d` (new worktree) and `wt -o` (open branch as new worktree) | `openCmd` |
| **switched** | After `wt -s` (switch worktree) and `wt -o` (when worktree already exists) | `switchCmd` |

### Commands that do **not** trigger hooks

`wt --rename <new-branch>` renames the current worktree's branch and moves the worktree directory to match, but it does **not** fire any hooks. The rename is an in-place operation — the worktree contents, uncommitted changes, and stash all remain untouched; only the branch name and directory path change. Because no new worktree is created and no context switch occurs, neither the `created` nor the `switched` hook applies.

Other commands that skip hooks: `wt -l` (list), `wt -c` (clear), `wt -r` (remove), `wt -L`/`-U` (lock/unlock), `wt --log`, `wt --init`.

## Hook lifecycle

The diagrams below show where each hook fires. All steps before the bold line have already
completed by the time your script runs.

### `wt -n <branch>` / `wt -n -d [name]`

```
validate args & config
  -> mkdir worktrees dir
  -> git worktree add -b <branch> <path> <ref>
  -> configure branch tracking (remote + merge)
  -> symlink .worktrees/hooks/ into worktree
  -> git fetch <ref>
  -> **run created hook** ($1=path, $2=branch, $3=ref, $4=root)
  -> warn if worktree count exceeds threshold
```

### `wt -o <branch>` — branch has no worktree yet

```
validate args & config
  -> git fetch origin
  -> git worktree add <path> <branch>
  -> symlink .worktrees/hooks/ into worktree
  -> **run created hook** ($1=path, $2=branch, $3=branch, $4=root)
  -> warn if worktree count exceeds threshold
```

### `wt -o <branch>` — worktree already exists

```
validate args & config
  -> detect existing worktree path
  -> **run switched hook** ($1=path, $2=branch, $3="", $4=root)
```

### `wt -s [branch]`

```
validate args & config
  -> resolve worktree path (from arg or fzf)
  -> **run switched hook** ($1=path, $2=branch, $3="", $4=root)
```

## Arguments

Both hooks receive the same positional arguments:

| Argument | Description | Example |
|----------|-------------|---------|
| `$1` | Worktree path | `/home/user/projects/my-app_worktrees/feature-login` |
| `$2` | Branch name | `feature-login` |
| `$3` | Base ref (empty for `switched`) | `origin/main` |
| `$4` | Main repository root | `/home/user/projects/my-app` |

For `switched` hooks, `$3` is always an empty string.

### `$3` (base ref) by command

| Command | Hook | `$3` value | Example |
|---------|------|-----------|---------|
| `wt -n <branch>` | created | `GWT_MAIN_REF` from config | `origin/main` |
| `wt -n <branch> --from <ref>` | created | user-specified `<ref>` | `release/2.0` |
| `wt -n -d [name]` | created | `GWT_DEV_REF` from config | `origin/release-next` |
| `wt -o <branch>` (new) | created | branch name itself | `feature-login` |
| `wt -o <branch>` (existing) | switched | empty string | |
| `wt -s [branch]` | switched | empty string | |

## Execution environment

- Hooks are executed via **bash** (resolved in order: `/bin/bash` → `/usr/bin/bash` → `command -v bash`)
- `PATH` is set to `/usr/local/bin:/usr/bin:/bin:$PATH` before execution
- Hook output (stdout and stderr) is captured and printed with a **2-space indent**
- The hook must be **executable** (`chmod +x`); if the file is missing or not executable it is silently skipped
- If bash cannot be found on the system, an error is printed and the hook is skipped

## Configuration

Hooks are configured in `.worktrees/config.json`:

```json
{
  "openCmd": ".worktrees/hooks/created.sh",
  "switchCmd": ".worktrees/hooks/switched.sh"
}
```

### Path resolution

- **Relative paths** are resolved from the main repository root (e.g. `.worktrees/hooks/created.sh` → `<repo-root>/.worktrees/hooks/created.sh`)
- **Absolute paths** are used as-is (e.g. `/opt/scripts/my-hook.sh`)

### Defaults

When `openCmd` or `switchCmd` are omitted from the config (or empty), they default to:

| Key | Default |
|-----|---------|
| `openCmd` | `.worktrees/hooks/created.sh` |
| `switchCmd` | `.worktrees/hooks/switched.sh` |

## Hook symlinking

When a new worktree is created (`wt -n`, `wt -o`), `wt` automatically symlinks the `.worktrees/hooks/` directory from the main repository into the new worktree. This ensures all worktrees share the same hook scripts.

Behavior of `_symlink_hooks`:

1. **Source**: `<main-repo>/.worktrees/hooks`
2. **Destination**: `<worktree>/.worktrees/hooks`
3. If the source directory doesn't exist, nothing happens
4. If a symlink already exists at the destination, nothing happens
5. Creates `<worktree>/.worktrees/` if needed
6. Attempts `ln -s` (symlink); falls back to `cp -R` (copy) if symlinking fails
7. If both fail, continues silently

## Default templates

Running `wt --init` generates minimal hook templates at `.worktrees/hooks/created.sh` and `.worktrees/hooks/switched.sh`:

```bash
#!/usr/bin/env bash
cd "$1" || exit 1
```

Both hooks are made executable automatically. If hooks already exist and differ from the new template, the existing hook is backed up with an `_old` suffix (e.g. `created.sh_old`) before being overwritten.

## Examples

### Install dependencies and open editor

```bash
#!/usr/bin/env bash
cd "$1" || exit 1

npm install
code .
```

### Copy environment files from main repo

```bash
#!/usr/bin/env bash
wt_path="$1"
main_root="$4"

cd "$wt_path" || exit 1

# Copy .env from main repo if it exists
if [ -f "$main_root/.env" ]; then
  cp "$main_root/.env" "$wt_path/.env"
  echo "Copied .env from main repo"
fi
```

### Run database migrations

```bash
#!/usr/bin/env bash
cd "$1" || exit 1

npm install
npx prisma migrate deploy
echo "Migrations applied for branch $2"
```

### Full setup hook (created.sh)

```bash
#!/usr/bin/env bash
wt_path="$1"
branch="$2"
base_ref="$3"
main_root="$4"

cd "$wt_path" || exit 1

# Install dependencies
npm install

# Copy environment files
for f in .env .env.local; do
  [ -f "$main_root/$f" ] && cp "$main_root/$f" "$wt_path/$f"
done

# Open in editor
code .

echo "Worktree ready: $branch (from $base_ref)"
```

### Switch hook with notification (switched.sh)

```bash
#!/usr/bin/env bash
cd "$1" || exit 1

# Reinstall if lockfile changed
if ! diff -q package-lock.json "$4/package-lock.json" >/dev/null 2>&1; then
  echo "package-lock.json differs — running npm install"
  npm install
fi

code .
```

## Troubleshooting

### Hook not running

1. **Not executable** — ensure the hook file has execute permission:

   ```bash
   chmod +x .worktrees/hooks/created.sh
   chmod +x .worktrees/hooks/switched.sh
   ```

2. **Path mismatch** — verify the `openCmd`/`switchCmd` paths in `.worktrees/config.json` match the actual file locations. Relative paths are resolved from the repo root.

3. **bash not found** — `wt` looks for bash at `/bin/bash`, `/usr/bin/bash`, then `command -v bash`. Ensure bash is installed and accessible.

4. **Hook exists but is empty** — a hook file with no meaningful commands will run without visible output. Add an `echo` statement to verify it executes.

### Hook output is indented

This is expected. All hook output is prefixed with two spaces to visually separate it from `wt` output.

### Symlink not created

- The source directory (`.worktrees/hooks/` in the main repo) must exist
- If the destination already has a symlink, it is not recreated
- On filesystems that don't support symlinks, `wt` falls back to copying the hooks directory
