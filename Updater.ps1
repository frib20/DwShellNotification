Write-Host "Fetching latest installer..." -ForegroundColor Cyan
$installerUrl = "https://raw.githubusercontent.com/frib20/DwShellNotification/main/Installer.ps1"
$code = Invoke-RestMethod -Uri $installerUrl
Invoke-Expression $code
