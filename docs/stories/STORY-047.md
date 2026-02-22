# STORY-047: Documentation audit — align README and per-command `--help` with current state

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 3
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** 7

---

## User Story

As a developer discovering `wt` for the first time (or returning after a gap)
I want the README and per-command `--help` to accurately reflect all current features, flags, and known limitations
So that I can understand the tool and use it correctly without reading source code

---

## Description

### Background

Sprint 6 retro identified that documentation is falling behind code. `wt` has grown across
six sprints — each story shipped working code, but README and `_help_*` functions were not
consistently updated. The gap has accumulated to the point where a dedicated audit is warranted.

**Specific gaps confirmed during retro:**

1. README "Commands" table exists but lacks descriptions and examples for all current flags
   (e.g., `--dry-run`, `--dev-only`, `--main-only`, `--check` for `wt --update`).
2. Per-command `--help` texts (the `_help_*` functions in `lib/commands.sh`) were created in
   STORY-036 and are broadly accurate, but need to be verified against the actual implemented
   flag set — particularly for `wt -c` which received several filter flags in later sprints.
3. STORY-030 (Warp completions) discovered a hard limitation: Warp intercepts Tab at the
   terminal UI level before zsh `compdef`/`compsys` dispatch is consulted. The workaround
   (run `zsh` as an inner subprocess inside Warp) is known but not documented in README.
4. `docs/hooks.md` is comprehensive, but argument descriptions (`$1–$4`) differ slightly in
   phrasing between the hooks doc and the inline README hooks table — they should be consistent.
5. The Definition of Done for stories has no formal requirement to update docs. This story
   introduces that requirement going forward.

**Key decision from retro:** Per-command `--help` (`_help_*` functions) is the "single source
of truth" for command-level documentation. README derives from it — shorter and scannable.
New features must always update the relevant `_help_*` first; README follows.

### Scope

**In scope:**

- Audit all 8 `_help_*` functions in `lib/commands.sh` against actual flag handling in `wt.sh`
  and `lib/commands.sh`; fix any gaps or stale text
- Verify `_cmd_help` (the `wt -h` full help output) matches the actual command set
- Update the README "Commands" section: one row per command with description + flags
- Update the README "Shell Completions" section: add a "Known Limitations" subsection for Warp
- Update `docs/hooks.md`: verify `$1–$4` argument descriptions are consistent with inline README
  hooks table and add any missing detail
- Update the story DoD template: add requirement to update `_help_*` and README for every
  user-visible change (applied to all future stories in Sprint 7+)

**Out of scope:**

- Adding new commands or flags (this is a docs-only story)
- Man-page or HTML documentation generation
- Rewriting `docs/hooks.md` from scratch (extend, not replace)
- Adding documentation for internal/utility functions (`_err`, `_info`, `_config_load`, etc.)
- Completing STORY-037 (completion placeholder hints) — that is a separate story

### User Flow

**New user discovering `wt`:**

1. User reads the README "Commands" section
2. Each command has a one-line description, the relevant flags, and an example
3. User understands immediately what `wt -c --merged --dry-run` does without looking at source

**User on Warp terminal:**

1. User installs `wt`, sources `wt.sh`, presses Tab — nothing happens
2. User checks README "Shell Completions" section, finds "Known Limitations" subsection
3. User reads: Warp intercepts Tab before zsh compdef is consulted — workaround: run `zsh`
   inside Warp
4. User runs inner `zsh`, Tab completion works

**Developer adding a new flag to `wt -c`:**

1. Developer implements the flag in `lib/commands.sh` + `wt.sh`
2. DoD checklist: "Did you update `_help_clear`?" — developer updates `_help_clear`
3. DoD checklist: "Did you add 1–3 lines to README?" — developer adds a row to the table
4. PR review confirms docs are updated before merge

---

## Acceptance Criteria

### AC-1: `_help_*` audit — all 8 functions verified

- [ ] `_help_new` — lists `--from`/`-b <ref>`, `-d`/`--dev`; examples match actual syntax
- [ ] `_help_switch` — confirms fzf fallback when no arg; no stale references
- [ ] `_help_open` — confirms fzf fallback, `origin/` prefix stripping, local + remote branches
- [ ] `_help_remove` — lists `-f`/`--force`; protection note: main/dev branches are always protected
- [ ] `_help_list` — confirms dirty/clean indicator, lock status, root worktree display
- [ ] `_help_clear` — lists ALL filter flags: `--merged`, `--pattern <glob>`, `--dry-run`,
      `--dev-only`, `--main-only`, `-f`/`--force`; clarifies that `<days>` is optional when
      `--merged` or `--pattern` is supplied; notes that main/dev branches are always protected
- [ ] `_help_init` — confirms what files are created (config.json + hook templates)
- [ ] `_help_update` — lists `--check` flag; confirms no install occurs with `--check`

### AC-2: `_cmd_help` (`wt -h`) matches actual command set

- [ ] Full help output includes `--rename`, `--uninstall`, `--log`, `-L`/`-U` lock/unlock,
      `-v`/`--version`, `-h`/`wt <cmd> --help`
- [ ] Flags block in `_cmd_help` includes all modifier flags:
      `--dev-only`, `--main-only`, `--merged`, `--pattern`, `--dry-run`, `--reflog`,
      `--since`, `--author`, `--check`
- [ ] No flag or command present in `wt.sh` arg-parsing loop is missing from `_cmd_help`

### AC-3: README "Commands" section — complete and accurate

- [ ] Every user-facing command has a row with: syntax, one-line description
- [ ] At minimum these commands and variants are present:
      `wt -n`, `wt -n --from`, `wt -n -d`, `wt -s`, `wt -r`, `wt -o`, `wt -l`, `wt -c`,
      `wt -c --merged`, `wt -c --pattern`, `wt -c --dry-run`, `wt -L`, `wt -U`,
      `wt --init`, `wt --log`, `wt --rename`, `wt --update`, `wt --update --check`,
      `wt --uninstall`, `wt -v`, `wt -h`, `wt <cmd> --help`
- [ ] Examples block in README illustrates key flags that users commonly miss
      (`--dry-run`, `--merged`, `--check`, `--from`, `-f`)
- [ ] README "Commands" section is self-consistent with `_cmd_help` output (no contradictions)

### AC-4: README "Shell Completions" — Warp known limitation documented

- [ ] A "Known Limitations" subsection exists under "Shell Completions"
- [ ] Limitation is described: Warp intercepts Tab at the terminal UI level before
      zsh `compdef`/`compsys` dispatch; this is an officially documented Warp incompatibility
- [ ] Workaround is documented: run `zsh` inside Warp (inner subprocess), then Tab completion works
- [ ] Standard terminals (iTerm2, Terminal.app, Kitty, etc.) are confirmed unaffected

### AC-5: `docs/hooks.md` argument reference — consistent and complete

- [ ] Arguments table (`$1–$4`) is present and matches the README inline hooks table exactly
      (same descriptions, same phrasing)
- [ ] `$3` (base ref) table shows the correct value for each command scenario:
      `wt -n` → `GWT_MAIN_REF`, `wt -n --from <ref>` → user ref, `wt -n -d` → `GWT_DEV_REF`,
      `wt -o` (new) → branch name, `wt -o` (existing) → empty, `wt -s` → empty
- [ ] No content removed from `docs/hooks.md`; additions only where gaps exist

### AC-6: Definition of Done updated for all future stories

- [ ] The DoD template (or a clearly referenced canonical DoD section) includes:
      "If the story adds or changes a user-visible feature: update the relevant `_help_*`
      function in `lib/commands.sh`; add 1–3 lines to README"
- [ ] The canonical DoD location is agreed and noted (e.g., a comment in the STORY template
      file or a section in `CLAUDE.md` that future Scrum Master prompts reference)

---

## Technical Notes

### Files to change

| File | Change |
|------|--------|
| `lib/commands.sh` | Update `_help_*` functions where gaps are found; update `_cmd_help` if flags are missing |
| `README.md` | Update "Commands" table; add Warp limitation to "Shell Completions" |
| `docs/hooks.md` | Verify and align `$1–$4` argument table with README inline table |
| `CLAUDE.md` | Add DoD requirement to "Code Conventions" section |

### Audit method for `_help_*` vs code

Compare the `_help_*` heredoc content against the `case` block in `wt()` router (`wt.sh`)
and the corresponding `_cmd_*` function body in `lib/commands.sh`. For each flag visible in
the router's `case` block, verify it appears in the relevant `_help_*` function.

Checklist to run during implementation:

```
wt.sh flags parsed:
  -f/--force    -> check _help_remove, _help_clear
  -d/--dev      -> check _help_new
  --dev-only    -> check _help_clear
  --main-only   -> check _help_clear
  --reflog      -> n/a (wt --log only; covered by _cmd_help)
  --since       -> n/a (wt --log only; covered by _cmd_help)
  --author      -> n/a (wt --log only; covered by _cmd_help)
  -b/--from     -> check _help_new
  --merged      -> check _help_clear
  --pattern     -> check _help_clear
  --dry-run     -> check _help_clear
  --check       -> check _help_update
```

### README "Known Limitations" subsection structure

Add the following subsection to the "Shell Completions" section in README, immediately after
the "Manual setup (if auto-registration fails)" subsection:

```markdown
### Known Limitations

**Warp terminal (primary shell):** Tab completion does not work when Warp is the primary
zsh shell. Warp intercepts the Tab key at the terminal UI level before zsh's `compdef`/
`compsys` dispatch is consulted — this is an officially documented Warp incompatibility
with `compdef` and `compinit`.

**Workaround:** Start an inner `zsh` subprocess inside Warp:

​```bash
zsh
​```

Once inside the inner shell, source `wt.sh` (or it will be sourced automatically via
`.zshrc`) and Tab completion will work normally. Standard terminals (iTerm2, Terminal.app,
Kitty, Alacritty) are unaffected.
```

### `_help_clear` — known gap (highest priority in this story)

`_help_clear` was written before STORY-029 (protected branches) was implemented. It currently
does not mention that main/dev branches are always skipped (never removed even if they match
the filter criteria). This is an important safety guarantee that users should know about.

The updated `_help_clear` should include a line like:

```
Note:
  Main and dev branches are always protected — they are never removed
  regardless of filters.
```

### DoD template location

Add the docs requirement to `CLAUDE.md` under "Code Conventions", as a new subsection
"Definition of Done (user-facing changes)". This makes it visible to every future Claude
Code session that reads project instructions. Example addition:

```markdown
## Definition of Done (user-facing changes)

Every story that adds or changes a user-visible feature must also:
- Update the relevant `_help_*` function in `lib/commands.sh`
- Add 1–3 lines to README (Commands section or appropriate subsection)
```

---

## Dependencies

- **STORY-036** (prerequisite, completed) — created the `_help_*` functions that this story audits;
  established the heredoc pattern and placeholder style that must be preserved

---

## Definition of Done

- [ ] All 8 `_help_*` functions audited and any gaps corrected
- [ ] `_cmd_help` full-help output verified against actual `wt.sh` flag set
- [ ] README "Commands" section covers all user-facing commands with descriptions
- [ ] README "Shell Completions" has a "Known Limitations" subsection with Warp workaround
- [ ] `docs/hooks.md` argument table (`$1–$4`) is consistent with README hooks table
- [ ] `CLAUDE.md` updated with DoD requirement for user-visible changes
- [ ] `shellcheck` passes on any modified `.sh` files (no new warnings)
- [ ] No BATS tests broken (docs-only story; no functional code changes expected)
- [ ] All changes committed with conventional commit format, lowercase subjects

---

## Story Points Breakdown

| Task | Points | Notes |
|------|--------|-------|
| Audit `_help_*` (8 functions) vs code + fix gaps | 1.0 | Mechanical cross-check; `_help_clear` likely has the most gaps |
| Update `_cmd_help` if missing flags | 0.5 | Small change; may be clean already |
| README "Commands" + examples update | 0.5 | Add rows, verify examples, not a rewrite |
| README "Shell Completions" — Warp limitation subsection | 0.5 | Short prose + code snippet |
| `docs/hooks.md` — verify and align argument tables | 0.25 | Mostly already correct; minor phrasing fix |
| `CLAUDE.md` — add DoD requirement | 0.25 | One short paragraph |
| **Total** | **3.0** | |

**Rationale:** The work is primarily reading and comparing existing content against existing code.
No new functionality is implemented. The ceiling on effort is the `_help_clear` gap (most flags
added after STORY-036) and the README prose update. All other tasks are small, targeted edits.

---

## Progress Tracking

**Status History:**

- 2026-02-21: Story created by Scrum Master — Sprint 6 retrospective action item
  (retro action: "Stworzyc STORY-047: Dokumentacja — audit aktualnych --help tekstow vs stan kodu")

**Actual Effort:** TBD

**Files Changed:** TBD

**Tests Added:** None expected (documentation-only story)

**Decisions Made:** TBD

---

**This story was created using BMAD Method v6 — Sprint 6 Retrospective action item**
