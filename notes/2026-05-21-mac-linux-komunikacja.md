---
date: "2026-05-21 07:30"
promoted: false
---

# Komunikacja Mac ↔ Linux VM — sync notatek i dostęp zdalny

## Dane VM

- **IP publiczne:** `20.54.82.106`
- **User:** `Marcin` / hasło: `<HASLO_VM>`
- **Klucz SSH (Mac):** `~/.ssh/claude-vm_key.pem`
- **SSH:** `ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106`

---

## Synchronizacja notatek i skillek

### Repo

- **GitHub:** `git@github.com:kaczmarekbrief-wq/JobNote.git`
- **Mac:** `~/shared/` (git repo)
- **Linux:** `~/shared/` (git repo, symlinki `~/.claude/notes` i `~/.claude/skills`)

### Czas synchronizacji

- **Cron co 5 minut** na obu maszynach:
  ```
  */5 * * * * cd ~/shared && git pull --rebase -q; git add -A && git diff --cached --quiet || git commit -m "auto-sync" && git push -q
  ```
- **Worst case:** zmiana widoczna na drugiej maszynie po max **10 minut** (5 min push + 5 min pull)
- **Typowo:** ~1–5 minut jeśli crony nie trafią na siebie

### Wymuszony sync (natychmiastowy)

```bash
# Z Maca → push od razu
cd ~/shared && git add -A && git commit -m "manual sync" && git push

# Na Linux → pull od razu
ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106 "cd ~/shared && git pull"
```

### Struktura ~/shared/

```
~/shared/
  notes/              ← notatki (symlink ~/.claude/notes na Linux)
  plans/
  scripts/
  claude-config/
    skills/           ← 98 skillek (symlink ~/.claude/skills na Linux)
    commands/         ← 3 commands
  .env                ← tokeny lokalne (NIE w git, .gitignore)
  .env.example        ← szablon
  storage_state.json  ← NotebookLM auth (NIE w git, .gitignore)
```

---

## Dostęp zdalny do VM

### Metoda 1: SSH (terminal)

```bash
ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106
```

### Metoda 2: VNC (pulpit graficzny) — ORYGINALNA

VNC server działa na VM na `:1` (port 5901, tylko localhost).
Wymaga tunelu SSH:

```bash
# Krok 1: tunel (zostaw otwarte w tle)
ssh -i ~/.ssh/claude-vm_key.pem -L 5901:localhost:5901 -N Marcin@20.54.82.106

# Krok 2: połącz VNC klientem
# macOS Screen Sharing (Spotlight → "Screen Sharing"):
#   vnc://localhost:5901
# Hasło VNC: <HASLO_VM>
```

**Uwaga:** przy zmianie sieci (dom → praca) tunel się zamyka — trzeba go otworzyć ponownie.
**Uwaga:** `already in use` przy tworzeniu tunelu = tunel już działa z poprzedniej sesji.

### Metoda 3: RDP (Microsoft Remote Desktop)

xrdp działa na VM na porcie 3389, ale port jest zablokowany przez Azure NSG.
Wymaga tunelu SSH:

```bash
# Krok 1: tunel
ssh -i ~/.ssh/claude-vm_key.pem -L 3389:localhost:3389 -N Marcin@20.54.82.106

# Krok 2: Microsoft Remote Desktop → localhost:3389
# User: Marcin / hasło: <HASLO_VM>
```

xrdp jest skonfigurowany żeby podłączyć się do istniejącej sesji VNC (port 5901).

### Autostart przy restarcie VM

| Usługa | Status | Komenda restart |
|--------|--------|----------------|
| VNC (Xtigervnc :1) | ✅ autostart | `vncserver :1` |
| xrdp | ✅ enabled (systemd) | `sudo systemctl start xrdp` |
| Claude Code daemon | ✅ keepalive w tmux | `tmux attach -t main` |
| Hermes gateway | ✅ systemd user service | `hermes gateway start` |
| Git sync cron | ✅ crontab | automatyczny |

---

## Troubleshooting

### VNC nie działa po restarcie Maca

Tunel zamknięty — uruchom ponownie:
```bash
ssh -i ~/.ssh/claude-vm_key.pem -L 5901:localhost:5901 -N Marcin@20.54.82.106 &
```

### RDP "Unable to connect" (0x204)

Port 3389 zablokowany przez Azure — użyj tunelu (patrz wyżej).

### RDP "login failed for user Marcin"

Hasło nie ustawione lub wygasło:
```bash
ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106 "echo 'Marcin:<TWOJE_HASLO>' | sudo chpasswd"
```

### RDP "VNC password failed"

Reset hasła VNC:
```bash
ssh -i ~/.ssh/claude-vm_key.pem Marcin@20.54.82.106 "echo '<TWOJE_HASLO>' | vncpasswd -f > ~/.vnc/passwd"
```

### Notatki nie synchronizują się

Sprawdź cron:
```bash
crontab -l | grep shared          # Mac
ssh ... "crontab -l | grep shared" # Linux
```
