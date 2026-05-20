---
name: ms-todo-add
description: "Dodaj zadanie do Microsoft To Do (konkretna lista). Wywołaj gdy użytkownik mówi: dodaj zadanie, wrzuć do todo, zapisz w To Do, utwórz task w MS To Do, dodaj reminder. Przyjmuje tytuł (wymagany), listę (opcjonalnie, domyślnie Zadania), termin (opcjonalnie, YYYY-MM-DD) i notatkę (opcjonalnie)."
argument-hint: "<tytuł> [--list <nazwa_listy>] [--due YYYY-MM-DD] [--note <tekst>]"
user-invocable: true
allowed-tools:
  - Bash
---

## Mechanizm

Azure Function `POST /api/tasks/create` na `autoproces-brief-tasks` (Managed Identity, Tasks.ReadWrite.All).
Brak Composio — bezpośredni Graph API przez gotowy endpoint.

**Endpoint:**
```
POST https://autoproces-brief-tasks-c3cqdge0ebczggef.northeurope-01.azurewebsites.net/api/tasks/create?code=<AZURE_FUNCTION_KEY>
Content-Type: application/json

{
  "title": "...",        // wymagany
  "listName": "...",     // opcjonalny, default "Zadania"
  "due": "YYYY-MM-DD",  // opcjonalny
  "note": "..."          // opcjonalny
}
```

**Dostępne listy (stan na 2026-05-19):**
Zadania, AI_REMOTE, AILOW, Autosoft, Claude, JOBNOTE, Kidsapp, Lista bieżąca, proflow, Flagged Emails

## Proces

1. **Parsuj argumenty** z `$ARGUMENTS` — wyodrębnij tytuł, --list, --due, --note. Jeśli brak flagi --list, użyj "Zadania".

2. **Wywołaj endpoint** jednym `Bash` wywołaniem:

```bash
curl -s -X POST \
  "https://autoproces-brief-tasks-c3cqdge0ebczggef.northeurope-01.azurewebsites.net/api/tasks/create?code=<AZURE_FUNCTION_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "<tytuł>",
    "listName": "<lista>",
    "due": "<YYYY-MM-DD lub pomiń pole>",
    "note": "<tekst lub pomiń pole>"
  }'
```

3. **Interpretuj odpowiedź:**

   - `ok: true` → potwierdź: `Dodano: "<title>" → lista "<listName>" [due: <due> jeśli podano]`
   - `ok: false, error: "List \"X\" not found"` → wypisz `availableLists` i zapytaj użytkownika którą wybrać, po czym powtórz wywołanie z właściwą listą
   - `ok: false` inne → podaj błąd i `hint` z odpowiedzi

## Reguły

- **Jeden Bash call** do tworzenia zadania — nie rozbijaj na wiele wywołań.
- Jeśli lista podana przez użytkownika nie istnieje → pokaż dostępne listy, nie zgaduj.
- Nie pytaj o potwierdzenie przed wysłaniem — działaj od razu.
- Nie modyfikuj JSON payloadu dynamicznie przez sed/awk — buduj go bezpośrednio w -d parametrze lub przez python3 -c json.dumps() jeśli tytuł zawiera cudzysłowy.

## Obsługa cudzysłowów w tytule

Jeśli tytuł może zawierać cudzysłowy lub znaki specjalne, użyj python3 do budowania JSON:

```bash
python3 -c "
import json, urllib.request, urllib.error
payload = json.dumps({
    'title': '<tytuł>',
    'listName': '<lista>',
    'due': '<YYYY-MM-DD>',   # pomiń klucz jeśli brak
    'note': '<nota>'          # pomiń klucz jeśli brak
}).encode()
req = urllib.request.Request(
    'https://autoproces-brief-tasks-c3cqdge0ebczggef.northeurope-01.azurewebsites.net/api/tasks/create?code=<AZURE_FUNCTION_KEY>',
    data=payload,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
with urllib.request.urlopen(req) as r:
    print(r.read().decode())
"
```
