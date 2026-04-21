# =================================================================
# DWShellNotification - TOAST ONLY (NO MESSAGEBOX)
# =================================================================

# --- THE HARD KILL ---
Write-Host "Purging all old notification processes..." -ForegroundColor Cyan
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force
Unregister-ScheduledTask -TaskName "DwGuiBridge" -Confirm:$false -ErrorAction SilentlyContinue

$dir = "C:\RemoteAdmin"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
icacls $dir /grant "Everyone:(OI)(CI)F" /T | Out-Null

# --- THE CLEAN LISTENER ---
$listenerCode = @'
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$trigger = "C:\RemoteAdmin\msg.txt"
$appId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

while($true) {
    if (Test-Path $trigger) {
        $msg = Get-Content $trigger -Raw -ErrorAction SilentlyContinue
        if ($msg) {
            try {
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
                $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
                $textNodes = $template.GetElementsByTagName("text")
                $textNodes[0].AppendChild($template.CreateTextNode("Shorix System")) > $null
                $textNodes[1].AppendChild($template.CreateTextNode($msg.Trim())) > $null
                $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
            } catch {
                # NO MESSAGE BOX HERE. EVER.
            }
        }
        Remove-Item $trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
'@
Set-Content -Path "$dir\NotificationListener.ps1" -Value $listenerCode -Encoding UTF8

# --- COMMANDS ---
"@echo off`necho %* > C:\RemoteAdmin\msg.txt" | Set-Content "C:\Windows\notify.bat"
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
'function notify { $args -join " " > "C:\RemoteAdmin\msg.txt" }' | Set-Content $profilePath -Force

# --- RE-INJECT ---
$activeUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
if ($activeUser) {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -File C:\RemoteAdmin\NotificationListener.ps1"
    $principal = New-ScheduledTaskPrincipal -UserId $activeUser -LogonType Interactive
    $triggerTask = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName "DwGuiBridge" -Action $action -Principal $principal -Trigger $triggerTask -Force | Out-Null
    Start-ScheduledTask -TaskName "DwGuiBridge"
    Write-Host "Success. The MessageBox code has been physically deleted." -ForegroundColor Green
}
