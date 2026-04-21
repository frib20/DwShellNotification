# =================================================================
# DWShellNotification - DIRECT SESSION JUMP (TRAY ICON FIX)
# =================================================================

# 1. CLEANUP EVERY OLD VERSION
Write-Host "Clearing old listeners..." -ForegroundColor Cyan
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwGuiBridge" -Confirm:$false -ErrorAction SilentlyContinue

# 2. SETUP DIRECTORY
$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# 3. THE LISTENER (Tray Icon + Bubble)
$listenerCode = @'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$trigger = "C:\RemoteAdmin\msg.txt"

# Force the tray icon to appear
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("powershell.exe")
$n.Text = "Shorix System"
$n.Visible = $true

# Show an initial bubble so we know it's alive
$n.ShowBalloonTip(2000, "Shorix System", "Bridge Connected!", [System.Windows.Forms.ToolTipIcon]::Info)

while($true) {
    if (Test-Path $trigger) {
        $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
        if ($msg) {
            $n.ShowBalloonTip(5000, "Shorix System", $msg.Trim(), [System.Windows.Forms.ToolTipIcon]::Info)
        }
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerCode -Encoding UTF8

# 4. CREATE COMMANDS
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

# 5. THE JUMP (Forcing it into the GUI)
$activeUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
if ($activeUser) {
    Write-Host "Targeting User: $activeUser" -ForegroundColor Green
    
    # We use 'schtasks' directly which is sometimes more reliable than the PS cmdlet
    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"
    schtasks /create /tn "DwGuiBridge" /tr "$cmd" /sc ONLOGON /rl HIGHEST /ru "$activeUser" /f | Out-Null
    
    # Run it immediately as that user
    schtasks /run /tn "DwGuiBridge" | Out-Null
    
    Write-Host "BRIDGE INJECTED. Check the tray icon now." -ForegroundColor Green
} else {
    Write-Host "ERROR: No logged-in user detected." -ForegroundColor Red
}
