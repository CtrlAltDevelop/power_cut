# Power Cut Pop-Up Warning — Setup Guide (Level 2)

An automatic, hard-to-ignore pop-up appears on your computer a few minutes
before each scheduled power switch-over, so you can save and shut down in time.
Uses only built-in tools — nothing to buy, nothing to install.

**Office power schedule (Mon–Fri):**

| Time | What happens | Gap without power |
|---|---|---|
| 10:00 AM | Mains goes off, generator starts | ~20 seconds |
| 12:00 PM | Mains returns, generator switches off | a few seconds |

You enter the **real power times**; the scripts calculate the warning time
themselves (2 minutes earlier by default).

---

## macOS

1. Download `install-mac-reminders.sh`
2. Open **Terminal** and run:

   ```bash
   bash ~/Downloads/install-mac-reminders.sh
   ```

3. Test the pop-up immediately:

   ```bash
   bash ~/Downloads/install-mac-reminders.sh test
   ```

   A red critical alert with sound should appear. Click **Allow** if macOS asks
   for permission the first time.

### Your own times

```bash
# Any number of times, 24-hour clock
bash ~/Downloads/install-mac-reminders.sh 10:00 12:00 16:30

# Warn 5 minutes before instead of 2
bash ~/Downloads/install-mac-reminders.sh --lead 5 10:00 12:00
```

Re-running the installer replaces the previous set — it never leaves old
reminders behind.

### Check and remove

```bash
bash ~/Downloads/install-mac-reminders.sh status
bash ~/Downloads/install-mac-reminders.sh uninstall
```

---

## Windows

1. Copy `power-reminder.ps1` to `C:\Tools\power-reminder.ps1`
2. Open **PowerShell** (a normal window is enough — no Administrator needed)
   and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Install
   ```

3. Test the pop-up immediately:

   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Test
   ```

### Your own times

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Install -Times 10:00,12:00,16:30

powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Install -Lead 5
```

Re-running `-Install` replaces the previous set of tasks.

### Check and remove

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Status
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Uninstall
```

The tasks are created in Task Scheduler under the **PowerCut** folder, named
`PowerCut-1000`, `PowerCut-1200`, and so on, if you prefer to inspect or edit
them by hand.

---

## Options (both platforms)

| What | macOS | Windows |
|---|---|---|
| Power event times | positional args, e.g. `10:00 12:00` | `-Times 10:00,12:00` |
| Minutes of warning | `--lead 5` | `-Lead 5` |
| Default | `10:00 12:00`, lead 2 | `10:00,12:00`, lead 2 |
| Days | Mon–Fri | Mon–Fri |

---

## Troubleshooting

**The pop-up never appeared.**
Run the `test` / `-Test` command. If the test works but the scheduled one does
not, the computer was asleep or logged out at that moment — the warning only
shows while you are logged in. On macOS check `status`; on Windows check
`-Status` and look at **next run**.

**No sound.**
Check the system volume and that Do Not Disturb / Focus is off. On macOS the
alert still appears silently; on Windows the pop-up is unaffected.

**macOS says the alert needs permission.**
Click **Allow** the first time. If you dismissed it, enable notifications for
**Script Editor** (or **Terminal**) in *System Settings → Notifications*.

**Windows: "running scripts is disabled on this system".**
Use the exact commands above — the `-ExecutionPolicy Bypass` part is what
allows it, and it applies only to that one run.

**I changed the office power schedule.**
Just re-run the installer with the new times; it replaces the old reminders.
