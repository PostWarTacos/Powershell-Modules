function Keep-Awake {
    <#
    .SYNOPSIS
    Keeps the computer awake by simulating F15 key presses.
    
    .DESCRIPTION
    Prevents the computer from going idle by simulating F15 key presses every 4 minutes.
    This does not affect mouse or keyboard usage.
    
    .EXAMPLE
    Keep-Awake
    Starts the keep-awake loop. Press Ctrl+C to stop.
    #>
    
    Write-Host "Keep-Awake script is running. Press Ctrl+C to stop."

    # Prevent idle without affecting mouse or keyboard
    Add-Type -AssemblyName System.Windows.Forms

    while ($true) {
        # Simulate "F15" reset every 4 minutes
        [System.Windows.Forms.Application]::DoEvents()
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        [System.Windows.Forms.SendKeys]::SendWait("{F15}")
        Start-Sleep -Seconds 240
    }
}

Export-ModuleMember -Function Keep-Awake
