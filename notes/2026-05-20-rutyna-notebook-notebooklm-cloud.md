---
date: "2026-05-20 12:00"
promoted: false
---

# Rutyna Notebook — NotebookLM w cloud routine (PoC)

## Cel
Zastąpić syntetyczny edge-tts Ryan głosami NotebookLM (dwóch AI hostów, konwersacyjnie — wyraźnie lepsza jakość). Twardy warunek: **0 zł**. Generowanie ma żyć **w chmurowej rutynie** na claude.ai/code/routines (NIE lokalnie na Macu) — runtime w chmurze. Jednorazowy setup auth na Macu jest OK; sam runtime nie wraca tam.

## Stan zatwierdzony
- Plan: `~/.claude/plans/shimmering-swinging-catmull.md` (Plan: AI Radio z głosem NotebookLM — w CHMUROWEJ rutynie, darmowo).
- Decyzja: scope DOWN do prostego PoC zanim budujemy pełną rutynę. Najpierw potwierdzić, że library notebooklm-py żyje w sandboxie cloud-routine z prawdziwym auth, i że da się przepuścić jedno proste źródło (np. YouTube URL) przez Audio Overview → Telegram.

## Research (sourced, maj 2026)
- Oficjalne Google API (Podcast API / NotebookLM Enterprise) istnieje, ale **gated „contact sales" / enterprise → nie darmowe → out**.
- `notebooklm-py` (PyPI v0.4.1, autor: teng-lin) — nieoficjalna, używa **niezadokumentowanych endpointów Google przez raw HTTP + session cookies**. **Nie wymaga headless browser / Playwrighta** → wykonalne w sandboxie rutyny.
- NotebookLM free tier: ~3–5 Audio Overviews/dzień (rolling 24h). 1 brief dziennie OK z zapasem.
- GitHub repo: https://github.com/teng-lin/notebooklm-py · PyPI: https://pypi.org/project/notebooklm-py/

## Feasibility probe (wykonane w COMPOSIO_REMOTE_WORKBENCH, sandbox 3hjw)
- ✅ `pip install notebooklm-py` → rc=0
- ✅ `import notebooklm` (UWAGA: moduł zwie się `notebooklm`, NIE `notebooklm_py` — klasyczna pułapka nazewnictwa PyPI vs import)
- ✅ `notebooklm.google.com` osiągalny z sandbox-IP (HTTP 200)
- ✅ `NotebookLMClient` zdefiniowany, bogate API: Artifact, AudioFormat, AudioLength, AuthTokens, sources/artifacts/notebooks namespacy

## Auth — uczciwy precyzyjny wymóg
`NotebookLMClient(auth: AuthTokens, ...)`. `AuthTokens` wymaga:
- `cookies: dict[tuple[name, domain], str]` (3+ cookies Google)
- `csrf_token` (SNlM0e) — wydłubany ze strony NotebookLM po zalogowaniu
- `session_id` (FdrFJe) — to samo

**Same cookies NIE wystarczą.** Library ma helper `NotebookLMClient.from_storage(path=...)` który czyta `storage_state.json` (format Playwright/httpx) i sam wyciąga csrf/session_id.

## 2 ścieżki auth — DO DECYZJI USERA
1. **`from_storage` + plik storage_state.json** (zalecane, native dla library): jednorazowo lokalnie na Macu user generuje plik (CLI `notebooklm auth login` lub Playwright codegen), daje treść JSON, ja wklejam jako sekret w prompcie rutyny, w sandboxie zapisuję do `/mnt/files/storage_state.json` i wołam `NotebookLMClient.from_storage(path=...)`.
2. **Tylko 3 cookies + ja w sandboxie wyciągam csrf/session_id z HTML**: user kopiuje 3 cookies z Chrome DevTools, ja w sandboxie GET na notebooklm.google.com z tymi cookies, regex łapie SNlM0e/FdrFJe, składam AuthTokens ręcznie. Krócej dla usera, kruchsze przy zmianach HTML.

**Rekomendacja: #1.** Czekam na decyzję usera.

## PoC scope (minimal viable)
1. Auth (sposób #1 lub #2)
2. `client.notebooks.create('PoC')`
3. `client.sources.add_url(notebook_id, '<jakiś YouTube URL>')`
4. `client.artifacts.generate_audio(notebook_id, instructions='...')` → task_id
5. `client.artifacts.wait_for_completion(notebook_id, task_id)` (multi-cell polling, bo 3-10 min vs 180s/cell limit; agent rutyny loopuje)
6. `client.artifacts.download_audio(notebook_id, '/mnt/files/poc.mp3')`
7. `get_mount_file_url` (helper Composio) → `TELEGRAM_SEND_DOCUMENT` na chat 8018506547
8. (opcjonalnie) cleanup notebooka

## Świadomie akceptowane ryzyka
- Cookies/storage_state rotują → ręczny refresh co 2–8 tygodni (głównie `__Secure-1PSIDTS`)
- Library nieoficjalna → może paść w każdej chwili (mitigation: fallback na edge-tts Ryan w tej samej rutynie)
- IP chmury vs konto Google → minimalne przy 1 gen/dzień (mitigation: dedykowane konto Google tylko do tej automatyzacji)
- Generacja 3–10 min → multi-cell polling przez built-in `wait_for_completion`

## Out of scope (na teraz)
- Pełny prompt rutyny AI Radio z NotebookLM (build później, po PoC)
- Lokalna ścieżka na Macu (odrzucona)
- Oficjalne Google Cloud Podcast API (nie darmowe)
- Refresh cookies przez automatyzację (zbyt kruche)

## Następny krok
User wybiera ścieżkę auth (#1 storage_state.json vs #2 cookies+manual extract). Po tym: PoC z YouTube URL → Audio Overview → Telegram. Bez budowania reszty.
