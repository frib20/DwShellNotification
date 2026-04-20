# --- 1. LOAD CONFIG ---
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try {
    Invoke-RestMethod -Uri $configUrl | Invoke-Expression
} catch {
    $GlobalConfig = @{ Title="Remote Admin"; ServiceName="AutoRemoteNotify"; Folder="C:\RemoteAdmin"; IconType="Information" }
}

$dir = $GlobalConfig.Folder
$scriptPath = "$dir\NotificationListener.ps1"
$taskName = $GlobalConfig.ServiceName

if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null

# --- 2. CREATE EVENT-DRIVEN LISTENER (No Polling Delay) ---
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$dir = "$dir"
`$triggerFile = "msg.txt"

`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::$($GlobalConfig.IconType)
`$n.Visible = `$True

# Event Watcher: This triggers the INSTANT the file hits the disk
`$watcher = New-Object System.IO.FileSystemWatcher
`$watcher.Path = `$dir
`$watcher.Filter = `$triggerFile
`$watcher.EnableRaisingEvents = `$true

`$action = {
    `$fullPath = `$Event.SourceEventArgs.FullPath
    # Small delay to ensure CMD has finished writing the file
    Start-Sleep -Milliseconds 20
    if (Test-Path `$fullPath) {
        `$message = [System.IO.File]::ReadAllText(`$fullPath).Trim()
        if (`$message) {
            `$n.ShowBalloonTip(10000, "$($GlobalConfig.Title)", `$message, [System.Windows.Forms.ToolTipIcon]::$($GlobalConfig.IconType))
        }
        [System.IO.File]::Delete(`$fullPath)
    }
}

# Bind the event
Register-ObjectEvent `$watcher "Created" -Action `$action | Out-Null

# Keep the script alive silently
while (`$true) { Start-Sleep -Seconds 3600 }
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# --- 3. CREATE NOTIFY.BAT (Optimized CMD Pipeline) ---
$batContent = @'
@echo off
if "%~1"=="" exit /b
:: Native CMD redirect is the fastest way to trigger the watcher
(echo.%*) > C:\RemoteAdmin\msg.txt
'@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 4. REGISTER & START ---
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "--- Instant-Response Mode Active ---" -ForegroundColor Green
