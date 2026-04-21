# =================================================================
# DWShellNotification - VBS QUOTE-PROOF VERSION
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
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null

# 3. THE LISTENER
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
    Start-Sleep -Milliseconds 250
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# 4. THE STARTUP VBS (Bulletproof Concatenation)
# We build the VBS line by adding the quotes manually to avoid PowerShell escaping bugs
$q = [char]34
$vbsLine = 'CreateObject(' + $q + 'Wscript.Shell' + $q + ').Run ' + $q + 'powershell.exe -NoProfile -WindowStyle Hidden -File ' + $q + $q + $scriptPath + $q + $q + $q + ', 0, True'
Set-Content -Path $vbsPath -Value $vbsLine

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
Write-Host "VBS syntax has been hardened. Please check the remote screen now."
