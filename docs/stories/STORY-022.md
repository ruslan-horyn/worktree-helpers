# STORY-022: Improve wt --init worktrees path prompt

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-10
**Sprint:** 4

---

## User Story

As a developer setting up worktree-helpers for a new project
I want the worktrees path prompt during `wt --init` to support tab completion, have a clearer label, and offer a smart default suffix
So that I can configure the worktrees directory faster and with fewer typos

---

## Description

### Background

The current `wt --init` command prompts for the worktrees directory with:

```
Worktrees dir [/Users/dev/projects/myapp_worktrees]:
```

This has three UX issues:

1. **No tab completion** — The `read -r` command doesn't support filesystem tab completion, forcing users to type full paths manually (error-prone for long paths).
2. **Unclear label** — "Worktrees dir" is abbreviated and slightly ambiguous. "Worktrees path" is clearer and more conventional.
3. **No suffix customization** — The default `_worktrees` suffix is hardcoded in the path computation. Users who want a different naming convention (e.g., `-worktrees`, `.worktrees`, `_wt`) must retype the entire path.

### Scope

**In scope:**
- Enable filesystem tab completion on the worktrees path prompt (shell-aware: bash `read -e`, zsh `vared`, POSIX fallback)
- Rename prompt label from "Worktrees dir" to "Worktrees path"
- Show default suffix separately and allow editing just the suffix (e.g., `Worktrees suffix [_worktrees]:` then compute full path, or show full path but highlight the editable suffix)
- Keep the full path override working (user can still type an absolute path)

**Out of scope:**
- Tab completion for other init prompts (Project, Main branch, etc.) — that could be a follow-up
- Changing the default suffix value itself (remains `_worktrees`)
- Changes to STORY-021 init UX improvements (colorized output, hook suggestions, auto .gitignore are separate)

### User Flow

**Current flow:**
1. User runs `wt --init`
2. Prompt: `Worktrees dir [/path/to/project_worktrees]:`
3. User must type full path or press Enter for default
4. No tab completion available

**New flow:**
1. User runs `wt --init`
2. Prompt: `Worktrees path [/path/to/project_worktrees]:`
3. Tab completion works for filesystem paths (in bash and zsh)
4. If user wants to change just the suffix, a secondary approach:
   - Show the computed base (`/path/to/parent/projectname`) and ask for suffix
   - `Worktrees suffix [_worktrees]:` → user types `_wt` → full path becomes `/path/to/parent/projectname_wt`
   - Or: user types an absolute path to override entirely

---

## Acceptance Criteria

- [ ] Prompt label changed from "Worktrees dir" to "Worktrees path"
- [ ] Tab completion works for filesystem paths in **bash** (via `read -e`)
- [ ] Tab completion works for filesystem paths in **zsh** (via `vared` or zsh-compatible readline)
- [ ] Falls back gracefully to plain `read -r` in POSIX shells without readline
- [ ] Default suffix `_worktrees` is shown and editable separately:
  - Prompt shows: `Worktrees suffix [_worktrees]:` (user can change just the suffix)
  - Then shows computed full path for confirmation: `Worktrees path: /parent/project_wt ✓`
- [ ] User can still override with a full absolute path (if input starts with `/`, use it as-is)
- [ ] Existing config.json output format unchanged (`worktreesDir` key)
- [ ] Works correctly when project name contains special characters (spaces, hyphens)
- [ ] Unit test coverage for the new prompt logic (helper function testable in isolation)

---

## Technical Notes

### Components

- **`lib/commands.sh`** — `_cmd_init` function, lines 352-401 (primary change)
- **`lib/utils.sh`** — New helper `_read_path` for shell-aware readline input

### Implementation Approach

**1. Create `_read_path` helper in `lib/utils.sh`:**

```shell
# Read user input with filesystem tab completion (when available)
# Usage: _read_path <prompt> <default> <varname>
_read_path() {
  local prompt="$1" default="$2"
  if [ -n "${ZSH_VERSION:-}" ]; then
    # zsh: use vared for tab completion
    local REPLY="$default"
    printf "%s" "$prompt" >&2
    vared REPLY
    echo "$REPLY"
  elif [ -n "${BASH_VERSION:-}" ]; then
    # bash: use read -e for readline tab completion
    local REPLY
    read -e -r -p "$prompt" -i "$default" REPLY
    echo "${REPLY:-$default}"
  else
    # POSIX fallback: plain read
    printf "%s" "$prompt" >&2
    local r
    read -r r
    echo "${r:-$default}"
  fi
}
```

**2. Update `_cmd_init` in `lib/commands.sh`:**

Replace the single worktrees dir prompt with:

```shell
# Compute base path and default suffix
local base_path="${root%/*}/${name}"
local wt_suffix="_worktrees"

# Ask for suffix (simple read is fine here)
printf "Worktrees suffix [%s]: " "$wt_suffix" >&2; read -r r; [ -n "$r" ] && wt_suffix="$r"

# Compute full path
local wt_dir="${base_path}${wt_suffix}"

# Show full path with tab-completion override option
local override
override=$(_read_path "Worktrees path [$wt_dir]: " "$wt_dir")
[ -n "$override" ] && wt_dir="$override"
```

### Edge Cases

- **Absolute path override:** If user types a path starting with `/`, use it directly (ignore suffix logic)
- **Empty suffix:** If user clears the suffix, worktrees dir = base path (valid but unusual)
- **Spaces in path:** Ensure quoting handles paths with spaces
- **zsh `vared` availability:** `vared` is a zsh builtin, always available in zsh — no external dependency
- **bash `read -e -i`:** The `-i` flag (initial text) requires bash 4.0+. On macOS with bash 3.x, fall back to `read -e` without `-i`

### Testing Strategy

- Test `_read_path` helper in `test/utils.bats`:
  - Mock `BASH_VERSION` / `ZSH_VERSION` to test branch selection
  - Verify default value returned when user presses Enter
  - Verify custom value returned when user types input
- Test `_cmd_init` path prompt in `test/commands.bats`:
  - Verify config.json has correct `worktreesDir` with default suffix
  - Verify config.json has correct `worktreesDir` with custom suffix
  - Verify absolute path override works

### Security Considerations

- No new external inputs beyond filesystem paths (already trusted)
- `vared` and `read -e` are shell builtins — no external command risk

---

## Dependencies

**Prerequisite Stories:**
- None (independent improvement to existing `--init` command)

**Blocked Stories:**
- None

**Related Stories:**
- STORY-021: Improve wt --init UX (colorized output, hook suggestions, auto .gitignore) — complementary but independent

**External Dependencies:**
- None

---

## Definition of Done

- [ ] Code implemented following POSIX conventions (`_` prefix functions, `GWT_*` globals)
- [ ] `_read_path` helper added to `lib/utils.sh`
- [ ] `_cmd_init` updated in `lib/commands.sh`
- [ ] Prompt label reads "Worktrees path" (not "Worktrees dir")
- [ ] Tab completion works in bash (4.0+)
- [ ] Tab completion works in zsh
- [ ] Graceful fallback in POSIX shells
- [ ] Suffix prompt allows quick customization
- [ ] Absolute path override works
- [ ] BATS tests cover new helper and init prompt changes
- [ ] Shellcheck passes
- [ ] Manual testing in both bash and zsh
- [ ] Help text unchanged (no user-facing flag changes)

---

## Story Points Breakdown

- **`_read_path` helper:** 0.5 points
- **`_cmd_init` prompt refactor:** 0.5 points
- **Shell compatibility (bash/zsh/POSIX):** 0.5 points
- **Testing:** 0.5 points
- **Total:** 2 points

**Rationale:** Small, focused UX improvement touching 2 files with a clear implementation path. Shell-aware readline adds some complexity but the approach is well-understood.

---

## Additional Notes

- The `_read_path` helper can be reused by STORY-021 and future interactive prompts
- bash 3.x (macOS default) doesn't support `read -e -i` — degrade to `read -e` (tab works, but no pre-filled default shown inline)
- Consider: if STORY-021 adds colorized output, the prompt label here should use those colors too — coordinate during implementation

---

## Progress Tracking

**Status History:**
- 2026-02-10: Created

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
