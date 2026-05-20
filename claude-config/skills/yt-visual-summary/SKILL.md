---
name: yt-visual-summary
description: "Downloads a YouTube video transcript + extracts key frames at moments where something is shown on screen. Produces a folder with summary.md (text + embedded screenshots) and frames/ directory. Token-efficient: transcript is free, video download only if visual cues found, LLM sees only 2-6 key frames. Use when user wants a rich summary of a tutorial, demo, or presentation where visuals matter."
argument-hint: "<url> [--lang pl,en] [--out <dir>] [--max-frames N]"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

<objective>
Produce a rich summary of a YouTube video combining:
- Full transcript text (what was said)
- Key screenshot frames (what was shown on screen)

Output: a folder containing summary.md with embedded frame references + frames/ subdirectory.

Token strategy:
- Transcript download: 0 tokens (yt-dlp + awk)
- Visual cue detection: ~1 000 tokens (LLM reads timestamped transcript)
- Frame extraction: 0 tokens (ffmpeg)
- Frame analysis + summary: ~3 000–6 000 tokens (LLM reads 2-6 frames)
- Total: ~5 000–8 000 tokens regardless of video length
</objective>

<inputs>

**Required:**
- `url` — YouTube URL (full, youtu.be, shorts)

**Optional:**
- `--lang pl,en` — caption language preference. Default: pl,en
- `--out <dir>` — output base dir. Default: `~/Desktop/transcripts/`
- `--max-frames N` — cap on frames to extract. Default: 6

</inputs>

<procedure>

## Step 1 — Parse URL and validate

Extract video ID from URL pattern. If invalid → STOP with usage message.

## Step 2 — Probe metadata

```bash
yt-dlp --skip-download --dump-json --no-warnings "<URL>" > /tmp/yt-vs-meta.json 2>/dev/null
```

Extract: title, channel, duration, upload_date. If fails → STOP with error.

## Step 3 — Download VTT (with timestamps preserved)

Try pl then en, manual then auto (same loop as yt-transcript):

```bash
VIDEO_ID="..."
for LANG_TRY in pl en; do
  for SRC_TRY in manual auto; do
    rm -f /tmp/yt-vs-${VIDEO_ID}.* 2>/dev/null
    SUBS_FLAG=$([ "$SRC_TRY" = "manual" ] && echo "--write-subs" || echo "--write-auto-subs")
    yt-dlp --skip-download $SUBS_FLAG --sub-langs "$LANG_TRY" --sub-format vtt \
      --output "/tmp/yt-vs-%(id)s.%(ext)s" --no-warnings "$URL" >/dev/null 2>&1
    if [ -s "/tmp/yt-vs-${VIDEO_ID}.${LANG_TRY}.vtt" ]; then
      SOURCE="$SRC_TRY"; LANG="$LANG_TRY"; break 2
    fi
  done
done
[ -z "$SOURCE" ] && echo "ERROR: no captions found" && exit 1
```

## Step 4 — Parse VTT → timestamped transcript (zero tokens)

Extract lines with their start timestamps using Python:

```bash
python3 << 'EOF'
import re, sys

vtt = open(f"/tmp/yt-vs-{VIDEO_ID}.{LANG}.vtt").read()
blocks = re.split(r'\n\n+', vtt)
lines = []
last = ""

for block in blocks:
    rows = block.strip().split('\n')
    ts_row = next((r for r in rows if '-->' in r), None)
    if not ts_row:
        continue
    start = ts_row.split('-->')[0].strip()
    # Convert HH:MM:SS.mmm → total seconds
    parts = start.replace(',', '.').split(':')
    secs = int(parts[-3])*3600 + int(parts[-2])*60 + float(parts[-1]) if len(parts)==3 else int(parts[-2])*60 + float(parts[-1])
    m, s = divmod(int(secs), 60)
    ts = f"{m}:{s:02d}"
    for row in rows:
        if '-->' in row or re.match(r'^\d+$', row) or row.startswith('WEBVTT') or not row.strip():
            continue
        text = re.sub(r'<[^>]+>', '', row).strip()
        if text and text != last:
            print(f"[{ts}] {text}")
            last = text
EOF
```

Save to `/tmp/yt-vs-timestamped.txt`.

## Step 5 — LLM: identify visual cue timestamps

Read `/tmp/yt-vs-timestamped.txt` via Read tool.

Scan for phrases that indicate something is being shown on screen:
- "here you can see", "as you can see", "look at this", "on screen"
- "on the left/right", "I'll show you", "here's what", "notice that"
- "this is what", "take a look", "you'll see", "here we have"
- Transitions to demo/screenshare context

For each match, note the timestamp. Output a JSON list:

```json
[
  {"ts": "0:38", "reason": "author says 'here you can see the setup'"},
  {"ts": "1:12", "reason": "transition to diagram shown on screen"},
  {"ts": "2:45", "reason": "'on the right side you'll notice'"}
]
```

Cap at `--max-frames` (default 6). If no visual cues found → produce text-only summary (skip Steps 6-7, go to Step 8 with transcript only).

## Step 6 — Download video (only if visual cues found)

```bash
yt-dlp "<URL>" \
  -f "bestvideo[height<=480]+bestaudio/best[height<=480]" \
  -o "/tmp/yt-vs-${VIDEO_ID}-video.mp4" \
  --no-warnings 2>&1 | tail -2
```

Use 480p max — sufficient for screen content, smaller file.

## Step 7 — Extract frames at identified timestamps (zero tokens)

```bash
OUTFRAMES="/tmp/yt-vs-${VIDEO_ID}-frames"
mkdir -p "$OUTFRAMES"

# For each timestamp from Step 5, add +2s offset:
# Visual cue phrases are spoken ~1-2s before the screen content appears
# (author says "here you can see" → camera cuts to screen ≈ 2 seconds later)
for TS in "0:38" "1:12" "2:45"; do
  SLUG=$(echo "$TS" | tr ':' 'm')s
  # Convert MM:SS → total seconds, add 2, convert back to HH:MM:SS for ffmpeg
  TOTAL_SECS=$(echo "$TS" | awk -F: '{ print ($1 * 60) + $2 + 2 }')
  FFMPEG_TS=$(printf "%02d:%02d:%02d" $((TOTAL_SECS/3600)) $((TOTAL_SECS%3600/60)) $((TOTAL_SECS%60)))
  ffmpeg -i "/tmp/yt-vs-${VIDEO_ID}-video.mp4" \
    -ss "$FFMPEG_TS" -frames:v 1 \
    -vf "scale=480:-1" \
    "$OUTFRAMES/frame_${SLUG}.jpg" \
    -loglevel error
done

echo "Frames: $(ls $OUTFRAMES/*.jpg | wc -l)"
```

## Step 8 — Generate output folder and files

```bash
# Slug generation
CHANNEL_SLUG=$(echo "$CHANNEL" | iconv -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | cut -c1-25)
TITLE_SLUG=$(echo "$TITLE" | iconv -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | cut -c1-50)
DATE=$(echo "$UPLOAD_DATE" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')

OUTDIR="${BASE_OUTDIR}/${DATE}-${CHANNEL_SLUG}-${VIDEO_ID}-${TITLE_SLUG}"
mkdir -p "$OUTDIR/frames"

# Copy frames to output folder
cp "$OUTFRAMES"/*.jpg "$OUTDIR/frames/" 2>/dev/null
```

## Step 9 — LLM: read transcript + frames, write summary.md

Read the timestamped transcript + each frame image via Read tool.

Write `$OUTDIR/summary.md` using Write tool:

```markdown
---
title: "<title>"
channel: "<channel>"
video_id: <id>
url: <url>
duration_formatted: "<HH:MM:SS>"
upload_date: <date>
language: <lang>
generated_at: <ISO8601>
frames_count: <N>
---

# <title>

**Channel:** <channel> · **Duration:** <HH:MM:SS> · **Uploaded:** <date>
**URL:** <url>

---

## Podsumowanie

<3-6 bullet points covering the main message of the video>

---

## Kluczowe momenty wizualne

### [MM:SS] <short title of what's shown>

![](./frames/frame_<slug>.jpg)

<2-3 sentences: what's being said + what's visible on screen at this moment>

---

### [MM:SS] <next moment>

![](./frames/frame_<slug>.jpg)

<description>

---

## Pełny transkrypt

<clean transcript text without timestamps>
```

## Step 10 — Cleanup tmp files

```bash
rm -f /tmp/yt-vs-${VIDEO_ID}.*
rm -f /tmp/yt-vs-timestamped.txt
rm -rf /tmp/yt-vs-${VIDEO_ID}-frames
# Keep video? No — large file, frames already copied
rm -f /tmp/yt-vs-${VIDEO_ID}-video.mp4
```

## Step 11 — Terminal output

```
✓ Visual summary saved
  Title:    <title>
  Channel:  <channel>
  Duration: <HH:MM:SS>
  Frames:   <N> key moments extracted
  Output:   <outdir>/
              summary.md
              frames/ (<N> files)

Open in Obsidian: obsidian://open?path=<outdir>/summary.md
```

</procedure>

<anti_rationalization>

| Rationalization | Block |
|---|---|
| "No visual cues in transcript, I'll extract frames anyway" | NO. If no visual cue phrases found → text-only summary, skip video download entirely. |
| "I'll download 1080p for better quality" | NO. 480p max — sufficient for screen content, much smaller file. |
| "Let me extract frames every 30 seconds to be safe" | NO. Only timestamps identified from transcript. That's the whole point. |
| "I'll read the full transcript into context for accuracy" | NO. Read timestamped version only for cue detection, then use it in Step 9 combined read. |
| "User didn't say --max-frames so I'll extract all cues" | NO. Default cap is 6 frames. Beyond that, prioritize the most visually descriptive cues. |
| "The video is short, I'll download it before checking for cues" | NO. Always check transcript for visual cues first. Download only if cues found. |

</anti_rationalization>

<definition_of_done>

- Output folder exists with summary.md and frames/ subdirectory
- summary.md has valid YAML frontmatter
- summary.md contains ## Podsumowanie section
- summary.md contains ## Kluczowe momenty wizualne section (or note "no visual moments found" if text-only)
- Each frame referenced in summary.md exists in frames/
- Tmp files cleaned up
- Terminal output shows path + frame count

</definition_of_done>

<example_invocations>

```bash
# Standard — transcript + key frames
/yt-visual-summary https://youtu.be/dQw4w9WgXcQ

# Polish captions preferred
/yt-visual-summary https://youtu.be/dQw4w9WgXcQ --lang pl,en

# Limit frames to 3
/yt-visual-summary https://youtu.be/dQw4w9WgXcQ --max-frames 3

# Custom output dir
/yt-visual-summary https://youtu.be/dQw4w9WgXcQ --out ~/Documents/research
```

</example_invocations>
