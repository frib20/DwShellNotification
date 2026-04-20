# Customization.ps1
# This file controls the branding and behavior of the DwShellNotification system.

$GlobalConfig = @{
    # 1. THE APPEARANCE
    # The 'Title' is the bold text at the top of the notification bubble.
    Title       = "System Administrator"

    # 2. THE ICON (Choose one: Information, Warning, Error, or None)
    IconType    = "Information"

    # 3. THE SYSTEM NAMES
    # 'ServiceName' is the name that appears in Windows Task Scheduler.
    ServiceName = "DwShellNotifyTask"

    # 4. THE PATHS
    # 'Folder' is where the listener script and message buffer will live.
    Folder      = "C:\RemoteAdmin"
    
    # 5. REFRESH RATE
    # How often (in seconds) the script checks for new messages.
    Interval    = 1
}
