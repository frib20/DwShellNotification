# =================================================================
# DWShellNotification - Full Installer Logic
# =================================================================

# --- 1. LOAD CUSTOMIZATIONS ---
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try {
    Invoke-RestMethod -Uri $configUrl | Invoke-Expression
    Write-Host "Customizations loaded: $($GlobalConfig.Title)" -ForegroundColor Cyan
} catch {
    Write-Host "Failed to load Config.ps1, using defaults." -ForegroundColor Yellow
    $GlobalConfig = @{ 
        Title       = "Remote Admin"
        ServiceName = "AutoRemoteNotify"
        Folder      = "C:\RemoteAdmin"
        IconType    = "Information" 
    }
}

# --- 2. SETUP PATHS & PERMISSIONS ---
$dir = $GlobalConfig.Folder
$scriptPath = "$dir\NotificationListener.ps1"
$taskName = $GlobalConfig.ServiceName

if (!(Test-Path $dir)) { 
    New-Item -ItemType Directory -Path $dir -Force | Out-Null 
}

# Grant "Everyone" access so CMD can write to the folder regardless of user level
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null

# --- 3. CREATE LISTENER (High-Speed / Low Latency) ---
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$triggerFile = "$dir\msg.txt"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::$($GlobalConfig.IconType)
`$n.Visible = `$True

while(`$true) {
    if ([System.IO.File]::Exists(`$triggerFile)) {
        try {
            `$message = [System.IO.File]::ReadAllText(`$triggerFile).Trim()
            if (`$message) {
                `$n.ShowBalloonTip(10000, "$($GlobalConfig.Title)", `$message, [System.Windows.Forms.ToolTipIcon]::$($GlobalConfig.IconType))
            }
        } finally {
            [System.IO.File]::Delete(`$triggerFile)
        }
    }
    # 100ms polling for near-instant response
    Start-Sleep -Milliseconds 100
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# --- 4. CREATE NOTIFY.BAT (Optimized for CMD & Speed) ---
$batContent = @'
@echo off
if "%~1" == "" exit /b
:: The (echo.) trick prevents "ECHO is off" and writes instantly
(echo.%*) > C:\RemoteAdmin\msg.txt
echo [SUCCESS] Notification sent (CMD): %*
'@

# Using ASCII to ensure CMD never misreads the file or shows "endlocal"
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 5. CREATE POWERSHELL ALIAS (Isolation Fix) ---
$functionCode = @"
function notify {
    param([Parameter(ValueFromRemainingArguments=`$true)]`$RawMessage)
    `$msg = `$RawMessage -join ' '
    if (!`$msg) { return }
    # PS writes directly to file to avoid double-triggering the .bat
    [System.IO.File]::WriteAllText("$dir\msg.txt", `$msg)
    Write-Host "[SUCCESS] Notification sent (PS): `$msg" -ForegroundColor Green
}
"@

$ManualProfile = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$profileDir = Split-Path $ManualProfile -Parent
if (!(Test-Path $profileDir)) { New-Item -Type Directory -Path $profileDir -Force | Out-Null }
Set-Content -Path $ManualProfile -Value $functionCode -Force

# --- 6. REGISTER & START TASK ---
# Stop old task first to release file locks
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "--- Installation Complete ---" -ForegroundColor Green
Write-Host "Service: $taskName"
Write-Host "Folder: $dir"
Write-Host "Try typing 'notify hello' in CMD or PowerShell!"
