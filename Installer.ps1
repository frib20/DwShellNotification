# =================================================================
# DWShellNotification - TRUE TOAST REGISTRATION VERSION
# =================================================================

# 1. CLEANUP OLD GHOSTS
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwShellNotify" -Confirm:$false -ErrorAction SilentlyContinue

# 2. SETUP DIRECTORY
$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)F" /T | Out-Null

# 3. REGISTER POWERSHELL FOR TOASTS (The missing piece)
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.PowerShell.V1"
if (!(Test-Path $RegPath)) { New-Item $RegPath -Force }
Set-ItemProperty $RegPath -Name "ShowInActionCenter" -Value 1
Set-ItemProperty $RegPath -Name "Enabled" -Value 1

# 4. THE LISTENER (Modern Toast API)
$listenerCode = @'
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$trigger = "C:\RemoteAdmin\msg.txt"

while($true) {
    if (Test-Path $trigger) {
        try {
            $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
            if ($msg) {
                # Load Windows Notification Assemblies
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
                $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
                
                # Set Text
                $textNodes = $template.GetElementsByTagName("text")
                $textNodes[0].AppendChild($template.CreateTextNode("Shorix System")) > $null
                $textNodes[1].AppendChild($template.CreateTextNode($msg.Trim())) > $null
                
                # Show Toast
                $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
                # We use the AppID "Windows.PowerShell.V1" which we registered in step 3
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Windows.PowerShell.V1").Show($toast)
            }
        } catch {
            # Only use MessageBox if the Toast system is literally broken
            [System.Windows.Forms.MessageBox]::Show($msg.Trim(), "Shorix System Fallback")
        }
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerCode

# 5. THE COMMANDS
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

# 6. START IN INTERACTIVE SESSION
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"
$triggerTask = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest
Register-ScheduledTask -TaskName "DwShellNotify" -Action $action -Trigger $triggerTask -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName "DwShellNotify"

Write-Host "INSTALL COMPLETE. CLOSE/OPEN SHELL AND TYPE: notify test" -ForegroundColor Green
