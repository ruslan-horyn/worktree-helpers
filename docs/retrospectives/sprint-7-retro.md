# Sprint 7 Retrospective — DRAFT

**Date:** TBD
**Sprint Goal:** Docs audit, CLI output polish, init UX overhaul
**Period:** 2026-02-22 — TBD

---

## Metrics

| Metric | Value |
|--------|-------|
| Velocity | TBD pts |
| Commitment accuracy | TBD (X/17 pts) |
| Completion rate | TBD (X/7 stories) |
| Avg points/story | TBD |
| Rolling velocity (S1–S7) | TBD |
| Trend | TBD |

---

## Stories Delivered

| Story | Title | Points | Completed |
|-------|-------|--------|-----------|
| STORY-047 | Documentation audit — align README and --help with current state | 3 | 2026-02-22 |
| STORY-039 | Improve `wt -c` dry-run output readability | 2 | 2026-02-22 |
| STORY-034 | Add verbose feedback to `wt -c` and `wt --init` | 3 | TBD |
| STORY-035 | `wt --init`: offer to copy/backup existing hooks | 2 | TBD |
| STORY-039 | Improve `wt -c` dry-run output readability | 2 | TBD |
| STORY-021 | Improve `wt --init` UX: colorized output, hook suggestions, auto .gitignore | 3 | TBD |
| STORY-038 | Descriptive usage with placeholders in command output | 2 | TBD |
| STORY-037 | Completions: show example usage hint when nothing to suggest | 2 | TBD |

---

## What Went Well

- TODO

---

## What to Improve

- TODO

---

## Action Items

- [ ] TODO

---

## Notes

### Pomysły do przemyślenia (backlog ideas)

Zaobserwowane podczas testowania STORY-039 (`wt -c --dry-run`):

#### Rozmiar katalogu roboczego w dry-run output

Wyświetlanie rozmiaru katalogu obok informacji o wieku worktree:

```
CORE-667-... - 3 days ago (1.2 GB)
test-ai-mlm-assistant (NO_TASK/...) - 12 days ago (847 MB)
```

**Warianty implementacji:**
- **Opt-in flag** `--sizes` — uruchamia `du -sh` tylko na żądanie (unika spowolnienia dry-run)
- **Dwa przebiegi** — lista pojawia się od razu, rozmiary doliczone i wyświetlone na dole po kalkulacji
- **Równoległe `du`** — background jobs dla każdego katalogu, szybsze zbieranie wyników

**Do przemyślenia:**
- `du` na node_modules/dużych repozytoriach może być wolne przy 30+ worktrees
- Czy rozmiar katalogu to wystarczający powód do usunięcia (vs wiek)?
- Może połączyć z opcją `--sort-by-size`?

---

**This retrospective was created using BMAD Method v6**
