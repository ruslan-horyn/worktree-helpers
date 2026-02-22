# STORY-044: Improve default hooks (smart templates, restore command, arg docs)

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 5
**Status:** Not Started
**Assigned To:** Unassigned
**Created:** 2026-02-21
**Sprint:** Backlog
**Blocked By:** STORY-034, STORY-035

---

## User Story

As a developer setting up `wt` for the first time
I want the default hooks to contain useful, commented examples based on my project type
So that I can quickly configure my workflow without consulting external docs

---

## Description

### Background

Currently `wt --init` generates minimal hook files containing only `#!/usr/bin/env bash` and
`cd "$1" || exit 1`. Most developers do not know what to put next or what arguments are
available. This story delivers three complementary improvements to the hook authoring experience.

### Improvement 1: Smart Default Hook Templates

`wt --init` detects the project type by checking for the presence of well-known files in the
repo root and generates hook files that include commented, stack-relevant examples.

Detection order (first match wins):

| File | Stack |
|---|---|
| `package.json` | Node.js |
| `Makefile` | Make |
| `requirements.txt` / `pyproject.toml` | Python |
| `Gemfile` | Ruby |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `composer.json` | PHP |

If no known file is found, a generic template is generated that covers the most common
cross-stack use cases (`.env` copy/symlink, editor open, VS Code settings symlink).

Example generated `created.sh` for a Node.js project:

```bash
#!/usr/bin/env bash
# Hook args:
#   $1 = worktree_path    (absolute path to the new worktree)
#   $2 = branch           (branch name)
#   $3 = base_ref         (ref the branch was created from)
#   $4 = main_repo_root   (absolute path to the primary repo checkout)
cd "$1" || exit 1

# --- Uncomment what you need ---
# npm install                  # install dependencies
# cp "$4/.env" .env            # copy .env from main worktree
# ln -sf "$4/.env" .env        # or symlink .env instead
# ln -sf "$4/.vscode" .vscode  # symlink VS Code settings
# code .                       # open in VS Code
```

### Improvement 2: `wt --restore-hooks` Command

A new command that regenerates the hook files using current smart templates, useful when hooks
are accidentally deleted, corrupted, or need to be refreshed after a project type change.

```
wt --restore-hooks           # Restore hooks; prompts if hooks already exist
wt --restore-hooks -f        # Force overwrite without prompt
wt --restore-hooks --backup  # Back up existing hooks to <hook>.bak before restoring
```

The prompt mirrors the STORY-035 hook backup prompt style for consistency:

```
Hooks directory already exists: .worktrees/hooks/
  - created.sh
  - switched.sh

Would you like to:
  [1] Keep existing hooks (skip)
  [2] Back up existing hooks to .worktrees/hooks.bak/
  [3] Overwrite with smart defaults

Choice [1]:
```

### Improvement 3: Detailed Hook Argument Documentation

Every generated hook file (from both `wt --init` and `wt --restore-hooks`) includes a
commented argument reference block (`$1`–`$4`). The `wt --init` success message also echoes
a one-line summary of hook args. `docs/hooks.md` is updated with a full reference table,
created-vs-switched differences, and practical copy-paste examples.

### Scope

**In scope:**
- Smart template generation in `_cmd_init`
- New `_cmd_restore_hooks` function in `lib/commands.sh`
- New `--restore-hooks` flag wired in `wt.sh` router
- `_help_restore_hooks` function added to `lib/commands.sh`
- Arg reference comment block in all generated hook templates
- `wt --init` success output updated to mention hook args
- `docs/hooks.md` reference page created/updated

**Out of scope:**
- Detecting project type from file contents (only check file existence)
- Framework-specific templates beyond the 7 stacks listed
- Running `--restore-hooks` non-interactively without `-f` (i.e., no `--yes` alias in this story)

### User Flow: `wt --init` with smart templates

1. Developer runs `wt --init` in a Node.js repo containing `package.json`
2. `wt --init` prompts for project name, main branch, warning threshold (unchanged)
3. Tool detects `package.json` and selects the Node.js template
4. `created.sh` and `switched.sh` are written with Node.js-relevant commented examples
5. Success message includes: `Hook args: $1=path $2=branch $3=base_ref $4=main_root`

### User Flow: `wt --restore-hooks`

1. Developer accidentally deletes `.worktrees/hooks/created.sh`
2. Developer runs `wt --restore-hooks`
3. Tool detects project type and regenerates both hook files
4. If files already existed, prompt asks whether to keep / backup / overwrite
5. Developer can also run `wt --restore-hooks -f` to skip the prompt

---

## Acceptance Criteria

### Smart Templates

- [ ] `wt --init` detects project type from: `package.json`, `Makefile`, `requirements.txt`,
      `pyproject.toml`, `Gemfile`, `go.mod`, `Cargo.toml`, `composer.json`
- [ ] Generated `created.sh` contains commented examples relevant to the detected stack
- [ ] Generated `switched.sh` contains commented examples for switching context
      (e.g., `# nvm use` for Node.js, `# pyenv local` for Python)
- [ ] If no project type is detected, a generic template is generated with the most common
      cross-stack examples (`.env` copy/symlink, editor open, `.vscode` symlink)
- [ ] Templates include examples for: copy `.env`, symlink `.env`, symlink `.vscode`/`.idea`,
      run stack install command, open editor

### Hook Argument Documentation

- [ ] Every generated hook file (from `wt --init` and `wt --restore-hooks`) includes a
      `# Hook args:` comment block documenting `$1`–`$4` with plain-English descriptions
- [ ] `wt --init` success output includes a one-line summary:
      `Hook args: $1=path  $2=branch  $3=base_ref  $4=main_root`
- [ ] `docs/hooks.md` is updated (or created) with: arg reference table, created vs switched
      behavioural differences, and at least 3 practical copy-paste examples

### Restore Command

- [ ] `wt --restore-hooks` restores both `created.sh` and `switched.sh` using smart templates
- [ ] `wt --restore-hooks` detects project type the same way `wt --init` does
- [ ] If hooks already exist: three-option prompt (keep / backup / overwrite); default is keep
- [ ] `wt --restore-hooks -f` overwrites both hooks without prompting
- [ ] `wt --restore-hooks --backup` moves existing hooks to `.worktrees/hooks.bak/` before
      restoring; does not prompt
- [ ] Non-interactive mode (stdin not a terminal): defaults to keep (no destructive action)
- [ ] `wt --restore-hooks --help` prints concise usage via `_help_restore_hooks`

### General

- [ ] `shellcheck` passes on all modified files
- [ ] BATS tests cover: project type detection, template content assertions, restore prompt
      paths (keep / backup / overwrite), non-interactive default, `-f` flag
- [ ] README updated with 1–3 lines about `wt --restore-hooks`
- [ ] `_help_init` updated to mention smart templates

---

## Technical Notes

### Files to Modify

- `lib/commands.sh` — add `_detect_project_type`, `_hook_template_created`,
  `_hook_template_switched`, `_cmd_restore_hooks`, `_help_restore_hooks`; update `_cmd_init`
  and `_help_init`
- `wt.sh` — wire `--restore-hooks` flag in the router; add `-f` / `--backup` sub-flag parsing
- `docs/hooks.md` — reference page (create if missing)
- `README.md` — 1–3 lines in Commands section

### Project Type Detection

Check only file existence (not contents) for speed:

```sh
_detect_project_type() {
  local root="$1"
  [ -f "$root/package.json" ]     && { echo "node";   return; }
  [ -f "$root/Makefile" ]         && { echo "make";   return; }
  [ -f "$root/requirements.txt" ] && { echo "python"; return; }
  [ -f "$root/pyproject.toml" ]   && { echo "python"; return; }
  [ -f "$root/Gemfile" ]          && { echo "ruby";   return; }
  [ -f "$root/go.mod" ]           && { echo "go";     return; }
  [ -f "$root/Cargo.toml" ]       && { echo "rust";   return; }
  [ -f "$root/composer.json" ]    && { echo "php";    return; }
  echo "generic"
}
```

### Hook Template Storage

Store templates as shell functions (heredocs) inside `lib/commands.sh` rather than as
separate files — this keeps the library self-contained. Two functions per hook:
`_hook_template_created <type>` and `_hook_template_switched <type>`, each printing the
template to stdout.

### `_cmd_restore_hooks` Skeleton

```sh
_cmd_restore_hooks() {
  local force="$1" backup="$2"
  _repo_root >/dev/null || return 1
  local root; root=$(_main_repo_root)
  local hooks_dir="$root/.worktrees/hooks"
  local type; type=$(_detect_project_type "$root")

  # Detect existing hooks
  if [ -d "$hooks_dir" ] && [ "$(ls -A "$hooks_dir" 2>/dev/null)" ]; then
    if [ "$force" -eq 1 ]; then
      : # proceed to overwrite
    elif [ "$backup" -eq 1 ]; then
      mv "$hooks_dir" "${hooks_dir}.bak"
      mkdir -p "$hooks_dir"
    elif [ ! -t 0 ]; then
      _info "Non-interactive: keeping existing hooks"; return 0
    else
      # 3-option prompt (keep / backup / overwrite)
      ...
    fi
  fi

  mkdir -p "$hooks_dir"
  _hook_template_created  "$type" > "$hooks_dir/created.sh"
  _hook_template_switched "$type" > "$hooks_dir/switched.sh"
  chmod +x "$hooks_dir"/*.sh
  _info "Hooks restored ($type template)"
}
```

### Backup Mechanism

Reuse the same `mv "$hooks_dir" "${hooks_dir}.bak"` approach established in STORY-035's
`_cmd_init` hook backup logic to ensure consistent behaviour across both commands.

### Hook Args Reference (to embed in templates)

```
# Hook args:
#   $1 = worktree_path   — absolute path to the worktree directory
#   $2 = branch          — branch name checked out in this worktree
#   $3 = base_ref        — ref the branch was created from (empty for wt -s)
#   $4 = main_repo_root  — absolute path to the primary repository checkout
```

Note: `$3` (base_ref) is empty when the hook is called from `_cmd_switch` / `wt -s`.

### POSIX Compatibility

All new code must use POSIX-compatible shell syntax (no bash arrays, no `[[`, no process
substitution). The heredoc approach for template output is POSIX-safe.

---

## Dependencies

**Prerequisite Stories (must be complete before implementing STORY-044):**

- **STORY-034** — Verbose feedback to `wt -c` and `wt --init`: the `_cmd_init` step-by-step
  output established in that story is the base onto which the project-type detection message
  and hook arg summary line are added.
- **STORY-035** — `wt --init`: offer to copy/backup existing hooks: the backup mechanism and
  the 3-option prompt introduced there are reused directly by `--restore-hooks`.

**Stories blocked by STORY-044:**

- None

**External Dependencies:**

- None (no new runtime dependencies; detection uses only `[ -f ]` tests)

---

## Definition of Done

- [ ] `_detect_project_type` implemented and tested for all 8 project types + generic fallback
- [ ] `_hook_template_created` and `_hook_template_switched` produce stack-appropriate output
- [ ] `_cmd_init` uses smart templates instead of minimal stubs
- [ ] `_cmd_init` success message includes hook arg one-liner
- [ ] `_cmd_restore_hooks` implemented with keep / backup / overwrite / force paths
- [ ] `--restore-hooks` flag wired in `wt.sh` router with `-f` and `--backup` sub-flags
- [ ] `_help_restore_hooks` written and accessible via `wt --restore-hooks --help`
- [ ] `_help_init` updated to mention smart templates
- [ ] `docs/hooks.md` updated with arg table, created-vs-switched differences, examples
- [ ] README updated with 1–3 lines about `wt --restore-hooks`
- [ ] BATS tests: project detection, template content, restore prompt paths, non-interactive
      default, `-f` flag
- [ ] `shellcheck` passes on all modified files
- [ ] All new AC items checked off

---

## Story Points Breakdown

- **Project type detection + templates:** 2 points
- **`--restore-hooks` command + flag wiring:** 2 points
- **Arg docs (templates, init output, docs/hooks.md, README, --help):** 1 point
- **Total:** 5 points

**Rationale:** Smart template generation requires careful heredoc authoring for 8+ stacks
and tests asserting template content. The restore command needs full prompt handling plus
non-interactive and force paths. Arg documentation is lightweight but spans several files.

---

## Additional Notes

- Project type detection checks file existence only — content inspection is explicitly out of
  scope for performance reasons and to avoid parsing complex formats.
- Hook template files live in `lib/commands.sh` as shell functions, not as separate files,
  to keep distribution simple (single-file install still works).
- The `--restore-hooks --backup` flag creates `.worktrees/hooks.bak/`; if a `.bak` directory
  already exists it should be overwritten (simpler than versioned backups).

---

## Progress Tracking

**Status History:**
- 2026-02-21: Created (draft) — backlog
- 2026-02-22: Formalized by Scrum Master

**Actual Effort:** TBD

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
