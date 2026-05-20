---
name: post-run-review
description: "Post-run feedback loop implementing Rule 4: after any skill runs, ask if output matched expectations, then permanently update SKILL.md if the fix is recurring. Call after any skill execution to capture learnings. Arguments: <skill-name>"
argument-hint: "<skill-name>"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
---

<objective>
Capture post-run feedback on any skill and update its SKILL.md if the fix is permanent. Implements Rule 4 (Anthropic engineers): skills learn from every session.

Can be invoked manually with `/post-run-review <skill-name>`, or added as the last step in any skill's procedure.
</objective>

<procedure>

## Step 1 — Identify the skill

If `$ARGUMENTS` is empty → use AskUserQuestion to ask which skill was just run.

Resolve path: `~/.claude/skills/<skill-name>/SKILL.md`

Verify it exists:
```bash
test -f ~/.claude/skills/<skill-name>/SKILL.md && echo "found" || echo "not found"
```

If not found → STOP. Output: `Skill '<skill-name>' not found at ~/.claude/skills/<skill-name>/SKILL.md`

## Step 2 — Was the output as expected?

Use AskUserQuestion:
- Question: "Was the output of `/<skill-name>` what you expected?"
- Options: "Yes, all good", "Partially — some things off", "No — output was wrong"

If "Yes, all good" → output `✓ No changes needed.` and STOP.

## Step 3 — What was wrong?

Use AskUserQuestion (multiSelect: true):
- Question: "What specifically was wrong or missing?"
- Options: "Output format", "Missing step", "Wrong assumption", "Behavior mismatch"

Follow-up (single select):
- Question: "Is this a one-time edge case, or something the skill should always handle differently?"
- Options: "One-time — just this run", "Permanent — update the skill"

If "One-time" → output `✓ Noted. No skill update.` and STOP.

## Step 4 — Read current SKILL.md

```bash
cat ~/.claude/skills/<skill-name>/SKILL.md
```

Based on the feedback and the current content, propose ONE minimal, surgical change. Target:
- A step in `<procedure>` — add/modify
- An entry in `<anti_rationalization>` — add a new row
- A check in `<definition_of_done>` — tighten a criterion
- A boundary in `<scope_boundaries>` — clarify DO/DON'T

Show the proposed change in terminal as a human-readable before/after:

```
Proposed change to ~/.claude/skills/<skill-name>/SKILL.md:

BEFORE:
  <original text>

AFTER:
  <replacement text>

Reason: <one sentence>
```

## Step 5 — Confirm and apply

Use AskUserQuestion:
- Question: "Apply this change to the skill?"
- Options: "Yes, apply", "Edit the proposal first", "No, discard"

If "No, discard" → STOP.
If "Edit the proposal first" → use AskUserQuestion to collect the corrected text (free text), show updated before/after, and ask again.
If "Yes, apply" → use Edit tool to apply the change to `~/.claude/skills/<skill-name>/SKILL.md`.

## Step 6 — Done

Output:
```
✓ Skill updated: ~/.claude/skills/<skill-name>/SKILL.md
  Change: <one-line summary>
```

</procedure>

<anti_rationalization>

| Rationalization | Block |
|---|---|
| "The issue is obvious, I'll update the skill without asking" | NO. Always show before/after and wait for Step 5 confirmation. |
| "User said 'partially' — I'll make several improvements while I'm here" | NO. One surgical change per session. Scope to the specific feedback. |
| "I'll rewrite the whole procedure section for clarity" | NO. Touch only the relevant part, match existing style. |
| "User didn't name a skill, I'll infer it from conversation context" | NO. Ask explicitly via AskUserQuestion if $ARGUMENTS is empty. |
| "The change is tiny, I'll skip the before/after display" | NO. Always show the diff before applying. |

</anti_rationalization>

<definition_of_done>

Exactly one of these outcomes:
- Feedback positive → output "No changes needed", stopped.
- Feedback one-time → output "Noted, no update", stopped.
- Feedback permanent → SKILL.md edited, user confirmed, output shows path + one-line summary of change.

</definition_of_done>
