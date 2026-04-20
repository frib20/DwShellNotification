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

# --- 3. CREATE LISTENER ---
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

# --- 4. CREATE NOTIFY.BAT (Fixed: No Double-Write) ---
$batContent = @'
@echo off
if "%*"=="" exit /b
:: Direct CMD redirect to the file. No PowerShell calls here = No double trigger.
(echo.%*) > C:\RemoteAdmin\msg.txt
echo [SUCCESS] Notification sent (CMD): %*
'@

# We only use ASCII here. It is the most stable for CMD.
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 5. CREATE POWERSHELL ALIAS ---
$functionCode = @"
function notify {
    param([Parameter(ValueFromRemainingArguments=`$true)]`$RawMessage)
    `$msg = `$RawMessage -join ' '
    if (!`$msg) { return }
    # Write directly to the file. PS uses this function, CMD uses the .bat file.
    [System.IO.File]::WriteAllText("$dir\msg.txt", `$msg)
    Write-Host "[SUCCESS] Notification sent (PS): `$msg" -ForegroundColor Green
}
"@

$ManualProfile = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$profileDir = Split-Path $ManualProfile -Parent
if (!(Test-Path $profileDir)) { New-Item -Type Directory -Path $profileDir -Force | Out-Null }
Set-Content -Path $ManualProfile -Value $functionCode -Force

# --- 6. REGISTER TASK ---
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "Installation Complete: $taskName is running." -ForegroundColor Green
