---
name: inspect-dashboard
description: Opens the Command Centre dashboard (localhost:7373) in a headed Playwright browser, navigates all pages, takes screenshots, and reports which panels have real data vs are empty or missing. Use when you want to audit the dashboard, debug missing data, see what the user sees on screen, or compare current state with Mansel Scheffel's reference implementation.
---

# Inspect Dashboard

Tours the Command Centre dashboard visually using Playwright. Browser opens on screen so the user can watch. Screenshots are read back by Claude to produce a panel-by-panel audit.

## Quick start

```bash
# 1. Ensure server is running
curl -s http://localhost:7373/api/tasks | python3 -c "import sys,json; print('OK tasks:', len(json.load(sys.stdin).get('tasks',[])))"

# 2. Run the tour script (Node 20 required)
. ~/.nvm/nvm.sh && nvm use 20 --silent && node ~/.claude/skills/inspect-dashboard/scripts/tour.js
```

Then read each screenshot with the Read tool and report findings.

## Workflow

- [ ] Check server is up at localhost:7373
- [ ] Run `tour.js` — browser opens headed, navigates Command → Activity → Skills
- [ ] Screenshots land in `/tmp/dashboard-tour/`
- [ ] Read each PNG with Read tool (Claude is multimodal)
- [ ] For each panel: ✅ has data | ⚠️ empty/zeros | ❌ missing entirely
- [ ] Compare against Mansel's panels (see Reference below)

## Reading screenshots

Use the Read tool on PNG files — Claude sees the image directly:
```
Read /tmp/dashboard-tour/01-command.png
Read /tmp/dashboard-tour/02-activity.png
Read /tmp/dashboard-tour/03-skills.png
```

## Mansel's panels (reference checklist)

- [ ] Cache hit rate (should be >70%)
- [ ] Token usage by model
- [ ] MCP latency + error rate per tool
- [ ] Skill activations last 24h
- [ ] Skill token cost per run (join history.jsonl + session JSONL)
- [ ] Recent sessions (ID, model, duration)
- [ ] Live sessions (roster.json)
- [ ] Skills registry (all skills with descriptions)
- [ ] Posture: Security audit report
- [ ] Posture: Context efficiency report

See [REFERENCE.md](REFERENCE.md) for data source details.
