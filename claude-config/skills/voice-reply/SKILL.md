---
name: voice-reply
description: Turns a concise status/answer into a Polish voice message (MP3) and sends it straight to the user's Telegram so they can listen instead of read. Use when the user asks for an answer/status by voice, says "wyślij mi to na głos", "nie będę czytać, wyślij audio", "przeczytaj mi to na Telegram", "wyślij głosówkę", or is driving / hands-free / out of the house and wants to listen.
---

# voice-reply

Push a short spoken summary to the user's Telegram as audio. Mechanism is proven; the deterministic part lives in `scripts/send-voice.sh` — use it, do not re-improvise the curl/TTS.

## When to use

User wants to LISTEN, not read: driving, walking, out of the house, "wyślij na głos / głosówką / audio / na Telegram". Manual trigger only — never auto-send on every response.

## Workflow

1. **Form the spoken digest** (you write it — this is the only thinking part):
   - Plain spoken Polish. Full sentences. **No markdown, no tables, no headings, no file paths, no code** — they sound terrible read aloud.
   - ~60–150 words. Lead with the decision/status, then what needs the user, then "wróć i powiedz X".
   - If the user passed text as an argument, use that verbatim instead of composing.
2. **Write it to a temp file**: `T=$(mktemp -t vr-XXXXXX).txt` then write the digest into `$T` (use the Write tool or a heredoc).
3. **Send + verify** (one call, deterministic):
   ```bash
   bash ~/.claude/skills/voice-reply/scripts/send-voice.sh "$T" [chat_id] [title]
   ```
   Default chat_id `8018506547` (Marcin, private — not a secret). Override only if the user names another target.
4. **Report honestly**: the script prints `WYSLANE ok=True msg_id=...` on Telegram-verified success, or `NIE wyslane: <powód>`. Relay that exactly. **Never claim it sent unless you saw `ok=True`.**

## Hard rules (non-negotiable — from this project's whole history)

- **Never hardcode the bot token.** It is read from `~/.voice-reply-telegram` (chmod 600, not in repo; bot = @ClaudeOPPArchitectBot). That one specific file only — do not scan other credential stores. Note: `~/.antigravity_telegram` holds a DIFFERENT bot (@AntigravityDevOPPBot) — do not use it here.
- **Never fabricate a send.** No `ok=True` from Telegram → say "NIE wysłane" with the real reason. Honesty over a clean-looking outcome.
- **Voice is `pl-PL-MarekNeural` at `-6%`** (sounds natural; macOS `say`/Zosia is rejected — do not substitute).
- **No auto-trigger.** Manual invocation only; auto-on-every-response is too heavy and risky.
- If `~/.antigravity_telegram`, the token, `python3`, or `edge_tts` is missing, the script stops with a clear message — surface it, don't paper over.

## Quick start

```bash
T=$(mktemp -t vr-XXXXXX).txt
printf '%s' "Status krótko. Zrobione X i Y. Czeka na Twoją decyzję Z. Wróć i powiedz numery." > "$T"
bash ~/.claude/skills/voice-reply/scripts/send-voice.sh "$T"
```

## Notes

- Complements the local hotkey TTS (`tts_auto_read.md` — F3/F4, on-machine). This skill is the "push to Telegram" variant for when the user is away from the Mac.
- chat_id resolution: if the default ever fails and the user has just messaged the bot, you may resolve their real chat from `getUpdates` on the same token (their actual message = user-intended, not a guess). Never send to an inferred group.
