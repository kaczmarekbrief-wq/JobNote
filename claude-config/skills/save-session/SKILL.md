---
name: save-session
description: Save the current Claude Code session as verbatim JSONL + jq-converted MD to ~/Desktop/AI-Memory/raw/sessions/. Zero LLM in content path — mechanical bash + jq only.
---

# save-session skill

## Purpose

Persist the current Claude Code session to disk so it can be resumed in a future session — without the LLM ever touching, paraphrasing, or "improving" the conversation content.

## Hard contract (anti-hallucination)

**The LLM is a TRIGGER. Bash is the WORKER.**

- ❌ DO NOT generate, paraphrase, summarize, or "improve" the session content.
- ❌ DO NOT use Write/Edit tools for the output files.
- ❌ DO NOT read the source JSONL into your context "to verify."
- ❌ DO NOT copy session text into chat as a fallback.
- ✅ DO call exactly one Bash command: `~/.scripts/save-current-session.sh "$ARGUMENTS"`.
- ✅ DO show the bash output verbatim.
- ✅ DO confirm in ≤1 sentence and stop.

The conversion is performed by:
1. `cp` (byte-exact JSONL master) — operating system file copy, no interpretation.
2. `jq` mechanical filter via `~/.scripts/jsonl-to-md.sh` (no LLM).

## Procedure

1. Read `$ARGUMENTS` as an optional title for the saved file.
2. Run:
   ```bash
   ~/.scripts/save-current-session.sh "$ARGUMENTS"
   ```
3. Show the script's stdout to the user.
4. Stop. Do not narrate, do not summarize.

## Arguments

- `[title]` — short slug for the filename (default: `session`). Spaces/special chars are sanitized by the script.
- `--session-id <uuid>` — override auto-detection (default = most-recently-modified JSONL).

## Output

Two files in `~/Desktop/AI-Memory/raw/sessions/`, same basename:
- `<TIMESTAMP>-<slug>.jsonl` — master, byte-exact copy
- `<TIMESTAMP>-<slug>.md` — readable, jq-converted

## Resuming in a future session

Paste in a fresh Claude session:
```
@~/Desktop/AI-Memory/raw/sessions/<TIMESTAMP>-<slug>.md
Continue from where this session ended.
```

## Definition of done

- Bash script returned exit 0.
- Two files exist on disk with matching basenames.
- You stopped after one Bash call. You did not generate any session content.

## Failure modes

- Script not executable → tell user to `chmod +x ~/.scripts/save-current-session.sh`.
- Source JSONL missing → tell user no recent Claude sessions found; do not fabricate.
- Anything else → show the bash error verbatim. Do not retry by writing files yourself.
