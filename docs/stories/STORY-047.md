# STORY-047: Documentation audit — align README and per-command `--help` with current state

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 3
**Status:** Completed
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

- [x] `_help_new` — lists `--from`/`-b <ref>`, `-d`/`--dev`; examples match actual syntax
- [x] `_help_switch` — confirms fzf fallback when no arg; no stale references
- [x] `_help_open` — confirms fzf fallback, `origin/` prefix stripping, local + remote branches
- [x] `_help_remove` — lists `-f`/`--force`; protection note added: main/dev branches are always protected
- [x] `_help_list` — confirms dirty/clean indicator, lock status, root worktree display (note added)
- [x] `_help_clear` — lists ALL filter flags: `--merged`, `--pattern <glob>`, `--dry-run`,
      `--dev-only`, `--main-only`, `-f`/`--force`; clarifies that `<days>` is optional when
      `--merged` or `--pattern` is supplied; notes that main/dev branches are always protected
- [x] `_help_init` — confirms what files are created (config.json + hook templates)
- [x] `_help_update` — lists `--check` flag; confirms no install occurs with `--check`

### AC-2: `_cmd_help` (`wt -h`) matches actual command set

- [x] Full help output includes `--rename`, `--uninstall`, `--log`, `-L`/`-U` lock/unlock,
      `-v`/`--version`, `-h`/`wt <cmd> --help`
- [x] Flags block in `_cmd_help` includes all modifier flags:
      `--dev-only`, `--main-only`, `--merged`, `--pattern`, `--dry-run`, `--reflog`,
      `--since`, `--author`, `--check`
- [x] No flag or command present in `wt.sh` arg-parsing loop is missing from `_cmd_help`

### AC-3: README "Commands" section — complete and accurate

- [x] Every user-facing command has a row with: syntax, one-line description
- [x] At minimum these commands and variants are present:
      `wt -n`, `wt -n --from`, `wt -n -d`, `wt -s`, `wt -r`, `wt -o`, `wt -l`, `wt -c`,
      `wt -c --merged`, `wt -c --pattern`, `wt -c --dry-run`, `wt -L`, `wt -U`,
      `wt --init`, `wt --log`, `wt --rename`, `wt --update`, `wt --update --check`,
      `wt --uninstall`, `wt -v`, `wt -h`, `wt <cmd> --help`
- [x] Examples block in README illustrates key flags that users commonly miss
      (`--dry-run`, `--merged`, `--check`, `--from`, `-f`)
- [x] README "Commands" section is self-consistent with `_cmd_help` output (no contradictions)

### AC-4: README "Shell Completions" — Warp known limitation documented

- [x] A "Known Limitations" subsection exists under "Shell Completions"
- [x] Limitation is described: Warp intercepts Tab at the terminal UI level before
      zsh `compdef`/`compsys` dispatch; this is an officially documented Warp incompatibility
- [x] Workaround is documented: run `zsh` inside Warp (inner subprocess), then Tab completion works
- [x] Standard terminals (iTerm2, Terminal.app, Kitty, etc.) are confirmed unaffected

### AC-5: `docs/hooks.md` argument reference — consistent and complete

- [x] Arguments table (`$1–$4`) is present and matches the README inline hooks table exactly
      (same descriptions, same phrasing)
- [x] `$3` (base ref) table shows the correct value for each command scenario:
      `wt -n` → `GWT_MAIN_REF`, `wt -n --from <ref>` → user ref, `wt -n -d` → `GWT_DEV_REF`,
      `wt -o` (new) → branch name, `wt -o` (existing) → empty, `wt -s` → empty
- [x] No content removed from `docs/hooks.md`; additions only where gaps exist

### AC-6: Definition of Done updated for all future stories

- [x] The DoD template (or a clearly referenced canonical DoD section) includes:
      "If the story adds or changes a user-visible feature: update the relevant `_help_*`
      function in `lib/commands.sh`; add 1–3 lines to README"
- [x] The canonical DoD location is agreed and noted (e.g., a comment in the STORY template
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

- [x] All 8 `_help_*` functions audited and any gaps corrected
- [x] `_cmd_help` full-help output verified against actual `wt.sh` flag set
- [x] README "Commands" section covers all user-facing commands with descriptions
- [x] README "Shell Completions" has a "Known Limitations" subsection with Warp workaround
- [x] `docs/hooks.md` argument table (`$1–$4`) is consistent with README hooks table
- [x] `CLAUDE.md` updated with DoD requirement for user-visible changes
- [x] `shellcheck` passes on any modified `.sh` files (no new warnings)
- [x] No BATS tests broken (docs-only story; no functional code changes expected) — 317/317 pass
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
- 2026-02-22: Implementation complete by Developer

**Actual Effort:** 3 points (matched estimate)

**Files Changed:**

| File | Change type | Description |
|------|-------------|-------------|
| `lib/commands.sh` | Updated | `_help_remove`: added protection note (main/dev branches cannot be removed) |
| `lib/commands.sh` | Updated | `_help_list`: added note that root worktree is shown as `[root]` |
| `lib/commands.sh` | Updated | `_help_clear`: added protection note; added combined-filters example |
| `lib/commands.sh` | Updated | `_cmd_help`: added `--since`, `--author`, `--check` to Flags block |
| `README.md` | Updated | Commands table: added rows for `wt -c --merged`, `wt -c --pattern <glob>`, `wt -c <days> --dry-run`; improved descriptions for several rows |
| `README.md` | Updated | Examples: added `wt --update --check` example |
| `README.md` | Added | "Known Limitations" subsection under "Shell Completions" — Warp terminal incompatibility and workaround |
| `CLAUDE.md` | Pre-existing | DoD section already present (added before this story ran); confirmed correct |
| `docs/hooks.md` | No change needed | `$1–$4` argument table already consistent and complete; `$3` per-command table already covers all AC-5 scenarios |

**Tests Added:** None (documentation-only story)

**Test Results:** 317/317 BATS tests pass, 0 failures; `shellcheck lib/commands.sh` clean

**Decisions Made:**

- `docs/hooks.md` required no changes: the `$1–$4` argument table already matched README phrasing exactly, and the per-command `$3` table already covered all scenarios listed in AC-5. Adding duplicate content would reduce signal-to-noise — decision: no change.
- CLAUDE.md DoD section was already present (added as part of story setup by the Scrum Master). Confirmed correct; no change needed.
- `_cmd_help` Flags block was missing `--since`, `--author`, `--check` — all three added (AC-2).
- README Commands table was missing three `wt -c` variant rows required by AC-3 — rows added.
- `_help_remove` and `_help_list` gaps were smaller than anticipated; added concise one-line notes rather than restructuring.

---

**This story was created using BMAD Method v6 — Sprint 6 Retrospective action item**

---

## QA Review

**Date:** 2026-02-22
**Reviewer:** QA Engineer

### Files Reviewed

| File | Status | Notes |
|------|--------|-------|
| `lib/commands.sh` | Pass | Four targeted additions: `_cmd_help` Flags block (`--since`, `--author`, `--check`); `_help_remove` protection note; `_help_list` root worktree note; `_help_clear` combined-filter example and protection note. POSIX-compliant heredocs; no style issues. |
| `README.md` | Pass | Three new `wt -c` variant rows; improved descriptions on several existing rows; new `wt --update --check` example; "Known Limitations" subsection added under "Shell Completions". All markdown renders correctly. |
| `docs/hooks.md` | Pass (no change) | `$1–$4` argument table verified against README inline hooks table — phrasing identical. Per-command `$3` table covers all AC-5 scenarios. No changes needed; decision documented in Progress Tracking. |
| `CLAUDE.md` | Pass (no change) | DoD section ("Definition of Done (user-facing changes)") pre-existed and matches AC-6 requirement exactly. |

### Issues Found

None

### AC Verification

- [x] AC-1: All 8 `_help_*` functions audited against `wt.sh` router case-block and `_cmd_*` bodies.
  - `_help_new` — `--from`/`-b`, `-d`/`--dev` documented; examples match actual syntax (`lib/commands.sh:709–730`)
  - `_help_switch` — fzf fallback confirmed; no stale text (`lib/commands.sh:732–749`)
  - `_help_open` — fzf fallback, `origin/` prefix stripping, local/remote branches documented (`lib/commands.sh:751–769`)
  - `_help_remove` — `-f`/`--force` listed; protection note added: "Main and dev branches are always protected — they cannot be removed." (`lib/commands.sh:771–794`)
  - `_help_list` — dirty/clean indicator, lock status, root worktree note added: "The main (root) worktree is shown as [root] with its branch name." (`lib/commands.sh:796–812`)
  - `_help_clear` — all filter flags listed (`--merged`, `--pattern`, `--dry-run`, `--dev-only`, `--main-only`, `-f`/`--force`); `<days>` noted optional; protection note added (`lib/commands.sh:814–847`)
  - `_help_init` — config.json and hook templates creation confirmed (`lib/commands.sh:849–864`)
  - `_help_update` — `--check` flag documented; no-install confirmation present (`lib/commands.sh:866–884`)

- [x] AC-2: `_cmd_help` full-help output verified against `wt.sh` router (`wt.sh:41–83`).
  - Commands block includes `--rename`, `--uninstall`, `--log`, `-L`/`-U`, `-v`/`--version`, `-h`, `wt <cmd> --help` (shown as `--update --check` pattern)
  - Flags block now includes `--since`, `--author`, `--check` (added in this story, `lib/commands.sh:703–705`)
  - Every flag in `wt.sh` case-block has a matching entry in Flags or Commands block of `_cmd_help`

- [x] AC-3: README "Commands" table complete and accurate (`README.md:98–121`).
  - All required commands from AC-3 list present: `wt -n`, `wt -n --from`, `wt -n -d`, `wt -s`, `wt -r`, `wt -o`, `wt -l`, `wt -c`, `wt -c --merged`, `wt -c --pattern`, `wt -c <days> --dry-run`, `wt -L`, `wt -U`, `wt --init`, `wt --log`, `wt --rename`, `wt --update`, `wt --update --check`, `wt --uninstall`, `wt -v`, `wt -h`, `wt <cmd> --help`
  - Examples block illustrates `--dry-run`, `--merged`, `--check` (added), `--from`, `-f` (`README.md:123–187`)
  - No contradictions with `_cmd_help` output

- [x] AC-4: README "Shell Completions" has "Known Limitations" subsection (`README.md:292–307`).
  - Warp terminal Tab interception described with technically accurate explanation (compdef/compsys dispatch)
  - Workaround documented: run `zsh` inner subprocess
  - Standard terminals (iTerm2, Terminal.app, Kitty, Alacritty) confirmed unaffected

- [x] AC-5: `docs/hooks.md` argument table (`$1–$4`) consistent with README inline hooks table.
  - `docs/hooks.md:98–103` argument table phrasing matches `README.md:232–237` exactly
  - `$3` per-command table (`docs/hooks.md:109–116`) covers all six AC-5 scenarios: `wt -n` → `GWT_MAIN_REF`, `wt -n --from <ref>` → user ref, `wt -n -d` → `GWT_DEV_REF`, `wt -o` (new) → branch name, `wt -o` (existing) → empty, `wt -s` → empty
  - No content removed; no change needed

- [x] AC-6: DoD template updated for future stories.
  - `CLAUDE.md:51–58` — "Definition of Done (user-facing changes)" section present, correctly states requirement to update `_help_*` and README for every user-visible change
  - Section is referenced in Commit Guidelines context ensuring future Claude sessions pick it up

### Test Results

- Total: 317 / Passed: 317 / Failed: 0
- Test suite: `npm test` (`test/libs/bats-core/bin/bats test/`)
- No tests broken; story is documentation-only with no functional code changes

### Shellcheck

- Clean: yes — `shellcheck -x wt.sh lib/*.sh` produced no warnings or errors

---

## Manual Testing

**Date:** 2026-02-22
**Tester:** QA Engineer
**Environment:** macOS Darwin 24.6.0, zsh, bash (POSIX-compatible sourcing via `bash -c 'source ./wt.sh'`)

### Test Scenarios

| # | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|--------|-----------|
| 1 | `wt --help` includes `--since` in Flags block | Line `--since <date>   Limit log to commits after date (with --log)` present | Line present at position matching `--reflog` group | Pass |
| 2 | `wt --help` includes `--author` in Flags block | Line `--author <pattern>   Limit log to commits by author (with --log)` present | Line present | Pass |
| 3 | `wt --help` includes `--check` in Flags block | Line `--check   Check for update without installing (with --update)` present | Line present | Pass |
| 4 | `wt --help` Commands block includes `--update --check` | Entry `--update --check   Check for updates without installing` present | Present | Pass |
| 5 | `wt -r --help` shows protection note | Note "Main and dev branches are always protected — they cannot be removed." present | Note present under `Note:` heading | Pass |
| 6 | `wt -l --help` shows `[root]` note | Description line "The main (root) worktree is shown as [root] with its branch name." present | Present in second line of description | Pass |
| 7 | `wt -c --help` includes combined-filters example | Example line `wt -c --merged --pattern "fix-*" --dry-run` present | Present in Examples block | Pass |
| 8 | `wt -c --help` shows protection note | Note "Main and dev branches are always protected — they are never removed regardless of filters." present | Present under `Note:` heading | Pass |
| 9 | `wt -c --help` lists all filter flags | `--merged`, `--pattern`, `--dry-run`, `--dev-only`, `--main-only`, `-f`/`--force` all listed under Options | All six present | Pass |
| 10 | `wt -n --help` lists `--from`/`-b` and `-d`/`--dev` | Options block contains `--from, -b <ref>` and `-d, --dev` | Both present | Pass |
| 11 | `wt -s --help` mentions fzf fallback | Description mentions "opens fzf picker if no argument given" | Present in description | Pass |
| 12 | `wt -o --help` mentions fzf, `origin/` prefix, local/remote | Description mentions fzf; example shows `origin/release-2.0` | Both present | Pass |
| 13 | `wt --init --help` confirms config.json + hook templates | Description "Creates .worktrees/config.json and default hook scripts." | Present | Pass |
| 14 | `wt --update --help` lists `--check`; confirms no-install | Usage row `wt --update --check   Check for updates without installing`; Options `--check   Check for a new version without installing it` | Both present | Pass |
| 15 | `wt -h` and `wt --help` produce identical output | Diff empty | Diff empty | Pass |
| 16 | `wt --help` Commands block includes `--rename`, `--uninstall`, `--log`, `-L`/`-U`, `-v`/`--version`, `-h` | All listed | All listed in Commands block | Pass |
| 17 | README Commands table has `wt -c --merged` row | Row present | Present at line 108 | Pass |
| 18 | README Commands table has `wt -c --pattern <glob>` row | Row present | Present at line 109 | Pass |
| 19 | README Commands table has `wt -c <days> --dry-run` row | Row present | Present at line 110 | Pass |
| 20 | README Commands table has `wt --update --check` row | Row present | Present at line 117 | Pass |
| 21 | README Commands table has `wt <cmd> --help` row | Row present | Present at line 121 | Pass |
| 22 | README Examples block includes `wt --update --check` | Example present | Present at line 186 | Pass |
| 23 | README "Shell Completions" has "Known Limitations" subsection | `### Known Limitations` heading present | Present at line 292 | Pass |
| 24 | README "Known Limitations" describes Warp Tab interception | Text references `compdef`/`compsys` and officially documented Warp incompatibility | Text present at lines 294–297 | Pass |
| 25 | README "Known Limitations" documents `zsh` subprocess workaround | `zsh` code block with explanation present | Present at lines 299–307 | Pass |
| 26 | README "Known Limitations" confirms standard terminals unaffected | iTerm2, Terminal.app, Kitty, Alacritty listed | Listed at line 306 | Pass |
| 27 | CLAUDE.md has DoD section for user-visible changes | Section "Definition of Done (user-facing changes)" present with `_help_*` + README requirement | Present at line 51; correct content | Pass |
| 28 | Unknown flag produces error and exits non-zero | `wt --unknown-flag` outputs "Unknown: --unknown-flag" and exits 1 | Correct error message; exit code 1 | Pass |
| 29 | `shellcheck -x lib/commands.sh` clean | No warnings or errors | Exit 0; no output | Pass |
| 30 | Full BATS test suite: 317/317 pass, 0 failures | All tests green | `ok 317 _wt_open creates flat directory for slash branch name`; 0 `not ok` lines | Pass |

### Issues Found

None
