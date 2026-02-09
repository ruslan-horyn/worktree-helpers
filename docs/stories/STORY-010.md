# STORY-010: Add CI/CD pipeline (shellcheck + tests)

**Epic:** Quality Infrastructure
**Priority:** Must Have
**Story Points:** 3
**Status:** Completed
**Assigned To:** Unassigned
**Created:** 2026-02-08
**Sprint:** 3

---

## User Story

As a developer
I want PRs automatically linted and tested
So that code quality is enforced before merging

---

## Description

### Background

The worktree-helpers project currently has no automated quality checks. All linting and testing is manual, which means regressions and shellcheck warnings can slip into the codebase unnoticed. With STORY-009 delivering a BATS test suite, we need a CI pipeline to run those tests and shellcheck automatically on every push and pull request.

### Scope

**In scope:**
- GitHub Actions workflow for CI (push + PR to main)
- Shellcheck linting of all `.sh` files
- BATS test suite execution
- Fix any existing shellcheck warnings/errors
- `.shellcheckrc` configuration if needed
- CI status badge in README
- Tests run on ubuntu-latest with bash

**Out of scope:**
- Matrix testing across multiple OS versions (future enhancement)
- Code coverage reporting (future enhancement)
- Automated release pipeline changes (existing `release.yml` stays as-is)
- macOS CI runners (cost consideration)

### User Flow

1. Developer pushes code or opens a PR targeting `main`
2. GitHub Actions CI workflow triggers automatically
3. Shellcheck runs against `wt.sh`, `lib/*.sh`, and `install.sh`
4. BATS test suite runs
5. PR shows green/red status check
6. Developer sees inline annotations for any shellcheck or test failures
7. PR cannot merge until CI passes (enforced via branch protection — optional, manual setup)

---

## Acceptance Criteria

- [ ] GitHub Actions workflow file exists at `.github/workflows/ci.yml`
- [ ] Workflow triggers on push to `main` and on pull requests targeting `main`
- [ ] Shellcheck runs against all `.sh` files: `wt.sh`, `lib/utils.sh`, `lib/config.sh`, `lib/worktree.sh`, `lib/commands.sh`, `install.sh`
- [ ] BATS test suite runs as part of CI (requires STORY-009 test infrastructure)
- [ ] All existing shellcheck warnings/errors in the codebase are fixed
- [ ] `.shellcheckrc` is created if project-wide shellcheck directives are needed
- [ ] CI status badge is added to `README.md` (both shellcheck and tests)
- [ ] Tests run on `ubuntu-latest` with bash
- [ ] CI completes in under 2 minutes for a typical run
- [ ] Workflow uses pinned action versions (e.g., `@v4` not `@latest`)

---

## Technical Notes

### Workflow Structure

Create `.github/workflows/ci.yml` with two jobs:

**Job 1: Shellcheck**
- Runs `shellcheck` against all `.sh` files
- Uses `koalaman/shellcheck-action` or installs shellcheck directly
- Fail on any error (warnings can be configured via `.shellcheckrc`)

**Job 2: Tests**
- Installs BATS dependencies (`bats-core`, `bats-support`, `bats-assert`)
- Installs runtime dependencies (`jq`, `git`)
- Runs `bats test/` (or wherever STORY-009 places tests)
- Reports test results

### Shell Files to Lint

```
wt.sh
lib/utils.sh
lib/config.sh
lib/worktree.sh
lib/commands.sh
install.sh
```

### Shellcheck Configuration

A `.shellcheckrc` may be needed for project-wide directives:
- `shell=bash` — default shell dialect
- Potential exclusions for intentional patterns (e.g., `SC2034` for unused variables that are used by other sourced files, `SC1091` for non-resolvable source paths)

### Known Shellcheck Considerations

Based on codebase review, areas likely to need attention:
- `wt.sh`: `_wt_get_script_dir()` uses `ZSH_VERSION` and `BASH_SOURCE` — may need shellcheck directives for cross-shell compatibility
- `lib/utils.sh`: Uses `$*` in `_err()` — shellcheck may suggest `"$@"`
- `lib/commands.sh`: `local` declarations inside loops (shellcheck may flag)
- `lib/worktree.sh`: Uses `\` line continuations with pipes

### Integration with Existing Release Workflow

The existing `.github/workflows/release.yml` triggers on tags (`v*`) for GitHub releases. The new CI workflow is independent — it triggers on push/PR to `main`. No changes to the release workflow are needed.

### CI Badge

Add to the top of `README.md`:
```markdown
[![CI](https://github.com/<owner>/worktree-helpers/actions/workflows/ci.yml/badge.svg)](https://github.com/<owner>/worktree-helpers/actions/workflows/ci.yml)
```

### Edge Cases
- BATS not yet available (STORY-009 not merged): CI workflow should still work for shellcheck-only; BATS job can be conditional or added after STORY-009 lands
- Shellcheck version differences between local and CI: pin shellcheck version in workflow
- Shell files with `#!/usr/bin/env bash` vs no shebang (sourced files): configure shellcheck appropriately

---

## Dependencies

**Prerequisite Stories:**
- STORY-009: Add test suite with BATS (tests must exist to run in CI)

**Blocked Stories:**
- None

**External Dependencies:**
- GitHub Actions (free for public repos)
- `koalaman/shellcheck-action` or shellcheck binary
- BATS GitHub Actions or manual BATS installation in CI
- `jq` package available in ubuntu-latest

---

## Definition of Done

- [ ] `.github/workflows/ci.yml` created and committed
- [ ] Shellcheck job passes on all `.sh` files
- [ ] BATS test job passes (all tests green)
- [ ] All pre-existing shellcheck errors/warnings resolved
- [ ] `.shellcheckrc` created (if needed)
- [ ] CI badge added to `README.md`
- [ ] CI runs successfully on a test PR
- [ ] Workflow uses pinned action versions
- [ ] No regressions in existing functionality
- [ ] Works in both bash and zsh (shell files remain POSIX-compatible)

---

## Story Points Breakdown

- **Shellcheck setup + fixes:** 1 point
- **BATS CI integration:** 1 point
- **Workflow configuration + badge:** 1 point
- **Total:** 3 points

**Rationale:** The individual pieces (shellcheck action, BATS action, badge) are straightforward. The main effort is fixing any shellcheck findings in existing code. 3 points reflects a moderate task completable in 4-8 hours.

---

## Additional Notes

- This story should be implemented after STORY-009 (tests) is complete, as the BATS CI job depends on tests existing
- If STORY-009 is still in progress, the shellcheck portion can be done first as an incremental PR
- Consider enabling GitHub branch protection rules to require CI to pass before merging (manual step, not part of this story)
- The existing `release.yml` workflow remains unchanged

---

## Progress Tracking

**Status History:**
- 2026-02-08: Created
- 2026-02-09: Completed

**Actual Effort:** 3 points (matched estimate)

**Implementation Notes:**
- Created `.shellcheckrc` with project-wide directives (SC2148, SC2034)
- Fixed 4 SC2164 (cd without exit), 1 SC2155 (declare/assign), 1 SC2086 (quoting), 2 SC2016 (intentional single quotes), 1 SC2129 (grouped redirects)
- Added inline directives for SC2296 (zsh syntax) and SC1083 (literal braces in @{u})
- CI workflow with two parallel jobs: shellcheck + BATS tests
- BATS libraries loaded via git submodules (checkout with `submodules: true`)
- All 108 tests pass, shellcheck clean at all severity levels

---

**This story was created using BMAD Method v6 - Phase 4 (Implementation Planning)**
