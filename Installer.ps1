# =================================================================
# DWShellNotification - FULL REPAIR & SYNC VERSION
# =================================================================

# --- 1. CLEANUP OLD GHOSTS ---
$taskName = "AutoRemoteNotify" # Matches Config default
Write-Host "Purging old tasks and background processes..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*NotificationListener*" } | Stop-Process -Force

# --- 2. LOAD CONFIG ---
$configUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Config.ps1"
try {
    # We download the text and execute it to get the $GlobalConfig hashtable
    $configText = Invoke-RestMethod -Uri $configUrl
    Invoke-Expression $configText
    Write-Host "Config loaded from GitHub: $($GlobalConfig.Title)" -ForegroundColor Green
} catch {
    Write-Host "Failed to load Config.ps1, using local defaults." -ForegroundColor Yellow
    $GlobalConfig = @{ 
        Title       = "Remote Admin"
        ServiceName = "AutoRemoteNotify"
        Folder      = "C:\RemoteAdmin"
        IconType    = "Information" 
    }
}

$dir = $GlobalConfig.Folder
$title = $GlobalConfig.Title
$icon = $GlobalConfig.IconType
$taskName = $GlobalConfig.ServiceName
$scriptPath = "$dir\NotificationListener.ps1"

# --- 3. FOLDER & PERMISSIONS ---
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
# Ensure CMD can write here even if not running as Admin
icacls $dir /grant "Everyone:(OI)(CI)M" /T | Out-Null
Remove-Item "$dir\msg.txt" -Force -ErrorAction SilentlyContinue

# --- 4. THE LISTENER (Fast & Reliable) ---
$listenerContent = @"
Add-Type -AssemblyName System.Windows.Forms
`$trigger = "$dir\msg.txt"
`$n = New-Object System.Windows.Forms.NotifyIcon
`$n.Icon = [System.Drawing.SystemIcons]::$icon
`$n.Visible = `$True

while(`$true) {
    if (Test-Path `$trigger) {
        try {
            # Open file with 'ReadWrite' sharing to prevent locking conflicts
            `$stream = [System.IO.File]::Open(`$trigger, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            `$reader = New-Object System.IO.StreamReader(`$stream)
            `$msg = `$reader.ReadToEnd().Trim()
            `$reader.Close(); `$stream.Close()

            if (`$msg) {
                `$n.ShowBalloonTip(10000, "$title", `$msg, [System.Windows.Forms.ToolTipIcon]::$icon)
            }
        } catch {}
        Remove-Item `$trigger -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 200
}
"@
Set-Content -Path $scriptPath -Value $listenerContent -Encoding UTF8

# --- 5. THE BATCH FILE (Fixed Path & No Echo Error) ---
# We inject the REAL directory path into the batch file here
$batContent = @"
@echo off
if "%~1"=="" exit /b
(echo.%*) > "$dir\msg.txt"
echo [SUCCESS] Notification sent (CMD)
"@
[System.IO.File]::WriteAllLines("C:\Windows\notify.bat", $batContent, [System.Text.Encoding]::ASCII)

# --- 6. POWERSHELL FUNCTION (No Double-Send) ---
$functionCode = @"
function notify {
    param([Parameter(ValueFromRemainingArguments=`$true)]`$RawMessage)
    `$msg = `$RawMessage -join ' '
    if (!`$msg) { return }
    # Write directly to file - DO NOT call the 'notify' command or .bat
    [System.IO.File]::WriteAllText("$dir\msg.txt", `$msg)
    Write-Host "[SUCCESS] Notification sent (PS)" -ForegroundColor Green
}
"@
$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path (Split-Path $profilePath))) { New-Item -Type Directory (Split-Path $profilePath) -Force }
Set-Content -Path $profilePath -Value $functionCode -Force

# --- 7. SCHEDULE TASK (Interactive Mode) ---
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File ""$scriptPath"""
$trigger = New-ScheduledTaskTrigger -AtLogOn
# 'Interactive' ensures the bubble appears on the current desktop
$principal = New-ScheduledTaskPrincipal -GroupId "Interactive" -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Host "REPAIR COMPLETE. Restart your shell and try 'notify hello'" -ForegroundColor Green
