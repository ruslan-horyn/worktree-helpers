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

- Instrukcje do manualnego testowania były niedokładne (błędne ścieżki, etykiety wklejone jako komendy)
- Za szybkie twierdzenia bez weryfikacji (causa błędu `vared` w VS Code)
- Testowanie na lokalnym repo bez remote ujawniło kilka problemów UX wcześniej niewidocznych

---

## Action Items

- [ ] TODO

---

## Bugs odkryte podczas testowania STORY-034

### 1. `vared: ZLE not enabled` w VS Code terminal
**Objaw:** `_read_input` wywołuje `vared`, który failuje mimo że `[[ -o zle ]]` zwraca `true` i stdin jest tty.
**Przyczyna:** Nieznana — VS Code terminal (`$TERM_PROGRAM=vscode`) ma specyficzne zachowanie dla `vared` mimo aktywnego ZLE.
**Fix zastosowany:** `vared 2>/dev/null || { read -r fallback }` — catch błędu zamiast pre-check.
**Fix w commicie:** `fix: catch vared failure and fall back to read -r in zsh`

### 2. `wt -c -f` nie usuwa dirty worktree
**Objaw:** `git worktree remove` failuje z "Failed to remove" gdy worktree ma untracked files.
**Przyczyna:** `_cmd_clear` przekazywało `force` tylko do pominięcia pytania o potwierdzenie, ale **nie** do `git worktree remove --force`. `_cmd_remove` robił to poprawnie — różnica między komendami była niezamierzona.
**Fix zastosowany:** `local rm_force_flag=""; [ "$force" -eq 1 ] && rm_force_flag="--force"` + `git worktree remove $rm_force_flag "$wt_path"`.
**Fix w commicie:** `fix(clear): pass --force to git worktree remove when -f flag is set`

### 3. `wt --init` zapisuje pusty `mainBranch`
**Objaw:** Pressing Enter na "Main branch []:" zapisuje pusty string → `wt -n` failuje z `fatal: not a valid object name: 'origin/'`.
**Przyczyna:** Brak walidacji i auto-detekcji gałęzi domyślnej.
**Rozwiązanie:** Draft STORY-048 dodany do backlogu.

### 4. Hardcoded `devBranch: "origin/release-next"` / `devSuffix: "_RN"`
**Objaw:** Wygenerowany `config.json` zawiera wartości specyficzne dla jednego projektu.
**Przyczyna:** Prompty dla `devBranch`/`devSuffix` zgubione podczas refaktoryzacji STORY-001 (potwierdzone w historii git — commit `48fb469`).
**Rozwiązanie:** Draft STORY-049 dodany do backlogu.

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
