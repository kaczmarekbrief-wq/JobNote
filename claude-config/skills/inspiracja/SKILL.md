---
name: inspiracja
description: Manage a personal registry of inspiring people — add entries with name, description, social media accounts, and tags. Data stored in ~/.claude/inspiracja/PEOPLE.md (global, accessible from all projects). Use when user wants to add someone who inspires them, view their inspiration list, search for a person by name or tag, or update an existing entry. Triggers: "dodaj do inspiracji", "kto mnie inspiruje", "lista inspiracji", "pokaż inspiracje", "wyszukaj inspirację", "zaktualizuj wpis".
---

# Inspiracja

Personal registry of inspiring people. Data lives in `~/.claude/inspiracja/PEOPLE.md`.

## Entry format

```
## [Imię Nazwisko]
**Role:** programista / youtuber / researcher / entrepreneur / autor / podcaster / inżynier AI / (inne słowo opisujące specjalizację)
**Description:** Kim jest, czym się zajmuje (1-2 zdania)
**Tags:** #tag1 #tag2
**Social:**
- Twitter/X: @handle lub URL
- LinkedIn: URL
- YouTube: URL
- Instagram: @handle lub URL
**Added:** YYYY-MM-DD
```

## Workflows

### Dodaj osobę

1. Jeśli `~/.claude/inspiracja/PEOPLE.md` nie istnieje — utwórz plik z nagłówkiem `# Inspiracje`
2. Zbierz dane (pytaj po kolei jeśli brakuje):
   - Imię i nazwisko
   - Opis (kim jest, czym się zajmuje)
   - Social media (pomiń nieznane — nie wymuszaj)
   - Tagi (np. `#AI #design #biznes`)
3. Dołącz wpis na końcu pliku używając Write/Edit
4. Potwierdź: "Dodano [Imię] do listy inspiracji"

### Wyświetl listę

- Bez filtra → Read `~/.claude/inspiracja/PEOPLE.md` i wyświetl wszystkie wpisy
- Z filtrem → przeszukaj plik (grep) po imieniu, tagu lub słowie kluczowym i wyświetl trafienia

### Wyszukaj

Użyj grep na `~/.claude/inspiracja/PEOPLE.md` z podaną frazą (imię, tag, dziedzina). Wyświetl pasujące sekcje `##`.

### Zaktualizuj wpis

1. Znajdź sekcję `## [Imię]` w pliku
2. Pokaż aktualne wartości
3. Zapytaj które pole zmienić
4. Edytuj pole w miejscu używając Edit tool
5. Potwierdź zmianę
