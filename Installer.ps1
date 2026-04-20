# --- 1. LOAD CONFIG ---
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try {
    Invoke-RestMethod -Uri $configUrl | Invoke-Expression
} catch {
    $GlobalConfig = @{ Title="Remote Admin"; ServiceName="AutoRemoteNotify"; Folder="C:\RemoteAdmin"; IconType="Information" }
}

$dir = $GlobalConfig.Folder
$scriptPath = "$dir\NotificationListener.ps1"
$taskName = $GlobalConfig.ServiceName

if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null

# --- 2. CREATE STABLE LISTENER (Ultra-Fast Polling) ---
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$triggerFile = "$dir\msg.txt"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::$($GlobalConfig.IconType)
`$n.Visible = `$True

while(`$true) {
    # Using the .NET method for speed
    if ([System.IO.File]::Exists(`$triggerFile)) {
        try {
            # Direct file read with no locking
            `$stream = [System.IO.File]::Open(`$triggerFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            `$reader = New-Object System.IO.StreamReader(`$stream)
            `$message = `$reader.ReadToEnd().Trim()
            `$reader.Close()
            `$stream.Close()

            if (`$message) {
                `$n.ShowBalloonTip(10000, "$($GlobalConfig.Title)", `$message, [System.Windows.Forms.ToolTipIcon]::$($GlobalConfig.IconType))
            }
        } catch {}
        # Force delete immediately
        [System.IO.File]::Delete(`$triggerFile)
    }
    # 50ms is 20 checks per second - effectively instant
    [System.Threading.Thread]::Sleep(50)
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# --- 3. CREATE NOTIFY.BAT ---
$batContent = @'
@echo off
if "%~1"=="" exit /b
(echo.%*) > C:\RemoteAdmin\msg.txt
'@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 4. REGISTER & START (Critical Session Fix) ---
# We use 'Unregister' to kill any old hanging processes
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn

# IMPORTANT: Using 'Interactive' group ensures it pops up on the CURRENT user's screen
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "--- Installation Complete ---" -ForegroundColor Green
