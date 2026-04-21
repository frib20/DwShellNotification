# =================================================================
# DWShellNotification - THE GUI SHELL BRIDGE (BUBBLE VERSION)
# =================================================================

Write-Host "1. Cleaning up Session 0 ghosts..." -ForegroundColor Cyan
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwGuiBridge" -Confirm:$false -ErrorAction SilentlyContinue

# Setup the bridge folder
$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
icacls $dir /grant "Everyone:(OI)(CI)F" /T | Out-Null

Write-Host "2. Creating Local GUI Listener..." -ForegroundColor Cyan
# This script will ONLY run in the local graphical shell
$listenerCode = @'
Add-Type -AssemblyName System.Windows.Forms
$trigger = "C:\RemoteAdmin\msg.txt"

# Windows 10/11 REQUIRES an icon to show a bubble notification
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")
$n.Text = "Shorix Background Bridge"
$n.Visible = $True

while($true) {
    if (Test-Path $trigger) {
        try {
            $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
            if ($msg) {
                # This is the classic "Bubble" request
                $n.ShowBalloonTip(10000, "Shorix System", $msg.Trim(), "Info")
            }
        } catch {}
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerCode -Encoding UTF8

Write-Host "3. Creating Shell Commands..." -ForegroundColor Cyan
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

Write-Host "4. Injecting into Graphical User Interface..." -ForegroundColor Cyan
# This is the magic. We find the person at the keyboard.
$activeUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName

if ($activeUser) {
    Write-Host "-> Found active local user: $activeUser" -ForegroundColor Green
    
    # We use Task Scheduler to cross the boundary from DWService to the Local Desktop
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"
    
    # Force it into their interactive session
    $principal = New-ScheduledTaskPrincipal -UserId $activeUser -LogonType Interactive
    $triggerTask = New-ScheduledTaskTrigger -AtLogOn
    
    Register-ScheduledTask -TaskName "DwGuiBridge" -Action $action -Principal $principal -Trigger $triggerTask -Force | Out-Null
    
    # Start it immediately in their GUI
    Start-ScheduledTask -TaskName "DwGuiBridge"
    
    Write-Host "BRIDGE ESTABLISHED. Close/Open your shell and type: notify test" -ForegroundColor Green
} else {
    Write-Host "-> ERROR: Could not detect anyone logged into the desktop screen." -ForegroundColor Red
    Write-Host "-> The bubble needs a screen to draw on. Log into the computer first." -ForegroundColor Yellow
}
