# =================================================================
# DWShellNotification - MODERN TOAST VERSION
# =================================================================

# 1. CLEANUP
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force

# 2. DIRECTORY
$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)F" /T | Out-Null

# 3. THE LISTENER (Modern XML Toast)
$listenerCode = @'
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$trigger = "C:\RemoteAdmin\msg.txt"

while($true) {
    if (Test-Path $trigger) {
        try {
            $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
            if ($msg) {
                # Load the Windows Toast XML
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
                $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
                
                # Set the Title and Message
                $toastTextElements = $template.GetElementsByTagName("text")
                $toastTextElements[0].AppendChild($template.CreateTextNode("Shorix System")) > $null
                $toastTextElements[1].AppendChild($template.CreateTextNode($msg.Trim())) > $null
                
                # Show it
                $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell").Show($toast)
            }
        } catch {
            # Fallback to popup if Toast API fails
            [System.Windows.Forms.MessageBox]::Show($msg, "Shorix System - Fallback")
        }
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
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

# 5. START (Using the Interactive principal via Scheduled Task for best Toast support)
$taskName = "DwShellNotify"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"
$triggerTask = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggerTask -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "TOAST INSTALLER COMPLETE." -ForegroundColor Green
