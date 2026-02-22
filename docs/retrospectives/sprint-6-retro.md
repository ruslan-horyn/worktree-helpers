# Sprint 6 Retrospective

**Date:** 2026-02-21
**Sprint Goal:** Fix critical bugs from real-world usage and overhaul completions
**Period:** 2026-02-19 — 2026-02-21 *(actual; planned 2026-02-23 → 2026-03-08)*

---

## Metrics

| Metric | Value |
|--------|-------|
| Velocity | 17 pts |
| Commitment accuracy | 100% (17/17 pts) |
| Completion rate | 100% (6/6 stories) |
| Avg points/story | 2.83 |
| Rolling velocity (S1–S6) | 16.8 pts |
| Trend | +0.2 vs rolling avg — stabilny |

---

## Stories Delivered

| Story | Title | Points | Completed |
|-------|-------|--------|-----------|
| STORY-029 | Protect main/dev branches from `wt -c` deletion | 3 | 2026-02-21 |
| STORY-031 | Replace slashes with dashes in worktree directory names | 2 | 2026-02-19 |
| STORY-030 | Fix completions in Warp + zsh to work like git | 5 | 2026-02-21 |
| STORY-032 | Show only worktree name instead of full path everywhere | 2 | 2026-02-19 |
| STORY-033 | Prompt to re-source after `wt --update` | 2 | 2026-02-19 |
| STORY-036 | Per-command help (`wt <cmd> --help`) | 3 | 2026-02-20 |

---

## What Went Well

- **100% delivery** — wszystkie 6 stories ukończone, 17/17 pts, zero scope creep
- **Szybkie tempo** — sprint zaplanowany do 2026-03-08, ukończony 2026-02-21 (przed terminem)
- **Krytyczne bugi naprawione** — STORY-029 i STORY-031 eliminują realne problemy z real-world usage (ochrona main/dev branchy, slash→dash w nazwach katalogów)
- **STORY-030 dobrze zadiagnozowany** — znaleziono ograniczenie Warp primary shell (incompatible z `compdef`), udokumentowano workaround

---

## What to Improve

### 1. Warp completions — nierozwiązany problem primary shell

STORY-030 nie mogła w pełni rozwiązać problemu z Warp jako primary zsh shell —
`compdef` jest niekompatybilne. Workaround (uruchom inner zsh w Warp) jest nieintuicyjny
i nieudokumentowany w README.

### 2. Dokumentacja nie nadąża za rozwojem toola

Gromadzą się nam cechy bez odpowiedniego udokumentowania. Każde story kończy się
działającym kodem, ale README i per-command `--help` nie są aktualizowane.

**Konkretny problem:**

- README nie odzwierciedla wszystkich aktualnych flag i komend
- `wt -h` i per-command `--help` mogą być niezsynchronizowane po dodaniu nowych cech
- Brak rozszerzonej dokumentacji funkcjonalności poza `--help`

**Rozwiązanie wypracowane w retro:**
Każda story powinna kończyć się aktualizacją dokumentacji:

1. **README** — krótka wzmianka o nowej cesze (1-3 linijki)
2. **Per-command `--help`** — tekst w `_help_*` musi uwzględniać nowe flagi/opcje
3. **Rozszerzone docs** — `docs/usage/` lub inline w `--help` dla złożonych cech

Per-command `--help` staje się "single source of truth" — można go użyć jako bazy
do README i docs. Nowe cechy powinny zawsze aktualizować odpowiedni `_help_*`.

### 3. Daty sprintów nie zgadzają się z rzeczywistością

Sprint 6 był zaplanowany na 2026-02-23 → 2026-03-08, ale faktycznie trwał 2-3 dni
(2026-02-19 → 2026-02-21). Daty w YAML mijały się z rzeczywistością przez cały sprint.

---

## Action Items

- [ ] Zaktualizować README o ograniczenie Warp completions + workaround (inner zsh) → **STORY-047 AC-4**
- [x] Dodać do **Definition of Done** każdego story: aktualizacja README + per-command `--help` → dodane do `CLAUDE.md` (2026-02-21)
- [x] Stworzyć STORY-047: Dokumentacja — audit aktualnych `--help` tekstów vs stan kodu, wyrównanie README → `docs/stories/STORY-047.md` (2026-02-21)
- [x] Ustalać realistyczne daty sprintów (start = dziś, nie data planowania) → Sprint 6 daty poprawione w `sprint-status.yaml`

---

## Notes

- Sprint 6 był krótkim sprintem intensywnym — 6 stories w 2-3 dni robocze (vs planowane 2 tygodnie)
- Warto rozważyć krótsze, częstsze sprinty zamiast 2-tygodniowych dla single-developer
- STORY-039 (notes były gotowe) mogła wejść do Sprint 6, ale nie była sformalizowana na czas

---

**This retrospective was created using BMAD Method v6**
