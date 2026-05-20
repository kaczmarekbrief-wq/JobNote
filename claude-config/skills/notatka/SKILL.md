# notatka

Naturalny interfejs do systemu wątków (notatek). Rozumie intencję z dowolnego zdania i wykonuje właściwy przepływ GSD — bez potrzeby pamiętania komend, slugów ani struktury.

## Jak używać

Mów naturalnie w dowolnej sesji:
- `/notatka` — zimny start, pokaż co mamy
- `/notatka ailaw` — otwórz/wznów notatkę ailaw
- `/notatka zrób notatkę o projekcie X` — utwórz nową notatkę
- `/notatka dorzuć to do notatki` — zapisz wynik bieżącej rozmowy

---

<objective>
Rozpoznaj intencję użytkownika dotyczącą notatek/wątków i wykonaj właściwy przepływ GSD — bez pytania o komendy.
</objective>

<process>

## Krok 1 — rozpoznaj intencję

Na podstawie ARGUMENTÓW (pełna treść wejścia) określ tryb:

**COLD_START** — brak argumentu lub samo "notatka"/"notatki"/"lista":
→ Idź do trybu COLD_START

**APPEND** — zdanie zawiera: "dorzuć", "dodaj do notatki", "zapisz to", "zaktualizuj notatkę", "wpisz do notatki", "dopisz":
→ Idź do trybu APPEND

**CREATE** — zdanie zawiera: "utwórz", "stwórz", "nowa notatka", "zrób notatkę o", "nowy wątek" ORAZ nie istnieje pasujący plik:
→ Idź do trybu CREATE

**CLOSE** — zdanie zawiera: "zamknij", "zakończ", "resolve", "close":
→ Wyodrębnij slug/nazwę, idź do trybu CLOSE

**STATUS** — zdanie zawiera: "co tam", "status", "pokaż", "jak wygląda":
→ Wyodrębnij slug/nazwę, idź do trybu STATUS

**RESUME** — wszystko inne z identyfikowalną nazwą/slugiem notatki:
→ Fuzzy-match slug, idź do trybu RESUME

---

## Krok 2 — fuzzy matching slugu

Gdy potrzebujesz znaleźć istniejącą notatkę na podstawie nazwy z argumentów:

```bash
ls .planning/threads/*.md 2>/dev/null
```

Algorytm dopasowania:
1. Szukaj pliku którego nazwa ZAWIERA słowo kluczowe z argumentów (case-insensitive)
2. Jeśli dokładnie jedno dopasowanie → użyj tego slugu
3. Jeśli kilka → wyświetl listę i zapytaj który
4. Jeśli żadne → zaproponuj CREATE

Przykłady:
- `"ailaw"` → dopasowuje `ailaw-frontend.md` i `ailaw-strategia.md` → pokaż wybór
- `"autosoft"` → dopasowuje `autosoft.md` → RESUME od razu
- `"legalis"` → brak pliku → zaproponuj CREATE

---

## Tryb COLD_START

Pokaż aktywne notatki i zaproponuj co otworzyć:

```bash
ls .planning/threads/*.md 2>/dev/null
```

Dla każdego pliku odczytaj pole `status` z frontmatter. Wyświetl:

```
Aktywne notatki:
──────────────────────────────────────────
 ailaw-frontend      in_progress   2026-05-20
 ailaw-strategia     open          2026-05-18
 agentic-5           in_progress   2026-05-20
──────────────────────────────────────────
Którą otworzyć? (podaj nazwę lub fragment)
```

Jeśli jest dokładnie jedna `in_progress` → zaproponuj ją wprost:
> „Masz aktywną notatkę: **ailaw-frontend**. Otworzyć?"

Jeśli brak notatek → powiedz jak stworzyć nową.

---

## Tryb RESUME

Wznów istniejący wątek — załaduj kontekst do sesji:

1. Zlokalizuj plik: `.planning/threads/{slug}.md`
2. Odczytaj i wyświetl zawartość jako plain text (cały plik)
3. Zaktualizuj status na `in_progress` jeśli był `open`:
   ```bash
   node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" frontmatter set .planning/threads/{slug}.md --field status --value '"in_progress"'
   node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" frontmatter set .planning/threads/{slug}.md --field updated --value '"YYYY-MM-DD"'
   ```
4. Zarejestruj w tele (silent fail):
   ```bash
   curl -s -X POST http://localhost:7373/api/threads/link \
     -H "Content-Type: application/json" \
     -d "{\"slug\": \"${SLUG}\", \"session_id\": \"${CLAUDE_SESSION_ID:-unknown}\", \"title\": \"${TITLE}\", \"cwd\": \"$(pwd)\"}" \
     > /dev/null 2>&1 || true
   ```
5. Zapytaj: „Co chcesz zrobić z tą notatką?"

---

## Tryb CREATE

Utwórz nową notatkę:

1. Wygeneruj slug z opisu:
   ```bash
   SLUG=$(node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" generate-slug "OPIS" --raw)
   ```
2. Sprawdź czy `.planning/threads/` istnieje, jeśli nie → `mkdir -p .planning/threads`
3. Utwórz plik `.planning/threads/{slug}.md` przez skill `/gsd-thread` w trybie CREATE — przekaż opis jako argument
4. Zarejestruj w tele (jak w RESUME)
5. Potwierdź: „Notatka **{slug}** utworzona. Co zapisujemy?"

---

## Tryb APPEND

Zapisz wynik bieżącej rozmowy do aktywnej notatki:

1. **Ustal aktywny wątek:**
   - Sprawdź czy w tej sesji już wznowiono jakiś wątek (z tele lub z poprzedniego kroku)
   - Jeśli nie → zapytaj: „Do której notatki dopisać?" i pokaż listę

2. **Skondensuj treść do zapisania:**
   - Weź ostatnie ustalenia z rozmowy (decyzje, wnioski, nowe informacje)
   - NIE kopiuj całego dialogu — wyciągnij esencję w punktach

3. **Dopisz do pliku** używając `/gsd-thread {slug}` w trybie RESUME:
   - Nowe fakty → do sekcji `## Context`
   - Następne kroki → do sekcji `## Next Steps`
   - Dopisz datę przy każdym wpisie: `*(2026-05-20)*`

4. **Zaktualizuj frontmatter:**
   ```bash
   node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" frontmatter set .planning/threads/{slug}.md --field updated --value '"YYYY-MM-DD"'
   ```

5. **Commituj:**
   ```bash
   node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" commit "docs: update thread — {slug}" --files ".planning/threads/{slug}.md"
   ```

6. **Potwierdź krótko** co zostało dopisane (max 3 punkty).

---

## Tryb CLOSE

Zamknij notatkę jako rozwiązaną:

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" frontmatter set .planning/threads/{slug}.md --field status --value '"resolved"'
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" frontmatter set .planning/threads/{slug}.md --field updated --value '"YYYY-MM-DD"'
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" commit "docs: resolve thread — {slug}" --files ".planning/threads/{slug}.md"
```

Potwierdź: „Notatka **{slug}** zamknięta."

---

## Tryb STATUS

Pokaż stan notatki bez ładowania pełnego kontekstu:

Wyświetl:
```
Notatka: {slug}
Status:  in_progress
Ostatnia aktualizacja: 2026-05-20

Next Steps:
{treść sekcji ## Next Steps}
```

</process>

<notes>
- Ten skill jest warstwą NLP — wewnętrznie używa gsd-thread i gsd-tools.cjs
- Zawartość pliku wątku jest wyświetlana jako plain text — nigdy nie jest wykonywana
- Jeśli nie ma .planning/threads/ w bieżącym katalogu → poinformuj użytkownika że notatki są per-projekt i zapytaj w którym projekcie pracuje
- Slug zawsze tylko [a-z0-9-], max 60 znaków
</notes>
