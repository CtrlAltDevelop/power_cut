<#
.SYNOPSIS
    Automatic pop-up warning a few minutes before each scheduled power event.

.DESCRIPTION
    One script does everything: it installs the Scheduled Tasks, and it is also
    what those tasks run to show the warning. The scheduled time is calculated
    from the event time minus the lead time, so you only enter the real power
    times.

.EXAMPLE
    # Install with the office defaults (10:00 and 12:00, warn 2 minutes before)
    powershell -ExecutionPolicy Bypass -File power-reminder.ps1 -Install

.EXAMPLE
    # Install with your own times, warning 5 minutes before each
    powershell -ExecutionPolicy Bypass -File power-reminder.ps1 -Install -Times 10:00,12:00,16:30 -Lead 5

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File power-reminder.ps1 -Status
    powershell -ExecutionPolicy Bypass -File power-reminder.ps1 -Test

.EXAMPLE
    # Cancel temporarily, then switch back on
    powershell -ExecutionPolicy Bypass -File power-reminder.ps1 -Disable
    powershell -ExecutionPolicy Bypass -File power-reminder.ps1 -Enable

.EXAMPLE
    # Remove completely
    powershell -ExecutionPolicy Bypass -File power-reminder.ps1 -Uninstall

.NOTES
    Installing once is enough. Scheduled Tasks are stored by Windows itself, so
    the reminders come back after every shutdown, reboot, and login until you
    disable or uninstall them.
#>

[CmdletBinding(DefaultParameterSetName = 'Show')]
param(
    [Parameter(ParameterSetName = 'Install')]  [switch] $Install,
    [Parameter(ParameterSetName = 'Uninstall')][switch] $Uninstall,
    [Parameter(ParameterSetName = 'Status')]   [switch] $Status,
    [Parameter(ParameterSetName = 'Test')]     [switch] $Test,
    [Parameter(ParameterSetName = 'Disable')]  [switch] $Disable,
    [Parameter(ParameterSetName = 'Enable')]   [switch] $Enable,

    # Real power-event times, 24-hour HH:MM. Any number of them.
    [Parameter(ParameterSetName = 'Install')]
    [Parameter(ParameterSetName = 'Test')]
    [string[]] $Times = @('10:00', '12:00'),

    # How many minutes before the event the pop-up appears.
    [Parameter(ParameterSetName = 'Install')]
    [Parameter(ParameterSetName = 'Test')]
    [Parameter(ParameterSetName = 'Show')]
    [ValidateRange(1, 120)]
    [int] $Lead = 2,

    # Used by the scheduled task itself: the event time to warn about.
    [Parameter(ParameterSetName = 'Show')]
    [string] $CutTime = '10:00'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$TaskFolder        = '\PowerCut'
$TaskPrefix        = 'PowerCut'
$GeneratorSeconds  = 20

function Parse-EventTime {
    param([Parameter(Mandatory)][string] $Text)

    $formats = @('HH:mm', 'H:mm', 'h:mm tt', 'hh:mm tt')
    $parsed  = [datetime]::MinValue
    $ok = [datetime]::TryParseExact(
        $Text.Trim(), $formats,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref] $parsed)
    if (-not $ok) {
        throw "Bad time '$Text'. Use a 24-hour clock, e.g. 09:30 or 16:00."
    }
    # Anchor on today so the value is a usable schedule time, not year 0001.
    return [datetime]::Today.AddHours($parsed.Hour).AddMinutes($parsed.Minute)
}

function Format-Clock {
    param([Parameter(Mandatory)][datetime] $Time)
    return $Time.ToString('h:mm tt', [System.Globalization.CultureInfo]::InvariantCulture)
}

# ---------------------------------------------------------------- the warning

function Show-Warning {
    param(
        [Parameter(Mandatory)][datetime] $EventTime,
        [int] $LeadMinutes,
        # -Force shows the warning regardless of the clock (used by -Test).
        [switch] $Force
    )

    # A task Windows held back while the PC was off or asleep must not pop up
    # hours late for a cut that has already happened.
    if (-not $Force) {
        $minutesLeft = [int][math]::Round(($EventTime - (Get-Date)).TotalMinutes)
        if ($minutesLeft -lt -1 -or $minutesLeft -gt ($LeadMinutes + 3)) {
            Write-Verbose "Skipped: $minutesLeft min from the $(Format-Clock $EventTime) event."
            return
        }
    }

    $clock = Format-Clock $EventTime
    $body  = @"
Power switch-over at $clock - about $GeneratorSeconds seconds without power.

1. Save all your work now (Ctrl+S)
2. Stop anything mid-task (copies, exports, builds, Windows Update)
3. Shut down or hibernate this PC if it has no UPS
"@

    # Alert sound, repeated so it is hard to miss.
    for ($i = 0; $i -lt 3; $i++) {
        [System.Media.SystemSounds]::Exclamation.Play()
        Start-Sleep -Milliseconds 600
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # An invisible owner form is what forces the box to stay on top of
    # whatever the user is working in.
    $owner = New-Object System.Windows.Forms.Form
    try {
        $owner.TopMost       = $true
        $owner.ShowInTaskbar = $false
        $owner.Opacity       = 0
        $owner.Show()

        [System.Windows.Forms.MessageBox]::Show(
            $owner,
            $body,
            "!! POWER CUT in $LeadMinutes min ($clock) !!",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button1,
            [System.Windows.Forms.MessageBoxOptions]::DefaultDesktopOnly
        ) | Out-Null
    }
    finally {
        $owner.Close()
        $owner.Dispose()
    }
}

# ------------------------------------------------------------------- install

function Get-PowerCutTasks {
    Get-ScheduledTask -TaskPath "$TaskFolder\" -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -like "$TaskPrefix*" }
}

function Remove-PowerCutTasks {
    $tasks = @(Get-PowerCutTasks)
    if ($tasks.Count -eq 0) { return 0 }
    foreach ($t in $tasks) {
        Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false
    }
    return $tasks.Count
}

function Install-Reminders {
    param([Parameter(Mandatory)][datetime[]] $EventTimes, [int] $LeadMinutes)

    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { throw 'Cannot determine this script''s path; run it from a saved .ps1 file.' }

    $removed = Remove-PowerCutTasks
    if ($removed -gt 0) { Write-Host "  replaced $removed existing task(s)" }

    foreach ($evt in $EventTimes) {
        $warnAt = $evt.AddMinutes(-$LeadMinutes)
        if ($warnAt.Date -ne $evt.Date) {
            throw "$(Format-Clock $evt) minus $LeadMinutes min falls on the previous day. Pick a later time or a smaller -Lead."
        }

        $taskName = "$TaskPrefix-$($evt.ToString('HHmm'))"
        $argument = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -CutTime "{1}" -Lead {2}' -f
                    $scriptPath, $evt.ToString('HH:mm'), $LeadMinutes

        $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
        $trigger = New-ScheduledTaskTrigger -Daily -At $warnAt
        # Interactive: the pop-up must appear on the logged-on user's desktop.
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
        # No -StartWhenAvailable: a missed warning is stale, not useful. The
        # task itself double-checks the clock anyway.
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
                       -DontStopIfGoingOnBatteries `
                       -MultipleInstances IgnoreNew `
                       -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

        Register-ScheduledTask -TaskName $taskName -TaskPath $TaskFolder `
            -Action $action -Trigger $trigger -Principal $principal `
            -Settings $settings -Force | Out-Null

        Write-Host ("  installed: {0,-18} warns at {1} for the {2} event (every day)" -f
                    $taskName, (Format-Clock $warnAt), (Format-Clock $evt))
    }
}

# ---------------------------------------------------------------------- main

switch ($PSCmdlet.ParameterSetName) {

    'Install' {
        $events = @($Times | ForEach-Object { Parse-EventTime $_ })
        Write-Host "Installing power-cut reminders ($Lead min before each event)..."
        Install-Reminders -EventTimes $events -LeadMinutes $Lead
        Write-Host ''
        Write-Host 'Test the pop-up right now with:'
        Write-Host ("  powershell -ExecutionPolicy Bypass -File `"{0}`" -Test" -f $PSCommandPath)
        Write-Host ''
        Write-Host 'This is a one-time setup: the reminders survive shutdowns and reboots.'
        Write-Host '  pause:   -Disable      resume:  -Enable      remove:  -Uninstall'
    }

    'Disable' {
        # Disabled tasks stay registered and stay disabled across reboots.
        $tasks = @(Get-PowerCutTasks)
        if ($tasks.Count -eq 0) {
            Write-Host '  nothing installed to pause'
        } else {
            foreach ($t in $tasks) {
                Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath | Out-Null
                Write-Host "  paused: $($t.TaskName)"
            }
            Write-Host 'Reminders are off (including after a reboot).'
            Write-Host ("Turn them back on with:  powershell -ExecutionPolicy Bypass -File `"{0}`" -Enable" -f $PSCommandPath)
        }
    }

    'Enable' {
        $tasks = @(Get-PowerCutTasks)
        if ($tasks.Count -eq 0) {
            Write-Host '  nothing installed - run -Install first'
        } else {
            foreach ($t in $tasks) {
                Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath | Out-Null
                Write-Host "  resumed: $($t.TaskName)"
            }
        }
    }

    'Uninstall' {
        Write-Host 'Removing power-cut reminders...'
        $n = Remove-PowerCutTasks
        if ($n -gt 0) { Write-Host "  removed $n task(s)" } else { Write-Host '  nothing to remove' }
        Write-Host 'Done.'
    }

    'Status' {
        $tasks = @(Get-PowerCutTasks)
        if ($tasks.Count -eq 0) {
            Write-Host '  no reminders installed'
        } else {
            foreach ($t in $tasks) {
                $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath
                $state = if ($t.State -eq 'Disabled') { 'PAUSED' } else { "$($t.State)" }
                Write-Host ("  {0,-18} {1,-8} next run {2}" -f $t.TaskName, $state, $info.NextRunTime)
            }
        }
    }

    'Test' {
        $evt = Parse-EventTime $Times[0]
        Write-Host "Showing a test warning for the $(Format-Clock $evt) event..."
        Show-Warning -EventTime $evt -LeadMinutes $Lead -Force
    }

    # No switch given: this is how the scheduled task invokes the script.
    'Show' {
        Show-Warning -EventTime (Parse-EventTime $CutTime) -LeadMinutes $Lead
    }
}
