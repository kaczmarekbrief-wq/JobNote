#!/usr/bin/env python3
"""
Deterministic verifier for /yt-transcript output.
Checks all criteria from SKILL.md <definition_of_done>.

Usage:
    python3 verify.py <output-file-path>

Exit codes:
    0 = PASS
    1 = FAIL
"""

import sys
import os
import re

MIN_BYTES = 100
MIN_WORDS = 50
REQUIRED_FRONTMATTER_FIELDS = ["title", "channel", "url", "video_id", "source"]


def fail(reason):
    print(f"FAIL  {reason}")
    sys.exit(1)


def check(path):
    # 1. File exists
    if not path:
        fail("No output path provided")
    if not os.path.exists(path):
        fail(f"Output file not found: {path}")

    # 2. File size > MIN_BYTES
    size = os.path.getsize(path)
    if size < MIN_BYTES:
        fail(f"File too small: {size} bytes (minimum {MIN_BYTES})")

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # 3. YAML frontmatter present and parseable
    if not content.startswith("---"):
        fail("Missing YAML frontmatter (file must start with ---)")

    parts = content.split("---", 2)
    if len(parts) < 3:
        fail("Malformed frontmatter: missing closing ---")

    frontmatter_raw = parts[1]
    body = parts[2]

    # 4. Required frontmatter fields present and non-empty
    missing = []
    for field in REQUIRED_FRONTMATTER_FIELDS:
        pattern = rf"^{field}\s*:\s*(.+)$"
        match = re.search(pattern, frontmatter_raw, re.MULTILINE)
        if not match or not match.group(1).strip().strip('"').strip("'"):
            missing.append(field)
    if missing:
        fail(f"Frontmatter missing or empty fields: {', '.join(missing)}")

    # 5. Body contains enough words
    word_count = len(body.split())
    if word_count < MIN_WORDS:
        fail(f"Body too short: {word_count} words (minimum {MIN_WORDS})")

    # All checks passed
    print(f"PASS")
    print(f"  File:   {path}")
    print(f"  Size:   {size} bytes")
    print(f"  Words:  {word_count}")
    frontmatter_fields_found = [f for f in REQUIRED_FRONTMATTER_FIELDS
                                if re.search(rf"^{f}\s*:", frontmatter_raw, re.MULTILINE)]
    print(f"  Fields: {', '.join(frontmatter_fields_found)}")
    sys.exit(0)


if __name__ == "__main__":
    output_path = sys.argv[1] if len(sys.argv) > 1 else ""
    check(output_path)
