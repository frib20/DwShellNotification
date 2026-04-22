# 1. ELEVATION CHECK
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator to remove system components!" -ForegroundColor Red
    return
}

Write-Host "Starting full cleanup of AutoRemoteNotify..." -ForegroundColor Cyan

# 2. STOP AND REMOVE THE SCHEDULED TASK
$taskName = "AutoRemoteNotify"
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping and unregistering scheduled task..." -ForegroundColor Yellow
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# 3. KILL ANY LINGERING PROCESSES
# Finds any hidden PowerShell windows running the listener script specifically
$listenerProcs = Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*NotificationListener.ps1*" }
if ($listenerProcs) {
    Write-Host "Closing background listener processes..." -ForegroundColor Yellow
    $listenerProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}

# 4. REMOVE FILES AND DIRECTORIES
$dir = "C:\RemoteAdmin"
$batPath = "C:\Windows\notify.bat"

if (Test-Path $dir) {
    Write-Host "Removing directory: $dir" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $dir
}

if (Test-Path $batPath) {
    Write-Host "Removing CMD command: $batPath" -ForegroundColor Yellow
    Remove-Item -Force $batPath
}

# 5. CLEAN UP POWERSHELL PROFILE
if (Test-Path $PROFILE) {
    Write-Host "Cleaning up PowerShell profile..." -ForegroundColor Yellow
    $profileContent = Get-Content $PROFILE
    
    # This logic looks for the specific comment block we added and removes everything between/including them
    $newProfile = $profileContent | Out-String
    $pattern = "(?ms)# --- Remote Admin Notifier ---.*?\}\r?\n"
    
    if ($newProfile -match $pattern) {
        $newProfile = $newProfile -replace $pattern, ""
        Set-Content -Path $PROFILE -Value $newProfile.Trim() -Encoding UTF8
        Write-Host "Function 'notify' removed from profile." -ForegroundColor Green
    }
}

Write-Host "`n---[ UNINSTALL COMPLETE ]---" -ForegroundColor Green
Write-Host "All components have been removed. You may need to restart your terminal." -ForegroundColor White
