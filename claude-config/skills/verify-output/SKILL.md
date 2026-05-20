---
name: verify-output
description: "Deterministic post-run verifier. Looks for verify.py inside the skill's folder and runs it against the output path. Returns PASS/FAIL with details. Called by post-run-review or skill procedures — not by users directly."
argument-hint: "<skill-name> <output-path>"
user-invocable: false
allowed-tools:
  - Bash
---

<objective>
Run a skill's own verify.py deterministically against its output. Zero LLM interpretation — code checks code. Returns structured PASS/FAIL so callers can branch on the result.

This skill is the deterministic anchor in the Rule 4 loop:
  skill → output → verify-output → PASS/FAIL → post-run-review (if FAIL)
</objective>

<procedure>

## Step 1 — Parse arguments

Expected: `<skill-name> <output-path>`

Extract:
- `SKILL_NAME` = first token
- `OUTPUT_PATH` = second token (may be empty — see Step 2)

If `SKILL_NAME` is empty → STOP. Output: `Usage: verify-output <skill-name> <output-path>`

## Step 2 — Locate verify.py

```bash
VERIFY_SCRIPT="$HOME/.claude/skills/$SKILL_NAME/verify.py"
test -f "$VERIFY_SCRIPT" && echo "found" || echo "missing"
```

If missing → output:
```
SKIP: no verify.py found at ~/.claude/skills/<skill-name>/verify.py
To add verification: create that file (see ~/.claude/skills/yt-transcript/verify.py as reference).
```
Then exit 0 (not a failure — skill just has no verifier yet).

## Step 3 — Run verify.py

```bash
python3 "$HOME/.claude/skills/$SKILL_NAME/verify.py" "$OUTPUT_PATH"
```

Capture exit code and stdout.

## Step 4 — Output result

If exit code = 0:
```
PASS  /<skill-name>
  Output: <output-path>
  <stdout from verify.py>
```

If exit code ≠ 0:
```
FAIL  /<skill-name>
  Output: <output-path>
  <stdout from verify.py>
```

Do NOT interpret the failure. Just relay stdout verbatim. The caller (post-run-review or the user) decides what to do.

</procedure>

<anti_rationalization>

| Rationalization | Block |
|---|---|
| "verify.py output looks fine to me, I'll override to PASS" | NO. Exit code is authoritative. Relay it unchanged. |
| "There's no verify.py, I'll check the output myself with LLM" | NO. Output SKIP and stop. LLM interpretation is not deterministic. |
| "I'll run extra checks beyond what verify.py does" | NO. verify.py is the spec. Don't add. |

</anti_rationalization>

<definition_of_done>

One of three outcomes:
- `PASS` — verify.py exited 0, stdout relayed.
- `FAIL` — verify.py exited non-zero, stdout relayed.
- `SKIP` — no verify.py found, instructed caller how to add one.

</definition_of_done>
