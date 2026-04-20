# =================================================================
# DWShellNotification - BULLETPROOF RESET VERSION
# =================================================================

# 1. KILL EVERYTHING OLD
Write-Host "Cleaning up old processes and tasks..." -ForegroundColor Cyan
$taskName = "AutoRemoteNotify"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force

# 2. LOAD CONFIG (With Fallback)
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try {
    Invoke-RestMethod -Uri $configUrl | Invoke-Expression
    $dir = $GlobalConfig.Folder
    $title = $GlobalConfig.Title
    $icon = $GlobalConfig.IconType
} catch {
    $dir = "C:\RemoteAdmin"
    $title = "System Alert"
    $icon = "Information"
}

# 3. FRESH DIRECTORY SETUP
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null
Remove-Item "$dir\msg.txt" -Force -ErrorAction SilentlyContinue

# 4. THE LISTENER (The "Will Not Fail" Loop)
$scriptPath = "$dir\NotificationListener.ps1"
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$trigger = "$dir\msg.txt"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::$icon
`$n.Visible = `$True

while(`$true) {
    if (Test-Path `$trigger) {
        try {
            # Read and immediately close the file
            `$msg = Get-Content `$trigger -Raw -ErrorAction SilentlyContinue
            if (`$msg) {
                `$n.ShowBalloonTip(10000, "$title", `$msg.Trim(), [System.Windows.Forms.ToolTipIcon]::$icon)
            }
        } catch {}
        # Delete it so we don't loop the same message
        Remove-Item `$trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 200
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# 5. THE BATCH FILE (Dynamically links to the Config folder)
$batContent = @"
@echo off
if "%~1"=="" exit /b
(echo.%*) > "$dir\msg.txt"
echo [SUCCESS] Sent to $dir: %*
"@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# 6. REGISTER TASK (Standard User Session)
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
# We use the current user's identity to ensure the UI can pop up
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "--- Reset Complete ---" -ForegroundColor Green
Write-Host "Testing notification in 3 seconds..."
Start-Sleep -Seconds 3
notify "System Reset Successful!"
