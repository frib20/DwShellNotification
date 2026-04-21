# =================================================================
# DWShellNotification - SIMPLE NUCLEAR INSTALLER
# =================================================================

# --- 1. THE UNINSTALL (Kill Everything) ---
Write-Host "Wiping old installation..." -ForegroundColor Cyan
$taskName = "DwShellNotify"
$dir = "C:\RemoteAdmin"
$startupFile = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\StartNotify.vbs"

# Stop the Scheduled Task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Kill any running PowerShell instances of the listener
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force

# Delete the old Startup VBS and the main directory
if (Test-Path $startupFile) { Remove-Item $startupFile -Force }
if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path "C:\Windows\notify.bat") { Remove-Item "C:\Windows\notify.bat" -Force }

Write-Host "Cleanup complete. Installing fresh..." -ForegroundColor Green

# --- 2. THE INSTALL (Hard-Coded Paths) ---
New-Item -ItemType Directory -Path $dir -Force | Out-Null
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null

# --- 3. CREATE THE LISTENER ---
$listenerContent = @'
Add-Type -AssemblyName System.Windows.Forms
$trigger = "C:\RemoteAdmin\msg.txt"
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("powershell.exe")
$n.Visible = $True

while($true) {
    if (Test-Path $trigger) {
        try {
            $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
            if ($msg) {
                $n.ShowBalloonTip(10000, "Shorix System", $msg.Trim(), "Info")
            }
        } catch {}
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 200
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerContent -Encoding UTF8

# --- 4. CREATE THE VBS LAUNCHER (No Quote Hell) ---
# Hard-coding the path here avoids the "Expected end of statement" error
$vbsContent = 'CreateObject("WScript.Shell").Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1", 0'
Set-Content -Path $startupFile -Value $vbsContent

# --- 5. CREATE NOTIFY.BAT ---
$batContent = @'
@echo off
if "%~1"=="" exit /b
echo %* > "C:\RemoteAdmin\msg.txt"
'@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 6. CREATE POWERSHELL PROFILE ALIAS ---
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
Set-Content -Path $profilePath -Value 'function notify { $msg = $args -join " "; $msg > "C:\RemoteAdmin\msg.txt"; Write-Host "[SENT]" -FG Green }' -Force

# --- 7. FIRE IT UP ---
# This runs the VBS immediately in the user session
& wscript.exe $startupFile

Write-Host "DONE. Open a new shell and type: notify test" -ForegroundColor Green
