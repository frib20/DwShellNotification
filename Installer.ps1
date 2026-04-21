# =================================================================
# DWShellNotification - MASTER INSTALLER (FIXED)
# =================================================================

# --- 1. PRE-INSTALL CLEANUP ---
$taskName = "DwShellNotify"
Write-Host "Cleaning up old processes..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force

# --- 2. LOAD CONFIG ---
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try {
    $configText = Invoke-RestMethod -Uri $configUrl
    Invoke-Expression $configText
} catch {
    $GlobalConfig = @{ Title="System Alert"; ServiceName="DwShellNotify"; Folder="C:\RemoteAdmin"; IconType="Information" }
}

$dir = $GlobalConfig.Folder
$title = $GlobalConfig.Title
$icon = $GlobalConfig.IconType
$scriptPath = "$dir\NotificationListener.ps1"

# --- 3. DIRECTORY & PERMISSIONS ---
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null
Remove-Item "$dir\msg.txt" -Force -ErrorAction SilentlyContinue

# --- 4. CREATE THE LISTENER ---
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$trigger = "$dir\msg.txt"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::$icon
`$n.Visible = `$True

while(`$true) {
    if (Test-Path `$trigger) {
        try {
            # Use FileStream to allow CMD to write while we read
            `$stream = [System.IO.File]::Open(`$trigger, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            `$reader = New-Object System.IO.StreamReader(`$stream)
            `$msg = `$reader.ReadToEnd().Trim()
            `$reader.Close(); `$stream.Close()

            if (`$msg) {
                `$n.ShowBalloonTip(10000, "$title", `$msg, [System.Windows.Forms.ToolTipIcon]::$icon)
            }
        } catch {}
        Remove-Item `$trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 250
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# --- 5. CREATE NOTIFY.BAT (For CMD) ---
$batContent = @"
@echo off
if "%~1"=="" exit /b
(echo.%*) > "$dir\msg.txt"
"@
# ASCII is required for CMD to read the file correctly
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 6. CREATE POWERSHELL FUNCTION ---
$functionCode = @"
function notify {
    param([Parameter(ValueFromRemainingArguments=`$true)]`$RawMessage)
    `$msg = `$RawMessage -join ' '
    if (!`$msg) { return }
    [System.IO.File]::WriteAllText("$dir\msg.txt", `$msg)
    Write-Host "[SUCCESS] Notification sent" -ForegroundColor Green
}
"@
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$profileDir = Split-Path $profilePath
if (!(Test-Path $profileDir)) { New-Item -Type Directory $profileDir -Force }
Set-Content -Path $profilePath -Value $functionCode -Force

# --- 7. SCHEDULE TASK (The UI Fix) ---
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
# 'Interactive' Group is the magic fix for showing UI via DWService
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "--- INSTALLATION COMPLETE ---" -ForegroundColor Green
Write-Host "Restart your DWService Shell for changes to take effect."
