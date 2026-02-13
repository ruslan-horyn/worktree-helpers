# STORY-026: Remove worktreesDir from config and always auto-derive path

**Epic:** Core Simplification
**Priority:** Must Have
**Story Points:** 3
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-12
**Sprint:** 4

---

## User Story

As a developer using worktree-helpers
I want the worktrees directory path to be automatically derived from the project name and repo location
So that I don't have to configure it manually, and the path is always correct regardless of which worktree I'm in

---

## Description

### Background

`_config_load` in `lib/config.sh` currently reads `worktreesDir` from `.worktrees/config.json` (line 11) and falls back to auto-deriving the path when the field is empty (lines 32-37). This creates two problems:

1. **Unnecessary configuration** — the `worktreesDir` field in config is redundant because the path can always be derived as `<parent_of_repo>/<projectName>_worktrees`. Users never need to customize it since the convention is deterministic.

2. **Bug in fallback** — the fallback code on lines 32-37 uses `_repo_root()` (which returns the root of the *current* worktree) instead of the `root` variable from line 5 (which is `_main_repo_root()` — always the main repository). This means the derived path is incorrect when running from inside a worktree.

The fix is simple: remove `worktreesDir` from the config schema entirely and always derive the path using the already-correct `root` variable.

### Scope

**In scope:**
- Remove `worktreesDir` jq read from `_config_load` (config.sh line 11)
- Remove the fallback block (config.sh lines 32-37)
- Add deterministic derivation after defaults are applied (after line 26): `GWT_WORKTREES_DIR="${root%/*}/${GWT_PROJECT_NAME}_worktrees"`
- Remove `worktreesDir` variable, prompt, and JSON field from `_cmd_init` (commands.sh)
- Remove `worktreesDir` from `.worktrees/config.json`
- Update test helper template and config tests
- Update README (config table, example JSON)
- Update STORY-022 scope (worktrees path prompt is now eliminated)

**Out of scope:**
- Migration script for existing configs (field is simply ignored — backward compatible)
- Changing the naming convention (`_worktrees` suffix)
- Changing `_main_repo_root()` implementation

### Backward Compatibility

Existing configs with `worktreesDir` field: the field is simply ignored (not read by `_config_load`). The derived path will be identical to the previously configured value as long as `projectName` and repo location haven't changed. No migration is needed.

---

## Acceptance Criteria

- [ ] `_config_load` does NOT read `worktreesDir` from config.json
- [ ] `GWT_WORKTREES_DIR` is always derived as `<parent_of_main_repo>/<projectName>_worktrees`
- [ ] Derivation uses `_main_repo_root()` (via `root` variable), NOT `_repo_root()`
- [ ] `wt --init` does NOT prompt for worktrees directory
- [ ] `wt --init` does NOT write `worktreesDir` to config.json
- [ ] Existing configs with `worktreesDir` field still work (field is ignored)
- [ ] Path is correct when running from inside a worktree (not just main repo)
- [ ] All existing BATS tests pass (updated as needed)
- [ ] `.worktrees/config.json` in the repo itself has `worktreesDir` removed
- [ ] README updated: `worktreesDir` removed from config table and example JSON, auto-derivation noted

---

## Technical Notes

### Components

- **`lib/config.sh`** — `_config_load` function (primary change)
- **`lib/commands.sh`** — `_cmd_init` function (remove prompt and JSON field)
- **`.worktrees/config.json`** — remove `worktreesDir` field
- **`test/test_helper.bash`** — remove `worktreesDir` from template config
- **`test/config.bats`** — update 3 tests
- **`README.md`** — remove from config table and example
- **`docs/stories/STORY-022.md`** — update scope

### Changes Detail

**1. `lib/config.sh` — `_config_load`**

Remove line 11 (`GWT_WORKTREES_DIR` jq read):
```sh
# REMOVE:
GWT_WORKTREES_DIR=$(jq -r '.worktreesDir // empty' "$cfg")
```

Remove lines 32-37 (buggy fallback):
```sh
# REMOVE:
if [ -z "$GWT_WORKTREES_DIR" ]; then
  local repo_root
  repo_root=$(_repo_root)          # BUG: should be $root (_main_repo_root)
  repo_root="${repo_root%/*}"
  GWT_WORKTREES_DIR="$repo_root/${GWT_PROJECT_NAME}_worktrees"
fi
```

Add after line 26 (after all defaults are applied):
```sh
# Always derive worktrees directory from main repo root and project name
GWT_WORKTREES_DIR="${root%/*}/${GWT_PROJECT_NAME}_worktrees"
```

**2. `lib/commands.sh` — `_cmd_init`**

Remove line 361 (`wt_dir` variable):
```sh
# REMOVE:
local wt_dir="${root%/*}/${name}_worktrees"
```

Remove line 365 (worktrees dir prompt):
```sh
# REMOVE:
printf "Worktrees dir [%s]: " "$wt_dir" >&2; read -r r; [ -n "$r" ] && wt_dir="$r"
```

Remove `worktreesDir` from JSON output (~line 393):
```sh
# REMOVE from config JSON:
"worktreesDir": "$wt_dir",
```

**3. `.worktrees/config.json`**

Remove line 3:
```json
"worktreesDir": "/Users/ruslanhoryn/Own_projects/worktree-helpers_worktrees",
```

**4. `test/test_helper.bash:82`**

Remove `worktreesDir` line from `create_test_config`:
```sh
# REMOVE:
"worktreesDir": "$TEST_TEMP_DIR/test-project_worktrees",
```

**5. `test/config.bats` — Update 3 tests**

- **Line 25** (`_config_load parses all fields`): Remove `GWT_WORKTREES_DIR` assertion from "parses all fields" test — it's now always derived, not parsed.
- **Lines 104-124** (`_config_load keeps absolute hook paths`): Remove `worktreesDir` from config JSON in test fixture.
- **Lines 126-143** (`_config_load derives worktreesDir when not set`): Rename test to verify derivation always works (not just "when not set"). The assertion itself stays the same.

**6. `README.md`**

- Remove `worktreesDir` row from config options table (~line 173)
- Remove `worktreesDir` from example JSON (~line 186)
- Add note about auto-derivation (e.g., "Worktrees are created in `<parent>/<projectName>_worktrees` automatically")

### Edge Cases

- **Project name with special characters:** derivation uses `GWT_PROJECT_NAME` as-is — same behavior as before
- **Config without `worktreesDir`:** works by design (field no longer read)
- **Config WITH `worktreesDir`:** field is ignored, no error, no warning
- **Running from inside a worktree:** `root` uses `_main_repo_root()` (git-common-dir), so path is always correct

### Security Considerations

- No new inputs or attack surface — derivation uses existing trusted variables

---

## Dependencies

**Prerequisite Stories:**
- None (standalone simplification)

**Blocked Stories:**
- None

**Related Stories:**
- STORY-022: Improve `wt --init` worktrees path prompt — scope is reduced (worktrees path prompt is eliminated entirely; only suffix/tab-completion improvements for other prompts remain relevant)

**External Dependencies:**
- None

---

## Definition of Done

- [ ] `lib/config.sh` — `worktreesDir` jq read and fallback removed, deterministic derivation added
- [ ] `lib/commands.sh` — `_cmd_init` no longer prompts for or writes `worktreesDir`
- [ ] `.worktrees/config.json` — `worktreesDir` field removed
- [ ] `test/test_helper.bash` — template config updated
- [ ] `test/config.bats` — 3 tests updated and passing
- [ ] `README.md` — config table and example JSON updated, auto-derivation noted
- [ ] `docs/stories/STORY-022.md` — scope updated to reflect reduced scope
- [ ] All existing BATS tests pass
- [ ] Shellcheck passes
- [ ] CI pipeline green
- [ ] Manual testing: `wt --init` works without worktreesDir prompt, all commands derive path correctly

---

## Story Points Breakdown

- **`_config_load` refactor:** 1 point (remove jq read, remove fallback, add derivation line)
- **`_cmd_init` cleanup:** 0.5 points (remove variable, prompt, JSON field)
- **Test updates:** 1 point (update 3 tests + helper template)
- **Docs updates:** 0.5 points (README, STORY-022)
- **Total:** 3 points

**Rationale:** The changes are surgical — removing code is simpler than adding. The derivation formula is already proven (it's the existing fallback, just with the correct variable). The main effort is updating tests and documentation.

---

## Additional Notes

- This story fixes a latent bug (wrong `_repo_root()` in fallback) while simultaneously simplifying the config schema. Two wins in one.
- After this story, STORY-022 can focus solely on improving other `--init` prompts (tab completion, suffix customization) without the worktrees path prompt.
- The derived path convention `<parent>/<projectName>_worktrees` ensures worktrees sit next to the repo (sibling directory), which is the universal convention in this tool.

---

## Progress Tracking

**Status History:**
- 2026-02-12: Created

**Actual Effort:** TBD
