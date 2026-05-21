#!/bin/bash
# fswatch watcher — Mac → GitHub push przy każdej zmianie w ~/shared/
# Uruchom raz: bash ~/shared/scripts/sync-watch-mac.sh &

SHARED="$HOME/shared"
LOG="$HOME/shared/scripts/sync-mac.log"

echo "[$(date)] sync-watch-mac uruchomiony" >> "$LOG"

/opt/homebrew/bin/fswatch -o --exclude='\.git' --exclude='sync-mac\.log' "$SHARED" | while read -r count; do
    cd "$SHARED" || continue
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "auto-sync mac [fswatch]" -q
        git push -q && echo "[$(date)] pushed" >> "$LOG"
    fi
    git pull --rebase -q 2>/dev/null
done
