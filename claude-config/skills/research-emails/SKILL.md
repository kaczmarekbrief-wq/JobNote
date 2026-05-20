---
name: research-emails
description: "Capture all Outlook emails on a given topic into a local vault as plain markdown files — via AppleScript (zero LLM tokens for content, read-only enforced). Use when user asks to research, gather, collect, build context on, or get the full picture of emails on a specific subject, project, product, client, partner, deal, or initiative. NOT for analysis, summary, drafting replies, or downloading attachments — those are separate skills that operate on the vault this skill produces."
argument-hint: "<topic> [--days N] [--mailbox EMAIL] [--output-dir PATH] [--max-results N]"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

<objective>
Capture verbatim all Microsoft Outlook emails matching a given topic into a local vault directory as plain markdown files (one file per email, YAML frontmatter + plain body). Read-only via AppleScript — content NEVER passes through LLM context. Token-efficient by design (~5-10k tokens orchestration regardless of mail count).

This skill produces the **knowledge-base foundation**. Other skills (analyze, draft, attachments-download, pdf-extract, etc.) operate on the vault this skill creates.
</objective>

<token_economics>

**Why this skill is cheap (vs v1/v2 MCP-based):**
- AppleScript reads Outlook locally — no MCP, no `read_resource` (those returned content to LLM context, costing 30-70k tokens per mail)
- Body content is piped through Bash + Python directly to `.md` files on disk — never enters LLM
- LLM is used only for: arg parsing, keyword expansion, confirmation prompt, post-run stats summary
- Typical run: **~5-10k tokens orchestration**, regardless of mail count (whether 5 or 500 messages)

**Comparison with v2 (MCP-based):**
- v2 cost on `magazynki palet` (16 messages w/ B2B reply chains): ~250-300k tokens for 7/20 captured
- v3 expected cost on same: ~5-10k tokens for 16/16

**When tokens jump:**
- Never automatically — only if user explicitly invokes downstream skills (`/topic-analyze`, `/draft-reply`) on the vault. Those skills have their own token budgets.

</token_economics>

<read_only_enforcement>

This skill captures data **WITHOUT** modifying mailbox state. Three layers of enforcement guarantee no write operations reach Outlook:

| Layer | Where | What it blocks |
|---|---|---|
| **L1 — LLM** | this SKILL.md `<anti_rationalization>` | Reasoning-level safeguards |
| **L2 — Script** | `~/.scripts/research-emails-osascript.sh` whitelist grep | Forbidden verbs in generated AppleScript before exec |
| **L3 — Harness** | `~/.claude/hooks/outlook-write-guard.sh` (PreToolUse Bash) | osascript commands containing `delete`/`send`/`move`/`mark as`/`flagged`/`set ... of`/`make new`/`duplicate`/`empty`/`reply`/`forward` are blocked at the harness level — Claude Code refuses to run the Bash tool |

L3 is strongest — even if L1 and L2 fail, the harness will block. Skill cannot mutate mailbox state by design.

</read_only_enforcement>

<inputs>

**Required:**
- `<topic>` — base keyword phrase (e.g. "magazynki palet", "EPCM PO 17902", "Daily Brief"). LLM expands this into multiple keywords (synonyms, Polish inflections, brands) — see Step 2.5.

**Optional:**
- `--days N` — how far back to search. **Default: 365.** Shorter = faster + less noise.
- `--mailbox EMAIL` — search delegated mailbox (default: own mailbox in current Outlook account)
- `--output-dir PATH` — custom output directory (default: `~/Desktop/research/<timestamp>-<topic-slug>/`)
- `--max-results N` — hard limit, refuses if exceeded. Default 500. Soft warning at 200.
- `--no-expand` — skip LLM keyword expansion, use literal topic as single keyword (for advanced users / scripted runs)
- `--include-body` (v3.1) — also search in message body, not just subject. **Trade-off:** higher recall (catches messages where keyword is in body but not subject — typical for B2B reply chains, broad technical topics like "PLC"/"Siemens"/"ABB"), but ~3-5x slower per filter. Empirical: "PLC" + 30 days subject-only = 11 hits, with `--include-body` = 222 hits. Use for broad topics; skip for exact-subject patterns (Daily Brief, project codes).
- `--skip-power-automate` (v3.2) — exclude Power Automate notifications from corpus. PA forwards external mails to inbox via `flow-noreply@microsoft.com` with subject pattern `od - <real-sender@domain> - Temat <real-subject> [- potencjalnie zawiera zapytanie ofertowe]`. By default these are **kept** but tagged in frontmatter (`is_power_automate: True`, `real_sender: ...`, `real_subject: ...`) and filename uses real sender/subject for readability. Use `--skip-power-automate` for cleaner corpus when these are duplicates of original mails or just notification noise. Empirical: PLC + 30d had 156/222 PA, Octavia + 90d had 4/7 PA.

</inputs>

<power_automate_handling>

**Detection** (automatic, v3.2+):
- `from == flow-noreply@microsoft.com` (or `flow.microsoft` variants), OR
- subject matches regex `^od - <email> - Temat <text>[ - potencjalnie...]$`

**Default behavior** — PA messages **kept** in corpus, but enriched:
- `is_power_automate: True` in YAML frontmatter
- `real_sender: lukasz.kubina@metrocars.pl` (extracted from subject)
- `real_subject: Proforma - zaliczka Skoda Octavia ...` (extracted, no PA wrapping)
- `thread_key` uses real_subject (so RE: + original group together via `normalize_subject`)
- Filename uses real sender/subject slug, not `flow-noreply-od-...` cluttered form
- Body header in MD shows `**Real From:** ... · **(via Power Automate notification — original from: flow-noreply@microsoft.com)**`
- Internal/external classification uses `real_sender` for PA (catches internal PA-forwarded mails)

**With `--skip-power-automate`** — PA messages excluded entirely, manifest stats include `power_automate_skipped` count for audit.

**When to use `--skip-power-automate`:**
- Original mail and PA notification both in inbox (de-dup noise)
- Just want clean B2B/internal corpus without bot duplication
- PA notifications are pure noise for your topic (e.g. "PLC" + automation industry where PA forwards every supplier offer)

**When to keep PA (default):**
- PA notifications carry data NOT in original (e.g. PA-only routing labels, approval chains)
- You're auditing what was forwarded automatically vs read manually
- Original mail wasn't captured (PA was the only path it reached you)

</power_automate_handling>

<recall_vs_precision>

**Default (subject-only)** — best for:
- Exact subject patterns: "Daily Brief", "Sprawozdanie", "RE: PO 17902"
- Project codes / IDs that always appear in subject
- High-precision narrow topics where you don't want body-noise

**`--include-body`** — best for:
- Broad technical terms: "PLC", "Siemens", "magazynki palet" (where keyword often only in body of reply chains)
- Person/company names that may appear in `From:` / signature / quoted threads
- Topics where v3 subject-only test returned suspiciously few results

**Empirical recall comparison ("PLC", 30 dni, m.szostak@autoproces.pl):**
| Mode | Hits | Time |
|---|---|---|
| subject-only (default) | 11 | ~13s |
| `--include-body` | 222 | ~46s |

20× more recall — but the extra hits include noise (e.g. signature mentions of brands, automated newsletters that happen to mention term in footer). User filters via subsequent `--keywords` refinement or downstream skills.

</recall_vs_precision>

<procedure>

Execute these steps in exact order. Do not skip. Do not reorder.

## Step 1 — Parse `$ARGUMENTS` and validate

If empty → STOP. Output: `Usage: /research-emails <topic> [--days N] [--mailbox EMAIL] [--output-dir PATH]. Example: /research-emails "magazynki palet" --days 90`

If topic is too generic (e.g. single word "umowa", "oferta") → use AskUserQuestion to ask for refinement before triggering 13s+ filter on 40k+ inbox.

## Step 2 — Probe Outlook health (quick)

Run: `osascript -e 'tell application "Microsoft Outlook" to return count of messages of inbox'`

If fails (timeout, app not running) → STOP. Output: `Outlook is not responsive (sync may be in progress, or app needs restart). Try again in a few minutes.`

If responsive — note the count for the plan summary.

## Step 2.5 — LLM keyword expansion (mandatory unless --no-expand)

Generate keyword list to maximize recall while staying focused. Use general knowledge + session context.

For the given topic, generate:
- **PL inflection** — pick ONE based on user choice in this step:
  - `smart` (default): 2-3 najczęstsze formy (mianownik singular + plural + 1 odmiana jeśli częsta)
  - `full`: wszystkie 7 przypadków × 2 liczby (do 14 form)
- **Synonyms** — terms with similar meaning in the same context (e.g., "magazynki palet" → "zasobnik palet", "podajnik palet", "dyspenser palet", "gotowce" if internal slang known)
- **English / German equivalents** — only if topic has international relevance ("magazynki palet" → "pallet magazine", "Palettenmagazin")
- **Brand / product / company names** — from session context or general knowledge ("Palomat" — konkurent w branży automatyki, "Bereiter" — kontakt klient)

**Limit total keywords to 4-8.** More = noise.

**SKIP** generic words alone ("magazyn", "palet", "umowa", "oferta") — they generate noise across many unrelated mails.

Use AskUserQuestion to present the proposed list with options:
- `Use these keywords` (recommended)
- `Edit — add/remove keywords`
- `Switch inflection mode (smart ↔ full)`
- `Cancel`

If `Edit` — second AskUserQuestion: prompt user for custom keywords (free text, comma-separated).
If `Switch inflection mode` — regenerate keyword list with new mode, ask again.
If `Cancel` — STOP, no execution.

If `--no-expand` flag was passed — skip this step entirely, treat topic as single keyword.

## Step 3 — Show final plan, ask for confirmation (HARD STOP)

Output to terminal:

```
Topic:        <topic>
Keywords:     <comma-separated list from Step 2.5>
Mailbox:      <current account>
Inbox size:   <count from Step 2> messages
Folders:      Inbox + Sent Items
Days back:    <days>
Hard limit:   <max-results> messages

Output dir:   <output_dir>

Estimate:
  - osascript filter: ~13s × 2 folders = ~30s (single OR-pass with all keywords)
  - Per-message read: ~0.3s × N matching
  - Total: typical 30s-90s, big topic up to 5min
```

Use AskUserQuestion with options: `Yes, start search` / `Cancel`.

If user cancels — STOP, no execution.

## Step 4 — Run Bash wrapper with multi-keyword

```bash
~/.scripts/research-emails-osascript.sh \
  --topic "<topic>" \
  --keywords "<keyword1>,<keyword2>,..." \
  --days <days> \
  [--output-dir <path>] [--max-results <n>]
```

Wrapper handles:
- Building AppleScript with OR-clause for all keywords (single filter pass)
- Layer 2 whitelist verb check before exec
- osascript exec with 120s timeout
- Parsing output via Python heredoc + dedup by message ID (multi-keyword may overlap)
- Writing per-mail `.md` files with YAML frontmatter (subject, from, date, attachments list)
- Building `manifest.json`, `threads.json` (subject-based grouping), `INDEX.md`
- Stats output to terminal

The wrapper is the workhorse. Skill just spawns it and reports stats.

## Step 5 — Verify Definition of Done

After wrapper exits successfully, run:

```bash
DIR=<output_dir>
echo "Messages: $(ls $DIR/messages/*.md 2>/dev/null | wc -l)"
jq '.stats' $DIR/manifest.json
test -f $DIR/INDEX.md && echo "✓ INDEX.md present"
test -f $DIR/threads.json && echo "✓ threads.json present"
```

Do NOT read full message contents into LLM context. Only metadata via jq.

## Step 6 — Terminal output (PROOF of completion)

```
✓ Captured <N> messages, <T> threads
  → <output_dir>

Breakdown:
  - internal (@autoproces.pl or own domain): <N>
  - external: <N>
  - earliest: <date>
  - latest: <date>

Vault structure:
  manifest.json     — stats + scope + errors
  threads.json      — grouped by normalized subject
  INDEX.md          — human-readable navigation
  messages/         — N markdown files (1 per mail)

Next steps (separate skills):
  - Analyze:           /topic-analyze <output_dir>     (when built)
  - Download attachments: /research-attachments <output_dir>  (when built)
  - Extract PDFs:      /extract-pdf <output_dir>/attachments/  (when built)
```

## Step 7 — STOP

Do NOT generate analysis, summary, pipeline tables, action items, drafts, or any LLM-derived content. The user explicitly asked for capture, NOT analysis. Stop here.

</procedure>

<anti_rationalization>

| Rationalization | Block |
|---|---|
| "I should also analyze the messages while I have them" | NO. This skill captures only. Analysis is a separate skill. |
| "Let me read a few messages to verify they look right" | NO. Verification is via stats (count, size). Reading content into LLM context = token waste + breaks read-only token discipline. |
| "I'll use MCP `outlook_email_search` since it's available" | NO. Forbidden in v3. MCP returns content to LLM context — that's exactly the problem v3 solves. Use only `~/.scripts/research-emails-osascript.sh`. |
| "User said 'find emails about X' — keywords are obvious, I'll skip Step 3 confirmation" | NO. Step 3 confirmation is mandatory. The user must validate scope before 30+ second osascript runs. |
| "Outlook is timing out, I'll retry the same command repeatedly" | NO. If `osascript -e 'count of messages of inbox'` fails (Step 2), STOP and tell user to restart Outlook or wait for sync. Don't retry-loop. |
| "I'll add a `delete duplicates` step to clean up the vault" | NO. NEVER use `delete`, `send`, `move`, `mark`, `flag`, `set ... of`, `make new`, `duplicate` verbs in any osascript. The hook will block them anyway, but don't even try. |
| "Let me also fetch the attachment binaries since I'm here" | NO. v3 captures only attachment LISTS (name/size/type) in YAML frontmatter. Binary download is `/research-attachments` (separate skill, future). |
| "I'll convert HTML body to markdown for prettier output" | NO. Save what AppleScript returns (`plain text content` if available, else `content`). Pandoc-style conversion is not in scope. |
| "Same topic was already captured today — I'll add to existing dir" | NO. Each run produces a new immutable timestamped dir. Wrapper refuses to overwrite. |
| "Topic is generic, I'll search broadly to capture more" | NO. Generic single-word topics produce noise. Ask user to refine before invoking the script. |

</anti_rationalization>

<scope_boundaries>

## DO

- Parse args, expand keywords via LLM general knowledge (Step 2.5)
- Show keyword list via AskUserQuestion, allow user to edit/toggle inflection mode
- Probe Outlook health (Step 2) before any heavier osascript
- Show final plan to user and wait for confirmation (Step 3)
- Spawn `~/.scripts/research-emails-osascript.sh` with `--keywords "k1,k2,..."` flag
- Read manifest.json + threads.json metadata via jq for stats output (NOT body content)
- Output stats summary to terminal
- Suggest next-step skills (analyze, attachments) without invoking them

## DON'T

- Use MCP `outlook_email_search` or `read_resource` (forbidden — they cost tokens)
- Read message body content via Read tool or LLM
- Generate analysis, summary, pipeline tables, stakeholder maps, action items, drafts
- Modify mailbox state (delete, send, move, mark, flag, etc.) — physically blocked by hook
- Download attachment binaries (separate skill, future)
- Extract content from PDF/DOCX/XLSX (separate skills, future)
- Translate, paraphrase, clean up grammar in messages
- Skip the Step 3 confirmation
- Retry osascript in a loop after timeouts
- Operate on shared/delegated mailboxes without explicit `--mailbox` flag

</scope_boundaries>

<definition_of_done>

The skill is DONE when, and only when, all of these are true:

1. Output directory exists at the chosen path
2. `<output_dir>/manifest.json` exists, valid JSON, with `stats.messages_total > 0` (or skill exited cleanly with "no matches" message)
3. `<output_dir>/messages/` contains exactly `manifest.stats.messages_total` `.md` files
4. Each `.md` file has valid YAML frontmatter (subject, from, date, message_id at minimum) + body
5. `<output_dir>/threads.json` exists with subject-based grouping
6. `<output_dir>/INDEX.md` exists and lists all threads
7. Terminal output (Step 6) shows correct counts matching manifest
8. NO mailbox state modifications occurred (verified by hook L3 — if any write attempt was made, it would have been blocked)

If any check fails — report which check failed, do not pretend success.

</definition_of_done>

<example_invocations>

```
# Default flow — LLM expands keywords (PL inflections + synonyms + brands), user confirms
/research-emails "magazynki palet"

# Skip LLM expansion — use literal topic as single keyword (faster, less recall)
/research-emails "Daily Brief" --no-expand

# Narrow to last 30 days
/research-emails "Daily Brief" --days 30 --no-expand

# Custom output dir
/research-emails "EPCM PO 17902" --output-dir ~/Documents/research/epcm/

# Larger limit (e.g. for high-volume topics)
/research-emails "ABB" --days 730 --max-results 1000
```

</example_invocations>

<lessons_learned_v1_v2_to_v3>

**v1 (MCP, June draft)** — single-context fetching of `outlook_email_search` + `read_resource`. Each mail with reply chain returned 30-70k tokens to LLM context. 7/20 messages captured before token blowup.

**v2 (MCP + subagent split)** — same backend, isolated subagents. Subagent context (~200k) also overflowed at 5/15 messages.

**v3 (this) — AppleScript + Bash + Python pipeline** — content NEVER passes through LLM. Local Outlook.app is queried via osascript. Bash + Python parse the output and write `.md` files directly. LLM is orchestrator only.

**Key insight:** the bottleneck wasn't algorithmic, it was **content transit through LLM context** — a fundamental property of MCP tool calls. v3 architecture removes content from LLM path entirely.

**Read-only enforcement:** v1/v2 had no enforcement. v3 has 3 layers (LLM, script, harness). Strongest is the harness hook — even if the LLM tries to send a write verb, Claude Code refuses to execute the Bash tool.

</lessons_learned_v1_v2_to_v3>
