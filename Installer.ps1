# =================================================================
# DWShellNotification - RECOVERY VERSION
# =================================================================

# 1. CLEANUP (Kill everything to start fresh)
Write-Host "Resetting system..." -ForegroundColor Cyan
$dir = "C:\RemoteAdmin"
$taskName = "DwShellNotify"

# Kill old processes
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# 2. FOLDER SETUP
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null
Remove-Item "$dir\msg.txt" -Force -ErrorAction SilentlyContinue

# 3. THE LISTENER (The code that worked before)
$listenerContent = @'
Add-Type -AssemblyName System.Windows.Forms
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.SystemIcons]::Information
$n.Visible = $True
while($true) {
    if (Test-Path "C:\RemoteAdmin\msg.txt") {
        try {
            $msg = Get-Content "C:\RemoteAdmin\msg.txt" -Raw -ErrorAction SilentlyContinue
            if ($msg) {
                $n.ShowBalloonTip(10000, "Shorix System", $msg.Trim(), "Info")
            }
        } catch {}
        Remove-Item "C:\RemoteAdmin\msg.txt" -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerContent -Encoding UTF8

# 4. THE COMMANDS (CMD & PowerShell)
# CMD Version
$batContent = "@echo off`nif `"%~1`"==`"`" exit /b`necho %* > `"C:\RemoteAdmin\msg.txt`""
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# PowerShell Version
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
Set-Content -Path $profilePath -Value 'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' -Force

# 5. START THE LISTENER (Manual Start)
# This runs it immediately so you don't have to reboot
Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"

Write-Host "RECOVERY COMPLETE." -ForegroundColor Green
Write-Host "Type 'notify test' to check."
