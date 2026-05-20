---
description: Capture Outlook emails on a given topic via AppleScript (read-only, ~5-10k tokens orchestration regardless of mail count) → vault at ~/Desktop/research/<timestamp>-<topic-slug>/
argument-hint: <topic> [--days N] [--include-body] [--skip-power-automate] [--no-expand] [--mailbox EMAIL] [--output-dir PATH] [--max-results N]
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

Invoke the `research-emails` agent skill (defined at `~/.claude/skills/research-emails/SKILL.md`) with the user's arguments.

User input: $ARGUMENTS

Read `~/.claude/skills/research-emails/SKILL.md` first to load the v3 procedure, anti-rationalization rules, scope boundaries, and definition of done. Then execute according to that skill — do NOT improvise.

**Architecture v3 (key facts):**
- Backend: `~/.scripts/research-emails-osascript.sh` (Bash + osascript + Python heredoc)
- Read-only enforced 3 layers — DO NOT use MCP `outlook_email_search` / `read_resource` (those are forbidden, cost tokens, and v3 explicitly rejects them)
- Content NEVER enters LLM context — bash pipes osascript → Python → `.md` files directly on disk
- LLM orchestration only: arg parse, confirmation, post-run stats summary
