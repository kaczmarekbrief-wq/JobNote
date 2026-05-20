# Reference — Dashboard Data Sources

## Źródła danych (skąd pochodzą liczby w panelach)

| Panel | Źródło | Endpoint |
|-------|--------|----------|
| Cache hit rate | `~/.claude/projects/**/*.jsonl` → `message.usage.cache_read_input_tokens` | `/api/stats` |
| Skill activations | `~/.claude/history.jsonl` → wpisy z `display` zaczynającym się od `/` | `/api/stats` |
| Token cost per skill | JOIN: history.jsonl (sessionId+skill) + session JSONL (usage) | `/api/stats` |
| MCP latency | Session JSONL: delta T2(tool_result) − T1(tool_use) grouped by `name` | `/api/stats` |
| Live sessions | `~/.claude/daemon/roster.json` | `/api/live` |
| Recent sessions | SQLite `sessions` table | `/api/sessions` |
| Task board | SQLite `ops_tasks` table | `/api/tasks` |
| Skills registry | SQLite `skills` table | `/api/skills` |
| Failed OTEL events | `~/.claude/telemetry/1p_failed_events.*.json` | `/api/stats` |

## Panele Mansela których może brakować danych

### Skill token cost (join JSONL)
Wymaga żeby `history.jsonl` miał wpisy z `sessionId` i `display=/skillname`.
Sprawdź: `grep '"display":"/' ~/.claude/history.jsonl | tail -5`

### MCP latency
Wymaga par tool_use → tool_result w tym samym JSONL z timestampami.
Sprawdź: `cat ~/.claude/projects/**/*.jsonl | python3 -c "import sys,json; [print(l) for l in sys.stdin if 'tool_use' in l]" | head -3`

### Live sessions
Wymaga żeby `~/.claude/daemon/roster.json` istniał i był aktualny.
Sprawdź: `cat ~/.claude/daemon/roster.json 2>/dev/null || echo "brak"`

### Posture panels (Security + Context)
NIE są zasilane OTEL/JSONL — to outputy skilli (`security-audit`, `context-audit`) które trzeba ręcznie uruchomić. Mansel miał te skille w swoim środowisku. U nas tych skilli nie ma.

## Playwright troubleshooting

```bash
# Sprawdź Node version (musi być 20+)
. ~/.nvm/nvm.sh && nvm use 20 && node --version

# Sprawdź czy Playwright jest zainstalowany
node -e "require('/Users/marcinszostak/AI_REMOTE/tele/ui/node_modules/playwright-core'); console.log('OK')"

# Ręczny test screenshota
. ~/.nvm/nvm.sh && nvm use 20 --silent && node ~/.claude/skills/inspect-dashboard/scripts/tour.js
```
