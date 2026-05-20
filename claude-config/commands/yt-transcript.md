---
description: Download YouTube video transcript (captions) to ~/Desktop/transcripts/ via yt-dlp — token-cheap (~1-3k orchestration only)
argument-hint: <youtube-url> [--lang pl,en] [--format md|txt|vtt] [--summary] [--keep-raw] [--out <dir>]
allowed-tools:
  - Skill
  - Bash
  - Read
  - Write
---

Invoke the `yt-transcript` agent skill (defined at `~/.claude/skills/yt-transcript/SKILL.md`) with the user's arguments.

User input: $ARGUMENTS

Read `~/.claude/skills/yt-transcript/SKILL.md` first to load the procedure, anti-rationalization rules, scope boundaries, and definition of done. Then execute according to that skill — do NOT improvise.

**Token discipline reminder:** transcript content does NOT enter your context unless `--summary` flag is set. For default invocations, you are doing orchestration only — keep it that way.
