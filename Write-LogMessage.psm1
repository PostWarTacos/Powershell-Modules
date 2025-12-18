Function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [string]$Message,
        [Parameter(Position=1)]
        [ValidateSet("Info", "Warning", "Error", "Success", "Default")]
        [string]$Level,
        [string]$LogFile = "$healthLogPath\HealthCheck.txt"
    )
    
    # Generate timestamp for log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Add level-specific prefixes for visual identification    
    if ($Level) {
        $prefix = switch ($Level) {
            "Info"    { "[*]" }     # Informational messages
            "Warning" { "[!]" }     # Warning messages  
            "Error"   { "[!!!]" }   # Error messages
            "Success" { "[+]" }     # Success messages
        }
    }
    else {
        $prefix = "[*]" # Default prefix for unspecified level
        $Level = "Default"
    }

    
    $logEntry = "[$timestamp] $prefix $Message"

    # Display console output with appropriate colors for each level (only when running interactively)
    switch ($Level) {
        "Default" { Write-Host $logEntry -ForegroundColor DarkGray }
        "Info"    { Write-Host $logEntry -ForegroundColor White }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error"   { Write-Host $logEntry -ForegroundColor Red }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to log file if specified
    if ($LogFile) {
        try {
            $logEntry | Out-File -FilePath $LogFile -Append -ErrorAction Stop
        } catch {
            # Use Write-Warning to avoid recursion when logging fails
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Write-LogMessage
