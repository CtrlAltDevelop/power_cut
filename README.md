# power_cut

A hard-to-ignore pop-up appears on your computer a few minutes before each
scheduled power switch-over, so you can save your work and shut down in time.

Built entirely on tools that ship with the operating system — launchd on macOS,
Task Scheduler on Windows. Nothing to buy, nothing to install, no background
app running.

## Layout

```
mac/      install-mac-reminders.sh   the installer (also does status/test/pause/remove)
          power-cut-menu.command     double-click menu wrapping the installer

windows/  power-reminder.ps1         the installer (also does status/test/pause/remove)
          power-cut-menu.cmd         double-click menu wrapping the installer

power-cut-guide.md      full guide (English)
power-cut-guide.fa.md   full guide (Persian / فارسی)
```

Each launcher finds its own installer in the same folder, so keep the pairs
together.

## Quick start

No typing required — double-click the menu for your platform:

- **macOS:** `mac/power-cut-menu.command` (first time: right-click → **Open**)
- **Windows:** `windows/power-cut-menu.cmd`

The menu shows the current status and can install, test, pause, resume, and
remove everything.

From the command line instead:

```bash
# macOS — default times 10:00 and 12:00, warning 2 minutes before
bash mac/install-mac-reminders.sh
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File C:\Tools\power-reminder.ps1 -Install
```

You enter the **real power times**; the scripts work out the warning time
themselves.

## Good to know

- **Set it up once.** It survives restarts, sleep, log-outs, and power cuts,
  until you explicitly pause or remove it.
- **It fires every day**, at the times you give it.
- **No late warnings.** If the machine was off at 09:58 and you switch it on at
  11:00, the warning for a cut that already happened is skipped.
- **Nothing is left behind.** `uninstall` / `-Uninstall` removes everything the
  installer created, and no reboot is needed.

Full instructions, your own times, pausing, and troubleshooting are in
[power-cut-guide.md](power-cut-guide.md) — or in Persian,
[power-cut-guide.fa.md](power-cut-guide.fa.md).

## License

MIT — see [LICENSE](LICENSE).
