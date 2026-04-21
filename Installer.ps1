# =================================================================
# DWShellNotification - REPAIR VERSION (VBS FIX)
# =================================================================

# 1. SETUP & CONFIG
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try { 
    $configText = Invoke-RestMethod -Uri $configUrl
    Invoke-Expression $configText 
} catch { 
    $GlobalConfig = @{ Title="Shorix System"; Folder="C:\Users\Public\Documents\DwNotify"; IconType="Information" } 
}

$dir = $GlobalConfig.Folder
$scriptPath = "$dir\NotificationListener.ps1"
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$vbsPath = "$startupFolder\StartNotify.vbs"

Write-Host "Cleaning up old processes..." -ForegroundColor Cyan
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force

# 2. DIRECTORY & PERMISSIONS
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null

# 3. THE LISTENER (High-Speed Polling)
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
`$trigger = "$dir\msg.txt"

`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("powershell.exe")
`$n.Text = "Shorix Notification Listener"
`$n.Visible = `$True

while(`$true) {
    if (Test-Path `$trigger) {
        try {
            `$msg = Get-Content `$trigger -Raw -ErrorAction SilentlyContinue
            if (`$msg) {
                `$n.ShowBalloonTip(10000, "$($GlobalConfig.Title)", `$msg.Trim(), "Info")
            }
        } catch {}
        Remove-Item `$trigger -Force -ErrorAction SilentlyContinue
    }
    # 100ms for instant feel
    Start-Sleep -Milliseconds 100
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# 4. THE STARTUP VBS (FIXED QUOTES)
# We use '""' to escape quotes properly inside VBScript
$vbsContent = "CreateObject(`"Wscript.Shell`").Run `"powershell.exe -NoProfile -WindowStyle Hidden -File `"`"$scriptPath`"`"`", 0, True"
Set-Content -Path $vbsPath -Value $vbsContent

# 5. THE NOTIFY.BAT (For CMD)
$batContent = @"
@echo off
if "%~1"=="" exit /b
echo %* > "$dir\msg.txt"
"@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# 6. THE POWERSHELL FUNCTION
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
Set-Content -Path $profilePath -Value "function notify { `$msg = `$args -join ' '; `$msg > '$dir\msg.txt'; Write-Host '[SENT]' -FG Green }" -Force

# 7. START IT NOW
Remove-Item "$dir\msg.txt" -ErrorAction SilentlyContinue
wscript.exe "$vbsPath"

Write-Host "--- REPAIR COMPLETE ---" -ForegroundColor Green
Write-Host "No more VBS errors. Close/Open your shell and test it!"
