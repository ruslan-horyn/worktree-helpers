# STORY-032: Show only worktree name instead of full path everywhere

**Epic:** UX Polish
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-19
**Sprint:** 6

---

## User Story

As a developer with a long worktrees path
I want every `wt` command to show just the worktree name, not the full absolute path
So that all output is readable and not cluttered with irrelevant path prefixes

---

## Description

### Background

When `wt` displays worktrees in any context — listings, confirmation messages, fzf pickers,
remove/clear output — it shows the full absolute path of the worktree directory:

```
/Users/ruslanhoryn/Projects/imine-dashboard_worktrees/feature-foo
```

The `worktreesDir` prefix is always identical across all entries; it adds no useful
information to the reader. The only meaningful part is the last path segment — the
worktree name (e.g., `feature-foo`). Showing the full path wastes horizontal space,
makes fzf picker entries hard to scan, and clutters confirmation messages.

This affects every surface where `wt` outputs a worktree reference: `_cmd_list`,
`_cmd_new` (creation confirmation), `_cmd_open` (switch confirmation), `_cmd_remove`
(prompt and deletion message), `_cmd_clear` (listing and per-item removal messages),
`_cmd_lock`/`_cmd_unlock` (confirmation), and the `_wt_select` fzf picker.

### Scope

**In scope:**

- Create a shared display helper `_wt_display_name <path>` that returns `basename "$path"`
- Apply it in all user-facing output in `lib/commands.sh` and `lib/worktree.sh`
- Label the main worktree distinctly (e.g., `[root]`) in `wt -l` since it has no
  separate worktree name
- Consider adding a one-line header in `wt -l` showing the worktrees directory path
  (e.g., `Worktrees in: ~/Projects/imine-dashboard_worktrees/`) so users always know
  where their worktrees live even though individual paths are hidden
- Update BATS tests to assert on names, not full paths

**Out of scope:**

- Changing how paths are used internally (git operations always use full paths)
- Changing error messages that reference user-supplied arguments
- Changing hook invocations (hooks receive full paths as arguments by design)
- Shortening the worktrees directory path itself

### User Flow

1. Developer runs `wt -l` — sees a compact list of worktree names with status badges
2. Developer runs `wt -n feature/my-story` — sees `Created worktree: feature-my-story`
3. Developer runs `wt -r` or `wt -s` — fzf picker shows short names only
4. Developer runs `wt -c 30` — listing and per-item removal messages show names only
5. Developer runs `wt -L feature-foo` or `wt -U feature-foo` — confirmation uses name

### Expected Behaviour per Command

| Command | Before | After |
|---------|--------|-------|
| `wt -l` | `/Users/.../worktrees/feature-foo  [active] [clean]` | `feature-foo  [active] [clean]` |
| `wt -l` (main) | `/Users/.../project  main (main)  [active] [clean]` | `[root]  main (main)  [active] [clean]` |
| `wt -n` confirmation | `Creating worktree 'feat' from 'origin/main'` | `Creating worktree 'feat' from 'origin/main'` *(branch name already shown)* |
| `wt -o` already open | `Switching to 'branch': /Users/.../feature-foo` | `Switching to 'branch': feature-foo` |
| `wt -r` prompt | `Remove '/Users/.../feature-foo'? [y/N]` | `Remove 'feature-foo'? [y/N]` |
| `wt -r` / `wt -s` fzf | `/Users/.../feature-foo` | `feature-foo` |
| `wt -c` listing | `/Users/.../feature-foo (branch) - 14 days ago` | `feature-foo (branch) - 14 days ago` |
| `wt -c` locked skip | `/Users/.../feature-foo (branch) [locked]` | `feature-foo (branch) [locked]` |
| `wt -c` removal | `Removed /Users/.../feature-foo` | `Removed feature-foo` |
| `wt -L` / `wt -U` | `Locked /Users/.../feature-foo` | `Locked feature-foo` |

---

## Acceptance Criteria

- [ ] `wt -l` displays only the worktree name, not the full path
- [ ] `wt -l` labels the main worktree distinctly (e.g., `[root]`) instead of its full path
- [ ] `wt -n` success/info messages reference the worktree by name, not full path
- [ ] `wt -o` "switching" info message shows worktree name, not full path
- [ ] `wt -r` confirmation prompt shows worktree name, not full path
- [ ] `wt -r` / `wt -s` fzf picker entries (`_wt_select`) show only worktree name
- [ ] `wt -c` worktree listing shows name only (including locked-skip list and dry-run output)
- [ ] `wt -c` per-item removal message shows name only
- [ ] `wt -L` / `wt -U` confirmation messages show name only
- [ ] Shared `_wt_display_name <path>` helper used across all commands
- [ ] Main worktree (repo root) uses a fixed label rather than `basename` of repo path
- [ ] Full paths still used for all internal git operations (display-only change)
- [ ] BATS tests updated to assert on names instead of full paths
- [ ] `shellcheck` passes on all modified files

---

## Technical Notes

### Components Affected

- **`lib/utils.sh`** — add `_wt_display_name <path>` helper
- **`lib/worktree.sh`** — `_wt_select` (fzf picker), `_wt_open` (info message)
- **`lib/commands.sh`** — `_cmd_list`, `_cmd_remove`, `_cmd_clear`, `_cmd_lock`, `_cmd_unlock`
- **`test/cmd_list.bats`** — update assertions from full paths to names
- **`test/cmd_remove.bats`** — update prompt/confirmation assertions
- **`test/cmd_clear.bats`** — update listing and removal message assertions
- **`test/cmd_lock.bats`** — update confirmation assertions

### New Helper

Add to `lib/utils.sh`:

```sh
# Return display-friendly worktree name (basename of path)
# Usage: _wt_display_name <wt_path>
_wt_display_name() {
  basename "$1"
}
```

`basename` is POSIX-compliant and already used elsewhere in the codebase.

### Key Change Points in `lib/commands.sh`

**`_cmd_list`** (line 422):

```sh
# Before
printf "%-50s %s %s %s\n" "$worktree" "$branch_display" "$lock_indicator" "$dirty_indicator"

# After
local display_name
if [ -n "$is_main" ]; then
  display_name="[root]"
else
  display_name=$(_wt_display_name "$worktree")
fi
printf "%-30s %s %s %s\n" "$display_name" "$branch_display" "$lock_indicator" "$dirty_indicator"
```

**`_cmd_remove`** (line 39):

```sh
# Before
printf "Remove '%s'? [y/N] " "$wt_path" >&2

# After
printf "Remove '%s'? [y/N] " "$(_wt_display_name "$wt_path")" >&2
```

**`_cmd_clear`** locked-skip display (line 249):

```sh
# Before
echo "  ${C_DIM}$wt_path${C_RESET} ($br) ${C_RED}[locked]${C_RESET}" >&2

# After
echo "  ${C_DIM}$(_wt_display_name "$wt_path")${C_RESET} ($br) ${C_RED}[locked]${C_RESET}" >&2
```

**`_cmd_clear`** listing and dry-run (lines 296-319):
Replace `$wt_path` display with `$(_wt_display_name "$wt_path")`.

**`_cmd_clear`** removal confirmation (line 346-349):

```sh
# Before
_info "Removed $wt_path"

# After
_info "Removed $(_wt_display_name "$wt_path")"
```

**`_cmd_lock` / `_cmd_unlock`** (lines 79, 86):

```sh
# Before
git worktree lock "$wt_path" && _info "Locked $wt_path"

# After
git worktree lock "$wt_path" && _info "Locked $(_wt_display_name "$wt_path")"
```

### Key Change Points in `lib/worktree.sh`

**`_wt_select`** fzf picker (line 36):

```sh
# Before
git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | fzf --prompt="${1:-wt> }"

# After
git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while IFS= read -r p; do
  basename "$p"
done | fzf --prompt="${1:-wt> }"
```

Note: If `_wt_select` is modified to return names instead of full paths, callers that
use its output as a path (`_wt_resolve`) must be reviewed. The safest approach is to
keep `_wt_select` returning full paths and apply `_wt_display_name` only at the display
layer — or maintain a name→path mapping for the fzf picker. Consider using `awk` to
format `name -> full_path` and pipe through `fzf --with-nth=1` to show only names while
preserving the full path for selection output.

Alternative fzf approach (recommended for correctness):

```sh
_wt_select() {
  command -v fzf >/dev/null 2>&1 || { _err "Install fzf or pass branch"; return 1; }
  # Pipe "name\tfull_path" to fzf; display only name (field 1), output full path (field 2)
  git worktree list --porcelain \
    | awk '/^worktree /{p=substr($0,10); printf "%s\t%s\n", p, p}' \
    | awk -F'\t' '{n=$1; sub(/.*\//, "", n); print n "\t" $2}' \
    | fzf --prompt="${1:-wt> }" --with-nth=1 --delimiter='\t' \
    | cut -f2
}
```

This returns the full path to callers while displaying only names in the fzf UI.

### BATS Test Updates

- `test/cmd_list.bats`: change `assert_output --partial "$wt_path"` to
  `assert_output --partial "list-branch"` (use branch/name instead of full path)
- `test/cmd_remove.bats`: update prompt assertion from full path to name
- `test/cmd_clear.bats`: update listing and removal message assertions
- `test/cmd_lock.bats`: update confirmation assertions

### Edge Cases

- Main worktree has no worktree-specific name (it IS the repo root); label as `[root]`
- Worktree paths with trailing slashes: `basename` handles these correctly
- Worktrees not under `GWT_WORKTREES_DIR` (user-managed paths): `basename` still works
- fzf not installed: existing fallback paths in `_wt_resolve` remain unaffected

---

## Dependencies

- **STORY-011**: Show dirty/clean status in `wt -l` (completed — this builds on that output format)
- **STORY-031**: Replace slashes with dashes in worktree directory names (Sprint 6 — if delivered
  first, the worktree names shown by this story will already be dash-normalised, which is correct)

---

## Definition of Done

- [ ] `_wt_display_name` helper added to `lib/utils.sh`
- [ ] All user-facing output in `lib/commands.sh` uses display name instead of full path
- [ ] `_wt_select` fzf picker in `lib/worktree.sh` shows names while returning full paths to callers
- [ ] `_cmd_list` labels main worktree as `[root]`
- [ ] BATS tests updated for new output format across all affected commands
- [ ] `shellcheck` passes on all modified files (`lib/utils.sh`, `lib/commands.sh`, `lib/worktree.sh`)
- [ ] No regressions: full paths still used for all git operations internally
- [ ] Works in both zsh and bash

---

## Story Points Breakdown

- **`_wt_display_name` helper + `lib/utils.sh`:** 0.5 points
- **`lib/commands.sh` display updates (5 commands):** 0.5 points
- **`lib/worktree.sh` fzf picker update:** 0.5 points
- **BATS test updates:** 0.5 points
- **Total:** 2 points

**Rationale:** All changes are mechanical substitutions of `$path` with `_wt_display_name "$path"`.
The only complexity is the fzf picker, which needs to display names while returning full paths.
No new logic, no schema changes, no external dependencies. 2 points is appropriate.

---

## Additional Notes

- The `_cmd_new` creation message (`Creating worktree 'branch' from 'ref'`) already uses
  the branch name, not the path — no change needed there.
- The `_cmd_rename` confirmation (`Renamed 'old' → 'new'` and `Worktree: $new_path`) uses
  the full path for the worktree location line; this is informational and acceptable to
  keep as a full path since the user just moved a directory.
- Consider whether `wt -l` should display a header line with the worktrees directory
  (e.g., `Worktrees in ~/Projects/imine-dashboard_worktrees/`) so context is never lost.
  This is a minor UX addition and should be implemented if it fits within the 2-point estimate.

---

## Progress Tracking

**Status History:**

- 2026-02-19: Created by Ruslan Horyn (BMAD Scrum Master)

**Actual Effort:** TBD (will be filled during/after implementation)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
