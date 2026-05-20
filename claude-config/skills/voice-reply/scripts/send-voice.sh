#!/usr/bin/env bash
# voice-reply: text -> MP3 (edge-tts Marek) -> Telegram sendAudio -> verify ok:true.
# Proven mechanism. Honest: never fabricates a send; verifies Telegram JSON.
#
# Usage: send-voice.sh <text-file> [chat_id] [title]
#   <text-file>  required. Plain spoken text (NO markdown). Caller writes the digest here.
#   [chat_id]    optional. Overrides config/default.
#   [title]      optional. Default "Wiadomość głosowa".
#
# Config: ~/.voice-reply-telegram (chmod 600, NOT in repo). Lines:
#   TELEGRAM_BOT_TOKEN=...   (ClaudeArchitectBot @ClaudeOPPArchitectBot — secret)
#   CHAT_ID=...              (default target; not a secret)
# Token NEVER hardcoded here. If file/token missing -> stop honestly, do not fake a send.
# Exit 0 + "WYSLANE ok=True ..." on Telegram-verified success. Non-zero + "NIE wyslane: ..." otherwise.

set -euo pipefail

TXT="${1:?NIE wyslane: brak pliku z tekstem (arg 1)}"
CID_ARG="${2:-}"
TITLE="${3:-Wiadomość głosowa}"
CFG="$HOME/.voice-reply-telegram"

[ -f "$TXT" ] || { echo "NIE wyslane: plik tekstu nie istnieje: $TXT"; exit 1; }
[ -s "$TXT" ] || { echo "NIE wyslane: plik tekstu pusty"; exit 1; }
[ -f "$CFG" ] || { echo "NIE wyslane: brak $CFG (token niedostepny). Utworz plik z TELEGRAM_BOT_TOKEN= ; nie udaje."; exit 1; }

TOKEN="$(grep '^TELEGRAM_BOT_TOKEN=' "$CFG" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"'' | xargs || true)"
[ -n "$TOKEN" ] || { echo "NIE wyslane: brak TELEGRAM_BOT_TOKEN w $CFG. Nie udaje."; exit 1; }

CID_CFG="$(grep '^CHAT_ID=' "$CFG" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'"'' | xargs || true)"
CID="${CID_ARG:-${CID_CFG:-8018506547}}"

command -v python3 >/dev/null || { echo "NIE wyslane: brak python3"; exit 1; }
python3 -m edge_tts --help >/dev/null 2>&1 || { echo "NIE wyslane: edge_tts niedostepny (pip install edge-tts)"; exit 1; }

MP3="$(mktemp -t voicereply-XXXXXX).mp3"
trap 'rm -f "$MP3"' EXIT

python3 -m edge_tts --voice pl-PL-MarekNeural --rate=-6% \
  --file "$TXT" --write-media "$MP3" >/dev/null 2>&1 \
  || { echo "NIE wyslane: edge-tts nie wygenerowal audio"; exit 1; }
[ -s "$MP3" ] || { echo "NIE wyslane: pusty plik MP3 po TTS"; exit 1; }

API="https://api.telegram.org/bot${TOKEN}"
CAP="$(head -c 900 "$TXT")"
RESP="$(curl -sS -m 45 \
  -F "chat_id=${CID}" \
  -F "audio=@${MP3};type=audio/mpeg" \
  -F "title=${TITLE}" \
  -F "caption=${CAP}" \
  "${API}/sendAudio" 2>&1 || true)"

echo "$RESP" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("NIE wyslane: nieparsowalna odpowiedz Telegrama"); sys.exit(1)
if d.get("ok"):
    r = d["result"]
    frm = r.get("from", {}) or {}
    bot = frm.get("username", "?")
    print("WYSLANE ok=True msg_id=" + str(r["message_id"]) + " chat=" + str(r["chat"]["id"]) + " bot=@" + str(bot))
    sys.exit(0)
print("NIE wyslane: " + str(d.get("description"))); sys.exit(1)
'
