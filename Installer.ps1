# =================================================================
# DWShellNotification - ULTIMATE REPAIR
# =================================================================

# 1. SETUP & CONFIG
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try { $configText = Invoke-RestMethod -Uri $configUrl; Invoke-Expression $configText } catch { 
    $GlobalConfig = @{ Title="Shorix System"; Folder="C:\Users\Public\Documents\DwNotify"; IconType="Information" } 
}

$dir = $GlobalConfig.Folder
$scriptPath = "$dir\NotificationListener.ps1"
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$vbsPath = "$startupFolder\StartNotify.vbs"

# 2. KILL OLD GHOSTS
Write-Host "Cleaning up..." -ForegroundColor Cyan
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwShellNotify" -Confirm:$false -ErrorAction SilentlyContinue

# 3. DIRECTORY & PERMISSIONS
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null

# 4. THE LISTENER (Modern Toast/Popup Hybrid)
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
`$trigger = "$dir\msg.txt"

# Create the tray icon (Required for notifications to work)
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("powershell.exe")
`$n.Text = "Shorix Notification Listener"
`$n.Visible = `$True

while(`$true) {
    if (Test-Path `$trigger) {
        try {
            `$msg = Get-Content `$trigger -Raw -ErrorAction SilentlyContinue
            if (`$msg) {
                # Try a standard Balloon Tip
                `$n.ShowBalloonTip(5000, "$($GlobalConfig.Title)", `$msg.Trim(), "Info")
            }
        } catch {}
        Remove-Item `$trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# 5. THE STARTUP VBS (Forces it into YOUR session, not Session 0)
$vbsContent = "CreateObject(`"Wscript.Shell`").Run `"powershell.exe -NoProfile -WindowStyle Hidden -File `"$scriptPath`"`", 0, True"
Set-Content -Path $vbsPath -Value $vbsContent

# 6. THE NOTIFY.BAT (For CMD)
$batContent = @"
@echo off
if "%~1"=="" exit /b
echo %* > "$dir\msg.txt"
echo [SENT] %*
"@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# 7. THE POWERSHELL FUNCTION
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
Set-Content -Path $profilePath -Value "function notify { `$msg = `$args -join ' '; `$msg > '$dir\msg.txt'; Write-Host '[SENT]' -FG Green }" -Force

# 8. START IT NOW
wscript.exe "$vbsPath"

Write-Host "--- REPAIR COMPLETE ---" -ForegroundColor Green
Write-Host "1. Close this shell."
Write-Host "2. Open a new shell."
Write-Host "3. Type: notify hello"
