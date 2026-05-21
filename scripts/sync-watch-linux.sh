#!/bin/bash
SHARED="/home/Marcin/shared"
LOG="$SHARED/scripts/sync-linux.log"
echo "[$(date)] sync-watch-linux uruchomiony" >> "$LOG"
while true; do
    inotifywait -r -e modify,create,delete,move --exclude '\.git|sync-linux\.log' "$SHARED" -q 2>/dev/null
    sleep 1
    cd "$SHARED" || continue
    git pull --rebase -q 2>/dev/null
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m 'auto-sync linux [inotify]' -q
        git push -q && echo "[$(date)] pushed" >> "$LOG"
    fi
done
