# 1. CLEANUP OLD STUFF

$Name = "DwNotification"
Write-Host "Cleaning up old tasks and files..." -ForegroundColor Cyan
$taskName = "AutoRemoteNotify"
$dir = "C:\RemoteAdmin"
Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
if (Test-Path "C:\Windows\notify.bat") { Remove-Item -Force "C:\Windows\notify.bat" }

# 2. CREATE FOLDER
New-Item -ItemType Directory -Path $dir -Force | Out-Null

# 3. CREATE THE SMART LISTENER
# This uses [System.IO.File] to read symbols exactly as they are written
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$triggerFile = "$dir\msg.txt"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::Information
`$n.Visible = `$False

while(`$true) {
    if (Test-Path `$triggerFile) {
        try {
            `$message = [System.IO.File]::ReadAllText(`$triggerFile).Trim()
            if (`$message) {
                `$n.ShowBalloonTip(10000, "$Name", `$message, [System.Windows.Forms.ToolTipIcon]::Info)
            }
        } finally {
            Remove-Item `$triggerFile -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 1
}
"@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerContent -Encoding UTF8

# 4. CREATE THE UNIVERSAL 'NOTIFY' COMMAND (CMD version)
# Using delayed expansion to handle symbols like & ^ % ! in CMD
$batContent = @'
@echo off
setlocal enabledelayedexpansion
set "msg=%*"
if not defined msg (echo [ERROR] No message provided. & exit /b)
echo !msg! > C:\RemoteAdmin\msg.txt
echo [SUCCESS] Notification sent: "!msg!"
endlocal
'@
Set-Content -Path "C:\Windows\notify.bat" -Value $batContent


# 5. CREATE POWERSHELL PROFILE FUNCTION (PowerShell version)
$profileDir = Split-Path $PROFILE -Parent
if (!(Test-Path $profileDir)) { New-Item -Type Directory -Path $profileDir -Force }

# We use a single-quote here-string '@ ... @' so we don't have to escape every $ sign
# 1. Define the code (Your snippet)
$functionCode = @'

function notify {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        $RawMessage
    )
    
    $msg = $RawMessage -join ' '
    $targetDir = "C:\RemoteAdmin"
    $targetPath = "$targetDir\msg.txt"

    if ([string]::IsNullOrWhiteSpace($msg)) {
        Write-Host "[ERROR] No message provided." -ForegroundColor Red
        return
    }

    try {
        if (!(Test-Path $targetDir)) { 
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null 
        }
        $msg | Set-Content -Path $targetPath -Encoding UTF8
        Write-Host "[SUCCESS] Notification sent: `"$msg`"" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to write notification: $($_.Exception.Message)" -ForegroundColor Red
    }
}
'@
# Append to profile instead of overwriting it
Add-Content -Path $PROFILE -Value $functionCode
# 6. REGISTER PERMANENT AUTO-START TASK
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$dir\NotificationListener.ps1"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

# 7. REFRESH CURRENT SESSION
. $PROFILE

Write-Host "`n--- SETUP COMPLETE ---" -ForegroundColor Green
Write-Host "1. Works in CMD: notify !@#$%^&*()" -ForegroundColor White
Write-Host "2. Works in PS:  notify '!@#$%^&*()'" -ForegroundColor White
Write-Host "3. Persists through reboots." -ForegroundColor White
