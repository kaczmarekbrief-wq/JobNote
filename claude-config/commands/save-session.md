---
description: Save the current Claude Code session to ~/Desktop/AI-Memory/raw/sessions/ — verbatim JSONL + jq-converted MD. Zero LLM in content path.
argument-hint: [title]
allowed-tools:
  - Skill
  - Bash
---

Invoke the `save-session` agent skill (defined at `~/.claude/skills/save-session/SKILL.md`) with the user's arguments.

User input: $ARGUMENTS

Read `~/.claude/skills/save-session/SKILL.md` first to load the anti-hallucination contract, scope boundaries, and definition of done. Then execute according to that skill — do NOT improvise.

**Hard rule:** the LLM is a trigger only. Bash + jq do the work. Do NOT generate, paraphrase, or summarize session content. One Bash call, show its output, stop.
