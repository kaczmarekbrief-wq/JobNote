---
date: "2026-05-20 23:45"
promoted: false
---

# NotebookLM na Linuxie — setup rutyny

## Cel

Uruchomić rutynę AI Radio z głosem NotebookLM (dwóch hostów AI, jakość >> edge-tts Ryan)
działającą w chmurowej rutynie na claude.ai. Runtime: Linux VM (20.54.82.106) lub
Composio sandbox. Twardy warunek: **0 zł**.

## Referencje

- Plan główny: `~/.claude/plans/shimmering-swinging-catmull.md`
- Notatka research: `~/.claude/notes/2026-05-20-rutyna-notebook-update-research.md`
- Prompt rutyny edge-tts (fallback): `~/.claude/plans/ai-radio-routine.md`

## Co już działa na Linuxie

- ✅ `pip install notebooklm-py` (venv: `/home/Marcin/.venv`)
- ✅ `import notebooklm` działa
- ✅ `notebooklm.google.com` osiągalny z IP VM (HTTP 200)
- ✅ `NotebookLMClient`, `AuthTokens`, `from_storage` — API zweryfikowane

## Czego brakuje — jedyna blokada

**`storage_state.json`** — plik z sesją Google zalogowaną na NotebookLM.

`NotebookLMClient.from_storage(path=...)` czyta ten plik i wyciąga cookies +
csrf_token + session_id automatycznie. Bez niego auth nie przejdzie.

### Jak wygenerować storage_state.json (jednorazowo)

**Metoda: Playwright z nowym profilem Chrome przez VNC**

Problem poprzedniej próby: skrypt używał domyślnego profilu Chrome
(`/home/Marcin/.config/google-chrome`) → Chrome blokował remote debugging.

Poprawiony skrypt (`/tmp/extract_storage.py`):

```python
from playwright.sync_api import sync_playwright
import json

with sync_playwright() as p:
    # KLUCZOWE: nowy katalog profilu, nie domyślny
    ctx = p.chromium.launch_persistent_context(
        "/tmp/nlm-profile",          # <-- nie /home/Marcin/.config/google-chrome
        headless=False,
        args=["--no-sandbox"],
    )
    page = ctx.new_page()
    page.goto("https://notebooklm.google.com")
    input("Zaloguj się ręcznie w oknie VNC, potem naciśnij Enter...")
    storage = ctx.storage_state()
    json.dump(storage, open("/home/Marcin/shared/storage_state.json", "w"))
    print("Zapisano: /home/Marcin/shared/storage_state.json")
    ctx.close()
```

### Kroki do wykonania

1. Połącz się z VM przez VNC (`localhost:5901` przez tunel SSH lub bezpośrednio)
2. Uruchom skrypt: `source /home/Marcin/.venv/bin/activate && python3 /tmp/extract_storage.py`
3. W oknie Chrome (widocznym w VNC) zaloguj się na **dedykowane konto Google** → otwórz NotebookLM → zaakceptuj ToS
4. Wróć do terminala → Enter
5. Plik `storage_state.json` ląduje w `~/shared/` → git push → dostępny z Maca

## Użycie w rutynie (po uzyskaniu storage_state.json)

```python
from notebooklm import NotebookLMClient

client = NotebookLMClient.from_storage(
    path="/home/Marcin/shared/storage_state.json"
)
# lub w Composio sandbox:
# client = NotebookLMClient.from_storage(path="/mnt/files/storage_state.json")
```

## Flow rutyny AI Radio z NotebookLM

1. KROK 0: `pip install notebooklm-py edge-tts` + auth `from_storage`
2. KROK 1: pobierz dane (pogoda Dębica, HN Algolia AI, Robotics RSS, arXiv)
3. KROK 2: zbuduj `sources.md` z faktami
4. KROK 3: `client.notebooks.create()` → `client.sources.add_url()` → `client.artifacts.generate_audio()`
5. KROK 4: polling co ~60s aż status `READY` (3–10 min generacji)
6. KROK 5: `download_audio()` → `TELEGRAM_SEND_DOCUMENT` na chat 8018506547
7. KROK 6: `client.notebooks.delete()` — cleanup
8. KROK 7 (fallback): przy błędzie → edge-tts Ryan → Telegram (zawsze dostarczy audio)

## Ważne ryzyka

- **Cookies wygasają co ~2–4 tygodnie** → ręczny refresh storage_state.json
- **DBSC (Device Bound Session Credentials)** — Google może powiązać sesję z TPM urządzenia → wtedy przeniesienie do chmury przestanie działać całkowicie; fallback: edge-tts Ryan
- **Rate limit z IP chmury** — minimalne przy 1 gen/dzień; library ma jittered backoff
- **NotebookLM free tier**: ~3–5 Audio Overviews/dzień — 1 brief dziennie OK

## Status

- [ ] Wygenerować storage_state.json przez VNC
- [ ] Wkleić do sekretu rutyny na claude.ai
- [ ] PoC: YouTube URL → Audio Overview → Telegram
- [ ] Obserwacja 3–5 dni → decyzja czy zostać z NotebookLM czy edge-tts
