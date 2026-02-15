# STORY-022: Improve wt --init worktrees path prompt

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 2
**Status:** Completed
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

> **Note:** STORY-026 removed the worktrees path prompt entirely from `wt --init`. The worktrees directory is now always auto-derived as `<parent>/<projectName>_worktrees`. The original worktrees path UX issues described below are no longer relevant. This story's remaining scope is limited to tab completion and UX improvements for the other `--init` prompts (Project name, Main branch, etc.).

The current `wt --init` command previously prompted for the worktrees directory. That prompt has been eliminated by STORY-026. The remaining UX improvements for other prompts include:

1. **No tab completion** — The `read -r` commands for other prompts don't support tab completion.
2. **Suffix customization** — No longer applicable (worktrees path is auto-derived).

### Scope

**In scope:**
- Enable tab completion on remaining `--init` prompts where useful (shell-aware: bash `read -e`, zsh `vared`, POSIX fallback)
- General UX improvements to `--init` prompts (Project name, Main branch, Warning threshold)

**Out of scope:**
- Worktrees path prompt (eliminated by STORY-026 — path is now auto-derived)
- Worktrees suffix customization (no longer applicable)
- Changes to STORY-021 init UX improvements (colorized output, hook suggestions, auto .gitignore are separate)

### User Flow

> **Note:** The worktrees path prompt was removed by STORY-026. The flow below reflects the remaining prompts.

**Current flow:**
1. User runs `wt --init`
2. Prompts for: Project name, Main branch, Warning threshold
3. No tab completion available on any prompt

**New flow:**
1. User runs `wt --init`
2. Prompts for: Project name, Main branch, Warning threshold
3. Tab completion works where applicable (in bash and zsh)

---

## Acceptance Criteria

> **Updated after STORY-026:** Worktrees path prompt was eliminated. Criteria related to worktrees path/suffix are no longer applicable.

- [ ] Tab completion works for remaining prompts in **bash** (via `read -e`) where applicable
- [ ] Tab completion works for remaining prompts in **zsh** (via `vared` or zsh-compatible readline) where applicable
- [ ] Falls back gracefully to plain `read -r` in POSIX shells without readline
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
