# =================================================================
# DWShellNotification - DEFINITIVE BUBBLE FIX
# =================================================================

# 1. KILL ALL GHOSTS (Clean Start)
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwGuiBridge" -Confirm:$false -ErrorAction SilentlyContinue

# 2. FORCE WINDOWS TO ALLOW BUBBLES (Registry)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $regPath -Name "EnableBalloonTips" -Value 1 -ErrorAction SilentlyContinue
# Unlocks legacy notifications for Windows 10/11
$policyPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
if (!(Test-Path $policyPath)) { New-Item $policyPath -Force | Out-Null }
Set-ItemProperty -Path $policyPath -Name "EnableLegacyBalloonNotifications" -Value 1 -ErrorAction SilentlyContinue

# 3. THE LISTENER (Tray Icon + Bubble)
$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$listenerCode = @'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$trigger = "C:\RemoteAdmin\msg.txt"

# This setup is CRITICAL. No icon = No bubble.
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("powershell.exe")
$n.Text = "Shorix System Bridge"
$n.Visible = $true

while($true) {
    if (Test-Path $trigger) {
        $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
        if ($msg) {
            # 5000ms timeout, Title, Message, Icon Type
            $n.ShowBalloonTip(5000, "Shorix System", $msg.Trim(), [System.Windows.Forms.ToolTipIcon]::Info)
        }
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerCode -Encoding UTF8

# 4. SHELL COMMANDS
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

# 5. INJECT INTO GUI SESSION
$activeUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
if ($activeUser) {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"
    $principal = New-ScheduledTaskPrincipal -UserId $activeUser -LogonType Interactive
    $triggerTask = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName "DwGuiBridge" -Action $action -Principal $principal -Trigger $triggerTask -Force | Out-Null
    Start-ScheduledTask -TaskName "DwGuiBridge"
    Write-Host "INSTALLER: Bridge established for $activeUser" -ForegroundColor Green
}
