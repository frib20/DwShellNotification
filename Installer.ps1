# =================================================================
# DWShellNotification - THE "TOTAL FIX" INSTALLER
# =================================================================

# --- 1. SETTINGS & PATHS ---
$dir = "C:\RemoteAdmin"
$title = "Shorix System"
$icon = "Information"
$scriptPath = "$dir\NotificationListener.ps1"
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\LaunchNotify.vbs"

Write-Host "Starting Fresh Install..." -ForegroundColor Cyan

# --- 2. CLEANUP ---
# Kill any existing listeners and remove the old task
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwShellNotify" -Confirm:$false -ErrorAction SilentlyContinue

# --- 3. DIRECTORY SETUP ---
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
            `$msg = Get-Content `$trigger -Raw -ErrorAction SilentlyContinue
            if (`$msg) {
                `$n.ShowBalloonTip(10000, "$title", `$msg.Trim(), [System.Windows.Forms.ToolTipIcon]::$icon)
            }
        } catch {}
        Remove-Item `$trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# --- 5. CREATE STARTUP LAUNCHER (VBS Trick to hide window) ---
# This starts the listener in the BACKGROUND without a blue box appearing
$vbsContent = "CreateObject(`"Wscript.Shell`").Run `"powershell.exe -NoProfile -File `"$scriptPath`"`", 0, True"
Set-Content -Path $startupPath -Value $vbsContent

# --- 6. CREATE NOTIFY.BAT (For CMD) ---
$batContent = @"
@echo off
if "%~1"=="" exit /b
(echo.%*) > "$dir\msg.txt"
echo [SUCCESS] Notification Sent.
"@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 7. CREATE POWERSHELL ALIAS ---
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
Set-Content -Path $profilePath -Value "function notify { (echo `$args) > '$dir\msg.txt'; Write-Host '[SUCCESS] Notification Sent' -FG Green }" -Force

# --- 8. RUN NOW ---
# Start the listener immediately so you don't have to reboot
wscript.exe "$startupPath"

Write-Host "DONE! Try typing 'notify Test' in the shell now." -ForegroundColor Green
