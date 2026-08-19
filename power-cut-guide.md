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

## Do I have to set this up again after a reboot?

**No — you set it up once and it keeps working.**

- **macOS** stores it as a Launch Agent in `~/Library/LaunchAgents`, which macOS
  loads automatically every time you log in.
- **Windows** stores it as a Scheduled Task, which Windows keeps in its own
  database.

So it survives shutdowns, restarts, sleep, log-outs, and power cuts — for as
long as you want, until you explicitly pause or remove it. You never need to
re-run the installer unless the office power times change.

Two things it deliberately does **not** do:

- It does not fire a **late** warning. If the computer was off or asleep at
  09:58 and you switch it on at 11:00, you do not get a "power cut in 2 minutes"
  pop-up for a cut that already happened — the warning is skipped.
- It does not run while nobody is logged in, because there would be no screen to
  show the pop-up on.

---

## Easiest way: the double-click menu

If you would rather not type commands, use the menu — it can set up, test,
pause, resume, and remove everything:

- **macOS:** double-click **`power-cut-menu.command`** in Finder
  (keep it in the same folder as `install-mac-reminders.sh`)
- **Windows:** double-click **`power-cut-menu.cmd`**
  (keep it in the same folder as `power-reminder.ps1`)

The menu shows the current status at the top, so you can always see whether the
reminders are active, paused, or not installed.

macOS may refuse to open a downloaded `.command` file the first time —
right-click it and choose **Open**, then **Open** again to confirm.

The rest of this guide is the same thing done from the command line.

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

### Check, pause, and remove

```bash
# What is installed right now, and is it active?
bash ~/Downloads/install-mac-reminders.sh status

# Cancel temporarily — keeps the setup, stays off across reboots
bash ~/Downloads/install-mac-reminders.sh disable

# Switch back on
bash ~/Downloads/install-mac-reminders.sh enable

# Remove completely
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

### Check, pause, and remove

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Status
```

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Disable
```

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Enable
```

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Uninstall
```

`-Disable` keeps the tasks but stops them running, and stays off after a reboot.
`-Uninstall` deletes them.

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
| Status | `status` | `-Status` |
| Test pop-up | `test` | `-Test` |
| Pause / resume | `disable` / `enable` | `-Disable` / `-Enable` |
| Remove | `uninstall` | `-Uninstall` |
| Survives reboot | yes | yes |

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

**I paused it and now nothing happens.**
That is expected — `status` / `-Status` shows **PAUSED**. Run `enable` /
`-Enable` to switch it back on.

**I want it gone for good.**
`uninstall` / `-Uninstall` removes everything the installer created; nothing is
left behind and no reboot is needed.
