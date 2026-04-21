# 1. ELEVATION CHECK
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    return
}

# 2. CONFIGURATION & CLEANUP
$taskName = "AutoRemoteNotify"
$dir = "C:\RemoteAdmin"
Write-Host "Cleaning up and prepping environment..." -ForegroundColor Cyan

Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
if (Test-Path "C:\Windows\notify.bat") { Remove-Item -Force "C:\Windows\notify.bat" }

New-Item -ItemType Directory -Path $dir -Force | Out-Null

# 3. CREATE THE INSTANT LISTENER (Event-Driven)
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$dirToWatch = "$dir"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::Information
`$n.Visible = `$True

`$action = {
    `$path = `$Event.SourceEventArgs.FullPath
    # Small delay to ensure the writing process has released the file
    Start-Sleep -Milliseconds 100
    try {
        `$message = [System.IO.File]::ReadAllText(`$path).Trim()
        if (`$message) {
            `$n.ShowBalloonTip(10000, "Remote Admin", `$message, [System.Windows.Forms.ToolTipIcon]::Info)
        }
    } finally {
        Remove-Item `$path -Force -ErrorAction SilentlyContinue
    }
}

`$watcher = New-Object System.IO.FileSystemWatcher
`$watcher.Path = `$dirToWatch
`$watcher.Filter = "msg.txt"
`$watcher.EnableRaisingEvents = `$true

Register-ObjectEvent `$watcher "Created" -Action `$action | Out-Null

# Keep the session alive for the events
while (`$true) { Start-Sleep -Seconds 3600 }
"@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerContent -Encoding UTF8

# 4. CREATE THE UNIVERSAL 'NOTIFY' COMMAND (CMD)
$batContent = @'
@echo off
setlocal enabledelayedexpansion
set "msg=%*"
if not defined msg (echo [ERROR] No message provided. & exit /b)
:: Use PowerShell to write the file to ensure UTF8 encoding for symbols
powershell -Command "[System.IO.File]::WriteAllText('C:\RemoteAdmin\msg.txt', \"!msg!\")"
endlocal
'@
Set-Content -Path "C:\Windows\notify.bat" -Value $batContent

# 5. CREATE POWERSHELL FUNCTION (Non-Destructive)
$functionCode = @"

# --- Remote Admin Notifier ---
function notify {
    param([Parameter(ValueFromRemainingArguments=`$true)]`$RawMessage)
    `$msg = `$RawMessage -join ' '
    if (!`$msg) { Write-Host "[ERROR] No message provided." -ForegroundColor Red; return }
    [System.IO.File]::WriteAllText("$dir\msg.txt", `$msg)
    Write-Host "[SUCCESS] Notification sent." -ForegroundColor Green
}
"@
if (!(Test-Path $PROFILE)) { 
    New-Item -Type File -Path $PROFILE -Force | Out-Null 
}
Add-Content -Path $PROFILE -Value $functionCode

# 6. REGISTER AUTO-START TASK
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$dir\NotificationListener.ps1"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

# 7. REFRESH SESSION
. $PROFILE

Write-Host "`n--- SETUP COMPLETE ---" -ForegroundColor Green
Write-Host "The 'notify' command is now instant and active." -ForegroundColor Gray
