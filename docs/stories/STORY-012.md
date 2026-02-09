# STORY-012: Add `--version` flag

**Epic:** Developer Experience
**Priority:** Should Have
**Story Points:** 1
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-08
**Sprint:** 3

---

## User Story

As a user
I want to check which version of `wt` I have installed
So that I can troubleshoot issues or verify updates

---

## Description

### Background

Currently there is no way to check the installed version of `wt`. Users encountering bugs or wanting to verify they have the latest release have no quick way to confirm their version. This is also a prerequisite for STORY-013 (self-update mechanism), which needs to compare the installed version against the latest release.

### Scope

**In scope:**
- `-v` / `--version` flag in the `wt` router
- Single canonical version source (a `VERSION` file at repo root)
- Version output format: `wt version X.Y.Z`
- Install script embeds or copies the version correctly
- Version kept in sync with `package.json` via `commit-and-tag-version`

**Out of scope:**
- Version checking against remote (that's STORY-013)
- Build-time version stamping or templating
- Git describe / commit hash in version output

### User Flow

1. User runs `wt -v` or `wt --version`
2. Tool prints `wt version 1.0.1` (or current version)
3. User can compare this against the latest release on GitHub

---

## Acceptance Criteria

- [ ] `wt -v` prints version in format `wt version X.Y.Z`
- [ ] `wt --version` prints the same output as `wt -v`
- [ ] Version is sourced from a single canonical `VERSION` file at repo root
- [ ] Router in `wt.sh` handles `-v`/`--version` flags before other parsing
- [ ] Install script copies the `VERSION` file to the install directory
- [ ] `VERSION` file content stays in sync with `package.json` version (documented process or automated via `commit-and-tag-version` bump scripts)
- [ ] Help text (`wt -h`) updated to include `-v, --version`

---

## Technical Notes

### Components

- **`VERSION`** (new file): Plain text file containing only the version string (e.g., `1.0.1`)
- **`wt.sh`**: Add `-v`/`--version` case in the router's `while` loop, and a `_cmd_version` handler (or inline print)
- **`lib/commands.sh`**: Add `_cmd_version` function that reads `$_WT_DIR/VERSION` and prints it
- **`install.sh`**: Update file copy to include `VERSION` file
- **`package.json`**: Already has version — `commit-and-tag-version` bumps it, and a `.versionrc` config or npm script can sync `VERSION` file

### Implementation Approach

1. **Create `VERSION` file** at repo root with content `1.0.1`
2. **Add flag parsing** in `wt.sh` router:
   ```sh
   -v|--version) action="version"; shift ;;
   ```
3. **Add handler** in `wt.sh` case dispatch:
   ```sh
   version) _cmd_version ;;
   ```
4. **Add `_cmd_version`** in `lib/commands.sh`:
   ```sh
   _cmd_version() {
     local ver=""
     if [ -f "$_WT_DIR/VERSION" ]; then
       read -r ver < "$_WT_DIR/VERSION"
     fi
     echo "wt version ${ver:-unknown}"
   }
   ```
5. **Update help text** in `_cmd_help` to include `-v, --version`
6. **Update `install.sh`** to copy `VERSION` alongside `wt.sh` and `lib/`
7. **Sync with `package.json`**: Add a `postbump` script or `.versionrc` bumpFiles config to update `VERSION` file when running `npm run release`

### Files Changed

| File | Change |
|------|--------|
| `VERSION` | New file — `1.0.1` |
| `wt.sh` | Add `-v`/`--version` flag and `version` action |
| `lib/commands.sh` | Add `_cmd_version` function, update `_cmd_help` |
| `install.sh` | Copy `VERSION` file to install dir |
| `package.json` | Optional: add `postbump` script for sync |

### Edge Cases

- `VERSION` file missing in install dir (show `unknown` gracefully)
- Running from source (repo clone) vs installed copy — both should work since `$_WT_DIR` resolves correctly in both cases

---

## Dependencies

**Prerequisite Stories:**
- None (independent, foundational work)

**Blocked Stories:**
- STORY-013: Add self-update mechanism (`wt --update`) — needs `--version` to compare installed vs latest

**External Dependencies:**
- None

---

## Definition of Done

- [ ] `VERSION` file created at repo root with current version
- [ ] `wt -v` and `wt --version` print correct version
- [ ] `_cmd_version` reads from `$_WT_DIR/VERSION`
- [ ] `_cmd_help` includes `-v, --version` in output
- [ ] `install.sh` copies `VERSION` file
- [ ] Version sync mechanism documented or automated
- [ ] Code follows existing patterns (`_` prefix, POSIX-compatible)
- [ ] Works in both zsh and bash
- [ ] No regressions in existing functionality
- [ ] Manually tested: install, source, run `wt -v`

---

## Story Points Breakdown

- **Router + command handler:** 0.5 points
- **VERSION file + sync:** 0.5 points
- **Total:** 1 point

**Rationale:** Minimal code changes — one new file, a few lines added to router, commands, help, and install script. No complex logic or external dependencies. Straightforward 1-point story that can be completed in under 2 hours.

---

## Additional Notes

- The `commit-and-tag-version` tool (used for releases via `npm run release`) can be configured to bump the `VERSION` file automatically. Add to `.versionrc` or `package.json`:
  ```json
  {
    "bumpFiles": [
      { "filename": "package.json", "type": "json" },
      { "filename": "VERSION", "type": "plain-text" }
    ]
  }
  ```
- This keeps `package.json` and `VERSION` in sync on every release without manual steps.

---

## Progress Tracking

**Status History:**
- 2026-02-08: Created
- 2026-02-09: Completed

**Actual Effort:** 1 point (matched estimate)

**Implementation Notes:**
- `VERSION` file at repo root as single source of truth
- `_cmd_version` reads from `$_WT_DIR/VERSION`, falls back to "unknown"
- `.versionrc.json` bumpFiles keeps VERSION in sync with package.json on release
- 7 new BATS tests (106 total, 0 regressions)

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
