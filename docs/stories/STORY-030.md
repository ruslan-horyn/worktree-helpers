# STORY-030: Fix completions in Warp + zsh to work like git

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 5
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-19
**Sprint:** 6

---

## User Story

As a developer using Warp terminal with zsh
I want `wt` tab completions to work the same way `git` completions do
So that I can complete branch names, worktree names, and flags without leaving the keyboard

---

## Description

### Background

Tab completions were delivered in STORY-014 (v1.3.0) and the compinit ordering fix was
delivered in STORY-028 (v1.3.1). Despite both fixes, users on Warp terminal report that
pressing `<Tab>` after `wt` or `wt -s` produces nothing — while `git <Tab>` works perfectly
in the same shell session.

**Root cause (hypothesis):** Warp uses its own proprietary completion engine that bypasses
the standard zsh `compdef`/`compsys` dispatch. Git completions work in Warp because
`git-completion.zsh` is registered through a mechanism Warp supports (likely pure `fpath`
discovery with a `#compdef git` header, or a `compctl`-based fallback). The current
`_wt` function relies entirely on `compdef _wt wt` which Warp does not honour.

**Observed behaviour:**

- `wt <Tab>` → nothing (Warp + zsh)
- `git <Tab>` → shows all git subcommands (Warp + zsh, same session)
- `wt <Tab>` → shows flags correctly (iTerm2/Terminal.app + zsh)

### Scope

**In scope:**

- Investigate how git's completion registers with Warp and replicate that mechanism for `wt`
- Ensure the fix works for all completion contexts: flags, worktree branches, git branches, refs
- Preserve all existing completion behaviour in standard zsh terminals (iTerm2, Terminal.app)
- Bash completions must remain unaffected

**Out of scope:**

- Fish shell completions
- Warp's native AI-based command completion (a separate Warp feature)
- Completions in non-zsh shells on Warp (bash on Warp is a separate problem)
- STORY-037 placeholder hints (handled in Sprint 7 as a follow-on)

### User Flow

1. Developer installs worktree-helpers and sources `wt.sh` in their `.zshrc`
2. Developer opens Warp terminal — a new zsh session starts
3. Developer types `wt` and presses `<Tab>` → sees all flags and commands (same as `git`)
4. Developer types `wt -s` and presses `<Tab>` → sees list of existing worktree branch names
5. Developer types `wt -o` and presses `<Tab>` → sees list of local git branch names
6. Developer types `wt -r` and presses `<Tab>` → sees list of existing worktree branch names
7. Developer types `wt --from` and presses `<Tab>` → sees list of all git refs
8. Existing iTerm2/Terminal.app users see no change in behaviour

---

## Acceptance Criteria

- [ ] `wt <TAB>` shows all flags in Warp + zsh
- [ ] `wt -s <TAB>` completes existing worktree names in Warp + zsh
- [ ] `wt -o <TAB>` completes local branch names in Warp + zsh
- [ ] `wt -r <TAB>` completes existing worktree names in Warp + zsh
- [ ] `wt --from <TAB>` completes git refs in Warp + zsh
- [ ] All existing completion behaviour preserved in standard zsh (iTerm2, Terminal.app)
- [ ] Bash completions unaffected
- [ ] `shellcheck` passes on all modified files

---

## Technical Notes

### Investigation Areas

**1. How git completions register with Warp**

Git's zsh completion (`git-completion.zsh` or the distro-provided `_git`) works in Warp.
The key difference to investigate:

- Git's completion file uses a `#compdef git` shebang header and is placed in `fpath`
- Warp may scan `fpath` directly (bypassing `compdef`) to discover `#compdef` headers
- The current `_wt` file already has `#compdef wt` at line 1 — if Warp reads fpath, it
  should discover `_wt` automatically without needing `compdef _wt wt`

**2. Possible root cause: `autoload -Uz _wt` not completing before Warp initialises**

Warp may initialise its completion engine before `precmd_functions` runs (where our
deferred `compdef` lives from STORY-028). If Warp snapshots `fpath` at shell start, and
`autoload -Uz _wt` hasn't been called yet, `_wt` may not be present when Warp looks for it.

**3. Possible fix approaches (investigate in order)**

- **Approach A — Pure fpath, no runtime compdef:** Remove `compdef _wt wt` entirely.
  Rely solely on `fpath=("$_WT_DIR/completions" $fpath)` + `autoload -Uz _wt` + the
  `#compdef wt` header in the file. This is how many system completions work.

- **Approach B — compctl fallback:** Add `compctl -K _wt wt` as a fallback. `compctl` is
  the older zsh completion system and may be what Warp hooks into.

- **Approach C — Warp-specific detection:** Check `$TERM_PROGRAM` or `$WARP_HONOR_PS1`;
  if Warp is detected, use an alternative registration path.

- **Approach D — Both mechanisms (belt and braces):** Keep existing `compdef` path AND
  add `compctl -K _wt wt` so one of them fires regardless of the engine.

**4. Testing strategy**

Warp cannot be tested in CI (GUI terminal). The approach must be:

1. Test Approach A locally in Warp (manual)
2. Verify iTerm2/Terminal.app still works after the change (manual)
3. Run BATS suite (which tests bash completions + logic) to confirm no regressions

### Components

- **`wt.sh`**: Completion registration block (lines 114–140)
- **`completions/_wt`**: Zsh completion function (may not need changes if Approach A works)

### Relevant Environment Variables

| Variable | Set by | Meaning |
|----------|--------|---------|
| `TERM_PROGRAM` | Warp sets `"WarpTerminal"` | Detect Warp |
| `WARP_HONOR_PS1` | Warp | Another Warp indicator |
| `ZSH_VERSION` | zsh | Already used in `wt.sh` |

### Edge Cases

- User upgrades from v1.3.1 → new version: existing `.zshrc` already sources `wt.sh`;
  completion fix must be transparent (no manual steps required)
- Non-interactive zsh (scripts): completion registration must not error
- Multiple `source wt.sh` calls: registration must be idempotent (already handled by
  the deferred compdef pattern from STORY-028)

---

## Dependencies

**Prerequisite Stories:**

- STORY-014: Add shell completions (bash + zsh) — base implementation
- STORY-028: Fix zsh tab completions silently failing when sourced before compinit — context and
  the deferred `compdef` pattern this story builds on

**Blocked Stories:**

- STORY-037: Completions — show example usage hint when nothing to suggest (Sprint 7, depends on
  this story being stable first)

**External Dependencies:**

- Manual access to Warp terminal for verification (macOS only; Warp is macOS/Linux GUI app)
- No third-party library changes required

---

## Definition of Done

- [ ] Root cause of Warp incompatibility identified and documented in commit message
- [ ] Fix applied to `wt.sh` (and `completions/_wt` if needed)
- [ ] Manual verification: `wt <Tab>` works in Warp + zsh
- [ ] Manual verification: `wt -s <Tab>` completes worktree branches in Warp + zsh
- [ ] Manual verification: `wt -o <Tab>` completes git branches in Warp + zsh
- [ ] Manual verification: `wt --from <Tab>` completes git refs in Warp + zsh
- [ ] Manual verification: completions still work in iTerm2 + zsh
- [ ] Manual verification: completions still work in Terminal.app + zsh
- [ ] All existing BATS tests pass (no regressions)
- [ ] `shellcheck` passes on `wt.sh` and `completions/_wt`
- [ ] No errors or warnings printed when sourcing `wt.sh` in any terminal

---

## Story Points Breakdown

- **Investigation (Warp engine behaviour, git completion comparison):** 2 points
- **Fix implementation (wt.sh registration block, possibly completions/_wt):** 1.5 points
- **Manual verification across 3 terminals (Warp, iTerm2, Terminal.app):** 1 point
- **BATS regression testing + shellcheck:** 0.5 points
- **Total:** 5 points

**Rationale:** The 2 investigation points reflect genuine uncertainty about Warp's internals.
If Approach A (pure fpath) works, implementation is trivial. If Warp requires a different
mechanism, research time increases. The 5-point estimate accounts for this risk.

---

## Additional Notes

- The `#compdef wt` header is already present at line 1 of `completions/_wt` — this is a
  positive sign for Approach A (pure fpath discovery).
- Warp (as of 2026) has a "Warp AI" completion system that is separate from zsh completions.
  This story is only about the standard zsh `<Tab>` completion, not Warp AI suggestions.
- If neither Approach A nor B works, escalate to STORY-037 and document Warp as a known
  limitation until a workaround is found.
- Consider adding a note to the README / install docs if a manual step is required for Warp
  users (e.g., `compctl -K _wt wt` in their `.zshrc`).

---

## Progress Tracking

**Status History:**

- 2026-02-19: Story created — Warp incompatibility identified after v1.3.1 release

**Actual Effort:** TBD (will be filled during/after implementation)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
