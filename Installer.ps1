# --- 1. LOAD CUSTOMIZATIONS ---
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try {
    Invoke-RestMethod -Uri $configUrl | Invoke-Expression
    Write-Host "Customizations loaded: $($GlobalConfig.Title)" -ForegroundColor Cyan
} catch {
    Write-Host "Failed to load Customization.ps1, using defaults." -ForegroundColor Yellow
    $GlobalConfig = @{ Title="Remote Admin"; ServiceName="AutoRemoteNotify"; Folder="C:\RemoteAdmin"; IconType="Information" }
}

# --- 2. SETUP PATHS ---
$dir = $GlobalConfig.Folder
$scriptPath = "$dir\NotificationListener.ps1"
$taskName = $GlobalConfig.ServiceName

if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# --- 3. CREATE LISTENER (Using Config Variables) ---
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$triggerFile = "$dir\msg.txt"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::$($GlobalConfig.IconType)
`$n.Visible = `$True

while(`$true) {
    if (Test-Path `$triggerFile) {
        try {
            `$message = [System.IO.File]::ReadAllText(`$triggerFile).Trim()
            if (`$message) {
                `$n.ShowBalloonTip(10000, "$($GlobalConfig.Title)", `$message, [System.Windows.Forms.ToolTipIcon]::$($GlobalConfig.IconType))
            }
        } finally {
            Remove-Item `$triggerFile -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 1
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# --- 4. CREATE NOTIFY.BAT (Enhanced for Symbols & Empty Messages) ---
$batContent = @"
@echo off
setlocal enabledelayedexpansion
set "msg=%*"
if "!msg!"=="" (
    echo [ERROR] No message provided.
    exit /b
)
:: The parentheses around the echo prevent the "ECHO is off" bug
(echo !msg!) > "$dir\msg.txt"
echo [SUCCESS] Notification sent: "!msg!"
endlocal
"@
Set-Content -Path "C:\Windows\notify.bat" -Value $batContent

# --- 5. REGISTER TASK ---
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "Installation Complete: $taskName is running." -ForegroundColor Green
