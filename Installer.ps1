# =================================================================
# DWShellNotification - TRUE USER TOAST INJECTION
# =================================================================

# 1. CLEANUP
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwShellNotify" -Confirm:$false -ErrorAction SilentlyContinue

# 2. DIRECTORY SETUP
$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
icacls $dir /grant "Everyone:(OI)(CI)F" /T | Out-Null

# 3. THE LISTENER (Native Toast with Trusted AppID)
$listenerCode = @'
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$trigger = "C:\RemoteAdmin\msg.txt"

# This is the official AppID Windows uses for PowerShell. It bypasses the block.
$appId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

while($true) {
    if (Test-Path $trigger) {
        try {
            $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
            if ($msg) {
                # Build the Toast
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
                $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
                
                $textNodes = $template.GetElementsByTagName("text")
                $textNodes[0].AppendChild($template.CreateTextNode("Shorix System")) > $null
                $textNodes[1].AppendChild($template.CreateTextNode($msg.Trim())) > $null
                
                $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
            }
        } catch {
            # Absolute last resort fallback
            [System.Windows.Forms.MessageBox]::Show($msg, "Shorix System")
        }
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerCode

# 4. COMMANDS
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

# 5. USER INJECTION (The Magic Fix)
# We find out who is actually looking at the screen right now
$activeUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName

if ($activeUser) {
    Write-Host "Injecting listener into user session: $activeUser" -ForegroundColor Cyan
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"
    $triggerTask = New-ScheduledTaskTrigger -AtLogOn
    
    # Force the task to run as the exact human logged in
    $principal = New-ScheduledTaskPrincipal -UserId $activeUser -LogonType Interactive
    
    Register-ScheduledTask -TaskName "DwShellNotify" -Action $action -Trigger $triggerTask -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName "DwShellNotify"
    Write-Host "INSTALL COMPLETE. CLOSE/OPEN SHELL AND TYPE: notify test" -ForegroundColor Green
} else {
    Write-Host "ERROR: No user is currently logged into the desktop." -ForegroundColor Red
    Write-Host "Someone must be logged in for Toast notifications to exist." -ForegroundColor Yellow
}
