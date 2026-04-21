# =================================================================
# DWShellNotification - TOTAL RESET (BACK TO BASICS)
# =================================================================

Write-Host "--- KILLING OLD PROCESSES ---" -ForegroundColor Cyan
# 1. Force stop every possible background version of this script
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwShellNotify" -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "--- WIPING FOLDER ---" -ForegroundColor Cyan
# 2. Delete and recreate the folder to fix permissions
if (Test-Path "C:\RemoteAdmin") { Remove-Item "C:\RemoteAdmin" -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path "C:\RemoteAdmin" -Force | Out-Null
icacls "C:\RemoteAdmin" /grant "Everyone:(OI)(CI)F" /T | Out-Null

Write-Host "--- CREATING LISTENER ---" -ForegroundColor Cyan
# 3. Simple Listener (The exact one that worked)
$listenerCode = @'
Add-Type -AssemblyName System.Windows.Forms
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.SystemIcons]::Information
$n.Visible = $True
while($true) {
    if (Test-Path "C:\RemoteAdmin\msg.txt") {
        $msg = Get-Content "C:\RemoteAdmin\msg.txt" -Raw
        if ($msg) { $n.ShowBalloonTip(10000, "Shorix System", $msg.Trim(), "Info") }
        Remove-Item "C:\RemoteAdmin\msg.txt" -Force
    }
    Start-Sleep -Seconds 1
}
'@
Set-Content -Path "C:\RemoteAdmin\NotificationListener.ps1" -Value $listenerCode

Write-Host "--- CREATING COMMANDS ---" -ForegroundColor Cyan
# 4. Create the Batch file for CMD
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"

# 5. Create the PowerShell Function
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

Write-Host "--- STARTING LISTENER ---" -ForegroundColor Cyan
# 6. Start the listener in a hidden window
Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"

Write-Host "INSTALL COMPLETE. CLOSE YOUR SHELL AND OPEN A NEW ONE." -ForegroundColor Green
