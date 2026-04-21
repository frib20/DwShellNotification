# =================================================================
# DWShellNotification - FORCE POPUP VERSION
# =================================================================

# 1. CLEANUP
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force

# 2. DIRECTORY
$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)F" /T | Out-Null

# 3. THE LISTENER (Using Popups instead of Balloon Tips)
$listenerCode = @'
Add-Type -AssemblyName System.Windows.Forms
while($true) {
    if (Test-Path "C:\RemoteAdmin\msg.txt") {
        try {
            $msg = Get-Content "C:\RemoteAdmin\msg.txt" -Raw -ErrorAction SilentlyContinue
            if ($msg) {
                # This creates a real window that pops up in front of everything
                [System.Windows.Forms.MessageBox]::Show($msg.Trim(), "Shorix System", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information, [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::ServiceNotification)
            }
        } catch {}
        Remove-Item "C:\RemoteAdmin\msg.txt" -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerCode

# 4. THE COMMANDS
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

# 5. START
Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"

Write-Host "INSTALL COMPLETE. CLOSE/OPEN SHELL AND TYPE: notify hello" -ForegroundColor Green
