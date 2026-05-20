---
name: yt-transcript
description: "Download a YouTube video transcript (auto-generated or author-uploaded captions) into a markdown file with metadata under ~/Desktop/transcripts/. Uses yt-dlp CLI — content does NOT pass through LLM context, so token cost is ~minimal (~1-3k tokens for orchestration). Use when user wants the text of a YouTube video, transcript, captions, subtitles, lecture notes, or to read what someone said without watching. Topics: 'transkrypcja yt', 'pobierz napisy', 'co jest w tym filmie', 'youtube transcript'."
argument-hint: "<url> [--lang pl,en,auto] [--format md|txt|vtt] [--summary] [--keep-raw] [--out <dir>]"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

<objective>
Download the transcript of a YouTube video into a clean markdown file with YAML frontmatter (title, channel, URL, duration, source, date). Pure CLI execution via `yt-dlp` — content NEVER enters LLM context unless `--summary` flag is used. Token-efficient by design.

This skill produces text files. ANALYZE/SUMMARIZE/Q&A on the transcript are separate tasks that read the file.
</objective>

<token_economics>

**Why this skill is cheap (vs research-emails):**
- yt-dlp downloads captions to disk directly — LLM never sees the content
- Bash + sed/awk handle VTT → clean text conversion — zero LLM tokens
- LLM is used only for: parsing args, validating URL, formatting frontmatter, printing preview
- Typical run: **~1-3k tokens orchestration**, plus ~$0 in compute

**When tokens jump:**
- `--summary` flag → LLM reads transcript file (10-50k tokens depending on video length) and produces summary. Use only when needed.
- Long videos (>2h podcasts) with `--summary` can hit 100k+ tokens — consider chunked summary in v2.

</token_economics>

<inputs>

**Required:**
- `url` — YouTube URL. Accepts: full URL, short youtu.be, with/without timestamp params

**Optional:**
- `--lang pl,en,auto` — language preference. Default: `pl,en,auto` (try Polish first, then English, then any). Pass `auto` alone for auto-detect.
- `--format md|txt|vtt` — output format. Default: `md` (markdown with frontmatter).
  - `txt` — plain text only (no frontmatter)
  - `vtt` — preserve original VTT format with timestamps
- `--summary` — after download, LLM produces 5-7 bullet summary in Polish appended to file. Adds ~10-50k tokens.
- `--keep-raw` — also save the raw VTT file alongside the cleaned output
- `--out <dir>` — output directory. Default: `~/Desktop/transcripts/`

</inputs>

<procedure>

## Step 1 — Parse URL and validate

If `$ARGUMENTS` is empty → STOP. Output: `Usage: /yt-transcript <youtube-url> [flags]. Example: /yt-transcript https://youtu.be/abc123 --lang pl --summary`

Extract video ID:
- `https://www.youtube.com/watch?v=ID` → `ID`
- `https://youtu.be/ID` → `ID`
- `https://www.youtube.com/shorts/ID` → `ID`
- Anything else → STOP, output `Invalid YouTube URL`.

## Step 2 — Probe metadata via yt-dlp

```bash
yt-dlp --skip-download --dump-json --no-warnings "<URL>" > /tmp/yt-meta.json 2>/dev/null
```

(Use `--dump-json`, NOT `--print-json | head -1`. The latter breaks command-substitution in some shells; redirect of `--dump-json` is robust.)

Extract via jq:
- `.title`
- `.channel` (or `.uploader`)
- `.duration` (seconds)
- `.upload_date` (YYYYMMDD)
- `.subtitles` (object — keys are language codes for manual captions)
- `.automatic_captions` (object — keys are language codes for auto-generated)
- `.description` (first 500 chars only — for frontmatter)

If probe fails — STOP, output exact yt-dlp error.

## Step 3 — Choose subtitle source (try-and-verify, NOT just check keys)

**Critical:** YouTube `automatic_captions` keys list **all possible auto-translation targets**, but most are Google-Translate of the original auto-caption. yt-dlp does NOT download translations by default — only the original auto-caption language. So checking JSON keys is not sufficient — must attempt download and verify VTT file exists.

**Algorithm (loop fallback):**

```bash
SOURCE=""; LANG=""
for LANG_TRY in pl en; do          # priority langs from --lang flag
  for SRC_TRY in manual auto; do
    rm -f /tmp/yt-transcript-${VIDEO_ID}.* 2>/dev/null
    SUBS_FLAG=$([ "$SRC_TRY" = "manual" ] && echo "--write-subs" || echo "--write-auto-subs")
    yt-dlp --skip-download $SUBS_FLAG --sub-langs "$LANG_TRY" --sub-format vtt \
      --output "/tmp/yt-transcript-%(id)s.%(ext)s" --no-warnings "$URL" >/dev/null 2>&1
    if [ -s "/tmp/yt-transcript-${VIDEO_ID}.${LANG_TRY}.vtt" ]; then
      SOURCE="$SRC_TRY"; LANG="$LANG_TRY"
      break 2
    fi
  done
done

if [ -z "$SOURCE" ]; then
  echo "ERROR: No captions in $LANG_FLAG_LIST (manual or auto). Whisper fallback (--whisper) not yet implemented."
  exit 1
fi
```

This empirically tries each combination and accepts the first that produces a VTT file. Logs selected source: `manual:pl`, `auto:en`, etc.

## Step 4 — Download captions

If Step 3's loop succeeded, the VTT file is already at `/tmp/yt-transcript-${VIDEO_ID}.${LANG}.vtt`. No additional download needed — Step 3 left the file there as a side effect.

If you want to skip the loop and download directly (knowing source/lang):

```bash
SUBS_FLAG=$([ "$SOURCE" = "manual" ] && echo "--write-subs" || echo "--write-auto-subs")
yt-dlp --skip-download $SUBS_FLAG --sub-langs "$LANG" --sub-format vtt \
  --output "/tmp/yt-transcript-%(id)s.%(ext)s" --no-warnings "$URL" >/dev/null 2>&1
```

Verify file exists and is non-empty (>100 bytes).

## Step 5 — Convert VTT → clean text

Use sed/awk (NOT LLM):

```bash
VTT="/tmp/yt-transcript-<ID>.<lang>.vtt"
awk '
  /^WEBVTT|^Kind:|^Language:/ { next }
  /^[0-9]+$/ { next }
  /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]+ -->/ { next }
  /^[[:space:]]*$/ { next }     # skip blank lines, do NOT reset `last`
  {
    gsub(/<[^>]+>/, "", $0)     # strip inline HTML-like tags <c>, <00:00:00.000>
    if ($0 != last && $0 != "") {
      print $0
      last = $0
    }
  }
' "$VTT"
```

**Critical fix (v1.1):** the blank-line rule MUST be `next` (skip silently), NOT `print empty; reset last`. YouTube auto-captions emit each line 2-3 times with blank lines between (overlap effect). Resetting `last` on blank breaks dedupe — file ends up 3x larger. With `next`, `last` is preserved across blank lines, dedupe works correctly. Verified empirically: 27-min video came out as 15068 words with old logic, 5068 words with corrected logic.

**Token discipline:** never use shell-variable capture (`CLEAN=$(awk ...)`) for long content — variables that end up echo'd back can blow up context. Pipe directly to file via printf/redirect:

```bash
{
  printf -- "---\n..."   # frontmatter
  awk '...' "$VTT"        # body, streamed to file, NOT through LLM
} > "$OUTFILE"
```

## Step 6 — Generate filename

```bash
CHANNEL_SLUG=$(echo "$CHANNEL" | iconv -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | cut -c1-30)
TITLE_SLUG=$(echo "$TITLE"   | iconv -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | cut -c1-60)
DATE=$(echo "$UPLOAD_DATE" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')
OUTFILE="${OUTDIR}/${DATE}-${CHANNEL_SLUG}-${VIDEO_ID}-${TITLE_SLUG}.${FORMAT}"
```

Pattern: `{YYYY-MM-DD}-{channel-slug}-{video-id}-{title-slug}.{ext}` — all slug logic is in the snippet above, do not interpret it differently.

## Step 7 — Write output file

For `--format md` (default):

```markdown
---
title: "<title>"
channel: "<channel>"
video_id: <id>
url: <full url>
duration_seconds: <n>
duration_formatted: "<HH:MM:SS>"
upload_date: <YYYY-MM-DD>
language: <lang>
source: <manual|auto>
downloaded_at: <ISO8601 now>
yt_dlp_version: <version>
---

# <title>

**Channel:** <channel> · **Duration:** <HH:MM:SS> · **Uploaded:** <date>
**Source:** <auto/manual> captions in <lang>
**URL:** <url>

---

<clean transcript here>
```

For `--format txt`: just the clean text, no frontmatter.

For `--format vtt`: copy raw VTT file to output dir, no conversion.

If `--keep-raw`: also copy original VTT alongside.

## Step 8 — Optional summary (--summary flag)

ONLY if user passed `--summary`:

1. Read the just-written transcript file via Read tool (this loads it into context — note token cost)
2. Generate 5-7 bullet point summary in Polish
3. Append to file:
   ```markdown
   
   ---
   ## Podsumowanie (LLM-generated)
   
   - bullet 1
   - bullet 2
   ...
   ```

Skip this step if `--summary` not given. Default behavior is no LLM-generated content.

## Step 9 — Cleanup tmp files

```bash
rm -f /tmp/yt-transcript-<ID>.*
rm -f /tmp/yt-meta.json
```

Unless `--keep-raw` was used (then VTT is copied to output dir before cleanup).

## Step 10 — Terminal output

```
✓ Transcript saved
  Title:    <title>
  Channel:  <channel>
  Duration: <HH:MM:SS>
  Source:   <auto|manual> (<lang>)
  Length:   <N> words, <M> chars
  Output:   <path>

Preview (first 300 chars):
  <preview...>

Tokens used (orchestration only): ~<estimate>
```

</procedure>

<anti_rationalization>

| Rationalization | Block |
|---|---|
| "User probably wants a summary, I'll add one" | NO. Summary requires explicit `--summary` flag. Default = transcript only. |
| "I'll clean up grammar / punctuation while I'm at it" | NO. Output is verbatim from yt-dlp. Auto-captions have errors — that's their nature. Don't paraphrase. |
| "The transcript is in English, I'll translate to Polish" | NO. Only the captions language is preserved. Translation is a separate task. |
| "Let me read the transcript to verify it makes sense" | NO. Verification is character/word count + frontmatter validity. Reading the content into context = token waste. |
| "There's no captions, I'll run Whisper on the audio" | NO. Whisper fallback is `--whisper` flag (not implemented yet). Without flag, exit cleanly with message. |
| "User passed --summary but transcript is huge, I'll skip" | NO. If user explicitly asked, do it. Warn about token cost in terminal output but execute. |
| "I'll add timestamps in markdown for easier navigation" | NO. Default output is clean text without timestamps. `--format vtt` preserves them. |
| "Same video already downloaded, I'll skip" | NO. Each invocation produces a new file (idempotent re-runs OK). User decides whether to dedupe. |

</anti_rationalization>

<scope_boundaries>

## DO
- Probe metadata via yt-dlp
- Download VTT subtitles
- Convert VTT to clean markdown with frontmatter via sed/awk
- Write to ~/Desktop/transcripts/ (or --out path)
- Optionally append LLM summary IF --summary flag

## DON'T
- Download the video file or audio (that's a separate skill)
- Run Whisper on audio (separate flag, not implemented)
- Translate transcript to other language
- Paraphrase, clean up grammar, fix typos
- Generate summary, takeaways, action items WITHOUT --summary flag
- Echo the full transcript content to terminal (only preview ~300 chars)
- Read transcript file into LLM context unless --summary flag
- Modify yt-dlp config or system PATH

</scope_boundaries>

<definition_of_done>

The skill is DONE when, and only when, all of these are true:

1. Output file exists at the expected path
2. File size > 100 bytes (sanity check)
3. If `--format md`: YAML frontmatter parseable + contains required fields (title, channel, url, video_id, source)
4. Body contains transcript text (>50 words for any reasonable video)
5. /tmp temporary files cleaned up (unless --keep-raw)
6. Terminal output shows path + counts + preview
7. If `--summary` was passed: file contains "## Podsumowanie" section

If a check fails — report which check failed, do not pretend success.

</definition_of_done>

<example_invocations>

```
# Minimum — just transcript in default Polish/English
/yt-transcript https://youtu.be/dQw4w9WgXcQ

# Specific language preference
/yt-transcript https://youtu.be/dQw4w9WgXcQ --lang en

# With LLM summary appended
/yt-transcript https://youtu.be/dQw4w9WgXcQ --summary

# Plain text format, no frontmatter
/yt-transcript https://youtu.be/dQw4w9WgXcQ --format txt

# Keep raw VTT for archival
/yt-transcript https://youtu.be/dQw4w9WgXcQ --keep-raw

# Different output directory
/yt-transcript https://youtu.be/dQw4w9WgXcQ --out ~/Documents/yt
```

</example_invocations>
