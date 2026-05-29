---
date: "2026-05-21 00:30"
updated: "2026-05-29"
promoted: false
---

# Rutyny — pełny kontekst operacyjny

> Notatka dla Claude na Linuxie / Composio sandbox.
> Zawiera wszystko czego potrzebujesz do uruchomienia rutyn — bez dopytywania.

---

## Stan na 2026-05-29 — VM Daily Brief działa produkcyjnie

### Główna rutyna: VM `/opt/routines/daily-brief-unified/`

**Działa codziennie od 2026-05-21. Ostatni run: 2026-05-28 msg_id=1684.**

| Komponent | Plik | Status |
|---|---|---|
| Zbieranie danych | `collectors.py` | ✅ |
| Formatowanie | `formatters.py` | ✅ |
| Audio pipeline | `audio_pipeline.py` | ✅ |
| Punkt wejścia | `run_brief.py` | ✅ |

**Timer:** `systemd --user daily-brief-unified.timer` — codziennie 04:45 CEST (02:45 UTC)  
**Sprawdź:** `systemctl --user status daily-brief-unified.timer`  
**Logi:** `/opt/routines/logs/daily-brief-YYYYMMDDTHHMMSS.log` + `.json`

**Dane zbierane co rano:**
- ✅ Pogoda Dębica (open-meteo)
- ✅ Imieniny
- ✅ AI/LLM newsy (HN Algolia)
- ✅ Robotyka RSS
- ✅ Zadania (Azure Function `/api/tasks`)
- ⚠️ arXiv — timeout, graceful degradation

**Audio:**
- PRIMARY: NotebookLM PL (~271s generacji, ~4MB MP3, dwoje hostów AI)
- FALLBACK: edge-tts EN Ryan

**Dostawa:**
- Telegram: bezpośrednie Bot API (token: `TELEGRAM_BOT_TOKEN` w `~/shared/.env`)
- Bot: ClaudeOPPArchitectBot

**Auth NotebookLM:**
- `storage_state.json`: `/home/Marcin/shared/storage_state.json` (chmod 600)
- 49 cookies, expires 2027-06-24
- venv: `/home/Marcin/.venv` (notebooklm-py 0.4.1)

### Rutyna cloud (claude.ai) — wakeup only

Oddzielna rutyna na claude.ai wysyła tylko wakeup na Telegram i buzi sesję na VM.  
**NIE** generuje audio — to robi VM lokalnie.

### Zmiany 2026-05-29 — pełna integracja M365 + rozszerzone newsy

#### Nowe endpointy Azure Function (deployed)

| Endpoint | Co robi |
|---|---|
| `GET /api/calendar-get?day=YYYY-MM-DD` | Spotkania z kalendarza Outlook |
| `GET /api/emails?hours=24` | Emaile z Inbox (ostatnie N godzin) |
| `POST /api/calendar` | Tworzy blok (bez zmian) |
| `GET /api/tasks` | Zadania To-Do (bez zmian) |

Managed Identity `autoproces-brief-tasks` (object ID: `d7be2448-cc11-42ef-bcc0-44089029c691`):
- ✅ `Calendars.ReadWrite` — było
- ✅ `Mail.Read` — dodano 2026-05-29 przez Azure Cloud Shell

#### Nowe kolektory w `collectors.py`

- `get_calendar()` → Azure Function GET `/api/calendar-get` — spotkania dnia/jutro
- `get_emails()` → Azure Function GET `/api/emails?hours=24` — emaile z filtrem spamu

#### Bloki kalendarza w `run_brief.py` — `create_calendar_blocks()`

Krok 1.5 uruchamia się po zebraniu danych:
- **Blok "Zadania zaległe (N)"** → wolny slot 09:00–11:00 — jeśli overdue ≥ 1
- **Blok "Przygotowanie do: {spotkanie}"** → 30–60 min przed spotkaniem
  - Treść bloku: uczestnicy + powiązane emaile (match po email/nazwisku) + powiązane zadania

#### Rozszerzone newsy

| Sekcja | Przed | Po |
|---|---|---|
| AI news | 8 itemów, tylko tytuły | 12 itemów, excerpty 600 zn, okno 48h |
| Robotics | 5 itemów, 1 feed | 10 itemów, 4 feedy |
| format_pl | ~3200 zn (~3 min) | ~7900 zn (~9 min) |

Działające feedy robotyki:
- `roboticsandautomationnews.com/feed/` ✅
- `spectrum.ieee.org/rss/robotics/fulltext` ✅ (IEEE)
- `manufacturingtomorrow.com/rss/news.php` ✅
- `plasticstoday.com/rss.xml` ✅

#### Nierozwiązane

- 📤 **Email z kaczmarekbrief@gmail.com** — Composio API zwraca 410 Gone (API v1/v2 wycofane, v3 404). Do rozwiązania osobno — opcje: Gmail OAuth2 one-time setup, lub inny relay.
- ⏱ **arXiv** — timeout/429, graceful degradation, nie krytyczne.

### Inne rutyny cloud (claude.ai) — działają osobno

Nie ingeruj w: `Wiadomości`, `AI_PROGRESS`, `Sprawdzenie kalendarza` — oddzielne rutyny.

---

## Telegram

- **chat_id:** `8018506547`
- **Bot:** `@MarcinDailyBot` (połączony przez Composio)
- **Wysyłka audio:** `run_composio_tool("TELEGRAM_SEND_DOCUMENT", {"chat_id": 8018506547, "document": url, "caption": "..."})`
- **Fallback tekst:** `run_composio_tool("TELEGRAM_SEND_MESSAGE", {"chat_id": 8018506547, "text": "..."})`

## Lokalizacja

- **Miasto:** Dębica (Poland)
- **Strefa czasowa:** `Europe/Warsaw`
- **Współrzędne:** pobierasz z `https://geocoding-api.open-meteo.com/v1/search?name=D%C4%99bica&count=1`

## NotebookLM auth

- **storage_state.json:** `/home/Marcin/shared/storage_state.json`
- **Expires:** 2027-06-24 (rotujące SIDTS/SIDCC do 2027-05-20)
- **Smoke test (2026-05-20):** AUTH OK, `notebooks.list()` zwrócił 3 notebooki

```python
import asyncio
from notebooklm import NotebookLMClient

async def get_client():
    client = await NotebookLMClient.from_storage(
        path="/home/Marcin/shared/storage_state.json"
    )
    return client

# UWAGA: API jest async-first, wymaga 'async with':
# async with client:
#     notebooks = await client.notebooks.list()
```

---

## RUTYNA 1: AI Radio — edge-tts Ryan (sprawdzona, darmowa)

**Głos:** `en-GB-RyanNeural`, rate `+0%`  
**Środowisko:** COMPOSIO_REMOTE_WORKBENCH  
**Ceiling:** 12 min

```
ROLE: Codziennie zbuduj krótkie ANGIELSKIE audio dla Marcina: (a) krótka pogoda
Dębica z ostrzeżeniem, (b) Zakres 1: AI/LLM/agentic — „nasza działka", (c) Zakres 2:
robotyka przemysłowa/automatyzacja maszyn — istotne dla Autoproces. BEZ ogólnych
newsów. Dostarcz jako plik audio na Telegram. ZERO halucynacji — tylko fakty z
pobranych tytułów; nie dopowiadaj szczegółów spoza tytułu.

== KONTEKST ==
- Strefa Europe/Warsaw. Telegram chat_id 8018506547. VOICE="en-GB-RyanNeural"; RATE="+0%".
- Całość w COMPOSIO_REMOTE_WORKBENCH (urllib). Bash curl zablokowany. Ceiling 12 min.
- NOW=datetime.now(ZoneInfo("Europe/Warsaw")); EN_DATE=NOW.strftime("%A, %B %-d")
- now=int(time.time()); TS=now-36*3600  (okno ~ostatnie 36h)

== KROK 1: DANE ==

1.1 POGODA Dębica (open-meteo, bez klucza) — KRÓTKO:
  geo: https://geocoding-api.open-meteo.com/v1/search?name=D%C4%99bica&count=1&language=pl&format=json
  fc:  https://api.open-meteo.com/v1/forecast?latitude={la}&longitude={lo}
       &current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,
       precipitation_probability_max,wind_gusts_10m_max,weather_code&timezone=Europe%2FWarsaw
  temp_now, t_min, t_max, rain_prob, gust(km/h), opis z weather_code.
  severe = wc in 95..99 LUB rain_prob>=70 LUB gust>=60. (błąd → pomiń pogodę)

  (TS = now - 40*3600 — okno ~40h. Ceiling rutyny PODNIEŚ do ~18 min: więcej fetchy.)

1.2 ZAKRES 1 — AI/LLM/agentic (HN Algolia, darmowe, bez klucza):
  Dla q,minpts in [("LLM",25),("OpenAI",30),("Anthropic",20),("agent",60),
   ("Claude",25),("Gemini",25),("DeepSeek",20),("MCP",25),("model",90),
   ("inference",25),("AI safety",30)]:
    GET https://hn.algolia.com/api/v1/search_by_date?tags=story&query={urlenc q}
        &numericFilters=created_at_i%3E{TS},points%3E{minpts}&hitsPerPage=6
    zbierz hits: objectID,title,points,url (dedupe po objectID).
  FILTR TEMATYCZNY (KONIECZNY — HN łapie szum): zostaw tytuł tylko jeśli lower()
   zawiera któreś z: ai, llm, gpt, model, agent, openai, anthropic, claude, gemini,
   deepseek, mistral, llama, qwen, inference, mcp, rag, fine-tun, transformer,
   neural, prompt, reasoning, frontier, open-source model, tokens, context window.
  Sortuj po points malejąco → TOP 8 (puste → "Quiet day in A I.").
  DOCIĄGNIJ TREŚĆ: dla każdego z 8 (ThreadPoolExecutor, timeout 8s, UA Mozilla),
   pobierz url, zdejmij <script/style> i tagi, scal whitespace → excerpt[:900].
   ANTY-ŚMIECI: jeśli excerpt to nav/cookie/„JavaScript is not available"/redirect/
   menu (brak realnej treści) → użyj SAMEGO tytułu (1 zdanie). NIGDY nie czytaj
   boilerplate'u. Zero halucynacji — fakt tylko z tytułu lub czystej treści.

1.3 ZAKRES 2 — maszyny/Autoproces (Robotics & Automation News RSS):
  GET https://roboticsandautomationnews.com/feed/  (UA Mozilla/5.0); xml.etree <item>.
  BLOCKLIST (odrzuć tytuł jeśli lower() zawiera): coverage, insurance, contractor,
   casino, betting, loan, crypto price, "best ", "guide to", sponsored.
  Weź pierwsze 5 trafnych; dla każdego zapisz title + <description> (zdejmij HTML,
   ~500 zn) — to realne, wiarygodne streszczenie wydawcy.
  (puste/err → pomiń sekcję, nie zmyślaj)

1.4 RESEARCH — arXiv (darmowe, bez klucza; abstrakty = fakty):
  GET http://export.arxiv.org/api/query?search_query=cat:cs.MA+OR+cat:cs.CL+OR+cat:cs.AI
      &sortBy=submittedDate&sortOrder=descending&max_results=20
  Atom: title + summary. Zostaw tylko gdy (title+summary).lower() zawiera:
   agent, llm, language model, reasoning, multi-agent, tool, retrieval, planning,
   memory. Weź 2 → title + pierwsze ~280 zn streszczenia. (puste → pomiń)

== KROK 2: SKRYPT (ANGIELSKI, ton lektora; cel ~5 min, zakres 3–10 min; ~700–950 słów) ==
  "Good morning, Marcin. It's {EN_DATE}."
  [pogoda] " Quick weather: in Debica {opis}, {t_min} to {t_max} degrees..."
  [severe] dopisz: " Heads up — rough weather today."
  " Now your A I brief, our space first."
   dla KAŻDEGO z TOP-8: 2–3 zdania EN. Akronimy literuj (L L M, A I, M C P).
  [jeśli 1.3] " Now robotics and factory automation, relevant to Autoproces:"
  [jeśli 1.4] " Finally, fresh research:"
  " That's your A I and machines brief. Have a productive day."
  Bez markdown/emoji. ZERO halucynacji.

== KROK 3: TTS + WYSYŁKA ==
  path=f"/mnt/files/ai-radio-{NOW.date().isoformat()}.mp3"
  synth: edge_tts.Communicate(script, VOICE, rate=RATE).save(path)
  u,err=get_mount_file_url(path)
  run_composio_tool("TELEGRAM_SEND_DOCUMENT",
    {"chat_id":8018506547,"document":u,"caption":f"🎧 AI Radio — {EN_DATE}"})
  FALLBACK: run_composio_tool("TELEGRAM_SEND_MESSAGE",{"chat_id":8018506547,"text":"🎧 AI Radio (audio nie wyszło):\n"+script})

== KROK 0: BOOTSTRAP ==
  import subprocess,sys,asyncio,os,json,time,urllib.request,urllib.parse
  import xml.etree.ElementTree as ET, datetime as dt; from zoneinfo import ZoneInfo
  subprocess.run([sys.executable,"-m","pip","install","-q","edge-tts"],timeout=120); import edge_tts
  from concurrent.futures import ThreadPoolExecutor
```

---

## RUTYNA 2: AI Radio — NotebookLM (głosy AI, w budowie)

**Status:** storage_state.json gotowy → PoC do wykonania  
**Środowisko:** COMPOSIO_REMOTE_WORKBENCH lub lokalnie na Linux VM

```python
# KROK 0: bootstrap
import subprocess, sys, asyncio, json, time
subprocess.run([sys.executable,"-m","pip","install","-q","notebooklm-py","edge-tts"], timeout=120)
from notebooklm import NotebookLMClient
import datetime as dt; from zoneinfo import ZoneInfo

# KROK 1: auth
# W Composio sandbox: skopiuj /home/Marcin/shared/storage_state.json → /mnt/files/
# Na Linux VM: ścieżka bezpośrednia
STORAGE_PATH = "/home/Marcin/shared/storage_state.json"  # lub /mnt/files/storage_state.json

async def run():
    async with await NotebookLMClient.from_storage(path=STORAGE_PATH) as client:

        # KROK 2: dane (pogoda + HN + RSS — identyczne jak Rutyna 1, KROK 1)
        sources_md = "..."  # zbuduj ze zebranych faktów

        # KROK 3: trigger
        NOW = dt.datetime.now(ZoneInfo("Europe/Warsaw"))
        nb = await client.notebooks.create(title=f"AI Radio {NOW.date()}")
        await client.sources.add(nb.id, content=sources_md, title="brief.md")
        job = await client.artifacts.generate_audio(nb.id)

        # KROK 4: polling (max ~15 min)
        for _ in range(15):
            status = await client.artifacts.get_status(nb.id, job.id)
            if status == "READY":
                break
            await asyncio.sleep(60)

        # KROK 5: download + Telegram
        mp3 = await client.artifacts.download(nb.id, job.id)
        path = f"/mnt/files/ai-radio-nlm-{NOW.date()}.mp3"
        open(path, "wb").write(mp3)
        u, _ = get_mount_file_url(path)
        run_composio_tool("TELEGRAM_SEND_DOCUMENT",
            {"chat_id": 8018506547, "document": u,
             "caption": f"🎧 AI Radio (NotebookLM) — {NOW.strftime('%A, %B %-d')}"})

        # KROK 6: cleanup
        await client.notebooks.delete(nb.id)

asyncio.run(run())
```

**Fallback:** przy błędzie → Rutyna 1 (edge-tts Ryan)

---

## Checklist PoC NotebookLM

- [x] `notebooklm-py` zainstalowany
- [x] `storage_state.json` wygenerowany i przetestowany
- [ ] PoC end-to-end: YouTube URL → Audio Overview → Telegram
- [ ] Obserwacja 3–5 dni
