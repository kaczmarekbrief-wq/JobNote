---
date: "2026-05-21 06:45"
promoted: false
---

# Hermes Agent — zainstalowany na Azure VM, brakuje API key

> **Status na 2026-05-21 04:45 UTC:** Hermes Agent v0.14.0 zainstalowany na claude-vm,
> wszystkie 89 skills bundled, CLI działa. **Brakuje tylko klucza OpenRouter** żeby zacząć korzystać.

## Co już jest na VM (claude-vm, 20.54.82.106)

- **Binary**: `/home/Marcin/.local/bin/hermes` (alias przez uv)
- **Code**: `/home/Marcin/.hermes/hermes-agent/` (git repo NousResearch/hermes-agent, branch main)
- **Config**: `/home/Marcin/.hermes/config.yaml` (57 KB, default)
- **API keys**: `/home/Marcin/.hermes/.env` (23 KB, ale **bez OPENROUTER_API_KEY**)
- **Skills**: `/home/Marcin/.hermes/skills/` (89 bundled — pretext, comfyui, obsidian, notion, linear, airtable, powerpoint, ocr-and-documents, claude-design itd.)
- **Sessions/logs**: `/home/Marcin/.hermes/{sessions,logs,cron,audio_cache}/`
- **Default model**: `anthropic/claude-opus-4.6`, provider `Auto`
- **Reload PATH** (po `source ~/.bashrc`): `hermes` dostępny globalnie

## Jak dodać klucz OpenRouter (z Maca, najszybsze)

```bash
# Z Twojego Maca (jednorazowo):

# Wariant A — skopiuj cały .env z Maca (zawiera OPENROUTER_API_KEY + reszta):
scp ~/.hermes/.env Marcin@20.54.82.106:~/.hermes/.env
ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106 'chmod 600 ~/.hermes/.env'

# Wariant B — dopisz tylko klucz (jeśli VM .env zawiera inne ustawienia warte zachowania):
KEY=$(grep '^OPENROUTER_API_KEY=' ~/.hermes/.env | head -1)
ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106 "echo '$KEY' >> ~/.hermes/.env && chmod 600 ~/.hermes/.env"
```

**Wariant A jest pewniejszy** — przeniesie wszystkie Twoje keys i ustawienia z Maca.

## Sanity check po wgraniu klucza (na VM)

```bash
ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106
hermes status
# Powinno pokazać: OpenRouter ✓ (set)

hermes model     # sprawdź jaki model jest default
hermes doctor    # ogólny health check

# Pierwsza rozmowa
hermes -z "Powiedz po polsku jedno zdanie potwierdzenia że działasz na Azure VM."
```

## Migracja z OpenClaw (jeśli była na Macu)

Hermes ma wbudowane: `hermes claw migrate` przenosi settings/memories/skills/API keys
z `~/.openclaw/` do `~/.hermes/`. Na VM OpenClaw nigdy nie było — pomijamy.

Na Macu, jeśli kiedykolwiek używałeś OpenClaw przed Hermesem i chcesz wszystko przenieść:
```bash
hermes claw migrate
hermes claw clean   # archiwum starych katalogów
```

## Co jeszcze warto skonfigurować (opcjonalnie)

### Gateway (messaging + cron) — żeby Hermes mógł odpisywać na Telegram/WhatsApp

```bash
hermes gateway install
hermes gateway --help
```

Na VM przyda się jeśli chcemy żeby Hermes słuchał wiadomości z Telegrama na chat `8018506547`.

### Integracja z naszym daily brief?

Daily-brief-unified już działa lokalnie (systemd timer, NotebookLM PL + edge-tts EN fallback,
codziennie 04:45 Europe/Warsaw). Hermes mógłby być warstwą *nad* tym — np.:
- generować summary z briefu (LLM call zamiast template)
- odpowiadać na wiadomości follow-up od Marcina ("co tam w MUST DO?")
- użyć skills (notion, linear) do dodawania zadań głosem

To osobny task — najpierw setup API key, potem zdecydujemy czy integrujemy.

## Wymagania VM (potwierdzone)

- 4 CPU, 15 GB RAM, 51 GB disk, Ubuntu 24.04, kernel 6.17 azure
- uv 0.11.15, Python 3.11.15, Node.js 20.20.2, git 2.43.0
- ffmpeg + ripgrep + pocketsphinx (dla TTS/STT) — zainstalowane podczas Hermes installer

## Następny krok (po Twojej stronie, ~1 min)

1. Otwórz terminal na Macu
2. Uruchom Wariant A (powyżej): `scp ~/.hermes/.env Marcin@20.54.82.106:~/.hermes/.env`
3. Napisz w czacie z Claude "gotowe" — uruchomię `hermes status` żeby zweryfikować że klucz wszedł
4. (Opcjonalne) zdecyduj czy chcesz integrację z daily brief — wtedy zaczynamy Fazę 2
