---
date: "2026-05-20 12:30"
promoted: false
---

# Rutyna Notebook — UPDATE po researchu NotebookLM

**Referencja:** poprzednia notatka `2026-05-20-rutyna-notebook-notebooklm-cloud.md`.
User puścił mój prompt research'owy do NotebookLM. Wyniki potwierdziły kierunek + dodały kilka istotnych rzeczy.

## Potwierdzone (zgodne z wcześniejszym audytem)
- `notebooklm-py` w sandbox chmurowym = czysty HTTP klient (no browser at runtime).
- Jednorazowy login MUSI być w przeglądarce sterowanej przez człowieka (Google 2FA/CAPTCHA).
- `storage_state.json` jako sekret → ścieżka #1, rekomendowana.
- NotebookLM Enterprise Podcast API = płatne → out dla 0 zł.

## Nowe ustalenia (warto pamiętać)

1. **`notebooklm-sdk` (TypeScript)** — wariant Node/Vercel; alternatywa dla Python jeśli kiedyś przenosimy.
2. **DBSC (Device Bound Session Credentials)** ⚠️ **ważne forward risk**:
   - Google wdraża standard wiążący cookies sesyjne z TPM fizycznego urządzenia.
   - Jeśli konto Google zostanie tym objęte → przeniesienie sesji do chmury **przestaje działać w ogóle** (nie tylko expiry — całkowity blok).
   - Mitigation: fallback edge-tts Ryan zostaje; gdyby pękło → wracamy do Ryana.
3. **Cookies expire ~2–4 tygodnie** (pesymistyczniej niż moje 2–8). Refresh **~co miesiąc**.
4. **Konwencja env var: `NOTEBOOKLM_AUTH_JSON`** — community standard, użyć w prompcie rutyny.
5. **Alternatywne deploymenty deklarowane jako sprawdzone publicznie**:
   - GitHub Actions cron (free dla public repo / 2000 min/mc dla free private).
   - AWS Lambda, GCP Cloud Functions.
   - **NoteCast** — referencyjny OSS pattern (Docker container + auto RSS), do podejrzenia jeśli Composio sandbox będzie ciasny.
6. Library `notebooklm-py` ma **jittered backoff** wbudowany przeciw rate limiting Google na cloud-IP.

## Decyzja operacyjna (zacementowana po researchu)
- Ścieżka **#1: `from_storage` + `storage_state.json`** — bez dalszego wahania.
- Akceptowane ryzyka: miesięczny refresh, DBSC forward risk, ewentualny rate limit cloud-IP.
- Plan B na wypadek gdyby Composio sandbox był problematyczny: GitHub Actions cron z tym samym kodem (publicznie udokumentowany pattern).

## Następny krok (oczekiwane od usera)
- Jednorazowo wyeksportować `storage_state.json` z zalogowanej sesji Chrome na NotebookLM (dowolne urządzenie, niekoniecznie Mac):
  - Opcja A: `notebooklm` CLI (instaluje się z paczką) — sprawdzić czy ma `auth login` lub równoważną komendę.
  - Opcja B: Playwright codegen lokalnie raz.
  - Opcja C: ręcznie z DevTools (Application → Storage State export).
- Wkleić treść JSON do mnie → ja zapiszę jako sekret w prompcie rutyny → PoC w sandboxie (YouTube URL → Audio Overview → Telegram).
